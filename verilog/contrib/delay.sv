/*
    Automatic speech recognition processor (asrv2)

    Copyright 2014 MIT
    Author: Michael Price (pricem@mit.edu)
    
    Use and distribution of this code is restricted.
    See LICENSE file in top level project directory.
*/

/*
    Delay/synchronization block
*/

`timescale 1 ns / 1 ps

module delay_sv #(
    num_bits = 1,
    num_cycles = 1,
    initial_value = 0
) (
    ClockReset.client cr,
	input logic [num_bits - 1 : 0] in,
	output logic [num_bits - 1 : 0] out
);

    logic [num_bits - 1 : 0] storage [num_cycles - 1 : 0];
    integer i;

    always_comb begin
        out = storage[0];
    end

    always_ff @(posedge cr.clk) if (cr.reset) begin
        for (i = 0; i < num_cycles; i = i + 1)
    		storage[i] <= initial_value;
    end
    else begin
		storage[num_cycles - 1] <= in;
		for (i = 0; i < num_cycles - 1; i = i + 1)
			storage[i] <= storage[i + 1];
    end

endmodule


