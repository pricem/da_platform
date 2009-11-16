module dut_tracking_fifo;

    reg clk_in;
    reg [7:0] data_in;
    reg write_in;
    reg clk_out;
    wire [7:0] data_out;
    reg read_out;
    wire [10:0] addr_in;
    wire [10:0] addr_out;
    reg reset;
    
    initial begin
        $from_myhdl(clk_in, data_in, write_in, clk_out, read_out, reset);
        $to_myhdl(data_out, addr_in, addr_out);
    end
    
    tracking_fifo dut (.clk_in(clk_in), .data_in(data_in), .write_in(write_in), .clk_out(clk_out), .data_out(data_out), .read_out(read_out), .addr_in(addr_in), .addr_out(addr_out), .reset(reset));
    
endmodule

