`timescale 1ns / 1ps

module spi_master #(
    parameter int M = 2
) (
    input clk,
    input reset,
    input clk_serial,

    FIFOInterface.in request,
    FIFOInterface.out response,

    output logic sck,
    output logic ss_out,
    input ss_in,
    output logic mosi,
    input miso,
    
    output logic [3:0] state
);

reg request_isread;
reg request_addr_bytes;
reg [15:0] request_addr_contents;
reg request_data_bytes;
reg [15:0] request_data_contents;

localparam STATE_IDLE = 4'h0;
localparam STATE_SEND_ADDR = 4'h1;
localparam STATE_SEND_DATA = 4'h2;
localparam STATE_READ_DATA = 4'h3;
localparam STATE_RESPOND = 4'h4;

reg [5:0] bit_counter;
reg [5:0] num_ss_cycles;
reg [5:0] ss_cycle_counter;

assign sck = !clk_serial & !ss_in;

always_comb begin
    case (state)
        STATE_SEND_ADDR: mosi = (request_addr_contents >> bit_counter);
        STATE_SEND_DATA: mosi = (request_data_contents >> bit_counter);
        default: mosi = 0;
    endcase
end

//  FIFOs to cross clock domain
wire [M:0] request_fifo_wr_count;
wire [M:0] request_fifo_rd_count;

FIFOInterface #(.num_bits(35)) request_int(clk_serial);

fifo_async #(.Nb(35), .M(M)) request_fifo(
	.reset,
	.in(request),
	.in_count(request_fifo_wr_count),
	.out(request_int.out),
	.out_count(request_fifo_rd_count)
);

wire [M:0] response_fifo_wr_count;
wire [M:0] response_fifo_rd_count;

FIFOInterface #(.num_bits(32)) response_int(clk_serial);

fifo_async #(.Nb(32), .M(M)) response_fifo(
	.reset,
	.in(response_int.in),
	.in_count(response_fifo_wr_count),
	.out(response),
	.out_count(response_fifo_rd_count)
);

assign request_int.ready = (state == STATE_IDLE);

always @(posedge clk_serial) begin
    if (reset) begin
        request_isread <= 0;
        request_addr_bytes <= 0;
        request_addr_contents <= 0;
        request_data_bytes <= 0;
        request_data_contents <= 0;
        
        response_int.valid <= 0;
        response_int.data <= 0;
        
        ss_out <= 1;
        bit_counter <= 0;
        num_ss_cycles <= 0;
        ss_cycle_counter <= 0;
        
        state <= STATE_IDLE;
        
    end
    else begin
        response_int.valid <= 0;
    
        if (ss_out == 0) begin
            if (ss_cycle_counter < num_ss_cycles - 1)
                ss_cycle_counter <= ss_cycle_counter + 1;
            else begin
                ss_cycle_counter <= 0;
                ss_out <= 1;
            end
        end
    
        case (state)
        STATE_IDLE: begin
            if (request_int.valid && request_int.ready) begin
                
                {request_isread, request_addr_bytes, request_data_bytes, request_addr_contents, request_data_contents} <= request_int.data;
                if (request_int.data[33])   //  request_addr_bytes
                    bit_counter <= 15;
                else
                    bit_counter <= 7;
                    
                ss_out <= 0;
                ss_cycle_counter <= 0;
                if (request_int.data[33] && request_int.data[32])   //  request_addr_bytes, request_data_bytes
                    num_ss_cycles <= 32;
                else if (request_int.data[33] || request_int.data[32])
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
            response_int.data <= {response_int.data, miso};
            if (bit_counter != 0)
                bit_counter <= bit_counter - 1;
            else begin
                response_int.data[31:16] <= request_addr_contents;
                state <= STATE_RESPOND;
            end
        end
        STATE_RESPOND: begin
        	response_int.valid <= 1;
            state <= STATE_IDLE;
        end
        endcase
        
    end
end

endmodule
