
/*
    Testbench for DA platform being ported to new interfaces
    Michael Price, 8/3/2016
*/

`timescale 1ns / 1ps

module da_platform_tb #(
    mem_width = 32,
    host_width = 16,
    mem_log_depth = 20
) ();


`include "commands.v"
`include "structures.sv"

ClockReset cr_mem ();
FIFOInterface #(.num_bits(65 /* $sizeof(MemoryCommand) */)) mem_cmd (cr_mem.clk);
FIFOInterface #(.num_bits(mem_width)) mem_write (cr_mem.clk);
FIFOInterface #(.num_bits(mem_width)) mem_read (cr_mem.clk);
ClockReset cr_host ();
FIFOInterface #(.num_bits(host_width)) host_in (cr_host.clk);
FIFOInterface #(.num_bits(host_width)) host_out (cr_host.clk);
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

da_platform_wrapper dut(
    .fxclk_in(fx2_ifclk),
    .ifclk_in(fx2_ifclk),
    .reset(cr_host.reset),
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
da_platform #(
    .mem_width(mem_width),
    .host_width(host_width)
) dut(
    .cr_mem(cr_mem.client),
    .mem_cmd(mem_cmd.out),
    .mem_write(mem_write.out),
    .mem_read(mem_read.in),
    .cr_host(cr_host.client),
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
always @(posedge cr_mem.clk) begin
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
always @(posedge cr_host.clk) begin
    if (host_out.ready && host_out.enable) begin
        receive_data[receive_counter] = host_out.data;
        receive_counter++;
    end
end

task send_cmd_simple(input logic [7:0] destination, input logic [7:0] command, input logic [23:0] data_length);
    host_in.write(destination);
    host_in.write(command);
    for (int i = 0; i < data_length; i++)
        host_in.write(send_cmd_data[i]);
    if (data_length == 0)
        host_in.write(0);
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
    for (int i = 0; i < wait_cycles; i++) @(posedge cr_host.clk);
    receive_length = receive_counter;
endtask

//  This task is based around SPI format for DSD1792 - 8 bit addr and data
task spi_read(input logic [7:0] destination, input logic [7:0] addr, output logic [7:0] data);
/*
    checksum = 0x61 + addr + 0x80
	cmd = numpy.array([slot, 0x20, 0x00, 0x00, 0x02, 0x61, addr + 0x80, checksum / 256, checksum % 256], dtype=numpy.uint8
*/	
    logic [9:0] receive_length;
    send_cmd_data[0] = SPI_READ_REG;
    send_cmd_data[1] = addr + 8'h80;
    transaction(destination, CMD_FIFO_WRITE, 2, 1000, receive_length);
    
    $display("%t spi_read(addr %h): receive length = %d, data[4] = %h", $time, addr, receive_length, receive_data[4]);
endtask

task spi_write(input logic [7:0] destination, input logic [7:0] addr, input logic [7:0] data);
/*
    checksum = 0x61 + addr + 0x80
	cmd = numpy.array([slot, 0x20, 0x00, 0x00, 0x02, 0x61, addr + 0x80, checksum / 256, checksum % 256], dtype=numpy.uint8
*/	
    send_cmd_data[0] = SPI_WRITE_REG;
    send_cmd_data[1] = addr;
    send_cmd_data[2] = data;
    send_cmd(destination, CMD_FIFO_WRITE, 3);
    
    $display("%t spi_write(addr %h)", $time, addr);
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

//  Fun stuff
logic [7:0] spi_receive_data;
logic [15:0] test_receive_length;
initial begin
    @(negedge cr_host.reset);
    
    @(posedge cr_host.clk);
    
    //  Wait 10 us for config information (dir/chan) to be serialized by isolator and received
    //  and for SS chip selects to be all deasserted (clock startup; ser/des) 
    #10000 ;
    
    /*
    //  Try some SPI setup stuff
    spi_write(8'h01, 8'h29, 8'hA3);
    spi_read(8'h01, 8'h19, spi_receive_data);
    spi_read(8'h01, 8'h29, spi_receive_data);
    
    //  Set ACON
    send_cmd_data[0] = SLOT_SET_ACON;
    send_cmd_data[1] = 8'h64;
    send_cmd(8'h00, CMD_FIFO_WRITE, 2);
    #1000 ;
    send_cmd_data[0] = SLOT_SET_ACON;
    send_cmd_data[1] = 8'h51;
    send_cmd(8'h00, CMD_FIFO_WRITE, 2);
    
    //  Reset slots
    send_cmd(8'hFF, RESET_SLOTS, 0);
    */
    
    //  Put a blocker on everyone
    send_cmd_data[0] = 4'b0000;
    send_cmd_simple(8'hFF, UPDATE_BLOCKING, 1);
    
    //  Enable recording
    send_cmd_data[0] = SLOT_START_RECORDING;
    send_cmd_data[1] = 0;
    send_cmd(8'h00, CMD_FIFO_WRITE, 2);
    /*
    //  Short audio test
    for (int i = 0; i < 10; i++) send_cmd_data[i] = (2 * i) + ((2 * i + 1) << 8);
    send_cmd(8'h01, AUD_FIFO_WRITE, 10);
    
    //  Disable recording after 100 us / approx 4 samples (wait for timeout, we should get the data back)
    #100000 ;
    send_cmd_data[0] = SLOT_STOP_RECORDING;
    send_cmd_data[1] = 0;
    transaction(8'h00, CMD_FIFO_WRITE, 2, 2000, test_receive_length);    //  TBD: How many words to receive?  Depends on timing.
    
    //  Test reporting of FIFO status
    send_cmd_simple(8'h00, FIFO_READ_STATUS);
    */
    //  Long audio loop: test that we can stall
    for (int i = 0; i < 128; i++) begin
        send_cmd_data[2 * i] = i / 256;
        send_cmd_data[2 * i + 1] = i % 256;
    end
    send_cmd(8'h01, AUD_FIFO_WRITE, 32);

    //  Now unblock ADC and DAC simultaneously
    send_cmd_data[0] = 4'b0011;
    send_cmd_simple(8'hFF, UPDATE_BLOCKING, 1);

    #250000 send_cmd_data[0] = SLOT_STOP_RECORDING;
    send_cmd_data[1] = 0;
    send_cmd(8'h00, CMD_FIFO_WRITE, 2);

    //  1/1/2017: Test audio FIFO read
    send_cmd_data[0] = 0;
    send_cmd_data[1] = 16;
    send_cmd_simple(8'h00, AUD_FIFO_READ, 2);

    //  Flush idea to try: wait a fit for all samples to come in, read status, then read remaining samples
    #50000 send_cmd_simple(8'hFF, FIFO_READ_STATUS, 0);
    
    

    //  Temporary
    //  #1000 $finish;
end

//  Clocks
`ifndef verilator
always #2.5 cr_mem.clk = !cr_mem.clk;
always #10.4166 cr_host.clk = !cr_host.clk;
`else
logic clk_global;
always_comb begin
    cr_mem.clk = clk_global;
    cr_host.clk = clk_global;
end
`endif

//  Setup
initial begin
    cr_mem.reset = 1;
    cr_mem.clk = 0;
    cr_host.reset = 1;
    cr_host.clk = 0;
    
    #100 cr_mem.reset = 0;
    cr_host.reset = 0;
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
always @(posedge cr_host.clk) begin
    cycle_counter <= cycle_counter + 1;
    if (cycle_counter > 100000) $finish;
end

endmodule

