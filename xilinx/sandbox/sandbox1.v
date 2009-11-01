module sandbox1 (led, switches);

input [7:0] switches;
output [7:0] led;

assign led[7:0] = switches[7:0];

endmodule
