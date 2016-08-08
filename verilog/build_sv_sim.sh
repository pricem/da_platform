#!/bin/bash

#   Without wrapper
xvlog -sv interfaces.sv da_platform.sv da_platform_tb.sv fifo_arbiter.sv slot_controller.v spi_master.v fifo_sync.v fifo_async.v delay.v serializer.v deserializer.v clk_divider.v contrib/fifo_sync.sv contrib/fifo_async.sv isolator_model.sv i2s_receiver.sv slot_model_dac2.sv spi_slave.v

#   With wrapper and full MIG / Micron DDR3 model
#xvlog -sv -d USE_WRAPPER -f sources_wrapper_full.txt


#   With wrapper and MIG model
#   TODO


xelab --debug all da_platform_tb
#xelab --debug all -L unisims_ver -L secureip da_platform_tb glbl

xsim --R da_platform_tb


