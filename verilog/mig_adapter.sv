/*
    MIG Adapter module

    Redesigned for DA Platform project by Michael Price 12/28/2017
*/

`timescale 1ns / 1ps

module MIGAdapter #(
    parameter addr_width = 28,
    parameter data_width = 256,
    parameter interface_width = 8,
    parameter DDR3_BURST_LENGTH = 8,
    parameter nCK_PER_CLK = 4
) (
    input reset,
    input clk,
    
    FIFOInterface.in ext_mem_cmd,
    FIFOInterface.in ext_mem_write,
    FIFOInterface.out ext_mem_read,
    
    input logic mig_clk,
    input logic mig_reset,
    input logic mig_init_done,
    input logic mig_af_rdy,
    output logic mig_af_wr_en,
    output logic [addr_width - 1 : 0] mig_af_addr,
    output logic [2:0] mig_af_cmd,
    input logic mig_wdf_rdy,
    output logic mig_wdf_wr_en,
    output logic [data_width - 1 : 0] mig_wdf_data,
    output logic mig_wdf_last,
    output logic [data_width / 8 - 1 : 0] mig_wdf_mask,
    input logic mig_read_data_valid,
    input logic mig_read_data_last,
    input logic [data_width - 1 : 0] mig_read_data
);

`include "structures.sv"

localparam CMD_READ = 3'b001;
localparam CMD_WRITE = 3'b000;

//  Offset added to prevent startup calibration from overwriting data that we need
//  256 words should be plenty.
localparam PHYS_ADDR_OFFSET = 32'h00000100;

//  TODO

endmodule

