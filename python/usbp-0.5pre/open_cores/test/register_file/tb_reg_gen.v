module tb_reg_gen;

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

initial begin
    $from_myhdl(
        clk_i,
        rst_i,
        cyc_i,
        stb_i,
        adr_i,
        we_i,
        sel_i,
        dat_i
    );
    $to_myhdl(
        dat_o,
        ack_o
    );
end

reg_gen dut(
    clk_i,
    rst_i,
    cyc_i,
    stb_i,
    adr_i,
    we_i,
    sel_i,
    dat_i,
    dat_o,
    ack_o
);

endmodule
