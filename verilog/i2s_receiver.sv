/*
    Testbench module only
    Prints notifications when audio samples are received in I2S format. 
    TODO: Add a FIFO output of the samples for testability.
*/

`timescale 1ns / 1ps


module i2s_receiver(
    //  Testbench output
    input logic sample_clk,
    FIFOInterface.out samples,
    //  I2S port
    input logic bck,
    input logic lrck,
    input logic sdata
);

logic reset_bck;
logic reset_sck;
initial begin
    reset_bck <= 1;
    @(posedge bck) #10 reset_bck <= 0;
end
initial begin
    reset_sck <= 1;
    @(posedge sample_clk) reset_sck <= 0;
end

FIFOInterface #(.num_bits(48)) samples_local(bck);

logic [2:0] count_in;
logic [2:0] count_out;
fifo_async_sv2 #(.width(48), .depth(4), .debug_display(1)) sample_fifo(
    .clk_in(bck),
    .reset_in(reset_bck),
    .in(samples_local.in),
    .count_in(count_in),
    .clk_out(sample_clk),
    .reset_out(reset_sck),
    .out(samples),
    .count_out(count_out)
);

int cycle_counter;
logic lrck_last;

logic [23:0] sample_left;
logic [23:0] sample_right;

logic left_not_right;

always @(posedge bck) begin
    lrck_last <= lrck;
    
    samples_local.enable <= 0;
    
    if (lrck && !lrck_last) begin
        cycle_counter <= 0;
        sample_right <= 0;
        left_not_right <= 0;
    end
    else if (!lrck && lrck_last) begin
        cycle_counter <= 0;
        sample_left <= 0;
        left_not_right <= 1;
        $display("%t %m: received I2S samples left = %h, right = %h", $time, sample_left, sample_right);
        samples_local.enable <= 1;
        samples_local.data <= {sample_left, sample_right};
    end
    else
        cycle_counter <= cycle_counter + 1;
        
    if (left_not_right && (cycle_counter < 24))
        sample_left <= {sample_left, sdata};
    if (!left_not_right && (cycle_counter < 24))
        sample_right <= {sample_right, sdata};  
    
end


endmodule
