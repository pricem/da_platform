//  A dummy module for a nonexistent ADC.

module dummy_adc(
    //  FIFO connection
    fifo_clk, fifo_data, fifo_write, fifo_addr_in, fifo_addr_out,
    //  FX2 data port
    slot_data, direction, channels,
    //  Control
    clk, reset
    );
    
    output reg fifo_clk;
    output reg [7:0] fifo_data;
    output reg fifo_write;
    input [10:0] fifo_addr_in;
    input [10:0] fifo_addr_out;
    
    input [5:0] slot_data;
    input direction;
    input channels;
    
    input clk;
    input reset;
    
    //  100 MHz input clk / 256 = 400 kHz
    reg [7:0] clk_counter;
    reg [1:0] msg_counter;
    reg fifo_clk_last;
    wire [31:0] message = 32'hDEADBEEF;
    
    //  Keep reset around so you can cycle FIFO clock at reset
    reg reset_last;
    
    always @(posedge clk) begin
        if (reset) begin
            clk_counter <= 0;
            msg_counter <= 0;
            fifo_clk_last <= 0;
            //  Cycle FIFO clock at reset
            if (reset_last)
                fifo_clk <= 0;
            else
                fifo_clk <= 1;
            fifo_data <= 0;
            reset_last <= 1;
        end
        else begin
            reset_last <= 0;
            clk_counter <= clk_counter + 1;
            
            //  Trigger the FIFO clock once in a while
            if (clk_counter == 127)
                fifo_clk <= fifo_clk + 1;
            
            //  When the FIFO clock is triggered, send 4 bytes of data to the FIFO.
            fifo_clk_last <= fifo_clk;
            if (((fifo_clk == 1) && (fifo_clk_last == 0)) || (msg_counter != 0)) 
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
            else begin
                fifo_write <= 0;
                fifo_data <= 0;
            end

        end
    end
    

endmodule

