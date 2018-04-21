## HDL design for DA platform

The baseline DA platform implementation has an FPGA in it, to act as an asynchronous FIFO and I2S/SPI/GPIO interface to the DAC and ADC cards.  This directory contains the SystemVerilog hardware description language (HDL) code for the digital logic on the FPGA.

The design is to some extent decoupled from the hardware platform that it runs on.  Please look at the xilinx directory for the scripts that build this into a bitstream for a specific FPGA.

All code here is licensed under the Solderpad license (docs/licenses/LICENSE-SHL).

