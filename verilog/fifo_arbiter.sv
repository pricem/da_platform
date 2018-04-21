/*
    FIFO arbiter - uses external DDR SDRAM to implement a vector of byte-wide FIFOs
    SV port (8/3/2016)
    Async FIFOs are included here since this is the endpoint of the memory related interfaces.
    For now, fixed 32 bit sample width.  (Internally, FIFOs are serialized to match memory interface width.)
*/

`timescale 1ns / 1ps

module fifo_arbiter #(
    num_ports = 4,
    mem_width = 32
) (
    input reset,
    input clk_core,
    
    /*
    //  Vector of FIFOs to arbitrate
    //  TODO: Back off to unbundled syntax if simulation/synthesis don't support it.
    FIFOInterface.in ports_in[num_ports],
    FIFOInterface.out ports_out[num_ports],
    */
    //  TEMPORARY: Vector of individual FIFO signals since array of interfaces is broken.
    output logic ports_in_ready[num_ports],
    input logic ports_in_enable[num_ports],
    input logic [mem_width - 1 : 0] ports_in_data[num_ports],
    input logic ports_out_ready[num_ports],
    output logic ports_out_enable[num_ports],
    output logic [mem_width - 1 : 0] ports_out_data[num_ports],
    
    //  Memory interface
    input clk_mem,
    FIFOInterface.out mem_cmd,
    FIFOInterface.out mem_write,
    FIFOInterface.in mem_read,
    
    //  Monitoring
    output logic [31:0] write_counters[num_ports],
    output logic [31:0] read_counters[num_ports]
);

`include "structures.sv"

localparam   STATE_WAITING = 4'h0;
localparam   STATE_READ_INIT = 4'h1;
localparam   STATE_READ_CMD = 4'h2;
localparam	STATE_READ_DATA = 4'h3;
localparam	STATE_WRITE_INIT = 4'h4;
localparam	STATE_WRITE_CMD = 4'h5;
localparam   STATE_WRITE_DATA = 4'h6;

//  How many words (samples) are allocated to FIFO storage for each port?
//  ZTEX module 2.13 has 256 MB of memory; with 8 ports, that's 32 MB (8M samples) per port.
//  But for simulation/testing we can use less.
localparam region_log_depth = 23;
//  Counters are restricted to twice the region depth.
//  This allows us to distinguish between full and empty.
localparam counter_mask = (1 << (region_log_depth + 1)) - 1;

//  Log depth of FIFOs (write, read).
localparam M_fw = 6;
localparam N_fw = (1 << M_fw);
localparam M_fr = 6;
localparam N_fr = (1 << M_fr);

logic [3:0] state;

logic [M_fw:0] write_words_target;
logic [M_fw:0] write_words_count;

logic [M_fw:0] read_words_target;
logic [M_fw:0] read_words_count;

logic port_in_active;
logic port_out_active;
logic [$clog2(num_ports) - 1 : 0] current_port_index;

logic [$clog2(num_ports) - 1 : 0] next_port_index;
always_comb begin
    if (current_port_index == num_ports - 1) 
        next_port_index = 0;
    else 
        next_port_index = current_port_index + 1;
end

logic [31:0] last_write_addr[num_ports - 1 : 0];
logic [31:0] last_read_addr[num_ports - 1 : 0];
always_comb begin
    for (int i = 0; i < num_ports; i++) begin
        write_counters[i] = last_write_addr[i];
        read_counters[i] = last_read_addr[i];
    end
end

logic full_flags[num_ports];
logic empty_flags[num_ports];
always_comb begin
    for (int i = 0; i < num_ports; i++) begin
        empty_flags[i] = 0;
        full_flags[i] = 0;
        if (last_write_addr[i] == last_read_addr[i])
            empty_flags[i] = 1;
        if (last_write_addr[i] == ((last_read_addr[i] + (1 << region_log_depth)) & counter_mask))
            full_flags[i] = 1;
    end
end

function logic [31:0] space_remaining(input logic [$clog2(num_ports)-1:0] port);
    if (empty_flags[port]) return (1 << region_log_depth);
    else if (full_flags[port]) return 0;
    else return (last_read_addr[port] - last_write_addr[port]) & (counter_mask >> 1);
endfunction

function logic [31:0] read_gap(input logic [31:0] write_addr, input logic [31:0] read_addr);
    return (write_addr - read_addr) & counter_mask;
endfunction

/*
    Just redoing everything in SV interfaces.
    - Each port has its own FIFO in order to keep track of counts within the module.
    - Mux selects active port interface to feed into
    - Async FIFOs handle clock domain crossing from selected port to mem interface
*/

//  Here is the code for the FIFOs placed at each port
FIFOInterface #(.num_bits(mem_width)) ports_in_buf[num_ports] (clk_core);
FIFOInterface #(.num_bits(mem_width)) ports_out_buf[num_ports] (clk_core);

logic [M_fw:0] in_count[num_ports];
logic [M_fr:0] out_count[num_ports];

genvar g;
//  Experimenting to solve problem of ports_in / ports_out not being an array
//  RRRR....
FIFOInterface #(.num_bits(mem_width)) ports_in_rep[num_ports] (clk_core);
FIFOInterface #(.num_bits(mem_width)) ports_out_rep[num_ports] (clk_core);

generate for (g = 0; g < num_ports; g++) begin: ports_dup
    assign ports_in_ready[g] = ports_in_rep[g].ready;
    assign ports_in_rep[g].valid = ports_in_enable[g];
    assign ports_in_rep[g].data = ports_in_data[g];
    assign ports_out_rep[g].ready = ports_out_ready[g];
    assign ports_out_enable[g] = ports_out_rep[g].valid;
    assign ports_out_data[g] = ports_out_rep[g].data;
    fifo_sync #(.Nb(mem_width), .M(M_fw)) write_fifo (
        .clk(clk_core),
        .reset,
        .in(ports_in_rep[g].in),
        .out(ports_in_buf[g].out),
        .count(in_count[g])
    );
    fifo_sync #(.Nb(mem_width), .M(M_fr)) read_fifo (
        .clk(clk_core),
        .reset,
        .in(ports_out_buf[g].in),
        .out(ports_out_rep[g].out),
        .count(out_count[g])
    );
end
endgenerate

//  Here is the code for the async FIFOs to/from the memory interface
FIFOInterface #(.num_bits(mem_width)) port_in_sel(clk_core);
FIFOInterface #(.num_bits(mem_width)) port_out_sel(clk_core);

logic [4:0] c2m_wr_count;
logic [4:0] c2m_rd_count;
fifo_async #(.Nb(mem_width), .M(4)) main_write_fifo(
    .reset,
    .in(port_in_sel.in),
    .in_count(c2m_wr_count),
    .out(mem_write),
    .out_count(c2m_rd_count)
);

logic [4:0] m2c_wr_count;
logic [4:0] m2c_rd_count;
fifo_async #(.Nb(mem_width), .M(4)) main_read_fifo(
    .reset,
    .in(mem_read),
    .in_count(m2c_wr_count),
    .out(port_out_sel.out),
    .out_count(m2c_rd_count)
);

//  Here is the code that acts as a FIFO mux.
//  First there are some extra signals defined to work around SystemVerilog interface array limitations.
logic ports_in_buf_ready[num_ports];
logic ports_in_buf_enable[num_ports];
logic [mem_width - 1 : 0] ports_in_buf_data[num_ports];
logic ports_out_buf_ready[num_ports];
logic ports_out_buf_enable[num_ports];
logic [mem_width - 1 : 0] ports_out_buf_data[num_ports];
generate for (g = 0; g < num_ports; g++) always_comb begin
    ports_in_buf[g].ready = ports_in_buf_ready[g];
    ports_in_buf_enable[g] = ports_in_buf[g].valid;
    ports_in_buf_data[g] = ports_in_buf[g].data;
    ports_out_buf_ready[g] = ports_out_buf[g].ready;
    ports_out_buf[g].valid = ports_out_buf_enable[g];
    ports_out_buf[g].data = ports_out_buf_data[g];
end
endgenerate

always_comb begin

    for (int i = 0; i < num_ports; i++) begin
        ports_in_buf_ready[i] = 0;
        port_in_sel.valid = 0;
        port_in_sel.data = 0;
        ports_out_buf_enable[i] = 0;
        ports_out_buf_data[i] = 0;
        port_out_sel.ready = 0;
    end

    if (port_in_active) begin
        ports_in_buf_ready[current_port_index] = port_in_sel.ready;
        port_in_sel.valid = ports_in_buf_enable[current_port_index];
        port_in_sel.data = ports_in_buf_data[current_port_index];
    end

    if (port_out_active) begin
        port_out_sel.ready = ports_out_buf_ready[current_port_index];
        ports_out_buf_enable[current_port_index] = port_out_sel.valid;
        ports_out_buf_data[current_port_index] = port_out_sel.data;
    end

end

//  Here is an async FIFO for mem commands.
MemoryCommand cur_mem_cmd;
FIFOInterface #(.num_bits(65 /* $sizeof(MemoryCommand) */)) mem_cmd_core (clk_core);
logic [2:0] c2m_cmd_wr_count;
logic [2:0] c2m_cmd_rd_count;
fifo_async #(.Nb(65), .M(2)) main_cmd_fifo(
    .reset,
    .in(mem_cmd_core.in),
    .in_count(c2m_cmd_wr_count),
    .out(mem_cmd),
    .out_count(c2m_cmd_rd_count)
);
always_comb mem_cmd_core.data = cur_mem_cmd;

always @(posedge clk_core) begin
    if (reset) begin
        for (int i = 0; i < num_ports; i = i + 1) begin
            last_write_addr[i] <= 0;
            last_read_addr[i] <= 0;
        end
        
        write_words_target <= 0;
        write_words_count <= 0;
        read_words_target <= 0;
        read_words_count <= 0;        

        port_in_active <= 0;
        port_out_active <= 0;
        current_port_index <= 0;
        
        mem_cmd_core.valid <= 0;
        cur_mem_cmd <= 0;
        
        state <= 0;
    end
    else begin
        if (mem_cmd_core.ready) mem_cmd_core.valid <= 0;

        //  Watch data go by and stop when we have target number of words
        if (port_in_sel.valid && port_in_sel.ready) begin
            write_words_count <= write_words_count + 1;
            if (write_words_count == write_words_target - 1)
                port_in_active <= 0;
        end

        case (state)
        STATE_WAITING: begin
            //  Identify next port needing attention
            current_port_index <= next_port_index;
            
            //	Begin a read when the address is mismatched and there is space in the FIFO
            if ((out_count[next_port_index] < (1 << M_fr)) && ports_out_buf_ready[next_port_index] && !empty_flags[next_port_index]) begin
                port_out_active <= 1;
                state <= STATE_READ_INIT;
            end
            //  Begin a write when there is data waiting
            else if ((in_count[next_port_index] != 0) && !full_flags[next_port_index]) begin

                //  Count the number of words we are going to write
                //  $display("%t %m: port %d in count = %d space remaining = %d", $time, next_port_index, in_count[next_port_index], space_remaining(next_port_index));
                if (space_remaining(next_port_index) < in_count[next_port_index])
                    write_words_target <= space_remaining(next_port_index);
                else
                    write_words_target <= in_count[next_port_index];
                write_words_count <= 0;
                state <= STATE_WRITE_CMD;
            end
        end
        STATE_READ_INIT: begin
            //  Count the number of words we are going to read
            //if (last_write_addr[current_port_index] - last_read_addr[current_port_index] > ((1 << M_fr) - out_count[current_port_index]))
            if (read_gap(last_write_addr[current_port_index], last_read_addr[current_port_index]) > ((1 << M_fr) - out_count[current_port_index]))
                read_words_target <= (1 << M_fr) - out_count[current_port_index];
            else
                read_words_target <= read_gap(last_write_addr[current_port_index], last_read_addr[current_port_index]);
            read_words_count <= 0;
            state <= STATE_READ_CMD;
        end
        STATE_READ_CMD: begin
            //  Submit command for read, if we need nonzero amount of data
            if (read_words_target > 0) begin
                cur_mem_cmd.length <= read_words_target;
                cur_mem_cmd.address <= last_read_addr[current_port_index] + (current_port_index << region_log_depth);
                cur_mem_cmd.read_not_write <= 1;
                mem_cmd_core.valid <= 1;
                state <= STATE_READ_DATA;
            end
            else begin
                port_out_active <= 0;
                state <= STATE_WAITING;
            end
        end
        STATE_READ_DATA: begin
            //  Watch data go by and stop when we have target number of words
            if (port_out_sel.valid && port_out_sel.ready) begin
                read_words_count <= read_words_count + 1;
                if (read_words_count == read_words_target - 1) begin
                    last_read_addr[current_port_index] <= (last_read_addr[current_port_index] + read_words_target) & counter_mask;
                    port_out_active <= 0;
                    state <= STATE_WAITING;
                end
            end
        end
        STATE_WRITE_INIT: begin
            
        end
        STATE_WRITE_CMD: begin
            //  Submit command for write
            cur_mem_cmd.length <= write_words_target;
            cur_mem_cmd.address <= last_write_addr[current_port_index] + (current_port_index << region_log_depth);
            cur_mem_cmd.read_not_write <= 0;
            mem_cmd_core.valid <= 1;
            last_write_addr[current_port_index] <= (last_write_addr[current_port_index] + write_words_target) & counter_mask;
            port_in_active <= 1;
            state <= STATE_WRITE_DATA;
        end
        STATE_WRITE_DATA: begin
            //  Transaction is finished.
            if (write_words_target == write_words_count)
                state <= STATE_WAITING;
        end
        endcase
    end
end


endmodule
