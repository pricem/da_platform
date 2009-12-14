//
//  Dual-Port RAM with Asynchronous Read
//  From XST 11.3 manual page 142
//

module bram_2k_8 (clk, we, a, dpra, di, spo, dpo);
    input clk;
    input we;
    input [10:0] a;
    input [10:0] dpra;
    input [7:0] di;
    output reg [7:0] spo;
    output reg [7:0] dpo;
    reg [7:0] ram[2047:0];
    always @(posedge clk) begin
        if (we) begin
            $display("Wrote %c to address %d.", di, a);
            ram[a] <= di;
        end
        spo <= ram[a];
        dpo <= ram[dpra];
    end
endmodule
