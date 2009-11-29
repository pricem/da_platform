/*

Top-level module for testing.
Has everything in it.

*/


module usb_toplevel(
    //  FX2 connections
    usb_ifclk, usb_slwr, usb_slrd, usb_sloe, usb_addr, usb_data_in, usb_data_out, usb_ep2_empty, usb_ep4_empty, usb_ep6_full, usb_ep8_full,
    //  Cell RAM connections
    mem_addr, mem_data, mem_oe, mem_we, mem_clk, mem_addr_valid, 
    //  Audio converter connections
    slot0_data, slot1_data, slot2_data, slot3_data, spi_adc_cs, spi_adc_mclk, spi_adc_mdi, spi_adc_mdo, spi_dac_cs, spi_dac_mclk, spi_dac_mdi, spi_dac_mdo, custom_adc_hwcon, custom_adc_ovf, custom_clk0, custom_srclk, custom_clksel, custom_clk1,
    //  Control
    reset, clk
    );
    
    /*  In/out declarations  */
    
    //  USB interface
    input usb_ifclk;
    output usb_slwr;
    output usb_slrd;
    output usb_sloe;
    output [1:0] usb_addr;
    output [7:0] usb_data_in;
    input [7:0] usb_data_out;
    input usb_ep2_empty;
    input usb_ep4_empty;
    input usb_ep6_full;
    input usb_ep8_full;
    
    //  Cell RAM connection
    output [22:0] mem_addr;
    inout [15:0] mem_data;
    output mem_oe;
    output mem_we;
    output mem_clk;
    output mem_addr_valid;
    
    //  Audio converter (40-pin isolated bus)
    inout [5:0] slot0_data;
    inout [5:0] slot1_data;
    inout [5:0] slot2_data;
    inout [5:0] slot3_data;
    output spi_adc_cs;
    output spi_adc_mclk;
    output spi_adc_mdi;
    input spi_adc_mdo;
    output spi_dac_cs;
    output spi_dac_mclk;
    output spi_dac_mdi;
    input spi_dac_mdo;
    output custom_adc_hwcon;
    input custom_adc_ovf;
    input custom_clk0;
    output custom_srclk;
    output custom_clksel;
    input custom_clk1;
    
    //  Control (100-150 MHz clock)
    input clk;
    input reset;
    
    
    /* Interconnect signals */
    
    //  Between FX2 interface and tracking FIFOs
    wire [7:0] ep2_port_data;
    wire ep2_port_write[3:0];
    wire ep2_port_clk;
    wire [7:0] ep6_port_data[3:0];
    wire ep6_port_read[3:0];
    wire ep6_port_clk;
    
    //  Between FX2 interface and configuration memory
    wire [7:0] config_addr;
    wire config_write;
    wire config_clk;
    wire [7:0] config_data;
    
    //  Between FX2 interface and command encoder
    wire cmd_new_command;
    wire [7:0] cmd_data;
    wire cmd_clk;
    wire cmd_read;
    
    //  Between memory arbitrator and tracking FIFOs
    wire [10:0] write_in_addr[7:0];
    wire [10:0] write_out_addr[7:0];
    wire [7:0] write_read_data[7:0];
    wire write_fifo_clk;
    wire write_read[7:0];
    wire [10:0] read_in_addr[7:0];
    wire [10:0] read_out_addr[7:0];
    wire [7:0] read_write_data[7:0];
    wire read_fifo_clk;
    wire read_write[7:0];
    
    //  Between tracking FIFOs and converter interfaces
    wire slot_dac_fifo_clk[3:0];
    wire slot_adc_fifo_clk[3:0];
    wire slot_dac_fifo_read[3:0];
    wire slot_adc_fifo_write[3:0];
    wire [7:0] slot_dac_fifo_data[3:0];
    wire [7:0] slot_adc_fifo_data[3:0];
    
    /* Logic module instances */
    
    //  FX2 interface (includes command decoder and port decoders)
    fx2_interface interface(
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
        .ep2_port_data(ep2_port_data), 
        .ep2_port_write(ep2_port_write), 
        .ep2_port_clk(ep2_port_clk), 
        .ep6_port_data(ep6_port_data), 
        .ep6_port_read(ep6_port_read), 
        .ep6_port_clk(ep6_port_clk), 
        .config_addr(config_addr), 
        .config_write(config_write), 
        .config_clk(config_clk), 
        .config_data(config_data), 
        .cmd_new_command(cmd_new_command), 
        .cmd_data(cmd_data), 
        .cmd_clk(cmd_clk), 
        .cmd_read(cmd_read), 
        .reset(reset), 
        .clk(clk)
        );
    
    //  Tracking FIFOs: EP2->RAM
    tracking_fifo fifos_ep2_in [3:0] (
        .clk_in(ep2_port_clk),
        .data_in(ep2_port_data), 
        .write_in(ep2_port_write), 
        .clk_out(write_fifo_clk), 
        .data_out(write_read_data[3:0]),
        .read_out(write_read[3:0]), 
        .addr_in(write_in_addr[3:0]), 
        .addr_out(write_out_addr[3:0]), 
        .reset(reset)
        );
    
    //  Tracking FIFOs: RAM->DACs
    tracking_fifo fifos_dac_out [3:0] (
        .clk_in(read_fifo_clk),
        .data_in(read_write_data[3:0]), 
        .write_in(read_write[3:0]), 
        .clk_out(slot_dac_fifo_clk), 
        .data_out(slot_dac_fifo_data),
        .read_out(slot_dac_fifo_read), 
        .addr_in(read_in_addr[3:0]), 
        .addr_out(read_out_addr[3:0]), 
        .reset(reset)
        );
    
    //  Tracking FIFOs: ADCs->RAM
    tracking_fifo fifos_adc_in [3:0] (
        .clk_in(slot_adc_fifo_clk),
        .data_in(slot_adc_fifo_data), 
        .write_in(slot_adc_fifo_write), 
        .clk_out(write_fifo_clk), 
        .data_out(write_read_data[7:4]),
        .read_out(write_read[7:4]), 
        .addr_in(write_in_addr[7:4]), 
        .addr_out(write_out_addr[7:4]), 
        .reset(reset)
        );
    
    //  Tracking FIFOs: RAM->EP6
    tracking_fifo fifos_ep6_out [3:0] (
        .clk_in(read_fifo_clk),
        .data_in(read_write_data[7:4]), 
        .write_in(read_write[7:4]), 
        .clk_out(ep6_port_clk), 
        .data_out(ep6_port_data),
        .read_out(ep6_port_read), 
        .addr_in(read_in_addr[7:4]), 
        .addr_out(read_out_addr[7:4]), 
        .reset(reset)
        );
    
    //  Memory arbitrator
    memory_arbitrator arb(
        .write_in_addr(write_in_addr), 
        .write_out_addr(write_out_addr), 
        .write_read_data(write_read_data), 
        .write_clk(write_clk), 
        .write_read(write_read),
        .read_in_addr(read_in_addr), 
        .read_out_addr(read_out_addr), 
        .read_write_data(read_write_data), 
        .read_clk(read_clk), 
        .read_write(read_write),
        .write_fifo_byte_count(write_fifo_byte_count),
        .read_fifo_byte_count(read_fifo_byte_count),
        .mem_addr(mem_addr), 
        .mem_data(mem_data),
        .mem_oe(mem_oe), 
        .mem_we(mem_we), 
        .mem_clk(mem_clk), 
        .mem_addr_valid(mem_addr_valid), 
        .clk(clk), 
        .reset(reset)
        );
    
    //  Configuration memory
    bram_2k_8 config_mem (
        .clk(config_clk),
        .we(config_write), 
        .a(config_addr), 
        .dpra(config_read_addr), 
        .di(config_data), 
        .dpo(config_read_data)
        );
    
    //  Uncompleted modules follow
    //  Configuration controller
    //  Local button controller
    //  Monitor
    
    
    
endmodule

