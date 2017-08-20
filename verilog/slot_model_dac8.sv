/*
    Slot module with 30-pin interface.
*/

`timescale 1ns / 1ps


module slot_model_dac8(
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
    
    //  Testbench output
    input logic sample_clk,
    FIFOInterface.out samples
);

//  8-channel DAC
assign dir = 1;
assign chan = 1;

//  ADC stuff unused
assign hwflag = 0;

//  SPI interface
spi_slave #(
    .address_bits(16), 
    .data_bits(8)
) ctl_model(
    .clk(mclk), 
    .reset(!reset_n), 
    .sck(mclk), 
    .ss(cs_n), 
    .mosi(mosi), 
    .miso(miso)
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
