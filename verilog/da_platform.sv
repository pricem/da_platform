
/*
    Skeleton for DA platform being ported to new interfaces
    Michael Price, 8/3/2016

    TODO: 
    - check isolator reset line; does it need to be MCLK synchronous?
    - add commands to read FIFO counters for a slot
    - make slot controller honor circular buffer limits; figure out pause/resume/discard functionality, i.e. commands to adjust FIFO counters 
    - allow 16/24/32 bit data packing (currently it's only 32 bit)
    - add length/checksum to output packets as well, so the software can parse them (there's a bit of guesswork now...)
*/

`timescale 1ns / 1ps

module da_platform #(
    //  Note: mem_width is word width for the interface to the memory controller,
    //  which can be less than that of the physical memory.  The memory controller handles concatenation.
    //  The mem_width is the maximum number of bits per sample, since one sample is stored in each word.
    //  (As of 8/3/2016 the memory controller is yet to be implemented...)
    host_width = 16,
    mem_width = 32,
    mclk_ratio = 8,
    num_slots = 4
) (
    //  Generic memory interface
    ClockReset.client cr_mem,
    FIFOInterface.out mem_cmd,
    FIFOInterface.out mem_write,
    FIFOInterface.in mem_read,
    
    //  Generic host interface
    ClockReset.client cr_host,
    FIFOInterface.in host_in,
    FIFOInterface.out host_out,
    
    //  Interface to isolator board
    IsolatorInterface.fpga iso,
    
    //  Other
    output [3:0] led_debug
);

`include "commands.v"

//  Internal FIFO log depth
localparam M = 10;

genvar g;

//  Core clock domain - for now, just attached to host
ClockReset cr_core ();
always_comb begin
    cr_core.clk = cr_host.clk;
    cr_core.reset = cr_host.reset;
end

//  Drive isolator reset line
//  8/10/2016: DSD1792 reset is active low.
logic reset_local;
logic [7:0] reset_local_counter;
localparam reset_local_timeout_cycles = 200;
always_comb begin
    iso.reset_out = !(cr_core.reset || reset_local);
end

//  MCLK generation, along with a reset synchronized to it
wire mclk_last;
reg reset_mclk;

clk_divider #(.ratio(mclk_ratio)) mclkdiv(cr_core.reset, cr_core.clk, iso.mclk);
delay mclk_delay(cr_core.clk, cr_core.reset, iso.mclk, mclk_last);

always @(posedge cr_core.clk) begin
    if (cr_core.reset)
        reset_mclk <= 1;
    else if (!iso.mclk && mclk_last)
        reset_mclk <= 0;
end

//  SRCLK generation - for serializers
wire srclk_predelay;
clk_divider #(.ratio(64), .threshold(4)) srclkdiv(cr_core.reset, cr_core.clk, srclk_predelay);

always_comb begin
    iso.srclk = !srclk_predelay;
end

reg [3:0] clk_inhibit;
reg [3:0] reset_slots;

wire clk0_last;
delay clk0_delay(cr_core.clk, cr_core.reset, iso.clk0, clk0_last);
wire clk1_last;
delay clk1_delay(cr_core.clk, cr_core.reset, iso.clk1, clk1_last);

//  Parallel versions of serialized signals

wire [7:0] aovf_parallel;
wire [7:0] dirchan_parallel;
wire [7:0] dmcs_parallel;
wire [7:0] amcs_parallel;
reg [7:0] clksel_parallel;

wire [7:0] acon0_parallel;
wire [7:0] acon1_parallel;

deserializer dirchan_des(iso.mclk, iso.dirchan, iso.srclk, dirchan_parallel);
deserializer aovf_des(iso.mclk, iso.aovf, iso.srclk, aovf_parallel);

serializer amcs_ser(iso.mclk, iso.amcs, iso.srclk, amcs_parallel);
serializer dmcs_ser(iso.mclk, iso.dmcs, iso.srclk, dmcs_parallel);
serializer clksel_ser(iso.mclk, iso.clksel, iso.srclk, clksel_parallel);
serializer acon0_ser(iso.mclk, iso.acon[0], iso.srclk, acon0_parallel);
serializer acon1_ser(iso.mclk, iso.acon[1], iso.srclk, acon1_parallel);

//  FIFOs for clock domain conversion (host interface (USB/FX2) to core)
FIFOInterface #(.num_bits(host_width)) host_in_core (cr_core.clk);
FIFOInterface #(.num_bits(host_width)) host_out_core (cr_core.clk);

wire [M:0] host_in_wr_count;
wire [M:0] host_in_rd_count;
wire [M:0] host_out_wr_count;
wire [M:0] host_out_rd_count;

fifo_async_sv2 #(.width(host_width), .depth(1 << M)) host_in_h2c(
    .clk_in(cr_host.clk),
    .reset_in(cr_host.reset),
    .in(host_in),
    .count_in(host_in_wr_count),
    .clk_out(cr_core.clk),
    .reset_out(cr_core.reset),
    .out(host_in_core.out),
    .count_out(host_in_rd_count)
);

fifo_async_sv2 #(.width(host_width), .depth(1 << M), .debug_display(1)) host_out_c2h(
    .clk_in(cr_core.clk),
    .reset_in(cr_core.reset),
    .in(host_out_core.in),
    .count_in(host_out_wr_count),
    .clk_out(cr_host.clk),
    .reset_out(cr_host.reset),
    .out(host_out),
    .count_out(host_out_rd_count)
);

reg [7:0] slot_index;

localparam STATE_IDLE = 4'h0;
localparam STATE_HANDLE_INPUT = 4'h1;
localparam STATE_HANDLE_OUTPUT = 4'h2;

reg [23:0] word_counter;
reg [23:0] fifo_read_length;
reg [23:0] fifo_write_length;
localparam cmd_length_words = 24 / (host_width + 1) + 1;

localparam checksum_words = 2;
reg [host_width * checksum_words - 1 : 0] data_checksum_calculated;
reg [host_width * checksum_words - 1 : 0] data_checksum_received;

reg [7:0] current_cmd;
reg [7:0] current_report;
reg [7:0] report_slot_index;
reg [23:0] report_msg_length;
reg [31:0] report_checksum;
reg [3:0] state;

reg [7:0] report_data_waiting;

reg [7:0] sample_bit_counter;

reg cmd_stall;
reg [7:0] cmd_data_waiting;

//  Monitor AMCS and DMCS to estimate what the values are on the board
wire [7:0] amcs_parallel_est;
wire [7:0] dmcs_parallel_est;
deserializer amcs_des(iso.mclk, iso.amcs, iso.srclk, amcs_parallel_est);
deserializer dmcs_des(iso.mclk, iso.dmcs, iso.srclk, dmcs_parallel_est);

//  Things which are replicated for each slot

assign amcs_parallel[7:4] = 4'b1111;
assign dmcs_parallel[7:4] = 4'b1111;

/*  FIFO interface declarations
    - Audio data goes through RAM-based arbiter; control data goes through plain FIFOs
    - "In" refers to data coming from the host (i.e. commands, or DAC samples);
      "Out" refers to data going to the host (i.e. responses, or ADC samples).
    - For audio, "Write" refers to the FIFO going into the arbiter, "read" is the one coming out.
      The connection of these FIFOs is reversed for the "in" and "out" directions.
 */

FIFOInterface #(.num_bits(32)) aud_slots_in_write[num_slots] (cr_core.clk);
FIFOInterface #(.num_bits(32)) aud_slots_in_read[num_slots] (cr_core.clk);

FIFOInterface #(.num_bits(32)) aud_slots_out_write[num_slots] (cr_core.clk);
//  FIFOInterface #(.num_bits(32)) aud_slots_out_read[num_slots] (cr_core.clk);

FIFOInterface #(.num_bits(host_width)) ctl_slots_in[num_slots] (cr_core.clk);
FIFOInterface #(.num_bits(host_width)) ctl_slots_out[num_slots] (cr_core.clk);

//  RAM-based arbiter for audio FIFOs
//  (in both directions; that's why num_ports = num_slots * 2
//  The inputs and outputs of the arbiter include audio FIFOs in both directions, 
//  and we can't concatenate interface arrays, so there is some plumbing here.

//  Temporary - breakout FIFO interfaces
logic arb_in_ready[num_slots * 2];
logic arb_in_enable[num_slots * 2];
logic [31:0] arb_in_data[num_slots * 2];
logic arb_out_ready[num_slots * 2];
logic arb_out_enable[num_slots * 2];
logic [31:0] arb_out_data[num_slots * 2];

generate for (g = 0; g < num_slots; g++) always_comb begin
    //  Audio in (DAC) has arbitrator I/O ports from 0 to num_slots - 1
    aud_slots_in_write[g].ready = arb_in_ready[g];
    arb_in_enable[g] = aud_slots_in_write[g].enable;
    arb_in_data[g] = aud_slots_in_write[g].data;

    arb_out_ready[g] = aud_slots_in_read[g].ready;
    aud_slots_in_read[g].enable = arb_out_enable[g];
    aud_slots_in_read[g].data = arb_out_data[g];
    
    //  Audio out (ADC) has arbitrator I/O ports from num_slots to 2 * num_slots - 1
    aud_slots_out_write[g].ready = arb_in_ready[num_slots + g];
    arb_in_enable[num_slots + g] = aud_slots_out_write[g].enable;
    arb_in_data[num_slots + g] = aud_slots_out_write[g].data;
    /*
    arb_out_ready[num_slots + g] = aud_slots_out_read[g].ready;
    aud_slots_out_read[g].enable = arb_out_enable[num_slots + g];
    aud_slots_out_read[g].data = arb_out_data[num_slots + g];
    */
end
endgenerate

logic [31:0] fifo_write_counters[num_slots * 2];
logic [31:0] fifo_read_counters[num_slots * 2];

fifo_arbiter #(.num_ports(num_slots * 2), .mem_width(mem_width)) arbiter(
    .cr_core(cr_core),
    /*
    .ports_in(arb_in.in),
    .ports_out(arb_out.out),
    */
    //  Temporary - breakout FIFO interfaces
    .ports_in_ready(arb_in_ready),
    .ports_in_enable(arb_in_enable),
    .ports_in_data(arb_in_data),
    .ports_out_ready(arb_out_ready),
    .ports_out_enable(arb_out_enable),
    .ports_out_data(arb_out_data),
    
    .cr_mem(cr_mem),
    .mem_cmd(mem_cmd),
    .mem_read(mem_read),
    .mem_write(mem_write),
    
    .write_counters(fifo_write_counters),
    .read_counters(fifo_read_counters)
);

//  Master FIFO interfaces that the logic below deals with
//  (port connection is automatically selected)

FIFOInterface #(.num_bits(32)) aud_in_write (cr_core.clk);
FIFOInterface #(.num_bits(32)) aud_in_read (cr_core.clk);
FIFOInterface #(.num_bits(32)) aud_out_write (cr_core.clk);
//  FIFOInterface #(.num_bits(32)) aud_out_read (cr_core.clk);

FIFOInterface #(.num_bits(host_width)) ctl_in (cr_core.clk);
//  FIFOInterface #(.num_bits(host_width)) ctl_out (cr_core.clk);

//  Extra flow control for host input FIFO
logic host_in_ready_int;
always_comb begin
    host_in_core.ready = host_in_ready_int;
    if ((state == STATE_HANDLE_INPUT) && (slot_index != GLOBAL_TARGET_INDEX)) begin
        if ((current_cmd == AUD_FIFO_WRITE) && !aud_in_write.ready)
            host_in_core.ready = 0;
        if ((current_cmd == CMD_FIFO_WRITE) && !ctl_in.ready)
            host_in_core.ready = 0;
    end
end

/*
//  Extra flow control for audio and control FIFOs
logic aud_out_read_ready_int;
logic ctl_out_ready_int;
always_comb begin
    aud_out_read.ready = aud_out_read_ready_int;
    ctl_out.ready = ctl_out_ready_int;
end
*/

//  New experiment for slot muxing - 8/9/2016
logic ctl_slots_in_ready[num_slots];
logic ctl_slots_out_ready[num_slots];
logic ctl_slots_out_enable[num_slots];
logic ctl_slots_out_waiting[num_slots];
logic [host_width - 1 : 0] ctl_slots_out_data[num_slots];
generate for (g = 0; g < num_slots; g++) begin: ctl_slot_map
    always_comb begin
        ctl_slots_out[g].data[15:8] = 0;    //  since slot controller ctl output is currently 8 bits wide
    
        ctl_slots_in_ready[g] = ctl_slots_in[g].ready;
        ctl_slots_out[g].ready = ctl_slots_out_ready[g];
        ctl_slots_out_enable[g] = ctl_slots_out[g].enable;
        ctl_slots_out_data[g] = ctl_slots_out[g].data;
    end
end
endgenerate

always_comb begin
    aud_in_write.ready = 0;
    //  aud_out_read.enable = 0;
    //  aud_out_read.data = 0;
    for (int i = 0; i < num_slots; i++) if (slot_index == i) begin
        aud_in_write.ready = arb_in_ready[i];
        //  aud_out_read.enable = arb_out_enable[num_slots + i];
        //  aud_out_read.data = arb_out_data[num_slots + i];
    end
    
    ctl_in.ready = 0;
    //  ctl_out.enable = 0;
    //  ctl_out.data = 0;
    for (int i = 0; i < num_slots; i++) if (slot_index == i) begin
        ctl_in.ready = ctl_slots_in_ready[i];
        //  ctl_out.enable = ctl_slots_out_enable[i];
        //  ctl_out.data = ctl_slots_out_data[i];
    end
end

generate for (g = 0; g < num_slots; g++) begin: slots

    //  Muxing of audio FIFOs.  Assignment to array elements can be done with always_comb,
    //  but assignment to master interfaces has to be done with assign.
    always_comb begin
        if (slot_index == g) begin
            aud_slots_in_write[g].enable = aud_in_write.enable;
            aud_slots_in_write[g].data = aud_in_write.data;
            //  aud_slots_out_read[g].ready = aud_out_read.ready;
        end
        else begin
            aud_slots_in_write[g].enable = 0;
            aud_slots_in_write[g].data = 0;
            //  aud_slots_out_read[g].ready = 0;
        end
    end
    
    //  Muxing of control FIFOs.
    always_comb begin
        if (slot_index == g) begin
            ctl_slots_in[g].enable = ctl_in.enable;
            ctl_slots_in[g].data = ctl_in.data;
            //  ctl_slots_out[g].ready = ctl_out.ready;

        end
        else begin
            ctl_slots_in[g].enable = 0;
            ctl_slots_in[g].data = 0;
            //  ctl_slots_out[g].ready = 0;
        end
    end

    //  Muxing of isolator interface signals
    wire slot_clk = (!clk_inhibit[g]) && (clksel_parallel[g] ? iso.clk1 : iso.clk0);

    wire slot_dir = dirchan_parallel[g];
    wire slot_chan = dirchan_parallel[g+4];
    wire [1:0] slot_aovf = aovf_parallel[(g+1)*2-1:g*2];
    
    wire [7:0] slot_acon;
    assign acon0_parallel = ((slot_dir == 0) && (g == 0)) ? slot_acon : 8'bzzzzzzzz;
    assign acon1_parallel = ((slot_dir == 0) && (g == 2)) ? slot_acon : 8'bzzzzzzzz;

    wire slot_spi_ss_out;
    assign amcs_parallel[g] = !((slot_dir == 0) && (slot_spi_ss_out == 0));
    assign dmcs_parallel[g] = !((slot_dir == 1) && (slot_spi_ss_out == 0));
    wire slot_spi_ss_in = slot_dir ? dmcs_parallel_est[g] : amcs_parallel_est[g];
    wire slot_spi_sck;
    wire slot_spi_mosi;
    assign iso.amdi = ((slot_dir == 0) && (slot_spi_ss_in == 0)) ? slot_spi_mosi : 1'bz;
    assign iso.dmdi = ((slot_dir == 1) && (slot_spi_ss_in == 0)) ? slot_spi_mosi : 1'bz;
    wire slot_spi_miso = slot_dir ? iso.dmdo : iso.amdo;
    
    //  Debug - monitor SPI state
    wire [3:0] slot_spi_state;
    assign led_debug = (g == 0) ? slot_spi_state : 4'bzzzz;

    //  Slot controllers
    //  Note: control protocol uses 8 LSBs only
    slot_controller ctl(
        .clk_core(cr_core.clk), 
        .reset(reset_slots[g]),
        .ctl_rd_valid(ctl_slots_in[g].enable), 
        .ctl_rd_data(ctl_slots_in[g].data[7:0]), 
        .ctl_rd_ready(ctl_slots_in[g].ready),
        .ctl_wr_valid(ctl_slots_out[g].enable), 
        .ctl_wr_data(ctl_slots_out[g].data[7:0]), 
        .ctl_wr_ready(ctl_slots_out[g].ready),
        .ctl_wr_waiting(ctl_slots_out_waiting[g]),
        .aud_rd_valid(aud_slots_in_read[g].enable), 
        .aud_rd_data(aud_slots_in_read[g].data), 
        .aud_rd_ready(aud_slots_in_read[g].ready),
        .aud_wr_valid(aud_slots_out_write[g].enable), 
        .aud_wr_data(aud_slots_out_write[g].data), 
        .aud_wr_ready(aud_slots_out_write[g].ready),
        .spi_ss_out(slot_spi_ss_out), 
        .spi_ss_in(slot_spi_ss_in),
        .spi_sck(slot_spi_sck), 
        .spi_mosi(slot_spi_mosi), 
        .spi_miso(slot_spi_miso),
        .slot_data(iso.slotdata[(g+1)*6-1:g*6]), 
        .slot_clk(slot_clk), 
        .mclk(iso.mclk), 
        .dir(slot_dir), 
        .chan(slot_chan), 
        .acon(slot_acon), 
        .aovf(slot_aovf),
        .spi_state(slot_spi_state)
    );

end
endgenerate

//  Audio output (ADC) FIFO:
//  Stores samples so they can be sent out in batches.
//  FIFO interfaces and some control registers

localparam audio_out_fifo_depth = 128;
localparam audio_out_fifo_timeout_cycles = 1200;  //  should normally be 48000 (1 ms), but that makes simulation longer

FIFOInterface #(.num_bits(32)) audio_out_fifo_in(cr_core.clk);
FIFOInterface #(.num_bits(32)) audio_out_fifo_out(cr_core.clk);
logic [$clog2(audio_out_fifo_depth):0] audio_out_fifo_count;
logic [1:0] audio_out_fifo_slot;
logic audio_out_fifo_write_active;
logic audio_out_fifo_read_active;

logic [15:0] audio_out_lsb_word;
logic audio_out_lsb_pending;

logic [15:0] audio_out_fifo_timeout_counter;

fifo_sync_sv #(.width(32), .depth(audio_out_fifo_depth)) audio_out_fifo(
    .cr(cr_core),
    .in(audio_out_fifo_in.in),
    .out(audio_out_fifo_out.out),
    .count(audio_out_fifo_count)
);

always_comb begin
    //  Connect selected arb_out port to audio_out_fifo_in when audio_out_fifo_write_active = 1
    audio_out_fifo_in.enable = 0;
    audio_out_fifo_in.data = 0;
    if (audio_out_fifo_write_active) begin
        audio_out_fifo_in.enable = arb_out_enable[num_slots + audio_out_fifo_slot];
        audio_out_fifo_in.data = arb_out_data[num_slots + audio_out_fifo_slot];
    end
    //  Stall audio_out_fifo_out when host isn't ready
    audio_out_fifo_out.ready = audio_out_fifo_read_active && !audio_out_lsb_pending && host_out_core.ready;
end

generate for (g = 0; g < num_slots; g = g + 1) begin
    always_comb begin
        arb_out_ready[num_slots + g] = 0;
        if (audio_out_fifo_write_active && (g == audio_out_fifo_slot)) 
            arb_out_ready[num_slots + g] = audio_out_fifo_in.ready;
    end
end
endgenerate

//  Control output FIFO:
//  Same idea as audio output FIFO: give each slot a certain window of time to provide control messages
//  This also helps since we'll know the right length in advance by watching the FIFO count
localparam ctl_out_fifo_depth = 32;
localparam ctl_out_fifo_timeout_cycles = 480;   //  10 us

FIFOInterface #(.num_bits(host_width)) ctl_out_fifo_in(cr_core.clk);
FIFOInterface #(.num_bits(host_width)) ctl_out_fifo_out(cr_core.clk);
logic [$clog2(ctl_out_fifo_depth):0] ctl_out_fifo_count;
logic [1:0] ctl_out_fifo_slot;
logic ctl_out_fifo_write_active;
logic ctl_out_fifo_read_active;

logic [15:0] ctl_out_fifo_timeout_counter;

fifo_sync_sv #(.width(host_width), .depth(ctl_out_fifo_depth)) ctl_out_fifo(
    .cr(cr_core),
    .in(ctl_out_fifo_in.in),
    .out(ctl_out_fifo_out.out),
    .count(ctl_out_fifo_count)
);

always_comb begin
    //  Connect selected ctl_out port to audio_out_fifo_in when audio_out_fifo_write_active = 1
    for (int i = 0; i < num_slots; i++) ctl_slots_out_ready[i] = 0;
    ctl_out_fifo_in.enable = 0;
    ctl_out_fifo_in.data = 0;
    if (ctl_out_fifo_write_active) begin
        ctl_slots_out_ready[ctl_out_fifo_slot] = ctl_out_fifo_in.ready;
        ctl_out_fifo_in.enable = ctl_slots_out_enable[ctl_out_fifo_slot];
        ctl_out_fifo_in.data = ctl_slots_out_data[ctl_out_fifo_slot];
    end
    //  Stall audio_out_fifo_out when host isn't ready
    ctl_out_fifo_out.ready = ctl_out_fifo_read_active && host_out_core.ready;
end


//  Temporary echo FIFO
reg echo_wr_valid;
reg [7:0] echo_wr_data;
wire echo_wr_ready;
reg echo_rd_ready;
wire echo_rd_valid;
wire [7:0] echo_rd_data;
wire [4:0] echo_fifo_count;
fifo_sync #(.Nb(8), .M(4)) echo_fifo(
	.clk(cr_core.clk), 
	.reset(cr_core.reset),
	.wr_valid(echo_wr_valid), 
	.wr_data(echo_wr_data),
	.wr_ready(echo_wr_ready),
	.rd_ready(echo_rd_ready),
	.rd_valid(echo_rd_valid), 
	.rd_data(echo_rd_data),
	.count(echo_fifo_count)
);
reg [3:0] echo_count;

//  Sequential logic
integer i;

always @(posedge cr_core.clk) begin
    if (cr_core.reset) begin
        host_in_ready_int <= 0;
        host_out_core.enable <= 0;
        host_out_core.data <= 0;
        
        slot_index <= 0;
        report_slot_index <= 0;
        
        aud_in_write.enable <= 0;
        aud_in_write.data <= 0;
        //  aud_out_read_ready_int <= 0;
        ctl_in.enable <= 0;
        ctl_in.data <= 0;
        //  ctl_out_ready_int <= 0;

        clksel_parallel <= 0;
        clk_inhibit <= 0;
        reset_slots <= 4'hF;
        
        word_counter <= 0;
        fifo_read_length <= 0;
        fifo_write_length <= 0;
        data_checksum_calculated <= 0;
        data_checksum_received <= 0;
        current_cmd <= 0;
        current_report <= 0;
        state <= STATE_IDLE;
        
        report_data_waiting <= 0;
        report_msg_length <= 0;
        report_checksum <= 0;

        echo_wr_valid <= 0;
        echo_wr_data <= 0;
        echo_rd_ready <= 0;
        echo_count <= 0;

        cmd_stall <= 0;
        cmd_data_waiting <= 0;

        sample_bit_counter <= 0;

        audio_out_fifo_slot <= 0;
        audio_out_fifo_write_active <= 0;
        audio_out_fifo_read_active <= 0;
        audio_out_fifo_timeout_counter <= 0;
        audio_out_lsb_pending <= 0;
        audio_out_lsb_word <= 0;
        
        ctl_out_fifo_slot <= 0;
        ctl_out_fifo_write_active <= 0;
        ctl_out_fifo_read_active <= 0;
        ctl_out_fifo_timeout_counter <= 0;
        
        reset_local <= 0;
        reset_local_counter <= 0;
    end
    else begin
        host_in_ready_int <= 0;
        if (host_out_core.ready) host_out_core.enable <= 0;

        if (aud_in_write.ready) aud_in_write.enable <= 0;
        //  aud_out_read_ready_int <= 0;
        if (ctl_in.ready) ctl_in.enable <= 0;
        //  ctl_out_ready_int <= 0;

        echo_wr_valid <= 0;
        echo_rd_ready <= 0;
        clk_inhibit <= 0;

        if (reset_local) begin
            if (reset_local_counter == reset_local_timeout_cycles - 1)
                reset_local <= 0;
            else
                reset_local_counter <= reset_local_counter + 1;
        end

        for (i = 0; i < 4; i = i + 1) begin
            if (reset_slots[i] && !clk_inhibit[i] && !reset_mclk) begin
                //  Wait for clock pulse of selected clock before disabling reset for that slot
                if (clksel_parallel[i] == 1'b1) begin
                    if (iso.clk1 && !clk1_last) begin
                        reset_slots[i] <= 0;
                    end
                end
                else begin
                    if (iso.clk0 && !clk0_last) begin
                        reset_slots[i] <= 0;
                    end
                end
            end
        end

        if (host_out_core.ready && host_out_core.enable)
            report_checksum <= report_checksum + host_out_core.data;

        case (state)
        STATE_IDLE: begin
            
            host_in_ready_int <= 1;

            if (host_in_core.ready && host_in_core.enable) begin
                slot_index <= host_in_core.data;
                word_counter <= 0;
                state <= STATE_HANDLE_INPUT;
            end
            else begin
                
                if ((ctl_out_fifo_count == ctl_out_fifo_depth) || (ctl_out_fifo_timeout_counter == ctl_out_fifo_timeout_cycles)) begin
                    //  If the control output FIFO has filled, go output it to the host.
                    ctl_out_fifo_write_active <= 0;
                    ctl_out_fifo_timeout_counter <= 0;
                    report_slot_index <= ctl_out_fifo_slot;
                    report_msg_length <= ctl_out_fifo_count;
                    report_checksum <= 0;
                    word_counter <= 0;
                    current_report <= CMD_FIFO_REPORT;
                    state <= STATE_HANDLE_OUTPUT;
                end
                else if ((audio_out_fifo_count == audio_out_fifo_depth) || (audio_out_fifo_timeout_counter == audio_out_fifo_timeout_cycles)) begin
                    //  If the audio output FIFO has filled, go output it to the host.
                    audio_out_fifo_write_active <= 0;
                    audio_out_fifo_timeout_counter <= 0;
                    audio_out_lsb_pending <= 0;
                    report_slot_index <= audio_out_fifo_slot;
                    report_msg_length <= audio_out_fifo_count * (32 / host_width);
                    report_checksum <= 0;
                    word_counter <= 0;
                    current_report <= AUD_FIFO_REPORT;
                    state <= STATE_HANDLE_OUTPUT;
                end

                /*  Parallel part 1: audio FIFO management */
                
                //  Update cycle counter for timeout
                if (audio_out_fifo_write_active) begin
                    if (audio_out_fifo_in.enable)
                        audio_out_fifo_timeout_counter <= 0;
                    else if (audio_out_fifo_timeout_counter < audio_out_fifo_timeout_cycles)
                        audio_out_fifo_timeout_counter <= audio_out_fifo_timeout_counter + 1;
                end
            
                //  Start an audio output transfer if there is valid data at the next slot
                if (!audio_out_fifo_write_active) begin
                    assert (audio_out_fifo_count == 0);
                    if (arb_out_enable[num_slots + audio_out_fifo_slot]) begin
                        audio_out_fifo_timeout_counter <= 0;
                        audio_out_fifo_write_active <= 1;
                    end
                    else begin
                        //  Cycle the slot index so we're always checking for data
                        if (audio_out_fifo_slot == num_slots - 1)
                            audio_out_fifo_slot <= 0;
                        else
                            audio_out_fifo_slot <= audio_out_fifo_slot + 1;
                    end
                end


                /*  Parallel part 2: control FIFO management */
                
                //  Update cycle counter for timeout
                if (ctl_out_fifo_write_active) begin
                    if (ctl_out_fifo_in.enable)
                        ctl_out_fifo_timeout_counter <= 0;
                    else if (ctl_out_fifo_timeout_counter < ctl_out_fifo_timeout_cycles)
                        ctl_out_fifo_timeout_counter <= ctl_out_fifo_timeout_counter + 1;
                end
            
                //  Start an audio output transfer if there is valid data at the next slot
                if (!ctl_out_fifo_write_active) begin
                    assert (ctl_out_fifo_count == 0);
                    if (ctl_slots_out_waiting[ctl_out_fifo_slot]) begin
                        ctl_out_fifo_timeout_counter <= 0;
                        ctl_out_fifo_write_active <= 1;
                    end
                    else begin
                        //  Cycle the slot index so we're always checking for data
                        if (ctl_out_fifo_slot == num_slots - 1)
                            ctl_out_fifo_slot <= 0;
                        else
                            ctl_out_fifo_slot <= ctl_out_fifo_slot + 1;
                    end
                end

            end

        end
        STATE_HANDLE_INPUT: begin
            /*
                This state is entered after the target slot has been read and stored
                in slot_index.
                - Byte counter = 0: command index
                - Byte counter = 1 to N - 1: command-specific data
            */
            host_in_ready_int <= 1;
            if (host_in_core.ready && host_in_core.enable) begin
                word_counter <= word_counter + 1;
                if (word_counter == 0) begin
                    current_cmd <= host_in_core.data;
                    data_checksum_calculated <= 0;
                    data_checksum_received <= 0;
                    report_checksum <= 0;
                    case (host_in_core.data)
                    DIRCHAN_READ: begin
                        word_counter <= 0;
                        report_slot_index <= GLOBAL_TARGET_INDEX;
                        report_msg_length <= 1;
                        current_report <= DIRCHAN_REPORT;
                        state <= STATE_HANDLE_OUTPUT;
                    end
                    AOVF_READ: begin
                        word_counter <= 0;
                        report_slot_index <= GLOBAL_TARGET_INDEX;
                        report_msg_length <= 1;
                        current_report <= AOVF_REPORT;
                        state <= STATE_HANDLE_OUTPUT;
                    end
                    FIFO_READ_STATUS: begin
                        word_counter <= 0;
                        report_slot_index <= GLOBAL_TARGET_INDEX;
                        report_msg_length <= num_slots * 4 * 32 / host_width;
                        current_report <= FIFO_REPORT_STATUS;
                        state <= STATE_HANDLE_OUTPUT;
                    end
                    RESET_SLOTS: begin
                        reset_local <= 1;
                        reset_local_counter <= 0;
                        state <= STATE_IDLE;
                    end
                    endcase
                end
                else case (current_cmd)
                AUD_FIFO_WRITE, CMD_FIFO_WRITE: begin
                    if (word_counter < (1 + cmd_length_words)) begin
                        fifo_read_length <= {fifo_read_length, host_in_core.data};
                        sample_bit_counter <= 0;
                    end
                    else if (word_counter > fifo_read_length + cmd_length_words) begin
                        data_checksum_received <= {data_checksum_received, host_in_core.data};
                        if (word_counter == fifo_read_length + cmd_length_words + checksum_words) begin
                            //  Compare checksums
                            if ({data_checksum_received, host_in_core.data} != data_checksum_calculated) begin
                                word_counter <= 0;
                                report_slot_index <= slot_index;
                                report_msg_length <= 4;
                                current_report <= CHECKSUM_ERROR;
                                state <= STATE_HANDLE_OUTPUT;
                            end
                            else
                                state <= STATE_IDLE;
                        end
                    end
                    else begin
                        if (current_cmd == AUD_FIFO_WRITE) begin
                            //  Data is written to target FIFO
                            if (sample_bit_counter + host_width >= 32) begin
                                aud_in_write.enable <= 1;
                                sample_bit_counter <= 0;
                            end
                            else begin
                                aud_in_write.enable <= 0;
                                sample_bit_counter <= sample_bit_counter + host_width;
                            end
                            aud_in_write.data <= {aud_in_write.data, host_in_core.data};
                        end
                        else begin // if (current_cmd == CMD_FIFO_WRITE)
                            ctl_in.enable <= 1;
                            ctl_in.data <= host_in_core.data;
                        end
                        
                        //  Update checksum
                        data_checksum_calculated <= data_checksum_calculated + host_in_core.data;
                    end
                end

                ECHO_SEND: begin
                    if (word_counter == 1) begin
                        echo_count <= host_in_core.data;
                    end
                    else begin
                        echo_wr_valid <= 1;
                        echo_wr_data <= host_in_core.data;
                        if (word_counter == echo_count + 1) begin
                            word_counter <= 0;
                            report_slot_index <= slot_index;
                            report_msg_length <= echo_count;
                            current_report <= ECHO_REPORT;
                            state <= STATE_HANDLE_OUTPUT;
                        end
                    end
                end

                SELECT_CLOCK: begin
                    //  For each slot that is being switched over, stop the clock and reset it.
                    clk_inhibit <= (clksel_parallel ^ host_in_core.data);
                    reset_slots <= (clksel_parallel ^ host_in_core.data);
                    clksel_parallel <= host_in_core.data;
                    state <= STATE_IDLE;
                end
                
                endcase
                
            end
        end
        STATE_HANDLE_OUTPUT: begin
            if (host_out_core.ready) begin

                word_counter <= word_counter + 1;
                host_out_core.enable <= 1;
                if (word_counter < 4) case (word_counter)
                    //  Header
                    0:  host_out_core.data <= report_slot_index;
                    1:  host_out_core.data <= current_report;
                    2:  host_out_core.data <= report_msg_length[23:16];
                    3:  host_out_core.data <= report_msg_length[15:0];
                endcase
                else if (word_counter < 4 + report_msg_length) begin
                    //  Message contents
                    case (current_report)
                    AUD_FIFO_REPORT: begin
                        audio_out_fifo_read_active <= 1;
                        if (audio_out_fifo_out.ready && audio_out_fifo_out.enable) begin
                            //  This will need to be reworked if host width is changed from 16 bits
                            host_out_core.data <= audio_out_fifo_out.data[15:0];
                            audio_out_lsb_word <= audio_out_fifo_out.data[31:16];
                            audio_out_lsb_pending <= 1;
                        end
                        else if (audio_out_lsb_pending) begin
                            host_out_core.data <= audio_out_lsb_word;
                            audio_out_lsb_pending <= 0;
                        end
                        else begin
                            //  Skip...
                            host_out_core.enable <= 0;
                            word_counter <= word_counter;
                        end
                    end
                    CMD_FIFO_REPORT: begin
                        ctl_out_fifo_read_active <= 1;
                        if (ctl_out_fifo_out.ready && ctl_out_fifo_out.enable)
                            host_out_core.data <= ctl_out_fifo_out.data;
                        else begin
                            //  Skip...
                            host_out_core.enable <= 0;
                            word_counter <= word_counter;
                        end
                    end
                    DIRCHAN_REPORT: begin
                    	host_out_core.data <= dirchan_parallel;
                    end
                    AOVF_REPORT: begin
                        host_out_core.data <= aovf_parallel;
                    end
                    FIFO_REPORT_STATUS: begin
                        case ((word_counter - 4) % 4)
                        0: host_out_core.data <= fifo_write_counters[(word_counter - 4) / 4][31:16];
                        1: host_out_core.data <= fifo_write_counters[(word_counter - 4) / 4][15:0];
                        2: host_out_core.data <= fifo_read_counters[(word_counter - 4) / 4][31:16];
                        3: host_out_core.data <= fifo_read_counters[(word_counter - 4) / 4][15:0];
                        endcase
                    end
                    CHECKSUM_ERROR: begin
                        //  TODO: Fix
                        case (word_counter)
                        4: host_out_core.data <= data_checksum_received[15:8];
                        5: host_out_core.data <= data_checksum_received[7:0];
                        6: host_out_core.data <= data_checksum_calculated[15:8];
                        7: host_out_core.data <= data_checksum_calculated[7:0];
                        endcase
                    end
                    ECHO_REPORT: begin
                        echo_rd_ready <= 1;
                        if (echo_rd_valid) begin
                            host_out_core.data <= echo_rd_data;
                        end
                        else begin
                            //  Skip...
                            host_out_core.enable <= 0;
                            word_counter <= word_counter;
                        end
                    end
                    endcase
                end
                else begin
                    //  Stop changing the checksum when we're outputting the checksum...
                    report_checksum <= report_checksum;
                    
                    //  Footer (checksum)
                    case (word_counter)
                    4 + report_msg_length: host_out_core.data <= report_checksum[31:16];
                    5 + report_msg_length: begin
                        host_out_core.data <= report_checksum[15:0];
                        word_counter <= 0;
                        audio_out_fifo_read_active <= 0;
                        ctl_out_fifo_read_active <= 0;
                        state <= STATE_IDLE;
                    end
                    endcase
                end

            end
        end
        endcase
    end
end


endmodule


