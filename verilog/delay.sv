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

