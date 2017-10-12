//	Obtained from ftp://ftp.probo.com/pub/mig_ddr2_bfm/mig_ddr2_model.v on July 21, 2012
//  Please see: http://www.probo.com/mig_ddr2_bfm.php
//	Subsequently modified by Michael Price (pricem@mit.edu) for: dense memory storage
//	Subsequently modified by Michael Price (pricem@mit.edu) for: MIG 7-series DDR3 modeling


/*                      MIG_ddr3_MODEL
 *
 * This a is sparse memory based functional model that implements the
 * Xilinx MIG ddr3 controller application user interface.
 *
 * It does NOT implement a ddr3 controller - the ddr3 ram pins are inactive!
 *
 * Its purpose is to provide a fast simulation vehicle for testing the user
 * logic connected to the Xilinx MIG ddr3 controller.
 *
 * 
 *
 *              Copyright 2009, Providenza & Boekelheide, Inc.
 *
 * No warranties expressed or implied!        Use at your own risk!
 *
 * Please email bugs / sugggestions / improvements to
 *      johnp
 *              aaaattttt
 *                      probo
 *                              period/dot
 *                                              com
 *
 *
 * The input address is mapped to row/col/bank as
 *      { bank[bank_width-1:0],  row[row_width-1:0], col[col_width-1:0] } = app_af_addr
 * This matches the mapping used by the Xilinx MIG ddr3 controller
 *
 *
 * NOTES:
 *
 * Since this is a sparse memory model, the amount of memory actually
 * available during simulation is controlled by the parameter NUM_PAGES.
 * This controls the number of pages in the memory pool.  As a new row/bank
 * is detected, a page is assigned.
 *
 * The model attempts to insert some performance "hits" similar to what a
 * ddr3 ram would do.  This feature is a work-in-progress!  It is enabled
 * by the parameter TIMING_HITS_ON
 *
 *
 *
 * 4-22-09      jrp
 *      initial release
 *
 * 4-22-09b     jrp
 *      changed "peek" routine to be a task.  As a function, it enabled a task (which
 *      is illegal)
 */

module mig_ddr3_model # (
    parameter BANK_WIDTH                = 2,
    parameter COL_WIDTH                 = 10,
    parameter ROW_WIDTH                 = 14,
    parameter CKE_WIDTH                 = 1,    // unused
    parameter CLK_WIDTH                 = 1,    // unused
    parameter CS_NUM                    = 1,    // unused
    parameter CS_WIDTH                  = 1,    // unused
    parameter CS_BITS                   = 1,    // unused
    parameter DM_WIDTH                  = 8,    // unused
    parameter DQ_WIDTH                  = 64,    // unused
    parameter DQ_PER_DQS                = 8,    // unused
    parameter DQ_BITS                   = 8,    // unused
    parameter DQS_WIDTH                 = 8,    // unused
    parameter DQS_BITS                  = 1,    // unused
    parameter BURST_LEN                 = 4,	//	not the same as the memory's actual burst length... just set to get right number of cycles when reading
    parameter RST_ACT_LOW               = 1,    // 1: active low, 0: active high
    parameter CLKIN_PERIOD              = 3750,  // in psec
    
	parameter nCS_PER_RANK          	= 1,
	parameter nCK_PER_CLK				= 4,
	parameter RANKS						= 1,
	parameter ADDR_WIDTH				= 28,
	parameter CK_WIDTH					= 1,
	parameter PAYLOAD_WIDTH				= 64,
	
	parameter BURST_TYPE				= 0,
	parameter TRCD                      = 13125,
    parameter TRFC                      = 110000,
    parameter TRP                       = 13125,
    parameter TWTR                      = 7500,
    
    parameter init_use_file 			= 0,
	parameter init_filename 			= ""
) (

	input                               		 sys_clk_p,
	input                                 		 sys_clk_n,      // unused
	input                               		 clk_ref_p,       // unused
	input                               		 clk_ref_n,       // unused
	input                               		 sys_rst,

	output                              		 ddr3_ras_n,     // unused
	output                              		 ddr3_cas_n,     // unused
	output                              		 ddr3_we_n,      // unused
	output [CS_WIDTH*nCS_PER_RANK-1:0]           ddr3_cs_n,      // unused
	output [CKE_WIDTH-1:0]                       ddr3_cke,       // unused
	output [RANKS-1:0]                           ddr3_odt,       // unused
	output [DM_WIDTH-1:0]                        ddr3_dm,        // unused
	inout [DQ_WIDTH-1:0]                         ddr3_dq,        // unused
	inout [DQS_WIDTH-1:0]                        ddr3_dqs_p,     // unused
	inout [DQS_WIDTH-1:0]                        ddr3_dqs_n,     // unused
	output [CK_WIDTH-1:0]                        ddr3_ck_p,      // unused
	output [CK_WIDTH-1:0]                        ddr3_ck_n,      // unused
	output [BANK_WIDTH-1:0]                      ddr3_ba,        // unused
	output [ROW_WIDTH-1:0]                       ddr3_addr,      // unused
	output reg                                   ddr3_reset_n		= 1'b0,

	input [ADDR_WIDTH-1:0]                       app_addr,
	input [2:0]                                  app_cmd,
	input                                        app_en,
	input [(nCK_PER_CLK*2*PAYLOAD_WIDTH)-1:0]    app_wdf_data,
	input                                        app_wdf_end,
	input [(nCK_PER_CLK*2*PAYLOAD_WIDTH)/8-1:0]  app_wdf_mask,
	input                                        app_wdf_wren,
	output [(nCK_PER_CLK*2*PAYLOAD_WIDTH)-1:0]   app_rd_data,
	output reg                                   app_rd_data_end     = 1'b0,
	output reg                                   app_rd_data_valid   = 1'b0,
	output reg                                   app_rdy             = 1'b0,
	output reg                                   app_wdf_rdy         = 1'b0,
	input                                        app_sr_req,
	output reg                                   app_sr_active       = 1'b0,
	input                                        app_ref_req,
	output reg                                   app_ref_ack         = 1'b0,
	input                                        app_zq_req,
	output reg                                   app_zq_ack          = 1'b0,
	output                                       ui_clk,
	output reg                                   ui_clk_sync_rst     = 1'b0,

	output reg                                   init_calib_complete = 1'b0
);


//                      Customizable Params
parameter       NUM_PAGES       = 1024;                 // allow 1K pages of memory
parameter       TIMING_HITS_ON  = 1;                    // enable ddr3 timing model

parameter       DATA_FIFO_DEPTH   = 128;
parameter       ADDR_FIFO_DEPTH   = 128;

parameter       REF_PERIOD_PS   = 7500000;              // psec

//  Michael Price 9/24/2015: Allow an offset to be subtracted from the provided
//  address (useful when data is loaded from a file).
//  This is to match physical address offset in the MIG adapter (which is there
//  so the startup sequence of the DDR controller doesn't overwrite useful data).
localparam PHYS_ADDR_OFFSET = 32'h00000100;

//                      Derrived Params
localparam      PAGE_SIZE       = 1 << COL_WIDTH;						//	10 -> 1024
localparam      ROW_COUNT       = (1 << ROW_WIDTH) * (1 << BANK_WIDTH);	//	14, 3 -> 128k
localparam      BANK_COUNT      = (1 << BANK_WIDTH);					//	3
localparam      MEM_WIDTH       = nCK_PER_CLK * 2 * PAYLOAD_WIDTH;		//	256
localparam		APPDATA_WIDTH	= MEM_WIDTH;
localparam      MASK_WIDTH      = MEM_WIDTH / 8;
localparam      DATA_FIFO_WIDTH = MEM_WIDTH + MASK_WIDTH;


//                      User I/F Params
localparam      APPCMD_WIDTH    = 3 + ADDR_WIDTH;
localparam      APP_WR_CMD      = 3'b000,
                APP_RD_CMD      = 3'b001;
localparam      BURST_SEQ       = 0,
                BURST_INTER     = 1;

//	Old-style variables mapping
reg app_wdf_afull = 1'b0;
reg app_af_afull = 1'b0;
reg [2:0] app_af_cmd = 3'b0;
reg [(nCK_PER_CLK*2*PAYLOAD_WIDTH)/8-1:0] app_wdf_mask_data;
reg app_af_wren;
reg [ADDR_WIDTH-1:0] app_af_addr;
reg rd_data_valid;
reg [MEM_WIDTH-1:0] rd_data_fifo_out;
wire sys_rst_n = sys_rst;

assign app_rd_data = rd_data_fifo_out;

always @(*) begin
	app_wdf_rdy = !app_wdf_afull;
	app_rdy = !app_af_afull;
	app_af_cmd = app_cmd;
	app_wdf_mask_data = app_wdf_mask;
	app_af_wren = app_en;
	app_af_addr = app_addr;
	app_rd_data_valid = rd_data_valid;
end

//	Memory array (added by Michael Price 7/21/2012)
//	256 bits / 32 bytes wide, and should be 32M deep for 1 GB
//	Hard code 256 MB since for some reason, VCS thinks anything over 512 MB is greater than 2 GB?
localparam mem_log_depth = 22;
localparam MEM_DEPTH = (1 << mem_log_depth);
//  localparam MEM_DEPTH = 1048576;
reg [MEM_WIDTH-1:0] mem[MEM_DEPTH-1:0];
//	reg [MEM_WIDTH-1:0] mem[PAGE_SIZE * ROW_COUNT / (nCK_PER_CLK * 2) - 1:0];

integer                         mem_free_ptr = -1;
task init_mem_pool;

    reg load_file;
	integer i;
	integer j;
	integer init_file;
	integer return_code;
	reg [1:1024] filename;
	reg [MEM_WIDTH-1:0] orig_reg;
	reg [MEM_WIDTH-1:0] byteswap_reg;

	begin
	
	    load_file = 0;
	
		init_file = 0;
		//	Start with all zeros
		$display("Initalizing memory in MIG/DDR3 model");
		for (i = 0; i < MEM_DEPTH; i = i + 1)
			mem[i] = 0;
        $display("Set memory contents to zero");
		
		//	Then fill in contents of file
		if (init_use_file) begin
		    filename = init_filename;
			init_file = $fopen(filename, "rb");
			load_file = 1;
        end
        else if ($test$plusargs("mig-init-data")) begin
            $value$plusargs("mig-init-data=%s", filename);
            init_file = $fopen(filename, "rb");
            load_file = 1;
        end
        
        if (load_file) begin
			return_code = $fread(mem, init_file);
			
			//  Fix byte ordering
			for (i = 0; i < PAGE_SIZE * ROW_COUNT; i = i + 1) begin
			    orig_reg = mem[i];
			    for (j = 0; j < MEM_WIDTH / 8; j = j + 1)
			        byteswap_reg[j * 8 +: 8] = orig_reg[(MEM_WIDTH / 8 - j - 1) * 8 +: 8];
			    mem[i] = byteswap_reg;
			end
			
			$display("Read memory data from %s to registers in %m with return code %d", filename, return_code);
		end
		mem_free_ptr        = 0;
	end			
endtask

/*	Disabled by Michael Price 7/21/2012
// ----------------------------------------------------------------------
//                      Sparse Memory Pool
reg     [MEM_WIDTH-1:0]         mem[NUM_PAGES*PAGE_SIZE-1:0];
integer                         mem_free_ptr = -1;
integer                         row_ptr[ROW_COUNT-1:0];


task init_mem_pool;
integer     idx;
    begin
    for(idx=0; idx<ROW_COUNT; idx=idx+1)
        row_ptr[idx]    = -1;

    mem_free_ptr        = 0;
    end
endtask
*/

// ----------------------------------------------------------------------
//                      Misc signals
wire            rst     = RST_ACT_LOW ? ~sys_rst_n : sys_rst_n;

assign ui_clk   = sys_clk_p;

always @(posedge ui_clk)
    ui_clk_sync_rst     <= rst;



//                      init_calib_complete
integer         phy_init_delay;
always @(posedge ui_clk)
    if (rst)
        begin
        init_calib_complete           <= 1'b0;
        phy_init_delay          <= 0;
        end
    else
        begin
        if (phy_init_delay < 50)	//	Michael Price 8/10/2016 - earlier value was 2660
            phy_init_delay      <= phy_init_delay + 1;
        else
            init_calib_complete       <= 1'b1;
        end


// ----------------------------------------------------------------------
//                      APP Write Data Fifo
reg [DATA_FIFO_WIDTH-1:0]       data_fifo_data[DATA_FIFO_DEPTH-1 : 0];
integer                         data_fifo_wptr    = 0;
integer                         data_fifo_rptr    = 0;
integer                         data_fifo_cnt     = 0;

always @ (*)
    data_fifo_cnt     = (data_fifo_wptr >= data_fifo_rptr) ? data_fifo_wptr - data_fifo_rptr
                                                           : DATA_FIFO_DEPTH + data_fifo_wptr - data_fifo_rptr
                                                           ;

always @(posedge ui_clk)
    if (rst)
        begin
        data_fifo_wptr    = 0;
        data_fifo_rptr    = 0;
        end
    else
        begin
        app_wdf_afull   <= data_fifo_cnt >= (DATA_FIFO_DEPTH - 12);

        if (app_wdf_wren)
            begin
            data_fifo_data[data_fifo_wptr] = {app_wdf_mask_data, app_wdf_data};
            data_fifo_wptr                = (data_fifo_wptr + 1) % DATA_FIFO_DEPTH;
            if (data_fifo_wptr == data_fifo_rptr)
                begin
                $display("%t ERROR: data_fifo overflow!", $time);
                $stop;
                end
            end
        end

// read an entry from the data fifo
task  dfifo_rd;
output  [DATA_FIFO_WIDTH-1:0]  dfifo_rd_data;

    begin
    dfifo_rd_data       = data_fifo_data[data_fifo_rptr];
    data_fifo_rptr      = (data_fifo_rptr + 1) % DATA_FIFO_DEPTH;
    end
endtask




// ----------------------------------------------------------------------
//                      APP Write Cmd Fifo
reg [APPCMD_WIDTH-1:0]          addr_fifo_data[ADDR_FIFO_DEPTH-1 : 0];
integer                         addr_fifo_wptr    = 0;
integer                         addr_fifo_rptr    = 0;
integer                         addr_fifo_cnt     = 0;

always @ (*)
    addr_fifo_cnt     = (addr_fifo_wptr >= addr_fifo_rptr) ? addr_fifo_wptr - addr_fifo_rptr
                                                           : ADDR_FIFO_DEPTH + addr_fifo_wptr - addr_fifo_rptr
                                                           ;

always @(posedge ui_clk)
    if (rst)
        begin
        addr_fifo_wptr    = 0;
        addr_fifo_rptr    = 0;
        end
    else
        begin
        app_af_afull    <= addr_fifo_cnt >= (ADDR_FIFO_DEPTH - 12);

        if (app_af_wren)
            begin
            if (app_af_cmd !== APP_WR_CMD && app_af_cmd !== APP_RD_CMD)
                begin
                $display("%t ERROR: illegal addr_fifo cmd=%h", $time, app_af_cmd);
                $stop;
                end
            addr_fifo_data[addr_fifo_wptr] = {app_af_addr - PHYS_ADDR_OFFSET, app_af_cmd};
            addr_fifo_wptr                = (addr_fifo_wptr + 1) % ADDR_FIFO_DEPTH;
            if (addr_fifo_wptr == addr_fifo_rptr)
                begin
                $display("%t ERROR: addr_fifo overflow!", $time);
                $stop;
                end
            end
        end






// ----------------------------------------------------------------------
//                      APP Command Processor
// Read user commands from the cmd/addr fifo and process them.
//
// We try to add in some delays to model some of the ddr3 ram delays

reg     [2:0]   burst_cnt;
integer         cmd_proc_idx;
integer         cmd_proc_cnt;
integer         cmd_proc_state;
parameter       CMD_PROC_IDLE           = 0,
                CMD_PROC_RD             = 1,
                CMD_PROC_WR             = 2,
                CMD_PROC_PENALTY        = 3,
                CMD_PROC_LAST           = 255;

integer         bank_row_open[BANK_COUNT-1 : 0];
integer         refresh_cnt             = 0;

integer         cmd_penalty_delay       = 0;
integer         penalty_code            = 0;
parameter       PENALTY_BANK_CONFLICT   = 1,
                PENALTY_RD_WR_CHG       = 2,
                PENALTY_ACTIVATE        = 3,
                PENALTY_REFRESH         = 4;


// variables for performance monitoring
integer         cyc_count;
integer         active_count;
real            bus_efficiency;


always @ (*)
    bus_efficiency = (100.0 * active_count) / (cyc_count * 1.0);

task    stat_clr;
    begin
    cyc_count               = 1;
    active_count            = 0;
    end
endtask


// actual cmd processor
always @(posedge ui_clk)
    if (rst)
        begin : init
        integer         idx;

        if (mem_free_ptr != 0)
        begin
            init_mem_pool;
        end
        cmd_proc_cnt        = 0;
        cmd_proc_idx        = 0;
        cmd_proc_state      = CMD_PROC_IDLE;

        for(idx=0; idx<BANK_COUNT; idx=idx+1)
            bank_row_open[idx]  = -1;

        stat_clr;
        refresh_cnt             = 0;
        cmd_penalty_delay       = 0;
        burst_cnt               = 0;
        end

    else
        begin : app_cmd_proc
        reg     [ROW_WIDTH-1 : 0]       row;
        reg     [COL_WIDTH-1 : 0]       col;
        reg     [BANK_WIDTH-1 : 0]      bank;
        integer                         page_base_idx;
        reg     [2:0]                   prev_cmd;
        integer                         idx;
        reg     [DATA_FIFO_WIDTH-1:0]   wr_data;

        refresh_cnt     = refresh_cnt + (CLKIN_PERIOD / nCK_PER_CLK);
        cyc_count       = cyc_count + 1;

        case (cmd_proc_state)
        CMD_PROC_IDLE:
            begin
            rd_data_valid           = 1'b0;
            rd_data_fifo_out        = {APPDATA_WIDTH{1'bz}};
            app_rd_data_end 		= 0;
            penalty_code            = 0;
            burst_cnt               = 0;

            if (TIMING_HITS_ON && refresh_cnt >= REF_PERIOD_PS)
                begin
                // refresh time...

                // close all banks
                for(idx=0; idx<BANK_COUNT; idx=idx+1)
                    bank_row_open[idx] = -1;

                refresh_cnt             = 0;
                cmd_penalty_delay       = (TRFC+TRP+TRCD)/(CLKIN_PERIOD / nCK_PER_CLK) + 1;
                penalty_code            = PENALTY_REFRESH;
                cmd_proc_state          = CMD_PROC_PENALTY;
                end

            else if (addr_fifo_cnt != 0)
                begin : app_cmd_proc_idle
                reg     [30:0]          addr;
                reg     [2:0]           cmd;

                // a user command is pending...
                //
                // peek at the cmd fifo to see what the next command is.  If
                // it violates a timing param, go to the penalty box for a while
                {addr, cmd}     = addr_fifo_data[addr_fifo_rptr];

                // break the addr into row/col/bank and get the memory array base index
                addr_split(addr, cmd, row, col, bank, page_base_idx);

                if (TIMING_HITS_ON && bank_row_open[bank] == -1)
                    begin
                    // need to activate the row
                    prev_cmd            = cmd;
                    bank_row_open[bank] = row;
                    cmd_penalty_delay   = (TRCD)/(CLKIN_PERIOD / nCK_PER_CLK) + 1;
                    penalty_code        = PENALTY_ACTIVATE;
                    cmd_proc_state      = CMD_PROC_PENALTY;
                    end

                else if (TIMING_HITS_ON && bank_row_open[bank] != row)
                    begin
                    // bank conflict
                    prev_cmd            = cmd;
                    bank_row_open[bank] = row;
                    cmd_penalty_delay   = (TRP+TRCD)/(CLKIN_PERIOD / nCK_PER_CLK) + 1;
                    penalty_code        = PENALTY_BANK_CONFLICT;
                    cmd_proc_state      = CMD_PROC_PENALTY;
                    end

                else if (TIMING_HITS_ON && cmd != prev_cmd)
                    begin
                    // dead cycles between rd and wr operations
                    prev_cmd            = cmd;
                    cmd_penalty_delay   = (TWTR)/(CLKIN_PERIOD / nCK_PER_CLK) + 1;
                    penalty_code        = PENALTY_RD_WR_CHG;
                    cmd_proc_state      = CMD_PROC_PENALTY;
                    end

                else
                    begin
                    // no penalty, process this command
                    prev_cmd            = cmd;
                    cmd_proc_cnt        = cmd_proc_cnt + 1;
                    active_count        = active_count + 1;

                    // advance the cmd fifo, we already have the info from it
                    addr_fifo_rptr  = (addr_fifo_rptr + 1) % ADDR_FIFO_DEPTH;

                    if (cmd == APP_WR_CMD)
                        begin
                        if (data_fifo_cnt == 0)
                            begin
                            $display("%t ERROR: write cmd with no pending data", $time);
                            $stop;
                            end
                        else
                            begin
                            // write one entry from the data fifo, then write
                            // the rest of the data burst in a dedicated state
                            dfifo_rd(wr_data);
                            do_write((page_base_idx + col) / (nCK_PER_CLK * 2), wr_data[APPDATA_WIDTH-1:0], wr_data>>APPDATA_WIDTH);
                            $display("%t: write (first of burst) index %h data %h mask %h", $time, (page_base_idx + col) / (nCK_PER_CLK * 2), wr_data[APPDATA_WIDTH-1:0], wr_data>>APPDATA_WIDTH);
                            if (BURST_LEN > 1) begin
                                cmd_proc_state = CMD_PROC_WR;
                                cmd_proc_idx = BURST_LEN - 2;
                            end
                            end
                        end
                    else
                        begin
                        // read the 1st two memory locations, then go to
                        // dedicated state for the rest of the burst
                        do_read((page_base_idx + col) / (nCK_PER_CLK * 2));
                        if (BURST_LEN > 1) begin
                            cmd_proc_state      = CMD_PROC_RD;
                            cmd_proc_idx        = BURST_LEN-2;
                        end
                        if (cmd_proc_idx == 0)
            				app_rd_data_end = 1;
                        end
                    end
                end
            end

        CMD_PROC_WR:
            begin
            if (data_fifo_cnt == 0)
                begin
                $display("%t ERROR: write_continue with no pending data", $time);
                $stop;
                end

            active_count        = active_count + 1;
            dfifo_rd(wr_data);
            do_write((page_base_idx + col) / (nCK_PER_CLK * 2), wr_data[APPDATA_WIDTH-1:0], wr_data>>APPDATA_WIDTH);
            $display("%t: write index %h data %h mask %h", $time, (page_base_idx + col) / (nCK_PER_CLK * 2), wr_data[APPDATA_WIDTH-1:0], wr_data>>APPDATA_WIDTH);

            cmd_proc_idx = cmd_proc_idx - 2;
            if (cmd_proc_idx == 0)
                cmd_proc_state = CMD_PROC_IDLE;
            end

        CMD_PROC_RD:
            begin
            active_count        = active_count + 1;
    
            if (cmd_proc_idx > 0)
	            do_read((page_base_idx + col) / (nCK_PER_CLK * 2));
	        else begin
	        	//	We already had the last cycle.
	        	app_rd_data_valid = 0;
	        	rd_data_fifo_out        = {APPDATA_WIDTH{1'bz}};
	        end

			if (cmd_proc_idx == 2)
            	app_rd_data_end = 1;

            cmd_proc_idx = cmd_proc_idx - 2;
            
            if (cmd_proc_idx < 0)
            	app_rd_data_end = 0;
                cmd_proc_state = CMD_PROC_IDLE;
            end

        CMD_PROC_PENALTY:
            begin
            // waste time here spoofing a ddr3 ram operation
            cmd_penalty_delay = cmd_penalty_delay - 1;
            if (cmd_penalty_delay == 0)
                cmd_proc_state = CMD_PROC_IDLE;
            end
        endcase
        end



// ----------------------------------------------------------------------
//                      Functions & Tasks


//                      MK_MEM_INDEX
// Given a base memory address, apply the current burst count in either
// sequential or interleved order to create the proper memory index for this
// cycle of a burst.
//
// Increment the burst counter for next cycle.
//
function [31:0] mk_mem_index;
input [31:0]    base_mem_idx;

reg     [2:0]   mem_offset;

    begin
    if (BURST_TYPE == BURST_SEQ)
        begin
        mem_offset[1:0] = base_mem_idx + burst_cnt;
        mem_offset[2]   = burst_cnt[2] ^ base_mem_idx[2];
        end
    else
        begin
        // interleaved - NOT TESTED!!!!!
        mem_offset = base_mem_idx ^ burst_cnt;
        end

    if (BURST_LEN == 4)
        mk_mem_index = {base_mem_idx[31 : 2], mem_offset[1:0]};
    else
        mk_mem_index = {base_mem_idx[31 : 3], mem_offset[2:0]};

    //  Limit depth - Michael Price 1/1/2017
    mk_mem_index = mk_mem_index[0 +: mem_log_depth];

    burst_cnt = burst_cnt + 1;
    end
endfunction



//                      DO_WRITE
// write data to memory, update burst counter
// return the updated col value
task do_write;
input [31:0]                    mem_idx;
input [APPDATA_WIDTH-1:0]       wr_data;
input [MASK_WIDTH-1:0]          wr_mask;        // 1's for bits to ignore

reg     [APPDATA_WIDTH-1:0]     mask;
reg     [MEM_WIDTH-1 :0]        d_low, d_hi;
reg     [31:0]                  mem_idx_lo, mem_idx_hi;
integer                         i;

    begin
    // create a mask to merge new data with old
    // a 1 indicates preserve ORIG value, a 0 indicate write NEW value
    //
    // Note the mask bits are BYTE wide since the Xilinx MIG forces that restriction
    for(i=0; i<APPDATA_WIDTH; i=i+8)
        mask[i +: 8] = {8{wr_mask[i/8]}};

    // mask off the data bits that will be preserved in the ram memory
    //	{d_hi, d_low}       = wr_data & ~mask;
    d_low = wr_data & ~mask;

    // stuff it in memory
    mem_idx_lo          = mk_mem_index(mem_idx);
    //	mem_idx_hi          = mk_mem_index(mem_idx);
    mem[mem_idx_lo]     = d_low | (mem[mem_idx_lo] & mask);
    //	mem[mem_idx_hi]     = d_hi |  (mem[mem_idx_hi] & mask[APPDATA_WIDTH-1:APPDATA_WIDTH/2]);
    end
endtask



//                      DO_READ
// read data from memory and output it to the app bus,
// update burst counter
//
task do_read;
input [31:0]    mem_idx;

reg     [MEM_WIDTH-1 :0] d_low, d_hi;
reg     [31:0]                  mem_idx_lo, mem_idx_hi;

    begin
    // get data from memory...
    mem_idx_lo          = mk_mem_index(mem_idx);
  //  mem_idx_hi          = mk_mem_index(mem_idx);

    d_low               = mem[mem_idx_lo];
  // d_hi                = mem[mem_idx_hi];

    // output to the user
  //  rd_data_fifo_out    = {d_hi, d_low};
    rd_data_fifo_out    = d_low;
    rd_data_valid       = 1'b1;
    end
endtask



// split a linear address into row/col/bank etc
// If needed, allocate a new page of memory
task addr_split;
input   [30:0]                  addr;
input   [2:0]                   cmd;
output  [ROW_WIDTH-1 : 0]       row;
output  [COL_WIDTH-1 : 0]       col;
output  [BANK_WIDTH-1 : 0]      bank;
output  integer                 page_base_idx;

integer                         row_bank_idx;

    begin
    col             = addr[COL_WIDTH-1 : 0];
    row             = addr[ROW_WIDTH+COL_WIDTH-1 : COL_WIDTH];
    bank            = addr[BANK_WIDTH+ROW_WIDTH+COL_WIDTH-1 : ROW_WIDTH+COL_WIDTH];
    row_bank_idx    = (row<<BANK_WIDTH) + bank;

	/*	Modified by Michael Price 7/21/2012	
    if (row_ptr[row_bank_idx] == -1)
        begin
        // we need to assign another block of memory
        if (cmd == APP_WR_CMD)
            begin
            if (mem_free_ptr >= NUM_PAGES*PAGE_SIZE)
                begin
                $display("%t ERROR: addr_split wr memory pool exhausted (poke)", $time);
                $stop;
                end
            else
                begin
                $display("%t info:  alloc page memory @ %h for row=%h, bank=%h",
                    $time, mem_free_ptr, row, bank);
                row_ptr[row_bank_idx] = mem_free_ptr;
                mem_free_ptr = mem_free_ptr + PAGE_SIZE;
                end
            end
        else
            begin
            $display("%t ERROR: addr_split rd with no page allocated", $time);
            $stop;
            end
        end

    // get the base addr for the current page. This is an index into the main
    // memory array
    page_base_idx   = row_ptr[row_bank_idx];
    */
    
    //	Get direct start-of-page address (linear addressing)
    page_base_idx  = (row + (bank << ROW_WIDTH)) << COL_WIDTH;
    end

endtask



//                      POKE & PEEK
// These two tasks/functions are meant for preloading/verifying memory


//                      POKE
// poke memory with a value
task poke;
input  [30:0]                   addr;
input  [APPDATA_WIDTH-1:0]      data;
input  [(APPDATA_WIDTH/8)-1:0]  mask;

reg     [ROW_WIDTH-1 : 0]       row;
reg     [COL_WIDTH-1 : 0]       col;
reg     [BANK_WIDTH-1 : 0]      bank;
integer                         page_base_idx;

    begin
    burst_cnt = 0;
    addr_split(addr, APP_WR_CMD, row, col, bank, page_base_idx);
    do_write(page_base_idx + col, data, mask);
    end

endtask


//                      PEEK
// peek into memory
task peek;
input   [30:0]                  addr;
output  [APPDATA_WIDTH-1:0]     rd_data;

reg     [ROW_WIDTH-1 : 0]       row;
reg     [COL_WIDTH-1 : 0]       col;
reg     [BANK_WIDTH-1 : 0]      bank;
integer                         page_base_idx;

reg     [MEM_WIDTH-1 :0]        d_low, d_hi;
reg     [1:0]                   nibble_addr;

    begin
    burst_cnt = 0;
    addr_split(addr, APP_RD_CMD, row, col, bank, page_base_idx);

    // get data from memory...
    d_low       = mem[page_base_idx + col];
    nibble_addr = col[1:0] + 1;
    d_hi        = mem[page_base_idx + {col[COL_WIDTH-1:2], nibble_addr} ];

    rd_data = {d_hi, d_low};
    end
endtask



initial
    $display("%t info: ddr3 Functional model: BURST_LEN=%0d BURST_TYPE=%0s, TimingDelays=%0d",
        $time,
        BURST_LEN,
        BURST_TYPE==BURST_SEQ ? "Sequential" : "Interleaved (NOT TESTED)",
        TIMING_HITS_ON
    );

endmodule

