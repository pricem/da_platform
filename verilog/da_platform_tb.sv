
/*
    Testbench for DA platform
    
    Uses behavioral models of USB host interface (via FX2) and DDR3 memory (AXI slave)
    and checks basic features such as SPI masters and audio I/O.  Limited coverage.
    
    Michael Price, 8/3/2016
*/

`timescale 1ns / 1ps

module da_platform_tb #(
    mem_width = 32,
    host_width = 16,
    mem_log_depth = 20
) ();

localparam num_slots = 4;

`include "commands.vh"
`include "structures.sv"

logic reset;

logic clk_mem;
FIFOInterface #(.num_bits(65 /* $sizeof(MemoryCommand) */)) mem_cmd (clk_mem);
FIFOInterface #(.num_bits(mem_width)) mem_write (clk_mem);
FIFOInterface #(.num_bits(mem_width)) mem_read (clk_mem);

logic clk_host;
wire tb_host_clk;
FIFOInterface #(.num_bits(host_width)) host_in (tb_host_clk);
FIFOInterface #(.num_bits(host_width)) host_out (tb_host_clk);

IsolatorInterface iso ();
logic [3:0] led_debug;

`ifdef USE_WRAPPER
//  Use a wrapper and more realistic interfaces
wire [15:0] ddr3_dq;
wire [1:0] ddr3_dqs_n;
wire [1:0] ddr3_dqs_p;
wire [13:0] ddr3_addr;
wire [2:0] ddr3_ba;
wire ddr3_ras_n;
wire ddr3_cas_n;
wire ddr3_we_n; 
wire ddr3_reset_n;
wire [0:0] ddr3_ck_p;
wire [0:0] ddr3_ck_n;
wire [0:0] ddr3_cke;
wire [1:0] ddr3_dm;
wire [0:0] ddr3_odt;

wire fx2_ifclk;
wire [15:0] fx2_fd;
wire fx2_slwr;
wire fx2_pktend;
wire fx2_slrd;
wire fx2_sloe;
wire [1:0] fx2_fifoaddr;
wire fx2_empty_flag;
wire fx2_full_flag;

assign tb_host_clk = fx2_ifclk;

da_platform_wrapper dut(
    .fxclk_in(fx2_ifclk),
    .ifclk_in(fx2_ifclk),
    .reset(reset),
    .ddr3_dq(ddr3_dq),
    .ddr3_dqs_n(ddr3_dqs_n),
    .ddr3_dqs_p(ddr3_dqs_p),
    .ddr3_addr(ddr3_addr),
    .ddr3_ba(ddr3_ba),
    .ddr3_ras_n(ddr3_ras_n),
    .ddr3_cas_n(ddr3_cas_n),
    .ddr3_we_n(ddr3_we_n),
    .ddr3_reset_n(ddr3_reset_n),
    .ddr3_ck_p(ddr3_ck_p),
    .ddr3_ck_n(ddr3_ck_n),
    .ddr3_cke(ddr3_cke),
    .ddr3_dm(ddr3_dm),
    .ddr3_odt(ddr3_odt),
    .fx2_fd(fx2_fd),
    .fx2_slwr(fx2_slwr), 
    .fx2_slrd(fx2_slrd),
    .fx2_sloe(fx2_sloe), 
    .fx2_fifoaddr0(fx2_fifoaddr[0]), 
    .fx2_fifoaddr1(fx2_fifoaddr[1]), 
    .fx2_pktend(fx2_pktend),
    .fx2_flaga(fx2_empty_flag), 
    .fx2_flagb(fx2_full_flag),
    /*
    .iso_slotdata(iso.slotdata),
    .iso_mclk(iso.mclk),
    .iso_amcs(iso.amcs),
    .iso_amdi(iso.amdi), 
    .iso_amdo(iso.amdo), 
    .iso_dmcs(iso.dmcs), 
    .iso_dmdi(iso.dmdi), 
    .iso_dmdo(iso.dmdo), 
    .iso_dirchan(iso.dirchan),
    .iso_acon(iso.acon),
    .iso_aovf(iso.aovf),
    .iso_clk0(iso.clk0), 
    .iso_reset_out(iso.reset_out),
    .iso_srclk(iso.srclk),
    .iso_clksel(iso.clksel),
    .iso_clk1(iso.clk1),
    */
    .iso(iso.fpga),
    .led_debug(led_debug)
);

fx2_model fx2(
    .reset,
    .ifclk(fx2_ifclk),
    .fd(fx2_fd),
    .SLWR(fx2_slwr), 
    .PKTEND(fx2_pktend),
    .SLRD(fx2_slrd), 
    .SLOE(fx2_sloe), 
    .FIFOADDR(fx2_fifoaddr),
    .EMPTY_FLAG(fx2_empty_flag),
    .FULL_FLAG(fx2_full_flag),
    .in(host_in.in),
    .out(host_out.out)
);

`ifndef USE_MIG_MODEL
//  DDR3 SDRAM model
//  (note: if USE_MIG_MODEL is defined, that means the da_platform_wrapper module instantiated a simplified model
//  of the MIG+DDR3 combination, and thus the detailed model of the DDR3 memory itself doesn't need to be instantiated.)
ddr3_model mem (
    .rst_n(ddr3_rst_n),
    .ck(ddr3_ck_p),
    .ck_n(ddr3_ck_n),
    .cke(ddr3_cke),
    .cs_n(1'b0),    //  always selected, only 1 chip
    .ras_n(ddr3_ras_n),
    .cas_n(ddr3_cas_n),
    .we_n(ddr3_we_n),
    .dm_tdqs(ddr3_dm),
    .ba(ddr3_ba),
    .addr(ddr3_addr),
    .dq(ddr3_dq),
    .dqs(ddr3_dqs_p),
    .dqs_n(ddr3_dqs_n),
    .tdqs_n(ddr3_tqds_n),
    .odt(ddr3_odt)
);
`endif

`else
//  Instantiate core DA Platform logic directly

assign tb_host_clk = clk_host;

da_platform #(
    .mem_width(mem_width),
    .host_width(host_width)
) dut(
    .reset,
    .clk_mem,
    .mem_cmd(mem_cmd.out),
    .mem_write(mem_write.out),
    .mem_read(mem_read.in),
    .clk_host,
    .host_in(host_in.in),
    .host_out(host_out.out),
    .iso(iso.fpga),
    .led_debug(led_debug)
);
`endif

isolator_model isolator(.iso(iso.isolator));

//  Interface tasks - fake memory.
localparam mem_depth = (1 << mem_log_depth);
logic [mem_width - 1 : 0] memory[mem_depth];
MemoryCommand cur_cmd;
logic [mem_width - 1 : 0] cur_write_val;
always @(posedge clk_mem) begin
    mem_cmd.read(cur_cmd);
    if (cur_cmd.read_not_write) begin
        for (int i = 0; i < cur_cmd.length; i++)
            mem_read.write(memory[(cur_cmd.address + i) % mem_depth]);
    end
    else begin
        for (int i = 0; i < cur_cmd.length; i++) begin
            mem_write.read(cur_write_val);
            memory[(cur_cmd.address + i) % mem_depth] = cur_write_val;
        end
    end
end

//  Interface tasks - supplying data/commands.
logic [15:0] send_cmd_word;
logic [31:0] send_cmd_checksum;
logic [15:0] send_cmd_data[1024];
logic [9:0] receive_counter;
logic [15:0] receive_data[1024];
always @(posedge tb_host_clk) begin
    if (host_out.ready && host_out.valid) begin
        receive_data[receive_counter] = host_out.data;
        receive_counter++;
    end
end

task send_cmd_simple(input logic [7:0] destination, input logic [7:0] command, input logic [23:0] data_length);
    //  No checksum, just raw data.
    host_in.write(destination);
    host_in.write(command);
    for (int i = 0; i < data_length; i++)
        host_in.write(send_cmd_data[i]);
endtask

task send_cmd(input logic [7:0] destination, input logic [7:0] command, input logic [23:0] data_length);
    host_in.write(destination);
    host_in.write(command);
    host_in.write(data_length[23:16]);
    host_in.write(data_length[15:0]);
    send_cmd_checksum = 0;
    //  Some commented code for the case of 8-bit data (using 16-bit for now)
    //  for (int i = 0; i < (data_length - 1) / 2 + 1; i++) begin
    for (int i = 0; i < data_length; i++) begin
        /*
        send_cmd_word[7:0] = send_cmd_data[i * 2];
        if (i * 2 + 1 < data_length)
            send_cmd_word[15:8] = send_cmd_data[i * 2 + 1];
        else
            send_cmd_word[15:8] = 0;
        */
        send_cmd_word = send_cmd_data[i];
        send_cmd_checksum = send_cmd_checksum + send_cmd_word;
        host_in.write(send_cmd_word);
    end
    host_in.write(send_cmd_checksum[31:16]);
    host_in.write(send_cmd_checksum[15:0]);
endtask

task transaction(input logic [7:0] destination, input logic [7:0] command, input logic [23:0] data_length, input logic [15:0] wait_cycles, output logic [9:0] receive_length);
    receive_counter = 0;
    send_cmd(destination, command, data_length);
    for (int i = 0; i < wait_cycles; i++) @(posedge clk_host);
    receive_length = receive_counter;
endtask

task transaction_simple(input logic [7:0] destination, input logic [7:0] command, input logic [23:0] data_length, input logic [15:0] wait_cycles, output logic [9:0] receive_length, input int target_count = -1);
    receive_counter = 0;
    send_cmd_simple(destination, command, data_length);
    for (int i = 0; i < wait_cycles; i++) 
        if ((target_count == -1) || (receive_counter < target_count)) 
            @(posedge clk_host);
    receive_length = receive_counter;
endtask

task spi_read(input logic [7:0] destination, input logic addr_size, input logic data_size, input logic [15:0] addr, output logic [15:0] data);
    logic [9:0] receive_length;
    send_cmd_data[0] = SPI_READ_REG;
    send_cmd_data[1] = {6'h00, addr_size, data_size};
    send_cmd_data[2] = addr[15:8];
    send_cmd_data[3] = addr[7:0];
    transaction(destination, CMD_FIFO_WRITE, 4, 1500, receive_length);
    
    data = (receive_data[7][7:0] << 8) + receive_data[8][7:0];
    $display("%t spi_read(addr %h): receive length = %d, data = %h", $time, addr, receive_length, data);
    
endtask

task spi_write(input logic [7:0] destination, input logic addr_size, input logic data_size, input logic [15:0] addr, input logic [15:0] data);
    send_cmd_data[0] = SPI_WRITE_REG;
    send_cmd_data[1] = {6'h00, addr_size, data_size};
    send_cmd_data[2] = addr[15:8];
    send_cmd_data[3] = addr[7:0];
    send_cmd_data[4] = data[15:8];
    send_cmd_data[5] = data[7:0];
    send_cmd(destination, CMD_FIFO_WRITE, 6);
    
    $display("%t spi_write(addr %h, data %h)", $time, addr, data);
endtask


//  Interface initialization
initial begin
    mem_cmd.init_read;
    mem_write.init_read;
    mem_read.init_write;
    host_in.init_write;
    host_out.init_read;
    //  Temporary until we figure out what to do 
    host_out.ready = 1;
    receive_counter = 0;
end

/*  Some quick unit tests   */

int num_test_errors;

task fail_test(input string error_str);
    num_test_errors++;
    $error("%t: %s", $time, error_str);
endtask

task test_spi(input int slot);
    logic [15:0] spi_receive_data;

    //  8 bit data/address
    isolator.set_spi_mode(slot, 8, 8);
    spi_write(slot, 0, 0, 8'h47, 8'hA3);
    spi_read(slot, 0, 0, 8'hC7, spi_receive_data);
    assert(spi_receive_data[7:0] == 8'hA3) else fail_test($sformatf("8-bit SPI readback (8-bit addr) on slot %0d failed.", slot));

    //  16 bit address, 8 bit data
    isolator.set_spi_mode(slot, 16, 8);
    spi_write(slot, 1, 0, 16'h0829, 8'hF6);
    spi_read(slot, 1, 0, 16'h8829, spi_receive_data);
    assert(spi_receive_data[7:0] == 8'hF6) else fail_test($sformatf("8-bit SPI readback (16-bit addr) on slot %0d failed.", slot));

    //  8 bit address, 16 bit data
    isolator.set_spi_mode(slot, 8, 16);
    spi_write(slot, 0, 1, 8'h1C, 16'h5DA9);
    spi_read(slot, 0, 1, 8'h9C, spi_receive_data);
    assert(spi_receive_data[15:0] == 16'h5DA9) else fail_test($sformatf("16-bit SPI readback (8-bit addr) on slot %0d failed.", slot));

    //  16 bit address, 16 bit data
    isolator.set_spi_mode(slot, 16, 16);
    spi_write(slot, 1, 1, 16'h30AA, 16'h3D1A);
    spi_read(slot, 1, 1, 16'hB0AA, spi_receive_data);
    assert(spi_receive_data[15:0] == 16'h3D1A) else fail_test($sformatf("16-bit SPI readback (16-bit addr) on slot %0d failed.", slot));

endtask

task test_clock_select;
    send_cmd_data[0] = 0;
    send_cmd_simple(8'hFF, SELECT_CLOCK, 1);
    #1000 assert(iso.clksel == 1'b0) else fail_test("Clock select didn't work.");
    
    send_cmd_data[0] = 1;
    send_cmd_simple(8'hFF, SELECT_CLOCK, 1);
    #1000 assert(iso.clksel == 1'b1) else fail_test("Clock select didn't work.");
endtask

task test_hwcon(input int slot);
    logic [7:0] hwcon_val;
    
    for (int i = 0; i < 3; i++) begin
        hwcon_val = $random();
    
        send_cmd_data[0] = SLOT_SET_ACON;
        send_cmd_data[1] = hwcon_val;
        send_cmd(slot, CMD_FIFO_WRITE, 2);
        
        #30000 assert (isolator.get_hwcon_parallel(slot) === hwcon_val) else fail_test($sformatf("Setting HWCON for slot %0d didn't work", slot));
    end
endtask

task send_slot_cmd_simple(input int slot, input logic [7:0] cmd_id);
    send_cmd_data[0] = cmd_id;
    send_cmd_data[1] = 0;
    send_cmd(slot, CMD_FIFO_WRITE, 2);
endtask 

task test_dac(input int slot, input int num_samples);
    int skip_samples;
    int sample_latency_detected;
    int num_errors;
    logic [31:0] samples_received[];
    logic [31:0] samples_sent[];
    
    samples_received = new [num_samples];   //  not really required since using pass by value - see isolator_model.sv
    samples_sent = new [num_samples];
    
    //  Supply some samples to the desired slot and use the I2S receiver to compare them.
    //  We will capture some extra samples first due to latency.  (This is a hack, but
    //  other solutions for bracketing captures samples are more complex and will be 
    //  implemented later.)
    skip_samples = 10;
    for (int i = 0; i < num_samples; i++) begin
        samples_sent[i] = $random() & ((1 << 24) - 1);
        send_cmd_data[2 * i] = samples_sent[i] >> 16;
        send_cmd_data[2 * i + 1] = samples_sent[i] & ((1 << 16) - 1);
    end
    fork
        send_cmd(slot, AUD_FIFO_WRITE, num_samples * 2);
        isolator.capture_samples(slot, num_samples + skip_samples, samples_received);
    join

    sample_latency_detected = -1;
    for (int i = 0; i < skip_samples; i++) begin
        if ((sample_latency_detected == -1) && (samples_received[i] != 0))
            sample_latency_detected = i;
    end
    num_errors = 0;
    for (int i = 0; i < num_samples; i++) begin
        assert(samples_received[i + sample_latency_detected] === samples_sent[i]) 
        else begin
            num_errors++;
            fail_test($sformatf("DAC output capture sample %0d val %h didn't match supplied value %h", i, samples_received[i + sample_latency_detected], samples_sent[i]));
        end
    end
    $display("%t: test_dac (slot %0d): detected latency of %0d samples, %0d/%0d failures", $time, slot, sample_latency_detected, num_errors, num_samples);
    
    samples_received.delete;
    samples_sent.delete;
endtask

task test_adc(input int slot, input int num_samples);
    //  Send some samples from an I2S source and make sure we can read them.
    int skip_samples;
    int sample_latency_detected;
    int num_errors;
    logic [31:0] samples_received[];
    logic [31:0] samples_sent[];
    logic [9:0] receive_length;
    
    skip_samples = 10;
    samples_received = new [num_samples + skip_samples];
    samples_sent = new [num_samples];

    for (int i = 0; i < num_samples; i++) begin
        samples_sent[i] = $random() & ((1 << 24) - 1);
    end
    send_slot_cmd_simple(slot, SLOT_START_RECORDING);
    fork
        isolator.source_samples(slot, num_samples, samples_sent);
        begin
            send_cmd_data[0] = (num_samples + skip_samples) >> 16;
            send_cmd_data[1] = (num_samples + skip_samples) & ((1 << 16) - 1);
            transaction_simple(slot, AUD_FIFO_READ, 2, 10000, receive_length, (num_samples + skip_samples) * 2 + 6);
            send_slot_cmd_simple(slot, SLOT_STOP_RECORDING);
        end
    join
    sample_latency_detected = -1;
    for (int i = 0; i < (receive_length - 6) / 2; i++) begin
        samples_received[i] = (receive_data[i * 2 + 5] << 16) + receive_data[i * 2 + 4];
        if ((sample_latency_detected == -1) && (samples_received[i] != 0))
            sample_latency_detected = i;
    end

    num_errors = 0;
    for (int i = 0; i < num_samples; i++) begin
        assert(samples_received[i + sample_latency_detected] === samples_sent[i]) 
        else begin
            num_errors++;
            fail_test($sformatf("ADC output capture sample %0d val %h didn't match supplied value %h", i, samples_received[i + sample_latency_detected], samples_sent[i]));
        end
    end
    $display("%t: test_adc (slot %0d): detected latency of %0d samples, %0d/%0d failures", $time, slot, sample_latency_detected, num_errors, num_samples);
    
    samples_received.delete;
    samples_sent.delete;
endtask

task test_loopback(input int slot_dac, input int slot_adc);
    //  Configure the isolator model to connect I2S lines from one slot to another,
    //  and make sure we read back the same samples from the ADC slot that we wrote
    //  to the DAC slot.
    
    //  Put a blocker on everyone
    send_cmd_data[0] = 4'b0000;
    send_cmd_simple(8'hFF, UPDATE_BLOCKING, 1);
    
    //  Enable recording on slot 1 - ADC
    send_cmd_data[0] = SLOT_START_RECORDING;
    send_cmd_data[1] = 0;
    send_cmd(slot_adc, CMD_FIFO_WRITE, 2);
    
    //  Long audio loop: test that we can stall
    for (int i = 0; i < 256; i++) begin
        send_cmd_data[2 * i] = i / 256;
        send_cmd_data[2 * i + 1] = i % 256;
    end
    send_cmd(slot_dac, AUD_FIFO_WRITE, 512);

    //  Now unblock ADC and DAC simultaneously
    send_cmd_data[0] = 4'b0011;
    send_cmd_simple(8'hFF, UPDATE_BLOCKING, 1);

    for (int i = 0; i < 4; i++) begin
        #750000     //  1/1/2017: Test audio FIFO read
        send_cmd_data[0] = 0;
        send_cmd_data[1] = 64;
        send_cmd_simple(slot_adc, AUD_FIFO_READ, 2);
    end

    send_cmd_data[0] = SLOT_STOP_RECORDING;
    send_cmd_data[1] = 0;
    send_cmd(slot_adc, CMD_FIFO_WRITE, 2);

    //  Flush idea to try: wait a fit for all samples to come in, read status, then read remaining samples
    #50000 send_cmd_simple(8'hFF, FIFO_READ_STATUS, 0);
endtask

task test_fifo_status;
    //  Test reporting of FIFO status
    send_cmd_simple(8'hFF, FIFO_READ_STATUS, 0);
    
    #5000;
    assert(receive_counter == 38) else fail_test("FIFO status command returned %0d bytes, expected 38");

    //  TODO - come back once we know DAC, ADC, etc are working.
    fail_test("FIFO status test not yet implemented");

endtask

task test_slot_reset;
    int time_counter;
    logic has_reset;

    //  a) Pulse reset
    has_reset = 0;
    send_cmd_simple(8'hFF, RESET_SLOTS, 0);
    fork
        begin
            @(negedge iso.reset_n);
            time_counter = $time;
            @(posedge iso.reset_n);
            $display("%t: Reset pulse of %0d ns detected", $time, $time - time_counter);
            has_reset = 1;
        end
        begin
            #10000 if (!has_reset) fail_test("Reset pulse didn't happen");
        end
    join

    //  b) Enter reset and don't leave until we tell it to
    //     (Note: the da_platform logic enforces a minimum reset pulse width
    //     of 200 cycles, so we have to wait for that.)
    send_cmd_simple(8'hFF, ENTER_RESET, 0);
    #1000 assert(!iso.reset_n) else fail_test("Slots didn't enter reset when we asked");
    send_cmd_simple(8'hFF, LEAVE_RESET, 0);
    #10000 assert(iso.reset_n) else fail_test("Slots didn't leave reset when we asked");
    
endtask

//  Fun stuff

logic [15:0] test_receive_length;
initial begin
    @(negedge reset);
    
    @(posedge clk_host);
    
    //  Wait 10 us for config information (dir/chan) to be serialized by isolator and received
    //  and for SS chip selects to be all deasserted (clock startup; ser/des) 
    #10000 ;

    //  Run sequence of unit tests
    
    test_clock_select;
    test_slot_reset;
    for (int i = 0; i < num_slots; i++)
        test_hwcon(i);
    for (int i = 0; i < num_slots; i++)
        test_spi(i);
    for (int i = 0; i < num_slots; i++) begin
        isolator.set_slot_mode(i, DAC2);
        test_dac(i, 16);
    end
    for (int i = 0; i < num_slots; i++) begin
        isolator.set_slot_mode(i, ADC2);
        test_adc(i, 16);
    end

    $display("Counted %0d test failures", num_test_errors);
    $finish;

    test_loopback(0, 1);
    test_fifo_status;
end

//  Clocks
`ifndef verilator
always #2.5 clk_mem = !clk_mem;
always #10.4166 clk_host = !clk_host;
`else
logic clk_global;
always_comb begin
    clk_mem = clk_global;
    clk_host = clk_global;
end
`endif

//  Setup
initial begin
    reset = 1;
    clk_mem = 0;
    clk_host = 0;
    
    #1000 reset = 0;
end
/*
`ifndef verilator
initial begin
    $dumpfile("da_platform_tb.vcd");
    $dumpvars(0, da_platform_tb);
end
`endif
*/
//  Time limit
logic [31:0] cycle_counter;
initial cycle_counter = 0;
always @(posedge clk_host) begin
    cycle_counter <= cycle_counter + 1;
    if (cycle_counter > 1000000) $finish;
end

endmodule

