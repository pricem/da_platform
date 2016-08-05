/*
    Slot module with 30-pin interface.
*/

`timescale 1ns / 1ps


module slot_model_dac2(
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
    input reset
);

//  2-channel DAC
assign dir = 1;
assign chan = 0;

//  ADC stuff unused
assign amdo = 0;
assign aovfl = 0;
assign aovfr = 0;

//  SPI interface
spi_slave ctl_model(
    .clk(clk), 
    .reset(reset), 
    .sck(dmclk), 
    .ss(dmcs), 
    .mosi(dmdi), 
    .miso(dmdo)
);

//  Audio receiver (stereo... make 8-ch ones later)
i2s_receiver dac_model(
    .bck(slotdata[5]),
    .lrck(slotdata[3]),
    .sdata(slotdata[4])
);

endmodule
