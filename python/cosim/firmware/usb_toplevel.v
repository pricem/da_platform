/*

Top-level module for testing.
Has everything in it.

*/


module usb_toplevel(
    //  FX2 connections
    usb_ifclk, usb_slwr, usb_slrd, usb_sloe, usb_slcs, usb_addr, usb_data_in, usb_data_out, usb_ep2_empty, usb_ep4_empty, usb_ep6_full, usb_ep8_full,
    //  Cell RAM connections
    mem_addr, mem_data, mem_ce, mem_oe, mem_we, mem_clk, mem_wait, mem_addr_valid, mem_cre, mem_lb, mem_ub,
    //  Audio converter connections
    slot_data_in, slot_data_out, pmod_io, custom_dirchan, spi_adc_cs, spi_adc_mclk, spi_adc_mdi, spi_adc_mdo, spi_dac_cs, spi_dac_mclk, spi_dac_mdi, spi_dac_mdo, custom_adc_hwcon, custom_adc_ovf, custom_clk0, custom_srclk, custom_clksel, custom_clk1,
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
    output usb_slcs;
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
    output [3:0] pmod_io;
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
    
    //  Between FX2 interface and main controller
    wire [7:0] cmd_in_id;
    wire [15:0] cmd_in_length;
    wire [7:0] cmd_in_data;
    wire cmd_in_clk;
    wire cmd_in_ready;
    wire cmd_in_read;
    wire [7:0] cmd_out_id;
    wire [15:0] cmd_out_length;
    wire [7:0] cmd_out_data;
    wire cmd_out_clk;
    wire cmd_out_ready;
    wire cmd_out_write;
    
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
    
    //  Between controller and converter interfaces
    wire [1:0] io_config_addr;
    wire [7:0] io_config_data;
    wire [7:0] io_config_write;
    wire [7:0] io_config_read;
    wire io_config_clk;
    
    //  Between configuration memory and SPI controller
    wire [10:0] spi_config_addr;
    wire [7:0] spi_config_data;
    wire spi_config_read;
    wire spi_config_write;
    wire spi_config_clk;
    
    //  Between configuration memory and main controller
    wire [10:0] config_addr;
    wire [7:0] config_data;
    wire config_read;
    wire config_write;
    wire config_clk;
    
    //  Between I/O connections and converter modules
    wire [5:0] slot_data [3:0];
    wire [3:0] directions = 4'b1100;    //  Ports 0-1 are DAC, ports 2-3 are ADC
                                        //  This should be updated to reflect the DIR/CHAN port
    wire [3:0] channels = 4'b0000;      //  All ports 2-channel for now
    generate for (i = 0; i < 4; i = i + 1) begin:slot_assign
            assign slot_data[i] = directions[i] ? slot_data_in[((i + 1) * 4 - 1):(i * 4)] : 6'hZZ;
        end
    endgenerate
    
    //  Other signals needed for main controller
    wire [7:0] aovf;                    //  ADC overflow bits (for parallel ADCs like the PCM4202)
                                        //  Channel ordering (MSB first): R3, L3, R2, L2, R1, L1, R0, L0
    wire [3:0] direction;               //  Direction bit (0 = DAC, 1 = ADC) for each port
    wire [3:0] num_channels;            //  Number of channels bit (0 = 2-ch, 1 = 8-ch) for each port
    wire [3:0] clksel;                  //  Choice of clock (0 = 11.2896 MHz, 1 = 24.576 MHz) for each port
    wire [7:0] hwcon [3:0];             //  Hardware configuration register
    wire [31:0] hwcons;
    
    //  Other signals needed for SPI interface
    wire spi_mclk;
    assign spi_adc_mclk = spi_mclk;
    assign spi_dac_mclk = spi_mclk;
    wire spi_direction;                 //  Which type of device is active; 0 = DAC, 1 = ADC
    wire [1:0] spi_port_id;             //  Which port is being used (0 to 3)
    wire [3:0] spi_adcs;
    wire [3:0] spi_dacs;
    
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
    
    //  Generate shift register clock (custom_srclk) based on SPI clock (spi_mclk)
    reg [2:0] sr_count;
    assign custom_srclk = (sr_count == 0);
    always @(posedge spi_mclk or posedge reset) begin
        if (reset)
            sr_count <= 0;
        else begin
            sr_count <= sr_count + 1;
        end
    end
    
    //  Assign usb_slcs (chip select for FX2) active low
    assign usb_slcs = 0;
    
    /* Logic module instances */
    
    //  Deserialize on the way in: ADC overflow bits, direction/channels
    deserializer deser_ovf(
        .load_clk(custom_srclk), 
        .in(custom_adc_ovf), 
        .out(aovf), 
        .clk(spi_mclk), 
        .reset(reset)
        );
    deserializer deser_dirchan(
        .load_clk(custom_srclk), 
        .in(custom_dirchan), 
        .out({num_channels, direction}), 
        .clk(spi_mclk), 
        .reset(reset)
        );
        
    //  Serialize on the way out: SPI chip selects, clock selects
    serializer ser_adc_cs(
        .load_clk(custom_srclk), 
        .in({4'b0, ~spi_adcs}),     //  Active low
        .out(spi_adc_cs), 
        .clk(spi_mclk), 
        .reset(reset)
        );
    serializer ser_dac_cs(
        .load_clk(custom_srclk), 
        .in({4'b0, ~spi_dacs}),     //  Active low
        .out(spi_dac_cs), 
        .clk(spi_mclk), 
        .reset(reset)
        );
    serializer ser_clksel(
        .load_clk(custom_srclk), 
        .in({4'b0, clksel}), 
        .out(custom_clksel), 
        .clk(spi_mclk), 
        .reset(reset)
        );
        
    //  Assign, serialize HWCON
    generate for (i = 0; i < 4; i = i + 1) begin:hwcon_assign
            assign hwcon[i] = hwcons[((i + 1) * 8 - 1):(i * 8)];
        end
    endgenerate
    reg [1:0] hwcon_index;
    always @(posedge custom_srclk or posedge reset) begin
        if (reset)
            hwcon_index <= 0;
        else begin
            hwcon_index <= hwcon_index + 1;
        end
    end
    serializer ser_hwcon(
        .load_clk(custom_srclk), 
        .in(hwcon[hwcon_index]), 
        .out(custom_hwcon), 
        .clk(spi_mclk), 
        .reset(reset)
        );
    
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
        .ep6_port_addr_ins({read_in_addr[7], read_in_addr[6], read_in_addr[5], read_in_addr[4]}),
        .ep6_port_addr_outs({read_out_addr[7], read_out_addr[6], read_out_addr[5], read_out_addr[4]}),
        .ep6_port_datas({ep6_port_data[3], ep6_port_data[2], ep6_port_data[1], ep6_port_data[0]}), 
        .ep6_port_read(ep6_port_read), 
        .ep6_port_clk(ep6_port_clk), 
        .cmd_in_id(cmd_in_id),
        .cmd_in_length(cmd_in_length),
        .cmd_in_data(cmd_in_data),
        .cmd_in_clk(cmd_in_clk),
        .cmd_in_ready(cmd_in_ready), 
        .cmd_in_read(cmd_in_read), 
        .cmd_out_id(cmd_out_id),
        .cmd_out_length(cmd_out_length),
        .cmd_out_data(cmd_out_data),
        .cmd_out_clk(cmd_out_clk),
        .cmd_out_ready(cmd_out_ready), 
        .cmd_out_write(cmd_out_write), 
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
            //  Substitute PMOD for first DAC port
            if (i == 0)
                dac_pmod dac_i (
                    .config_clk(io_config_clk), 
                    .config_write(io_config_write[i]),
                    .config_read(io_config_read[i]), 
                    .config_addr(io_config_addr), 
                    .config_data(io_config_data),
                    .fifo_clk(slot_dac_fifo_clk[i]),
                    .fifo_data(slot_dac_fifo_data[i]),
                    .fifo_read(slot_dac_fifo_read[i]),
                    .fifo_addr_in(read_in_addr[i]),
                    .fifo_addr_out(read_out_addr[i]),
                    .pmod_io(pmod_io),
                    .custom_clk0(custom_clk0), 
                    .custom_clk1(custom_clk1),
                    .write_fifo_byte_count(write_fifo_byte_count[i]),
                    .read_fifo_byte_count(read_fifo_byte_count[i]),
                    .clk(clk), 
                    .reset(reset)
                    );
            else 
                dummy_dac dac_i (
                    .config_clk(io_config_clk), 
                    .config_write(io_config_write[i]),
                    .config_read(io_config_read[i]), 
                    .config_addr(io_config_addr), 
                    .config_data(io_config_data),
                    .fifo_clk(slot_dac_fifo_clk[i]),
                    .fifo_data(slot_dac_fifo_data[i]),
                    .fifo_read(slot_dac_fifo_read[i]),
                    .fifo_addr_in(read_in_addr[i]),
                    .fifo_addr_out(read_out_addr[i]),
                    .custom_clk0(custom_clk0),
                    .write_fifo_byte_count(write_fifo_byte_count[i]),
                    .read_fifo_byte_count(read_fifo_byte_count[i]),
                    .custom_clk1(custom_clk1),
                    .slot_data(slot_data_out[((i + 1) * 6 - 1):(i * 6)]),
                    .direction(directions[i]),
                    .channels(channels[i]),
                    .clk(clk), 
                    .reset(reset)
                    );
        end
    endgenerate
    generate for (i = 0; i < 4; i = i + 1) begin:adcs
        dummy_adc adc_i (
            .config_clk(io_config_clk), 
            .config_write(io_config_write[i + 4]),
            .config_read(io_config_read[i + 4]), 
            .config_addr(io_config_addr), 
            .config_data(io_config_data),
            .fifo_clk(slot_adc_fifo_clk[i]),
            .fifo_data(slot_adc_fifo_data[i]),
            .fifo_write(slot_adc_fifo_write[i]),
            .fifo_addr_in(write_in_addr[i + 4]),
            .fifo_addr_out(write_out_addr[i + 4]),
            .custom_clk0(custom_clk0),
            .custom_clk1(custom_clk1),
            .write_fifo_byte_count(write_fifo_byte_count[i + 4]),
            .read_fifo_byte_count(read_fifo_byte_count[i + 4]),
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
    /*
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
    */

    //  Main controller
    controller controller(
        .ep4_cmd_id(cmd_in_id),
        .ep4_cmd_length(cmd_in_length),
        .ep4_data(cmd_in_data),
        .ep4_clk(cmd_in_clk),
        .ep4_ready(cmd_in_ready), 
        .ep4_read(cmd_in_read), 
        .ep8_cmd_id(cmd_out_id),
        .ep8_cmd_length(cmd_out_length),
        .ep8_data(cmd_out_data),
        .ep8_clk(cmd_out_clk),
        .ep8_ready(cmd_out_ready), 
        .ep8_write(cmd_out_write), 
        .cfg_clk(config_clk),
        .cfg_addr(config_addr),
        .cfg_data(config_data),
        .cfg_write(config_write),
        .cfg_read(config_read),
        .cfg_io_clk(io_config_clk), 
        .cfg_io_write(io_config_write), 
        .cfg_io_read(io_config_read), 
        .cfg_io_addr(io_config_addr), 
        .cfg_io_data(io_config_data),
        .direction(direction),
        .num_channels(num_channels),
        .hwcons(hwcons),
        .write_fifo_byte_counts({write_fifo_byte_count[7], write_fifo_byte_count[6], write_fifo_byte_count[5], write_fifo_byte_count[4], write_fifo_byte_count[3], write_fifo_byte_count[2], write_fifo_byte_count[1], write_fifo_byte_count[0]}),
        .read_fifo_byte_counts({read_fifo_byte_count[7], read_fifo_byte_count[6], read_fifo_byte_count[5], read_fifo_byte_count[4], read_fifo_byte_count[3], read_fifo_byte_count[2], read_fifo_byte_count[1], read_fifo_byte_count[0]}),
        .clk(clk),
        .reset(reset)
        ); 
        
    //  Configuration memory
    wire [7:0] config_data_out;
    assign config_data = config_read ? config_data_out : 8'hZZ;
    bram_2k_8 config_mem (
        .clk(config_clk),
        .clk2(spi_config_clk),
        .we(config_write), 
        .we2(spi_config_write),
        .a(config_addr), 
        .dpra(spi_config_addr), 
        .spo(config_data_out),
        .di(config_data), 
        .di2(spi_config_data),
        .dpo(spi_config_data),
        .reset(reset)
        );

    //  SPI controller
    spi_controller spi(
        .config_clk(spi_config_clk), 
        .config_addr(spi_config_addr), 
        .config_read(spi_config_read), 
        .config_write(spi_config_write), 
        .config_data(spi_config_data),
        .custom_srclk(custom_srclk),
        .direction(direction),
        .num_channels(num_channels),
        .spi_mclk(spi_mclk), 
        .spi_adc_cs(spi_adcs),
        .spi_adc_mdi(spi_adc_mdi), 
        .spi_adc_mdo(spi_adc_mdo), 
        .spi_dac_cs(spi_dacs), 
        .spi_dac_mdi(spi_dac_mdi), 
        .spi_dac_mdo(spi_dac_mdo),
        .clk(clk), 
        .reset(reset)
        );

    //  Uncompleted modules follow
    
    //  Local button controller
    //  Monitor

    
endmodule

