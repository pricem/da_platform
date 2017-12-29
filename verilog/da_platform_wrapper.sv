`timescale 1ns / 1ps

/*
    Adapts generic interfaces of da_platform to the physical interfaces (DDR3 memory, FX2 USB interface) on ZTEX FPGA module 2.13.
*/

module da_platform_wrapper #(
    host_width = 16,
    mem_width = 32,
    sclk_ratio = 8,
    num_slots = 4
) (
    //  ZTEX global inputs
    input fxclk_in,
    input ifclk_in,
    input reset,

    //  DDR3 memory interface
	inout [15:0] ddr3_dq,
	inout [1:0] ddr3_dqs_n,
	inout [1:0] ddr3_dqs_p,
	output [13:0] ddr3_addr,
	output [2:0] ddr3_ba,
	output ddr3_ras_n,
	output ddr3_cas_n,
	output ddr3_we_n,
    output ddr3_reset_n,
    output [0:0] ddr3_ck_p,
    output [0:0] ddr3_ck_n,
    output [0:0] ddr3_cke,
    output [1:0] ddr3_dm,
    output [0:0] ddr3_odt,
    
    //  FX2 host interface
    inout [15:0] fx2_fd,
    output fx2_slwr, 
    output fx2_slrd,
    output fx2_sloe, 
    output fx2_fifoaddr0, 
    output fx2_fifoaddr1, 
    output fx2_pktend,
    input fx2_flaga, 
    input fx2_flagb,

    //  Interface to isolator board
    (* keep = "true" *) IsolatorInterface.fpga iso,
    
    //  Other
    output [3:0] led_debug
);

//  Interfaces
logic clk_mem;
FIFOInterface #(.num_bits(65)) mem_cmd(clk_mem);
FIFOInterface #(.num_bits(mem_width)) mem_write(clk_mem);
FIFOInterface #(.num_bits(mem_width)) mem_read(clk_mem);

logic clk_host;
FIFOInterface #(.num_bits(host_width)) host_in(clk_host);
FIFOInterface #(.num_bits(host_width)) host_out(clk_host);

wire reset_usb;
wire [3:0] usb_status;

wire ifclk;
wire fxclk;

wire uiclk;
wire ui_clk_sync_rst;

always_comb begin
    clk_mem = uiclk;
    //  cr_mem.reset = ui_clk_sync_rst;
    clk_host = ifclk;
end

//  Core
da_platform #(
    .host_width(host_width),
    .mem_width(mem_width),
    .sclk_ratio(sclk_ratio),
    .num_slots(num_slots)
) main(
    .reset(reset_usb),
    .clk_host,
    .clk_mem,
    .mem_cmd(mem_cmd.out),
    .mem_write(mem_write.out),
    .mem_read(mem_read.in),
    .host_in(host_in.in),
    .host_out(host_out.out),
    .iso(iso),
    .led_debug(led_debug)
);

//  Host adapter
ezusb_io #(
    .OUTEP(2),
    .INEP(6),
    .TARGET("A7")
) ezusb_io_inst (
    .ifclk(ifclk),
    .reset(reset),
    .reset_out(reset_usb),
    .ifclk_in(ifclk_in),
    .fd(fx2_fd),
    .SLWR(fx2_slwr),
    .SLRD(fx2_slrd),
    .SLOE(fx2_sloe), 
    .PKTEND(fx2_pktend),
    .FIFOADDR({fx2_fifoaddr1, fx2_fifoaddr0}), 
    .EMPTY_FLAG(fx2_flaga),
    .FULL_FLAG(fx2_flagb),
    .DI(host_out.data),
    .DI_valid(host_out.valid),
    .DI_ready(host_out.ready),
    .DI_enable(1'b1),
    //  1/1/2017: Reduce timeout from 100 ms to minimum (1.3 ms) in order to reduce latency.
    //  Consider modifying ezusb_io.v to reduce further.
    //  .pktend_timeout(16'd73),
    .pktend_timeout(16'h01),
    .DO(host_in.data),
    .DO_valid(host_in.valid),
    .DO_ready(host_in.ready),
    .status(usb_status)	
);

//  MIG interfaces
wire [27:0] app_addr;
wire [2:0] app_cmd;
wire app_en;
wire app_wdf_wren;
wire app_rdy;
wire app_wdf_rdy;
wire app_wdf_end;
wire app_rd_data_valid;
wire app_rd_data_end;
wire [127:0] app_wdf_data;
wire [15:0] app_wdf_mask;
wire [127:0] app_rd_data;

wire clk200_in;
wire clk200;
wire clk400_in;
wire clk400;

wire init_calib_complete;

//  Clock generation
BUFG fxclk_buf (
    .I(fxclk_in),
    .O(fxclk) 
);

BUFG clk200_buf (  		// sometimes it is generated automatically, sometimes not ...
    .I(clk200_in),
    .O(clk200) 
);

BUFG clk400_buf (
    .I(clk400_in),
    .O(clk400) 
);

wire pll_fb;
PLLE2_BASE #(
	.BANDWIDTH("LOW"),
  	.CLKFBOUT_MULT(25),       // f_VCO = 1200 MHz (valid: 800 .. 1600 MHz)
  	.CLKFBOUT_PHASE(0.0),
  	.CLKIN1_PERIOD(20.832),
  	.CLKOUT0_DIVIDE(3),	// 400 MHz
  	.CLKOUT1_DIVIDE(6),	// 200 MHz
  	.CLKOUT0_DUTY_CYCLE(0.5),
  	.CLKOUT1_DUTY_CYCLE(0.5),
  	.CLKOUT0_PHASE(0.0),
  	.CLKOUT1_PHASE(0.0),
  	.DIVCLK_DIVIDE(1),
  	.REF_JITTER1(0.0),
  	.STARTUP_WAIT("FALSE")
)
dram_fifo_pll_inst (
  	.CLKIN1(fxclk),
  	.CLKOUT0(clk400_in),
  	.CLKOUT1(clk200_in),    
  	.CLKFBOUT(pll_fb),
  	.CLKFBIN(pll_fb),
  	.PWRDWN(1'b0),
  	.RST(1'b0)
);

//  Memory adapter (MIG)
MIGAdapter #(
    .addr_width(28),
    .data_width(128),
    .interface_width(32),
    .DDR3_BURST_LENGTH(8),
    .nCK_PER_CLK(4)
) mig_adapter(
    .clk(clk_mem),
    .reset,
    .ext_mem_cmd(mem_cmd.in),
    .ext_mem_write(mem_write.in),
    .ext_mem_read(mem_read.out),
    .mig_clk(uiclk),
    .mig_reset(ui_clk_sync_rst),
    .mig_init_done(init_calib_complete),
    .mig_af_rdy(app_rdy),
    .mig_af_wr_en(app_en),
    .mig_af_addr(app_addr),
    .mig_af_cmd(app_cmd),
    .mig_wdf_rdy(app_wdf_rdy),
    .mig_wdf_wr_en(app_wdf_wren),
    .mig_wdf_data(app_wdf_data),
    .mig_wdf_last(app_wdf_end),
    .mig_wdf_mask(app_wdf_mask),
    .mig_read_data_valid(app_rd_data_valid),
    .mig_read_data_last(app_rd_data_end),
    .mig_read_data(app_rd_data)
);

//  MIG instantiation
//  In simulation mode, use MIG model instead.
`ifdef USE_MIG_MODEL


//  Sim: reset latch, since UI clk doesn't start up until after reset is done
logic mig_model_reset;
initial begin
    mig_model_reset = 1;
    #1000 mig_model_reset = 0;
end

//  MIG model
mig_ddr3_model #(
    .BANK_WIDTH(3),
    .COL_WIDTH(10),
    .ROW_WIDTH(15),
    .BURST_LEN(1),	                //	not the same as the memory's actual burst length... just set to get right number of cycles when reading
    .RST_ACT_LOW(0),      // 1: active low, 0: active high
    .CLKIN_PERIOD(5000),    // in psec
	.nCK_PER_CLK(4),
	.RANKS(1),
	.ADDR_WIDTH(28),
	.CK_WIDTH(1),
	.PAYLOAD_WIDTH(16 /* 128 */),
	.BURST_TYPE("SEQ"),
	.TRCD(13750),
    .TRFC(300000),
    .TRP(13750),
    .TWTR(7500),
    .init_use_file(0)
) mig_model (
    .sys_clk_p(clk200),
    .sys_rst(mig_model_reset),
    .ddr3_reset_n(ddr3_reset_n),
    //  .app_addr({1'b0, app_addr, 3'b000}),
    .app_addr(app_addr),
    .app_cmd(app_cmd),
    .app_en(app_en),
    .app_wdf_data(app_wdf_data),
    .app_wdf_end(app_wdf_end),
    .app_wdf_mask(app_wdf_mask),
    .app_wdf_wren(app_wdf_wren),
    .app_rd_data(app_rd_data),
    .app_rd_data_end(app_rd_data_end),
    .app_rd_data_valid(app_rd_data_valid),
    .app_rdy(app_rdy),
    .app_wdf_rdy(app_wdf_rdy),
    .app_sr_req(1'b0),
    .app_sr_active(),
    .app_ref_req(1'b0),
    .app_ref_ack(),
    .app_zq_req(1'b0),
    .app_zq_ack(),
    .ui_clk(uiclk),
    .ui_clk_sync_rst(ui_clk_sync_rst),
    .init_calib_complete(init_calib_complete)
);
`else
//  Actual MIG
mig_7series_0 mem0 (
    .ddr3_dq(ddr3_dq),
    .ddr3_dqs_n(ddr3_dqs_n),
    .ddr3_dqs_p(ddr3_dqs_p),
    .ddr3_addr(ddr3_addr),
    .ddr3_ba(ddr3_ba),
    .ddr3_ras_n(ddr3_ras_n),
    .ddr3_cas_n(ddr3_cas_n),
    .ddr3_we_n(ddr3_we_n),
    .ddr3_reset_n(ddr3_reset_n),
    .ddr3_ck_p(ddr3_ck_p[0]),
    .ddr3_ck_n(ddr3_ck_n[0]),
    .ddr3_cke(ddr3_cke[0]),
    .ddr3_dm(ddr3_dm),
    .ddr3_odt(ddr3_odt[0]),
    //  .app_addr({1'b0, app_addr, 3'b000}),
    .app_addr(app_addr),
    .app_cmd(app_cmd),
    .app_en(app_en),
    .app_rdy(app_rdy),
    .app_wdf_rdy(app_wdf_rdy), 
    .app_wdf_data(app_wdf_data),
    .app_wdf_mask(app_wdf_mask),
    .app_wdf_end(app_wdf_wren),
    .app_wdf_wren(app_wdf_wren),
    .app_rd_data(app_rd_data),
    .app_rd_data_end(app_rd_data_end),
    .app_rd_data_valid(app_rd_data_valid),
    .app_sr_req(1'b0), 
    .app_sr_active(),
    .app_ref_req(1'b0),
    .app_ref_ack(),
    .app_zq_req(1'b0),
    .app_zq_ack(),
    .ui_clk(uiclk),
    .ui_clk_sync_rst(ui_clk_sync_rst),
    .init_calib_complete(init_calib_complete),
    .sys_rst(!reset),
    .sys_clk_i(clk400),
    .clk_ref_i(clk200)
);
`endif


endmodule


