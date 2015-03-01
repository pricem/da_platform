`timescale 1ns / 1ps

/*	FIFO model	*/
module fifo_async(
	reset,
	wr_clk, wr_valid, wr_data,
	wr_ready, wr_count,
	rd_clk, rd_valid,
	rd_ready, rd_data, rd_count
);

parameter Nb = 8;
parameter M = 2;
parameter N = (1 << M);

input reset;

input wr_clk;
input wr_valid				/*	synthesis syn_keep = 1	*/;
input [Nb-1:0] wr_data		/*	synthesis syn_keep = 1	*/;
output wr_ready			    /*	synthesis syn_keep = 1	*/;
output reg [M:0] wr_count	/*	synthesis syn_keep = 1	*/;

input rd_clk;
input rd_ready				/*	synthesis syn_keep = 1	*/;
output reg rd_valid			/*	synthesis syn_keep = 1	*/;
output reg [Nb-1:0] rd_data	/*	synthesis syn_keep = 1	*/;
output reg [M:0] rd_count	/*	synthesis syn_keep = 1	*/;

reg rd_empty;
reg wr_full;
assign wr_ready = !wr_full;

//	Addresses used by memory
reg [M:0] wr_addr_bin;
reg [M:0] rd_addr_bin;

//	Gray code versions of counter for read and write addresses
//	Keep an extra bit so we can tell when there is a wrap-around and the FIFO is full.
reg [M:0] wr_addr_gray;
reg [M:0] rd_addr_gray;

//	Registers for synchronization of counters
reg [M:0] wr_addr_mid;
reg [M:0] wr_addr_syncrd;
reg [M:0] rd_addr_mid;
reg [M:0] rd_addr_syncwr;

//	Memory array
reg [Nb-1:0] data[N-1:0];

//	Updates to binary and Gray code addresses based on inputs
wire [M:0] wr_addr_bin_next = wr_addr_bin + (wr_valid & ~wr_full);
wire [M:0] wr_addr_gray_next = (wr_addr_bin_next >> 1) ^ wr_addr_bin_next;

wire [M:0] rd_addr_bin_next = rd_addr_bin + (rd_ready & ~rd_empty);
wire [M:0] rd_addr_gray_next = (rd_addr_bin_next >> 1) ^ rd_addr_bin_next;

//	Full and empty signals based on synchronized Gray code counters
wire rd_empty_next = (rd_addr_gray_next == wr_addr_syncrd);
wire wr_full_next = (wr_addr_gray_next == {~rd_addr_syncwr[M:M-1], rd_addr_syncwr[M-2:0]});

//	Synchronous count outputs, which might be a little behind (Gray to binary conversion)
integer i;
reg [M:0] wr_addr_sync_bin;
reg [M:0] rd_addr_sync_bin;
wire [M:0] wr_count_next;
wire [M:0] rd_count_next;
always @(wr_addr_syncrd)
	for (i = 0; i < M + 1; i = i + 1)
		wr_addr_sync_bin[i] = ^(wr_addr_syncrd >> i);
always @(rd_addr_syncwr)
	for (i = 0; i < M + 1; i = i + 1)
		rd_addr_sync_bin[i] = ^(rd_addr_syncwr >> i);
assign rd_count_next = wr_addr_sync_bin - rd_addr_bin_next;
assign wr_count_next = wr_addr_bin_next - rd_addr_sync_bin;

always @(posedge wr_clk) begin
	if (reset) begin
		wr_addr_bin <= 0;
		wr_addr_gray <= 0;
		
		wr_full <= 0;
		wr_count <= 0;

		rd_addr_mid <= 0;
		rd_addr_syncwr <= 0;
	end
	else begin
		//	Update full flag and counters
		wr_full <= wr_full_next;
		wr_addr_bin <= wr_addr_bin_next;
		wr_addr_gray <= wr_addr_gray_next;
		wr_count <= wr_count_next;
	
		//	Synchronize counter coming from read domain
		{rd_addr_syncwr, rd_addr_mid} <= {rd_addr_mid, rd_addr_gray};
	
		//	Handle writing of data
		if (wr_valid && !wr_full)
			data[wr_addr_bin[M-1:0]] <= wr_data;
	end
end

always @(posedge rd_clk) begin
	if (reset) begin
		rd_addr_bin <= 0;
		rd_addr_gray <= 0;
		
		rd_data <= 0;
		rd_empty <= 1;
		rd_valid <= 0;
		rd_count <= 0;
		
		wr_addr_mid <= 0;
		wr_addr_syncrd <= 0;
	end
	else begin
		//	Update empty flag and counters
		rd_empty <= rd_empty_next;
		rd_addr_bin <= rd_addr_bin_next;
		rd_addr_gray <= rd_addr_gray_next;
		rd_count <= rd_count_next;
	
		//	Synchronize counter coming from write domain
		{wr_addr_syncrd, wr_addr_mid} <= {wr_addr_mid, wr_addr_gray};
	
		//	Handle reading of data and incrementing of binary counter
		if (rd_ready && !rd_empty) begin
			rd_data <= data[rd_addr_bin[M-1:0]];
			rd_valid <= 1;
		end
		else begin
		    if (rd_empty && rd_ready)
    		    rd_valid <= 0;
		end
	end
end

endmodule

