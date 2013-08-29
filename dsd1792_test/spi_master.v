module spi_master(clk, reset, clk_serial,
    request_valid, request_data, request_ready, 
    response_valid, response_data, response_ready,
    sck, ss_out, ss_in, mosi, miso, state
);

parameter M = 2;

input clk;
input reset;
input clk_serial;

input request_valid;
input [34:0] request_data;
output request_ready;

output response_valid;
output [31:0] response_data;
input response_ready;

output sck;
output reg ss_out;
input ss_in;
output reg mosi;
input miso;

reg request_isread;
reg request_addr_bytes;
reg [15:0] request_addr_contents;
reg request_data_bytes;
reg [15:0] request_data_contents;

parameter STATE_IDLE = 4'h0;
parameter STATE_SEND_ADDR = 4'h1;
parameter STATE_SEND_DATA = 4'h2;
parameter STATE_READ_DATA = 4'h3;
parameter STATE_RESPOND = 4'h4;

output reg [3:0] state;

reg [3:0] bit_counter;
reg [4:0] num_ss_cycles;
reg [4:0] ss_cycle_counter;

assign sck = !clk_serial & !ss_in;

always @(*) begin
    case (state)
        STATE_SEND_ADDR: mosi = (request_addr_contents >> bit_counter);
        STATE_SEND_DATA: mosi = (request_data_contents >> bit_counter);
        default: mosi = 0;
    endcase
end

//  FIFOs to cross clock domain
wire [M:0] request_fifo_wr_count;
wire [M:0] request_fifo_rd_count;

wire request_fifo_rd_valid;
wire [34:0] request_fifo_rd_data;
wire request_fifo_rd_ready;

fifo_async request_fifo(
	.reset(reset),
	.wr_clk(clk), 
	.wr_valid(request_valid), 
	.wr_data(request_data),
	.wr_ready(request_ready), 
	.wr_count(request_fifo_wr_count),
	.rd_clk(clk_serial), 
	.rd_valid(request_fifo_rd_valid),
	.rd_ready(request_fifo_rd_ready), 
	.rd_data(request_fifo_rd_data), 
	.rd_count(request_fifo_rd_count)
);
defparam request_fifo.Nb = 35;
defparam request_fifo.M = M;


wire [M:0] response_fifo_wr_count;
wire [M:0] response_fifo_rd_count;

reg response_fifo_wr_valid;
reg [31:0] response_fifo_wr_data;
wire response_fifo_wr_ready;

fifo_async response_fifo(
	.reset(reset),
	.wr_clk(clk_serial), 
	.wr_valid(response_fifo_wr_valid), 
	.wr_data(response_fifo_wr_data),
	.wr_ready(response_fifo_wr_ready), 
	.wr_count(response_fifo_wr_count),
	.rd_clk(clk), 
	.rd_valid(response_valid),
	.rd_ready(response_ready), 
	.rd_data(response_data), 
	.rd_count(response_fifo_rd_count)
);
defparam response_fifo.Nb = 32;
defparam response_fifo.M = M;


assign request_fifo_rd_ready = (state == STATE_IDLE);

always @(posedge clk_serial) begin
    if (reset) begin
        request_isread <= 0;
        request_addr_bytes <= 0;
        request_addr_contents <= 0;
        request_data_bytes <= 0;
        request_data_contents <= 0;
        
        response_fifo_wr_valid <= 0;
        response_fifo_wr_data <= 0;
        
        ss_out <= 1;
        bit_counter <= 0;
        num_ss_cycles <= 0;
        ss_cycle_counter <= 0;
        
        state <= STATE_IDLE;
        
    end
    else begin
        response_fifo_wr_valid <= 0;
    
        if (ss_out == 0) begin
            if (ss_cycle_counter < num_ss_cycles)
                ss_cycle_counter <= ss_cycle_counter + 1;
            else begin
                ss_cycle_counter <= 0;
                ss_out <= 1;
            end
        end
    
        case (state)
        STATE_IDLE: begin
            if (request_fifo_rd_valid) begin
                
                {request_isread, request_addr_bytes, request_data_bytes, request_addr_contents, request_data_contents} <= request_fifo_rd_data;
                if (request_fifo_rd_data[33])   //  request_addr_bytes
                    bit_counter <= 15;
                else
                    bit_counter <= 7;
                    
                ss_out <= 0;
                ss_cycle_counter <= 0;
                if (request_fifo_rd_data[33] && request_fifo_rd_data[32])   //  request_addr_bytes, request_data_bytes
                    num_ss_cycles <= 32;
                else if (request_fifo_rd_data[33] || request_fifo_rd_data[32])
                    num_ss_cycles <= 24;
                else
                    num_ss_cycles <= 16;
                    
                state <= STATE_SEND_ADDR;
            end
        end
        STATE_SEND_ADDR: if (!ss_in) begin
            if (bit_counter != 0)
                bit_counter <= bit_counter - 1;
            else begin
                if (request_data_bytes)
                    bit_counter <= 15;
                else
                    bit_counter <= 7;
                if (request_isread)
                    state <= STATE_READ_DATA;
                else
                    state <= STATE_SEND_DATA;
            end
        end
        STATE_SEND_DATA: if (!ss_in) begin
            if (bit_counter != 0)
                bit_counter <= bit_counter - 1;
            else
                state <= STATE_IDLE;
        end
        STATE_READ_DATA: if (!ss_in) begin
            response_fifo_wr_data <= {response_fifo_wr_data, miso};
            if (bit_counter != 0)
                bit_counter <= bit_counter - 1;
            else begin
                response_fifo_wr_data[31:16] <= request_addr_contents;
                state <= STATE_RESPOND;
            end
        end
        STATE_RESPOND: begin
        	response_fifo_wr_valid <= 1;
            state <= STATE_IDLE;
        end
        endcase
        
    end
end

endmodule
