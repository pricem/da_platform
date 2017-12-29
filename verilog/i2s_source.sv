/*
    Testbench module only
    Sends audio data in I2S format. 
    I2S master (reflecting a limitation of the isolator board, which is that each slot data bus has to be all in the same direction).
*/

`timescale 1ns / 1ps


module i2s_source(
    //  Testbench input
    input logic reset,
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

FIFOInterface #(.num_bits(48)) samples_local(bck);

logic [2:0] count_in;
logic [2:0] count_out;
fifo_async #(.Nb(48), .M(2)) sample_fifo(
    .reset,
    .in(samples),
    .in_count(count_in),
    .out(samples_local.out),
    .out_count(count_out)
);

//  BCK/LRCK generator - 256 x Fs
logic [7:0] mclk_count;
always @(posedge i2s_master_clk) begin
    if (reset) begin
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
    
    if (samples_local.ready && samples_local.valid) begin
        {sample_left, sample_right} <= samples_local.data;
        $display("%t %m: loading I2S samples left = %h, right = %h", $time, samples_local.data[47:24], samples_local.data[23:0]);
    end
    
    if (left_not_right && (cycle_counter < 24))
        sdata <= sample_left[24 - cycle_counter - 1];
    if (!left_not_right && (cycle_counter < 24))
        sdata <= sample_right[24 - cycle_counter - 1];
    
end


endmodule

