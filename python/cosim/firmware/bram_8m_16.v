//
// Single-Port RAM with Synchronous Read (Read Through)
// From XST manual
// Doesn't actually hold as much as it should
//
module bram_8m_16 (clk, we, oe, addr, din, dout, reset);
    input clk;
    input we;
    input oe;
    input [22:0] addr;
    input [15:0] din;
    output reg [15:0] data_out;
    output [15:0] dout;
    input reset;
    
    //  Should be larger in reality.  This is big enough for simulation.
    reg [15:0] ram[65536:0];
    
    assign dout = oe ? data_out : 16'hZZZZ;
    
    always @(posedge clk) begin
        if (reset)
            data_out <= 0;
        else begin
            if (we) begin
                $display("Wrote %s to big memory address %d at time %d.", din, addr, $time);
                ram[addr[15:0]] <= din;
            end
            data_out <= ram[addr];
        end
    end
endmodule
