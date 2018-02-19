`timescale 1ns / 1ps

module serializer #(
    parameter logic launch_negedge = 1,
    parameter logic default_val = 1
) (
    input clk_ser, 
    output logic data_ser, 
    input clk_par,
    input [7:0] data_par
);

//  Models the 74165 used on the isolator PCB

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
    logic [7:0] data_int;

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

