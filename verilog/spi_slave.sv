`timescale 1ns / 1ps

module spi_slave(clk, reset, sck, ss, mosi, miso);

//  Simple simulation model - read/write registers
//  - first bit received is used for read/write
//  - next 7 bits (assuming 8-bit mode) used for address

//  Mimics DSD1792A - other SPI slaves may have different behavior

parameter int max_addr_bits = 16;
parameter int max_data_bits = 16;

parameter num_registers = (1 << max_addr_bits);

input clk;
input reset;

input sck;
input ss;
input mosi;
output miso;

reg [31:0] data;

reg miso_val;
reg miso_en;

reg [max_data_bits-1 : 0] storage [num_registers - 1 : 0];

wire ss_last;
delay #(.initial_val(1)) ss_delay(clk, reset, ss, ss_last);

reg is_read;
reg [max_addr_bits - 1 : 0] read_addr;

reg [5:0] bit_counter;

logic debug_display;
int address_bits;
int data_bits;

logic [max_addr_bits-1:0] target_addr;
logic [max_data_bits-1:0] target_data;

always_comb begin
    target_addr = (data >> data_bits) & ((1 << address_bits) - 1);
    target_data = data & ((1 << data_bits) - 1);
end

initial begin
    debug_display = 0;
    address_bits = 8;
    data_bits = 8;
end

task set_mode(input int address_bits_new, input int data_bits_new);
    address_bits = address_bits_new;
    data_bits = data_bits_new;
endtask

assign miso = miso_en ?  miso_val : 1'bz;

always @(posedge sck) begin
    if (!ss) begin
        data <= {data, mosi};
        bit_counter <= bit_counter + 1;
        if (bit_counter == 0)
            is_read <= mosi;
        else if (is_read && (bit_counter == address_bits - 1)) begin
            read_addr <= ({data, mosi}) & ((1 << (address_bits - 1)) - 1);
        end
    end
end

always @(negedge sck) begin
    if (!ss && is_read && (bit_counter >= address_bits) && (bit_counter < address_bits + data_bits)) begin
        miso_en <= 1;
        miso_val <= storage[read_addr][address_bits + data_bits - 1 - bit_counter];
        if (debug_display && (bit_counter == address_bits))
            $display("Data of %h read from register %h", storage[read_addr], read_addr);
    end
    else
        miso_en <= 0;
end

always @(posedge clk) begin
    if (reset) begin
        data <= 0;
        is_read <= 0;
        bit_counter <= 0;
        miso_val <= 0;
        miso_en <= 0;
    end
    else if (ss && !ss_last) begin
        if (debug_display)
            $display("SPI slave %m received data %h at time %t", data, $time);
        if (!is_read) begin
            storage[target_addr] <= target_data;
            if (debug_display)
                $display("Data of %h stored in register %h", target_data, target_addr);
        end
        
        bit_counter <= 0;
        data <= 0;
    end
end

endmodule
