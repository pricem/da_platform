//  A dummy module for a nonexistent 16-bit stereo DAC.

module dummy_dac(
    //  Register programming
    config_clk, config_write, config_read, config_addr, config_data,
    //  FIFO connection
    fifo_clk, fifo_data, fifo_read, fifo_addr_in, fifo_addr_out,
    //  Other internal connections
    custom_clk0, custom_clk1, write_fifo_byte_count, read_fifo_byte_count,
    //  FX2 data port
    slot_data, direction, channels,
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
    
    input custom_clk0;
    input custom_clk1;
    input [31:0] write_fifo_byte_count;
    input [31:0] read_fifo_byte_count;
    
    output [5:0] slot_data;
    input direction;
    input channels;
    
    input clk;
    input reset;
       
    integer i;
    genvar g;
    
    //  Include configuration registers
    wire [31:0] registers;
    wire [7:0] config_w [3:0];
    generate for (g = 0; g < 4; g = g + 1) begin:config_wires
            assign config_w[g] = registers[((g + 1) * 8 - 1):(g * 8)];
        end
    endgenerate
    ioreg config_reg(config_clk, config_write, config_read, config_addr, config_data, registers, clk, reset);
    
    //  100 MHz input clk / 256 = 400 kHz
    reg [5:0] data_out;
    reg [7:0] clk_counter;
    reg [1:0] msg_counter;
    wire [1:0] msg_counter_delayed;
    reg sample_clk;
    reg sample_bit_clk;
    reg sample_clk_last;

    //  Wires to monitor output
    wire data = data_out[0];
    wire lrck = data_out[1];
    wire bck = data_out[2];

    //  Audio samples
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
    
    //  Run FIFO at full speed (could be changed for lower power consumption)
    assign fifo_clk = clk;
    
    //  Tristate outputs
    assign slot_data = (direction == 0) ? data_out : 6'hZZ;
    
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

    always @(posedge clk) begin
        if (reset) begin
            clk_counter <= 0;
            msg_counter <= 0;
            sample_clk_last <= 0;
            sample_bit_clk <= 0;
            sample <= 0;
            
            //  Cycle FIFO clock at reset
            if (reset_last)
                sample_clk <= 0;
            else
                sample_clk <= 1;
            data_out <= 0;
            reset_last <= 1;
        end
        else begin
            reset_last <= 0;
        
            clk_counter <= clk_counter + 1;
            
            //  Trigger the FIFO clock once in a while
            if (clk_counter == 127)
                sample_clk <= sample_clk + 1;
            if (clk_counter % 8 == 7)
                sample_bit_clk <= sample_bit_clk + 1;
            
            //  Left/right data
            data_out[0] <= sample[(clk_counter / 16)];
            //  LRCK
            data_out[1] <= sample_clk;
            //  BCK
            data_out[2] <= sample_bit_clk;
            
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

