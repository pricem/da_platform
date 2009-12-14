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

//  Handle in/out nature of USB data
wire usb_data_out = usb_data;
wire usb_data_in;
assign usb_data = usb_slwr ? 8'hZZ : usb_data_in;

//  USB module 
usb_toplevel dut(
        .usb_ifclk(usb_ifclk),
        .usb_slwr(usb_slwr),
        .usb_slrd(usb_slrd),
        .usb_sloe(usb_sloe),
        .usb_addr(usb_addr),
        .usb_data_in(usb_data_in),
        .usb_data_out(usb_data_out),
        .usb_ep2_empty(usb_flaga),
        .usb_ep4_empty(usb_flagb),
        .usb_ep6_full(usb_flagc),
        .usb_ep8_full(usb_flagb),
        .mem_addr(mem_addr),
        .mem_data(mem_data),
        .mem_oe(mem_oe),
        .mem_we(mem_we),
        .mem_clk(mem_clk),
        .mem_addr_valid(mem_adv),
        .slot0_data({fx2[11], fx2[9], fx2[7], fx2[5], fx2[3], fx2[1]}),
        .slot1_data({fx2[8], fx2[10], fx2[4], fx2[6], fx2[0], fx2[2]}),
        .slot2_data({fx2[23], fx2[21], fx2[19], fx2[17], fx2[15], fx2[13]}),
        .slot3_data({fx2[20], fx2[22], fx2[16], fx2[18], fx2[12], fx2[14]}),
        .spi_adc_cs(fx2[24]),
        .spi_adc_mclk(fx2[26]),
        .spi_adc_mdi(fx2[34]),
        .spi_adc_mdo(fx2[30]),
        .spi_dac_cs(fx2[32]),
        .spi_dac_mclk(fx2[26]),
        .spi_dac_mdi(fx2[34]),
        .spi_dac_mdo(fx2[36]),
        .custom_adc_hwcon({fx2[29], fx2[31]}),
        .custom_adc_ovf(fx2[27]),
        .custom_clk0(fx2[25]),
        .custom_srclk(fx2[37]),
        .custom_clksel(fx2[35]),
        .custom_clk1(fx2[33]),
        .clk(clk),
        .reset(reset)
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

assign flash_rp = 1;
assign flash_ce = 1;
assign mem_ub = 1;
assign mem_lb = 1;
assign mem_ce = 1;
assign mem_cre = 0;

endmodule