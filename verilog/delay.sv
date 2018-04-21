/*
    Open-source digital audio platform
    Copyright (C) 2009--2018 Michael Price

    delay: Parameterized synchronizer / register slice.

    Warning: Use and distribution of this code is restricted.
    This HDL file is distributed under the terms of the Solderpad Hardware 
    License, Version 0.51.  Other files in this project may be subject to
    different licenses.  Please see the LICENSE file in the top level project
    directory for more information.
*/

`timescale 1ns / 1ps

module delay #(
    parameter int num_bits = 1,
    parameter int num_cycles = 1,
    parameter int initial_val = 0
) (
    input clk,
    input reset,
    
    input [num_bits - 1 : 0] in,
    output logic [num_bits - 1 : 0] out
);


logic [num_bits - 1 : 0] state[num_cycles];

always_comb out = state[num_cycles - 1];

always_ff @(posedge clk) begin
    if (reset) begin
        for (int i = 0; i < num_cycles; i++)
            state[i] <= initial_val;
    end
    else begin
        state[0] <= in;
        for (int i = 1; i < num_cycles; i++)
            state[i] <= state[i - 1];
    end
end

endmodule

