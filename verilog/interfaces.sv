`timescale 1ns / 1ps

interface FIFOInterface #(num_bits = 8) (input logic clk);
    logic ready;
    logic enable;
    logic [num_bits - 1 : 0] data;

    modport out(input ready, output enable, output data);
    modport in(output ready, input enable, input data);

    //  Testbench tasks - not synthesizable, merely a convenience.
    task init_write;
        enable = 0;
        data = 0;
    endtask
    
    task init_read;
        ready = 0;
    endtask

    task write(input logic [num_bits - 1 : 0] val);
        @(posedge clk);
        enable <= 1;
        data <= val;
        @(posedge clk);
        while (!ready) @(posedge clk);
        enable <= 0;
    endtask
    
    task read(output logic [num_bits - 1 : 0] val);
        ready <= 1;
        @(posedge clk);
        while (!enable) @(posedge clk);
        ready <= 0;
        val = data;
    endtask

endinterface

interface ClockReset;
    logic clk;
    logic reset;
    
    modport client(input clk, input reset);
endinterface

interface IsolatorInterface;
    wire [23:0] slotdata;
    logic mclk;
    logic amcs; 
    logic amdi; 
    logic amdo; 
    logic dmcs; 
    logic dmdi; 
    logic dmdo; 
    logic dirchan;
    logic [1:0] acon;
    logic aovf;
    logic clk0; 
    logic reset_out;
    logic srclk;
    logic clksel;
    logic clk1;
    
    modport fpga(inout slotdata, output mclk, output amcs, output amdi, input amdo, output dmcs, output dmdi, input dmdo, input dirchan, output acon, input aovf, input clk0, output reset_out, output srclk, output clksel, input clk1);
    modport isolator(inout slotdata, input mclk, input amcs, input amdi, output amdo, input dmcs, input dmdi, output dmdo, output dirchan, input acon, output aovf, output clk0, input reset_out, input srclk, input clksel, output clk1);
endinterface

