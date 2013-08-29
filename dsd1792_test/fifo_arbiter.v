/*

    FIFO arbiter - uses external CellRAM to implement a vector of byte-wide FIFOs
    
*/

module fifo_arbiter(
    reset, clk_core,
    //  Connection to CellRAM interface
	cmd_bl, cmd_instr, cmd_addr, cmd_valid, cmd_ready, cmd_count, 
	wr_data, wr_valid, wr_ready, wr_count,
	rd_valid, rd_data, rd_ready, rd_count,
	//  Vector of FIFOs to arbitrate
	ports_rd_ready, ports_rd_valid, ports_rd_data,
	ports_wr_ready, ports_wr_valid, ports_wr_data
);

`include "parameters.v"

parameter num_ports = 4;
parameter Nbytes = Nb / 8;

input reset;
input clk_core;

output reg [Nb_bl-1:0] cmd_bl;
output reg [Nb_inst-1:0] cmd_instr;
output reg [Nb_addr-1:0] cmd_addr;
output reg cmd_valid;
input cmd_ready;
input [M_fc:0] cmd_count;

output [Nb-1:0] wr_data;
output wr_valid;
input wr_ready;
input [M_fw:0] wr_count;

input rd_valid;
input [Nb-1:0] rd_data;
output rd_ready;
input [M_fr:0] rd_count;

input [num_ports-1:0] ports_rd_ready;
output [num_ports-1:0] ports_rd_valid;
output [num_ports*8-1:0] ports_rd_data;

output [num_ports-1:0] ports_wr_ready;
input [num_ports-1:0] ports_wr_valid;
input [num_ports*8-1:0] ports_wr_data;



parameter   STATE_WAITING = 4'h0;
parameter   STATE_READ_INIT = 4'h1;
parameter   STATE_READ_CMD = 4'h2;
parameter	STATE_READ_DATA = 4'h3;
parameter	STATE_WRITE_INIT = 4'h4;
parameter	STATE_WRITE_CMD = 4'h5;
parameter   STATE_WRITE_DATA = 4'h6;

reg [3:0] state;

reg [M_fw:0] write_words_target;
reg [M_fw:0] write_words_count;

reg [M_fw:0] read_words_target;
reg [M_fw:0] read_words_count;




reg port_active;
reg [1:0] current_port_index;

reg allow_fifo_write;
reg allow_fifo_read;

wire current_port_rd_ready = wr_ready && allow_fifo_write;
wire current_port_rd_valid;
wire [Nb-1:0] current_port_rd_data;
wire [M_fr:0] current_port_rd_count;
wire current_port_wr_ready;
wire current_port_wr_valid = rd_valid;
wire [Nb-1:0] current_port_wr_data = rd_data;
wire [M_fw:0] current_port_wr_count;

wire [num_ports-1:0] ports_write_waiting;
wire [num_ports-1:0] ports_read_available;

assign wr_valid = current_port_rd_valid;
assign wr_data = current_port_rd_data;
assign rd_ready = current_port_wr_ready;

reg [Nb_addr-1:0] last_write_addr[num_ports-1:0];
reg [Nb_addr-1:0] last_read_addr[num_ports-1:0];

wire [Nb_addr-1:0] current_last_write_addr = last_write_addr[current_port_index];
wire [Nb_addr-1:0] current_last_read_addr = last_read_addr[current_port_index];

genvar g;
generate for (g = 0; g < num_ports; g = g + 1) begin: ports
    
    wire rd_fifo_rd_ready;
    wire rd_fifo_rd_valid;
    wire [Nb-1:0] rd_fifo_rd_data;
    
    wire rd_fifo_wr_ready;
    wire rd_fifo_wr_valid;
    wire [Nb-1:0] rd_fifo_wr_data;
    wire [4:0] rd_fifo_count;
    
    wire wr_fifo_rd_ready;
    wire wr_fifo_rd_valid;
    wire [Nb-1:0] wr_fifo_rd_data;
    
    wire wr_fifo_wr_ready;
    wire wr_fifo_wr_valid;
    wire [Nb-1:0] wr_fifo_wr_data;
    wire [4:0] wr_fifo_count;
    
    wire wr_fifo_rd_ready_last;
    delay wfrrl_delay(clk_core, reset, wr_fifo_rd_ready, wr_fifo_rd_ready_last);
    
    //  Map to selected active port
    assign current_port_rd_valid = (port_active && (current_port_index == g)) ? (wr_fifo_rd_valid && wr_fifo_rd_ready_last) : 1'bz;
    assign current_port_rd_data  = (port_active && (current_port_index == g)) ? wr_fifo_rd_data  : {Nb{1'bz}};
    assign current_port_wr_ready = (port_active && (current_port_index == g)) ? rd_fifo_wr_ready : 1'bz;
    
    assign current_port_wr_count = (port_active && (current_port_index == g)) ? wr_fifo_count : {(M_fw+1){1'bz}};
    assign current_port_rd_count = (port_active && (current_port_index == g)) ? rd_fifo_count : {(M_fr+1){1'bz}};
    
    assign wr_fifo_rd_ready = (port_active && (current_port_index == g)) ? (current_port_rd_ready && (state == STATE_WRITE_DATA) && ((write_words_count + 1 < write_words_target) || (write_words_count == 0))) : 1'b0;
    assign rd_fifo_wr_valid = (port_active && (current_port_index == g))? current_port_wr_valid : 1'b0;
    assign rd_fifo_wr_data  = (port_active && (current_port_index == g)) ? current_port_wr_data  : 0;

    assign ports_write_waiting[g] = (wr_fifo_count != 0);
    assign ports_read_available[g] = rd_fifo_wr_ready;

    //  Adapter
    fifo_byte_adapter #(.bytes_per_word(Nb / 8)) adapter(
        .clk_core(clk_core), 
        .reset(reset),
        .byte_wr_ready(ports_wr_ready[g]),
        .byte_wr_valid(ports_wr_valid[g]),
        .byte_wr_data(ports_wr_data[(g+1)*8-1:g*8]),
        .byte_rd_ready(ports_rd_ready[g]),
        .byte_rd_valid(ports_rd_valid[g]),
        .byte_rd_data(ports_rd_data[(g+1)*8-1:g*8]),
        .word_wr_ready(wr_fifo_wr_ready), 
        .word_wr_valid(wr_fifo_wr_valid), 
        .word_wr_data(wr_fifo_wr_data),
        .word_rd_ready(rd_fifo_rd_ready), 
        .word_rd_valid(rd_fifo_rd_valid), 
        .word_rd_data(rd_fifo_rd_data)
    );
    
    //  Read FIFO
    fifo_sync #(.Nb(Nb), .M(4)) rd_fifo(
    	.clk(clk_core), 
    	.reset(reset),
    	.wr_valid(rd_fifo_wr_valid), 
    	.wr_data(rd_fifo_wr_data),
    	.wr_ready(rd_fifo_wr_ready),
    	.rd_ready(rd_fifo_rd_ready),
    	.rd_valid(rd_fifo_rd_valid), 
    	.rd_data(rd_fifo_rd_data),
    	.count(rd_fifo_count)
    );

    //  Write FIFO
    fifo_sync #(.Nb(Nb), .M(4)) wr_fifo(
    	.clk(clk_core), 
    	.reset(reset),
    	.wr_valid(wr_fifo_wr_valid), 
    	.wr_data(wr_fifo_wr_data),
    	.wr_ready(wr_fifo_wr_ready),
    	.rd_ready(wr_fifo_rd_ready),
    	.rd_valid(wr_fifo_rd_valid), 
    	.rd_data(wr_fifo_rd_data),
    	.count(wr_fifo_count)
    );
end
endgenerate


integer i;

always @(posedge clk_core) begin
    if (reset) begin
        for (i = 0; i < num_ports; i = i + 1) begin
            last_write_addr[i] <= 0;
            last_read_addr[i] <= 0;
        end
        
        write_words_target <= 0;
        write_words_count <= 0;
        read_words_target <= 0;
        read_words_count <= 0;        
        
        allow_fifo_write <= 0;
        allow_fifo_read <= 0;
        
        port_active <= 0;
        current_port_index <= 0;
        
        cmd_valid <= 0;
        cmd_bl <= 0;
        cmd_instr <= 0;
        cmd_addr <= 0;
        
        state <= 0;
    end
    else begin
        cmd_valid <= 0;

        case (state)
        STATE_WAITING: begin
            //  Identify next port needing attention
            current_port_index <= current_port_index + 1;
            //	Begin a read when the address is mismatched and there is space in the FIFO
            if (ports_read_available[current_port_index + 1] && (last_read_addr[current_port_index + 1] != last_write_addr[current_port_index + 1])) begin
                port_active <= 1;
                state <= STATE_READ_INIT;
            end
            //  Begin a write when there is data waiting
            else if (ports_write_waiting[current_port_index + 1]) begin
                port_active <= 1;
                state <= STATE_WRITE_INIT;
            end
        end
        STATE_READ_INIT: begin
            //  Count the number of words we are going to read
            if (current_last_write_addr - current_last_read_addr > ((1 << M_fr) - current_port_rd_count))
                read_words_target <= (1 << M_fr) - current_port_rd_count;
            else
                read_words_target <= current_last_write_addr - current_last_read_addr;
            read_words_count <= 0;
            state <= STATE_READ_CMD;
        end
        STATE_READ_CMD: begin
            if (cmd_ready) begin
                //  Submit command for read
                cmd_bl <= read_words_target - 1;
                cmd_addr <= current_last_read_addr + (current_port_index << (Nb_addr - 2));
                cmd_instr <= INSTR_READ;
                cmd_valid <= 1;
                allow_fifo_read <= 1;
                state <= STATE_READ_DATA;
            end
        end
        STATE_READ_DATA: begin
            //  Watch data go by and stop when we have target number of words
            if (current_port_wr_valid) begin
                read_words_count <= read_words_count + 1;
                if (read_words_count == read_words_target - 1) begin
                    last_read_addr[current_port_index] <= current_last_read_addr + read_words_target;
                    allow_fifo_read <= 0;
                    state <= STATE_WAITING;
                end
            end
        end
        STATE_WRITE_INIT: begin
            //  Count the number of words we are going to write
            write_words_target <= current_port_wr_count;
            write_words_count <= 0;
            allow_fifo_write <= 1;
            state <= STATE_WRITE_DATA;
        end
        STATE_WRITE_DATA: begin
            //  Watch data go by and stop when we have target number of words
            if (current_port_rd_valid) begin
                write_words_count <= write_words_count + 1;
                if (write_words_count == write_words_target - 1) begin
                    allow_fifo_write <= 0;
                    state <= STATE_WRITE_CMD;
                end
            end
        end
        STATE_WRITE_CMD: begin
            if (cmd_ready) begin
                //  Submit command for write
                cmd_bl <= write_words_target - 1;
                cmd_addr <= current_last_write_addr + (current_port_index << (Nb_addr - 2));
                cmd_instr <= INSTR_WRITE;
                cmd_valid <= 1;
                last_write_addr[current_port_index] <= current_last_write_addr + write_words_target;
                state <= STATE_WAITING;
            end
        end
        endcase
    end
end


endmodule
