/*
    Open-source digital audio platform
    Copyright (C) 2009--2018 Michael Price

    fifo_async: Asynchronous FIFO.  
    Based on Cliff Cummings' design described in:
    "Simulation and Synthesis Techniques for Asynchronous FIFO Design"
    http://www.sunburst-design.com/papers/CummingsSNUG2002SJ_FIFO1.pdf

    Warning: Use and distribution of this code is restricted.
    This HDL file is distributed under the terms of the Solderpad Hardware 
    License, Version 0.51.  Other files in this project may be subject to
    different licenses.  Please see the LICENSE file in the top level project
    directory for more information.
*/

`timescale 1ns / 1ps

module fifo_async #(
    parameter int Nb = 8,
    parameter int M = 2,
    parameter int N = (1 << M)
) (
	input reset,
	FIFOInterface.in in,
	output logic [M:0] in_count,
	FIFOInterface.out out,
	output logic [M:0] out_count
);

logic rd_empty;
logic wr_full;
assign in.ready = !wr_full;

//	Addresses used by memory
logic [M:0] wr_addr_bin;
logic [M:0] rd_addr_bin;

//	Gray code versions of counter for read and write addresses
//	Keep an extra bit so we can tell when there is a wrap-around and the FIFO is full.
logic [M:0] wr_addr_gray;
logic [M:0] rd_addr_gray;

//	Registers for synchronization of counters
logic [M:0] wr_addr_mid;
logic [M:0] wr_addr_syncrd;
logic [M:0] rd_addr_mid;
logic [M:0] rd_addr_syncwr;

//	Memory array
logic [Nb-1:0] data[N-1:0];

//	Updates to binary and Gray code addresses based on inputs
wire [M:0] wr_addr_bin_next = wr_addr_bin + (in.valid & ~wr_full);
wire [M:0] wr_addr_gray_next = (wr_addr_bin_next >> 1) ^ wr_addr_bin_next;

wire [M:0] rd_addr_bin_next = rd_addr_bin + (out.ready & ~rd_empty);
wire [M:0] rd_addr_gray_next = (rd_addr_bin_next >> 1) ^ rd_addr_bin_next;

//	Full and empty signals based on synchronized Gray code counters
wire rd_empty_next = (rd_addr_gray_next == wr_addr_syncrd);
wire wr_full_next = (wr_addr_gray_next == {~rd_addr_syncwr[M:M-1], rd_addr_syncwr[M-2:0]});

//	Synchronous count outputs, which might be a little behind (Gray to binary conversion)
logic [M:0] wr_addr_sync_bin;
logic [M:0] rd_addr_sync_bin;
wire [M:0] wr_count_next;
wire [M:0] rd_count_next;
always_comb
	for (int i = 0; i < M + 1; i = i + 1)
		wr_addr_sync_bin[i] = ^(wr_addr_syncrd >> i);
always_comb
	for (int i = 0; i < M + 1; i = i + 1)
		rd_addr_sync_bin[i] = ^(rd_addr_syncwr >> i);
assign rd_count_next = wr_addr_sync_bin - rd_addr_bin_next;
assign wr_count_next = wr_addr_bin_next - rd_addr_sync_bin;

always_ff @(posedge in.clk) begin
	if (reset) begin
		wr_addr_bin <= 0;
		wr_addr_gray <= 0;
		
		wr_full <= 0;
		in_count <= 0;

		rd_addr_mid <= 0;
		rd_addr_syncwr <= 0;
	end
	else begin
		//	Update full flag and counters
		wr_full <= wr_full_next;
		wr_addr_bin <= wr_addr_bin_next;
		wr_addr_gray <= wr_addr_gray_next;
		in_count <= wr_count_next;
	
		//	Synchronize counter coming from read domain
		{rd_addr_syncwr, rd_addr_mid} <= {rd_addr_mid, rd_addr_gray};
	
		//	Handle writing of data
		if (in.valid && !wr_full)
			data[wr_addr_bin[M-1:0]] <= in.data;
	end
end

always_ff @(posedge out.clk) begin
	if (reset) begin
		rd_addr_bin <= 0;
		rd_addr_gray <= 0;
		
		out.data <= 0;
		rd_empty <= 1;
		out.valid <= 0;
		out_count <= 0;
		
		wr_addr_mid <= 0;
		wr_addr_syncrd <= 0;
	end
	else begin
		//	Update empty flag and counters
		rd_empty <= rd_empty_next;
		rd_addr_bin <= rd_addr_bin_next;
		rd_addr_gray <= rd_addr_gray_next;
		out_count <= rd_count_next;
	
		//	Synchronize counter coming from write domain
		{wr_addr_syncrd, wr_addr_mid} <= {wr_addr_mid, wr_addr_gray};
	
		//	Handle reading of data and incrementing of binary counter
		if (out.ready && !rd_empty) begin
			out.data <= data[rd_addr_bin[M-1:0]];
			out.valid <= 1;
		end
		else begin
		    if (rd_empty && out.ready)
    		    out.valid <= 0;
		end
	end
end

endmodule

