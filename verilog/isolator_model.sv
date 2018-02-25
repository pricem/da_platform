`timescale 1ns / 1ps

/*
    This models the hardware on the isolator board, including some set of installed slots.
*/

`include "structures.sv"

module isolator_model(
    IsolatorInterface.isolator iso
);

//  Model the oscillators: 22.5792 MHz (clk0) and 24.576 MHz (clk1)
logic clk_en;
logic clk0;
logic clk1;
initial begin
    clk_en = 1; //  tried disabling to see what would happen.  It breaks everything.
    clk0 = 0;
    clk1 = 0;
end
always #22.1443 clk0 = !clk0;
always #20.345 clk1 = !clk1;
always_comb iso.mclk = clk_en && (iso.clksel ? clk1 : clk0);

//  Local signals and logic (74xx chips on isolator PCB)
logic [3:0] slot_dir;
logic [3:0] slot_chan;
logic [3:0] slot_hwflag;
logic [3:0] slot_hwcon;
logic [3:0] slot_cs_n;

logic [3:0] tmp1, tmp2;

//  Model transmission of hwcon and hwflag

serializer #(.launch_negedge(0)) dirchan_ser(
    .clk_ser(iso.sclk), 
    .data_ser(iso.dirchan), 
    .clk_par(iso.srclk), 
    .data_par({slot_chan, slot_dir})
);

serializer #(.launch_negedge(0)) hwflag_ser(
    .clk_ser(iso.sclk), 
    .data_ser(iso.hwflag), 
    .clk_par(iso.srclk), 
    .data_par({4'h0, slot_hwflag})
);

deserializer cs_n_deser(
    .clk_ser(iso.sclk), 
    .data_ser(iso.cs_n), 
    .clk_par(iso.srclk), 
    .data_par({tmp1, slot_cs_n})
);

deserializer hwcon_deser(
    .clk_ser(iso.sclk), 
    .data_ser(iso.hwcon), 
    .clk_par(iso.srclk), 
    .data_par({tmp2, slot_hwcon})
);

/*  Sample FIFOs (modeling audio signals)   */

//  Connect some fake modules to the slots
//  And provide FIFOs for audio samples to be provided to I2S
//  (Note: slot-major ordering for FIFO interface array)

logic sample_clk;
FIFOInterface #(.num_bits(48)) samples_slot_in[16](sample_clk);
FIFOInterface #(.num_bits(48)) samples_slot_out[16](sample_clk);

//  Loopback configuration
logic [3:0] loopback_matrix[4]; //  for each source slot, a vector saying what slots it's distributing to
logic loopback_chan[4]; //  for each destination slot, 0 for 2-ch or 1 for 8-ch

initial begin
    //  At startup, loopback is disabled.
    for (int i = 0; i < 4; i++) begin
        loopback_matrix[i] = 0;
        loopback_chan[i] = 1;
    end
end

//  Source/capture configuration
SlotMode slot_modes[4];
initial begin
    for (int i = 0; i < 4; i++) slot_modes[i] = DAC2;
end

logic [31:0] capture_buffers[4][];
int capture_counters[4];
int capture_target_count[4];
logic capture_enabled[4];

logic [31:0] source_buffers[4][];
int source_counters[4];
int source_target_count[4];
logic source_enabled[4];

initial begin
    for (int i = 0; i < 4; i++) begin
        capture_counters[i] = 0;
        capture_target_count[i] = 0;
        capture_enabled[i] = 0;
        
        source_counters[i] = 0;
        source_target_count[i] = 0;
        source_enabled[i] = 0;
    end
end

//  Indices for generate loop:
//  g: destination slot
//  h: source slot
//  k: interface index within slot
generate for (genvar g = 0; g < 4; g++) for (genvar h = 0; h < 4; h++) for (genvar k = 0; k < 4; k++) begin: loopback
    always_comb begin
        //  By default, let them "float".
        samples_slot_in[g * 4 + k].valid = 0;
        samples_slot_in[g * 4 + k].data = 0;
        samples_slot_out[h * 4 + k].ready = 1;
    
        //  Is the output of slot g configured to loop back to slot h?
        if (loopback_matrix[h][g] && ((k == 0) || loopback_chan[g])) begin
            //  If so, connect the FIFO interfaces to each other.
            samples_slot_in[g * 4 + k].valid = samples_slot_out[h * 4 + k].valid;
            samples_slot_in[g * 4 + k].data = samples_slot_out[h * 4 + k].data;
            samples_slot_out[h * 4 + k].ready = samples_slot_in[g * 4 + k].ready;
        end

        if (source_enabled[g]) begin
            //  Source is enabled
            samples_slot_in[g * 4 + k].valid = (source_counters[g] < source_target_count[g]);
            samples_slot_in[g * 4 + k].data = source_buffers[g][source_counters[g]];
        end
    end
end
endgenerate

generate for (genvar g = 0; g < 4; g++) for (genvar k = 0; k < 4; k++) begin: source_capture
    always_ff @(posedge sample_clk) begin

        if (source_enabled[g]) begin
            case (slot_modes[g])
            ADC2: begin
                $fatal(0, "%t %m: ADC2 ext stimulus not implemented", $time);
            end
            ADC8: begin
                $fatal(0, "%t %m: ADC8 ext stimulus not implemented", $time);
            end
            default: $fatal(0, "%t %m: ext stimulus cannot source samples to a DAC", $time);
            endcase
        end
        if (capture_enabled[g]) begin
            case (slot_modes[g])
            DAC2: if (k == 0) begin
                if (samples_slot_out[g * 4].ready && samples_slot_out[g * 4].valid) begin
                    capture_buffers[g][capture_counters[g]] = samples_slot_out[g * 4].data[47:24];
                    capture_buffers[g][capture_counters[g] + 1] = samples_slot_out[g * 4].data[23:0];
                    capture_counters[g] += 2;
                end
            end
            DAC8: begin
                if (samples_slot_out[g * 4 + k].ready && samples_slot_out[g * 4 + k].valid) begin
                    capture_buffers[g][capture_counters[g] + k * 2] = samples_slot_out[g * 4 + k].data[47:24];
                    capture_buffers[g][capture_counters[g] + k * 2 + 1] = samples_slot_out[g * 4 + k].data[23:0];
                    if (k == 3) capture_counters[g] += 8;
                end
            end
            default: $fatal(0, "%t %m: ext stimulus cannot capture samples from an ADC", $time);
            endcase
            //  Auto-stop once we reach the target.
            if (source_counters[g] >= source_target_count[g])
                source_enabled[g] = 0;
            if (capture_counters[g] >= capture_target_count[g])
                capture_enabled[g] = 0;
        end

    end
end
endgenerate

//  TODO: This doesn't look right...
always_comb sample_clk = iso.mclk;

/*  Slot models */

//  All slots initialized to DAC2 mode.
//  Testbench should configure module types and loopback as desired.

//  Note that Vivado doesn't support modports on interface arrays, so they aren't specified.

slot_model slot0(
    .slotdata(iso.slotdata[5:0]),
    .mclk(iso.mclk),
    .sclk(iso.sclk),
    .cs_n(slot_cs_n[0]), 
    .miso(iso.miso), 
    .mosi(iso.mosi), 
    .dir(slot_dir[0]),
    .chan(slot_chan[0]),
    .hwcon(slot_hwcon[0]),
    .hwflag(slot_hwflag[0]),
    .srclk(iso.srclk),
    .srclk2(iso.srclk2),
    .reset_n(iso.reset_n),
    .sample_clk(sample_clk),
    .samples_in(samples_slot_in[0 +: 4]),
    .samples_out(samples_slot_out[0 +: 4])
);

slot_model slot1(
    .slotdata(iso.slotdata[11:6]),
    .mclk(iso.mclk),
    .sclk(iso.sclk),
    .cs_n(slot_cs_n[1]), 
    .miso(iso.miso), 
    .mosi(iso.mosi), 
    .dir(slot_dir[1]),
    .chan(slot_chan[1]),
    .hwcon(slot_hwcon[1]),
    .hwflag(slot_hwflag[1]),
    .srclk(iso.srclk),
    .srclk2(iso.srclk2),
    .reset_n(iso.reset_n),
    .sample_clk(sample_clk),
    .samples_in(samples_slot_in[4 +: 4]),
    .samples_out(samples_slot_out[4 +: 4])
);

slot_model slot2(
    .slotdata(iso.slotdata[17:12]),
    .mclk(iso.mclk),
    .sclk(iso.sclk),
    .cs_n(slot_cs_n[2]), 
    .miso(iso.miso), 
    .mosi(iso.mosi), 
    .dir(slot_dir[2]),
    .chan(slot_chan[2]),
    .hwcon(slot_hwcon[2]),
    .hwflag(slot_hwflag[2]),
    .srclk(iso.srclk),
    .srclk2(iso.srclk2),
    .reset_n(iso.reset_n),
    .sample_clk(sample_clk),
    .samples_in(samples_slot_in[8 +: 4]),
    .samples_out(samples_slot_out[8 +: 4])
);

slot_model slot3(
    .slotdata(iso.slotdata[23:18]),
    .mclk(iso.mclk),
    .sclk(iso.sclk),
    .cs_n(slot_cs_n[3]), 
    .miso(iso.miso), 
    .mosi(iso.mosi), 
    .dir(slot_dir[3]),
    .chan(slot_chan[3]),
    .hwcon(slot_hwcon[3]),
    .hwflag(slot_hwflag[3]),
    .srclk(iso.srclk),
    .srclk2(iso.srclk2),
    .reset_n(iso.reset_n),
    .sample_clk(sample_clk),
    .samples_in(samples_slot_in[12 +: 4]),
    .samples_out(samples_slot_out[12 +: 4])
);

/*  Control tasks/functions */

task set_slot_mode(input int slot, input SlotMode mode);
    slot_modes[slot] = mode;
    case (slot)
    0: slot0.set_mode(int'(mode));
    1: slot1.set_mode(int'(mode));
    2: slot2.set_mode(int'(mode));
    3: slot3.set_mode(int'(mode));
    default: $fatal(0, "%t %m: requested module mode change for nonexistent slot %0d", $time, slot);
    endcase
endtask

task set_spi_mode(input int slot, input int address_bits, input int data_bits);
    case (slot)
    0: slot0.spi.set_mode(address_bits, data_bits);
    1: slot1.spi.set_mode(address_bits, data_bits);
    2: slot2.spi.set_mode(address_bits, data_bits);
    3: slot3.spi.set_mode(address_bits, data_bits);
    default: $fatal(0, "%t %m: requested SPI mode change for nonexistent slot %0d", $time, slot);
    endcase
endtask

function logic [7:0] get_hwcon_parallel(input int slot);
    case (slot)
    0: return slot0.hwcon_parallel;
    1: return slot1.hwcon_parallel;
    2: return slot2.hwcon_parallel;
    3: return slot3.hwcon_parallel;
    default: $fatal(0, "%t %m: requested HWCON value from nonexistent slot %0d", $time, slot);
    endcase
endfunction

task enable_loopback(input int src, input int dest, input logic chan);
    loopback_matrix[src][dest] = 1;
    loopback_chan[dest] = chan;
endtask

task disable_loopback(input int src, input int dest);
    loopback_matrix[src][dest] = 0;
endtask

task source_samples(input int slot, input int num_samples, input logic [31:0] samples[]);
    source_enabled[slot] = 1;
    source_buffers[slot] = new[num_samples];
    for (int i = 0; i < num_samples; i++)
        source_buffers[slot][i] = samples[i];
    source_target_count[slot] = num_samples;
    source_counters[slot] = 0;
    source_buffers[slot].delete;
endtask

//  I wanted to use a pass by reference for the output samples.
//  But Vivado doesn't seem to handle that properly, so I'm going to pass by value
//  and allocate the output array here.
task automatic capture_samples(input int slot, input int num_samples, output logic [31:0] samples[]);
    capture_counters[slot] = 0;
    capture_buffers[slot] = new[num_samples];
    samples = new[num_samples];
    capture_target_count[slot] = num_samples;
    capture_enabled[slot] = 1;
    while (capture_enabled[slot]) 
        @(posedge sample_clk);
    for (int i = 0; i < num_samples; i++) begin
        //  $display("Capture buffer slot %0d index %0d = %h", slot, i, capture_buffers[slot][i]);
        samples[i] = capture_buffers[slot][i];
    end
    capture_buffers[slot].delete;
endtask

endmodule

