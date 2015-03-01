/*
    FIFO arbiter - uses external DDR SDRAM to implement a vector of byte-wide FIFOs
*/

module fifo_arbiter #(
    parameter num_ports = 4,
    parameter port_width = 16
) (
    input reset, 
    input clk_core,
    
    //  Connection to SDRAM interface
    inout [15:0] ddr3_dq,
    inout [1:0] ddr3_dqs_n,
    inout [1:0] ddr3_dqs_p,
    output [13:0] ddr3_addr,
    output [2:0] ddr3_ba,
    output ddr3_ras_n,
    output ddr3_cas_n,
    output ddr3_we_n,
    output ddr3_reset_n,
    output [0:0] ddr3_ck_p,
    output [0:0] ddr3_ck_n,
    output [0:0] ddr3_cke,
    output [1:0] ddr3_dm,
    output [0:0] ddr3_odt,

	//  Vector of FIFOs to arbitrate
	input [num_ports - 1 : 0] ports_rd_ready, 
    output [num_ports - 1 : 0] ports_rd_valid, 
    output [num_ports * port_width - 1 : 0] ports_rd_data,
	output [num_ports - 1 : 0] ports_wr_ready, 
    input [num_ports - 1 : 0] ports_wr_valid, 
    input [num_ports * port_width - 1 : 0] ports_wr_data
);

parameter Nb = 16;

parameter M_fc = 2;
parameter M_fr = 6;
parameter M_fw = 6;

parameter Nb_addr = 32;

parameter INSTR_WRITE = 0;
parameter INSTR_READ = 1;


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

wire current_port_rd_ready = allow_fifo_write;
wire current_port_rd_valid;
wire [Nb-1:0] current_port_rd_data;
wire [M_fr:0] current_port_rd_count;
wire current_port_wr_ready;
wire current_port_wr_valid = 1; //  TODO
wire [Nb-1:0] current_port_wr_data = 0; //  TODO
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

//  TODO: Update
reg cmd_valid;
reg [6:0] cmd_bl;
reg cmd_instr;
reg [31:0] cmd_addr;
reg cmd_ready;


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


/*  Interface to MIG - DDR3 SDRAM memory 
    Includes PLL
*/
parameter CLKOUT2_DIVIDE = 1;
parameter CLKOUT3_DIVIDE = 1;
parameter CLKOUT4_DIVIDE = 1;
parameter CLKOUT5_DIVIDE = 1;
parameter CLKOUT2_PHASE = 0.0;
parameter CLKOUT3_PHASE = 0.0;
parameter CLKOUT4_PHASE = 0.0;
parameter CLKOUT5_PHASE = 0.0;
localparam APP_DATA_WIDTH = 128;	
localparam APP_MASK_WIDTH = 16;
localparam APP_ADDR_WIDTH = 24;

BUFG fxclk_buf (
    .I(fxclk_in),
    .O(fxclk) 
);

PLLE2_BASE #(
    .BANDWIDTH("LOW"),
    .CLKFBOUT_MULT(25),       // f_VCO = 1200 MHz (valid: 800 .. 1600 MHz)
    .CLKFBOUT_PHASE(0.0),
    .CLKIN1_PERIOD(0.0),
    //  .CLKIN2_PERIOD(0.0),
    .CLKOUT0_DIVIDE(3),	// 400 MHz
    .CLKOUT1_DIVIDE(6),	// 200 MHz
    .CLKOUT2_DIVIDE(CLKOUT2_DIVIDE),
    .CLKOUT3_DIVIDE(CLKOUT3_DIVIDE),
    .CLKOUT4_DIVIDE(CLKOUT4_DIVIDE),
    .CLKOUT5_DIVIDE(CLKOUT5_DIVIDE),
    .CLKOUT0_DUTY_CYCLE(0.5),
    .CLKOUT1_DUTY_CYCLE(0.5),
    .CLKOUT2_DUTY_CYCLE(0.5),
    .CLKOUT3_DUTY_CYCLE(0.5),
    .CLKOUT4_DUTY_CYCLE(0.5),
    .CLKOUT5_DUTY_CYCLE(0.5),
    .CLKOUT0_PHASE(0.0),
    .CLKOUT1_PHASE(0.0),
    .CLKOUT2_PHASE(CLKOUT2_PHASE),
    .CLKOUT3_PHASE(CLKOUT3_PHASE),
    .CLKOUT4_PHASE(CLKOUT4_PHASE),
    .CLKOUT5_PHASE(CLKOUT5_PHASE),
    .DIVCLK_DIVIDE(1),
    .REF_JITTER1(0.0),
    .STARTUP_WAIT("FALSE")
)
dram_fifo_pll_inst (
    .CLKIN1(fxclk),
    .CLKOUT0(clk400),
    .CLKOUT1(clk200),   
    .CLKOUT2(clkout2),   
    .CLKOUT3(clkout3),   
    .CLKOUT4(clkout4),   
    .CLKOUT5(clkout5),   
    .CLKFBOUT(pll_fb),
    .CLKFBIN(pll_fb),
    .PWRDWN(1'b0),
    .RST(1'b0)
);

mig_7series_0 mem0 (
    // Memory interface ports
    .ddr3_dq(ddr3_dq),
    .ddr3_dqs_n(ddr3_dqs_n),
    .ddr3_dqs_p(ddr3_dqs_p),
    .ddr3_addr(ddr3_addr),
    .ddr3_ba(ddr3_ba),
    .ddr3_ras_n(ddr3_ras_n),
    .ddr3_cas_n(ddr3_cas_n),
    .ddr3_we_n(ddr3_we_n),
    .ddr3_reset_n(ddr3_reset_n),
    .ddr3_ck_p(ddr3_ck_p[0]),
    .ddr3_ck_n(ddr3_ck_n[0]),
    .ddr3_cke(ddr3_cke[0]),
    .ddr3_dm(ddr3_dm),
    .ddr3_odt(ddr3_odt[0]),
    // Application interface ports
    .app_addr( {1'b0, app_addr, 3'b000} ),	
    .app_cmd(app_cmd),
    .app_en(app_en),
    .app_rdy(app_rdy),
    .app_wdf_rdy(app_wdf_rdy), 
    .app_wdf_data(app_wdf_data),
    .app_wdf_mask({ APP_MASK_WIDTH {1'b0} }),
    .app_wdf_end(app_wdf_wren), // always the last word in 4:1 mode 
    .app_wdf_wren(app_wdf_wren),
    .app_rd_data(app_rd_data),
    .app_rd_data_end(app_rd_data_end),
    .app_rd_data_valid(app_rd_data_valid),
    .app_sr_req(1'b0), 
    .app_sr_active(),
    .app_ref_req(1'b0),
    .app_ref_ack(),
    .app_zq_req(1'b0),
    .app_zq_ack(),
    .ui_clk(uiclk),
    .ui_clk_sync_rst(ui_clk_sync_rst),
    .init_calib_complete(init_calib_complete),
    .sys_rst(!reset),
    // clocks inputs
    .sys_clk_i(clk400),
    .clk_ref_i(clk200)
);

/*  End of interface to MIG */

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
