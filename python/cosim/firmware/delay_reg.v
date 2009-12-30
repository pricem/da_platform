//  A synchronous delay register.

module delay_reg(clk, din, dout, reset);
    parameter NUM_BITS = 1;
    parameter NUM_CYCLES = 1;

    input clk;
    input [(NUM_BITS - 1):0] din;
    output [(NUM_BITS - 1):0] dout;
    input reset;
    
    reg [(NUM_BITS - 1):0] data [(NUM_CYCLES - 1):0];
    
    integer i;
    
    assign dout = data[NUM_CYCLES - 1];
    
    always @(posedge clk) begin
        for (i = 1; i < NUM_CYCLES; i = i + 1)
            if (reset)
                data[i] <= 0;
            else
                data[i] <= data[i - 1];
    end
    always @(posedge clk) begin:loading
        if (reset)
            data[0] <= 0;
        else
            data[0] <= din;
    end

endmodule


