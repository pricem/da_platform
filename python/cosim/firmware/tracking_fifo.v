//  Tracking FIFO

//  This is a FIFO with different in/out clocks that tracks and provides the
//  input and output addresses in memory. 

module tracking_fifo(clk_in, data_in, write_in, clk_out, data_out, read_out, addr_in, addr_out, full, empty, reset);

    parameter capacity = 2047;

    input clk_in;
    input [7:0] data_in;
    input write_in;
    input clk_out;
    output reg [7:0] data_out;
    input read_out;
    output reg addr_in;
    output reg addr_out;
    output full;
    output empty;
    input reset;
    
    wire [7:0] mem_data_out;
    wire [7:0] mem_data_read;
    
    always @(posedge clk_in) begin
        if (reset) begin
            addr_in <= 0;
        end
        else begin
            //  Update write address
            if (write_in)
                addr_in <= addr_in + 1;
        end
    end
    
    always @(posedge clk_out) begin
        if (reset) begin
            addr_out <= 0;
            data_out <= 0;
        end
        else begin
            //  Update read address
            if (read_out)
                addr_out <= addr_out + 1;
            //  Clock out data
            data_out <= mem_data_out;
        end
    end
    
    //  Assign flags
    assign full = (addr_in - addr_out) >= capacity;
    assign empty = (addr_in == addr_out);
    
    // RAM for holding data: read asynchronously
    bram_2k_8 ram(.clk(clk_in), .we(write_in), .a(addr_in), .dpra(addr_out), 
                  .di(data_in), .spo(mem_data_read), .dpo(mem_data_out));

endmodule
