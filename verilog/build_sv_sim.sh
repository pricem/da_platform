#!/bin/bash

xvlog -sv interfaces.sv da_platform.sv da_platform_tb.sv fifo_arbiter.sv slot_controller.v spi_master.v fifo_sync.v fifo_async.v delay.v serializer.v deserializer.v clk_divider.v contrib/fifo_sync.sv contrib/fifo_async.sv isolator_model.sv i2s_receiver.sv slot_model_dac2.sv spi_slave.v
# fifo_array_breakout.sv

xelab --debug all da_platform_tb

xsim --R da_platform_tb


