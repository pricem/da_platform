module cellram_interface(
	reset,
	clk_core, clk_mem_out,
	cmd_bl, cmd_instr, cmd_addr, cmd_valid, cmd_ready, cmd_count, 
	wr_data, wr_valid, wr_ready, wr_count,
	rd_valid, rd_data, rd_ready, rd_count,
	mem_adv_n, mem_ce_n, mem_oe_n, mem_we_n, mem_cre, mem_lb_n, mem_ub_n, mem_wait,
	mem_dq, mem_a
);

`include "parameters.v"

//	Startup delay > 150 us at 100 MHz clock
`ifdef SIMULATION
parameter startup_delay = 100;
`else
parameter startup_delay = 20000;
`endif

parameter bcr_value = 23'b000_1000_0001_1100_0001_1111;	//	BCR target value = 1D1F, includes register select bits
parameter rcr_value = 23'b000_0000_0000_0000_0001_0000;	//	RCR target value = 0010, includes register select bits

parameter async_write_we_cycles = 6;	//	Number of cycles to wait before completing a config register write;
parameter async_write_ce_cycles = 9;

parameter row_bits = 7;	//	128 words per row

//	I/O definitions

input reset;

input clk_core;
output clk_mem_out;

input [Nb_bl-1:0] cmd_bl;
input [Nb_inst-1:0] cmd_instr;
input [Nb_addr-1:0] cmd_addr;
input cmd_valid;
output cmd_ready;
output [M_fc:0] cmd_count;

input [Nb-1:0] wr_data;
input wr_valid;
output wr_ready;
output [M_fw:0] wr_count;

input rd_ready;
output [Nb-1:0] rd_data;
output rd_valid;
output [M_fr:0] rd_count;

output reg mem_adv_n;
output reg mem_ce_n;
output reg mem_oe_n;
output reg mem_we_n;
output reg mem_cre;
output reg mem_lb_n;
output reg mem_ub_n;
input mem_wait;

inout [Nb-1:0] mem_dq;
output reg [Nb_addr-1:0] mem_a;

//	Internal signals

wire mem_wait_last;
delay mem_wait_delay(clk_core, reset, mem_wait || mem_ce_n, mem_wait_last);

parameter STATE_RESET = 4'h0;
parameter STATE_STARTUP = 4'h1;
parameter STATE_PROGRAM_RCR = 4'h2;
parameter STATE_PROGRAM_BCR = 4'h3;
parameter STATE_WAITING = 4'h4;
parameter STATE_PARSE_CMD = 4'h5;
parameter STATE_READ = 4'h6;
parameter STATE_WRITE = 4'h7;
reg [3:0] state;

reg [15:0] startup_delay_counter;
reg [3:0] config_write_counter;

reg cmd_rd_ready;
wire cmd_rd_valid;
wire [Nb_bl-1:0] cmd_rd_bl;
wire [Nb_inst-1:0] cmd_rd_instr;
wire [Nb_addr-1:0] cmd_rd_addr;

reg rd_fifo_wr_valid;
wire [Nb-1:0] rd_fifo_wr_data;

reg wr_fifo_rd_extra;
wire wr_fifo_rd_ready = (!mem_ce_n && !mem_we_n && !mem_wait_last) || wr_fifo_rd_extra;
wire wr_fifo_rd_valid;
wire [Nb-1:0] wr_fifo_rd_data;

reg [Nb_bl-1:0] cur_bl;
reg [Nb_inst-1:0] cur_instr;
reg [Nb_addr-1:0] cur_addr;

reg [Nb_bl:0] cur_burst_count;
wire [Nb_addr-1:0] cur_addr_count = cur_addr + cur_burst_count;
wire new_row = ((cur_addr_count[Nb_addr-1:row_bits] != cur_addr[Nb_addr-1:row_bits]) && (cur_addr_count[row_bits-1:0] == 0));
reg new_row_ack;
reg new_row_req;

reg clk_mem_en;
wire [Nb-1:0] mem_dq_out;


assign clk_mem_out = (!clk_core) & clk_mem_en;
assign mem_dq_out = wr_fifo_rd_data;
assign mem_dq = (!mem_we_n && (mem_wait === 0)) ? mem_dq_out : 16'hZZZZ;

delay mem_read_delay(clk_mem_out, reset, mem_dq, rd_fifo_wr_data);
defparam mem_read_delay.Nb = Nb;

//	FIFOs
fifo_sync cmd_fifo(
	.clk(clk_core), 
	.reset(reset),
	.wr_valid(cmd_valid), 
	.wr_data({cmd_bl, cmd_instr, cmd_addr}),
	.wr_ready(cmd_ready),
	.rd_ready(cmd_rd_ready),
	.rd_valid(cmd_rd_valid), 
	.rd_data({cmd_rd_bl, cmd_rd_instr, cmd_rd_addr}),
	.count(cmd_count)
);
/*
fifo_async cmd_fifo(
	reset,
	clk_core, cmd_en, {cmd_bl, cmd_instr, cmd_addr},
	cmd_full, cmd_count,
	!clk_mem, cmd_fifo_rd_en,
	cmd_empty, {cmd_rd_bl, cmd_rd_instr, cmd_rd_addr},
	cmd_rd_count
);
*/
defparam cmd_fifo.Nb = Nb_bl + Nb_inst + Nb_addr;
defparam cmd_fifo.M = M_fc;

fifo_sync rd_fifo(
	.clk(clk_core), 
	.reset(reset),
	.wr_valid(rd_fifo_wr_valid), 
	.wr_data(rd_fifo_wr_data),
	.wr_ready(rd_fifo_wr_ready),
	.rd_ready(rd_ready),
	.rd_valid(rd_valid), 
	.rd_data(rd_data),
	.count(rd_count)
);
/*
//	Read: sample reads on positive clock edge since that's when it's valid
fifo_async rd_fifo(
	reset,
	clk_mem, rd_fifo_wr_en, rd_fifo_wr_data,
	rd_full, rd_wr_count,
	clk_core, rd_en,
	rd_empty, rd_data,
	rd_count
);
*/
defparam rd_fifo.Nb = Nb;
defparam rd_fifo.M = M_fr;

fifo_sync wr_fifo(
	.clk(clk_core), 
	.reset(reset),
	.wr_valid(wr_valid), 
	.wr_data(wr_data),
	.wr_ready(wr_ready),
	.rd_ready(wr_fifo_rd_ready),
	.rd_valid(wr_fifo_rd_valid), 
	.rd_data(wr_fifo_rd_data),
	.count(wr_count)
);
/*
fifo_async wr_fifo(
	reset,
	clk_core, wr_en, wr_data,
	wr_full, wr_count,
	!clk_mem, wr_fifo_rd_en_gated,
	wr_empty, wr_fifo_rd_data,
	wr_rd_count
);
*/
defparam wr_fifo.Nb = Nb;
defparam wr_fifo.M = M_fw;

//	Logic
always @(posedge clk_core) begin
	if (reset) begin
		mem_adv_n <= 1;
		mem_ce_n <= 1;
		mem_oe_n <= 1;
		mem_we_n <= 1;
		mem_cre <= 0;
		mem_lb_n <= 1;
		mem_ub_n <= 1;
		
		clk_mem_en <= 0;
	
		startup_delay_counter <= 0;
		config_write_counter <= 0;
		mem_a <= 0;
		
		cur_bl <= 0;
		cur_instr <= 0;
		cur_addr <= 0;
		
		cur_burst_count <= 0;
		new_row_ack <= 0;
		new_row_req <= 0;
		
		cmd_rd_ready <= 0;
		wr_fifo_rd_extra <= 0;
		rd_fifo_wr_valid <= 0;

		state <= STATE_RESET;
	end
	else begin
	
	    wr_fifo_rd_extra <= 0;
	
		case (state)
		
		STATE_RESET: begin
			state <= STATE_STARTUP;	
		end
		
		STATE_STARTUP: begin
			if (startup_delay_counter < startup_delay)
				startup_delay_counter <= startup_delay_counter + 1;
			else begin
				startup_delay_counter <= 0;
				
				mem_ce_n <= 0;
				mem_adv_n <= 0;
				mem_a <= rcr_value;
				mem_cre <= 1;
				config_write_counter <= 0;
				
				state <= STATE_PROGRAM_RCR;
			end
		end
		
		STATE_PROGRAM_RCR: begin
			mem_adv_n <= 1;
			
			if (config_write_counter < async_write_ce_cycles) begin
				config_write_counter <= config_write_counter + 1;
				if (config_write_counter < async_write_ce_cycles - async_write_we_cycles)
					mem_we_n <= 1;
				else
					mem_we_n <= 0;
			end
			else begin
				config_write_counter <= 0;
				mem_ce_n <= 1;
			end
			
			if (mem_ce_n) begin
				mem_ce_n <= 0;
				mem_adv_n <= 0;
				mem_a <= bcr_value;
				mem_lb_n <= 0;
				mem_ub_n <= 0;
				mem_cre <= 1;
				config_write_counter <= 0;
			
				state <= STATE_PROGRAM_BCR;
			end
		end
		
		STATE_PROGRAM_BCR: begin
			mem_adv_n <= 1;
			
			if (config_write_counter < async_write_ce_cycles) begin
				config_write_counter <= config_write_counter + 1;
				if (config_write_counter < async_write_ce_cycles - async_write_we_cycles)
					mem_we_n <= 1;
				else
					mem_we_n <= 0;
			end
			else begin
				config_write_counter <= 0;
				mem_ce_n <= 1;
				mem_cre <= 0;
				state <= STATE_WAITING;
			end

		end
		
		STATE_WAITING: begin
			rd_fifo_wr_valid <= 0;
		    cmd_rd_ready <= 1;
		
			if (cmd_rd_valid && cmd_rd_ready) begin
			    cmd_rd_ready <= 0;
                cur_bl <= cmd_rd_bl;
    			cur_instr <= cmd_rd_instr;
    			cur_addr <= cmd_rd_addr;
				state <= STATE_PARSE_CMD;
			end
		end
		
		STATE_PARSE_CMD: begin

			cur_burst_count <= 0;
			
			clk_mem_en <= 1;
			mem_ce_n <= 0;
			mem_adv_n <= 0;
			mem_a <= cmd_rd_addr;
			new_row_ack <= 0;
			new_row_req <= 0;
			
			case (cur_instr)
				INSTR_WRITE: begin
					mem_we_n <= 0;
					wr_fifo_rd_extra <= 1;
					state <= STATE_WRITE;
				end
				INSTR_READ: begin
					mem_we_n <= 1;
				
					state <= STATE_READ;
				end
			endcase
		end
		
		STATE_READ: begin
		
			if (new_row && !new_row_ack) begin
				//	Restart read after crossing a memory row boundary
				if (mem_ce_n) begin
					mem_ce_n <= 0;
					mem_adv_n <= 0;
					mem_a <= cur_addr_count;
					new_row_ack <= 1;
				end
				else begin
					mem_ce_n <= 1;
					rd_fifo_wr_valid <= 0;
				end
			end
			else if (cur_burst_count < cur_bl + 1) begin
				mem_adv_n <= 1;
			
				//	Stop writing to FIFO as we approach the end of a row and have to start another burst
				if (!mem_wait && (new_row_ack || !new_row)) begin
					rd_fifo_wr_valid <= 1;
					cur_burst_count <= cur_burst_count + 1;
				end
				else begin
					rd_fifo_wr_valid <= 0;
					if (cur_addr_count[row_bits-1:0] == {row_bits{1'b1}})
						new_row_req <= 1;
				end
				mem_oe_n <= 0;
			end
			else begin
				mem_adv_n <= 1;
				mem_ce_n <= 1;
				mem_oe_n <= 1;
				clk_mem_en <= 0;
				rd_fifo_wr_valid <= 0;
				state <= STATE_WAITING;
			end
		end
		
		STATE_WRITE: begin
		
			if (new_row && !new_row_ack) begin
				//	Restart write after crossing a memory row boundary
				if (mem_ce_n) begin
					mem_ce_n <= 0;
					mem_adv_n <= 0;
					mem_a <= cur_addr_count;

					new_row_ack <= 1;
				end
				else begin
					mem_ce_n <= 1;
				end
				
			end
			else if (cur_burst_count < cur_bl + 1) begin
				mem_adv_n <= 1;

				//	Maintain 2 reads queued up so we can respond with data ready when WAIT is deasserted
				//	Stop reading FIFO as we approach the end of a row and have to start another burst
				//  if (wr_ready && (cur_addr_count[row_bits-1:0] != {row_bits{1'b1}}) && (!mem_wait || (wr_fifo_reads_queued + wr_fifo_rd_valid < 1))) begin
				if (!mem_wait) begin
					cur_burst_count <= cur_burst_count + 1;
				end
			end
			else begin
				mem_adv_n <= 1;
				mem_ce_n <= 1;
				mem_we_n <= 1;
				clk_mem_en <= 0;
				state <= STATE_WAITING;
			end
		end
		
		endcase
	
	end
end

endmodule
