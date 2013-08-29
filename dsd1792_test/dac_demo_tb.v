`timescale 1ns / 1ps

module dac_demo_tb;

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

wire dac_sclk;
wire dac_dina;
wire dac_dinb;
wire dac_sync;

//  DUT - DAC demo module

dac_control dut(
    .clk_in(clk_core), 
    .reset(reset), 
    .clk_fx2(clk_fx2),
    .chanAddr(chanAddr), 
    .h2fData(h2fData), 
    .h2fValid(h2fValid), 
    .h2fReady(h2fReady), 
    .f2hData(f2hData), 
    .f2hValid(f2hValid), 
    .f2hReady(f2hReady),
    .dac_sclk(dac_sclk), 
    .dac_dina(dac_dina), 
    .dac_dinb(dac_dinb), 
    .dac_sync(dac_sync)
);

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
task tb_read_byte(output [7:0] byte);
begin
    tb_read_fifo_rd_ready <= 1;
    while (!tb_read_fifo_rd_valid)
        @(posedge clk_tb_read);
    tb_read_fifo_rd_ready <= 0;
    byte <= tb_read_fifo_rd_data;
end
endtask


//  Procedural code

reg [7:0] byte_read;
integer i;

initial begin

    $dumpfile("dac_demo_tb.vcd");
    $dumpvars(0, dac_demo_tb);

    clk_core <= 0;
    clk_fx2 <= 0;
    reset <= 1;
    
    tb_write_fifo_wr_valid <= 0;
    tb_read_fifo_rd_ready <= 0;
    
    chanAddr <= 0;
    
    #100 reset <= 0;

    #100 for (i = 0; i < 256; i = i + 1) begin
        tb_write_byte(i);
        tb_write_byte($random);
        tb_write_byte(i);
        tb_write_byte($random);
    end
    //  #100 tb_read_byte(byte_read);
    //  $display("%t Read %h", $time, byte_read);
    
    #100000 $finish;

end

//  Time limit
initial begin
    #1000000 $finish;
end

always #10.417 clk_fx2 <= !clk_fx2;
always #10 clk_core <= !clk_core;

endmodule
