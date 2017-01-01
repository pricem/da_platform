
/*
    Automatic speech recognition processor (asrv2)

    Copyright 2015 MIT
    Author: Michael Price (pricem@mit.edu)

    Adapted for DA Platform project
    Copyright 2009--2016 Michael Price
    
    Use and distribution of this code is restricted.
    See LICENSE file in top level project directory.
*/

/*
    SV version of MIG adapter.
    Includes handling of clock domain crossings.
*/

`timescale 1ns / 1ps

module MIGAdapter #(
    parameter addr_width = 28,
    parameter data_width = 256,
    parameter interface_width = 8,
    parameter DDR3_BURST_LENGTH = 8,
    parameter nCK_PER_CLK = 4
) (
    ClockReset.client cr,
    
    FIFOInterface.in ext_mem_cmd,
    FIFOInterface.in ext_mem_write,
    FIFOInterface.out ext_mem_read,
    
    input logic mig_clk,
    input logic mig_reset,
    input logic mig_init_done,
    input logic mig_af_rdy,
    output logic mig_af_wr_en,
    output logic [addr_width - 1 : 0] mig_af_addr,
    output logic [2:0] mig_af_cmd,
    input logic mig_wdf_rdy,
    output logic mig_wdf_wr_en,
    output logic [data_width - 1 : 0] mig_wdf_data,
    output logic mig_wdf_last,
    output logic [data_width / 8 - 1 : 0] mig_wdf_mask,
    input logic mig_read_data_valid,
    input logic mig_read_data_last,
    input logic [data_width - 1 : 0] mig_read_data
);

`include "../structures.sv"

typedef enum logic [3:0] { MAS_RESET, MAS_WAITING, MAS_FETCH_CMD, MAS_PARSE_CMD, MAS_READ_WAIT, MAS_READ_SUBMIT, MAS_WRITE_WAIT, MAS_WRITE_SUBMIT, MAS_PRE_WRITE, MAS_PRE_READ } MAState;

localparam INSTR_READ = 3'b001;
localparam INSTR_WRITE = 3'b000;

//  Offset added to prevent startup calibration from overwriting data that we need
//  256 words should be plenty.
localparam PHYS_ADDR_OFFSET = 32'h00000100;

localparam word_count = data_width / interface_width;

//  Reset synchronization
logic [1:0] reset_sync;
logic reset_internal;
always_ff @(posedge mig_clk) reset_sync <= {reset_sync[0], cr.reset};
always_comb reset_internal = reset_sync[1];

//  Also reset when MIG calibration completes
//  This is necessary since at startup, we may not have had any valid reset cycles.
logic mig_init_done_last;
logic init_done_pulse;
always_ff @(posedge mig_clk) mig_init_done_last <= mig_init_done;
always_comb init_done_pulse = mig_init_done && !mig_init_done_last;

//  Make up MIG clock interface for FIFOs
ClockReset cr_mig ();
always_comb begin
    cr_mig.clk = mig_clk;
    cr_mig.reset = reset_internal || mig_reset || init_done_pulse;
end

//  Async FIFOs - get everything to the mig_clk domain
//  1.  Control
FIFOInterface #(.num_bits(65)) ctl_in (cr.clk);
FIFOInterface #(.num_bits(65)) ctl_out (cr_mig.clk);
logic [2:0] ctl_wr_count;
logic [2:0] ctl_rd_count;
fifo_async_sv2 #(
    .width(65 /* sizeof(ExtMemRequest) */),
    .depth(4),
    .debug_display(1)
) ctl_fifo(
    .clk_in(cr.clk),
    .reset_in(cr.reset),
    .in(ctl_in.in),
    .count_in(ctl_wr_count),
    .clk_out(cr_mig.clk),
    .reset_out(cr_mig.reset),
    .out(ctl_out.out),
    .count_out(ctl_rd_count)
);
always_comb begin
    ext_mem_cmd.ready = ctl_in.ready;
    ctl_in.enable = ext_mem_cmd.enable;
    ctl_in.data = ext_mem_cmd.data;
end

//  2.  Write
FIFOInterface #(.num_bits(interface_width)) write_in (cr.clk);
FIFOInterface #(.num_bits(interface_width)) write_out (cr_mig.clk);
logic [6:0] write_wr_count;
logic [6:0] write_rd_count;
fifo_async_sv2 #(
    .width(interface_width),
    .depth(64),
    .debug_display(1)
) write_fifo(
    .clk_in(cr.clk),
    .reset_in(cr.reset),
    .in(write_in.in),
    .count_in(write_wr_count),
    .clk_out(cr_mig.clk),
    .reset_out(cr_mig.reset),
    .out(write_out.out),
    .count_out(write_rd_count)
);
always_comb begin
    ext_mem_write.ready = write_in.ready;
    write_in.enable = ext_mem_write.enable;
    write_in.data = ext_mem_write.data;
end

//  3.  Read
FIFOInterface #(.num_bits(interface_width)) read_in (cr_mig.clk);
FIFOInterface #(.num_bits(interface_width)) read_out (cr.clk);
logic [6:0] read_wr_count;
logic [6:0] read_rd_count;
fifo_async_sv2 #(
    .width(interface_width),
    .depth(64),
    .debug_display(1)
) read_fifo(
    .clk_in(cr_mig.clk),
    .reset_in(cr_mig.reset),
    .in(read_in.in),
    .count_in(read_wr_count),
    .clk_out(cr.clk),
    .reset_out(cr.reset),
    .out(read_out.out),
    .count_out(read_rd_count)
);
always_comb begin
    read_out.ready = ext_mem_read.ready;
    ext_mem_read.enable = read_out.enable;
    ext_mem_read.data = read_out.data;
end

//  Local registers

MAState state;

MemoryCommand cur_request;

//  Counts of interface words
logic [31:0] read_words_needed;
logic [31:0] read_words_requested;
logic [31:0] read_words_filled;
logic [7:0] read_words_pending;
logic [7:0] read_words_align;

logic [31:0] write_words_supplied;
logic [31:0] write_words_submitted;
logic [31:0] write_words_fetched;
logic [7:0] write_words_align;

logic [3:0] read_accum_index;
logic [7:0] write_accum_index;
logic [3:0] write_burst_index;
logic [data_width * DDR3_BURST_LENGTH /  2 / nCK_PER_CLK - 1 : 0] write_data_accum;
logic [data_width * DDR3_BURST_LENGTH / 16 / nCK_PER_CLK - 1 : 0] write_data_accum_mask;

logic [data_width * DDR3_BURST_LENGTH /  2 / nCK_PER_CLK - 1 : 0] read_data_accum;	//	handles data from 1 burst
logic [data_width * DDR3_BURST_LENGTH /  2 / nCK_PER_CLK - 1 : 0] read_data_accum_next;

logic [3:0] reads_in_flight;
logic [3:0] reads_in_flight_next;

//  Local read data FIFO (operates at MIG clock, along with logic)
localparam read_data_depth = 8;
FIFOInterface #(.num_bits(data_width)) read_data_in (cr_mig.clk);
FIFOInterface #(.num_bits(data_width)) read_data_out (cr_mig.clk);
logic [$clog2(read_data_depth):0] read_data_count;
logic read_data_afull;
fifo_sync_sv #(
    .width(data_width),
    .depth(read_data_depth)
) read_data_fifo(
    .cr(cr_mig.client),
    .in(read_data_in.in),
    .out(read_data_out.out),
    .count(read_data_count)
);
always_comb begin
    read_data_in.enable = mig_read_data_valid;
    read_data_in.data = mig_read_data;
    read_data_out.ready = (read_accum_index < (DDR3_BURST_LENGTH / 2 / nCK_PER_CLK));
    read_data_afull = (read_data_count + reads_in_flight > read_data_depth - 4);
end

generate for (genvar g = 0; g < DDR3_BURST_LENGTH / 2 / nCK_PER_CLK; g = g + 1) begin: read_data_assignment
	assign read_data_accum_next[(g+1)*data_width-1:g*data_width] = ((read_accum_index == g) && read_data_out.enable) ? read_data_out.data : read_data_accum[(g+1)*data_width-1:g*data_width];
end
endgenerate

wire [1:0] wr_fifo_pending_words = (write_out.enable && write_out.ready) ? 1 : 0;

//  Some delays to improve timing
logic [31:0] write_words_supplied_buf;
delay_sv #(.num_bits(32)) wws_delay(.cr(cr_mig), .in(write_words_supplied), .out(write_words_supplied_buf));

logic [7:0] write_words_align_buf;
delay_sv #(.num_bits(8)) wwa_delay(.cr(cr_mig), .in(write_words_align), .out(write_words_align_buf));

logic [31:0] read_words_needed_buf;
delay_sv #(.num_bits(32)) rwn_delay(.cr(cr_mig), .in(read_words_needed), .out(read_words_needed_buf));

logic [7:0] read_words_align_buf;
delay_sv #(.num_bits(8)) rwa_delay(.cr(cr_mig), .in(read_words_align), .out(read_words_align_buf));

//	This is needed to make things work properly with the MIG model - ignore for synthesis
//  wire #1 mig_read_data_valid_delay = mig_read_data_valid;
wire mig_read_data_valid_delay = mig_read_data_valid;

function logic [31:0] format_addr(input logic [31:0] base_addr);
    return (base_addr * interface_width) / (data_width / DDR3_BURST_LENGTH) + PHYS_ADDR_OFFSET;
endfunction

/*  Main sequential logic
    Note: all of this is on the mig_clk domain (200 MHz).
*/

always_ff @(posedge cr_mig.clk) if (cr_mig.reset) begin

    state <= MAS_RESET;
    
    cur_request <= 0;
    
    ctl_out.ready <= 0;
    write_out.ready <= 0;
    read_in.enable <= 0;
    read_in.data <= 0;
    
    mig_af_wr_en <= 0;
    mig_af_cmd <= 0;
    mig_af_addr <= 0;
    mig_wdf_wr_en <= 0;
    mig_wdf_data <= 0;
    mig_wdf_mask <= 0;
    mig_wdf_last <= 0;
    
    read_words_needed <= 0;
    read_words_requested <= 0;
    read_words_filled <= 0;
    read_words_pending <= 0;
    read_words_align <= 0;

    read_accum_index <= 0;
    read_data_accum <= 0;

    write_words_supplied <= 0;
    write_words_submitted <= 0;
    write_words_fetched <= 0;
    write_words_align <= 0;

    write_accum_index <= 0;
    write_burst_index <= 0;
    write_data_accum <= 0;
    write_data_accum_mask <= 0;
    
    reads_in_flight <= 0;

end
else begin
    ctl_out.ready <= 0;
    write_out.ready <= 0;
    
    if (read_in.ready) read_in.enable <= 0;

    //  Update count of reads in flight
    reads_in_flight_next = reads_in_flight;
    if (mig_af_wr_en && mig_af_rdy && (mig_af_cmd == INSTR_READ)) reads_in_flight_next++;
    if (mig_read_data_valid) reads_in_flight_next--;
    reads_in_flight <= reads_in_flight_next;

    //  Debug
    if (mig_read_data_valid) assert(read_data_in.ready);

    if (mig_af_rdy) mig_af_wr_en <= 0;

    case (state) 
    
    MAS_RESET: begin
        if (mig_init_done)
            state <= MAS_WAITING;
    end
    
    MAS_WAITING: begin
        ctl_out.ready <= 1;
        if (ctl_out.ready && ctl_out.enable) begin
            cur_request <= ctl_out.data;
            ctl_out.ready <= 0;
            state <= MAS_PARSE_CMD;
        end
    end
    
    MAS_PARSE_CMD: begin
        if (cur_request.read_not_write) begin
            //	Include read_bytes_align in read_bytes_needed
            //	read_bytes_needed <= cmd_fifo_rd_bl + 1;
            read_words_needed <= cur_request.length + (cur_request.address % (word_count * DDR3_BURST_LENGTH / 2 / nCK_PER_CLK));
            read_words_align <= cur_request.address % (word_count * DDR3_BURST_LENGTH / 2 / nCK_PER_CLK);
            state <= MAS_PRE_READ;
        end
        else begin
            write_words_supplied <= cur_request.length;
            write_words_align <= cur_request.address % (word_count * DDR3_BURST_LENGTH / 2 / nCK_PER_CLK);
            state <= MAS_PRE_WRITE;
        end
    
        read_words_requested <= 0;
        read_words_filled <= 0;
        read_words_pending <= 0;
        read_data_accum <= 0;
        write_data_accum <= 0;
        write_data_accum_mask <= 0;
        write_words_submitted <= 0;
        write_words_fetched <= 0;
        write_burst_index <= 0;
        write_accum_index <= 0;
    end
    
    MAS_PRE_WRITE: begin
        //	Let delayed versions of write_bytes_supplied and write_bytes_align catch up
        state <= MAS_WRITE_WAIT;
    end

    MAS_PRE_READ: begin
        //	Let delayed versions of read_bytes_needed and read_bytes_align catch up
        state <= MAS_READ_WAIT;
    end

    MAS_READ_WAIT: begin

        //	if (read_bytes_filled == read_bytes_needed_buf + read_bytes_align_buf) begin
        if (read_words_filled == read_words_needed_buf) begin
            //	Read command finished, we can go on to the next one
            state <= MAS_WAITING;
            read_accum_index <= 0;
            read_words_pending <= 0;
        end
        else if (read_data_out.ready && read_data_out.enable) begin
            //	Let the MIG fill our 1-burst accum register
            read_accum_index <= read_accum_index + 1;
            read_data_accum <= read_data_accum_next;
            read_words_pending <= read_words_pending + word_count;
        end
        //	Wait until the accumulator is completely full before discharging, in case we get data in non-consecutive clock cycles
        else if (read_in.ready && (read_words_pending > 0) && (read_accum_index == DDR3_BURST_LENGTH / 2 / nCK_PER_CLK)) begin
            //	Discharge the burst accum register to the read FIFO, excluding words that weren't part of the original request
            if (read_words_filled >= read_words_align_buf) begin
                read_in.enable <= 1;
                read_in.data <= read_data_accum >> ((word_count * DDR3_BURST_LENGTH / 2 / nCK_PER_CLK - read_words_pending) * interface_width);
                //	rd_fifo_wr_data is set above, outside the if statement
            end
            read_words_filled <= read_words_filled + 1;
            read_words_pending <= read_words_pending - 1;
            //  If we have handled the last word of a burst, start accumulating the next burst.
            if (read_words_pending - 1 == 0)
                read_accum_index <= 0;
        end

        //	if ((read_bytes_requested < read_bytes_needed_buf + read_bytes_align_buf) && (read_bytes_filled == read_bytes_requested) && !mig_af_rdy) begin
        if ((read_words_requested < read_words_needed_buf) && !read_data_afull && mig_af_rdy) begin
            //	Submit burst read requests as long as we need more data and the read FIFO has space.
            mig_af_wr_en <= 1;
            mig_af_cmd <= INSTR_READ;
            //  mig_af_addr <= ((cur_request.address - read_words_align_buf + read_words_requested) * interface_width) / (data_width / DDR3_BURST_LENGTH) + PHYS_ADDR_OFFSET;
            mig_af_addr <= format_addr(cur_request.address - read_words_align_buf + read_words_requested);
            read_words_requested <= read_words_requested + data_width * DDR3_BURST_LENGTH / 2 / nCK_PER_CLK / interface_width;
        end

    end


    MAS_WRITE_WAIT: begin

        if ((write_words_fetched < write_words_supplied_buf - wr_fifo_pending_words) && (write_accum_index < word_count * DDR3_BURST_LENGTH / 2 / nCK_PER_CLK - wr_fifo_pending_words) && !((write_words_submitted == 0) && (write_accum_index + wr_fifo_pending_words < write_words_align_buf)))
            write_out.ready <= 1;
        else
            write_out.ready <= 0;

        //	This assignment is outside the following if statement in order to reduce critical path delay
        //  mig_af_addr <= ((cur_request.address - write_words_align_buf + write_words_submitted) * interface_width) / (data_width / DDR3_BURST_LENGTH) + PHYS_ADDR_OFFSET;
        mig_af_addr <= format_addr(cur_request.address - write_words_align_buf + write_words_submitted);
        mig_wdf_data <= write_data_accum >> (write_burst_index * data_width);
        mig_wdf_mask <= write_data_accum_mask >> (write_burst_index * data_width / 8);

        mig_wdf_last <= 0;	//	overridden below

        if (write_words_submitted >= write_words_supplied_buf + write_words_align_buf) begin
            //	Write command finished, we can go on to the next one
            state <= MAS_WAITING;
            mig_wdf_wr_en <= 0;
            mig_af_wr_en <= 0;
        end
        else if (write_burst_index == DDR3_BURST_LENGTH / nCK_PER_CLK / 2) begin
            //	If we've written a burst worth of write data to the FIFO, submit a command to the MIG.

            //	Only move on if the MIG is ready to.
            if (mig_af_rdy && mig_af_wr_en) begin
                mig_af_wr_en <= 0;
                write_words_submitted <= write_words_submitted + word_count * DDR3_BURST_LENGTH / 2 / nCK_PER_CLK;
                write_burst_index <= 0;
                write_accum_index <= 0;
            end
            else begin
                mig_af_wr_en <= 1;
                mig_af_cmd <= INSTR_WRITE;
                mig_wdf_wr_en <= 0;
            end
        end
        else if (write_accum_index == word_count * DDR3_BURST_LENGTH / 2 / nCK_PER_CLK) begin
            //	Once the data is accumulated, write it to the MIG's write data FIFO.
            //	mig_wdf_data, mig_wdf_mask set outside
            mig_wdf_wr_en <= 1;
            mig_af_wr_en <= 0;

            if (write_burst_index + 1 == DDR3_BURST_LENGTH / nCK_PER_CLK / 2)
                mig_wdf_last <= 1;

            //	Only move on if the MIG is ready to.
            if (mig_wdf_rdy)
                write_burst_index <= write_burst_index + 1;
        end
        else begin
            mig_wdf_wr_en <= 0;
            mig_af_wr_en <= 0;
        end

        //	This if statement broken out separately in order to reduce critical path delay
        if (write_accum_index < word_count * DDR3_BURST_LENGTH / 2 / nCK_PER_CLK) begin
            //	Accumulate data from FIFO in a register wide enough to supply a burst to the MIG.
            if (write_out.enable && write_out.ready) begin
                write_data_accum <= { write_out.data, write_data_accum } >> interface_width;
                write_data_accum_mask <= { {(interface_width / 8){1'b0}}, write_data_accum_mask } >> (interface_width / 8);
                write_words_fetched <= write_words_fetched + 1;
                write_accum_index <= write_accum_index + 1;
            end
            else if (((write_accum_index < write_words_align_buf) && (write_words_submitted == 0)) || (write_words_fetched >= write_words_supplied_buf)) begin
                write_data_accum <= { {interface_width{1'b0}}, write_data_accum } >> interface_width;
                write_data_accum_mask <= { {(interface_width / 8){1'b1}}, write_data_accum_mask } >> (interface_width / 8);
                write_accum_index <= write_accum_index + 1;
            end
        end

    end

    endcase

end

endmodule


