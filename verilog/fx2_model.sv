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
    input reset,

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
//  8/8/2016: round frequency up since this is eventually going to a MIG, and it is very sensitive in simulation
//  in reality, half-period should be 10.41666... ns
always #10.4 ifclk <= !ifclk;

//  Generate outputs from a slightly delayed clock.
//  This prevents confusing simulation results relating to clock/data edge sequencing
//  (which are caused by the ezusb_io module having its own PLL).
wire #1 ifclk_delayed = ifclk;

FIFOInterface #(.num_bits(16)) in_local (ifclk_delayed);
FIFOInterface #(.num_bits(16)) out_local (ifclk_delayed);

//  FIFOs 
logic [9:0] in_count;
logic [9:0] out_count;
fifo_sync #(.Nb(16), .M(9)) in_fifo(
    .reset,
    .clk(ifclk_delayed),
    .in(in),
    .out(in_local),
    .count(in_count)
);
fifo_sync #(.Nb(16), .M(9)) out_fifo(
    .reset,
    .clk(ifclk_delayed),
    .in(out_local),
    .out(out),
    .count(out_count)
);

logic [15:0] data_buf;
logic data_pending;
logic data_pending_last;
logic empty_next;
logic enable_last;

//  I/O duties
assign fd = SLOE ? 16'hZZZZ : data_buf;
always_comb begin
    //  Active-low flags
    empty_next = !((in_count == 0));
    FULL_FLAG = !(out_count == 512);
    
    //  Only allow read/write if FIFO address is correct
    //  EMPTY_FLAG = !((in_count == 0));
    data_buf = in_local.data;
    in_local.ready = (!SLRD && (FIFOADDR == INEP / 2 - 1)) && !data_pending;

    out_local.data = fd;
    out_local.valid = (!SLWR && (FIFOADDR == OUTEP / 2 - 1));

    //  Doesn't bother with PKTEND
end

//  Monitoring logic
always @(posedge ifclk_delayed) begin
    if (reset) begin 
        data_pending <= 0;
        data_pending_last <= 0;
        enable_last <= 0;
        EMPTY_FLAG <= 0;
    end
    else begin
        data_pending_last <= data_pending;
        enable_last <= in_local.valid && in_local.ready;
        EMPTY_FLAG <= empty_next;
        if (!SLRD) begin
            data_pending <= 0;
            /*
            if (!data_pending)
                data_buf <= in_local.data;
            */
        end
        else if (enable_last)
            data_pending <= 1; 
        
        if (!SLWR && !out_local.ready) begin
            $display("%t %m: SLWR asserted but out FIFO is full", $time);
        end
    end
end

endmodule


