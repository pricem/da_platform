/*!
   memfifo -- bi-directional high speed communication on ZTEX USB-FPGA Module 2.13d by connecting EZ-USB slave FIFO's to a FIFO built of the on-board DDR3 SDRAM
   Copyright (C) 2009-2014 ZTEX GmbH.
   http://www.ztex.de

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License version 3 as
   published by the Free Software Foundation.

   This program is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
   General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, see http://www.gnu.org/licenses/.
!*/

/* 
    Top level module: glues everything together.    
    GPIO has been removed - loopback only.
*/  

module memfifo (
    input fxclk_in,
    input ifclk_in,
    input reset,
    // debug
    output [9:0] led1,
    output [19:0] led2,
    input SW8,
    input SW10,
    // ddr3 
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
    // ez-usb
    inout [15:0] fd,
    output SLWR, SLRD,
    output SLOE, FIFOADDR0, FIFOADDR1, PKTEND,
    input FLAGA, FLAGB,
    // GPIO
    input gpio_clk, gpio_dir,
    inout gpio_dat
);

wire ifclk;

wire reset_usb;
wire reset_mem;

wire [15:0] usb_data_in;
wire usb_in_valid;
wire usb_in_ready;

wire [15:0] usb_data_out;
wire usb_out_valid;
wire usb_out_ready;

wire [3:0] usb_status;

wire [127:0] fifo_data_in;
wire fifo_wr_full;
wire fifo_wr_err;
wire fifo_wr_en;

wire [127:0] fifo_data_out;
wire fifo_rd_empty;
wire fifo_rd_err;
wire fifo_rd_en;

wire [24:0] fifo_mem_free;
wire [9:0] fifo_status;

dram_fifo #(
    .FIRST_WORD_FALL_THROUGH("TRUE"),  			// Sets the FIFO FWFT to FALSE, TRUE
    .ALMOST_EMPTY_OFFSET2(13'h0008)
) dram_fifo_inst (
    .fxclk_in(fxclk_in),					// 48 MHz input clock pin
    .reset(reset || reset_usb),
    .reset_out(reset_mem),					// reset output
    .clkout2(),	 					// PLL clock outputs not used for memory interface
    .clkout3(),	
    .clkout4(),	
    .clkout5(),	
    // Memory interface ports
    .ddr3_dq(ddr3_dq),
    .ddr3_dqs_n(ddr3_dqs_n),
    .ddr3_dqs_p(ddr3_dqs_p),
    .ddr3_addr(ddr3_addr),
    .ddr3_ba(ddr3_ba),
    .ddr3_ras_n(ddr3_ras_n),
    .ddr3_cas_n(ddr3_cas_n),
    .ddr3_we_n(ddr3_we_n),
    .ddr3_reset_n(ddr3_reset_n),
    .ddr3_ck_p(ddr3_ck_p),
    .ddr3_ck_n(ddr3_ck_n),
    .ddr3_cke(ddr3_cke),
    .ddr3_dm(ddr3_dm),
    .ddr3_odt(ddr3_odt),
    // input fifo interface, see "7 Series Memory Resources" user guide (ug743)
    .DI(fifo_data_in),
    .FULL(fifo_wr_full),                    // 1-bit output: Full flag
    .ALMOSTFULL1(),  	     	// 1-bit output: Almost full flag
    .ALMOSTFULL2(),  	     	// 1-bit output: Almost full flag
    .WRERR(fifo_wr_err),                  // 1-bit output: Write error
    .WREN(fifo_wr_en),                    // 1-bit input: Write enable
    .WRCLK(ifclk),                  // 1-bit input: Rising edge write clock.
    // output fifo interface, see "7 Series Memory Resources" user guide (ug743)
    .DO(fifo_data_out),
    .EMPTY(fifo_rd_empty),                  // 1-bit output: Empty flag
    .ALMOSTEMPTY1(),                // 1-bit output: Almost empty flag
    .ALMOSTEMPTY2(),                // 1-bit output: Almost empty flag
    .RDERR(fifo_rd_err),                  // 1-bit output: Read error
    .RDCLK(ifclk),                  // 1-bit input: Read clock
    .RDEN(fifo_rd_en),                    // 1-bit input: Read enable
    // free memory
    .mem_free_out(fifo_mem_free),
    // for debugging
    .status(fifo_status)
);

ezusb_io #(
    .OUTEP(2),		        // EP for FPGA -> EZ-USB transfers
    .INEP(6), 		        // EP for EZ-USB -> FPGA transfers 
    .TARGET("A7")			// "A4" for Artix 7
) ezusb_io_inst (
    .ifclk(ifclk),
    .reset(reset),   		// asynchronous reset input
    .reset_out(reset_usb),		// synchronous reset output
    // pins
    .ifclk_in(ifclk_in),
    .fd(fd),
    .SLWR(SLWR),
    .SLRD(SLRD),
    .SLOE(SLOE), 
    .PKTEND(PKTEND),
    .FIFOADDR({FIFOADDR1, FIFOADDR0}), 
    .EMPTY_FLAG(FLAGA),
    .FULL_FLAG(FLAGB),
    // signals for FPGA -> EZ-USB transfer
    .DI(usb_data_in),		// data written to EZ-USB
    .DI_valid(usb_in_valid),	// 1 indicates data valid; DI and DI_valid must be hold if DI_ready is 0
    .DI_ready(usb_in_ready),	// 1 if new data are accepted
    .DI_enable(1'b1),		// setting to 0 disables FPGA -> EZ-USB transfers
    .pktend_timeout(16'd73),	// timeout in multiples of 65536 clocks (approx. 0.1s @ 48 MHz) before a short packet committed
			    // setting to 0 disables this feature
    // signals for EZ-USB -> FPGA transfer
    .DO(usb_data_out),			// data read from EZ-USB
    .DO_valid(usb_out_valid),	// 1 indicated valid data
    .DO_ready(usb_out_ready),	// setting to 1 enables writing new data to DO in next clock; DO and DO_valid are hold if DO_ready is 0
    // debug output
    .status(usb_status)	
);

memfifo_contents contents(
    .usb_data_in(usb_data_in),
    .usb_in_valid(usb_in_valid),
    .usb_in_ready(usb_in_ready),

    .usb_data_out(usb_data_out),
    .usb_out_valid(usb_out_valid),
    .usb_out_ready(usb_out_ready),

    .usb_status(usb_status),
    .usb_flagb(FLAGB),
    .usb_flaga(FLAGA),

    .fifo_data_in(fifo_data_in),
    .fifo_wr_full(fifo_wr_full),
    .fifo_wr_err(fifo_wr_err),
    .fifo_wr_en(fifo_wr_en),

    .fifo_data_out(fifo_data_out),
    .fifo_rd_empty(fifo_rd_empty),
    .fifo_rd_err(fifo_rd_err),
    .fifo_rd_en(fifo_rd_en),
    
    .fifo_mem_free(fifo_mem_free),
    .fifo_status(fifo_status),

    .ifclk(ifclk),
    .reset(reset),
    .reset_usb(reset_usb),
    .reset_mem(reset_mem),
    .led1(led1),
    .led2(led2),
    .SW8(SW8),
    .SW10(SW10)
);

    
endmodule

