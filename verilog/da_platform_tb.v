`timescale 1ns / 1ps

module da_platform_tb;

`include "parameters.v"

parameter M_fifos = 6;

//  Clocks/reset
reg clk_core;
reg clk_fx2;
reg reset;

reg [6:0] chanAddr;
wire [7:0] h2fData;
wire h2fValid;
wire h2fReady;
wire [7:0] f2hData;
wire f2hValid;
wire f2hReady;


wire [23:0] slotdata;

wire mclk;

wire amcs;
wire amdi;
wire amdo;

wire dmcs;
wire dmdi;
wire dmdo;

wire dirchan;
wire [1:0] acon;
wire aovf;
reg clk0;
wire reset_out;
wire srclk;
wire clksel;
reg clk1;

wire clk_mem;

wire mem_adv_n;
wire mem_cre;
wire mem_wait;
wire mem_ce_n;
wire mem_oe_n;
wire mem_we_n;
wire mem_ub_n;
wire mem_lb_n;
wire [Nb_addr-1:0] mem_addr;
wire [Nb-1:0] mem_dq;


//  DUT - DA platform control module

da_platform dut(
    .clk_nexys(clk_core), 
    .reset(reset), 
    
    .clk_mem_out(clk_mem), 
    .mem_adv_n(mem_adv_n), 
    .mem_ce_n(mem_ce_n), 
    .mem_oe_n(mem_oe_n), 
    .mem_we_n(mem_we_n), 
    .mem_cre(mem_cre), 
    .mem_lb_n(mem_lb_n), 
    .mem_ub_n(mem_ub_n), 
    .mem_wait(mem_wait),
	.mem_dq(mem_dq), 
	.mem_a(mem_addr),
    
    .clk_fx2(clk_fx2),
    .chanAddr(chanAddr), 
    .h2fData(h2fData), 
    .h2fValid(h2fValid), 
    .h2fReady(h2fReady), 
    .f2hData(f2hData), 
    .f2hValid(f2hValid), 
    .f2hReady(f2hReady),

    .slotdata(slotdata), 

    .mclk(mclk), 
    .amcs(amcs), 
    .amdi(amdi), 
    .amdo(amdo), 
    .dmcs(dmcs), 
    .dmdi(dmdi), 
    .dmdo(dmdo), 
    .dirchan(dirchan), 
    .acon(acon), 
    .aovf(aovf), 
    .clk0(clk0), 
    .reset_out(reset_out), 
    .srclk(srclk), 
    .clksel(clksel), 
    .clk1(clk1)
);

//  MEM - CellRAM memory

cellram ram (
    .clk    (clk_mem),
    .adv_n  (mem_adv_n),
    .cre    (mem_cre),
    .o_wait (mem_wait),
    .ce_n   (mem_ce_n),
    .oe_n   (mem_oe_n),
    .we_n   (mem_we_n),
    .ub_n   (mem_ub_n),
    .lb_n   (mem_lb_n),
    .addr   (mem_addr),
    .dq     (mem_dq)
);


//  Testing: hardware signals
reg [7:0] dirchan_parallel;
reg [7:0] aovf_parallel;

wire [7:0] amcs_parallel;
wire [7:0] dmcs_parallel;

wire [7:0] clksel_parallel;
wire [7:0] acon0_parallel;
wire [7:0] acon1_parallel;


serializer dirchan_ser(mclk, dirchan, srclk, dirchan_parallel);
serializer aovf_ser(mclk, aovf, srclk, aovf_parallel);

/*
assign dirchan = 1;
assign aovf = 1;
*/

deserializer amcs_des(mclk, amcs, srclk, amcs_parallel);
deserializer dmcs_des(mclk, dmcs, srclk, dmcs_parallel);
deserializer clksel_des(mclk, clksel, srclk, clksel_parallel);
deserializer acon0_des(mclk, acon[0], srclk, acon0_parallel);
deserializer acon1_des(mclk, acon[1], srclk, acon1_parallel);

//  Testing: SPI slaves
genvar g;
generate for (g = 0; g < 4; g = g + 1) begin: spi_slaves
    spi_slave adc_spi(
        .clk(clk_core),
        .reset(reset),
        .sck(mclk),
        .ss(amcs_parallel[g]),
        .mosi(amdi),
        .miso(amdo)
    );
    
    spi_slave dac_spi(
        .clk(clk_core),
        .reset(reset),
        .sck(mclk),
        .ss(dmcs_parallel[g]),
        .mosi(dmdi),
        .miso(dmdo)
    );
end
endgenerate

//  Testing: synchronous FIFOs working at FX2 interface clock connect to DUT

reg [7:0] tb_write_fifo_wr_data;
reg tb_write_fifo_wr_valid;
wire tb_write_fifo_wr_ready;

wire [7:0] tb_write_fifo_rd_data;
wire tb_write_fifo_rd_valid;
wire tb_write_fifo_rd_ready;

wire [M_fifos:0] tb_write_fifo_count;

wire [7:0] tb_read_fifo_wr_data;
wire tb_read_fifo_wr_valid;
wire tb_read_fifo_wr_ready;

wire [7:0] tb_read_fifo_rd_data;
wire tb_read_fifo_rd_valid;
reg tb_read_fifo_rd_ready;

wire [M_fifos:0] tb_read_fifo_count;

assign h2fData = tb_write_fifo_rd_data;
assign h2fValid = tb_write_fifo_rd_valid;
assign tb_write_fifo_rd_ready = h2fReady;

assign tb_read_fifo_wr_data = f2hData;
assign tb_read_fifo_wr_valid = f2hValid;
assign f2hReady = tb_read_fifo_wr_ready;

fifo_sync tb_write_fifo(
	.clk(clk_fx2), 
	.reset(reset),
	.wr_valid(tb_write_fifo_wr_valid), 
	.wr_data(tb_write_fifo_wr_data),
	.wr_ready(tb_write_fifo_wr_ready),
	.rd_ready(tb_write_fifo_rd_ready),
	.rd_valid(tb_write_fifo_rd_valid), 
	.rd_data(tb_write_fifo_rd_data),
	.count(tb_write_fifo_count)
);
defparam tb_write_fifo.Nb = 8;
defparam tb_write_fifo.M = M_fifos;

fifo_sync tb_read_fifo(
	.clk(clk_fx2), 
	.reset(reset),
	.wr_valid(tb_read_fifo_wr_valid), 
	.wr_data(tb_read_fifo_wr_data),
	.wr_ready(tb_read_fifo_wr_ready),
	.rd_ready(tb_read_fifo_rd_ready),
	.rd_valid(tb_read_fifo_rd_valid), 
	.rd_data(tb_read_fifo_rd_data),
	.count(tb_read_fifo_count)
);
defparam tb_read_fifo.Nb = 8;
defparam tb_read_fifo.M = M_fifos;


//  Tasks for read/write of those FIFOs

wire clk_tb_write = clk_fx2;
task tb_write_byte(input [7:0] byte);
begin
    while (!tb_write_fifo_wr_ready)
        @(posedge clk_tb_write);
    @(posedge clk_tb_write);
    tb_write_fifo_wr_valid <= 1;
    tb_write_fifo_wr_data <= byte;
    @(posedge clk_tb_write);
    while (!tb_write_fifo_wr_ready)
        @(posedge clk_tb_write);
    tb_write_fifo_wr_valid <= 0;
end
endtask


wire clk_tb_read = clk_fx2;
/*
task tb_read_byte(output [7:0] byte);
reg byte_captured;
begin
    byte_captured = 0;
    if (tb_read_fifo_rd_valid) begin
        byte = tb_read_fifo_rd_data;
        byte_captured = 1;
    end
    tb_read_fifo_rd_ready <= 1;
    @(posedge clk_tb_read);
    while (!tb_read_fifo_rd_valid && !byte_captured)
        @(posedge clk_tb_read);
    tb_read_fifo_rd_ready <= 0;
    if (!byte_captured)
        byte = tb_read_fifo_rd_data;
    @(posedge clk_tb_read);
end
endtask
*/
task tb_read_byte(output [7:0] byte);
reg byte_captured;
begin
    tb_read_fifo_rd_ready = 1;
    @(posedge clk_tb_read);
    while (!tb_read_fifo_rd_valid)
        @(posedge clk_tb_read);
    byte = tb_read_fifo_rd_data;
    tb_read_fifo_rd_ready = 0;
    @(posedge clk_tb_read);
end
endtask

//  Procedural code

reg [7:0] byte_read;
integer i;

initial begin

    $dumpfile("da_platform_tb.vcd");
    $dumpvars(0, da_platform_tb);
    
    dirchan_parallel <= 8'b10001111;
    aovf_parallel <= 8'b00100000;

    clk_core <= 0;
    clk_fx2 <= 0;
    clk0 <= 0;
    clk1 <= 0;
    reset <= 1;
    
    tb_write_fifo_wr_valid <= 0;
    tb_read_fifo_rd_ready <= 0;
    
    chanAddr <= 0;
    
    #100 reset <= 0;
    
    //  Test command: DIRCHAN_READ
    #2000 tb_write_byte(8'hFF);
    tb_write_byte(8'h41);
    $display("-- Testing DIRCHAN_READ");
    for (i = 0; i < 3; i = i + 1) begin
        tb_read_byte(byte_read);
        $display("Got byte %h at time %t", byte_read, $time);
    end
    
    //  Test command: AOVF_READ
    #2000 tb_write_byte(8'hFF);
    tb_write_byte(8'h43);
    $display("-- Testing AOVF_READ");
    for (i = 0; i < 3; i = i + 1) begin
        tb_read_byte(byte_read);
        $display("Got byte %h at time %t", byte_read, $time);
    end
    
    //  Test command: SELECT_CLOCK
    #2000 tb_write_byte(8'hFF);
    tb_write_byte(8'h40);
	tb_write_byte(8'h00);
	$display("-- Testing SELECT_CLOCK");
    
    //  Test command: AUD_FIFO_WRITE
    #2000 tb_write_byte(8'h01);
    tb_write_byte(8'h10);
	tb_write_byte(8'h00);
	tb_write_byte(8'h00);
	tb_write_byte(8'h06);
	$display("-- Testing AUD_FIFO_WRITE with checksum error");
	tb_write_byte(8'h12);   //  Data
	tb_write_byte(8'h34);
	tb_write_byte(8'h56);
	tb_write_byte(8'h78);
    tb_write_byte(8'h56);
	tb_write_byte(8'h78);
	tb_write_byte(8'h00);   //  Checksum (bogus)
	tb_write_byte(8'h03);
    for (i = 0; i < 6; i = i + 1) begin
        tb_read_byte(byte_read);
        $display("Got byte %h at time %t", byte_read, $time);
    end

    #2000 tb_write_byte(8'h01);
    tb_write_byte(8'h10);
	tb_write_byte(8'h00);
	tb_write_byte(8'h00);
	tb_write_byte(8'h42);
	$display("-- Testing AUD_FIFO_WRITE with correct checksum");
	for (i = 0; i < 10; i = i + 1) begin
	    tb_write_byte(8'h01);
	    tb_write_byte(8'h02);
	    tb_write_byte(8'h03);
	    tb_write_byte(8'hFF);
	    tb_write_byte(8'hFE);
	    tb_write_byte(8'hFD);
	end
	tb_write_byte(8'h12);   //  Data
	tb_write_byte(8'h34);
	tb_write_byte(8'h56);
	tb_write_byte(8'h78);
    tb_write_byte(8'h9A);
	tb_write_byte(8'hBC);
	tb_write_byte(8'h20);   //  Checksum (correct)
	tb_write_byte(8'h6A);
	
	#2000 tb_write_byte(8'h00);
    tb_write_byte(8'h20);
	tb_write_byte(8'h00);
	tb_write_byte(8'h00);
	tb_write_byte(8'h03);
	$display("-- Testing CMD_FIFO_WRITE - SPI write");
	tb_write_byte(8'h60);   //  Data
	tb_write_byte(8'h10);
	tb_write_byte(8'h58);
	tb_write_byte(8'h00);   //  Checksum (correct)
	tb_write_byte(8'hC8);
	
    #2000 tb_write_byte(8'h00);
    tb_write_byte(8'h20);
	tb_write_byte(8'h00);
	tb_write_byte(8'h00);
	tb_write_byte(8'h02);
	$display("-- Testing CMD_FIFO_WRITE - SPI read");
	tb_write_byte(8'h61);   //  Data
	tb_write_byte(8'h90);
	tb_write_byte(8'h00);   //  Checksum (correct)
	tb_write_byte(8'hF1);
	for (i = 0; i < 7; i = i + 1) begin
        tb_read_byte(byte_read);
        $display("Got byte %h at time %t", byte_read, $time);
    end
	
	$display("-- Testing ECHO_SEND");
	#2000 tb_write_byte(8'hFF);
    tb_write_byte(8'h45);
	tb_write_byte(8'h04);
	tb_write_byte(8'h73);
	tb_write_byte(8'ha5);
	tb_write_byte(8'hfe);   //  Data
	tb_write_byte(8'h09);
	for (i = 0; i < 7; i = i + 1) begin
        tb_read_byte(byte_read);
        $display("Got byte %h at time %t", byte_read, $time);
    end
    
	$display("-- Testing ECHO_SEND (again)");
	#2000 tb_write_byte(8'hFF);
    tb_write_byte(8'h45);
	tb_write_byte(8'h08);
	tb_write_byte(8'h44);
	tb_write_byte(8'ha5);
	tb_write_byte(8'hff);
	tb_write_byte(8'h09);
	tb_write_byte(8'h76);
	tb_write_byte(8'hcd);
	tb_write_byte(8'h0f);
	tb_write_byte(8'h0e);
	for (i = 0; i < 11; i = i + 1) begin
        tb_read_byte(byte_read);
        $display("Got byte %h at time %t", byte_read, $time);
    end
	
    #100000 $finish;

end

//  Time limit
initial begin
    #1000000 $finish;
end

always #10.417 clk_fx2 <= !clk_fx2;
always #10 clk_core <= !clk_core;

always #44.289 clk0 <= !clk0;
always #20.345 clk1 <= !clk1;

endmodule
