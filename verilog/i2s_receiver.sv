/*
    Testbench module only
    Prints notifications when audio samples are received in I2S format. 
    TODO: Add a FIFO output of the samples for testability.
*/

`timescale 1ns / 1ps


module i2s_receiver(
    input logic bck,
    input logic lrck,
    input logic sdata
);

int cycle_counter;
logic lrck_last;

logic [23:0] sample_left;
logic [23:0] sample_right;

logic left_not_right;

always @(posedge bck) begin
    lrck_last <= lrck;
    if (lrck && !lrck_last) begin
        cycle_counter <= 0;
        sample_right <= 0;
        left_not_right <= 0;
    end
    else if (!lrck && lrck_last) begin
        cycle_counter <= 0;
        sample_left <= 0;
        left_not_right <= 1;
        $display("%t %m: I2S samples left = %h, right = %h", $time, sample_left, sample_right);
    end
    else
        cycle_counter <= cycle_counter + 1;
        
    if (left_not_right && (cycle_counter < 24))
        sample_left <= {sample_left, sdata};
    if (!left_not_right && (cycle_counter < 24))
        sample_right <= {sample_right, sdata};  
    
end


endmodule
