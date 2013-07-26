module slot_controller(clk_core, reset,
    ctl_rd_valid, ctl_rd_data, ctl_rd_ready,
    ctl_wr_valid, ctl_wr_data, ctl_wr_ready,
    aud_rd_valid, aud_rd_data, aud_rd_ready,
    aud_wr_valid, aud_wr_data, aud_wr_ready,
    spi_ss_out, spi_ss_in, spi_sck, spi_mosi, spi_miso,
    slot_data, slot_clk, mclk, dir, chan, acon, aovf
);

`include "commands.v"

input clk_core;
input reset;

input ctl_rd_valid;
input [7:0] ctl_rd_data;
output ctl_rd_ready;

output reg ctl_wr_valid;
output reg [7:0] ctl_wr_data;
input ctl_wr_ready;

input aud_rd_valid;
input [7:0] aud_rd_data;
output aud_rd_ready;

output reg aud_wr_valid;
output reg [7:0] aud_wr_data;
input aud_wr_ready;

output spi_ss_out;
input spi_ss_in;
output spi_sck;
output spi_mosi;
input spi_miso;

inout [5:0] slot_data;
input slot_clk;
input mclk;
input dir;
input chan;
output reg [7:0] acon;
input [1:0] aovf;



wire [5:0] slot_data_val;

//  2 channel DAC mode
reg pbck;
reg plrck;
reg pdata;
wire dbck = 0;
wire dsdr = 0;
wire dsdl = 0;
assign slot_data_val = {pbck, pdata, plrck, dbck, dsdr, dsdl};

reg slot_data_en;
assign slot_data = slot_data_en ? slot_data_val : 6'bzzzzzz;




reg [9:0] audio_clk_ratio;
reg [3:0] audio_sample_res;
reg [3:0] audio_num_channels;

reg [9:0] audio_clk_counter;

reg [23:0] audio_sample_left;
reg [23:0] audio_sample_right;

reg [23:0] audio_sample_left_next;
reg [23:0] audio_sample_right_next;

reg [3:0] audio_bytes_received;
reg [3:0] audio_bytes_requested;


//  SPI controller

reg spi_request_valid;
reg spi_request_isread;
reg spi_request_addr_bytes;
reg [15:0] spi_request_addr_contents;
reg spi_request_data_bytes;
reg [15:0] spi_request_data_contents;
wire [34:0] spi_request_data = {spi_request_isread, spi_request_addr_bytes, spi_request_data_bytes, spi_request_addr_contents, spi_request_data_contents};
wire spi_request_ready;

wire spi_response_valid;
wire [31:0] spi_response_data;
wire [15:0] spi_response_read_addr;
wire [15:0] spi_response_read_data;
assign {spi_response_read_addr, spi_response_read_data} = spi_response_data;
reg spi_response_ready;

spi_master spi(
    .clk(clk_core), 
    .clk_serial(!mclk),
    .reset(reset), 
    .request_valid(spi_request_valid), 
    .request_data(spi_request_data), 
    .request_ready(spi_request_ready), 
    .response_valid(spi_response_valid), 
    .response_data(spi_response_data), 
    .response_ready(spi_response_ready), 
    .sck(spi_sck), 
    .ss_out(spi_ss_out), 
    .ss_in(spi_ss_in),
    .mosi(spi_mosi), 
    .miso(spi_miso)
);

reg [3:0] byte_counter;
reg [3:0] report_byte_counter;
reg [7:0] current_cmd;
reg [7:0] current_report;
reg report_active;

//  Asynchronous FIFO - audio

wire [4:0] audio_rx_fifo_wr_count;
wire [4:0] audio_rx_fifo_rd_count;

wire audio_rx_fifo_rd_valid;
wire [7:0] audio_rx_fifo_rd_data;
wire audio_rx_fifo_rd_ready = ((audio_clk_counter < 6) || (audio_bytes_requested > 0));

wire audio_rx_fifo_rd_ready_last;
delay arfrr_delay(slot_clk, reset, audio_rx_fifo_rd_ready, audio_rx_fifo_rd_ready_last);

fifo_async audio_rx_fifo(
	.reset(reset),
	.wr_clk(clk_core), 
	.wr_valid(aud_rd_valid && aud_rd_ready), 
	.wr_data(aud_rd_data),
	.wr_ready(aud_rd_ready), 
	.wr_count(audio_rx_fifo_wr_count),
	.rd_clk(slot_clk), 
	.rd_valid(audio_rx_fifo_rd_valid),
	.rd_ready(audio_rx_fifo_rd_ready), 
	.rd_data(audio_rx_fifo_rd_data), 
	.rd_count(audio_rx_fifo_rd_count)
);
defparam audio_rx_fifo.Nb = 8;
defparam audio_rx_fifo.M = 4;
defparam audio_rx_fifo.N = 16;


//  Sequential logic - audio
always @(posedge slot_clk) begin
    if (reset) begin

        slot_data_en <= 0;
        
        pbck <= 0;
        plrck <= 0;
        pdata <= 0;
        
        audio_sample_left <= 0;
        audio_sample_right <= 0;
        
        audio_sample_left_next <= 0;
        audio_sample_right_next <= 0;
        
        //  Hardcode settings for now...
        audio_clk_ratio <= 256;
        audio_sample_res <= 24;
        audio_num_channels <= 2;
        
        audio_clk_counter <= 0;
        audio_bytes_received <= 0;
        audio_bytes_requested <= 0;
    end
    else begin

        if (audio_clk_counter == audio_clk_ratio - 1)
            audio_clk_counter <= 0;
        else
            audio_clk_counter <= audio_clk_counter + 1;

        //  2 channel mode
        if (dir && !chan) begin
            slot_data_en <= 1;  
            
            //  Audio serial port
            pbck <= (audio_clk_counter / 2);
            plrck <= !(audio_clk_counter / 128);
            if (audio_clk_counter < 128)
                pdata <= audio_sample_left >> (31 - (audio_clk_counter / 4));
            else
                pdata <= audio_sample_right >> (31 - ((audio_clk_counter - 128) / 4));
        end
        
        if (audio_clk_counter == 0) begin
            audio_sample_left <= audio_sample_left_next;
            audio_sample_right <= audio_sample_right_next;
            audio_sample_left_next <= 0;
            audio_sample_right_next <= 0;
        end
        
        //  Request samples in chunks of 6 bytes (24 bits left/right)
        if (audio_rx_fifo_rd_ready) begin
            if (audio_bytes_requested >= 5)
                audio_bytes_requested <= 0;
            else
                audio_bytes_requested <= audio_bytes_requested + 1;
        end
        
        if (audio_rx_fifo_rd_valid && audio_rx_fifo_rd_ready_last) begin
            case (audio_bytes_received)
            0:  audio_sample_left_next[23:16] <= audio_rx_fifo_rd_data;
            1:  audio_sample_left_next[15:8] <= audio_rx_fifo_rd_data;
            2:  audio_sample_left_next[7:0] <= audio_rx_fifo_rd_data;
            3:  audio_sample_right_next[23:16] <= audio_rx_fifo_rd_data;
            4:  audio_sample_right_next[15:8] <= audio_rx_fifo_rd_data;
            5:  audio_sample_right_next[7:0] <= audio_rx_fifo_rd_data;
            endcase
            if (audio_bytes_received == 5)
                audio_bytes_received <= 0;
            else
                audio_bytes_received <= audio_bytes_received + 1;
        end
        
    end
end


assign ctl_rd_ready = spi_request_ready;

//  Sequential logic - control
always @(posedge clk_core) begin
    if (reset) begin
        ctl_wr_valid <= 0;
        ctl_wr_data <= 0;

        aud_wr_valid <= 0;
        aud_wr_data <= 0;
        
        spi_request_valid <= 0;
        spi_request_isread <= 0;
        spi_request_addr_bytes <= 0;
        spi_request_addr_contents <= 0;
        spi_request_data_bytes <= 0;
        spi_request_data_contents <= 0;
        
        spi_response_ready <= 0;
        
        byte_counter <= 0;
        report_byte_counter <= 0;
        report_active <= 0;
        current_cmd <= 0;
        current_report <= 0;
        
        acon <= 8'h53;
    end
    else begin
        ctl_wr_valid <= 0;
        spi_request_valid <= 0;
        
        //  Control - nonblocking
        if (ctl_rd_valid) begin
            byte_counter <= byte_counter + 1;
            if (byte_counter == 0)
                current_cmd <= ctl_rd_data;
            else case (current_cmd)
            SPI_WRITE_REG: begin
                case (byte_counter)
                1: spi_request_addr_contents[7:0] <= ctl_rd_data;
                2: spi_request_data_contents[7:0] <= ctl_rd_data;
                endcase
                if (byte_counter == 2) begin
                    spi_request_isread <= 0;
                    spi_request_addr_bytes <= 0;
                    spi_request_data_bytes <= 0;
                    spi_request_valid <= 1;
                    byte_counter <= 0;
                end
            end
            SPI_READ_REG: begin
                case (byte_counter)
                1: spi_request_addr_contents[7:0] <= ctl_rd_data;
                endcase
                if (byte_counter == 1) begin
                    spi_request_isread <= 1;
                    spi_request_addr_bytes <= 0;
                    spi_request_data_bytes <= 0;
                    spi_request_valid <= 1;
                    byte_counter <= 0;
                end
            end
            endcase
        end
        
        spi_response_ready <= 1;
        if (spi_response_valid) begin
            current_report <= SPI_REPORT;
            report_active <= 1;
            report_byte_counter <= 0;
        end
        
        if (report_active && ctl_wr_ready) begin
            report_byte_counter <= report_byte_counter + 1;
            
            ctl_wr_valid <= 1;
            
            if (report_byte_counter == 0)
                ctl_wr_data <= current_report;
            else case (current_report)
            SPI_REPORT: begin
                case (report_byte_counter)
                1:  ctl_wr_data <= spi_response_read_addr[15:8];
                2:  ctl_wr_data <= spi_response_read_addr[7:0];
                3:  ctl_wr_data <= spi_response_read_data[15:8];
                4:  ctl_wr_data <= spi_response_read_data[7:0];
                endcase
                if (report_byte_counter == 4)
                    report_active <= 0;
            end
            endcase
            
        end
    end
end

endmodule
