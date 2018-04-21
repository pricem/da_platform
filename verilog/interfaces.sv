/*
    Open-source digital audio platform
    Copyright (C) 2009--2018 Michael Price

    This is a collection of SV interfaces used throughout the design.

    Warning: Use and distribution of this code is restricted.
    This HDL file is distributed under the terms of the Solderpad Hardware 
    License, Version 0.51.  Other files in this project may be subject to
    different licenses.  Please see the LICENSE file in the top level project
    directory for more information.
*/

`timescale 1ns / 1ps

interface FIFOInterface #(num_bits = 8) (input logic clk);
    logic ready;
    logic valid;
    logic [num_bits - 1 : 0] data;

    modport out(input clk, input ready, output valid, output data);
    modport in(input clk, output ready, input valid, input data);

    //  Testbench tasks - not synthesizable, merely a convenience.
    task init_write;
        valid = 0;
        data = 0;
    endtask
    
    task init_read;
        ready = 0;
    endtask

    task write(input logic [num_bits - 1 : 0] val);
        @(posedge clk);
        valid <= 1;
        data <= val;
        @(posedge clk);
        while (!ready) @(posedge clk);
        valid <= 0;
    endtask
    
    task read(output logic [num_bits - 1 : 0] val);
        ready <= 1;
        @(posedge clk);
        while (!valid) @(posedge clk);
        ready <= 0;
        val = data;
    endtask

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

interface AXI4_Std #(id_width = 4, addr_width = 28, data_width = 32) (input logic aclk);
    logic [id_width - 1 : 0] awid;
    logic [addr_width - 1 : 0] awaddr;
    logic [7:0] awlen;
    logic [2:0] awsize;
    logic [1:0] awburst;
    logic [0:0] awlock;
    logic [3:0] awcache;
    logic [2:0] awprot;
    logic [3:0] awqos;
    logic awvalid;
    logic awready;
    logic [data_width - 1 : 0] wdata;
    logic [3:0] wstrb;
    logic wlast;
    logic wvalid;
    logic wready;
    logic bready;
    logic [id_width - 1 : 0] bid;
    logic [1:0] bresp;
    logic bvalid;
    logic [id_width - 1 : 0] arid;
    logic [addr_width - 1 : 0] araddr;
    logic [7:0] arlen;
    logic [2:0] arsize;
    logic [1:0] arburst;
    logic [0:0] arlock;
    logic [3:0] arcache;
    logic [2:0] arprot;
    logic [3:0] arqos;
    logic arvalid;
    logic arready;
    logic rready;
    logic [id_width - 1 : 0] rid;
    logic [data_width - 1 : 0] rdata;
    logic [1:0] rresp;
    logic rlast;
    logic rvalid;

    modport master(input aclk, output awid, awaddr, awlen, awsize, awburst, awlock, awcache, awprot, awqos, awvalid, wdata, wstrb, wlast, wvalid, bready, arid, araddr, arlen, arsize, arburst, arlock, arcache, arprot, arqos, arvalid, rready, input awready, wready, bid, bresp, bvalid, arready, rid, rdata, rresp, rlast, rvalid);
    modport slave(input aclk, input awid, awaddr, awlen, awsize, awburst, awlock, awcache, awprot, awqos, awvalid, wdata, wstrb, wlast, wvalid, bready, arid, araddr, arlen, arsize, arburst, arlock, arcache, arprot, arqos, arvalid, rready, output awready, wready, bid, bresp, bvalid, arready, rid, rdata, rresp, rlast, rvalid);

endinterface


