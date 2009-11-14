`timescale 1ns / 1ps

//	Nexys2 top level module
//	Michael Price

module nexys2_toplevel(
    usb_ifclk, usb_flaga, usb_flagb, usb_flagc, usb_int0, usb_sloe, usb_slrd, usb_slwr, usb_slcs, usb_addr, usb_pktend, usb_data,
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
	inout usb_int0;
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
//	sandbox1 sandbox(led, switches);

// Extra signals for sample-by-sample DAC
wire [7:0] usb_fifo0_out;
wire usb_fifo0_active;
reg [7:0] data [3:0];           //  Data for current DAC samples
reg [1:0] data_index;           //  Counter for current byte (0 to 3)
reg [11:0] dac_data1;           //  DAC left channel
reg [11:0] dac_data2;           //  DAC right channel
reg dac_start;                  //  DAC control lines
wire dac_done;

//  USB module from Joseph Rothweiler
usb_top usb (
    .CLK_50M(clk0),
    .SW(switches),
    .BTN(buttons),
    .U_FDATA(usb_data),
    .U_FADDR(usb_addr),
    .U_SLRD(usb_slrd),
    .U_SLWR(usb_slwr),
    .U_SLOE(usb_sloe),
    .U_SLCS(usb_slcs),
    .U_INT0(usb_int0),
    .U_PKTEND(usb_pktend),
    .U_FLAGA(usb_flaga),
    .U_FLAGB(usb_flagb),
    .U_FLAGC(usb_flagc),
    .U_IFCLK(usb_ifclk),
    .LED(led),
    .DATA(usb_fifo0_out),
    .ACTIVE(usb_fifo0_active)
  );
  

// Instantiate DAC
DA2RefComp dac_interface(
    .CLK(clk0),
    .RST(reset),
    .D1(pmod_a[1]),
    .D2(pmod_a[2]),
    .CLK_OUT(pmod_a[3]),
    .nSYNC(pmod_a[0]),
    .DATA1(dac_data1),
    .DATA2(dac_data2),
    .START(dac_start),
    .DONE(dac_done)
    );

always @(posedge clk0) begin

    if (reset)
        //  Handle resets
        data_index <= 2'b0;
    else
        //  Take data when available
        if (usb_fifo0_active) begin
            data[data_index] <= usb_fifo0_out;
            data_index <= data_index + 1;
        end
        
        //  Write to DAC after 4 bytes were read
        if ((data_index == 0) && (dac_done == 1)) begin
            dac_data1 <= {data[1], data[0][3:0]};
            dac_data2 <= {data[3], data[2][3:0]};
            dac_start <= 1;           
            end
        else
            dac_start <= 0;
end


//  Assign unused ports.  (Replace with appropriate interfaces if needed.)
/* Not commented since we have a usbtop module
assign usb_sloe = 1;
assign usb_slrd = 1;
assign usb_slwr = 1;
assign usb_slcs = 1;
assign usb_addr[1:0] = 2'b00;
*/
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