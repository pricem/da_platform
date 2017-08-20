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

/*
interface SlotData;
    wire bck;
    wire lrck;
    wire [3:0] data;
endinterface
*/

interface IsolatorInterface;
    //  Ideally, we would use:
    //  SlotData modules[4] ();
    //  But instead, let's break it down like this:
    //      slotdata[23:18] -> module 3
    //      slotdata[17:12] -> module 2
    //      slotdata[11:6]  -> module 1
    //      slotdata[5:0]   -> module 0
    //  And:
    //      slotdata[5:2]   -> module 0 data [3:0]
    //      slotdata[1]     -> module 0 lrck
    //      slotdata[0]     -> module 0 bck
    wire [23:0] slotdata;
    logic sclk;
    logic cs_n; 
    logic miso; 
    logic mosi; 
    logic dirchan;
    logic hwcon;
    logic hwflag;
    logic mclk; 
    logic reset_n;
    logic srclk;
    logic srclk2;
    logic clksel;
    
    modport fpga(inout slotdata, output sclk, cs_n, mosi, hwcon, reset_n, srclk, srclk2, clksel, input miso, dirchan, hwflag, mclk);
    modport isolator(inout slotdata, input sclk, cs_n, mosi, hwcon, reset_n, srclk, srclk2, clksel, output miso, dirchan, hwflag, mclk);
endinterface

