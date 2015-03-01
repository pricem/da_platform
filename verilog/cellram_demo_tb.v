module cellram_demo_tb;

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

cellram_demo dut(
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
    .f2hReady(f2hReady)
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

always @(posedge clk_fx2) begin
	if (reset) begin
		tb_write_fifo_wr_valid <= 0;
		tb_read_fifo_rd_ready <= 0;
	end
end

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



//	TODO: Tasks to run sequence of commands for a mem read/write test

task rw_test(input [Nb_addr:0] addr, input [7:0] num_words);
reg [7:0] ref_data[255:0];
reg [7:0] read_word;
integer i;
begin

	$display("%t -- Starting read/write test for %d bytes starting at addr %h", $realtime, num_words, addr);
    for (i = 0; i < num_words; i = i + 1)
        ref_data[i] = $random;

	tb_write_byte(8'h20);
	tb_write_byte(addr[23:16]);
	tb_write_byte(addr[15:8]);
	tb_write_byte(addr[7:0]);
	tb_write_byte(num_words);
	for (i = 0; i < num_words; i = i + 1)
		tb_write_byte(ref_data[i]);

	tb_write_byte(8'h10);
	tb_write_byte(addr[23:16]);
	tb_write_byte(addr[15:8]);
	tb_write_byte(addr[7:0]);
	tb_write_byte(num_words);
    for (i = 0; i < num_words; i = i + 1) begin
        tb_read_byte(read_word);
        if (read_word != ref_data[i])
            $display("READ ERROR: Got %h for word %d, expected %h", read_word, i, ref_data[i]);
    end
	$display("%t -- Completed read/write test for %d bytes starting at addr %h", $realtime, num_words, addr);
end
endtask



initial begin
    reset <= 1;
    clk_core <= 0;
    clk_fx2 <= 0;
    
    #100 reset <= 0;
    
    //  Test writing and reading back a word sequence in different places, different lengths
    rw_test(0, 1);
    #100 rw_test(0, 16);
    #100 rw_test(24'h00A0F2, 22);	//	even length, even addr
    #100 rw_test(24'h111604, 35);	//	odd length, even addr
    #100 rw_test(24'h48A0F5, 19);	//	odd length, odd addr
    #100 rw_test(24'h94CC45, 26);	//	even length, odd addr

    $display("All read/write tests finished at time %t", $time);

    #1000 $finish;
    
end

initial begin
    $dumpfile("cellram_demo_tb.vcd");
    $dumpvars(0, cellram_demo_tb);
    
    #100000 $finish;
end

always #10 clk_core <= !clk_core;
always #10.417 clk_fx2 <= !clk_fx2;

endmodule

