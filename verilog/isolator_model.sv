`timescale 1ns / 1ps

/*
    This models the hardware on the isolator board, including some set of installed slots.
*/

module isolator_model(
    IsolatorInterface.isolator iso
);

//  Model the oscillators: 11.2896 MHz (clk0) and 24.576 MHz (clk1)
initial begin
    iso.clk0 = 0;
    iso.clk1 = 0;
end
always #44.2885 iso.clk0 = !iso.clk0;
always #20.345 iso.clk1 = !iso.clk1;

//  Local signals and logic (74xx chips on isolator PCB)
logic [3:0] slot_dir;
logic [3:0] slot_chan;
logic [3:0] dmcs;
logic [3:0] amcs;
logic [3:0] aovfl;
logic [3:0] aovfr;
logic [3:0] clksel;
logic [3:0] slot_clk;

serializer dirchan_ser(
    .clk_ser(iso.mclk), .data_ser(iso.dirchan), .clk_par(iso.srclk), .data_par({slot_chan, slot_dir})
);

serializer aovf_ser(
    .clk_ser(iso.mclk), .data_ser(iso.aovf), .clk_par(iso.srclk), .data_par({aovfr[3], aovfl[3], aovfr[2], aovfl[2], aovfr[1], aovfl[1], aovfr[0], aovfl[0]})
);

deserializer dmcs_deser(
    .clk_ser(iso.mclk), .data_ser(iso.dmcs), .clk_par(iso.srclk), .data_par(dmcs)
);

deserializer amcs_deser(
    .clk_ser(iso.mclk), .data_ser(iso.amcs), .clk_par(iso.srclk), .data_par(amcs)
);

deserializer clksel_deser(
    .clk_ser(iso.mclk), .data_ser(iso.clksel), .clk_par(iso.srclk), .data_par(clksel)
);
assign slot_clk[0] = clksel[0] ? iso.clk1 : iso.clk0;
assign slot_clk[1] = clksel[1] ? iso.clk1 : iso.clk0;
assign slot_clk[2] = clksel[2] ? iso.clk1 : iso.clk0;
assign slot_clk[3] = clksel[3] ? iso.clk1 : iso.clk0;

//  Connect some fake modules to the slots

logic sample_clk;
FIFOInterface #(.num_bits(48)) samples_loopback(sample_clk);

always_comb sample_clk = iso.mclk;

//  Slot 0: ADC2
slot_model_adc2 adc2_model(
    .slotdata(iso.slotdata[5:0]),
    .clk(slot_clk[0]),
    .dmclk(iso.mclk),
    .dmcs(dmcs[0]), 
    .dmdi(iso.dmdi), 
    .dmdo(iso.dmdo), 
    .amclk(iso.mclk),
    .amcs(amcs[0]), 
    .amdi(iso.amdi), 
    .amdo(iso.amdo), 
    .dir(slot_dir[0]),
    .chan(slot_chan[0]),
    .hwcon(iso.acon[0]),
    .aovfl(aovfl[0]),
    .aovfr(aovfr[0]),
    .srclk(iso.srclk),
    .reset(iso.reset_out),
    .sample_clk(sample_clk),
    .samples(samples_loopback.in)
);
/*
//  Slot 1: DAC2
slot_model_dac2 dac2_model(
    .slotdata(iso.slotdata[11:6]),
    .clk(slot_clk[1]),
    .dmclk(iso.mclk),
    .dmcs(dmcs[1]), 
    .dmdi(iso.dmdi), 
    .dmdo(iso.dmdo), 
    .amclk(iso.mclk),
    .amcs(amcs[1]), 
    .amdi(iso.amdi), 
    .amdo(iso.amdo), 
    .dir(slot_dir[1]),
    .chan(slot_chan[1]),
    .hwcon(iso.acon[0]),
    .aovfl(aovfl[1]),
    .aovfr(aovfr[1]),
    .srclk(iso.srclk),
    .reset(iso.reset_out),
    .sample_clk(sample_clk),
    .samples(samples_loopback.out)
);
*/
//  Slot 1: DAC8
slot_model_dac8 dac8_model(
    .slotdata(iso.slotdata[11:6]),
    .clk(slot_clk[1]),
    .dmclk(iso.mclk),
    .dmcs(dmcs[1]), 
    .dmdi(iso.dmdi), 
    .dmdo(iso.dmdo), 
    .amclk(iso.mclk),
    .amcs(amcs[1]), 
    .amdi(iso.amdi), 
    .amdo(iso.amdo), 
    .dir(slot_dir[1]),
    .chan(slot_chan[1]),
    .hwcon(iso.acon[0]),
    .aovfl(aovfl[1]),
    .aovfr(aovfr[1]),
    .srclk(iso.srclk),
    .reset(iso.reset_out),
    .sample_clk(sample_clk),
    .samples(samples_loopback.out)
);

//  Slot 2: empty

//  Slot 3: empty


endmodule

