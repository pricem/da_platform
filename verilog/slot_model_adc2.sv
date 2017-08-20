/*
    Slot module with 30-pin interface.
*/

`timescale 1ns / 1ps


module slot_model_adc2(
    inout [5:0] slotdata,
    input mclk,
    input sclk,
    input cs_n, 
    input mosi, 
    output miso, 
    output dir,
    output chan,
    input hwcon,
    output hwflag,
    input srclk,
    input srclk2,
    input reset_n,
    
    //  Testbench input
    input logic sample_clk,
    FIFOInterface.in samples
);

//  2-channel ADC
assign dir = 0;
assign chan = 0;
assign hwflag = 0;

//  SPI interface
spi_slave #(
   .address_bits(8), 
   .data_bits(8)
) ctl_model(
    .clk(mclk), 
    .reset(!reset_n), 
    .sck(sclk), 
    .ss(cs_n), 
    .mosi(mosi), 
    .miso(miso)
);

//  Audio generator (stereo... make 8-ch ones later)
//  Pin mapping matches initial version of ADC2 board with PCM4202
i2s_source adc_model(
    .i2s_master_clk(mclk),
    .sample_clk(sample_clk),
    .samples(samples),
    .bck(slotdata[1]),
    .lrck(slotdata[0]),
    .sdata(slotdata[2])
);

endmodule

