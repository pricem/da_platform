module delay(
	clk, reset, sig_in, sig_out
);

parameter Nb = 1;	//	number of bits
parameter Nc = 1;	//	number of cycles
parameter initial_value = 0;

input clk;
input reset;
input [Nb-1:0] sig_in;
output [Nb-1:0] sig_out;

reg [Nb-1:0] storage [Nc-1:0];
integer i;

assign sig_out = storage[0];

always @(posedge clk) begin
	if (reset) begin
		for (i = 0; i < Nc; i=i+1)
			storage[i] <= initial_value;
	end
	else begin
		storage[Nc-1] <= sig_in;
		for (i = 0; i < Nc-1; i=i+1)
			storage[i] <= storage[i+1];
	end
end

endmodule

