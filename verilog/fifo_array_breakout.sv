module fifo_breakout_src #(
    width = 8,
    num_ports = 2
) (
    FIFOInterface.out fifos[num_ports],
    output logic ready[num_ports],
    input logic enable[num_ports],
    input logic [width - 1 : 0] data[num_ports]
);

genvar g;
generate for (g = 0; g < num_ports; g++) always_comb begin
    ready[g] = fifos[g].ready;
    fifos[g].enable = enable[g];
    fifos[g].data = data[g];
end
endgenerate

endmodule


module fifo_breakout_dest #(
    width = 8,
    num_ports = 2
) (
    FIFOInterface.in fifos[num_ports],
    input logic ready[num_ports],
    input logic enable[num_ports],
    output logic [width - 1 : 0] data[num_ports]
);

genvar g;
generate for (g = 0; g < num_ports; g++) always_comb begin
    fifos[g].ready = ready[g];
    enable[g] = fifos[g].enable;
    data[g] = fifos[g].data;
end
endgenerate

endmodule

