/*
    Open-source digital audio platform
    Copyright (C) 2009--2018 Michael Price

    deserializer: Models the 74164 / 74574 combination used on the isolator PCB.

    Warning: Use and distribution of this code is restricted.
    This HDL file is distributed under the terms of the Solderpad Hardware 
    License, Version 0.51.  Other files in this project may be subject to
    different licenses.  Please see the LICENSE file in the top level project
    directory for more information.
*/

`timescale 1ns / 1ps

module deserializer(
    input clk_ser, 
    input data_ser, 
    input clk_par, 
    output logic [7:0] data_par
);

logic [7:0] data_int;

always_ff @(posedge clk_ser)
    data_int <= {data_int, data_ser};
    
always_ff @(posedge clk_par)
    data_par <= data_int;

endmodule

