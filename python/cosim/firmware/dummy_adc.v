//  A dummy module for a nonexistent ADC.

module dummy_adc(
    //  Register programming
    config_clk, config_write, config_read, config_addr, config_data,
    //  FIFO connection
    fifo_clk, fifo_data, fifo_write, fifo_addr_in, fifo_addr_out,
    //  Other internal connections
    custom_clk0, custom_clk1,
    //  FX2 data port
    slot_data, direction, channels,
    //  Control
    clk, reset
    );
    
    input config_clk;
    input config_write;
    input config_read;
    input [1:0] config_addr;
    inout [7:0] config_data;
    
    output fifo_clk;
    output reg [7:0] fifo_data;
    output reg fifo_write;
    input [10:0] fifo_addr_in;
    input [10:0] fifo_addr_out;
        
    input custom_clk0;
    input custom_clk1;
    
    input [5:0] slot_data;
    input direction;
    input channels;
    
    input clk;
    input reset;
    
    integer i;
    
    //  Configuration registers
    reg [7:0] config [3:0];
    reg [7:0] config_data_out;
    always @(posedge config_clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 4; i = i + 1)
                config[i] <= 0;
        end
        else begin
            config_data_out <= config[config_addr];
            if (config_write) begin
                config[config_addr] <= config_data;
            end
        end
    end
    assign config_data = config_read ? config_data_out : 8'hZZ;
    
    //  100 MHz input clk / 256 = 400 kHz
    reg [7:0] clk_counter;
    reg [1:0] msg_counter;
    reg sample_clk;
    reg sample_bit_clk;
    reg sample_clk_last;
    wire [31:0] message = 32'hDEADBEEF;
    
    //  Keep reset around so you can cycle FIFO clock at reset
    reg reset_last;
    
    //  Run FIFO at full speed (could be changed for lower power consumption)
    assign fifo_clk = clk;
    
    always @(posedge clk) begin
        if (reset) begin
            clk_counter <= 0;
            msg_counter <= 0;
            sample_clk_last <= 0;
            sample_bit_clk <= 0;
            //  Cycle FIFO clock at reset
            if (reset_last)
                sample_clk <= 0;
            else
                sample_clk <= 1;
            fifo_data <= 0;
            fifo_write <= 0;
            reset_last <= 1;
        end
        else begin
            reset_last <= 0;
            clk_counter <= clk_counter + 1;
            
            //  Trigger the FIFO clock once in a while
            if (clk_counter == 127)
                sample_clk <= sample_clk + 1;
            if (clk_counter % 8 == 7)
                sample_bit_clk <= sample_bit_clk + 1;
            
            //  When the FIFO clock is triggered, send 4 bytes of data to the FIFO.
            sample_clk_last <= sample_clk;
            if (((sample_clk == 1) && (sample_clk_last == 0)) || (msg_counter != 0)) begin
                if (direction == 1) begin
                    msg_counter <= msg_counter + 1;
                    fifo_write <= 1;
                    case (msg_counter)
                        0: fifo_data <= message[7:0];
                        1: fifo_data <= message[15:8];
                        2: fifo_data <= message[23:16];
                        3: fifo_data <= message[31:24];
                    endcase
                end
            end
            else begin
                fifo_write <= 0;
                fifo_data <= 0;
            end

        end
    end
    

endmodule

