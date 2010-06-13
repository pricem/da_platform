/*  SPI controller

This module controls the shared SPI buses for the DACs and ADCs.

An interesting question is whether this module should read register values from
the converter chips and store them back into the configuration memory.
(There is a hook for this in the STATE_READBACK state.)
If so, which registers does it read?  Does it read all of them, or only the ones
present in configuration memory, or some other set?

*/

module spi_controller(
    //  Configuration memory interface
    config_clk, config_addr, config_read, config_write, config_data,
    //  Other signals to monitor
    direction, num_channels, custom_srclk,
    //  ADC and DAC buses
    spi_mclk, spi_adc_cs, spi_adc_mdi, spi_adc_mdo, spi_dac_cs, spi_dac_mdi, spi_dac_mdo,
    //  Basic
    clk, reset
    );
    
    output config_clk;
    output reg [10:0] config_addr;
    output reg config_read;
    output reg config_write;
    inout [7:0] config_data;
    
    input [3:0] direction;
    input [3:0] num_channels;
    input custom_srclk;
    
    output spi_mclk;
    output [3:0] spi_adc_cs;
    output spi_adc_mdi;
    input spi_adc_mdo;
    output [3:0] spi_dac_cs;
    output spi_dac_mdi;
    input spi_dac_mdo;
    
    input clk;
    input reset;

    genvar g;

    parameter MAX_NUM_REGISTERS = 16;
    
    //  State for configuration memory interface
    reg [2:0] state;
    parameter STATE_IDLE = 3'b000;
    parameter STATE_READING = 3'b001;
    parameter STATE_PROGRAMMING = 3'b010;
    parameter STATE_READBACK = 3'b011;
    
    reg [2:0] read_state;
    reg [2:0] write_state;
    parameter RW_IDLE = 3'b000;
    parameter RW_ADDRESS = 3'b001;
    parameter RW_DATA = 3'b010;
    parameter RW_PROCESSING = 3'b011;
    parameter RW_DONE = 3'b100;
    
    reg [3:0] reg_index;
    reg [1:0] port_index;
    
    //  State for SPI component
    reg [2:0] spi_state;
    parameter SPI_START = 3'b000;
    parameter SPI_GLOBAL_ADDRESS = 3'b001;
    parameter SPI_ADDRESS = 3'b010;
    parameter SPI_DATA = 3'b011;
    parameter SPI_DONE = 3'b100;
    reg [2:0] spi_state_last;
    
    reg spi_direction;                  //  0 = read, 1 = write
    reg [7:0] spi_global_addr;          //  Global address of chip (ADI only; includes R/W flag in LSB)
    reg [7:0] spi_addr;                 //  Address of register to read/write (for TI, includes R/W flag in MSB)
    reg [7:0] spi_data_in;
    reg [7:0] spi_data_out;
    reg [2:0] spi_bit_counter;
    reg spi_bit_out;
    wire spi_bit_in;
    wire [1:0] spi_format_id;
    parameter SPI_FORMAT_NONE = 2'b00;
    parameter SPI_FORMAT_TI = 2'b01;
    parameter SPI_FORMAT_ADI = 2'b10;
    
    //  Configuration memory bus
    assign config_clk = clk;            //  Run configuration memory at full speed.
    reg [7:0] config_data_out;
    assign config_data = config_write ? config_data_out : 8'hZZ;

    //  Generate SPI clock (spi_mclk)
    //  Divide main clock by 16 for now
    reg [3:0] spi_mclk_count;
    assign spi_mclk = (spi_mclk_count > 7);
    always @(posedge clk or posedge reset) begin
        if (reset)
            spi_mclk_count <= 0;
        else begin
            spi_mclk_count <= spi_mclk_count + 1;
        end
    end
    
    //  Assign SPI format parameters
    assign spi_format_id = direction[port_index] 
                            ? (num_channels[port_index] ? SPI_FORMAT_ADI : SPI_FORMAT_NONE) 
                            : (num_channels[port_index] ? SPI_FORMAT_ADI : SPI_FORMAT_TI);

    //  Assign chip select outputs.  Only one of the 8 is active at any given time.
    generate for (g = 0; g < 4; g = g + 1) begin:cs_assignment
            assign spi_adc_cs[g] = ((port_index == g) && (direction[port_index] == 1) && (spi_state_last != SPI_START) && (spi_state_last != SPI_DONE));
            assign spi_dac_cs[g] = ((port_index == g) && (direction[port_index] == 0) && (spi_state_last != SPI_START) && (spi_state_last != SPI_DONE));
        end
    endgenerate
    
    //  Assign SPI input/output
    assign spi_dac_mdi = (direction[port_index] || ~spi_dac_cs[port_index]) ? 1'bZ : spi_bit_out;
    assign spi_adc_mdi = (direction[port_index] && spi_adc_cs[port_index]) ? spi_bit_out : 1'bZ;
    assign spi_bit_in = direction[port_index] ? spi_adc_mdo : spi_dac_mdo;
    
    //  Primary state machine
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= STATE_IDLE;
            read_state <= RW_IDLE;
            write_state <= RW_IDLE;
            
            port_index <= 0;
            reg_index <= 0;
            
            config_addr <= 0;
            config_read <= 0;
            config_write <= 0;
            
            spi_data_out <= 0;
            spi_addr <= 0;
            spi_direction <= 0;
        end
        else begin
            case (state)
                STATE_IDLE: begin
                    reg_index <= 0;
                    read_state <= RW_ADDRESS;
                    state <= STATE_READING;
                end
                
                STATE_READING: begin
                    //  Read the current register from configuration RAM.
                    case (read_state)
                        RW_IDLE: begin
                            //  Sit here unless otherwise instructed.
                        end
                        
                        RW_ADDRESS: begin
                            //  Set address of register address
                            config_addr <= 11'h400 + (port_index << 7) + (direction[port_index] << 6) + (num_channels[port_index] << 5) + (reg_index << 1) + 1;
                            config_read <= 1;
                            read_state <= RW_DATA;
                        end 
                        
                        RW_DATA: begin
                            //  Set address of register data
                            config_addr <= 11'h400 + (port_index << 7) + (direction[port_index] << 6) + (num_channels[port_index] << 5) + (reg_index << 1);
                            config_read <= 1;
                            read_state <= RW_PROCESSING;
                        end
                        
                        RW_PROCESSING: begin
                            //  If this entry has been set, continue to read the data.
                            if (config_data[7]) begin
                                //  Get register address
                                spi_addr <= {1'b0, config_data[6:0]};
                                read_state <= RW_DONE;
                            end
                            //  Otherwise, there are no more registers to read... skip to the readback state.
                            else begin
                                reg_index <= 0;
                                read_state <= RW_IDLE;
                                state <= STATE_READBACK;                            
                            end
                        end
                        
                        RW_DONE: begin
                            //  Get register data
                            spi_data_out <= config_data;
                            config_read <= 0;
                            //  Go to programming SPI.
                            read_state <= RW_IDLE;
                            spi_direction <= 1;
                            state <= STATE_PROGRAMMING;
                        end
                    endcase
                end
                
                STATE_PROGRAMMING: begin
                    //  Program the converter chip with the current register over the SPI bus.
                    //  This is initiated at the end of the above read.
                    //  When it's done, move to the next register or start the readback cycle.
                    if (spi_state == SPI_DONE) begin
                        spi_direction <= 0;
                        if (reg_index >= MAX_NUM_REGISTERS - 1) begin
                            reg_index <= 0;
                            state <= STATE_READBACK;
                        end
                        else begin
                            reg_index <= reg_index + 1;
                            read_state <= RW_ADDRESS;
                            state <= STATE_READING;
                        end
                    end
                end
                
                STATE_READBACK: begin
                    //  Not yet supported. Return to idle mode and start on the next port.
                    port_index <= port_index + 1;
                    state <= STATE_IDLE;
                end
            endcase
        end
    end
    
    //  SPI bus state machine
    always @(posedge spi_mclk or posedge reset) begin
        if (reset) begin
            spi_state <= SPI_DONE;
            spi_state_last <= SPI_DONE;

            spi_global_addr <= 0;
            spi_data_in <= 0;
            spi_bit_counter <= 0;
            spi_bit_out <= 0;
        end
        else begin
            //  Keep track of state from last cycle
            spi_state_last <= spi_state;
            case (spi_state)
                SPI_START: begin
                    //  Decide which state to go to based on the SPI format of the current converter.
                    case (spi_format_id)
                        SPI_FORMAT_NONE: spi_state <= SPI_DONE;
                        SPI_FORMAT_ADI: begin
                            //  Write the global address byte to SPI before the register address.
                            spi_global_addr[7:1] <= 7'h04;
                            spi_global_addr[0] <= spi_direction;
                            
                            spi_bit_counter <= 0;
                            spi_state <= SPI_GLOBAL_ADDRESS;
                        end
                        SPI_FORMAT_TI: begin                            
                            spi_bit_counter <= 0;
                            spi_state <= SPI_ADDRESS;
                        end
                    endcase
                end
                
                SPI_GLOBAL_ADDRESS: begin
                    spi_bit_counter <= spi_bit_counter + 1;
                    spi_bit_out <= spi_global_addr[7 - spi_bit_counter];
                    if (spi_bit_counter == 7) begin
                        spi_bit_counter <= 0;
                        spi_state <= SPI_ADDRESS;
                    end
                end
                
                SPI_ADDRESS: begin
                    spi_bit_counter <= spi_bit_counter + 1;
                    case (spi_format_id)
                        SPI_FORMAT_TI: begin                            
                            //  Add the R/W flag to the address byte and continue to writing it.
                            //  The 2nd MSB is set to 0 because in configuration memory that bit is used to store the R/W flag.
                            case (spi_bit_counter)
                                0: spi_bit_out <= ~spi_direction;   //  TI format is: Read high, write low
                                1: spi_bit_out <= 0;
                                default: spi_bit_out <= spi_addr[7 - spi_bit_counter];
                            endcase
                        end
                        default: begin
                             spi_bit_out <= spi_addr[7 - spi_bit_counter];
                        end
                    endcase
                    if (spi_bit_counter == 7) begin
                        spi_bit_counter <= 0;
                        spi_state <= SPI_DATA;
                    end
                end
                
                SPI_DATA: begin
                    if (spi_direction == 0) begin
                        //  Reading from register
                        spi_data_in[7 - spi_bit_counter] <= spi_bit_in;
                    end
                    else begin
                        //  Writing to register
                        spi_bit_out <= spi_data_out[7 - spi_bit_counter];
                    end
                    spi_bit_counter <= spi_bit_counter + 1;
                    if (spi_bit_counter == 7) begin
                        spi_bit_counter <= 0;
                        spi_state <= SPI_DONE;
                    end
                end
                
                SPI_DONE: begin
                    if (state == STATE_PROGRAMMING)
                        //  Take the cue from the main state machine if another transfer is ready.
                        spi_state <= SPI_START;
                    else begin
                        //  Wait for the main state machine to move on, then go idle.
                        spi_data_in <= 0;
                        spi_bit_counter <= 0;
                    end
                end
            endcase
        end
    end
    
endmodule

