/*
    Slot module with 30-pin interface.
*/

`timescale 1ns / 1ps


module slot_model_dac8(
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
    
    //  Testbench output
    input logic sample_clk,
    FIFOInterface.out samples
);

//  8-channel DAC
assign dir = 1;
assign chan = 1;

//  ADC stuff unused
assign amdo = 0;
assign aovfl = 0;
assign aovfr = 0;

//  SPI interface
spi_slave #(
    .address_bits(16), 
    .data_bits(8)
) ctl_model(
    .clk(clk), 
    .reset(!reset), 
    .sck(dmclk), 
    .ss(dmcs), 
    .mosi(dmdi), 
    .miso(dmdo)
);

FIFOInterface samples_a(sample_clk);
FIFOInterface samples_b(sample_clk);
FIFOInterface samples_c(sample_clk);
FIFOInterface samples_d(sample_clk);

//  Audio receivers for 8-chan link
i2s_receiver dac_model_a(
    .sample_clk(sample_clk),
    .samples(samples_a),
    .bck(slotdata[4]),
    .lrck(slotdata[5]),
    .sdata(slotdata[3])
);
i2s_receiver dac_model_b(
    .sample_clk(sample_clk),
    .samples(samples_b),
    .bck(slotdata[4]),
    .lrck(slotdata[5]),
    .sdata(slotdata[2])
);
i2s_receiver dac_model_c(
    .sample_clk(sample_clk),
    .samples(samples_c),
    .bck(slotdata[4]),
    .lrck(slotdata[5]),
    .sdata(slotdata[1])
);
i2s_receiver dac_model_d(
    .sample_clk(sample_clk),
    .samples(samples_d),
    .bck(slotdata[4]),
    .lrck(slotdata[5]),
    .sdata(slotdata[0])
);

//  TODO: Actually serialize sample FIFOs via round-robin
//  Right now we just discard all samples
always_comb begin
    samples.enable = 0;
    samples.data = 0;
    samples_a.ready = 1;
    samples_b.ready = 1;
    samples_c.ready = 1;
    samples_d.ready = 1;
end

endmodule
