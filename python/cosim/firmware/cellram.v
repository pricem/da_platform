//  Micron Cellular RAM modelMT45W8MW16BGX
//  8 Meg x 16-bit

//  No timing constraints, but the version used on the Nexys2 has an 80 MHz
//  max clock speed (synchronous mode) or 70 ns read/write time (asynchronous)

//  The inputs (ce, we, oe, cre, adv, lb, ub) are all active low.

module cellram(clk, ce, we, oe, addr, data, reset, cre, mem_wait, adv, lb, ub);

    input clk;
    input ce;
    input we;
    input oe;
    input [22:0] addr;
    
    inout [15:0] data;
    input reset;
    input cre;
    output mem_wait;
    
    input adv;
    input lb;
    input ub;
    
    //  Connections to memory and internal signals
    wire mem_we;
    wire mem_oe;
    reg [22:0] mem_addr;
    wire [15:0] mem_data_in;
    wire [15:0] mem_data_out;
    wire reset_neg = ~reset;
    
    //  Internal signals
    parameter IDLE = 3'b000;
    parameter CONFIGURING = 3'b001;
    parameter READING_INIT = 3'b010;
    parameter WRITING_INIT = 3'b011;
    parameter READING = 3'b100;
    parameter WRITING = 3'b101;
    reg [2:0] mode;
    
    reg [22:0] config;
    reg [15:0] last_data;
    reg [1:0] config_counter;

    reg [2:0] write_counter;
    reg [2:0] read_counter;
    
    reg mem_wait_internal;
    
    //  Assign data line if chip is enabled
    assign data = ce ? 16'hZZZZ : last_data;
    
    //  Assign active high memory control signals based on state
    assign mem_we = (mode == WRITING) && ~ce;
    assign mem_oe = (mode == READING) && ~ce;

    //  Assign mem_wait output depending on configuration
    assign mem_wait = config[10] ? mem_wait_internal : ~mem_wait_internal;
    
    //  Assign data
    assign mem_data_in = data;

    always @(posedge clk) begin
        if (~reset) begin
            mem_addr <= 23'h000000;
            
            mode <= IDLE;
            
            config <= 23'h009D1F;
            last_data <= 16'hZZZZ;
            
            config_counter <= 0;
            write_counter <= 0;
            read_counter <= 0;
            
            mem_wait_internal <= 1'bZ;

        end
        else if (~ce) begin
            
            case (mode)
                IDLE: begin
                    //  This idle state is a disambiguator that chooses a next state when
                    //  the control lines cre or adv are asserted
                    if (cre) begin
                        //  Latch new configuration
                        mode <= CONFIGURING;
                        config <= addr;
                        config_counter <= 0;
                        mem_wait_internal <= 1;
                    end
                    else if (~adv) begin
                        //  Load address when adv ("address valid") is taken active low
                        mem_addr <= addr;
                        //  Determine whether this is a read using the active low we line
                        if (we) begin
                            mode <= READING_INIT;
                            mem_wait_internal <= 1;
                            read_counter <= 0;
                        end
                        else begin
                            mode <= WRITING_INIT;
                            mem_wait_internal <= 1;
                            write_counter <= 0;
                        end
                    end
                end
              
                //  Each of the 3 modes below (configuring, initializing read, initializing write) has a 
                //  delay of 3 clock cycles (set in BCR).
                //  The configuration mode ends there; the reading and writing modes begin reading/writing then
                //  and are only taken back to idle mode when the chip enable (ce) is deasserted (high).
                CONFIGURING: begin
                    if (config_counter == 2) begin
                        config_counter <= 0;
                        mode <= IDLE;
                        mem_wait_internal <= 0;
                    end
                    else begin
                        config_counter <= config_counter + 1;
                        mem_wait_internal <= 1;
                    end
                end
                
                READING_INIT: begin
                    if (read_counter == 2) begin
                        read_counter <= 0;
                        mode <= READING;
                        mem_wait_internal <= 0;
                    end
                    else begin
                        read_counter <= read_counter + 1;
                        mem_wait_internal <= 1;
                    end
                end
                
                WRITING_INIT: begin
                    if (write_counter == 2) begin
                        write_counter <= 0;
                        mode <= WRITING;
                        mem_wait_internal <= 0;
                    end
                    else begin
                        write_counter <= write_counter + 1;
                        mem_wait_internal <= 1;
                    end
                end
                
                READING: begin
                    mem_addr <= mem_addr + 1;
                    last_data <= mem_data_out;
                end
                
                WRITING: begin
                    mem_addr <= mem_addr + 1;
                    //  Data is directly connected; separate register not needed
                end
            
            endcase
            
        end
        else begin
            //  Reset the state if the chip is not enabled
            mem_wait_internal <= 1'bZ;
            mode <= IDLE;
            config_counter <= 0;
            read_counter <= 0;
            write_counter <= 0;
        end
    end
    
    bram_8m_16 mem(
        .clk(clk), 
        .we(mem_we), 
        .oe(mem_oe),
        .addr(mem_addr), 
        .din(mem_data_in), 
        .dout(mem_data_out),
        .reset(reset_neg)
        );
    
endmodule

