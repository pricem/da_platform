module da_platform(
    //  Connections on Nexys2 board
    clk_nexys, clk_fx2, reset,

    //  Interface to FPGALink
    chanAddr, h2fData, h2fValid, h2fReady, f2hData, f2hValid, f2hReady,

    //  Interface to isolator board
    slotdata,
    mclk, amcs, amdi, amdo, dmcs, dmdi, dmdo, dirchan, acon, aovf, clk0, reset_out, srclk, clksel, clk1
);

parameter M = 6;

`include "commands.v"

//  Connections on Nexys2 board
input clk_nexys;
input clk_fx2;
input reset;

//  Interface to FPGALink
input [6:0] chanAddr;

input [7:0] h2fData;
input h2fValid;
output h2fReady;

output [7:0] f2hData;
output f2hValid;
input f2hReady;

//  Interface to isolator board
inout [23:0] slotdata;

output mclk;                //  Clock signal for SPI ports and (serial) shift registers

output amcs;                //  Chip select for ADCs (serialized)
output amdi;                //  MOSI for ADCs SPI port
input amdo;                 //  MISO for ADCs SPI port

output dmcs;                //  Chip select for DACs (serialized)
output dmdi;                //  MOSI for DACs SPI port
input dmdo;                 //  MISO for DACs SPI port

input dirchan;              //  Conversion direction and number of channels (serialized)
output [1:0] acon;          //  Hardware configuration data for ADCs (serialized)
input aovf;                 //  Overflow flags for ADCs (serialized)
input clk0;                 //  11.2896 MHz clock from low jitter oscillator
output reset_out;           //  Reset signal to DAC/ADC boards (active low)
output srclk;               //  Clock for (parallel) shift registers
output clksel;              //  Selector between clocks for each DAC/ADC board (serialized)
input clk1;                 //  24.576 MHz clock from low jitter oscillator


//  Keep everything out of reset for now
assign reset_out = !reset;

//  Clock assignment
wire clk_core = clk_nexys;
wire reset_core = reset;

clk_divider mclkdiv(reset, clk_core, mclk);
defparam mclkdiv.ratio = 8;

wire mclk_last;
delay mclk_delay(clk_core, reset, mclk, mclk_last);

reg reset_mclk;
always @(posedge clk_core) begin
    if (reset)
        reset_mclk <= 1;
    else if (!mclk && mclk_last)
        reset_mclk <= 0;
end
/*
clk_divider srclkdiv(reset_mclk, mclk, srclk_predelay);
defparam srclkdiv.ratio = 9;
defparam srclkdiv.threshold = 1;
*/
clk_divider srclkdiv(reset, clk_core, srclk_predelay);
defparam srclkdiv.ratio = 64;
defparam srclkdiv.threshold = 4;

assign srclk = !srclk_predelay;

reg [3:0] clk_inhibit;
reg [3:0] reset_slots;

wire clk0_last;
delay clk0_delay(clk_core, reset, clk0, clk0_last);
wire clk1_last;
delay clk1_delay(clk_core, reset, clk1, clk1_last);

//  Parallel versions of serialized signals

wire [7:0] aovf_parallel;
wire [7:0] dirchan_parallel;
wire [7:0] dmcs_parallel;
wire [7:0] amcs_parallel;
reg [7:0] clksel_parallel;

wire [7:0] acon0_parallel;
wire [7:0] acon1_parallel;

deserializer dirchan_des(mclk, dirchan, srclk, dirchan_parallel);
deserializer aovf_des(mclk, aovf, srclk, aovf_parallel);

serializer amcs_ser(mclk, amcs, srclk, amcs_parallel);
serializer dmcs_ser(mclk, dmcs, srclk, dmcs_parallel);
serializer clksel_ser(mclk, clksel, srclk, clksel_parallel);
serializer acon0_ser(mclk, acon[0], srclk, acon0_parallel);
serializer acon1_ser(mclk, acon[1], srclk, acon1_parallel);


wire ctl_rd_valid;
wire [7:0] ctl_rd_data;
wire ctl_rd_ready;

wire ctl_wr_valid;
wire [7:0] ctl_wr_data;
reg ctl_wr_ready;

wire aud_rd_valid;
wire [7:0] aud_rd_data;
wire aud_rd_ready;

wire aud_wr_valid;
wire [7:0] aud_wr_data;
reg aud_wr_ready;

wire read_fifo_read_ok = aud_rd_ready && ctl_rd_ready;

//  FIFOs for clock domain conversion (FX2 -> Nexys2)

wire [M:0] read_fifo_wr_count;
wire [M:0] read_fifo_rd_count;

wire read_fifo_rd_valid;
wire [7:0] read_fifo_rd_data;

reg read_fifo_rd_ready_int;
wire read_fifo_rd_ready = read_fifo_rd_ready_int && read_fifo_read_ok;

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

wire [M:0] write_fifo_wr_count;
wire [M:0] write_fifo_rd_count;

reg write_fifo_wr_valid;
reg [7:0] write_fifo_wr_data;
wire write_fifo_wr_ready;

fifo_async write_fifo(
	.reset(reset_core),
	.wr_clk(clk_core), 
	.wr_valid(write_fifo_wr_valid), 
	.wr_data(write_fifo_wr_data),
	.wr_ready(write_fifo_wr_ready), 
	.wr_count(write_fifo_wr_count),
	.rd_clk(clk_fx2), 
	.rd_valid(f2hValid),
	.rd_ready(f2hReady), 
	.rd_data(f2hData), 
	.rd_count(write_fifo_rd_count)
);
defparam write_fifo.Nb = 8;
defparam write_fifo.M = M;


reg [7:0] slot_index;


parameter STATE_IDLE = 4'h0;
parameter STATE_HANDLE_READ = 4'h1;
parameter STATE_HANDLE_WRITE = 4'h2;

reg [23:0] byte_counter;
reg [23:0] fifo_read_length;
reg [23:0] fifo_write_length;
reg [15:0] data_checksum_calculated;
reg [15:0] data_checksum_received;
reg [7:0] current_cmd;
reg [7:0] current_report;
reg [7:0] report_slot_index;
reg read_pending;
reg [3:0] state;

reg [7:0] report_data_waiting;


reg cmd_stall;
reg [7:0] cmd_data_waiting;

//  Monitor AMCS and DMCS to estimate what the values are on the board
wire [7:0] amcs_parallel_est;
wire [7:0] dmcs_parallel_est;
deserializer amcs_des(mclk, amcs, srclk, amcs_parallel_est);
deserializer dmcs_des(mclk, dmcs, srclk, dmcs_parallel_est);

//  Things which are replicated for each slot

assign amcs_parallel[7:4] = 4'b1111;
assign dmcs_parallel[7:4] = 4'b1111;

//  Mask FIFO signals when no slot is activated
assign ctl_wr_valid = (slot_index < 4) ? 1'bz : 1'b0;
assign aud_wr_valid = (slot_index < 4) ? 1'bz : 1'b0;

assign ctl_rd_ready = (slot_index < 4) ? 1'bz : 1'b1;
assign aud_rd_ready = (slot_index < 4) ? 1'bz : 1'b1;

assign aud_rd_valid = read_fifo_rd_valid && (state == STATE_HANDLE_READ) && (current_cmd == AUD_FIFO_WRITE) && (byte_counter >= 4) && (byte_counter < fifo_read_length + 4);
assign aud_rd_data = read_fifo_rd_data;

assign ctl_rd_valid = read_fifo_rd_valid && (state == STATE_HANDLE_READ) && (current_cmd == CMD_FIFO_WRITE) && (byte_counter >= 4) && (byte_counter < fifo_read_length + 4);
assign ctl_rd_data = read_fifo_rd_data;

genvar g;
generate for (g = 0; g < 4; g = g + 1) begin: slots

    //  Muxing
    wire slot_ctl_rd_valid = (slot_index == g) ? ctl_rd_valid : 0;
    wire [7:0] slot_ctl_rd_data = (slot_index == g) ? ctl_rd_data : 0;
    wire slot_ctl_rd_ready;
    assign ctl_rd_ready = (slot_index == g) ? slot_ctl_rd_ready : 1'bz;
    
    wire slot_ctl_wr_valid;
    assign ctl_wr_valid = (slot_index == g) ? slot_ctl_wr_valid : 1'bz;
    wire [7:0] slot_ctl_wr_data;
    assign ctl_wr_data = (slot_index == g) ? slot_ctl_wr_data : 8'bzzzzzzzz;
    wire slot_ctl_wr_ready = (slot_index == g) ? ctl_wr_ready : 0;
    
    wire slot_aud_rd_valid = (slot_index == g) ? aud_rd_valid : 0;
    wire [7:0] slot_aud_rd_data = (slot_index == g) ? aud_rd_data : 0;
    wire slot_aud_rd_ready;
    assign aud_rd_ready = (slot_index == g) ? slot_aud_rd_ready : 1'bz;
    
    wire slot_aud_wr_valid;
    assign aud_wr_valid = (slot_index == g) ? slot_aud_wr_valid : 1'bz;
    wire [7:0] slot_aud_wr_data;
    assign aud_wr_data = (slot_index == g) ? slot_aud_wr_data : 8'bzzzzzzzz;
    wire slot_aud_wr_ready = (slot_index == g) ? aud_wr_ready : 0;
    
    wire slot_clk = (!clk_inhibit[g]) && (clksel_parallel[g] ? clk1 : clk0);

    wire slot_dir = dirchan_parallel[g];
    wire slot_chan = dirchan_parallel[g+4];
    wire [1:0] slot_aovf = aovf_parallel[(g+1)*2-1:g*2];
    
    wire [7:0] slot_acon;
    assign acon0_parallel = ((slot_dir == 0) && (g == 0)) ? slot_acon : 8'bzzzzzzzz;
    assign acon1_parallel = ((slot_dir == 0) && (g == 2)) ? slot_acon : 8'bzzzzzzzz;

    wire slot_spi_ss_out;
    assign amcs_parallel[g] = !((slot_dir == 0) && (slot_spi_ss_out == 0));
    assign dmcs_parallel[g] = !((slot_dir == 1) && (slot_spi_ss_out == 0));
    wire slot_spi_ss_in = slot_dir ? dmcs_parallel_est[g] : amcs_parallel_est[g];
    wire slot_spi_sck;
    wire slot_spi_mosi;
    assign amdi = ((slot_dir == 0) && (slot_spi_ss_in == 0)) ? slot_spi_mosi : 1'bz;
    assign dmdi = ((slot_dir == 1) && (slot_spi_ss_in == 0)) ? slot_spi_mosi : 1'bz;
    wire slot_spi_miso = slot_dir ? dmdo : amdo;

    //  FIFOs - control and audio, read and write
    
    wire int_ctl_rd_valid;
    wire [7:0] int_ctl_rd_data;
    wire int_ctl_rd_ready;
    wire int_ctl_wr_valid;
    wire [7:0] int_ctl_wr_data;
    wire int_ctl_wr_ready;
    wire int_aud_rd_valid;
    wire [7:0] int_aud_rd_data;
    wire int_aud_rd_ready;
    wire int_aud_wr_valid;
    wire [7:0] int_aud_wr_data;
    wire int_aud_wr_ready;
    
    wire [2:0] ctl_rd_fifo_count;
    fifo_sync #(.Nb(8), .M(2)) ctl_rd_fifo(
    	.clk(clk_core), 
    	.reset(reset_core),
    	.wr_valid(slot_ctl_rd_valid), 
    	.wr_data(slot_ctl_rd_data),
    	.wr_ready(slot_ctl_rd_ready),
    	.rd_ready(int_ctl_rd_ready),
    	.rd_valid(int_ctl_rd_valid), 
    	.rd_data(int_ctl_rd_data),
    	.count(ctl_rd_fifo_count)
    );
    
    wire [2:0] ctl_wr_fifo_count;
    fifo_sync #(.Nb(8), .M(2)) ctl_wr_fifo(
    	.clk(clk_core), 
    	.reset(reset_core),
    	.wr_valid(int_ctl_wr_valid), 
    	.wr_data(int_ctl_wr_data),
    	.wr_ready(int_ctl_wr_ready),
    	.rd_ready(slot_ctl_wr_ready),
    	.rd_valid(slot_ctl_wr_valid), 
    	.rd_data(slot_ctl_wr_data),
    	.count(ctl_wr_fifo_count)
    );
    
    wire [4:0] aud_rd_fifo_count;
    fifo_sync #(.Nb(8), .M(4)) aud_rd_fifo(
    	.clk(clk_core), 
    	.reset(reset_core),
    	.wr_valid(slot_aud_rd_valid), 
    	.wr_data(slot_aud_rd_data),
    	.wr_ready(slot_aud_rd_ready),
    	.rd_ready(int_aud_rd_ready),
    	.rd_valid(int_aud_rd_valid), 
    	.rd_data(int_aud_rd_data),
    	.count(aud_rd_fifo_count)
    );
    
    wire [4:0] aud_wr_fifo_count;
    fifo_sync #(.Nb(8), .M(4)) aud_wr_fifo(
    	.clk(clk_core), 
    	.reset(reset_core),
    	.wr_valid(int_aud_wr_valid), 
    	.wr_data(int_aud_wr_data),
    	.wr_ready(int_aud_wr_ready),
    	.rd_ready(slot_aud_wr_ready),
    	.rd_valid(slot_aud_wr_valid), 
    	.rd_data(slot_aud_wr_data),
    	.count(aud_wr_fifo_count)
    );

    //  Slot controllers
    slot_controller ctl(
        .clk_core(clk_core), 
        .reset(reset_slots[g]),
        .ctl_rd_valid(int_ctl_rd_valid), 
        .ctl_rd_data(int_ctl_rd_data), 
        .ctl_rd_ready(int_ctl_rd_ready),
        .ctl_wr_valid(int_ctl_wr_valid), 
        .ctl_wr_data(int_ctl_wr_data), 
        .ctl_wr_ready(int_ctl_wr_ready),
        .aud_rd_valid(int_aud_rd_valid), 
        .aud_rd_data(int_aud_rd_data), 
        .aud_rd_ready(int_aud_rd_ready),
        .aud_wr_valid(int_aud_wr_valid), 
        .aud_wr_data(int_aud_wr_data), 
        .aud_wr_ready(int_aud_wr_ready),
        .spi_ss_out(slot_spi_ss_out), 
        .spi_ss_in(slot_spi_ss_in),
        .spi_sck(slot_spi_sck), 
        .spi_mosi(slot_spi_mosi), 
        .spi_miso(slot_spi_miso),
        .slot_data(slotdata[(g+1)*6-1:g*6]), 
        .slot_clk(slot_clk), 
        .mclk(mclk), 
        .dir(slot_dir), 
        .chan(slot_chan), 
        .acon(slot_acon), 
        .aovf(slot_aovf)
    );

end
endgenerate

//  Temporary echo FIFO
reg echo_wr_valid;
reg [7:0] echo_wr_data;
wire echo_wr_ready;
reg echo_rd_ready;
wire echo_rd_valid;
wire [7:0] echo_rd_data;
wire [4:0] echo_fifo_count;
fifo_sync #(.Nb(8), .M(4)) echo_fifo(
	.clk(clk_core), 
	.reset(reset_core),
	.wr_valid(echo_wr_valid), 
	.wr_data(echo_wr_data),
	.wr_ready(echo_wr_ready),
	.rd_ready(echo_rd_ready),
	.rd_valid(echo_rd_valid), 
	.rd_data(echo_rd_data),
	.count(echo_fifo_count)
);
reg [3:0] echo_count;

//  Sequential logic
integer i;

always @(posedge clk_core) begin
    if (reset_core) begin
        read_fifo_rd_ready_int <= 0;
        write_fifo_wr_valid <= 0;
        write_fifo_wr_data <= 0;
        
        slot_index <= 0;
        report_slot_index <= 0;
        
        ctl_wr_ready <= 0;
        aud_wr_ready <= 0;

        clksel_parallel <= 0;
        clk_inhibit <= 0;
        reset_slots <= 4'hF;
        
        byte_counter <= 0;
        fifo_read_length <= 0;
        fifo_write_length <= 0;
        data_checksum_calculated <= 0;
        data_checksum_received <= 0;
        current_cmd <= 0;
        current_report <= 0;
        read_pending <= 0;
        state <= STATE_IDLE;
        
        report_data_waiting <= 0;

        echo_wr_valid <= 0;
        echo_wr_data <= 0;
        echo_rd_ready <= 0;
        echo_count <= 0;

        cmd_stall <= 0;
        cmd_data_waiting <= 0;

    end
    else begin
        read_fifo_rd_ready_int <= 0;
        write_fifo_wr_valid <= 0;
        aud_wr_ready <= 0;
        ctl_wr_ready <= 0;
        echo_wr_valid <= 0;
        echo_rd_ready <= 0;
        clk_inhibit <= 0;

        for (i = 0; i < 4; i = i + 1) begin
            if (reset_slots[i] && !clk_inhibit[i] && !reset_mclk) begin
                //  Wait for clock pulse of selected clock before disabling reset for that slot
                if (clksel_parallel[i] == 1'b1) begin
                    if (clk1 && !clk1_last) begin
                        reset_slots[i] <= 0;
                    end
                end
                else begin
                    if (clk0 && !clk0_last) begin
                        reset_slots[i] <= 0;
                    end
                end
            end
        end

        case (state)
        STATE_IDLE: begin
            
            read_fifo_rd_ready_int <= 1;
            if (read_pending) begin
                byte_counter <= 0;
                state <= STATE_HANDLE_READ;
                read_pending <= 0;
            end
            else begin
                if (read_fifo_rd_valid) begin
                    slot_index <= read_fifo_rd_data;
                    byte_counter <= 0;
                    state <= STATE_HANDLE_READ;
                end
                else begin
                    ctl_wr_ready <= 1;
                    aud_wr_ready <= 1;
                    
                    if (ctl_wr_valid) begin
                        ctl_wr_ready <= 0;
                        report_slot_index <= slot_index;
                        byte_counter <= 0;
                        report_data_waiting <= ctl_wr_data;
                        current_report <= CMD_FIFO_REPORT;
                        state <= STATE_HANDLE_WRITE;
                    end
                    
                end
            end
        end
        STATE_HANDLE_READ: begin
            /*
                This state is entered after the target slot has been read and stored
                in slot_index.
                - Byte counter = 0: command index
                - Byte counter = 1 to N - 1: command-specific data
            */
            read_fifo_rd_ready_int <= 1;
            if (read_fifo_rd_valid && read_fifo_rd_ready) begin
                byte_counter <= byte_counter + 1;
                if (byte_counter == 0) begin
                    current_cmd <= read_fifo_rd_data;
                    data_checksum_calculated <= 0;
                    data_checksum_received <= 0;
                    case (read_fifo_rd_data)
                    DIRCHAN_READ: begin
                        byte_counter <= 0;
                        report_slot_index <= GLOBAL_TARGET_INDEX;
                        current_report <= DIRCHAN_REPORT;
                        state <= STATE_HANDLE_WRITE;
                    end
                    AOVF_READ: begin
                        byte_counter <= 0;
                        report_slot_index <= GLOBAL_TARGET_INDEX;
                        current_report <= AOVF_REPORT;
                        state <= STATE_HANDLE_WRITE;
                    end
                    
                    endcase
                end
                else case (current_cmd)
                AUD_FIFO_WRITE, CMD_FIFO_WRITE: begin
                    if (byte_counter == 1)
                        fifo_read_length[23:16] <= read_fifo_rd_data;
                    else if (byte_counter == 2)
                        fifo_read_length[15:8] <= read_fifo_rd_data;
                    else if (byte_counter == 3)
                        fifo_read_length[7:0] <= read_fifo_rd_data;
                    else if (byte_counter == fifo_read_length + 4)
                        data_checksum_received[15:8] <= read_fifo_rd_data;
                    else if (byte_counter == fifo_read_length + 5) begin
                        data_checksum_received[7:0] <= read_fifo_rd_data;
                        //  Compare checksums
                        if ({data_checksum_received[15:8], read_fifo_rd_data} != data_checksum_calculated) begin
                            byte_counter <= 0;
                            report_slot_index <= slot_index;
                            current_report <= CHECKSUM_ERROR;
                            state <= STATE_HANDLE_WRITE;
                        end
                        else
                            state <= STATE_IDLE;
                    end
                    else begin
                        //  Data is written to target FIFO via combinational logic
                        data_checksum_calculated <= data_checksum_calculated + read_fifo_rd_data;
                    end
                end

                ECHO_SEND: begin
                    if (byte_counter == 1) begin
                        echo_count <= read_fifo_rd_data;
                    end
                    else begin
                        echo_wr_valid <= 1;
                        echo_wr_data <= read_fifo_rd_data;
                        if (byte_counter == echo_count + 1) begin
                            byte_counter <= 0;
                            report_slot_index <= slot_index;
                            current_report <= ECHO_REPORT;
                            state <= STATE_HANDLE_WRITE;
                        end
                    end
                end

                SELECT_CLOCK: begin
                    //  For each slot that is being switched over, stop the clock and reset it.
                    clk_inhibit <= (clksel_parallel ^ read_fifo_rd_data);
                    reset_slots <= (clksel_parallel ^ read_fifo_rd_data);
                    clksel_parallel <= read_fifo_rd_data;
                    state <= STATE_IDLE;
                end
                
                endcase
                
            end
        end
        STATE_HANDLE_WRITE: begin
            if (read_fifo_rd_ready_int && read_fifo_rd_valid) begin
                read_pending <= 1;
                slot_index <= read_fifo_rd_data;
            end
            else if (write_fifo_wr_ready) begin

                byte_counter <= byte_counter + 1;
                write_fifo_wr_valid <= 1;
                
                if (byte_counter == 0)
                    write_fifo_wr_data <= report_slot_index;
                else if (byte_counter == 1)
                    write_fifo_wr_data <= current_report;   
                else case (current_report)
                AUD_FIFO_REPORT: begin
                
                end
                CMD_FIFO_REPORT: begin
                    if (byte_counter > 2) begin
                        ctl_wr_ready <= 1;
                        if (ctl_wr_valid && ctl_wr_ready)
                            write_fifo_wr_data <= ctl_wr_data;
                        else begin
                            byte_counter <= byte_counter;
                            write_fifo_wr_valid <= 0;
                            if (ctl_wr_ready)
                                state <= STATE_IDLE;
                        end
                    end
                    else begin
                        write_fifo_wr_data <= report_data_waiting;
                    end
                end
                DIRCHAN_REPORT: begin
                	write_fifo_wr_data <= dirchan_parallel;
                	state <= STATE_IDLE;
                end
                AOVF_REPORT: begin
                    write_fifo_wr_data <= aovf_parallel;
                	state <= STATE_IDLE;
                end
                ECHO_REPORT: begin
                    if (byte_counter == 2) begin
                        write_fifo_wr_data <= echo_count;
                    end
                    else begin
                        echo_rd_ready <= 1;
                        if (echo_rd_valid) begin
                            write_fifo_wr_data <= echo_rd_data;
                        end
                        else begin
                            byte_counter <= byte_counter;
                            write_fifo_wr_valid <= 0;
                        end
                        if (byte_counter == 2 + echo_count)
                            state <= STATE_IDLE;
                    end
                end
                CHECKSUM_ERROR: begin
                    case (byte_counter)
                    2: write_fifo_wr_data <= data_checksum_received[15:8];
                    3: write_fifo_wr_data <= data_checksum_received[7:0];
                    4: write_fifo_wr_data <= data_checksum_calculated[15:8];
                    5: write_fifo_wr_data <= data_checksum_calculated[7:0];
                    endcase
                    if (byte_counter == 5)
                        state <= STATE_IDLE;
                end
                endcase

            end
        end
        endcase
    end
end

endmodule

