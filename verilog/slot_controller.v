module slot_controller(clk_core, reset,
    ctl_rd_valid, ctl_rd_data, ctl_rd_ready,
    ctl_wr_valid, ctl_wr_data, ctl_wr_ready,
    aud_rd_valid, aud_rd_data, aud_rd_ready,
    aud_wr_valid, aud_wr_data, aud_wr_ready,
    spi_ss_out, spi_ss_in, spi_sck, spi_mosi, spi_miso,
    slot_data, slot_clk, mclk, dir, chan, acon, aovf,
    spi_state, ctl_wr_waiting
);

`include "commands.v"

input clk_core;
input reset;

input ctl_rd_valid;
input [7:0] ctl_rd_data;
output ctl_rd_ready;

output ctl_wr_valid;
output [7:0] ctl_wr_data;
input ctl_wr_ready;

input aud_rd_valid;
input [31:0] aud_rd_data;
output aud_rd_ready;

output aud_wr_valid;
output [31:0] aud_wr_data;
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

output [3:0] spi_state;
output ctl_wr_waiting;

reg [5:0] slot_data_val;

//  DAC/ADC enable flags - first synchronized to I2S clock, then latched in by LRCK to ensure
//  that left channel always comes first.
reg playback_enabled;
reg recording_enabled;
reg playback_enabled_synclr;
wire playback_enabled_sync;
wire recording_enabled_sync;
reg recording_enabled_synclr;

reg [9:0] audio_clk_ratio;
reg [3:0] audio_sample_res;

reg [9:0] audio_clk_counter;

reg [23:0] audio_samples_active[7:0];
reg [23:0] audio_samples_next[7:0];

reg [3:0] audio_samples_received;
reg [3:0] audio_samples_requested;

reg ctl_wr_valid_int;
reg [7:0] ctl_wr_data_int;
wire ctl_wr_ready_int;

wire [3:0] ctl_wr_fifo_count;

//  FIFO for control output (before it gets muxed; this is helpful for letting slot_controller logic do its thing)
fifo_sync #(.Nb(8), .M(3)) ctl_wr_fifo(
	.clk(clk_core), 
	.reset(reset),
	.wr_valid(ctl_wr_valid_int), 
	.wr_data(ctl_wr_data_int),
	.wr_ready(ctl_wr_ready_int),
	.rd_ready(ctl_wr_ready),
	.rd_valid(ctl_wr_valid), 
	.rd_data(ctl_wr_data),
	.count(ctl_wr_fifo_count)
);

assign ctl_wr_waiting = (ctl_wr_fifo_count > 0);

//  256xFS master clock and I2S output format are the default. Should be configurable though.
//  TODO: Add configurable output justification, support RJ/LJ in addition to I2S.
reg pdata_left_active;     //  "LEFT" = "even" numbered channels 0, 2, 4, 6
reg pdata_right_active;    //  "RIGHT" = "odd" numbered channels 1, 3, 5, 7

always @(*) begin
    case (audio_clk_ratio)
    256: begin
        pdata_left_active = (audio_clk_counter > 4) && (audio_clk_counter <= 100);
        pdata_right_active = (audio_clk_counter > 132) && (audio_clk_counter <= 228);
    end
    512: begin
        pdata_left_active = (audio_clk_counter > 8) && (audio_clk_counter <= 200);
        pdata_right_active = (audio_clk_counter > 264) && (audio_clk_counter <= 456);
    end
    128: begin
        pdata_left_active = (audio_clk_counter > 2) && (audio_clk_counter <= 50);
        pdata_right_active = (audio_clk_counter > 66) && (audio_clk_counter <= 114);
    end
    default: begin
        pdata_left_active = 0;
        pdata_right_active = 0;
    end
    endcase
end

wire pdata_active = pdata_left_active || pdata_right_active;

//  Convenience: figure out how many channels we're supposed to have
wire [3:0] audio_num_channels;
assign audio_num_channels = chan ? 8 : 2;

//  2 channel DAC mode
reg dac_pbck;
reg dac_plrck;
//  wire plrck;
reg [3:0] dac_pdata;

//  Note: alternatively the other 3 lines can be used for DSD format.
//  This is not yet supported.
wire dac_dbck = 0;
wire dac_dsdr = 0;
wire dac_dsdl = 0;

//  wire pdata_mod = pdata || !pdata_active;
always @(*) begin
    slot_data_val = 0;
    if (dir && !chan) begin
        //  2-channel DAC: slot[5] = BCK, slot[3] = LRCK, slot[4] = SDATA
        slot_data_val = {dac_pbck, dac_pdata[0], dac_plrck, dac_dbck, dac_dsdr, dac_dsdl};
    end
    else if (dir && chan) begin
        //  8-channel not yet supported... but we can at least put the pin ordering here
        slot_data_val = {dac_plrck, dac_pbck, dac_pdata[0], dac_pdata[1], dac_pdata[2], dac_pdata[3]};
    end
end

//  2 channel ADC mode
reg adc_pbck;
reg adc_plrck;
reg [3:0] adc_pdata;
always @(*) begin
    {adc_pbck, adc_plrck, adc_pdata} = 0;
    if (!dir && !chan) begin
        //  2-channel ADC: slot[2] = SDATA, slot[1] = BCK, slot[0] = LRCK
        adc_pbck = slot_data[1];
        adc_plrck = slot_data[0];
        adc_pdata[0] = slot_data[2];
    end
    else if (!dir && chan) begin
        //  8-channel not yet supported
        adc_pbck = slot_data[3];
        adc_plrck = slot_data[2];
        adc_pdata[0] = slot_data[0];
        adc_pdata[1] = slot_data[1];
        adc_pdata[2] = slot_data[4];
        adc_pdata[3] = slot_data[5];
    end
end

assign slot_data = dir ? slot_data_val : 6'bzzzzzz;


//  Latch to ensure FIFO gets reset properly even though it waits for ADC bit clock
reg fifo_reset;
always @(reset, adc_pbck) begin
    if (reset)
        fifo_reset <= 1;
    else if (adc_pbck)
        fifo_reset <= 0;
end

//  Synchronizers for playback/record enable
delay #(.Nc(2)) pe_delay(.clk(slot_clk), .reset(reset), .sig_in(playback_enabled), .sig_out(playback_enabled_sync));
delay #(.Nc(2)) re_delay(.clk(adc_pbck), .reset(fifo_reset), .sig_in(recording_enabled), .sig_out(recording_enabled_sync));


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
    .miso(spi_miso),
    .state(spi_state)
);

reg [3:0] byte_counter;
reg [3:0] report_byte_counter;
reg [7:0] current_cmd;
reg [7:0] current_report;
reg report_active;

//  Asynchronous FIFO - audio for DACs

wire [4:0] audio_rx_fifo_wr_count;
wire [4:0] audio_rx_fifo_rd_count;

wire audio_rx_fifo_rd_valid;
wire [31:0] audio_rx_fifo_rd_data;
wire audio_rx_fifo_rd_ready = (((audio_clk_counter == 0) && (audio_rx_fifo_rd_count >= audio_num_channels)) || (audio_samples_requested > 0));

wire audio_rx_fifo_rd_ready_last;
delay arfrr_delay(slot_clk, reset, audio_rx_fifo_rd_ready, audio_rx_fifo_rd_ready_last);

fifo_async audio_rx_fifo(
	.reset(reset),
	.wr_clk(clk_core), 
	.wr_valid(aud_rd_valid), 
	.wr_data(aud_rd_data),
	.wr_ready(aud_rd_ready), 
	.wr_count(audio_rx_fifo_wr_count),
	.rd_clk(slot_clk), 
	.rd_valid(audio_rx_fifo_rd_valid),
	.rd_ready(audio_rx_fifo_rd_ready), 
	.rd_data(audio_rx_fifo_rd_data), 
	.rd_count(audio_rx_fifo_rd_count)
);
defparam audio_rx_fifo.Nb = 32;
defparam audio_rx_fifo.M = 4;
defparam audio_rx_fifo.N = 16;
/*
clk_divider lrclk_divider(reset, slot_clk, plrck);
defparam lrclk_divider.ratio = 192;
defparam lrclk_divider.threshold = 96;
*/

//  I2S receiver - audio for ADCs

wire [4:0] audio_tx_fifo_wr_count;
wire [4:0] audio_tx_fifo_rd_count;

reg audio_tx_fifo_wr_valid;
reg [31:0] audio_tx_fifo_wr_data;
wire audio_tx_fifo_wr_ready;    //  ignored; after all, data is arriving in real-time

fifo_async audio_tx_fifo(
	.reset(fifo_reset),
	.wr_clk(adc_pbck), 
	.wr_valid(audio_tx_fifo_wr_valid), 
	.wr_data(audio_tx_fifo_wr_data),
	.wr_ready(audio_tx_fifo_wr_ready), 
	.wr_count(audio_tx_fifo_wr_count),
	.rd_clk(clk_core), 
	.rd_valid(aud_wr_valid),
	.rd_ready(aud_wr_ready), 
	.rd_data(aud_wr_data), 
	.rd_count(audio_tx_fifo_rd_count)
);
defparam audio_tx_fifo.Nb = 32;
defparam audio_tx_fifo.M = 4;
defparam audio_tx_fifo.N = 16;

reg [5:0] adc_cycle_counter;
reg adc_lrck_last;
reg [23:0] adc_sample_left;
reg [23:0] adc_sample_right;
reg adc_left_not_right;

always @(posedge adc_pbck) begin

    adc_lrck_last <= adc_plrck;
    if (fifo_reset) recording_enabled_synclr <= 0;
    if (fifo_reset || audio_tx_fifo_wr_ready) audio_tx_fifo_wr_valid <= 0;
    
    if (adc_plrck && !adc_lrck_last) begin
        adc_cycle_counter <= 0;
        adc_sample_right <= 0;
        adc_left_not_right <= 0;
        audio_tx_fifo_wr_valid <= recording_enabled_synclr;
        audio_tx_fifo_wr_data <= adc_sample_left;
    end
    else if (!adc_plrck && adc_lrck_last) begin
        recording_enabled_synclr <= recording_enabled;
        adc_cycle_counter <= 0;
        adc_sample_left <= 0;
        adc_left_not_right <= 1;
        audio_tx_fifo_wr_valid <= recording_enabled_synclr;
        audio_tx_fifo_wr_data <= adc_sample_right;
    end
    else
        adc_cycle_counter <= adc_cycle_counter + 1;
        
    if (adc_left_not_right && (adc_cycle_counter < 24))
        adc_sample_left <= {adc_sample_left, adc_pdata[0]};
    if (!adc_left_not_right && (adc_cycle_counter < 24))
        adc_sample_right <= {adc_sample_right, adc_pdata[0]};  
    
end

//  Sequential logic - audio
integer i;
always @(posedge slot_clk) begin
    if (reset) begin

        dac_pbck <= 0;
        dac_plrck <= 0;
        dac_pdata <= 0;
        
        for (i = 0; i < 8; i = i + 1) begin
            audio_samples_active[i] <= 0;
            audio_samples_next[i] <= 0;
        end

        //  Hardcode settings for now...
        audio_clk_ratio <= 256;
        audio_sample_res <= 24;
        
        audio_clk_counter <= 0;
        audio_samples_received <= 0;
        audio_samples_requested <= 0;
        
        playback_enabled_synclr <= 0;
    end
    else begin

        if (audio_clk_counter == audio_clk_ratio - 1) begin
            audio_clk_counter <= 0;
            //  Latch playback enabled before falling edge
            playback_enabled_synclr <= playback_enabled;
        end
        else
            audio_clk_counter <= audio_clk_counter + 1;

        //  2 channel mode
        if (dir && !chan) begin
            
            //  Digital filtering in DSD1792
            //  Audio serial port
            dac_pbck <= audio_clk_counter / 2;
            dac_plrck <= (audio_clk_counter / 128);

            /*
            //  Standard right justified format
            if (audio_clk_counter < 128)
                pdata <= audio_sample_left >> (31 - (audio_clk_counter / 4));
            else
                pdata <= audio_sample_right >> (31 - ((audio_clk_counter - 128) / 4));
            */
            //  I2S format
            for (i = 0; i < 4; i = i + 1) begin
                if (playback_enabled_synclr && (i < audio_num_channels / 2)) begin
                    if (audio_clk_counter < audio_clk_ratio / 2)
                        dac_pdata[i] <= audio_samples_active[i * 2] >> (24 - audio_clk_counter / 4);
                    else
                        dac_pdata[i] <= audio_samples_active[i * 2 + 1] >> (24 - (audio_clk_counter - audio_clk_ratio / 2) / 4);
                end
                else begin
                    dac_pdata[i] <= 0;
                end
            end
            
            /*
            //  Digital filter here, bypassing digital filter in DSD1792
            dac_pbck <= audio_clk_counter;
            dac_plrck <= (audio_clk_counter / 32);
            dac_pdata <= audio_sample_right >> (31 - ((audio_clk_counter / 2) % 32));
            */
        end
        
        if (audio_clk_counter == 0) begin
            for (i = 0; i < audio_num_channels; i = i + 1) begin
                audio_samples_active[i] <= audio_samples_next[i];
                audio_samples_next[i] <= 0;
            end
        end
        
        //  Request samples in chunks of 6 bytes (24 bits left/right)
        if (audio_rx_fifo_rd_ready) begin
            if (audio_samples_requested >= audio_num_channels - 1)
                audio_samples_requested <= 0;
            else
                audio_samples_requested <= audio_samples_requested + 1;
        end
        
        if (audio_rx_fifo_rd_valid && audio_rx_fifo_rd_ready_last) begin
            audio_samples_next[audio_samples_received] <= audio_rx_fifo_rd_data;
            if (audio_samples_received >= audio_num_channels - 1)
                audio_samples_received <= 0;
            else
                audio_samples_received <= audio_samples_received + 1;
        end
        
    end
end


assign ctl_rd_ready = spi_request_ready;

//  Sequential logic - control
always @(posedge clk_core) begin
    if (reset) begin
        ctl_wr_valid_int <= 0;
        ctl_wr_data_int <= 0;

        spi_request_valid <= 0;
        spi_request_isread <= 0;
        spi_request_addr_bytes <= 0;
        spi_request_addr_contents <= 0;
        spi_request_data_bytes <= 0;
        spi_request_data_contents <= 0;
        
        playback_enabled <= 1;
        recording_enabled <= 0;
        
        spi_response_ready <= 0;
        
        byte_counter <= 0;
        report_byte_counter <= 0;
        report_active <= 0;
        current_cmd <= 0;
        current_report <= 0;
        
        acon <= 8'h53;
    end
    else begin
        ctl_wr_valid_int <= 0;
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
            SLOT_START_PLAYBACK: begin
                playback_enabled <= 1;
                byte_counter <= 0;
            end
            SLOT_STOP_PLAYBACK:begin
                playback_enabled <= 0;
                byte_counter <= 0;
            end
            SLOT_START_RECORDING: begin
                recording_enabled <= 1;
                byte_counter <= 0;
            end
            SLOT_STOP_RECORDING: begin
                recording_enabled <= 0;
                byte_counter <= 0;
            end
            endcase
        end
        
        spi_response_ready <= 1;
        if (spi_response_valid) begin
            current_report <= SPI_REPORT;
            report_active <= 1;
            report_byte_counter <= 0;
        end
        
        if (report_active && ctl_wr_ready_int) begin
            report_byte_counter <= report_byte_counter + 1;
            
            ctl_wr_valid_int <= 1;
            
            if (report_byte_counter == 0)
                ctl_wr_data_int <= current_report;
            else case (current_report)
            SPI_REPORT: begin
                case (report_byte_counter)
                1:  ctl_wr_data_int <= spi_response_read_addr[15:8];
                2:  ctl_wr_data_int <= spi_response_read_addr[7:0];
                3:  ctl_wr_data_int <= spi_response_read_data[15:8];
                4:  ctl_wr_data_int <= spi_response_read_data[7:0];
                endcase
                if (report_byte_counter == 4)
                    report_active <= 0;
            end
            endcase
            
        end
    end
end

endmodule
