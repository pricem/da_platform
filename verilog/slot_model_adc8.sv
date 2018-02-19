/*
    Slot module with 30-pin interface.
*/

`timescale 1ns / 1ps


module slot_model_adc8(
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

//  8-channel ADC
assign dir = 0;
assign chan = 1;
assign hwflag = 0;

//  SPI interface
spi_slave #(
   .max_addr_bits(8), 
   .max_data_bits(8)
) ctl_model(
    .clk(mclk), 
    .reset(!reset_n), 
    .sck(sclk), 
    .ss(cs_n), 
    .mosi(mosi), 
    .miso(miso)
);

//  Deserialize samples
logic [1:0] rr_index;
FIFOInterface #(.num_bits(48)) samples_a(sample_clk);
FIFOInterface #(.num_bits(48)) samples_b(sample_clk);
FIFOInterface #(.num_bits(48)) samples_c(sample_clk);
FIFOInterface #(.num_bits(48)) samples_d(sample_clk);

always_comb begin
    samples.ready = 0;
    
    samples_a.data = 0;
    samples_a.valid = 0;
    samples_b.data = 0;
    samples_b.valid = 0;
    samples_c.data = 0;
    samples_c.valid = 0;
    samples_d.data = 0;
    samples_d.valid = 0;
    
    case (rr_index)
    0: begin
        samples.ready = samples_a.ready;
        samples_a.data = samples.data;
        samples_a.valid = samples.valid;
    end
    1: begin
        samples.ready = samples_b.ready;
        samples_b.data = samples.data;
        samples_b.valid = samples.valid;
    end
    2: begin
        samples.ready = samples_c.ready;
        samples_c.data = samples.data;
        samples_c.valid = samples.valid;
    end
    3: begin
        samples.ready = samples_d.ready;
        samples_d.data = samples.data;
        samples_d.valid = samples.valid;
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


//  Audio generator (stereo... make 8-ch ones later)
//  Pin mapping matches initial version of ADC2 board with PCM4202
i2s_source adc1_model(
    .reset(!reset_n),
    .i2s_master_clk(mclk),
    .sample_clk(sample_clk),
    .samples(samples_a),
    .bck(slotdata[0]),
    .lrck(slotdata[1]),
    .sdata(slotdata[2])
);
i2s_source adc2_model(
    .reset(!reset_n),
    .i2s_master_clk(mclk),
    .sample_clk(sample_clk),
    .samples(samples_b),
    .bck(),
    .lrck(),
    .sdata(slotdata[3])
);
i2s_source adc3_model(
    .reset(!reset_n),
    .i2s_master_clk(mclk),
    .sample_clk(sample_clk),
    .samples(samples_c),
    .bck(),
    .lrck(),
    .sdata(slotdata[4])
);
i2s_source adc4_model(
    .reset(!reset_n),
    .i2s_master_clk(mclk),
    .sample_clk(sample_clk),
    .samples(samples_d),
    .bck(),
    .lrck(),
    .sdata(slotdata[5])
);

endmodule

