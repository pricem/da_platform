//  Tracking FIFO

//  This is a FIFO with different in/out clocks that tracks and provides the
//  input and output addresses in memory. 

module tracking_fifo(clk_in, data_in, write_in, clk_out, data_out, read_out, addr_in, addr_out, reset);

    parameter capacity = 2047;

    input clk_in;
    input [7:0] data_in;
    input write_in;
    input clk_out;
    output reg [7:0] data_out;
    input read_out;
    output reg [10:0] addr_in;
    output reg [10:0] addr_out;
    input reset;
    
    wire [7:0] mem_data_out;
    wire [7:0] mem_data_read;
    
    always @(posedge clk_in) begin
        if (reset) begin
            addr_in <= 0;
        end
        else begin
            //  Update write address
            if (write_in) begin
                addr_in <= addr_in + 1;
            end
        end
    end
    
    always @(posedge clk_out) begin
        if (reset) begin
            addr_out <= 0;
            data_out <= 0;
        end
        else begin
            //  Update read address, data
            if (read_out) begin
                //  Only advance the out address if data is available.
                if (addr_out != addr_in) begin
                    addr_out <= addr_out + 1;
                end
                data_out <= mem_data_out;
            end
            else
                data_out <= 8'hZ;
            
        end
    end
    
    // RAM for holding data: read asynchronously
    bram_2k_8 ram(.clk(clk_in), .we(write_in), .a(addr_in), .dpra(addr_out), 
                  .di(data_in), .spo(mem_data_read), .dpo(mem_data_out), .reset(reset));

endmodule
