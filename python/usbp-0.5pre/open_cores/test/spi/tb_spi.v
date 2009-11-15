module tb_spi;

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
wire [7:0] fifo_di;
reg [7:0] fifo_do;
reg fifo_do_vld;
wire fifo_rd;
wire fifo_wr;
reg fifo_full;
reg fifo_empty;
wire [7:0] SS;
wire SCK;
wire MOSI;
reg MISO;

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
        fifo_do,
        fifo_do_vld,
        fifo_full,
        fifo_empty,
        MISO
    );
    $to_myhdl(
        dat_o,
        ack_o,
        fifo_di,
        fifo_rd,
        fifo_wr,
        SS,
        SCK,
        MOSI
    );
end

spi dut(
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
    SS,
    SCK,
    MOSI,
    MISO
);

endmodule
