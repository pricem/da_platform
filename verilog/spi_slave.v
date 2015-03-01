module spi_slave(clk, reset, sck, ss, mosi, miso);

//  Simple simulation model - read/write registers, first bit received is used for read/write

//  Mimics DSD1792A - other SPI slaves may have different behavior

parameter address_bits = 8;
parameter data_bits = 8;
parameter num_registers = (1 << address_bits);

input clk;
input reset;

input sck;
input ss;
input mosi;
output miso;

reg [31:0] data;

reg miso_val;
reg miso_en;

reg [data_bits-1:0] storage [num_registers-1:0];

wire ss_last;
delay ss_delay(clk, reset, ss, ss_last);

wire [address_bits-1:0] target_addr = data[address_bits+data_bits-1:data_bits];
wire [data_bits-1:0] target_data = data[data_bits-1:0];

reg is_read;
reg [6:0] read_addr;

reg [3:0] bit_counter;

assign miso = miso_en ?  miso_val : 1'bz;

always @(posedge sck) begin
    if (!ss) begin
        data <= {data, mosi};
        bit_counter <= bit_counter + 1;
        if (bit_counter == 0)
            is_read <= mosi;
        else if (is_read && (bit_counter == 7)) begin
            read_addr <= {data[5:0], mosi};
        end
    end
end

always @(negedge sck) begin
    if (!ss && is_read && (bit_counter >= 8) && (bit_counter <= 16)) begin
        miso_en <= 1;
        miso_val <= storage[read_addr][15 - bit_counter];
        if (bit_counter == 8)
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
    if (ss && !ss_last) begin
        $display("SPI slave %m received data %h at time %t", data, $time);
        if (!is_read) begin
            storage[target_addr] <= target_data;
            $display("Data of %h stored in register %h", target_data, target_addr);
        end
        
        bit_counter <= 0;
        data <= 0;
    end
end

endmodule
