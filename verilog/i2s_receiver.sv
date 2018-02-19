/*
    I2S receiver model - simulation only.
    Detects audio samples present on I2S bus and sends them out via FIFO. 
    Prints notifications when audio samples are received in I2S format. 
*/

`timescale 1ns / 1ps


module i2s_receiver(
    input logic enable,
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
fifo_async #(.Nb(48), .M(2)) sample_fifo(
    .reset(reset_bck),
    .in(samples_local.in),
    .in_count(count_in),
    .out(samples),
    .out_count(count_out)
);

int cycle_counter;
logic lrck_last;

logic [23:0] sample_left;
logic [23:0] sample_right;

logic left_not_right;

logic debug_display;
initial begin
    debug_display = 0;
end

always @(posedge bck) begin
    lrck_last <= lrck;
    
    samples_local.valid <= 0;

    if (enable) begin

        if (lrck && !lrck_last) begin
            cycle_counter <= 0;
            sample_right <= 0;
            left_not_right <= 0;
        end
        else if (!lrck && lrck_last) begin
            cycle_counter <= 0;
            sample_left <= 0;
            left_not_right <= 1;
            if (debug_display)
                $display("%t %m: received I2S samples left = %h, right = %h", $time, sample_left, sample_right);
            samples_local.valid <= 1;
            samples_local.data <= {sample_left, sample_right};
        end
        else
            cycle_counter <= cycle_counter + 1;

        if (left_not_right && (cycle_counter < 24))
            sample_left <= {sample_left, sdata};
        if (!left_not_right && (cycle_counter < 24))
            sample_right <= {sample_right, sdata};  

    end

end


endmodule
