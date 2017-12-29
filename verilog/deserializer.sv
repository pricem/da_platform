`timescale 1ns / 1ps

module deserializer(
    input clk_ser, 
    input data_ser, 
    input clk_par, 
    output logic [7:0] data_par
);

//  Models the 74164 / 74574 combination used on the isolator PCB

logic [7:0] data_int;

always_ff @(posedge clk_ser)
    data_int <= {data_int, data_ser};
    
always_ff @(posedge clk_par)
    data_par <= data_int;

endmodule

