/*
    Allow one module working in bytes to talk to another working in words.
*/

module fifo_byte_adapter(
    clk_core, reset,
    byte_wr_ready, byte_wr_valid, byte_wr_data,
    byte_rd_ready, byte_rd_valid, byte_rd_data,
    word_wr_ready, word_wr_valid, word_wr_data,
    word_rd_ready, word_rd_valid, word_rd_data
);

parameter bytes_per_word = 2;

input clk_core;
input reset;

output reg byte_wr_ready;
input byte_wr_valid;
input [7:0] byte_wr_data;

input byte_rd_ready;
output reg byte_rd_valid;
output reg [7:0] byte_rd_data;

input word_wr_ready;
output reg word_wr_valid;
output reg [bytes_per_word*8-1:0] word_wr_data;

output reg word_rd_ready;
input word_rd_valid;
input [bytes_per_word*8-1:0] word_rd_data;


//  Read port - We read the word FIFO and split up the data, acting like a byte FIFO

reg [bytes_per_word*8-1:0] current_read_word;
reg current_read_valid;
reg [3:0] byte_read_count;

always @(posedge clk_core) begin
    if (reset) begin
        current_read_word <= 0;
        byte_read_count <= 0;
        current_read_valid <= 0;
        
        word_rd_ready <= 0;
        byte_rd_valid <= 0;
        byte_rd_data <= 0;
    end
    else begin
        if (!current_read_valid)
            word_rd_ready <= 1;
        
        if (word_rd_ready && word_rd_valid) begin
            word_rd_ready <= 0;
            current_read_valid <= 1;
            if (byte_rd_ready) begin
                byte_rd_valid <= 1;
                byte_rd_data <= word_rd_data[bytes_per_word*8-1:(bytes_per_word-1)*8];
                current_read_word <= word_rd_data << 8;
                byte_read_count <= 1;
            end
            else begin
                current_read_word <= word_rd_data;
                byte_read_count <= 0;
            end
        end
        else begin
            if (byte_rd_ready && current_read_valid) begin
                byte_rd_valid <= 1;
                byte_rd_data <= current_read_word[bytes_per_word*8-1:(bytes_per_word-1)*8];
                current_read_word <= current_read_word << 8;
                byte_read_count <= byte_read_count + 1;
                if (byte_read_count >= bytes_per_word - 1) begin
                    current_read_valid <= 0;
                    word_rd_ready <= 1;
                end
            end
            else if (byte_rd_ready) begin
                byte_rd_valid <= 0;
            end
        end

    end
end


//  Write port - We act like a byte FIFO and accumulate data to write the word FIFO

reg [bytes_per_word*8-1:0] current_write_word;
reg current_write_valid;
reg [3:0] byte_write_count;

always @(posedge clk_core) begin
    if (reset) begin
        current_write_word <= 0;
        byte_write_count <= 0;
        current_write_valid <= 0;
        
        byte_wr_ready <= 0;
        word_wr_valid <= 0;
        word_wr_data <= 0;
    end
    else begin
        byte_wr_ready <= word_wr_ready;
        
        if (word_wr_ready && word_wr_valid)
            word_wr_valid <= 0;
            
        if (byte_wr_valid) begin
            current_write_word <= {current_write_word, byte_wr_data};
            if (byte_write_count >= bytes_per_word - 1) begin
                word_wr_valid <= 1;
                word_wr_data <= {current_write_word, byte_wr_data};
                byte_write_count <= 0;
            end
            else begin
                byte_write_count <= byte_write_count + 1;
            end
        end

    end
end

endmodule
