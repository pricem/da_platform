module dut_usb_toplevel;

    wire usb_ifclk;
    reg usb_slwr;
    reg usb_slrd;
    reg usb_sloe;
    reg [1:0] usb_addr;
    reg [7:0] usb_data_in;
    wire [7:0] usb_data_out;
    wire usb_ep2_empty;
    wire usb_ep4_empty;
    wire usb_ep6_full;
    wire usb_ep8_full;
    
    //  Cell RAM connection
    reg [22:0] mem_addr;
    
    wire [15:0] mem_data_myhdl_in;
    wire mem_data_myhdl_driven;
    wire [15:0] mem_data;
    
    reg mem_oe;
    reg mem_we;
    reg mem_clk;
    reg mem_addr_valid; 
    
    //  Audio converter (40-pin isolated bus)
    wire [5:0] slot_data_myhdl_in [3:0];
    wire slot_data_myhdl_driven [3:0];
    wire [5:0] slot0_data;
    wire [5:0] slot1_data;
    wire [5:0] slot2_data;
    wire [5:0] slot3_data;
    wire [5:0] slot_data [3:0];
    
    reg spi_adc_cs;
    reg spi_adc_mclk;
    reg spi_adc_mdi;
    wire spi_adc_mdo;
    reg spi_dac_cs;
    reg spi_dac_mclk;
    reg spi_dac_mdi;
    wire spi_dac_mdo;
    reg custom_adc_hwcon;
    wire custom_adc_ovf;
    wire custom_clk0;
    reg custom_srclk;
    reg custom_clksel;
    wire custom_clk1;
    
    //  Control (100-150 MHz clock)
    wire clk;
    wire reset;
    
    initial begin
        $from_myhdl(usb_ifclk, usb_data_out, usb_ep2_empty, usb_ep4_empty, usb_ep6_full, usb_ep8_full, mem_data_myhdl_in, mem_data_myhdl_driven, slot_data_myhdl_in, slot_data_myhdl_driven, spi_adc_mdo, spi_dac_mdo, custom_adc_ovf, custom_clk0, custom_clk1, clk, reset);
        $to_myhdl(usb_slwr, usb_slrd, usb_sloe, usb_addr, usb_data_in, mem_addr, mem_data, mem_oe, mem_we, mem_clk, mem_addr_valid, slot_data, spi_adc_cs, spi_adc_mclk, spi_adc_mdi, spi_dac_cs, spi_dac_mclk, spi_dac_mdi, custom_adc_hwcon, custom_srclk, custom_clksel);
    end
    
    always @(mem_data_myhdl_in or mem_data_myhdl_driven)
        if (mem_data_myhdl_driven)
            mem_data = mem_data_myhdl_in;
            
    always @(slot_data_myhdl_in or slot_data_myhdl_driven) begin
        if (slot_data_myhdl_driven[0])
            slot0_data = slot_data_myhdl_in[0];
        if (slot_data_myhdl_driven[1])
            slot1_data = slot_data_myhdl_in[1];
        if (slot_data_myhdl_driven[2])
            slot2_data = slot_data_myhdl_in[2];
        if (slot_data_myhdl_driven[3])
            slot3_data = slot_data_myhdl_in[3];
        end
    
    assign slot_data[0] = slot0_data;
    assign slot_data[1] = slot1_data;
    assign slot_data[2] = slot2_data;
    assign slot_data[3] = slot3_data;
    
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
        .slot0_data(slot0_data),
        .slot1_data(slot1_data),
        .slot2_data(slot2_data),
        .slot3_data(slot3_data),
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
