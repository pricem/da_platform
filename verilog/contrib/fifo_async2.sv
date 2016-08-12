/*
    Automatic speech recognition processor (asrv2)

    Copyright 2014 MIT
    Author: Michael Price (pricem@mit.edu)
    
    Use and distribution of this code is restricted.
    See LICENSE file in top level project directory.
*/

/*
    Aynchronous FIFO based on registers.
    A reset from either clock domain will reset both the input and output sides.
*/

`timescale 1ns / 1ps

module fifo_async_sv2 #(
    width = 8,
    depth = 8,
    debug_display = 0
) (
    input clk_in,
    input reset_in,
	FIFOInterface.in in,
	output logic [$clog2(depth) : 0] count_in,
    input clk_out,
    input reset_out,
	FIFOInterface.out out,
	output logic [$clog2(depth) : 0] count_out
);

    localparam M = $clog2(depth);

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
    logic [width - 1 : 0] data[depth - 1 : 0];

    //	Updates to binary and Gray code addresses based on inputs
    logic [M:0] wr_addr_bin_next;
    logic [M:0] wr_addr_gray_next;

    logic [M:0] rd_addr_bin_next;
    logic [M:0] rd_addr_gray_next;

    //	Full and empty signals based on synchronized Gray code counters
    logic rd_empty_next;
    logic wr_full_next;

    //	Synchronous count outputs, which might be a little behind (Gray to binary conversion)
    int i;
    logic [M:0] wr_addr_sync_bin;
    logic [M:0] rd_addr_sync_bin;
    logic [M:0] wr_count_next;
    logic [M:0] rd_count_next;
    
    always_comb begin
        wr_addr_bin_next = wr_addr_bin + (in.enable && in.ready);
        wr_addr_gray_next = (wr_addr_bin_next >> 1) ^ wr_addr_bin_next;

        rd_addr_bin_next = rd_addr_bin + (out.enable && out.ready);
        rd_addr_gray_next = (rd_addr_bin_next >> 1) ^ rd_addr_bin_next;
        
        rd_empty_next = (rd_addr_gray_next == wr_addr_syncrd);
        wr_full_next = (wr_addr_gray_next == {~rd_addr_syncwr[M:M-1], rd_addr_syncwr[M-2:0]});
        
        for (i = 0; i < M + 1; i = i + 1)
    		wr_addr_sync_bin[i] = ^(wr_addr_syncrd >> i);
        for (i = 0; i < M + 1; i = i + 1)
    		rd_addr_sync_bin[i] = ^(rd_addr_syncwr >> i);
    		
        rd_count_next = wr_addr_sync_bin - rd_addr_bin_next;
        wr_count_next = wr_addr_bin_next - rd_addr_sync_bin;
    end
    
    //	Reset protection on input side
    logic [1:0] cr_out_reset_sync;
    always @(posedge clk_in) cr_out_reset_sync <= {cr_out_reset_sync[0], reset_out};

    logic temp_val;

    logic in_osc_counter;

    always @(posedge clk_in) if (reset_in || cr_out_reset_sync[1]) begin
		wr_addr_bin <= 0;
		wr_addr_gray <= 0;
		
		if (debug_display) $display("%t %m: reset, in.ready <= 1", $time);
		in.ready <= 1;
		count_in <= 0;

		rd_addr_mid <= 0;
		rd_addr_syncwr <= 0;
		
		in_osc_counter <= 0;
	end
	else begin
		//	Update full flag and counters
		in.ready <= !wr_full_next;
		wr_addr_bin <= wr_addr_bin_next;
		wr_addr_gray <= wr_addr_gray_next;
		//  if (debug_display) $display("%t %m: loading wr_addr_bin_next = %h wr_addr_gray_next = %h", $time, wr_addr_bin_next, wr_addr_gray_next);
		count_in <= wr_count_next;
		
		in_osc_counter <= !in_osc_counter;
		
		//  Vivado hack
		temp_val = 0;
		if (!wr_full_next) begin
		      //  if (debug_display) $display("%t %m: not full, setting in.ready = 1", $time);
		    in.ready <= 1;
		    temp_val = 1;
		end
	
		//	Synchronize counter coming from read domain
		{rd_addr_syncwr, rd_addr_mid} <= {rd_addr_mid, rd_addr_gray};
	
		//	Handle writing of data
		if (in.enable && in.ready) begin
			data[wr_addr_bin[M-1:0]] <= in.data[width - 1 : 0];
			if (debug_display) $display("%t %m: writing data %h to index %h", $time, in.data[width - 1 : 0], wr_addr_bin[M-1:0]);
        end
	end

	//	Reset protection on output side
	logic [1:0] cr_in_reset_sync;
	always @(posedge clk_out) cr_in_reset_sync <= {cr_in_reset_sync[0], reset_in};

    logic out_osc_counter;

    always @(posedge clk_out) if (reset_out || cr_in_reset_sync[1]) begin
		rd_addr_bin <= 0;
		rd_addr_gray <= 0;
		
		out.data[width - 1 : 0] <= 0;
	    out.enable <= 0;
		//  out_enable_dup <= 0;
		count_out <= 0;
		
		wr_addr_mid <= 0;
		wr_addr_syncrd <= 0;
		
		out_osc_counter <= 0;
	end
	else begin
		//	Update empty flag and counters
		//  Note: enable signal has changed based on FIFO discipline
		//  out.enable <= (out.ready && !rd_empty_next);
		//  out.enable <= !rd_empty_next;
		
		out_osc_counter <= !out_osc_counter;

		if (!rd_empty_next) begin
		    //  Note 1/30/2015: Was there seriously a bug here all this time?
		    //  out.data <= data[rd_addr_bin[M-1:0]];
		    out.data[width - 1 : 0] <= data[rd_addr_bin_next[M-1:0]];
		    out.enable <= 1;
		    if (debug_display && out.ready) $display("%t %m set out.enable = 1 data = %h", $time, data[rd_addr_bin_next[M-1:0]]);
        end
        else begin
            out.enable <= 0;
            //  if (debug_display) $display("%t %m set out.enable = 0", $time);
        end
        
		rd_addr_bin <= rd_addr_bin_next;
		rd_addr_gray <= rd_addr_gray_next;
		count_out <= rd_count_next;
	
		//	Synchronize counter coming from write domain
		{wr_addr_syncrd, wr_addr_mid} <= {wr_addr_mid, wr_addr_gray};
	end

    //  Non-functional lost data detection
    logic [width - 1 : 0] write_input_prev;
    logic write_enable_prev;
    logic write_ready_prev;
    always @(posedge clk_in) if (reset_in) begin
        write_input_prev <= 0;
        write_enable_prev <= 0;
        write_ready_prev <= 0;
    end
    else begin
        write_input_prev <= in.data;
        write_enable_prev <= in.enable;
        write_ready_prev <= in.ready;
        if (write_enable_prev && !write_ready_prev && (in.data[width - 1 : 0] != write_input_prev))
            $display("%t %m Warning: write data changed while input enabled and not ready, possible data loss", $time);
    end

endmodule


