`timescale 1ns/1ps

module dut_usb_toplevel;

    reg usb_ifclk;
    wire usb_slwr;
    wire usb_slrd;
    wire usb_sloe;
    wire [1:0] usb_addr;
    wire [7:0] usb_data_in;
    reg [7:0] usb_data_out;
    reg usb_ep2_empty;
    reg usb_ep4_empty;
    reg usb_ep6_full;
    reg usb_ep8_full;
    
    //  Cell RAM connection
    wire [22:0] mem_addr;
    
    reg [15:0] mem_data_myhdl_in;
    reg mem_data_myhdl_driven;
    wire [15:0] mem_data;
    
    wire mem_oe;
    wire mem_we;
    wire mem_clk;
    wire mem_addr_valid; 
    
    //  Audio converter (40-pin isolated bus)
    reg custom_dirchan;
    reg [23:0] slot_data_in;
    wire [23:0] slot_data_out;
    
    wire spi_adc_cs;
    wire spi_adc_mclk;
    wire spi_adc_mdi;
    reg spi_adc_mdo;
    wire spi_dac_cs;
    wire spi_dac_mclk;
    wire spi_dac_mdi;
    reg spi_dac_mdo;
    wire custom_adc_hwcon;
    reg custom_adc_ovf;
    reg custom_clk0;
    wire custom_srclk;
    wire custom_clksel;
    reg custom_clk1;
    
    //  Control (100-150 MHz clock)
    reg clk;
    reg reset;
    
    initial begin
        $dumpfile("usb_toplevel_verilog.vcd");
        $dumpvars(0, dut);
        $from_myhdl(usb_ifclk, usb_data_out, usb_ep2_empty, usb_ep4_empty, usb_ep6_full, usb_ep8_full, mem_data_myhdl_in, mem_data_myhdl_driven, slot_data_in, custom_dirchan, spi_adc_mdo, spi_dac_mdo, custom_adc_ovf, custom_clk0, custom_clk1, clk, reset);
        $to_myhdl(usb_slwr, usb_slrd, usb_sloe, usb_addr, usb_data_in, mem_addr, mem_data, mem_oe, mem_we, mem_clk, mem_addr_valid, slot_data_out, spi_adc_cs, spi_adc_mclk, spi_adc_mdi, spi_dac_cs, spi_dac_mclk, spi_dac_mdi, custom_adc_hwcon, custom_srclk, custom_clksel);
    end
    
    assign mem_data = mem_data_myhdl_driven ? mem_data_myhdl_in : 16'hZZZZ;
    
    usb_toplevel dut (
        .usb_ifclk(usb_ifclk),
        .usb_slwr(usb_slwr),
        .usb_slrd(usb_slrd),
        .usb_sloe(usb_sloe),
        .usb_addr(usb_addr),
        .usb_data_in(usb_data_in),
        .usb_data_out(usb_data_out),
        .usb_ep2_empty(usb_ep2_empty),
        .usb_ep4_empty(usb_ep4_empty),
        .usb_ep6_full(usb_ep6_full),
        .usb_ep8_full(usb_ep8_full),
        .mem_addr(mem_addr),
        .mem_data(mem_data),
        .mem_oe(mem_oe),
        .mem_we(mem_we),
        .mem_clk(mem_clk),
        .mem_addr_valid(mem_addr_valid),
        .slot_data_in(slot_data_in),
        .slot_data_out(slot_data_out),
        .custom_dirchan(custom_dirchan),
        .spi_adc_cs(spi_adc_cs),
        .spi_adc_mclk(spi_adc_mclk),
        .spi_adc_mdi(spi_adc_mdi),
        .spi_adc_mdo(spi_adc_mdo),
        .spi_dac_cs(spi_dac_cs),
        .spi_dac_mclk(spi_dac_mclk),
        .spi_dac_mdi(spi_dac_mdi),
        .spi_dac_mdo(spi_dac_mdo),
        .custom_adc_hwcon(custom_adc_hwcon),
        .custom_adc_ovf(custom_adc_ovf),
        .custom_clk0(custom_clk0),
        .custom_srclk(custom_srclk),
        .custom_clksel(custom_clksel),
        .custom_clk1(custom_clk1),
        .clk(clk),
        .reset(reset)
    );
    
endmodule
