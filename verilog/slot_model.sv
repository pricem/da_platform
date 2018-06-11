/*
    Open-source digital audio platform
    Copyright (C) 2009--2018 Michael Price

    slot_model: Slot module with 30-pin interface for simulation only.
    This one is meant to switch at runtime between different modes
    to simplify testbenches.

    Warning: Use and distribution of this code is restricted.
    This HDL file is distributed under the terms of the Solderpad Hardware 
    License, Version 0.51.  Other files in this project may be subject to
    different licenses.  Please see the LICENSE file in the top level project
    directory for more information.
*/

`timescale 1ns / 1ps

`include "structures.sv"

module slot_model #(
    parameter SlotMode initial_mode = DAC2
) (
    inout [5:0] slotdata,
    input mclk,
    input sclk,
    input cs_n, 
    input mosi, 
    output miso, 
    output logic dir,
    output logic chan,
    input hwcon,
    output logic hwflag,
    input srclk,
    input srclk2,
    input reset_n,
    
    //  Testbench connections for audio samples
    input logic sample_clk,
    FIFOInterface.in samples_in[4],
    FIFOInterface.out samples_out[4]
);

logic [9:0] clk_divide_ratio;   //  for I2S sources

task set_mode(input int slot_mode);
    case (SlotMode'(slot_mode))
    DAC2: begin
        dir = 1;
        chan = 0;
    end
    DAC8: begin
        dir = 1;
        chan = 1;
    end
    ADC2: begin
        dir = 0;
        chan = 0;
    end
    ADC8: begin
        dir = 0;
        chan = 1;
    end
    endcase
endtask

task set_clock_divider(input logic [9:0] ratio);
    clk_divide_ratio = ratio;
endtask

initial begin
    clk_divide_ratio = 512;
    set_mode(initial_mode);
end

//  SPI interface
spi_slave spi(
    .clk(mclk), 
    .reset(!reset_n), 
    .sck(sclk), 
    .ss(cs_n), 
    .mosi(mosi), 
    .miso(miso)
);

//  HWCON deserializer
logic [7:0] hwcon_parallel;
deserializer hwcon_deser(
    .clk_ser(srclk), 
    .data_ser(hwcon),
    .clk_par(srclk2), 
    .data_par(hwcon_parallel)
);

//  HWFLAG serializer
logic [7:0] hwflag_parallel;
serializer hwflag_ser(
    .clk_ser(srclk), 
    .data_ser(hwflag),
    .clk_par(srclk2), 
    .data_par(hwflag_parallel)
);
initial begin
    hwflag_parallel = 0;
end

//  I2S source model, for ADC modes
wire bck_adc;
wire lrck_adc;
wire [3:0] sdata_adc;
assign slotdata[0] = dir ? 1'bz : bck_adc;
assign slotdata[1] = dir ? 1'bz : lrck_adc;
assign slotdata[2] = dir ? 1'bz : sdata_adc[0];
assign slotdata[3] = dir ? 1'bz : sdata_adc[1];
assign slotdata[4] = dir ? 1'bz : sdata_adc[2];
assign slotdata[5] = dir ? 1'bz : sdata_adc[3];

i2s_source adc_model_a(
    .enable(!dir),
    .clk_divide_ratio,
    .reset(!reset_n),
    .i2s_master_clk(mclk),
    .sample_clk(sample_clk),
    .samples(samples_in[0]),
    .bck(bck_adc),
    .lrck(lrck_adc),
    .sdata(sdata_adc[0])
);
i2s_source adc_model_b(
    .enable(!dir && chan),
    .clk_divide_ratio,
    .reset(!reset_n),
    .i2s_master_clk(mclk),
    .sample_clk(sample_clk),
    .samples(samples_in[1]),
    .bck(),
    .lrck(),
    .sdata(sdata_adc[1])
);
i2s_source adc_model_c(
    .enable(!dir && chan),
    .clk_divide_ratio,
    .reset(!reset_n),
    .i2s_master_clk(mclk),
    .sample_clk(sample_clk),
    .samples(samples_in[2]),
    .bck(),
    .lrck(),
    .sdata(sdata_adc[2])
);
i2s_source adc_model_d(
    .enable(!dir && chan),
    .clk_divide_ratio,
    .reset(!reset_n),
    .i2s_master_clk(mclk),
    .sample_clk(sample_clk),
    .samples(samples_in[3]),
    .bck(),
    .lrck(),
    .sdata(sdata_adc[3])
);

//  I2S receiver model, for DAC modes
i2s_receiver dac_model_a(
    .enable(dir),
    .sample_clk(sample_clk),
    .samples(samples_out[0]),
    .bck(slotdata[0]),
    .lrck(slotdata[1]),
    .sdata(slotdata[2])
);
i2s_receiver dac_model_b(
    .enable(dir && chan),
    .sample_clk(sample_clk),
    .samples(samples_out[1]),
    .bck(slotdata[0]),
    .lrck(slotdata[1]),
    .sdata(slotdata[3])
);
i2s_receiver dac_model_c(
    .enable(dir && chan),
    .sample_clk(sample_clk),
    .samples(samples_out[2]),
    .bck(slotdata[0]),
    .lrck(slotdata[1]),
    .sdata(slotdata[4])
);
i2s_receiver dac_model_d(
    .enable(dir && chan),
    .sample_clk(sample_clk),
    .samples(samples_out[3]),
    .bck(slotdata[0]),
    .lrck(slotdata[1]),
    .sdata(slotdata[5])
);

endmodule

