#!/bin/bash

#   CellRAM interface TB
#vcs -pvalue+MEM_BITS=16 +define+sg708 cellram.v cellram_interface.v cellram_tb.v
iverilog -g2005 -o cellram_tb -DSIMULATION -Dsg708 cellram.v cellram_interface.v cellram_tb.v fifo_sync.v delay.v

#   DA platform TB
iverilog -g2005 -o da_platform_tb -DSIMULATION -Dsg708 da_platform_tb.v da_platform.v fifo_arbiter.v fifo_byte_adapter.v slot_controller.v spi_master.v spi_slave.v cellram.v cellram_interface.v fifo_sync.v fifo_async.v delay.v serializer.v deserializer.v clk_divider.v

#	CellRAM demo TB
iverilog -g2005 -o cellram_demo_tb -DSIMULATION -Dsg708 cellram.v cellram_interface.v cellram_demo.v cellram_demo_tb.v fifo_sync.v fifo_async.v delay.v
