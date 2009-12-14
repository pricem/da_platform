//  A dummy module for a nonexistent DAC.

module dummy_dac(
    //  FIFO connection
    fifo_clk, fifo_data, fifo_read, fifo_addr_in, fifo_addr_out,
    //  FX2 data port
    slot_data, direction, channels,
    //  Control
    clk, reset
    );
    
    output reg fifo_clk;
    input [7:0] fifo_data;
    output reg fifo_read;
    input [10:0] fifo_addr_in;
    input [10:0] fifo_addr_out;
    
    output [5:0] slot_data;
    input direction;
    input channels;
    
    input clk;
    input reset;
    
    //  100 MHz input clk / 256 = 400 kHz
    reg [5:0] data_out;
    reg [7:0] clk_counter;
    reg [1:0] msg_counter;
    reg fifo_clk_last;

    //  Keep reset around so you can cycle FIFO clock at reset
    reg reset_last;
    
    //  Tristate outputs
    assign slot_data = (direction == 0) ? data_out : 6'hZZ;
    
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
            data_out <= 0;
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
            if (((fifo_clk == 1) && (fifo_clk_last == 0)) || (msg_counter != 0)) begin
                msg_counter <= msg_counter + 1;
                fifo_read <= 1;
            end
            else
                fifo_read <= 0;
            
            //  Copy the data over when possible.
            if (fifo_read)
                data_out <= fifo_data[5:0];

        end
    end
    
    
endmodule

