/*
    Replacement for memfifo logic in ZTEX example.
*/

module memfifo_contents(
    //  Connections to EZ-USB I/O module (ezusb_io.v)
    output [15:0] usb_data_in,
    output reg usb_in_valid,
    input usb_in_ready,

    input [15:0] usb_data_out,
    input usb_out_valid,
    output usb_out_ready,
    
    input [3:0] usb_status,
    input usb_flagb,
    input usb_flaga,
        					
    //  Connections to FIFO (dram_fifo.v)
    output reg [127:0] fifo_data_in,               // 64-bit input: Data input
    input fifo_wr_full,                    // 1-bit output: Full flag
    input fifo_wr_err,                   // 1-bit output: Write error
    output reg fifo_wr_en,                     // 1-bit input: Write enable

    input [127:0] fifo_data_out,
    input fifo_rd_empty,                   // 1-bit output: Empty flag
    input fifo_rd_err,                   // 1-bit output: Read error
    output reg fifo_rd_en,                     // 1-bit input: Read enable
    
    input [24:0] fifo_mem_free,
    input [9:0] fifo_status,
    
    //  Other generic connections
    input ifclk,
    input reset,
    input reset_usb,
    input reset_mem,
    output [9:0] led1,
    output [19:0] led2,
    input SW8,
    input SW10
);

reg [127:0] in_data;
reg in_valid;

reg [127:0] rd_buf;
reg [3:0] wr_cnt;
reg [2:0] rd_cnt;

reg rderr_buf;
reg wrerr_buf;

reg reset_ifclk;

assign led1 = SW10 ? fifo_status : { fifo_rd_empty, fifo_wr_full, wrerr_buf, rderr_buf, usb_status, usb_flagb, usb_flaga };

assign led2[0] = fifo_mem_free != { 1'b1, 24'd0 };
assign led2[1] = fifo_mem_free[23:19] < 5'd30;
assign led2[2] = fifo_mem_free[23:19] < 5'd29;
assign led2[3] = fifo_mem_free[23:19] < 5'd27;
assign led2[4] = fifo_mem_free[23:19] < 5'd25;
assign led2[5] = fifo_mem_free[23:19] < 5'd24;
assign led2[6] = fifo_mem_free[23:19] < 5'd22;
assign led2[7] = fifo_mem_free[23:19] < 5'd20;
assign led2[8] = fifo_mem_free[23:19] < 5'd19;
assign led2[9] = fifo_mem_free[23:19] < 5'd17;
assign led2[10] = fifo_mem_free[23:19] < 5'd15;
assign led2[11] = fifo_mem_free[23:19] < 5'd13;
assign led2[12] = fifo_mem_free[23:19] < 5'd12;
assign led2[13] = fifo_mem_free[23:19] < 5'd10;
assign led2[14] = fifo_mem_free[23:19] < 5'd8;
assign led2[15] = fifo_mem_free[23:19] < 5'd7;
assign led2[16] = fifo_mem_free[23:19] < 5'd5;
assign led2[17] = fifo_mem_free[23:19] < 5'd3;
assign led2[18] = fifo_mem_free[23:19] < 5'd2;
assign led2[19] = fifo_mem_free == 25'd0;

assign usb_out_ready = !reset_ifclk && !fifo_wr_full;
assign usb_data_in = rd_buf[15:0];

assign test_sync = wr_cnt[0] || (wr_cnt == 4'd14);

always @ (posedge ifclk)
begin
    reset_ifclk <= reset || reset_usb || reset_mem;

    if ( reset_ifclk ) 
    begin
        rderr_buf <= 1'b0;
        wrerr_buf <= 1'b0;
    end else
    begin
        rderr_buf <= rderr_buf || fifo_rd_err;
        wrerr_buf <= wrerr_buf || fifo_wr_err;
    end
    
    // FPGA -> EZ-USB FIFO
    if ( reset_ifclk )
    begin
        rd_cnt <= 3'd0;
        usb_in_valid <= 1'd0;
    end else if ( usb_in_ready )
    begin
        usb_in_valid <= !fifo_rd_empty;
        if ( !fifo_rd_empty )
        begin
            if ( rd_cnt == 3'd0 )
            begin
                rd_buf <= fifo_data_out;
            end else
            begin
                rd_buf[111:0] <= rd_buf[127:16];
            end
            rd_cnt <= rd_cnt+1;
        end
    end

    fifo_rd_en <= !reset_ifclk && usb_in_ready && !fifo_rd_empty && (rd_cnt == 3'd0);

    if ( reset_ifclk ) 
    begin
        in_data <= 128'd0;
        in_valid <= 1'b0;
        wr_cnt <= 4'd0;
        fifo_wr_en <= 1'b0;
    end else if ( !fifo_wr_full )
    begin
        if ( in_valid ) fifo_data_in <= in_data;

        if ( usb_out_valid )
        begin
            in_data <= { usb_data_out, in_data[127:16] };
            in_valid <= wr_cnt[2:0] == 3'd7;
            wr_cnt <= wr_cnt + 1;
        end else
        begin
            in_valid <= 1'b0;
        end

    end
    fifo_wr_en <= !reset_ifclk && in_valid && !fifo_wr_full;
end

endmodule

