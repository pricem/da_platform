`timescale 1ns / 1ps

//	Nexys2 top level module
//	Michael Price

module nexys2_toplevel(
    usb_ifclk, usb_flaga, usb_flagb, usb_flagc, usb_sloe, usb_slrd, usb_slwr, usb_slcs, usb_addr, usb_pktend, usb_data,
    mem_addr, mem_data,
    mem_ub, mem_lb, mem_oe, mem_we, mem_ce, mem_cre, mem_adv, mem_clk, mem_wait, 
    flash_sts, flash_rp, flash_ce,
    pmod_a, pmod_b, pmod_c, pmod_d, fx2,
    led_upper, switches, led_7seg_an, led_7seg_cat, buttons,
    ps2_clk, ps2_data,
    vga_red, vga_green, vga_blue, vga_hsync, vga_vsync,
    serial_out, serial_in,
    clk0, clk1
    );

    //	USB control
    inout usb_ifclk;
    input usb_flaga;
    input usb_flagb;
    input usb_flagc;
    output usb_sloe;
    output usb_slrd;
    output usb_slwr;
    output usb_slcs;
    output [1:0] usb_addr;
    inout usb_pktend;
    //	USB data
    inout [7:0] usb_data;
    //	Memory (shared between DRAM and flash)
    output [23:1] mem_addr;
    inout [15:0] mem_data;
    //	Memory (DRAM specific)
    output mem_ub;
    output mem_lb;
    output mem_oe;
    output mem_we;
    output mem_ce;
    output mem_cre;
    output mem_adv;
    output mem_clk;
    input mem_wait;
    //	Memory (Flash specific)
    input flash_sts;
    output flash_rp;
    output flash_ce;
    //	Expansion connectors
    inout [7:0] pmod_a;
    inout [7:0] pmod_b;
    inout [7:0] pmod_c;
    inout [7:0] pmod_d;
    inout [39:0] fx2;
    //	Onboard gizmos
    output [3:0] led_upper;
    input [7:0] switches;
    output [3:0] led_7seg_an;
    output [7:0] led_7seg_cat;
    input [3:0] buttons;
    //  PS/2 port
    output ps2_clk;
    inout ps2_data;
    //  VGA port
    output [2:0] vga_red;
    output [2:0] vga_green;
    output [1:0] vga_blue;
    output vga_hsync;
    output vga_vsync;
    //  Serial port
    output serial_out;
    input serial_in;
    //	Clocks
    input clk0;
    input clk1;

//  The lower 3 LEDs are shared with the upper 4 bits of Pmod D.
wire [7:0] led;
assign pmod_d[7] = led[0];
assign pmod_d[6] = led[1];
assign pmod_d[5] = led[2];
assign pmod_d[4] = led[3];
assign led_upper[3:0] = led[7:4];

//  Assign reset to button 0.
wire reset;
assign reset = buttons[0];

//  Logic module instances
sandbox1 sandbox(led, switches);

//  Assign unused ports.  (Replace with appropriate interfaces if needed.)
assign usb_sloe = 1;
assign usb_slrd = 1;
assign usb_slwr = 1;
assign usb_slcs = 1;
assign usb_addr[1:0] = 2'b00;

assign vga_red[2:0] = 3'b000;
assign vga_green[2:0] = 3'b000;
assign vga_blue[1:0] = 2'b00;
assign vga_hsync = 0;
assign vga_vsync = 0;

assign serial_out = 0;

assign ps2_clk = 0;

assign led_7seg_an[3:0] = 4'b1111;
assign led_7seg_cat[7:0] = 8'b11111111;

assign mem_addr[23:1] = 23'h000000;

assign flash_rp = 1;
assign flash_ce = 1;

assign mem_ub = 1;
assign mem_lb = 1;
assign mem_oe = 1;
assign mem_we = 1;
assign mem_ce = 1;
assign mem_cre = 0;
assign mem_adv = 1;
assign mem_clk = 0;

endmodule