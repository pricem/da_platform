module dac_interface(clk, reset, data_en, data_left, data_right, dac_sclk, dac_sync, dac_dina, dac_dinb);

//  For DAC121S101 on Digilent PMOD DA2 board

input clk;
input reset;

input data_en;
input [11:0] data_left;
input [11:0] data_right;

output dac_sclk;
output reg dac_sync;
output reg dac_dina;
output reg dac_dinb;

reg active;
reg active_last;
reg [5:0] counter;
reg [15:0] saved_data_left;
reg [15:0] saved_data_right;

assign dac_sclk = clk;

always @(posedge clk) begin
    if (reset) begin
        dac_sync <= 0;
        dac_dina <= 0;
        dac_dinb <= 0;
        saved_data_left <= 0;
        saved_data_right <= 0;
        counter <= 0;
        active <= 0;
        active_last <= 0;
    end
    else begin
        active_last <= active;
        dac_sync <= 0;
        if (data_en && (counter == 0)) begin
            counter <= 15;
            saved_data_left <= {4'h0, data_left};
            saved_data_right <= {4'h0, data_right};
            dac_sync <= 1;
            active <= 1;
        end

        if (active) begin
            if (counter == 0)
                active <= 0;
            else
                counter <= counter - 1;
            dac_dina <= saved_data_left >> counter;
            dac_dinb <= saved_data_right >> counter;
        end
        else begin
            dac_dina <= 0;
            dac_dinb <= 0;
        end
    end
end

endmodule
