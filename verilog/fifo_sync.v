`timescale 1ns / 1ps

/*	FIFO model - synchronous (same read and write clock, no delay in count/full/empty)	*/
module fifo_sync(
	clk, reset,
	wr_valid, wr_data,
	wr_ready,
	rd_ready,
	rd_valid, rd_data,
	count
);

parameter Nb = 8;
parameter M = 2;
parameter N = (1 << M);

parameter debug_display = 0;

input clk;
input reset;

input wr_valid					/*	synthesis syn_keep = 1	*/;
input [Nb-1:0] wr_data			/*	synthesis syn_keep = 1	*/;
output wr_ready					/*	synthesis syn_keep = 1	*/;

input rd_ready					/*	synthesis syn_keep = 1	*/;
output reg rd_valid				/*	synthesis syn_keep = 1	*/;
output reg [Nb-1:0] rd_data		/*	synthesis syn_keep = 1	*/;

output [M:0] count				/*	synthesis syn_keep = 1	*/;

//	Addresses used by memory
reg [M:0] wr_addr_bin;
reg [M:0] rd_addr_bin;

//	Memory array
reg [Nb-1:0] data[N-1:0];

assign count = wr_addr_bin - rd_addr_bin;

//	Full and empty signals
wire rd_empty = (rd_addr_bin == wr_addr_bin);
wire wr_full = (wr_addr_bin == {~rd_addr_bin[M], rd_addr_bin[M-1:0]});

assign wr_ready = !wr_full;

always @(posedge clk) begin
	if (reset) begin
		wr_addr_bin <= 0;
		rd_addr_bin <= 0;
		rd_data <= 0;
		rd_valid <= 0;
	end
	else begin
		//	Handle writing of data and incrementing of binary counter	
		if (wr_valid && !wr_full) begin
			data[wr_addr_bin[M-1:0]] <= wr_data;
			wr_addr_bin <= wr_addr_bin + 1;
			if (debug_display)
			    $display("Sync FIFO %m accepted write data %h to location %h at time %t", wr_data, wr_addr_bin[M-1:0], $time);
		end
		
		//	Handle reading of data and incrementing binary counter
		if (rd_ready && !rd_empty) begin
			rd_data <= data[rd_addr_bin[M-1:0]];
			rd_valid <= 1;
			rd_addr_bin <= rd_addr_bin + 1;
			if (debug_display)
			    $display("Sync FIFO %m provided read data %h from location %h at time %t", data[rd_addr_bin[M-1:0]], rd_addr_bin[M-1:0], $time);
		end
		else begin
		    if (rd_empty && rd_ready)
    		    rd_valid <= 0;
		end
		
	end
end

endmodule

