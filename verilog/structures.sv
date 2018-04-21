/*
    Open-source digital audio platform
    Copyright (C) 2009--2018 Michael Price

    This is a collection of SV structures used throughout the design.

    Warning: Use and distribution of this code is restricted.
    This HDL file is distributed under the terms of the Solderpad Hardware 
    License, Version 0.51.  Other files in this project may be subject to
    different licenses.  Please see the LICENSE file in the top level project
    directory for more information.
*/

typedef struct packed {
    logic read_not_write;
    logic [31:0] address;
    logic [31:0] length;
} MemoryCommand;

typedef enum logic [1:0] { DAC2, ADC2, DAC8, ADC8 } SlotMode;
