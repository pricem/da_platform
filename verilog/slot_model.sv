/*
    Slot module with 30-pin interface for simulation only.
    This one is meant to switch at runtime between different modes
    to simplify testbenches.
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

task set_mode(input SlotMode slot_mode);
    case (slot_mode)
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

initial begin
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
i2s_source adc_model_a(
    .enable(!dir),
    .reset(!reset_n),
    .i2s_master_clk(mclk),
    .sample_clk(sample_clk),
    .samples(samples_in[0]),
    .bck(slotdata[0]),
    .lrck(slotdata[1]),
    .sdata(slotdata[2])
);
i2s_source adc_model_b(
    .enable(!dir && chan),
    .reset(!reset_n),
    .i2s_master_clk(mclk),
    .sample_clk(sample_clk),
    .samples(samples_in[1]),
    .bck(),
    .lrck(),
    .sdata(slotdata[3])
);
i2s_source adc_model_c(
    .enable(!dir && chan),
    .reset(!reset_n),
    .i2s_master_clk(mclk),
    .sample_clk(sample_clk),
    .samples(samples_in[2]),
    .bck(),
    .lrck(),
    .sdata(slotdata[4])
);
i2s_source adc_model_d(
    .enable(!dir && chan),
    .reset(!reset_n),
    .i2s_master_clk(mclk),
    .sample_clk(sample_clk),
    .samples(samples_in[3]),
    .bck(),
    .lrck(),
    .sdata(slotdata[5])
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

