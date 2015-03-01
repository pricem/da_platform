module clk_divider(reset, clkin, clkout);

parameter ratio = 3;
parameter B = 16;
parameter threshold = ratio / 2;

input reset;
input clkin;
output reg clkout;

reg [B-1:0] counter	/*	synthesis syn_keep = 1	*/;

initial begin
    counter <= 0;
    clkout <= 0;
end

always @(posedge clkin) begin
	if (reset) begin
		counter <= 0;
		clkout <= 0;
	end
	else begin
		if (counter < ratio - 1)
			counter <= counter + 1;
		else
			counter <= 0;
			
		if (counter < threshold)
			clkout <= 1;
		else
			clkout <= 0;
	end
end

endmodule

