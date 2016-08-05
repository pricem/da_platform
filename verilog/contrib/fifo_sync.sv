/*
    Automatic speech recognition processor (asrv2)

    Copyright 2014 MIT
    Author: Michael Price (pricem@mit.edu)
    
    Use and distribution of this code is restricted.
    See LICENSE file in top level project directory.
*/

/*
    Synchronous FIFO based on registers.
    TODO: Test.
*/

`timescale 1ns / 1ps

module fifo_sync_sv #(
    width = 8,
    depth = 8,
    debug_display = 0
) (
    ClockReset.client cr,
    FIFOInterface.in in,
    FIFOInterface.out out,
    output logic [$clog2(depth) : 0] count
);
    localparam M = $clog2(depth);

    //	Addresses used by memory
    logic [M : 0] wr_addr_bin;
    logic [M : 0] rd_addr_bin;

    //	Full and empty signals
    logic rd_empty;
    logic wr_full;

    //	Memory array
    logic [width - 1 : 0] data[depth - 1 : 0];

    always_comb begin
        count = wr_addr_bin - rd_addr_bin;
        
        rd_empty = (rd_addr_bin == wr_addr_bin);
        wr_full = (wr_addr_bin == {~rd_addr_bin[M], rd_addr_bin[M - 1 : 0]});
        
        in.ready = !wr_full;
        //  Experiment (4/3/2015): have enable always high when data is ready
        out.enable = !rd_empty; //  (out.ready && !rd_empty);
        out.data[width - 1 : 0] = data[rd_addr_bin[M - 1 : 0]];
    end

    always @(posedge cr.clk) if (cr.reset) begin
		wr_addr_bin <= 0;
		rd_addr_bin <= 0;
	end
	else begin
		//	Handle writing of data and incrementing of binary counter	
		if (in.enable) if (in.ready) begin
			data[wr_addr_bin[M - 1 : 0]] <= in.data[width - 1 : 0];
			wr_addr_bin <= wr_addr_bin + 1;
			if (debug_display)
			    $display("%t: Sync FIFO %m accepted write data %h to location %h", $time, in.data, wr_addr_bin[M - 1 : 0]);
		end
		/*
		else
			$display("%t: ERROR: Writing to full FIFO %m", $time);
		*/
		//	Handle incrementing binary counter when data is read out
		//  Experiment (4/3/2015): have enable always high when data is ready
		if (out.enable && out.ready) begin
			rd_addr_bin <= rd_addr_bin + 1;
			if (debug_display)
			    $display("%t: Sync FIFO %m provided read data %h from location %h", $time, out.data, rd_addr_bin[M-1:0]);
		end
	end


    //  Non-functional lost data detection
    logic [width - 1 : 0] write_input_prev;
    logic write_enable_prev;
    logic write_ready_prev;
    always @(posedge cr.clk) if (cr.reset) begin
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


