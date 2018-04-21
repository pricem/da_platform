/*
    Open-source digital audio platform
    Copyright (C) 2009--2018 Michael Price

    slot_controller: Controls audio and control interfaces for one module
    (audio interface card).  This includes I2S communication with a DAC or ADC,
    an SPI master, and GPIO lines.

    Warning: Use and distribution of this code is restricted.
    This HDL file is distributed under the terms of the Solderpad Hardware 
    License, Version 0.51.  Other files in this project may be subject to
    different licenses.  Please see the LICENSE file in the top level project
    directory for more information.
*/

`timescale 1ns / 1ps

module slot_controller(
    input clk_core, 
    input reset,
    FIFOInterface.in ctl_rd,
    FIFOInterface.out ctl_wr,
    FIFOInterface.in aud_rd,
    FIFOInterface.out aud_wr,
    output spi_ss_out, 
    input spi_ss_in, 
    output spi_sck, 
    output spi_mosi, 
    input spi_miso,
    inout [5:0] slot_data, 
    input slot_clk, 
    input sclk, 
    input dir, 
    input chan, 
    output logic [7:0] hwcon, 
    input [7:0] hwflag,
    output [3:0] spi_state, 
    output ctl_wr_waiting,
    //  This is a general "blocking" bit which determines whether the slot should
    //  produce or consume samples 
    input fifo_en
);

`include "commands.vh"

logic [5:0] slot_data_val;

//  DAC/ADC enable flags - first synchronized to I2S clock, then latched in by LRCK to ensure
//  that left channel always comes first.
logic clocks_enabled;
logic playback_enabled;
(* keep = "true" *) logic recording_enabled;
logic playback_enabled_synclr;
logic playback_enabled_sync;
(* keep = "true" *) logic recording_enabled_sync;
(* keep = "true" *) logic recording_enabled_synclr;

logic [9:0] audio_clk_ratio;
logic [3:0] audio_sample_res;

logic [9:0] audio_clk_counter;

logic [23:0] audio_samples_active[7:0];
logic [23:0] audio_samples_next[7:0];

logic [3:0] audio_samples_received;
logic [3:0] audio_samples_requested;

//  FIFO for control output (before it gets muxed; this is helpful for letting slot_controller logic do its thing)
FIFOInterface #(.num_bits(8)) ctl_wr_int(clk_core);
(* keep = "true" *) logic [3:0] ctl_wr_fifo_count;

fifo_sync #(.Nb(8), .M(3)) ctl_wr_fifo(
	.clk(clk_core), 
	.reset(reset),
	.in(ctl_wr_int.in),
	.out(ctl_wr),
	.count(ctl_wr_fifo_count)
);

assign ctl_wr_waiting = (ctl_wr_fifo_count > 0);

//  Reset for SPI master - needs to wait for clock to clear itself
logic reset_spi;
logic [3:0] spi_clock_count;
always_ff @(posedge reset or posedge sclk) begin
    if (reset) begin
        reset_spi <= 1;
        spi_clock_count <= 0;
    end
    else begin
        if (spi_clock_count >= 4)
            reset_spi <= 0;
        else begin
            reset_spi <= 1;
            spi_clock_count <= spi_clock_count + 1;
        end
    end
end

//  2 channel DAC mode
logic dac_pbck;
logic dac_plrck;
//  logic plrck;
logic [3:0] dac_pdata;

//  Note: alternatively the other 3 lines can be used for DSD format.
//  This is not yet supported.
logic dac_dbck = 0;
logic dac_dsdr = 0;
logic dac_dsdl = 0;

always_comb begin
    //  Version 2 isolator standardizes which pins are BCK/LRCK/DATA
    //  Side effect: DSD will have to use existing names
    slot_data_val = {dac_pdata[3], dac_pdata[2], dac_pdata[1], dac_pdata[0], dac_plrck, dac_pbck};
end

//  2 channel ADC mode
(* keep = "true" *) logic adc_pbck;
logic adc_plrck;
logic [3:0] adc_pdata;
always_comb begin
    //  Version 2 isolator standardizes which pins are BCK/LRCK/DATA
    adc_pbck = slot_data[0];
    adc_plrck = slot_data[1];
    adc_pdata[0] = slot_data[2];
    adc_pdata[1] = slot_data[3];
    adc_pdata[2] = slot_data[4];
    adc_pdata[3] = slot_data[5];
end

assign slot_data = dir ? slot_data_val : 6'bzzzzzz;


//  Latch to ensure FIFO gets reset properly even though it waits for ADC bit clock
logic fifo_reset;
always @(reset, adc_pbck) begin
    if (reset)
        fifo_reset <= 1;
    else if (adc_pbck)
        fifo_reset <= 0;
end

//  Synchronizers for playback/record enable
delay #(.num_cycles(2)) pe_delay(.clk(slot_clk), .reset(reset), .in(playback_enabled && fifo_en), .out(playback_enabled_sync));
delay #(.num_cycles(2)) re_delay(.clk(adc_pbck), .reset(fifo_reset), .in(recording_enabled && fifo_en), .out(recording_enabled_sync));

//  Synchronizers for dir/chan for ADC and DAC logic
wire dir_sync_adc;
wire chan_sync_adc;
wire dir_sync_dac;
wire chan_sync_dac;
delay #(.num_cycles(2)) dir_delay_adc(.clk(adc_pbck), .reset(reset), .in(dir), .out(dir_sync_adc));
delay #(.num_cycles(2)) chan_delay_adc(.clk(adc_pbck), .reset(reset), .in(chan), .out(chan_sync_adc));
delay #(.num_cycles(2)) dir_delay_dac(.clk(slot_clk), .reset(reset), .in(dir), .out(dir_sync_dac));
delay #(.num_cycles(2)) chan_delay_dac(.clk(slot_clk), .reset(reset), .in(chan), .out(chan_sync_dac));

//  Convenience: figure out how many channels we're supposed to have
wire [3:0] audio_num_channels_adc = chan_sync_adc ? 8 : 2;
wire [3:0] audio_num_channels_dac = chan_sync_dac ? 8 : 2;

//  SPI controller

FIFOInterface #(.num_bits(35)) spi_request(clk_core);
FIFOInterface #(.num_bits(32)) spi_response(clk_core);

logic spi_request_isread;
logic spi_request_addr_bytes;
logic [15:0] spi_request_addr_contents;
logic spi_request_data_bytes;
logic [15:0] spi_request_data_contents;
assign spi_request.data = {spi_request_isread, spi_request_addr_bytes, spi_request_data_bytes, spi_request_addr_contents, spi_request_data_contents};

logic [15:0] spi_response_read_addr;
logic [15:0] spi_response_read_data;
assign {spi_response_read_addr, spi_response_read_data} = spi_response.data;

spi_master spi(
    .clk(clk_core), 
    .clk_serial(!sclk),
    .reset(reset_spi), 
    .request(spi_request.in),
    .response(spi_response.out),
    .sck(spi_sck), 
    .ss_out(spi_ss_out), 
    .ss_in(spi_ss_in),
    .mosi(spi_mosi), 
    .miso(spi_miso),
    .state(spi_state)
);

(* keep = "true" *) logic [3:0] byte_counter;
(* keep = "true" *) logic [3:0] report_byte_counter;
(* keep = "true" *) logic [7:0] current_cmd;
(* keep = "true" *) logic [7:0] current_report;
(* keep = "true" *) logic report_active;

//  Asynchronous FIFO - audio for DACs

(* keep = "true" *) logic [4:0] audio_rx_fifo_wr_count;
(* keep = "true" *) logic [4:0] audio_rx_fifo_rd_count;

FIFOInterface #(.num_bits(32)) audio_rx(slot_clk);
always_comb audio_rx.ready = (((audio_clk_counter == 0) && (audio_rx_fifo_rd_count >= audio_num_channels_dac)) || (audio_samples_requested > 0));

logic audio_rx_rd_ready_last;
delay arfrr_delay(
    .clk(slot_clk), 
    .reset, 
    .in(audio_rx.ready), 
    .out(audio_rx_rd_ready_last)
);

fifo_async #(
    .Nb(32), 
    .M(4), 
    .N(16)
) audio_rx_fifo(
	.reset(reset),
	.in(aud_rd),
	.in_count(audio_rx_fifo_wr_count),
	.out(audio_rx.out),
	.out_count(audio_rx_fifo_rd_count)
);

/*
clk_divider lrclk_divider(reset, slot_clk, plrck);
defparam lrclk_divider.ratio = 192;
defparam lrclk_divider.threshold = 96;
*/

//  I2S receiver - audio for ADCs
localparam ADC_FORMAT_RJ = 2'b00;
localparam ADC_FORMAT_LJ = 2'b01;
localparam ADC_FORMAT_I2S = 2'b10;
logic [1:0] adc_format;
(* keep = "true" *) logic [4:0] audio_tx_fifo_wr_count;
(* keep = "true" *) logic [4:0] audio_tx_fifo_rd_count;

FIFOInterface #(.num_bits(32)) audio_tx(adc_pbck);

fifo_async #(
    .Nb(32),
    .M(4),
    .N(16)
) audio_tx_fifo(
	.reset(fifo_reset),
	.in(audio_tx.in),
	.in_count(audio_tx_fifo_wr_count),
	.out(aud_wr),
	.out_count(audio_tx_fifo_rd_count)
);

(* keep = "true" *) logic [5:0] adc_cycle_counter;
logic adc_lrck_last;
logic [23:0] adc_sample_left[3:0];
logic [23:0] adc_sample_right[3:0];
logic [23:0] adc_sample_left_last[3:0];
logic [23:0] adc_sample_right_last[3:0];
(* keep = "true" *) logic adc_left_not_right;

(* keep = "true" *) logic recording_enabled_synclr_last;
(* keep = "true" *) logic [3:0] adc_fifo_write_count;

always_ff @(posedge adc_pbck) begin

    //  Capture the samples into adc_sample_left[], adc_sample_right[]
    adc_lrck_last <= adc_plrck;
    if (fifo_reset) begin
        recording_enabled_synclr <= 0;
        recording_enabled_synclr_last <= 0;
        adc_fifo_write_count <= audio_num_channels_adc;
    end
    if (fifo_reset || audio_tx.ready) audio_tx.valid <= 0;
    
    if (adc_plrck && !adc_lrck_last) begin
        adc_cycle_counter <= 0;
        for (int i = 0; i < 4; i++) begin
            adc_sample_right_last[i] <= adc_sample_right[i];
            adc_sample_right[i] <= 0;
        end
        if (recording_enabled_synclr_last)
            adc_fifo_write_count <= 0;
        adc_left_not_right <= 0;
    end
    else if (!adc_plrck && adc_lrck_last) begin
        recording_enabled_synclr <= recording_enabled_sync;
        recording_enabled_synclr_last <= recording_enabled_synclr;
        adc_cycle_counter <= 0;
        for (int i = 0; i < 4; i++) begin
            adc_sample_left_last[i] <= adc_sample_left[i];
            adc_sample_left[i] <= 0;
        end
        adc_left_not_right <= 1;
    end
    else
        adc_cycle_counter <= adc_cycle_counter + 1;
    
    for (int i = 0; i < 4; i++) begin
        case (adc_format)
        ADC_FORMAT_I2S: begin
            if (adc_left_not_right && (adc_cycle_counter < 24))
                adc_sample_left[i] <= {adc_sample_left[i], adc_pdata[i]};
            if (!adc_left_not_right && (adc_cycle_counter < 24))
                adc_sample_right[i] <= {adc_sample_right[i], adc_pdata[i]};  
        end
        ADC_FORMAT_LJ: begin
            if (!adc_plrck && ((adc_cycle_counter == 31) || (adc_cycle_counter < 23)))
                adc_sample_left[i] <= {adc_sample_left[i], adc_pdata[i]};
            if (adc_plrck && ((adc_cycle_counter == 31) || (adc_cycle_counter < 23)))
                adc_sample_right[i] <= {adc_sample_right[i], adc_pdata[i]}; 
        end
        ADC_FORMAT_RJ: begin
            if (adc_left_not_right && ((adc_cycle_counter >= 7) && (adc_cycle_counter < 31)))
                adc_sample_left[i] <= {adc_sample_left[i], adc_pdata[i]};
            if (!adc_left_not_right && ((adc_cycle_counter >= 7) && (adc_cycle_counter < 31)))
                adc_sample_right[i] <= {adc_sample_right[i], adc_pdata[i]};
        end
        endcase
    end
    
    //  Write the received samples to the FIFO - up to 8 channels per LRCK cycle
    //  Note that there is no flow control here.  The FIFO better have space.
    if (recording_enabled_synclr_last && !dir_sync_adc) begin
        if ((adc_fifo_write_count < audio_num_channels_adc) && audio_tx.ready) begin
            audio_tx.valid <= 1;
            adc_fifo_write_count <= adc_fifo_write_count + 1;
            if (adc_fifo_write_count[0])
                audio_tx.data <= adc_sample_right_last[adc_fifo_write_count >> 1];
            else
                audio_tx.data <= adc_sample_left_last[adc_fifo_write_count >> 1];
        end
    end
    else begin
        audio_tx.valid <= 0;
        audio_tx.data <= 0;
    end
end

//  Sequential logic - audio
always_ff @(posedge slot_clk) begin
    if (reset) begin

        dac_pbck <= 0;
        dac_plrck <= 0;
        dac_pdata <= 0;
        
        for (int i = 0; i < 8; i++) begin
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
            playback_enabled_synclr <= playback_enabled_sync;
        end
        else
            audio_clk_counter <= audio_clk_counter + 1;

        //  2 channel mode
        if (dir_sync_dac /* && !chan */) begin
            
            //  Digital filtering in DSD1792
            //  Audio serial port
            if (clocks_enabled) begin
                dac_pbck <= audio_clk_counter / 2;
                dac_plrck <= (audio_clk_counter / 128);
            end
            else begin
                dac_pbck <= 0;
                dac_plrck <= 0;
            end

            /*
            //  Standard right justified format
            if (audio_clk_counter < 128)
                pdata <= audio_sample_left >> (31 - (audio_clk_counter / 4));
            else
                pdata <= audio_sample_right >> (31 - ((audio_clk_counter - 128) / 4));
            */
            //  I2S format
            for (int i = 0; i < 4; i++) begin
                if (playback_enabled_synclr && (i < audio_num_channels_dac / 2)) begin
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
            for (int i = 0; i < 8; i++) if (i < audio_num_channels_dac) begin
                audio_samples_active[i] <= audio_samples_next[i];
                audio_samples_next[i] <= 0;
            end
        end
        
        //  Request samples in chunks of 6 bytes (24 bits left/right)
        if (audio_rx.ready) begin
            if (audio_samples_requested >= audio_num_channels_dac - 1)
                audio_samples_requested <= 0;
            else
                audio_samples_requested <= audio_samples_requested + 1;
        end
        
        if (audio_rx.valid && audio_rx_rd_ready_last) begin
            audio_samples_next[audio_samples_received] <= audio_rx.data;
            if (audio_samples_received >= audio_num_channels_dac - 1)
                audio_samples_received <= 0;
            else
                audio_samples_received <= audio_samples_received + 1;
        end
        
    end
end


assign ctl_rd.ready = spi_request.ready;

//  Sequential logic - control
always_ff @(posedge clk_core) begin
    if (reset) begin
        ctl_wr_int.valid <= 0;
        ctl_wr_int.data <= 0;

        spi_request.valid <= 0;
        spi_request_isread <= 0;
        spi_request_addr_bytes <= 0;
        spi_request_addr_contents <= 0;
        spi_request_data_bytes <= 0;
        spi_request_data_contents <= 0;
        
        clocks_enabled <= 1;
        playback_enabled <= 1;
        recording_enabled <= 0;
        
        spi_response.ready <= 0;
        
        byte_counter <= 0;
        report_byte_counter <= 0;
        report_active <= 0;
        current_cmd <= 0;
        current_report <= 0;
        
        adc_format <= ADC_FORMAT_I2S;
        hwcon <= 8'h00;
    end
    else begin
        ctl_wr_int.valid <= 0;
        spi_request.valid <= 0;
        
        //  Control - nonblocking
        if (ctl_rd.valid && ctl_rd.ready) begin
            byte_counter <= byte_counter + 1;
            if (byte_counter == 0)
                current_cmd <= ctl_rd.data;
            else case (current_cmd)
            SPI_WRITE_REG: begin
                case (byte_counter)
                1: {spi_request_addr_bytes, spi_request_data_bytes} <= ctl_rd.data[1:0];
                2: spi_request_addr_contents[15:8] <= ctl_rd.data;
                3: spi_request_addr_contents[7:0] <= ctl_rd.data;
                4: spi_request_data_contents[15:8] <= ctl_rd.data;
                5: spi_request_data_contents[7:0] <= ctl_rd.data;
                endcase
                if (byte_counter == 5) begin
                    spi_request_isread <= 0;
                    spi_request.valid <= 1;
                    byte_counter <= 0;
                end
            end
            SPI_READ_REG: begin
                case (byte_counter)
                1: {spi_request_addr_bytes, spi_request_data_bytes} <= ctl_rd.data[1:0];
                2: spi_request_addr_contents[15:8] <= ctl_rd.data;
                3: spi_request_addr_contents[7:0] <= ctl_rd.data;
                endcase
                if (byte_counter == 3) begin
                    spi_request_isread <= 1;
                    spi_request.valid <= 1;
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
            SLOT_SET_ACON: begin
                hwcon <= ctl_rd.data;
                byte_counter <= 0;
            end
            SLOT_STOP_CLOCKS: begin
                clocks_enabled <= 0;
                byte_counter <= 0;
            end
            SLOT_START_CLOCKS: begin
                clocks_enabled <= 1;
                byte_counter <= 0;
            end
            SLOT_FMT_LJ: begin
                adc_format <= ADC_FORMAT_LJ;
                byte_counter <= 0;
            end
            SLOT_FMT_RJ: begin
                adc_format <= ADC_FORMAT_RJ;
                byte_counter <= 0;
            end
            SLOT_FMT_I2S: begin
                adc_format <= ADC_FORMAT_I2S;
                byte_counter <= 0;
            end
            endcase
        end
        
        spi_response.ready <= 1;
        if (spi_response.valid && spi_response.ready) begin
            current_report <= SPI_REPORT;
            report_active <= 1;
            report_byte_counter <= 0;
        end
        
        if (report_active && ctl_wr_int.ready) begin
            report_byte_counter <= report_byte_counter + 1;
            
            ctl_wr_int.valid <= 1;
            
            if (report_byte_counter == 0)
                ctl_wr_int.data <= current_report;
            else case (current_report)
            SPI_REPORT: begin
                case (report_byte_counter)
                1:  ctl_wr_int.data <= spi_response_read_addr[15:8];
                2:  ctl_wr_int.data <= spi_response_read_addr[7:0];
                3:  ctl_wr_int.data <= spi_response_read_data[15:8];
                4:  ctl_wr_int.data <= spi_response_read_data[7:0];
                endcase
                if (report_byte_counter == 4)
                    report_active <= 0;
            end
            endcase
            
        end
    end
end

endmodule
