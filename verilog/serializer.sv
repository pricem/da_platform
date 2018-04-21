/*
    Open-source digital audio platform
    Copyright (C) 2009--2018 Michael Price

    serializer: 8:1 serializer.  Can model the 74165 used on the isolator PCB
    or be used within the FPGA.

    Warning: Use and distribution of this code is restricted.
    This HDL file is distributed under the terms of the Solderpad Hardware 
    License, Version 0.51.  Other files in this project may be subject to
    different licenses.  Please see the LICENSE file in the top level project
    directory for more information.
*/

`timescale 1ns / 1ps

module serializer #(
    parameter logic launch_negedge = 1,
    parameter logic default_val = 1
) (
    input clk_ser, 
    (* keep = "true" *) output logic data_ser, 
    input clk_par,
    (* keep = "true" *) input [7:0] data_par
);

//  2/27/2017: change data launch to negative edge of clk_ser

generate if (launch_negedge == 0) begin: posedge_sensitive

    //  This is what the 74165 datasheet seems to imply.
    logic [7:0] data_int;
    always @(posedge clk_ser or negedge clk_par)
        if (!clk_par)
            data_int <= data_par;
        else
            data_int <= (data_int << 1) + default_val;
    always @(*) data_ser = data_int[7];

end
else begin: negedge_sensitive

    //  New code (negedge) -- for serializers within FPGA, to make timing work at board level
    (* keep = "true" *) logic [7:0] data_int;

    wire data_ser_next;
    assign data_ser_next = data_int[7];

    always_ff @(negedge clk_ser) begin
        if (!clk_par)
            data_int <= data_par;
        else
            data_int <= (data_int << 1) + default_val;
        data_ser <= data_ser_next;
    end

end
endgenerate

endmodule

