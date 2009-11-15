module tb_twi;

reg clk_i;
reg rst_i;
reg cyc_i;
reg stb_i;
reg [15:0] adr_i;
reg we_i;
reg sel_i;
reg [7:0] dat_i;
wire [7:0] dat_o;
wire ack_o;
reg [7:0] fifo_di;
reg [7:0] fifo_do;
reg fifo_do_vld;
reg fifo_rd;
reg fifo_wr;
reg fifo_full;
reg fifo_empty;
reg scl_pad_i;
reg scl_pad_o;
reg sda_pad_i;
reg sda_pad_o;

initial begin
    $from_myhdl(
        clk_i,
        rst_i,
        cyc_i,
        stb_i,
        adr_i,
        we_i,
        sel_i,
        dat_i,
        fifo_di,
        fifo_do,
        fifo_do_vld,
        fifo_rd,
        fifo_wr,
        fifo_full,
        fifo_empty,
        scl_pad_i,
        scl_pad_o,
        sda_pad_i,
        sda_pad_o
    );
    $to_myhdl(
        dat_o,
        ack_o
    );
end

twi dut(
    clk_i,
    rst_i,
    cyc_i,
    stb_i,
    adr_i,
    we_i,
    sel_i,
    dat_i,
    dat_o,
    ack_o,
    fifo_di,
    fifo_do,
    fifo_do_vld,
    fifo_rd,
    fifo_wr,
    fifo_full,
    fifo_empty,
    scl_pad_i,
    scl_pad_o,
    sda_pad_i,
    sda_pad_o
);

endmodule
