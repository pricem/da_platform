//  Micron Cellular RAM modelMT45W8MW16BGX
//  8 Meg x 16-bit

//  No timing constraints, but the version used on the Nexys2 has an 80 MHz
//  max clock speed (synchronous mode) or 70 ns read/write time (asynchronous)

//  The inputs (ce, we, oe, cre, adv, lb, ub) are all active low.

module cellram(clk, ce, we, oe, addr, data, reset, cre, mem_wait, adv, lb, ub);

    input clk;
    input ce;
    input we;
    input oe;
    input [22:0] addr;
    
    inout [15:0] data;
    input reset;
    input cre;
    output reg mem_wait;
    
    input adv;
    input lb;
    input ub;
    
    //  Connections to memory and internal signals
    wire mem_we;
    wire mem_oe;
    reg [22:0] mem_addr;
    reg [15:0] mem_data_in;
    wire [15:0] mem_data_out;
    wire reset_neg = ~reset;
    
    //  Internal signals
    reg [22:0] config;
    reg [15:0] last_data;
    reg [1:0] config_counter;
    
    //  Assign data line if chip is enabled
    assign data = ce ? 16'hZZZZ : last_data;
    
    //  Assign active high memory control signals based on active low inputs
    assign mem_we = (~ce && ~we);
    assign mem_oe = ~oe;

    always @(posedge clk) begin
        if (~reset) begin
            config <= 23'h009D1F;
            last_data <= 16'hZZZZ;
            config_counter <= 0;
            mem_wait <= 1'bZ;
            mem_addr <= 23'h000000;
            mem_data_in <= 16'hZZZZ;
        end
        else begin
            if (cre) begin
                config <= addr;
                last_data <= 16'hZZZZ;
                config_counter <= 1;
                mem_wait <= 0;
            end
            else begin
                if (config_counter != 0) begin
                    config_counter <= config_counter + 1;
                    mem_wait <= 0;
                end
                else begin
                    mem_wait <= ce ? 1'bZ : 1;
                    mem_addr <= addr;
                    mem_data_in <= data;
                    last_data <= mem_data_out;
                end
            end
        end
    end
    
    bram_8m_16 mem(
        .clk(clk), 
        .we(mem_we), 
        .oe(mem_oe),
        .addr(mem_addr), 
        .din(mem_data_in), 
        .dout(mem_data_out),
        .reset(reset_neg)
        );
    
endmodule

