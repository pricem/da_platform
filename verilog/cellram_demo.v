module cellram_demo(
    //  Connections on Nexys2 board
    clk_nexys, clk_fx2, reset,
    clk_mem_out, mem_adv_n, mem_ce_n, mem_oe_n, mem_we_n, mem_cre, mem_lb_n, mem_ub_n, mem_wait,
	mem_dq, mem_a,

    //  Interface to FPGALink
    chanAddr, h2fData, h2fValid, h2fReady, f2hData, f2hValid, f2hReady
);

`include "parameters.v"

parameter M = 6;

//  Connections on Nexys2 board
input clk_nexys;
input clk_fx2;
input reset;

output clk_mem_out;
output mem_adv_n;
output mem_ce_n;
output mem_oe_n;
output mem_we_n;
output mem_cre;
output mem_lb_n;
output mem_ub_n;
input mem_wait;

inout [Nb-1:0] mem_dq;
output [Nb_addr-1:0] mem_a;

//  Interface to FPGALink
input [6:0] chanAddr;

input [7:0] h2fData;
input h2fValid;
output h2fReady;

output [7:0] f2hData;
output f2hValid;
input f2hReady;

//	Internal lines to CellRAM interface

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

wire clk_core = clk_nexys;

cellram_interface interface (
	.reset(reset),
	.clk_core(clk_core), 
	.clk_mem_out(clk_mem_out),
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
	.mem_a(mem_a)
);

//  FIFOs for clock domain conversion (FX2 -> Nexys2)

wire [M:0] read_fifo_wr_count;
wire [M:0] read_fifo_rd_count;

wire read_fifo_rd_valid;
wire [7:0] read_fifo_rd_data;

reg read_fifo_rd_ready_int;
wire read_fifo_rd_ready = read_fifo_rd_ready_int;	//	 && read_fifo_read_ok;

fifo_async read_fifo(
	.reset(reset),
	.wr_clk(clk_fx2), 
	.wr_valid(h2fValid), 
	.wr_data(h2fData),
	.wr_ready(h2fReady), 
	.wr_count(read_fifo_wr_count),
	.rd_clk(clk_core), 
	.rd_valid(read_fifo_rd_valid),
	.rd_ready(read_fifo_rd_ready), 
	.rd_data(read_fifo_rd_data), 
	.rd_count(read_fifo_rd_count)
);
defparam read_fifo.Nb = 8;
defparam read_fifo.M = M;

wire [M:0] write_fifo_wr_count;
wire [M:0] write_fifo_rd_count;

reg write_fifo_wr_valid;
reg [7:0] write_fifo_wr_data;
wire write_fifo_wr_ready;

fifo_async write_fifo(
	.reset(reset),
	.wr_clk(clk_core), 
	.wr_valid(write_fifo_wr_valid), 
	.wr_data(write_fifo_wr_data),
	.wr_ready(write_fifo_wr_ready), 
	.wr_count(write_fifo_wr_count),
	.rd_clk(clk_fx2), 
	.rd_valid(f2hValid),
	.rd_ready(f2hReady), 
	.rd_data(f2hData), 
	.rd_count(write_fifo_rd_count)
);
defparam write_fifo.Nb = 8;
defparam write_fifo.M = M;


//	Control logic for talking to FPGALink

parameter STATE_IDLE = 4'h0;
parameter STATE_READ = 4'h1;
parameter STATE_WRITE = 4'h2;
parameter STATE_READ_WAITING = 4'h3;
parameter STATE_WRITE_SUBMIT = 4'h4;
reg [3:0] state;

reg [8:0] cmd_byte_index;
reg [23:0] cmd_address;
reg [7:0] cmd_num_bytes;

reg [7:0] read_bytes_received;
reg [7:0] read_byte_next;
reg read_byte_pending;

reg [7:0] write_msb_next;
reg [7:0] write_bytes_written;

always @(posedge clk_core) begin
	if (reset) begin
		read_fifo_rd_ready_int <= 1;
		write_fifo_wr_valid <= 0;
		write_fifo_wr_data <= 0;
	
		cmd_address <= 0;
		cmd_num_bytes <= 0;
		cmd_byte_index <= 0;
		
		read_bytes_received <= 0;
		read_byte_next <= 0;
		read_byte_pending <= 0;

		write_msb_next <= 0;
		write_bytes_written <= 0;
	
		wr_valid <= 0;
		cmd_valid <= 0;
		rd_ready <= 0;
	
		state <= STATE_IDLE;
	end
	else begin

		wr_valid <= 0;
		cmd_valid <= 0;
		rd_ready <= 0;
		write_fifo_wr_valid <= 0;

		case (state)
		STATE_IDLE: begin
			if (read_fifo_rd_ready && read_fifo_rd_valid) begin
				cmd_byte_index <= 1;
				case (read_fifo_rd_data)
				8'h10: begin
					read_bytes_received <= 0;
					state <= STATE_READ;
				end
				8'h20: begin
					write_bytes_written <= 0;
					state <= STATE_WRITE;
				end
				default: $display("%t Unrecognized command: %h", $realtime, read_fifo_rd_data);
				endcase
			end
		end
		STATE_READ: begin
			if (read_fifo_rd_ready && read_fifo_rd_valid) begin
				if (cmd_byte_index == 1)
					cmd_address[23:16] <= read_fifo_rd_data;
				if (cmd_byte_index == 2)
					cmd_address[15:8] <= read_fifo_rd_data;
				if (cmd_byte_index == 3)
					cmd_address[7:0] <= read_fifo_rd_data;
				if (cmd_byte_index == 4) begin
					cmd_num_bytes <= read_fifo_rd_data;
					
					//	Submit command
					cmd_valid <= 1;
					cmd_bl <= ((read_fifo_rd_data - 1) >> 1);
					cmd_addr <= cmd_address >> 1;
					cmd_instr <= INSTR_READ;

					rd_ready <= 1;
					read_bytes_received <= 0;
					state <= STATE_READ_WAITING;
				end
				cmd_byte_index <= cmd_byte_index + 1;
			end
		end
		STATE_WRITE: begin
			if (read_fifo_rd_ready && read_fifo_rd_valid) begin
			
				if (cmd_byte_index == 1)
					cmd_address[23:16] <= read_fifo_rd_data;
				if (cmd_byte_index == 2)
					cmd_address[15:8] <= read_fifo_rd_data;
				if (cmd_byte_index == 3)
					cmd_address[7:0] <= read_fifo_rd_data;
				if (cmd_byte_index == 4)
					cmd_num_bytes <= read_fifo_rd_data;
				
				if (cmd_byte_index > 4) begin
					if (!write_bytes_written[0])
						write_msb_next <= read_fifo_rd_data;
					else begin
						wr_valid <= 1;
						wr_data <= {write_msb_next, read_fifo_rd_data};
					end
					if (write_bytes_written >= cmd_num_bytes - 1) begin
						state <= STATE_WRITE_SUBMIT;

						//	TODO: flush half-word if writing odd bytes or odd start address
						if (cmd_num_bytes[0]) begin
							wr_valid <= 1;
							wr_data <= {read_fifo_rd_data, 8'h0};
						end
					end
					else
						write_bytes_written <= write_bytes_written + 1;
				end
				cmd_byte_index <= cmd_byte_index + 1;
			end
		end
		STATE_WRITE_SUBMIT: begin
			state <= STATE_IDLE;

			cmd_valid <= 1;
			cmd_bl <= ((cmd_num_bytes - 1) >> 1);
			cmd_addr <= cmd_address >> 1;
			cmd_instr <= INSTR_WRITE;
		end
		STATE_READ_WAITING: begin
			rd_ready <= 1;
			if (read_byte_pending) begin
				write_fifo_wr_valid <= 1;
				write_fifo_wr_data <= read_byte_next;
				if (write_fifo_wr_ready)
					read_byte_pending <= 0;
				if (read_bytes_received >= cmd_num_bytes)
					state <= STATE_IDLE;
			end
			if (rd_ready && rd_valid) begin
				//	We need a break, in order to write the 2 bytes. (Unless this is the last byte.)
				if (read_bytes_received != cmd_num_bytes - 1) begin
					rd_ready <= 0;
					read_byte_next <= rd_data[7:0];
					read_byte_pending <= 1;
				end
				
				//	Write the MSB of the received word.
				write_fifo_wr_valid <= 1;
				write_fifo_wr_data <= rd_data[15:8];
				
				if ((cmd_num_bytes == 1) || (read_bytes_received == cmd_num_bytes - 1)) begin
					rd_ready <= 0;
					state <= STATE_IDLE;
				end
				else
					read_bytes_received <= read_bytes_received + 2;
			end
		end
		endcase
	end
end

endmodule

