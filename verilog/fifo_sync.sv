/*	FIFO model - synchronous (same read and write clock, no delay in count/full/empty)	

    Adapted to use SV interfaces by Michael Price 12/28/2017
*/

`timescale 1ns / 1ps

module fifo_sync #(
    parameter int Nb = 8,
    parameter int M = 2,
    parameter int N = (1 << M)
) (
    input clk,
	input reset,
	FIFOInterface.in in,
	FIFOInterface.out out,
	output logic [M:0] count
);

//	Addresses used by memory
logic [M:0] wr_addr_bin;
logic [M:0] rd_addr_bin;

//	Memory array
logic [Nb-1:0] data[N-1:0];

assign count = wr_addr_bin - rd_addr_bin;

//	Full and empty signals
logic rd_empty = (rd_addr_bin == wr_addr_bin);
logic wr_full = (wr_addr_bin == {~rd_addr_bin[M], rd_addr_bin[M-1:0]});

always_comb in.ready = !wr_full;

always_ff @(posedge clk) begin
	if (reset) begin
		wr_addr_bin <= 0;
		rd_addr_bin <= 0;
		out.data <= 0;
		out.valid <= 0;
	end
	else begin
		//	Handle writing of data and incrementing of binary counter	
		if (in.valid && !wr_full) begin
			data[wr_addr_bin[M-1:0]] <= in.data;
			wr_addr_bin <= wr_addr_bin + 1;
		end
		
		//	Handle reading of data and incrementing binary counter
		if (out.ready && !rd_empty) begin
			out.data <= data[rd_addr_bin[M-1:0]];
			out.valid <= 1;
			rd_addr_bin <= rd_addr_bin + 1;
		end
		else begin
		    if (rd_empty && out.ready)
    		    out.valid <= 0;
		end
		
	end
end

endmodule

