module deserializer(clk_ser, data_ser, clk_par, data_par);

//  Models the 74164 / 74574 combination used on the isolator PCB

input clk_ser;
input data_ser;

input clk_par;
output reg [7:0] data_par;

reg [7:0] data_int;

always @(posedge clk_ser)
    data_int <= {data_int, data_ser};
    
always @(posedge clk_par)
    data_par <= data_int;

endmodule
