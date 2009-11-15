module tb_lbr_sdr;

reg reset;
reg sys_clk;
reg IFCLK;
reg FLAGA;
reg FLAGB;
reg FLAGC;
reg FLAGD;
wire SLOE;
wire SLRD;
wire SLWR;
wire [1:0] FIFOADR;
wire PKTEND;
reg [7:0] FDI;
wire [7:0] FDO;
wire [7:0] LEDs;
wire [7:0] SS;
wire SCK;
wire MOSI;
reg MISO;
reg SCL_i;
reg SCL_o;
reg SDA_i;
reg SDA_o;
reg SCLK;
reg SDATA;
reg LR;
wire EN4V;
wire NRST;

initial begin
    $from_myhdl(
        reset,
        sys_clk,
        IFCLK,
        FLAGA,
        FLAGB,
        FLAGC,
        FLAGD,
        FDI,
        MISO,
        SCL_i,
        SCL_o,
        SDA_i,
        SDA_o,
        SCLK,
        SDATA,
        LR
    );
    $to_myhdl(
        SLOE,
        SLRD,
        SLWR,
        FIFOADR,
        PKTEND,
        FDO,
        LEDs,
        SS,
        SCK,
        MOSI,
        EN4V,
        NRST
    );
end

lbr_sdr dut(
    reset,
    sys_clk,
    IFCLK,
    FLAGA,
    FLAGB,
    FLAGC,
    FLAGD,
    SLOE,
    SLRD,
    SLWR,
    FIFOADR,
    PKTEND,
    FDI,
    FDO,
    LEDs,
    SS,
    SCK,
    MOSI,
    MISO,
    SCL_i,
    SCL_o,
    SDA_i,
    SDA_o,
    SCLK,
    SDATA,
    LR,
    EN4V,
    NRST
);

endmodule
