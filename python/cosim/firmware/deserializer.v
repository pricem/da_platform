//  Simple deserializer using an N-bit shift register.  The register is cycled
//  using the clk input and propagated to the output using the load_clk input.
//  For an 8-bit register, you want a load_clk edge after every 8 clk edges 
//  (since a reset).

module deserializer(load_clk, in, out, clk, reset);
    
    parameter N = 8;
    
    input load_clk;
    input clk;
    input in;
    output reg [(N - 1):0] out;
    input reset;
    
    reg [(N - 1):0] data;

    always @(posedge clk or posedge reset) begin
        if (reset)
            data <= 0;
        else begin
            data <= (data << 1 + in);
        end
    end

    always @(posedge load_clk) begin
        out <= data;
    end
        

endmodule

