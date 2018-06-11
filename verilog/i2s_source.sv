/*
    Open-source digital audio platform
    Copyright (C) 2009--2018 Michael Price

    i2s_source: Sends audio data in I2S format. Testbench module only.

    Warning: Use and distribution of this code is restricted.
    This HDL file is distributed under the terms of the Solderpad Hardware 
    License, Version 0.51.  Other files in this project may be subject to
    different licenses.  Please see the LICENSE file in the top level project
    directory for more information.
*/

`timescale 1ns / 1ps

module i2s_source(
    input logic enable,
    input logic [9:0] clk_divide_ratio,
    
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

logic reset_int;
logic left_not_right;

FIFOInterface #(.num_bits(48)) samples_local(bck);

logic debug_display;
initial begin
    debug_display = 0;
end

logic [2:0] count_in;
logic [2:0] count_out;
fifo_async #(.Nb(48), .M(2)) sample_fifo(
    .reset(reset_int),
    .in(samples),
    .in_count(count_in),
    .out(samples_local.out),
    .out_count(count_out)
);

//  Reset synchronizer - synchronize to BCK so FIFO can properly initialize
always_ff @(posedge bck or posedge reset) begin
    if (reset)
        reset_int <= 1;
    else
        reset_int <= 0;
end

//  BCK/LRCK generator - adjustable for 128--512 * Fs
logic [9:0] mclk_count;
always @(posedge i2s_master_clk) begin
    if (reset) begin
        mclk_count <= 0;
        bck <= 0;
        lrck <= 0;
    end
    else begin
        if (mclk_count < clk_divide_ratio - 1)
            mclk_count <= mclk_count + 1;
        else
            mclk_count <= 0;
        bck <= mclk_count / (clk_divide_ratio >> 7);
        lrck <= (mclk_count >= (clk_divide_ratio >> 1));
    end
end

always @(negedge bck) begin
    lrck_last <= lrck;
    sdata <= 0;
    samples_local.ready <= 0;
    if (enable) begin
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
            if (debug_display)
                $display("%t %m: loading I2S samples left = %h, right = %h", $time, samples_local.data[47:24], samples_local.data[23:0]);
        end

        if (left_not_right && (cycle_counter < 24))
            sdata <= sample_left[24 - cycle_counter - 1];
        if (!left_not_right && (cycle_counter < 24))
            sdata <= sample_right[24 - cycle_counter - 1];
    end
end


endmodule

