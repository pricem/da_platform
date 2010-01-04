//  Memory arbitrator
//  Controls who reads and writes the off-chip memory.

//  8 write ports:
//  -   4 from EP2, selected by the port number in each data packet
//  -   4 from the audio converter interface bus.
//  8 read ports:
//  -   4 to the audio converter interface bus.
//  -   4 to EP6, read by a data encoder that checks the in/out delta

//  Context:
//  - This module is needed so multiple sources/sinks of data can share 
//  - Each of the ports of this module is connected to an asynchronous FIFO.
//  - The clock frequency of the arbitrator is limited by memory bandwidth.
//    It is set to twice the memory clock here because it reads/writes one
//    byte at a time to/from FIFOs, but the memory bus is 16 bits.

//  Algorithm:
//  Cycles through all write ports then all read ports.
//  For each port, if the in/out delta is greater than 0,
//  - store the in address and the delta D
//  - [write port] Read D bytes from the port FIFO and write them to RAM
//  - [read port] 

module memory_arbitrator(
    //  Connections to write port FIFOs
    write_in_addrs, write_out_addrs, write_read_datas, write_clk, write_read,
    //  Connections to read port FIFOs
    read_in_addrs, read_out_addrs, read_write_datas, read_clk, read_write,
    //  Connections to other devices
    write_fifo_byte_counts,         //  Byte count on the "in" side of the write FIFOs
    read_fifo_byte_counts,          //  Byte count on the "in" side of the read FIFOs
    //  Connections to memory
    mem_addr, mem_data, mem_ce, mem_oe, mem_we, mem_clk, mem_wait, mem_addr_valid, mem_cre,
    //  Double the memory clock; synchronous reset
    clk, reset);
    
    /*  I/O declarations */
    
    //  Connections to write side FIFOs
    input [87:0] write_in_addrs;
    input [87:0] write_out_addrs;
    input [63:0] write_read_datas;
    output write_clk;
    output reg [7:0] write_read;
    
    //  Connection to read side FIFOs
    input [87:0] read_in_addrs;
    input [87:0] read_out_addrs;
    output [63:0] read_write_datas;
    output read_clk;
    output reg [7:0] read_write;
    
    //  Byte counters for tracking
    input [255:0] write_fifo_byte_counts;
    output [255:0] read_fifo_byte_counts;
    
    //  Connections to cell RAM
    //  Memory definition (elsewhere) looks like this:
    //  cellram = bram_8m_16(.clk(clk_div2), .we(mem_we), .addr(mem_addr), .din(mem_data), .dout(mem_data));
    output [22:0] mem_addr;
    inout [15:0] mem_data;
    output reg mem_ce;
    output mem_oe;
    output mem_we;
    output mem_clk;
    input mem_wait;
    output reg mem_addr_valid;
    output reg mem_cre;
    
    //  Controls
    input clk;
    input reset;


    /* Internal signals */
    
    integer i;
    genvar g;
    
    //  Break down and assign buses
    wire [10:0] write_in_addr [7:0];
    wire [10:0] write_out_addr [7:0];
    wire [7:0] write_read_data [7:0];
    wire [10:0] read_in_addr [7:0];
    wire [10:0] read_out_addr [7:0];
    wire [7:0] read_write_data [7:0];
    wire [31:0] write_fifo_byte_count [7:0];
    reg [31:0] read_fifo_byte_count [7:0];
    generate for (g = 0; g < 8; g = g + 1) begin:fifos
        assign write_in_addr[g] = write_in_addrs[((g + 1) * 11 - 1):(g * 11)];
        assign write_out_addr[g] = write_out_addrs[((g + 1) * 11 - 1):(g * 11)];
        assign read_in_addr[g] = read_in_addrs[((g + 1) * 11 - 1):(g * 11)];
        assign read_out_addr[g] = read_out_addrs[((g + 1) * 11 - 1):(g * 11)];
        
        assign write_read_data[g] = write_read_datas[((g + 1) * 8 - 1):(g * 8)];
        assign read_write_datas[((g + 1) * 8 - 1):(g * 8)] = read_write_data[g];

        assign write_fifo_byte_count[g] = write_fifo_byte_counts[((g + 1) * 32 - 1):(g * 32)];
        assign read_fifo_byte_counts[((g + 1) * 32 - 1):(g * 32)] = read_fifo_byte_count[g];
        end
    endgenerate
    
    //  The primary clock (100-150 MHz) is divided by 2 to obtain the memory clock.
    reg clk_div2;
    
    //  Concatenated memory buses for read and write
    wire [15:0] mem_write_data;
    reg [7:0] write_lower_byte;
    reg [7:0] write_upper_byte;
    assign mem_write_data = {write_upper_byte, write_lower_byte};
    wire [15:0] mem_read_data = mem_data;
    wire [7:0] read_lower_byte;
    wire [7:0] read_upper_byte;
    assign read_lower_byte = mem_read_data[7:0];
    assign read_upper_byte = mem_read_data[15:8];
    reg [7:0] mem_read_byte;
    assign mem_clk = clk_div2;  //  clk_div2 ? clk : 0;
    assign write_clk = clk;
    assign read_clk = clk;

    //  Parameters
    
    //  Possible outer states
    parameter CONFIGURING = 3'b000;
    parameter READ_SCAN = 3'b010;
    parameter WRITE_SCAN = 3'b011;
    parameter READING = 3'b100;     //  READING cellram into FIFO (destination: EP6 or DAC)
    parameter WRITING = 3'b101;     //  WRITING FIFO into cellram (source: EP2 or ADC)  
    
    //  Possible cycle states
    parameter INITIALIZING = 2'b00;
    parameter WAITING = 2'b01;
    parameter ACTIVE = 2'b10;
    parameter DONE = 2'b11;
      
    parameter NUM_PORTS = 4;
    parameter BCR_VALUE = 23'h081D0F;
    parameter MIN_CHUNK = 4;        //  Minimum amount of data to read at a time
    
    //  States
    reg [2:0] state;                //  Outer state: configuring, read_scan, reading, write_scan, writing
    reg [1:0] cycle_state;          //  Inner state: start, wait, active
    reg [2:0] current_port;         //  Port index (0 to 7)
    reg [2:0] delay_counter;        //  Allow up to 8 cycles for memory to finish writing configuration register
    reg [10:0] current_fifo_addr;
    reg [10:0] current_delta;

    //  Internal byte counter for data as it is written to RAM
    reg [31:0] write_mem_byte_count[7:0];
    
    //  Delayed copy of read control for write FIFO
    reg write_read_delayed;
    
    //  Control memory
    assign mem_we = (state == WRITING);
    assign mem_data = mem_we ? mem_write_data : 16'hZZZZ;
    assign mem_oe = (state == READING);
    
    //  8M address space divided evenly into 8 sections of 1M each
    //  Address lines carry configuration register value during configuration
    assign mem_addr = mem_cre ? BCR_VALUE : (current_port << 10) + (current_fifo_addr >> 1);
    
    //  Assign data to write port of read-side tracking FIFOs
    generate for (g = 0; g < 8; g = g + 1) begin:read_datas
            assign read_write_data[g] = (current_port == g) ? mem_read_byte : 8'hZZ;
        end
    endgenerate
    
    /*  Logic processes */
    
    //  Drive memory clock at half speed of primary clock, with 90 deg shift.
    //  This ensures that at each positive edge of the memory clock, data set up at the positive
    //  edge of the primary clock will be usable.
    always @(negedge clk) begin
        if (reset)
            clk_div2 <= 1;
        else
            clk_div2 <= clk_div2 + 1;
    end
    
    //  Alternate reading lower and upper bytes for external RAM
    always @(posedge clk) begin
        if (reset) begin
            write_lower_byte <= 0;
            write_upper_byte <= 0;
            write_read_delayed <= 0;
        end
        else begin
            write_read_delayed <= write_read[current_port];
            
            //  Load lower/upper byte
            if (write_read_delayed == 1) begin
                if (clk_div2 == 0)
                    write_lower_byte <= write_read_data[current_port];
                else
                    write_upper_byte <= write_read_data[current_port];
            end
        end
    end

    //  Assign byte counters to keep track of number of samples since reset
    generate for (g = 0; g < 8; g = g + 1) begin:counters
            //  Applies to all read-side FIFOs
            //  (4 between RAM and DAC interfaces, then 4 between RAM and EP6)
            always @(posedge read_clk) begin
                if (reset)
                    read_fifo_byte_count[g] <= 0;
                else begin
                    if (read_write[g])
                        read_fifo_byte_count[g] <= read_fifo_byte_count[g] + 1;
                end
            end
        end
    endgenerate
    
    //  State machine with memory data transfer 
    //  (individual bytes are prepared at twice the memory clock rate)
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < 8; i = i + 1) begin
                write_read[i] <= 0;
                read_write[i] <= 0;
                write_mem_byte_count[i] <= 0;
            end
            state <= CONFIGURING;
            cycle_state <= DONE;
            current_port <= 0;
            current_fifo_addr <= 0;
            mem_ce <= 1;
            mem_addr_valid <= 0;
            current_delta <= 0;
            mem_cre <= 0;
            delay_counter <= 0;
            mem_read_byte <= 0;
        end
        else begin
        
            //  State machine with a twist:
            //  - Only transition to a new state when clk_div2 is high.
            //    This synchronizes operation with the external memory
            //    and holds values steady for 3/4 of a clock cycle.
            case (state)
                CONFIGURING: begin
                    //  If the memory's bus configuration register has not yet been set, program it.
                    //  This is done by setting mem_cre high, putting the register value on the address line
                    //  and holding a "write" until the mem_wait line goes high.
                    if (clk_div2 == 1) begin
                        //  Increment the delay counter so that we know how long we've been waiting
                        delay_counter <= delay_counter + 1;
    
                        if (~mem_wait && delay_counter > 1) begin
                            //  Move on to the other states once mem_wait is deasserted
                            delay_counter <= 0;
                            mem_cre <= 0;
                            current_port <= 0;
                            state <= READ_SCAN;
                        end
                        else begin
                            //  Set the mem_cre line to enable configuration for the first clk_div2 cycle
                            if (delay_counter > 0)
                                mem_cre <= 0;
                            else
                                mem_cre <= 1;
                        end
                    end
                end
                
                READ_SCAN: begin
                    write_read[current_port] <= 0;
                    read_write[current_port] <= 0;
                    mem_ce <= 0;

                    //  Compute delta from byte count lag between read side and write site.
                    current_fifo_addr <= read_in_addr[current_port];
                    current_delta <= write_mem_byte_count[current_port] - read_fifo_byte_count[current_port];

                    if (current_delta > MIN_CHUNK) begin
                        cycle_state <= INITIALIZING;
                        state <= READING;
                    end
                    else if (clk_div2 == 1) begin
                        if (current_port == (NUM_PORTS - 1)) begin
                            current_port <= 0;
                            state <= WRITE_SCAN;
                        end
                        else
                            current_port <= current_port + 1;
                    end
                end
                
                WRITE_SCAN: begin
                    write_read[current_port] <= 0;
                    read_write[current_port] <= 0;
                    mem_ce <= 0;
                    
                    //  Assign current_delta to write only up to an even number of bytes (due to 16-bit memory word)
                    if (clk_div2 == 1) begin
                        if (current_delta > MIN_CHUNK) begin
                            cycle_state <= INITIALIZING;
                            state <= WRITING;
                            //  Latch effective byte count at input.
                            write_mem_byte_count[current_port] <= write_mem_byte_count[current_port] + current_delta;
                            current_fifo_addr <= write_out_addr[current_port];
                            current_delta <= ((write_in_addr[current_port] - write_out_addr[current_port]) / 2) << 1;
                        end
                        else if (current_port == (NUM_PORTS - 1)) begin
                            current_port <= 0;
                            state <= READ_SCAN;
                            current_delta <= ((write_in_addr[0] - write_out_addr[0]) / 2) << 1;
                        end
                        else begin
                            current_port <= current_port + 1;
                            current_delta <= ((write_in_addr[(current_port + 1) % NUM_PORTS] - write_out_addr[current_port + 1] % NUM_PORTS) / 2) << 1;
                        end
                    end
                    else
                        current_delta <= ((write_in_addr[current_port] - write_out_addr[current_port]) / 2) << 1;
                end
                
                READING: begin
                    mem_read_byte <= clk_div2 ? read_upper_byte : read_lower_byte;
                    case (cycle_state)
                        INITIALIZING: begin
                            mem_ce <= 1;
                            //  Assert mem_addr_valid on first clk_div2 cycle, then wait
                            if (clk_div2 == 1) begin
                                if (~mem_addr_valid)
                                    mem_addr_valid <= 1;
                                else begin
                                    mem_addr_valid <= 0;
                                    cycle_state <= WAITING;
                                end
                            end
                        end
                        WAITING: begin
                            mem_ce <= 1;
                            //  Wait for mem_wait to be deasserted and then switch to active mode
                            if (clk_div2 == 1)
                                if (~mem_wait) begin
                                    read_write[current_port] <= 1;
                                    cycle_state <= ACTIVE;
                                end
                        end
                        ACTIVE: begin
                            //  Account for 3-cycle lag in current_delta
                            if (current_delta < 4) begin
                                mem_ce <= 0;
                                if (current_delta < 3)
                                    read_write[current_port] <= 0;
                                //  You're done if you've read all the memory that you needed to.
                                if (clk_div2 == 1) begin
                                    read_write[current_port] <= 0;
                                    cycle_state <= DONE;
                                end
                            end
                            else begin
                                //  When data is valid, write to tracking FIFO
                                mem_ce <= 1;
                                read_write[current_port] <= 1;
                                current_delta <= write_mem_byte_count[current_port] - read_fifo_byte_count[current_port];
                            end
                        end
                        DONE: begin
                            read_write[current_port] <= 0;
                            mem_ce <= 0;
                            current_port <= current_port + 1;
                            state <= READ_SCAN; 
                        end
                    endcase
                end
                
                WRITING: begin
                    case (cycle_state)
                        INITIALIZING: begin
                            mem_ce <= 1;
                            //  Assert mem_addr_valid on first clk_div2 cycle, then wait
                            //  Also, assert write_read for one clk_div2 cycle to get the first two bytes
                            if (clk_div2 == 1) begin
                                if (~mem_addr_valid) begin
                                    write_read[current_port] <= 1;
                                    mem_addr_valid <= 1;
                                end
                                else begin
                                    mem_addr_valid <= 0;
                                    write_read[current_port] <= 0;
                                    cycle_state <= WAITING;
                                end
                            end
                        end
                        WAITING: begin
                            mem_ce <= 1;
                            //  Wait for mem_wait to be deasserted and then switch to active mode
                            if (~mem_wait)
                                if (clk_div2 == 1) begin
                                    read_write[current_port] <= 0;
                                    write_read[current_port] <= 1;
                                    cycle_state <= ACTIVE;
                                end
                        end
                        ACTIVE: begin
                            if (current_delta < 2) begin
                                //  You're done if you've written all the memory that you needed to.
                                mem_ce <= 0;
                                write_read[current_port] <= 0;
                                if (clk_div2 == 1)
                                    cycle_state <= DONE;
                            end
                            else begin
                                //  When data is valid, read from tracking FIFO
                                mem_ce <= 1;
                                read_write[current_port] <= 0;
                                //  Allow for the delay in write_read control; avoid reading past end of FIFO
                                if (current_delta >= 4)
                                    write_read[current_port] <= 1;
                                else
                                    write_read[current_port] <= 0;
                                current_delta <= current_delta - 1;
                            end
                        end
                        DONE: begin
                            mem_ce <= 0;
                            current_port <= current_port + 1;
                            state <= WRITE_SCAN; 
                        end
                    endcase
                end
            endcase
        end
    end

endmodule
