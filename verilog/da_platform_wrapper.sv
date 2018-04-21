/*
    Open-source digital audio platform
    Copyright (C) 2009--2018 Michael Price

    da_platform_wrapper: Top level HDL module for synthesis.
    Adapts generic interfaces of da_platform to the physical interfaces
    (DDR3 memory, FX2 USB interface) on ZTEX FPGA module 2.13.

    Warning: Use and distribution of this code is restricted.
    This HDL file is distributed under the terms of the Solderpad Hardware 
    License, Version 0.51.  Other files in this project may be subject to
    different licenses.  Please see the LICENSE file in the top level project
    directory for more information.
*/

`timescale 1ns / 1ps

module da_platform_wrapper #(
    host_width = 16,
    mem_width = 32,
    sclk_ratio = 16,
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

logic uiclk;
logic ui_clk_sync_rst;

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
    .pktend_arm(1'b0),   //  TODO 12/28/2017 - figure out how to drive this.
    //  1/1/2017: Reduce timeout from 100 ms to minimum (1.3 ms) in order to reduce latency.
    //  Consider modifying ezusb_io.v to reduce further.
    //  .pktend_timeout(16'd73),
    .pktend_timeout(16'h01),
    .DO(host_in.data),
    .DO_valid(host_in.valid),
    .DO_ready(host_in.ready),
    .status(usb_status)	
);

//  MIG interface - now AXI
AXI4_Std mem_axi(uiclk);

wire clk200_in;
wire clk200;
wire clk400_in;
wire clk400;

logic init_calib_complete;

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
MIGAdapter mig_adapter(
    .clk(clk_mem),
    .reset(ui_clk_sync_rst),
    .ext_mem_cmd(mem_cmd.in),
    .ext_mem_write(mem_write.in),
    .ext_mem_read(mem_read.out),
    .mig_init_done(init_calib_complete),
    .axi(mem_axi.master)
);

//  MIG instantiation
//  In simulation mode, use MIG model instead.
`ifdef USE_MIG_MODEL

mem_model_axi sim_mem(
    .aclk(uiclk),
    .aresetn(!ui_clk_sync_rst),
    .axi(mem_axi.slave)
);

//  Model clock generation and startup of MIG
initial begin
    uiclk = 0;
    ui_clk_sync_rst = 1;
    init_calib_complete = 0;
    
    #100 ui_clk_sync_rst = 0;
    #1000 init_calib_complete = 1;
end

always #2.5 uiclk <= !uiclk;

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
    
    .aresetn(!ui_clk_sync_rst),

    .s_axi_awid(mem_axi.awid),
    .s_axi_awaddr(mem_axi.awaddr),
    .s_axi_awlen(mem_axi.awlen),
    .s_axi_awsize(mem_axi.awsize),
    .s_axi_awburst(mem_axi.awburst),
    .s_axi_awlock(mem_axi.awlock),
    .s_axi_awcache(mem_axi.awcache),
    .s_axi_awprot(mem_axi.awprot),
    .s_axi_awqos(mem_axi.awqos),
    .s_axi_awvalid(mem_axi.awvalid),
    .s_axi_awready(mem_axi.awready),
    .s_axi_wdata(mem_axi.wdata),
    .s_axi_wstrb(mem_axi.wstrb),
    .s_axi_wlast(mem_axi.wlast),
    .s_axi_wvalid(mem_axi.wvalid),
    .s_axi_wready(mem_axi.wready),
    .s_axi_bready(mem_axi.bready),
    .s_axi_bid(mem_axi.bid),
    .s_axi_bresp(mem_axi.bresp),
    .s_axi_bvalid(mem_axi.bvalid),
    .s_axi_arid(mem_axi.arid),
    .s_axi_araddr(mem_axi.araddr),
    .s_axi_arlen(mem_axi.arlen),
    .s_axi_arsize(mem_axi.arsize),
    .s_axi_arburst(mem_axi.arburst),
    .s_axi_arlock(mem_axi.arlock),
    .s_axi_arcache(mem_axi.arcache),
    .s_axi_arprot(mem_axi.arprot),
    .s_axi_arqos(mem_axi.arqos),
    .s_axi_arvalid(mem_axi.arvalid),
    .s_axi_arready(mem_axi.arready),
    .s_axi_rready(mem_axi.rready),
    .s_axi_rid(mem_axi.rid),
    .s_axi_rdata(mem_axi.rdata),
    .s_axi_rresp(mem_axi.rresp),
    .s_axi_rlast(mem_axi.rlast),
    .s_axi_rvalid(mem_axi.rvalid),

    .app_sr_req(1'b0),  //  reserved - tie low
    .app_ref_req(1'b0), //  request a refresh; we don't do this, just let the MIG handle it
    .app_zq_req(1'b0),  //  request ZQ calibration; we don't do this, just let the MIG handle it
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


