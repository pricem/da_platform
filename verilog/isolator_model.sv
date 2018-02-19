`timescale 1ns / 1ps

/*
    This models the hardware on the isolator board, including some set of installed slots.
*/

module isolator_model(
    IsolatorInterface.isolator iso
);

//  Model the oscillators: 22.5792 MHz (clk0) and 24.576 MHz (clk1)
logic clk_en;
logic clk0;
logic clk1;
initial begin
    clk_en = 1; //  tried disabling to see what would happen.  It breaks everything.
    clk0 = 0;
    clk1 = 0;
end
always #22.1443 clk0 = !clk0;
always #20.345 clk1 = !clk1;
always_comb iso.mclk = clk_en && (iso.clksel ? clk1 : clk0);

//  Local signals and logic (74xx chips on isolator PCB)
logic [3:0] slot_dir;
logic [3:0] slot_chan;
logic [3:0] slot_hwflag;
logic [3:0] slot_hwcon;
logic [3:0] slot_cs_n;

logic [3:0] tmp1, tmp2;

//  Model transmission of hwcon and hwflag

serializer #(.launch_negedge(0)) dirchan_ser(
    .clk_ser(iso.sclk), 
    .data_ser(iso.dirchan), 
    .clk_par(iso.srclk), 
    .data_par({slot_chan, slot_dir})
);

serializer #(.launch_negedge(0)) hwflag_ser(
    .clk_ser(iso.sclk), 
    .data_ser(iso.hwflag), 
    .clk_par(iso.srclk), 
    .data_par({4'h0, slot_hwflag})
);

deserializer cs_n_deser(
    .clk_ser(iso.sclk), 
    .data_ser(iso.cs_n), 
    .clk_par(iso.srclk), 
    .data_par({tmp1, slot_cs_n})
);

deserializer hwcon_deser(
    .clk_ser(iso.sclk), 
    .data_ser(iso.hwcon), 
    .clk_par(iso.srclk), 
    .data_par({tmp2, slot_hwcon})
);


//  Connect some fake modules to the slots

logic sample_clk;
FIFOInterface #(.num_bits(48)) samples_loopback_1(sample_clk);
FIFOInterface #(.num_bits(48)) samples_loopback_2(sample_clk);
logic [2:0] sample_fifo_count;

fifo_sync #(.Nb(48)) sample_fifo(
	.clk(sample_clk), 
	.reset(!iso.reset_n),
	.in(samples_loopback_1.in),
	.out(samples_loopback_2.out),
	.count(sample_fifo_count)
);

always_comb sample_clk = iso.mclk;

//  Slot 0: DAC8
slot_model_dac8 slot0(
    .slotdata(iso.slotdata[5:0]),
    .mclk(iso.mclk),
    .sclk(iso.sclk),
    .cs_n(slot_cs_n[0]), 
    .miso(iso.miso), 
    .mosi(iso.mosi), 
    .dir(slot_dir[0]),
    .chan(slot_chan[0]),
    .hwcon(slot_hwcon[0]),
    .hwflag(slot_hwflag[0]),
    .srclk(iso.srclk),
    .srclk2(iso.srclk2),
    .reset_n(iso.reset_n),
    .sample_clk(sample_clk),
    .samples(samples_loopback_1.out)
);

//  Slot 1: ADC8
slot_model_adc8 slot1(
    .slotdata(iso.slotdata[11:6]),
    .mclk(iso.mclk),
    .sclk(iso.sclk),
    .cs_n(slot_cs_n[1]), 
    .miso(iso.miso), 
    .mosi(iso.mosi), 
    .dir(slot_dir[1]),
    .chan(slot_chan[1]),
    .hwcon(slot_hwcon[1]),
    .hwflag(slot_hwflag[1]),
    .srclk(iso.srclk),
    .srclk2(iso.srclk2),
    .reset_n(iso.reset_n),
    .sample_clk(sample_clk),
    .samples(samples_loopback_2.in)
);

//  Slot 2: empty

//  Slot 3: empty


task set_spi_mode(input int slot, input int address_bits, input int data_bits);

endtask


endmodule

