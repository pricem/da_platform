//  Interface from a tracking FIFO to the Digilent PMOD-DA2 module.

module dac_pmod(
    //  Register programming
    config_clk, config_write, config_read, config_addr, config_data,
    //  FIFO connection
    fifo_clk, fifo_data, fifo_read, fifo_addr_in, fifo_addr_out,
    //  Clocks
    custom_clk0, custom_clk1, write_fifo_byte_count, read_fifo_byte_count,
    //  PMOD connector (instead of isolated FX2 bus)
    pmod_io,
    //  Control
    clk, reset
    );

    input config_clk;
    input config_write;
    input config_read;
    input [1:0] config_addr;
    inout [7:0] config_data;

    output fifo_clk;
    input [7:0] fifo_data;
    output reg fifo_read;
    input [10:0] fifo_addr_in;
    input [10:0] fifo_addr_out;
    
    //  6-pin PMOD connector; 4 pins for data are connected to this module.
    //  Pin 4: SCLK
    //  Pin 3: DINB
    //  Pin 2: DINA
    //  Pin 1: SYNC (goes low for the SCLK cycle before data words)
    output reg [3:0] pmod_io;
    
    input custom_clk0;
    input custom_clk1;
    input [31:0] write_fifo_byte_count;
    input [31:0] read_fifo_byte_count;
    
    input clk;
    input reset;
    
    genvar g;
    
    //  Clock management
    wire clksel = 1'b1;
    wire [3:0] clkexp = 4'b0111;
    wire clk_selected = clksel ? custom_clk1 : custom_clk0;
    reg [15:0] clk_counter;
    reg [5:0] bit_clk_counter;
    reg [1:0] msg_counter;
    wire [1:0] msg_counter_delayed;
    reg sample_clk;
    reg sample_clk_last;
    reg sample_bit_clk;

    //  Audio samples read from tracking FIFO in 16-bit LR format
    reg [31:0] sample;

    //  Keep reset around so you can cycle the sample clock at reset
    reg reset_last;
    
    //  Delay fifo_read signal for proper signal capture
    wire fifo_read_delayed;
    delay_reg fifo_read_delay(
        .clk(clk),
        .din(fifo_read),
        .dout(fifo_read_delayed),
        .reset(reset)
        );
    
    //  Wires for monitoring
    wire sync = pmod_io[0];
    wire dina = pmod_io[1];
    wire dinb = pmod_io[2];
    wire sclk = pmod_io[3];
    
    //  Run FIFO at full speed (could be changed for lower power consumption)
    assign fifo_clk = clk;
    
    //  Include configuration registers
    wire [31:0] registers;
    wire [7:0] config [3:0];
    generate for (g = 0; g < 4; g = g + 1) begin
            assign config[g] = registers[((g + 1) * 8 - 1):(g * 8)];
        end
    endgenerate
    ioreg config(config_clk, config_write, config_read, config_addr, config_data, registers, clk, reset);
    
    //  Delay message counter for loading samples
    delay_reg #(
        .NUM_BITS(2), 
        .NUM_CYCLES(2)
        ) 
        msg_delay(
        .clk(clk),
        .din(msg_counter),
        .dout(msg_counter_delayed),
        .reset(reset)
        );

    //  Run sample clock based on configuration
    always @(posedge clk_selected or posedge reset) begin
        if (reset) begin
            clk_counter <= 0;
            bit_clk_counter <= 0;
            sample_bit_clk <= 1;
            reset_last <= 1;
            //  Cycle FIFO clock at reset
            if (reset_last)
                sample_clk <= 0;
            else
                sample_clk <= 1;
        end
        else begin
            reset_last <= 0;

            //  Run sample bit clock at 32x the desired sample rate.
            //  The desired sample rate is the frequency of clk_selected << clkexp.
            if (bit_clk_counter == 31)
                sample_clk <= sample_clk + 1;
            if (clk_counter == (1 << (clkexp - 6)) - 1) begin
                sample_bit_clk <= sample_bit_clk + 1;
                bit_clk_counter <= bit_clk_counter + 1;
                clk_counter <= 0;
            end
            else
                clk_counter <= clk_counter + 1;

            //  Output bit clock
            pmod_io[3] <= sample_bit_clk;
            if (bit_clk_counter < 32) begin
                //  Right channel data
                pmod_io[2] <= sample[bit_clk_counter >> 1];
                //  Left channel data
                pmod_io[1] <= sample[16 + (bit_clk_counter >> 1)];
                //  Active low sync
                pmod_io[0] <= 0;
            end
            else begin
                //  Inactive period: SYNC high, no data
                pmod_io[2] <= 0;
                pmod_io[1] <= 0;
                pmod_io[0] <= 1;
            end
            
        end
    
    end

    always @(posedge clk) begin
        if (reset) begin
            msg_counter <= 0;
            sample <= 0;
            sample_clk_last <= 0;
        end
        else begin

            //  When the FIFO clock is triggered, read 4 bytes of data from the FIFO.
            sample_clk_last <= sample_clk;
            if (((sample_clk == 1) && (sample_clk_last == 0)) || (msg_counter != 0)) begin
                msg_counter <= msg_counter + 1;
                fifo_read <= 1;
            end
            else
                fifo_read <= 0;
            
            //  Copy the data over when possible.
            if (fifo_read_delayed) begin
                case (msg_counter_delayed)
                    0: sample[7:0] <= fifo_data;
                    1: sample[15:8] <= fifo_data;
                    2: sample[23:16] <= fifo_data;
                    3: sample[31:24] <= fifo_data;
                endcase
            end

        end
    end
    
    
endmodule

