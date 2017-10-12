module serdes_tb;

logic reset;
logic sclk;
logic srclk;
logic srclk2_modules;
logic srclk2_fpga_launch;
logic srclk2_fpga_capture;

//  Module to FPGA path
logic [63:0] data_m2f_in;
logic [7:0] data_m2f_s1;
logic data_m2f_ser;
logic [7:0] data_m2f_s2;
logic [63:0] data_m2f_out;
generate for (genvar g = 0; g < 8; g++) begin: modules_m2f
    serializer #(.launch_negedge(0)) module_ser(srclk, data_m2f_s1[g], srclk2_modules, data_m2f_in[g * 8 +: 8]);
    
    //  7/30/2017: Try hooking module up to sclk/srclk, not srclk/srclk2.
    //  serializer #(.launch_negedge(0)) module_ser(sclk, data_m2f_s1[g], srclk, data_m2f_in[g * 8 +: 8]);
end
endgenerate
serializer #(.launch_negedge(0)) module_m2f_ser(sclk, data_m2f_ser, srclk, data_m2f_s1);
deserializer fpga_m2f_deser(sclk, data_m2f_ser, srclk, data_m2f_s2);
generate for (genvar g = 0; g < 8; g++) begin: fpga_m2f
    deserializer fpga_deser(srclk, data_m2f_s2[g], srclk2_fpga_capture, data_m2f_out[g * 8 +: 8]);
end
endgenerate
always_ff @(posedge srclk2_modules) if (!reset) begin
    $display("%t: Module to FPGA: release val = %h", $time, data_m2f_in); 
end
always_ff @(posedge srclk2_fpga_capture) if (!reset) begin
    $display("%t: Module to FPGA: capture val = %h", $time, data_m2f_out); 
end

//  FPGA to module path
logic srclk_sync;
logic srclk2_sync;

logic [63:0] data_f2m_in;
logic [7:0] data_f2m_s1;
logic data_f2m_ser;
logic [7:0] data_f2m_s2;
logic [63:0] data_f2m_out;
generate for (genvar g = 0; g < 8; g++) begin: fpga_f2m
    serializer #(.launch_negedge(1)) fpga_ser(srclk_sync, data_f2m_s1[g], srclk2_sync, data_f2m_in[g * 8 +: 8]);
end
endgenerate
serializer #(.launch_negedge(1)) fpga_f2m_ser(sclk, data_f2m_ser, srclk_sync, data_f2m_s1);
deserializer module_f2m_deser(sclk, data_f2m_ser, srclk, data_f2m_s2);
generate for (genvar g = 0; g < 8; g++) begin: modules_f2m
    deserializer module_deser(srclk, data_f2m_s2[g], srclk2_modules, data_f2m_out[g * 8 +: 8]);
end
endgenerate
always_ff @(posedge srclk2_fpga_launch) if (!reset) begin
    $display("%t: FPGA to module: release val = %h", $time, data_f2m_in); 
end
always_ff @(posedge srclk2_modules) if (!reset) begin
    $display("%t: FPGA to module: capture val = %h", $time, data_f2m_out); 
end


//  Separate 1-level fpga to module path
logic [7:0] data2_f2m_in;
logic data2_f2m_ser;
logic [7:0] data2_f2m_out;
serializer #(.launch_negedge(1)) fpga2_f2m_ser(sclk, data2_f2m_ser, srclk_sync, data2_f2m_in);
deserializer module2_f2m_deser(sclk, data2_f2m_ser, srclk, data2_f2m_out);

//  Shared testbench code
int cycle_count;

initial begin
    reset = 1;
    sclk = 0;
    #20 reset = 0;
end
always #5 sclk <= !sclk;

initial begin
    $dumpfile("serdes_tb.vcd");
    $dumpvars(0, serdes_tb);
    
    #10000 $display("Time limit reached");
    $finish;
end

initial begin
    @(negedge reset);
    for (int i = 0; i < 10; i++) begin
        
        data_m2f_in <= {$random(), $random()};
        @(posedge srclk2_modules);
        data_f2m_in <= {$random(), $random()};
        @(posedge srclk2_fpga_launch);
    end
    
    #1000 $display("Test complete");
    $finish;
end

initial begin
    @(negedge reset);
    for (int i = 0; i < 70; i++) begin
        data2_f2m_in <= $random();
        @(posedge srclk);
    end
end

//  Divider for srclk and srclk2
always_ff @(posedge sclk) begin
    if (reset) begin
        cycle_count <= 0;
        srclk_sync <= 1;
        srclk2_sync <= 1;
    end
    else begin
        cycle_count <= cycle_count + 1;
        srclk_sync <= !(cycle_count % 8 == 7);
        srclk2_sync <= !(cycle_count % 64 == 63);
    end
end

always_ff @(posedge sclk) begin

end

logic srclk_en;
logic srclk2_modules_en;
logic srclk2_fpga_launch_en;
logic srclk2_fpga_capture_en;
always_latch if (!sclk) srclk_en = (!reset && (cycle_count % 8 == 0));
always_latch if (!sclk) srclk2_fpga_launch_en = (!reset && (cycle_count % 64 == 1));
always_latch if (!sclk) srclk2_modules_en = (!reset && (cycle_count % 64 == 17));
always_latch if (!sclk) srclk2_fpga_capture_en = (!reset && (cycle_count % 64 == 33));
always_comb begin
    srclk = !(sclk && srclk_en);
    srclk2_modules = !(sclk && srclk2_modules_en);
    srclk2_fpga_launch = !(sclk && srclk2_fpga_launch_en);
    srclk2_fpga_capture = !(sclk && srclk2_fpga_capture_en);
end

endmodule

