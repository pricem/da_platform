module serializer #(parameter launch_negedge = 1) (clk_ser, data_ser, clk_par, data_par);

//  Models the 74165 used on the isolator PCB

input clk_ser;
output reg data_ser;

input clk_par;
input [7:0] data_par;


/*
//  Original code (posedge)
    reg [7:0] data_next;
    always @(posedge clk_par)
        data_next <= data_par;

    reg [7:0] data_int;

    always @(*) data_ser = data_int[7];

    always @(negedge clk_par or posedge clk_ser) begin
        if (!clk_par)
            data_int <= data_next;
        else if (clk_par && clk_ser)
            data_int <= (data_int << 1);
    end
*/

//  2/27/2017: change data launch to negative edge of clk_ser

generate if (launch_negedge == 0) begin: posedge_sensitive

    //  This is what the 74165 datasheet seems to imply.
    reg [7:0] data_int;
    always @(posedge clk_ser or negedge clk_par)
        if (!clk_par)
            data_int <= data_par;
        else
            data_int <= (data_int << 1);
    always @(*) data_ser = data_int[7];

end
else begin: negedge_sensitive

    //  New code (negedge) -- for serializers within FPGA, to make timing work at board level
    reg [7:0] data_int;

    wire data_ser_next;
    assign data_ser_next = data_int[7];

    always @(negedge clk_ser) begin
        if (!clk_par)
            data_int <= data_par;
        else
            data_int <= (data_int << 1);
        data_ser <= data_ser_next;
    end

end
endgenerate

endmodule

