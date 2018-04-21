/*
    Open-source digital audio platform
    Copyright (C) 2009--2018 Michael Price

    fifo_sync: Synchronous FIFO.
    Same read and write clock, no delay in count/full/empty.

    Warning: Use and distribution of this code is restricted.
    This HDL file is distributed under the terms of the Solderpad Hardware 
    License, Version 0.51.  Other files in this project may be subject to
    different licenses.  Please see the LICENSE file in the top level project
    directory for more information.
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

//  2/22/2018: Compensate for pending output word when computing count.
//  (This wouldn't be necessary if data was assigned combinationally.)
assign count = wr_addr_bin - rd_addr_bin + (!out.ready && out.valid);

//	Full and empty signals
wire rd_empty = (rd_addr_bin == wr_addr_bin);
wire wr_full = (wr_addr_bin == {~rd_addr_bin[M], rd_addr_bin[M-1:0]});

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

