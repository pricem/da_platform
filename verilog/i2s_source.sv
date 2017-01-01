/*
    Testbench module only
    Sends audio data in I2S format. 
    I2S master (reflecting a limitation of the isolator board, which is that each slot data bus has to be all in the same direction).
*/

`timescale 1ns / 1ps


module i2s_source(
    //  Testbench input
    input logic sample_clk,
    FIFOInterface.in samples,
    //  I2S port
    input logic i2s_master_clk,
    output logic bck,
    output logic lrck,
    output logic sdata
);

int cycle_counter;
logic lrck_last;

logic [23:0] sample_left;
logic [23:0] sample_right;

logic left_not_right;

logic reset_mck;
logic reset_sck;
logic reset_bck;
initial begin
    reset_mck <= 1;
    @(posedge i2s_master_clk) reset_mck <= 0;
end
initial begin
    reset_sck <= 1;
    @(posedge sample_clk) reset_sck <= 0;
end
initial begin
    reset_bck <= 1;
    @(negedge bck) reset_bck <= 0;
end

FIFOInterface #(.num_bits(48)) samples_local(bck);

logic [2:0] count_in;
logic [2:0] count_out;
fifo_async_sv2 #(.width(48), .depth(4)) sample_fifo(
    .clk_in(sample_clk),
    .reset_in(reset_sck),
    .in(samples),
    .count_in(count_in),
    .clk_out(!bck),
    .reset_out(reset_bck),
    .out(samples_local.out),
    .count_out(count_out)
);

//  BCK/LRCK generator - 256 x Fs
logic [7:0] mclk_count;
always @(posedge i2s_master_clk) begin
    if (reset_mck) begin
        mclk_count <= 0;
        bck <= 0;
        lrck <= 0;
    end
    else begin
        mclk_count <= mclk_count + 1;
        bck <= mclk_count[1];
        lrck <= mclk_count[7];
    end
end

always @(negedge bck) begin
    lrck_last <= lrck;
    sdata <= 0;
    samples_local.ready <= 0;
    if (lrck && !lrck_last) begin
        cycle_counter <= 0;
        left_not_right <= 0;
    end
    else if (!lrck && lrck_last) begin
        cycle_counter <= 0;
        left_not_right <= 1;
    end
    else
        cycle_counter <= cycle_counter + 1;
    
    if (lrck && (cycle_counter == 30))
        samples_local.ready <= 1;
    
    if (samples_local.ready && samples_local.enable) begin
        {sample_left, sample_right} <= samples_local.data;
        $display("%t %m: loading I2S samples left = %h, right = %h", $time, samples_local.data[47:24], samples_local.data[23:0]);
    end
    
    if (left_not_right && (cycle_counter < 24))
        sdata <= sample_left[24 - cycle_counter - 1];
    if (!left_not_right && (cycle_counter < 24))
        sdata <= sample_right[24 - cycle_counter - 1];
    
end


endmodule

