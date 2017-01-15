/*
    Slot module with 30-pin interface.
*/

`timescale 1ns / 1ps


module slot_model_adc2(
    inout [5:0] slotdata,
    input clk,
    input dmclk,
    input dmcs, 
    input dmdi, 
    output dmdo, 
    input amclk,
    input amcs, 
    input amdi, 
    output amdo, 
    output dir,
    output chan,
    input hwcon,
    output aovfl,
    output aovfr,
    input srclk,
    input reset,
    
    //  Testbench input
    input logic sample_clk,
    FIFOInterface.in samples
);

//  2-channel ADC
assign dir = 0;
assign chan = 0;

//  DAC stuff unused
assign dmdo = 0;

assign aovfl = 0;
assign aovfr = 0;

//  SPI interface
spi_slave #(
   .address_bits(8), 
   .data_bits(8)
) ctl_model(
    .clk(clk), 
    .reset(!reset), 
    .sck(amclk), 
    .ss(amcs), 
    .mosi(amdi), 
    .miso(amdo)
);

//  Audio generator (stereo... make 8-ch ones later)
//  Pin mapping matches initial version of ADC2 board with PCM4202
i2s_source adc_model(
    .i2s_master_clk(clk),
    .sample_clk(sample_clk),
    .samples(samples),
    .bck(slotdata[1]),
    .lrck(slotdata[0]),
    .sdata(slotdata[2])
);

endmodule

