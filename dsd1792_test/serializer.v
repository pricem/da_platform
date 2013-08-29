module serializer(clk_ser, data_ser, clk_par, data_par);

//  Models the 74165 used on the isolator PCB

input clk_ser;
output data_ser;

input clk_par;
input [7:0] data_par;

reg [7:0] data_next;
always @(posedge clk_par)
    data_next <= data_par;

reg [7:0] data_int;

assign data_ser = data_int[7];

always @(negedge clk_par or posedge clk_ser) begin
    if (!clk_par)
        data_int <= data_next;
    else if (clk_par && clk_ser)
        data_int <= (data_int << 1);
end

endmodule
