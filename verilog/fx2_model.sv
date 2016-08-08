`timescale 1ns / 1ps

/*
    Simulation-only model of the FX2 microcontroller running the ZTEX default firmware.
    Note: PKTEND ignored, all data is immediately "committed"
        -> doesn't model details of USB protocol, which is packetized
*/

module fx2_model #(
    OUTEP = 2,
    INEP = 6
) (
    output logic ifclk,
    inout [15:0] fd,
    input SLWR, 
    input PKTEND,
    input SLRD, 
    input SLOE, 
    input [1:0] FIFOADDR,
    output logic EMPTY_FLAG,
    output logic FULL_FLAG,

    FIFOInterface.in in,
    FIFOInterface.out out
);

//  Generate clock - 48 MHz
initial ifclk = 0;
always #10.4166 ifclk <= !ifclk;

ClockReset cr_local ();
always_comb cr_local.clk = ifclk;
initial begin
    cr_local.reset = 1;
    @(posedge cr_local.clk) cr_local.reset = 0;
end    

FIFOInterface #(.num_bits(16)) in_local (ifclk);
FIFOInterface #(.num_bits(16)) out_local (ifclk);

//  FIFOs 
logic [9:0] in_count;
logic [9:0] out_count;
fifo_sync_sv #(.width(16), .depth(512)) in_fifo(
    .cr(cr_local),
    .in(in),
    .out(in_local),
    .count(in_count)
);
fifo_sync_sv #(.width(16), .depth(512)) out_fifo(
    .cr(cr_local),
    .in(out_local),
    .out(out),
    .count(out_count)
);

//  I/O duties
assign fd = SLOE ? 16'hZZZZ : in_local.data;
always_comb begin
    EMPTY_FLAG = (in_count == 0);
    FULL_FLAG = (out_count == 512);
    
    //  Only allow read/write if FIFO address is correct
    in_local.ready = (!SLRD && (FIFOADDR == INEP / 2 - 1));

    out_local.data = fd;
    out_local.enable = (!SLWR && (FIFOADDR == OUTEP / 2 - 1));

    //  Doesn't bother with PKTEND
end

//  Monitoring logic
always @(posedge ifclk) begin
    if (!SLWR && !out_local.ready) begin
        $display("%t %m: SLWR asserted but out FIFO is full", $time);
    end
end

endmodule


