
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
initial begin
    @(negedge cr_host.reset);
    
    @(posedge cr_host.clk);
    
    //  Wait 1.6 us for config information (dir/chan) to be serialized by isolator and received
    #1600 ;
    
    //  Try some SPI setup stuff
    spi_write(8'h01, 8'h29, 8'hA3);
    spi_read(8'h01, 8'h19, spi_receive_data);
    spi_read(8'h01, 8'h29, spi_receive_data);
    
    
    for (int i = 0; i < 10; i++) send_cmd_data[i] = (2 * i) + ((2 * i + 1) << 8);
    send_cmd(8'h01, AUD_FIFO_WRITE, 10);
end

//  Clocks
`ifndef verilator
always #2.5 cr_mem.clk = !cr_mem.clk;
always #10.41667 cr_host.clk = !cr_host.clk;
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

`ifndef verilator
initial begin
    $dumpfile("da_platform_tb.vcd");
    $dumpvars(0, da_platform_tb);
end
`endif

//  Time limit
logic [31:0] cycle_counter;
initial cycle_counter = 0;
always @(posedge cr_host.clk) begin
    cycle_counter <= cycle_counter + 1;
    if (cycle_counter > 10000) $finish;
end

endmodule

