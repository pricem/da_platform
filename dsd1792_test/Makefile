#
# Copyright (C) 2009-2012 Chris McClelland
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
TOP_LEVEL := top_level
PLATFORM  := nexys2-500
COMMON    := ../../../common
HDL       := verilog
HDLS      := \
	dsd1792_test.v \
	da_platform.v \
	slot_controller.v \
	clk_divider.v \
	delay.v \
	fifo_sync.v \
	fifo_async.v \
	spi_master.v \
	serializer.v \
	deserializer.v \
	../comm_fpga/comm_fpga_fx2.v

include $(COMMON)/top.mk
include $(COMMON)/$(VENDOR).mk
