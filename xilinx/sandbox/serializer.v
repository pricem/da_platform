//  Simple serializer using an N-bit shift register.  The register is cycled
//  using the clk input and the parallel input is loaded using the load_clk input.
//  For an 8-bit register, you want a load_clk edge after every 8 clk edges 
//  (since a reset).

module serializer(load_clk, in, out, clk, reset);
    
    parameter N = 8;
    
    input load_clk;
    input clk;
    input [(N - 1):0] in;
    output reg out;
    input reset;
    
    reg [(N - 1):0] data;
    
    integer i;

    always @(posedge clk or posedge reset or posedge load_clk) begin
        if (reset) begin
            i <= 0;
            out <= 0;
            data <= 0;
        end
        else begin
            if (load_clk) begin
                data <= in;
            end
            else begin
                i <= (i + 1) % N;
                out <= data[i];
            end
        end
    end


endmodule

