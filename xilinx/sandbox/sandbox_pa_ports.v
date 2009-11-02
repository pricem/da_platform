`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Create Date:    Sun Nov 01 21:07:17 2009
// Design Name: 
// Module Name:    netlist_1_EMPTY
//////////////////////////////////////////////////////////////////////////////////
module netlist_1_EMPTY(usb_addr, usb_data, mem_addr, mem_data, pmod_a, pmod_b, pmod_c, pmod_d, fx2, led_upper, switches, led_7seg_an, led_7seg_cat, buttons, vga_red, vga_green, vga_blue, usb_ifclk, usb_flaga, usb_flagb, usb_flagc, usb_sloe, usb_slrd, usb_slwr, usb_slcs, usb_pktend, mem_ub, mem_lb, mem_oe, mem_we, mem_ce, mem_cre, mem_adv, mem_clk, mem_wait, flash_sts, flash_rp, flash_ce, ps2_clk, ps2_data, vga_hsync, vga_vsync, serial_out, serial_in, clk0, clk1);
  output [1:0] usb_addr;
  inout  [7:0] usb_data;
  output [23:1] mem_addr;
  inout  [15:0] mem_data;
  inout  [7:0] pmod_a;
  inout  [7:0] pmod_b;
  inout  [7:0] pmod_c;
  inout  [7:0] pmod_d;
  inout  [39:0] fx2;
  output [3:0] led_upper;
  input [7:0] switches;
  output [3:0] led_7seg_an;
  output [7:0] led_7seg_cat;
  input [3:0] buttons;
  output [2:0] vga_red;
  output [2:0] vga_green;
  output [1:0] vga_blue;
  inout  usb_ifclk;
  input usb_flaga;
  input usb_flagb;
  input usb_flagc;
  output usb_sloe;
  output usb_slrd;
  output usb_slwr;
  output usb_slcs;
  inout  usb_pktend;
  output mem_ub;
  output mem_lb;
  output mem_oe;
  output mem_we;
  output mem_ce;
  output mem_cre;
  output mem_adv;
  output mem_clk;
  input mem_wait;
  input flash_sts;
  output flash_rp;
  output flash_ce;
  output ps2_clk;
  inout  ps2_data;
  output vga_hsync;
  output vga_vsync;
  output serial_out;
  input serial_in;
  input clk0;
  input clk1;


endmodule
