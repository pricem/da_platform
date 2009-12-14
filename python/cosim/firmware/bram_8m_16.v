//
// Single-Port RAM with Synchronous Read (Read Through)
// From XST manual
// Doesn't actually hold as much as it should
//
module bram_8m_16 (clk, we, addr, din, dout);
    input clk;
    input we;
    input [22:0] addr;
    input [15:0] din;
    output reg [15:0] dout;
    //  Should be larger in reality.  This is big enough for simulation.
    reg [15:0] ram[65536:0];
    always @(posedge clk) begin
        if (we)
            ram[addr[15:0]] <= din;
        dout <= ram[addr];
        end
endmodule
