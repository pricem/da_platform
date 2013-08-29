module cellram_tb;

`include "parameters.v"

reg clk_core;
reg reset;

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


reg [Nb_bl-1:0] cmd_bl;
reg [Nb_inst-1:0] cmd_instr;
reg [Nb_addr-1:0] cmd_addr;
reg cmd_valid;
wire cmd_ready;
wire [M_fc:0] cmd_count;

reg [Nb-1:0] wr_data;
reg wr_valid;
wire wr_ready;
wire [M_fw:0] wr_count;

reg rd_ready;
wire [Nb-1:0] rd_data;
wire rd_valid;
wire [M_fr:0] rd_count;

cellram_interface interface (
	.reset(reset),
	.clk_core(clk_core), 
	.clk_mem_out(clk_mem),
	.cmd_bl(cmd_bl), 
	.cmd_instr(cmd_instr), 
	.cmd_addr(cmd_addr), 
	.cmd_valid(cmd_valid), 
	.cmd_ready(cmd_ready), 
	.cmd_count(cmd_count), 
	.wr_data(wr_data), 
	.wr_valid(wr_valid), 
	.wr_ready(wr_ready), 
	.wr_count(wr_count),
	.rd_valid(rd_valid), 
	.rd_data(rd_data), 
	.rd_ready(rd_ready), 
	.rd_count(rd_count),
	.mem_adv_n(mem_adv_n), 
	.mem_ce_n(mem_ce_n), 
	.mem_oe_n(mem_oe_n), 
	.mem_we_n(mem_we_n), 
	.mem_cre(mem_cre), 
	.mem_lb_n(mem_lb_n), 
	.mem_ub_n(mem_ub_n), 
	.mem_wait(mem_wait),
	.mem_dq(mem_dq), 
	.mem_a(mem_addr)
);


task write_word(input [Nb-1:0] word);
begin
    wr_valid <= 1;
    wr_data <= word;
    @(posedge clk_core);
    while (!wr_ready) @(posedge clk_core);
    wr_valid <= 0;
end
endtask

task submit_cmd(input [Nb_inst-1:0] instr, input [Nb_addr-1:0] addr, input [Nb_bl:0] burst_length);
begin
    cmd_valid <= 1;
    cmd_bl <= burst_length - 1;
    cmd_addr <= addr;
    cmd_instr <= instr;
    @(posedge clk_core);
    while (!cmd_ready) @(posedge clk_core);
    cmd_valid <= 0;
end
endtask

task read_word(output [Nb-1:0] word);
begin
    rd_ready <= 1;
    @(posedge clk_core);
    while (!rd_valid) @(posedge clk_core);
    word <= rd_data;
    rd_ready <= 0;
    @(posedge clk_core);
end
endtask

reg [Nb-1:0] ref_data[63:0];

task rw_test(input [Nb_addr-1:0] addr, input [15:0] num_words);
integer i;
reg [Nb-1:0] read_word_test;
begin
    for (i = 0; i < num_words; i = i + 1) begin
        ref_data[i] = $random;
        write_word(ref_data[i]);
    end
    submit_cmd(INSTR_WRITE, addr, num_words);
    
    submit_cmd(INSTR_READ, addr, num_words);
    for (i = 0; i < num_words; i = i + 1) begin
        read_word(read_word_test);
        if (read_word_test != ref_data[i])
            $display("READ ERROR: Got %h for word %d, expected %h", read_word_test, i, ref_data[i]);
    end
end
endtask

initial begin
    reset <= 1;
    clk_core <= 0;
    
    cmd_bl <= 0;
    cmd_instr <= 0;
    cmd_addr <= 0;
    cmd_valid <= 0;
    
    wr_data <= 0;
    wr_valid <= 0;
    rd_ready <= 0;
    
    #100 reset <= 0;
    
    //  Test writing and reading back a word sequence in different places, different lengths
    rw_test(0, 1);
    #100 rw_test(0, 16);
    #100 rw_test(16'hA0F2, 22);
    #100 rw_test(16'h1607, 35);
    #100 rw_test(16'hA0F5, 19);

    $display("All read/write tests finished at time %t", $time);

    #1000 $finish;
    
end

initial begin
    $dumpfile("cellram_tb.vcd");
    $dumpvars(0, cellram_tb);
    
    #100000 $finish;
end

always #10 clk_core <= !clk_core;

endmodule
