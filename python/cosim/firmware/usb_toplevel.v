/*

Top-level module for testing.
Has everything in it.

*/


module usb_toplevel(
    //  FX2 connections
    usb_ifclk, usb_slwr, usb_slrd, usb_sloe, usb_addr, usb_data_in, usb_data_out, usb_ep2_empty, usb_ep4_empty, usb_ep6_full, usb_ep8_full,
    //  Cell RAM connections
    mem_addr, mem_data, mem_ce, mem_oe, mem_we, mem_clk, mem_wait, mem_addr_valid, mem_cre, mem_lb, mem_ub,
    //  Audio converter connections
    slot_data_in, slot_data_out, custom_dirchan, spi_adc_cs, spi_adc_mclk, spi_adc_mdi, spi_adc_mdo, spi_dac_cs, spi_dac_mclk, spi_dac_mdi, spi_dac_mdo, custom_adc_hwcon, custom_adc_ovf, custom_clk0, custom_srclk, custom_clksel, custom_clk1,
    //  Control
    reset, clk
    );
    
    genvar i;
    
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
    output mem_ce;
    output mem_oe;
    output mem_we;
    output mem_clk;
    //  The mem_wait signal is set to inout for simulation purposes where it is driven by the cellram module.
    inout mem_wait;
    //  input mem_wait;
    output mem_addr_valid;
    output mem_cre;
    output mem_lb;
    output mem_ub;
    
    //  Audio converter (40-pin isolated bus)
    input [23:0] slot_data_in;
    output [23:0] slot_data_out;
    input custom_dirchan;
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
   
    //  Between memory arbitrator and off-chip RAM: many wires need to be made active low
    wire mem_ce_neg = ~mem_ce;
    wire mem_oe_neg = ~mem_oe;
    wire mem_we_neg = ~mem_we;
    wire mem_adv_neg = ~mem_addr_valid;
    wire reset_neg = ~reset;
    
    //  Between FX2 interface and tracking FIFOs
    wire [7:0] ep2_port_data;
    wire [3:0] ep2_port_write;
    wire ep2_port_clk;
    wire [7:0] ep6_port_data[3:0];
    wire [3:0] ep6_port_read;
    wire ep6_port_clk;
    
    //  Between FX2 interface and command decoder (which in turn writes configuration memory)
    wire [15:0] cmd_in_id;
    wire [7:0] cmd_in_data;
    wire cmd_in_clk;
    wire cmd_valid;
    
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
    wire [7:0] write_read;
    wire [10:0] read_in_addr[7:0];
    wire [10:0] read_out_addr[7:0];
    wire [7:0] read_write_data[7:0];
    wire read_fifo_clk;
    wire [7:0] read_write;
    reg [31:0] write_fifo_byte_count[7:0];
    wire [31:0] read_fifo_byte_count[7:0];
    
    //  Between tracking FIFOs and converter interfaces
    wire slot_dac_fifo_clk[3:0];
    wire slot_adc_fifo_clk[3:0];
    wire slot_dac_fifo_read[3:0];
    wire slot_adc_fifo_write[3:0];
    wire [7:0] slot_dac_fifo_data[3:0];
    wire [7:0] slot_adc_fifo_data[3:0];
    
    //  Between configuration memory and serial port controller
    wire [10:0] config_read_addr;
    wire [7:0] config_read_data;
    
    //  Between I/O connections and converter modules
    wire [5:0] slot_data [3:0];
    wire [3:0] directions = 4'b1100;    //  Ports 0-1 are DAC, ports 2-3 are ADC
                                        //  This should be updated to reflect the DIR/CHAN port
    wire [3:0] channels = 4'b0000;      //  All ports 2-channel for now
    generate for (i = 0; i < 4; i = i + 1) begin:slot_assign
            assign slot_data[i] = directions[i] ? slot_data_in[((i + 1) * 4 - 1):(i * 4)] : 6'hZZ;
        end
    endgenerate
    
    //  Testing for PMOD DA2 module
    wire [3:0] pmod_io;
    wire pmod_clksel = 1;               //  24.576 MHz
    wire [3:0] pmod_clkexp = 4'b0111;   //  Divide by 2^7 = 128: 192 kHz
    
    //  Assign byte counters to keep track of number of samples since reset
    generate for (i = 0; i < 4; i = i + 1) begin:counters
            //  FIFOs between EP2 and memory arbitrator for DACs
            always @(posedge ep2_port_clk) begin
                if (reset)
                    write_fifo_byte_count[i] <= 0;
                else begin
                    if (ep2_port_write[i])
                        write_fifo_byte_count[i] <= write_fifo_byte_count[i] + 1;
                end
            end
            //  FIFOs between ADC converter interfaces and memory arbitrator
            always @(posedge slot_adc_fifo_clk[i]) begin
                if (reset)
                    write_fifo_byte_count[i + 4] <= 0;
                else begin
                    if (slot_adc_fifo_write[i])
                        write_fifo_byte_count[i + 4] <= write_fifo_byte_count[i + 4] + 1;
                end
            end
        end
    endgenerate
    
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
        .ep6_port_datas({ep6_port_data[3], ep6_port_data[2], ep6_port_data[1], ep6_port_data[0]}), 
        .ep6_port_read(ep6_port_read), 
        .ep6_port_clk(ep6_port_clk), 
        .cmd_in_id(cmd_in_id),
        .cmd_in_data(cmd_in_data),
        .cmd_valid(cmd_valid),
        .cmd_in_clk(cmd_in_clk),
        .cmd_new_command(cmd_new_command), 
        .cmd_data(cmd_data), 
        .cmd_clk(cmd_clk), 
        .cmd_read(cmd_read), 
        .reset(reset), 
        .clk(clk)
        );
    
    //  Tracking FIFOs: EP2->RAM
    generate for (i = 0; i < 4; i = i + 1) begin:ports
        tracking_fifo fifos_ep2_in_i (
            .clk_in(ep2_port_clk),
            .data_in(ep2_port_data), 
            .write_in(ep2_port_write[i]), 
            .clk_out(write_fifo_clk), 
            .data_out(write_read_data[i]),
            .read_out(write_read[i]), 
            .addr_in(write_in_addr[i]), 
            .addr_out(write_out_addr[i]), 
            .reset(reset)
            );
        
        //  Tracking FIFOs: RAM->DACs
        tracking_fifo fifos_dac_out_i (
            .clk_in(read_fifo_clk),
            .data_in(read_write_data[i]), 
            .write_in(read_write[i]), 
            .clk_out(slot_dac_fifo_clk[i]), 
            .data_out(slot_dac_fifo_data[i]),
            .read_out(slot_dac_fifo_read[i]), 
            .addr_in(read_in_addr[i]), 
            .addr_out(read_out_addr[i]), 
            .reset(reset)
            );
        
        //  Tracking FIFOs: ADCs->RAM
        tracking_fifo fifos_adc_in_i (
            .clk_in(slot_adc_fifo_clk[i]),
            .data_in(slot_adc_fifo_data[i]), 
            .write_in(slot_adc_fifo_write[i]), 
            .clk_out(write_fifo_clk), 
            .data_out(write_read_data[i + 4]),
            .read_out(write_read[i + 4]), 
            .addr_in(write_in_addr[i + 4]), 
            .addr_out(write_out_addr[i + 4]), 
            .reset(reset)
            );
        
        //  Tracking FIFOs: RAM->EP6
        tracking_fifo fifos_ep6_out_i (
            .clk_in(read_fifo_clk),
            .data_in(read_write_data[i + 4]), 
            .write_in(read_write[i + 4]), 
            .clk_out(ep6_port_clk), 
            .data_out(ep6_port_data[i]),
            .read_out(ep6_port_read[i]), 
            .addr_in(read_in_addr[i + 4]), 
            .addr_out(read_out_addr[i + 4]), 
            .reset(reset)
            );
        end
    endgenerate
    
    //  Converters
    generate for (i = 0; i < 4; i = i + 1) begin:dacs
            if (i == 0) begin
                dac_pmod dac_i (
                    .fifo_clk(slot_dac_fifo_clk[i]),
                    .fifo_data(slot_dac_fifo_data[i]),
                    .fifo_read(slot_dac_fifo_read[i]),
                    .fifo_addr_in(read_in_addr[i]),
                    .fifo_addr_out(read_out_addr[i]),
                    .pmod_io(pmod_io),
                    .custom_clk0(custom_clk0), 
                    .custom_clk1(custom_clk1),
                    .clksel(pmod_clksel), 
                    .clkexp(pmod_clkexp),
                    .clk(clk), 
                    .reset(reset)
                    );
            end
            else begin
                dummy_dac dac_i (
                    .fifo_clk(slot_dac_fifo_clk[i]),
                    .fifo_data(slot_dac_fifo_data[i]),
                    .fifo_read(slot_dac_fifo_read[i]),
                    .fifo_addr_in(read_in_addr[i]),
                    .fifo_addr_out(read_out_addr[i]),
                    .slot_data(slot_data_out[((i + 1) * 6 - 1):(i * 6)]),
                    .direction(directions[i]),
                    .channels(channels[i]),
                    .clk(clk), 
                    .reset(reset)
                    );
            end
        end
    endgenerate
    generate for (i = 0; i < 4; i = i + 1) begin:adcs
        dummy_adc adc_i (
            .fifo_clk(slot_adc_fifo_clk[i]),
            .fifo_data(slot_adc_fifo_data[i]),
            .fifo_write(slot_adc_fifo_write[i]),
            .fifo_addr_in(write_in_addr[i + 4]),
            .fifo_addr_out(write_out_addr[i + 4]),
            .slot_data(slot_data_in[((i + 1) * 6 - 1):(i * 6)]),
            .direction(directions[i]),
            .channels(channels[i]),
            .clk(clk), 
            .reset(reset)
            );
        end
    endgenerate
    
    //  Memory arbitrator
    memory_arbitrator arb(
        .write_in_addrs({write_in_addr[7], write_in_addr[6], write_in_addr[5], write_in_addr[4], write_in_addr[3], write_in_addr[2], write_in_addr[1], write_in_addr[0]}), 
        .write_out_addrs({write_out_addr[7], write_out_addr[6], write_out_addr[5], write_out_addr[4], write_out_addr[3], write_out_addr[2], write_out_addr[1], write_out_addr[0]}), 
        .write_read_datas({write_read_data[7], write_read_data[6], write_read_data[5], write_read_data[4], write_read_data[3], write_read_data[2], write_read_data[1], write_read_data[0]}), 
        .write_clk(write_fifo_clk), 
        .write_read(write_read),
        .read_in_addrs({read_in_addr[7], read_in_addr[6], read_in_addr[5], read_in_addr[4], read_in_addr[3], read_in_addr[2], read_in_addr[1], read_in_addr[0]}), 
        .read_out_addrs({read_out_addr[7], read_out_addr[6], read_out_addr[5], read_out_addr[4], read_out_addr[3], read_out_addr[2], read_out_addr[1], read_out_addr[0]}), 
        .read_write_datas({read_write_data[7], read_write_data[6], read_write_data[5], read_write_data[4], read_write_data[3], read_write_data[2], read_write_data[1], read_write_data[0]}), 
        .read_clk(read_fifo_clk), 
        .read_write(read_write),
        .write_fifo_byte_counts({write_fifo_byte_count[7], write_fifo_byte_count[6], write_fifo_byte_count[5], write_fifo_byte_count[4], write_fifo_byte_count[3], write_fifo_byte_count[2], write_fifo_byte_count[1], write_fifo_byte_count[0]}),
        .read_fifo_byte_counts({read_fifo_byte_count[7], read_fifo_byte_count[6], read_fifo_byte_count[5], read_fifo_byte_count[4], read_fifo_byte_count[3], read_fifo_byte_count[2], read_fifo_byte_count[1], read_fifo_byte_count[0]}),
        .mem_addr(mem_addr), 
        .mem_data(mem_data),
        .mem_ce(mem_ce),
        .mem_oe(mem_oe), 
        .mem_we(mem_we), 
        .mem_clk(mem_clk), 
        .mem_wait(mem_wait),
        .mem_addr_valid(mem_addr_valid), 
        .mem_cre(mem_cre),
        .clk(clk), 
        .reset(reset)
        );
    
    //  Always use both lower and upper bytes (active low signals)
    assign mem_ub_neg = 0;
    assign mem_lb_neg = 0;
    
    //  Memory (comment out for synthesis)
    cellram buffer(
        .clk(mem_clk), 
        .ce(mem_ce_neg),
        .we(mem_we_neg), 
        .oe(mem_oe_neg),
        .addr(mem_addr), 
        .data(mem_data), 
        .cre(mem_cre),
        .adv(mem_adv_neg),
        .mem_wait(mem_wait),
        .lb(mem_lb_neg),
        .ub(mem_ub_neg),
        .reset(reset_neg)
        );
    
    //  Uncompleted modules follow
    //  Configuration controller (and memory)
    //  Local button controller
    //  Monitor
    
    
    
endmodule

