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
    reg [7:0] read_write_data [7:0];
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
    wire [15:0] mem_read_data;
    wire [7:0] read_lower_byte;
    wire [7:0] read_upper_byte;
    assign read_lower_byte = mem_read_data[7:0];
    assign read_upper_byte = mem_read_data[15:8];
    assign mem_clk = clk_div2;  //  clk_div2 ? clk : 0;
    assign write_clk = clk;
    assign read_clk = clk;

    //  Parameters
    parameter CONFIGURING = 3'b000;
    parameter READ_SCAN = 3'b010;
    parameter WRITE_SCAN = 3'b011;
    parameter READING = 3'b100;     //  READING cellram into FIFO (destination: EP6 or DAC)
    parameter WRITING = 3'b101;     //  WRITING FIFO into cellram (source: EP2 or ADC)    
    parameter NUM_PORTS = 4;
    parameter BCR_VALUE = 23'h081D0F;
    
    //  States
    reg state;
    reg [2:0] current_port;         //  Port index (0 to 7)
    reg [2:0] delay_counter;       //  Allow up to 8 cycles for memory to finish writing configuration register
    reg [10:0] current_fifo_addr;
    reg [10:0] current_delta;

    //  Internal byte counter for data as it is written to RAM
    reg [31:0] write_mem_byte_count[7:0];
    
    //  Control memory
    reg write_read_delayed;
    reg read_write_delayed;
    assign mem_we = write_read[current_port];
    assign mem_data = mem_we ? mem_write_data : 16'hZZZZ;
    assign mem_oe = ~write_read_delayed;
    
    //  8M address space divided evenly into 8 sections of 1M each
    //  Address lines carry configuration register value during configuration
    assign mem_addr = mem_cre ? BCR_VALUE : (current_port << 10) + (fifo_addr >> 1);
    
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
            read_write_delayed <= 0;
            fifo_addr_delayed <= 0;
        end
        else begin
            //  Update delayed signals
            if (clk_div2 == 0) begin
                write_read_delayed <= write_read[current_port];
                read_write_delayed <= read_write[current_port];
                fifo_addr_delayed <= current_fifo_addr;
            end
       
            //  Load lower/upper byte
            if (clk_div2 == 0)
                write_lower_byte <= write_read_data[current_port_delayed];
            else
                write_upper_byte <= write_read_data[current_port_delayed];
            
        end
    end

    
    //  State machine with memory data transfer 
    //  (individual bytes are prepared at twice the memory clock rate)
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < 8; i = i + 1) begin
                write_read[i] <= 0;
                read_write_data[i] <= 0;
                read_write[i] <= 0;
                read_fifo_byte_count[i] <= 0;
                write_mem_byte_count[i] <= 0;
            end
            state <= CONFIGURING;
            current_port <= 0;
            current_fifo_addr <= 0;
            mem_ce <= 1;
            mem_addr_valid <= 0;
            current_delta <= 0;
            mem_cre <= 0;
            delay_counter <= 0;
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
    
                        if (mem_wait && delay_counter > 1) begin
                            //  Move on to the other states once mem_wait is asserted
                            delay_counter <= 0;
                            config_done <= 1;
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
                    if (clk_div2 == 1) begin
                    
                    end
                end
                
                WRITE_SCAN: begin
                
                end
                
                READING: begin
                
                    if (current_delta == 0)
                end
                
                WRITING: begin
                
                end
                
            endcase
        
            //  Advance state if necessary
            if ((current_delta == 0) && (!start_flag)) begin
                //  If the last port was reached, reset to port 0 and switch directions.
                if (current_port == (NUM_PORTS - 1)) begin
                    current_port <= 0;
                    if (current_direction == READING)
                        current_direction <= WRITING;
                    else
                        current_direction <= READING;
                end
                //  Otherwise go to the next port
                else
                    current_port <= current_port + 1;
                    
                write_read[current_port] <= 0;
                read_write[current_port] <= 0;
                start_flag <= 1;
                mem_ce <= 0;
            end
            
            //  At beginning of cycle, load parameters and clear start flag
            else if (start_flag) begin
                
                if (current_direction == WRITING) begin
                    //  Latch effective byte count at input.
                    write_mem_byte_count[current_port] <= write_fifo_byte_count[current_port];
                    
                    current_fifo_addr <= write_out_addr[current_port];
                    //  Write only up to an even number of bytes (due to 16-bit memory word)
                    current_delta <= ((write_in_addr[current_port] - write_out_addr[current_port]) / 2) << 1;
                    
                    /*
                    //  Start reads from write FIFOs ahead of time due to the 1-cycle latency in reading from a FIFO.
                    write_read[current_port] <= 1;
                    read_write[current_port] <= 0;
                    */
                end
                else begin
                    current_fifo_addr <= read_in_addr[current_port];
                    
                    //  Compute delta from byte count lag between read side and write site.
                    current_delta <= write_mem_byte_count[current_port] - read_fifo_byte_count[current_port];

                    read_write[current_port] <= 0;
                    write_read[current_port] <= 0;
                end
                mem_ce <= 0;
                start_flag <= 0;
            end
            
            //  Once cycle is under way, perform read or write task
            else begin
                mem_ce <= 1;
                if (start_flag_delayed)
                    mem_addr_valid <= 1;
                if (mem_addr_valid && ~clk_div2)
                    mem_addr_valid <= 0;
            
                if (current_direction == READING) begin
                    read_write[current_port] <= 1;
                    write_read[current_port] <= 0;
                end

                else begin
                    read_write[current_port] <= 0;
                    write_read[current_port] <= 1;
                    //  Update counters
                    current_fifo_addr <= current_fifo_addr + 1;
                    current_delta <= current_delta - 1;
                end
            end
        end
    end

endmodule
