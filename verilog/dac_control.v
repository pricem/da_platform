module dac_control(
    clk_in, clk_fx2, reset,

    //  Interface to FPGALink
    chanAddr, h2fData, h2fValid, h2fReady, f2hData, f2hValid, f2hReady,

    //  Interface to DAC
    dac_sclk, dac_dina, dac_dinb, dac_sync
);

parameter M = 6;

input clk_in;
input reset;
input clk_fx2;

input [6:0] chanAddr;

input [7:0] h2fData;
input h2fValid;
output h2fReady;

output [7:0] f2hData;
output f2hValid;
input f2hReady;

output dac_sclk;
output dac_dina;
output dac_dinb;
output dac_sync;


//  Reduce clock by factor of 4 - 12.5 MHz SPI clock
wire clk_core;
clk_divider clkdiv(reset, clk_in, clk_core);
defparam clkdiv.ratio = 4;

//  Hold reset_core high after reset until clk_core pulses high
reg reset_core;
always @(posedge clk_in) begin
    if (reset) begin
        reset_core <= 1;
    end
    else begin
        if (clk_core == 1)
            reset_core <= 0;
    end

end

//  FIFOs for clock domain conversion

wire [M:0] read_fifo_wr_count;

wire read_fifo_rd_valid;
wire [7:0] read_fifo_rd_data;
reg read_fifo_rd_ready;
wire [M:0] read_fifo_rd_count;

fifo_async read_fifo(
	.reset(reset_core),
	.wr_clk(clk_fx2), 
	.wr_valid(h2fValid), 
	.wr_data(h2fData),
	.wr_ready(h2fReady), 
	.wr_count(read_fifo_wr_count),
	.rd_clk(clk_core), 
	.rd_valid(read_fifo_rd_valid),
	.rd_ready(read_fifo_rd_ready), 
	.rd_data(read_fifo_rd_data), 
	.rd_count(read_fifo_rd_count)
);
defparam read_fifo.Nb = 8;
defparam read_fifo.M = M;

//  No write FIFO since there's no output data.
assign f2hData = 0;
assign f2hValid = 0;

//  DAC interface

reg write_to_dac;
reg [11:0] data_left;
reg [11:0] data_right;

dac_interface dacint(
    .clk(clk_core),
    .reset(reset_core),
    .data_en(write_to_dac),
    .data_left(data_left),
    .data_right(data_right),
    .dac_sclk(dac_sclk), 
    .dac_sync(dac_sync), 
    .dac_dina(dac_dina), 
    .dac_dinb(dac_dinb)
);

reg [3:0] byte_count;

reg [15:0] cycles_since_write = 0;
parameter target_cycles = 283;
parameter write_latency = 6;

reg ready_last;

//  Sequential logic

always @(posedge clk_core) begin
    if (reset_core) begin
        read_fifo_rd_ready <= 0;
        
        write_to_dac <= 0;
        data_left <= 0;
        data_right <= 0;
        
        byte_count <= 0;
        
        cycles_since_write <= 0;
        
        ready_last <= 0;
    end
    else begin
        ready_last <= read_fifo_rd_ready;
        write_to_dac <= 0;
        
        if ((cycles_since_write + write_latency >= target_cycles) && (byte_count < 2))
            read_fifo_rd_ready <= 1;
        else
            read_fifo_rd_ready <= 0;
        
        if (write_to_dac)
            cycles_since_write <= 0;
        else
            cycles_since_write <= cycles_since_write + 1;
        
        if (read_fifo_rd_valid && ready_last) begin
            byte_count <= byte_count + 1;
            case (byte_count)
            0: data_left[7:0] <= read_fifo_rd_data;
            1: data_left[11:8] <= read_fifo_rd_data[3:0];
            2: data_right[7:0] <= read_fifo_rd_data;
            3: data_right[11:8] <= read_fifo_rd_data[3:0];
            endcase
            if (byte_count == 3) begin
                write_to_dac <= 1;
                byte_count <= 0;
            end
        end

    end
end


endmodule

