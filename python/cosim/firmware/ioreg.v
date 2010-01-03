//  Component to make things modular

module ioreg(config_clk, config_write, config_read, config_addr, config_data, registers, clk, reset);

    input config_clk;
    input config_write;
    input config_read;
    input [1:0] config_addr;
    inout [7:0] config_data;
    
    output [31:0] registers;
    
    input clk;
    input reset;
    
    integer i;
    genvar g;
    
    //  Configuration registers
    reg [7:0] config [3:0];
    reg [7:0] config_data_out;
    always @(posedge config_clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 4; i = i + 1)
                config[i] <= 0;
        end
        else begin
            config_data_out <= config[config_addr];
            if (config_write) begin
                config[config_addr] <= config_data;
            end
        end
    end
    assign config_data = config_read ? config_data_out : 8'hZZ;
    generate for (g = 0; g < 4; g = g + 1) begin
            assign registers[((g + 1) * 8 - 1):(g * 8)] = config[g];
        end
    endgenerate
    
endmodule
    
    

