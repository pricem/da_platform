//
//  Dual-Port RAM
//  From XST 11.3 manual page 142
//

module bram_2k_8 (clk, clk2, we, we2, a, dpra, di, di2, spo, dpo, reset);
    input clk;
    input clk2;
    input we;
    input we2;
    input [10:0] a;
    input [10:0] dpra;
    input [7:0] di;
    input [7:0] di2;
    input reset;
    output reg [7:0] spo;
    output reg [7:0] dpo;
    reg [7:0] ram[2047:0];
    
    //  Initialization
    integer i;
    initial begin
        for (i = 0; i < 2048; i = i + 1)
            ram[i] <= 8'h00;
    end
    
    //  Operation
    always @(posedge clk) begin
        if (reset) begin
            spo <= 0;
            /*  Reset circuitry not actually available.
            for (i = 0; i < 2048; i = i + 1)
                ram[i] <= 0;
            */
        end
        else begin
            if (we) begin
                //  $display("Wrote %c to address %d.", di, a);
                ram[a] <= di;
            end
            spo <= ram[a];
        end
    end
    
    always @(posedge clk2) begin
        if (reset)
            dpo <= 0;
        else begin
            if (we2) begin
                ram[dpra] <= di2;
            end
            dpo <= ram[dpra];
        end
    end
endmodule
