/*
    Open-source digital audio platform
    Copyright (C) 2009--2018 Michael Price

    mem_model_axi: Behavioral model of an AXI-connected memory.
    Used in simulation to bypass the complex and slow-to-simulate MIG
    and DDR3 memory model.  But occasional verification that those models
    is still recommended.

    Warning: Use and distribution of this code is restricted.
    This HDL file is distributed under the terms of the Solderpad Hardware 
    License, Version 0.51.  Other files in this project may be subject to
    different licenses.  Please see the LICENSE file in the top level project
    directory for more information.
*/

module mem_model_axi #(
    parameter int depth = 32'h04000000  //  64M x 32 = 256 MB
) (
    input aclk,
    input aresetn,
    AXI4_Std.slave axi
);

logic read_active;
int read_word_index;
int read_burst_length;
logic [31:0] read_cur_addr;

logic write_active;
int write_word_index;
int write_burst_length;
logic [31:0] write_cur_addr;

logic [31:0] data[depth];

logic debug_display;
initial debug_display = 0;

always_ff @(posedge aclk) begin
    if (!aresetn) begin
        axi.awready <= 0;
        
        axi.wready <= 0;
        
        axi.bid <= 0;
        axi.bresp <= 0;
        axi.bvalid <= 0;
        
        axi.arready <= 0;
        
        axi.rid <= 0;
        axi.rdata <= 0;
        axi.rresp <= 0;
        axi.rlast <= 0;
        axi.rvalid <= 0;

        read_active <= 0;
        read_word_index <= 0;
        read_burst_length <= 0;
        read_cur_addr <= 0;
        
        write_active <= 0;
        write_word_index <= 0;
        write_burst_length <= 0;
        write_cur_addr <= 0;
    end
    else begin
        if (axi.rready) axi.rvalid <= 0;
        if (axi.bready) axi.bvalid <= 0;
    
        //  Read
        if (read_active) begin
            if (axi.rready) begin
                axi.rvalid <= 1;
                axi.rdata <= data[read_cur_addr / 4 + read_word_index];
                if (debug_display)
                    $display("%t %m: AXI read - word %0d/%0d, addr %h, data %h", $time, read_word_index + 1, read_burst_length, read_cur_addr / 4 + read_word_index, data[read_cur_addr / 4 + read_word_index]);
                read_word_index <= read_word_index + 1;
                if (read_word_index == read_burst_length - 1) begin
                    read_active <= 0;
                end
            end
        end
        else begin
            axi.arready <= !axi.rvalid; //  Make sure previous read is finished
            if (axi.arready && axi.arvalid) begin
                read_word_index <= 0;
                read_burst_length <= axi.arlen + 1;
                read_cur_addr <= axi.araddr;
                axi.arready <= 0;
                read_active <= 1;
            end
        end
        
        //  Write
        if (write_active) begin
            if (axi.wready && axi.wvalid) begin
                data[write_cur_addr / 4 + write_word_index] <= axi.wdata;
                if (debug_display)
                    $display("%t %m: AXI write - word %0d/%0d, addr %h, data %h", $time, write_word_index + 1, write_burst_length, write_cur_addr / 4 + write_word_index, axi.wdata);
                write_word_index <= write_word_index + 1;
                if (write_word_index == write_burst_length - 1) begin
                    axi.bvalid <= 1;
                    axi.bresp <= 1; //  TODO: What should this be?
                    axi.wready <= 0;
                    write_active <= 0;
                end
            end
        end
        else begin
            axi.awready <= 1;
            axi.wready <= 0;
            if (axi.awready && axi.awvalid) begin
                write_word_index <= 0;
                write_burst_length <= axi.awlen + 1;
                write_cur_addr <= axi.awaddr;
                axi.awready <= 0;
                axi.wready <= 1;
                write_active <= 1;
            end
        end
    end
end

endmodule

