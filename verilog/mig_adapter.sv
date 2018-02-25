/*
    MIG Adapter module

    Redesigned for DA Platform project (AXI4 MIG) by Michael Price 12/28/2017
*/

`timescale 1ns / 1ps

module MIGAdapter (
    input reset,
    input clk,
    
    FIFOInterface.in ext_mem_cmd,
    FIFOInterface.in ext_mem_write,
    FIFOInterface.out ext_mem_read,
    
    input logic mig_init_done,
    
    AXI4_Std.master axi
);

`include "structures.sv"

//  Offset added to prevent startup calibration from overwriting data that we need
//  256 words should be plenty.
localparam logic [31:0] PHYS_ADDR_OFFSET = 32'h00000100;

localparam int MAX_BURST_LENGTH = 256;
localparam logic [1:0] INCR = 1;

logic active;
MemoryCommand cur_cmd;

logic [31:0] words_requested;
logic [31:0] words_transferred;

//  TODO
always_comb begin
    ext_mem_cmd.ready = mig_init_done && !active;

    //  Connect read/write FIFOs directly to AXI interface and add some flow control
    ext_mem_write.ready = (active && !cur_cmd.read_not_write) && axi.wready;
    axi.wvalid = (active && !cur_cmd.read_not_write) && ext_mem_write.valid;
    axi.wdata = ext_mem_write.data;

    axi.rready = (active && cur_cmd.read_not_write) && ext_mem_read.ready;
    ext_mem_read.valid = (active && cur_cmd.read_not_write) && axi.rvalid;
    ext_mem_read.data = axi.rdata;
    
    axi.wlast = axi.wvalid && (words_transferred == words_requested - 1);
    
    //  Tie off unused AXI signals
    axi.awid = 0;
    axi.awsize = 0;
    axi.awburst = INCR;
    axi.awlock = 0;
    axi.awcache = 3;
    axi.awprot = 0;
    axi.awqos = 0;
    
    axi.wstrb = 0;
    
    axi.arid = 0;
    axi.arsize = 0;
    axi.arburst = INCR;
    axi.arlock = 0;
    axi.arcache = 3;
    axi.arprot = 0;
    axi.arqos = 0;
end

always_ff @(posedge clk) begin
    if (reset) begin
        axi.awaddr <= 0;
        axi.awlen <= 0;
    
        axi.bready <= 0;
    
        axi.araddr <= 0;
        axi.arlen <= 0;

        active <= 0;
        cur_cmd <= 0;
        words_requested <= 0;
        words_transferred <= 0;
    end
    else begin
        //  For now, ignore write channel responses, and just hope everything works.
        axi.bready <= 1;

        if (axi.arready) axi.arvalid <= 0;
        if (axi.awready) axi.awvalid <= 0;

        if (ext_mem_cmd.ready && ext_mem_cmd.valid) begin
            active <= 1;
            words_requested <= 0;
            words_transferred <= 0;
            cur_cmd <= ext_mem_cmd.data;
        end

        if (active) begin
            if (cur_cmd.read_not_write) begin
                //  Request more AXI reads as necessary
                if (axi.arready && !axi.arvalid && (words_requested < cur_cmd.length)) begin
                    axi.araddr <= PHYS_ADDR_OFFSET + ((cur_cmd.address + words_requested) << 2);
                    if (cur_cmd.length - words_requested >= MAX_BURST_LENGTH)
                        axi.arlen <= MAX_BURST_LENGTH - 1;
                    else
                        axi.arlen <= cur_cmd.length - words_requested - 1;
                    axi.arvalid <= 1;
                end
                if (axi.arready && axi.arvalid)
                    words_requested <= words_requested + axi.arlen + 1;

                //  A read is finished once we record the requested number of data words.
                if (ext_mem_read.ready && ext_mem_read.valid) begin
                    words_transferred <= words_transferred + 1;
                    if (words_transferred == cur_cmd.length - 1)
                        active <= 0;
                 end
            end
            else begin
                //  Request more AXI writes as necessary
                if (axi.awready && !axi.awvalid && (words_requested < cur_cmd.length)) begin
                    axi.awaddr <= PHYS_ADDR_OFFSET + ((cur_cmd.address + words_requested) << 2);
                    if (cur_cmd.length - words_requested >= MAX_BURST_LENGTH)
                        axi.awlen <= MAX_BURST_LENGTH - 1;
                    else
                        axi.awlen <= cur_cmd.length - words_requested - 1;
                    axi.awvalid <= 1;
                end
                if (axi.awready && axi.awvalid)
                    words_requested <= words_requested + axi.awlen + 1;

                //  A write is finished once we record the requested number of data words.
                if (ext_mem_write.ready && ext_mem_write.valid) begin
                    words_transferred <= words_transferred + 1;
                    if (words_transferred == cur_cmd.length - 1)
                        active <= 0;
                 end
                
            end
        end
    end
end

endmodule

