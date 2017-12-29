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

FIFOInterface #(.num_bits(48)) samples_a(sample_clk);
FIFOInterface #(.num_bits(48)) samples_b(sample_clk);
FIFOInterface #(.num_bits(48)) samples_c(sample_clk);
FIFOInterface #(.num_bits(48)) samples_d(sample_clk);

//  Audio receivers for 8-chan link
i2s_receiver dac_model_a(
    .sample_clk(sample_clk),
    .samples(samples_a),
    .bck(slotdata[0]),
    .lrck(slotdata[1]),
    .sdata(slotdata[2])
);
i2s_receiver dac_model_b(
    .sample_clk(sample_clk),
    .samples(samples_b),
    .bck(slotdata[0]),
    .lrck(slotdata[1]),
    .sdata(slotdata[3])
);
i2s_receiver dac_model_c(
    .sample_clk(sample_clk),
    .samples(samples_c),
    .bck(slotdata[0]),
    .lrck(slotdata[1]),
    .sdata(slotdata[4])
);
i2s_receiver dac_model_d(
    .sample_clk(sample_clk),
    .samples(samples_d),
    .bck(slotdata[0]),
    .lrck(slotdata[1]),
    .sdata(slotdata[5])
);

//  Serialize sample FIFOs of individual I2S receivers via round-robin

logic [1:0] rr_index;

always_comb begin
    samples.valid = 0;
    samples.data = 0;
    samples_a.ready = 0;
    samples_b.ready = 0;
    samples_c.ready = 0;
    samples_d.ready = 0;
    
    case (rr_index)
    0: begin
        samples.valid = samples_a.valid;
        samples.data = samples_a.data;
        samples_a.ready = samples.ready;
    end
    1: begin
        samples.valid = samples_b.valid;
        samples.data = samples_b.data;
        samples_b.ready = samples.ready;
    end
    2: begin
        samples.valid = samples_c.valid;
        samples.data = samples_c.data;
        samples_c.ready = samples.ready;
    end
    3: begin
        samples.valid = samples_d.valid;
        samples.data = samples_d.data;
        samples_d.ready = samples.ready;
    end
    endcase
end

always_ff @(posedge sample_clk) begin
    if (!reset_n) begin
        rr_index <= 0;
    end
    else begin
        if (samples.ready && samples.valid)
            rr_index <= rr_index + 1;
    end
end

endmodule
