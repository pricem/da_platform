#   Open-source digital audio platform
#   Copyright (C) 2009--2018 Michael Price
#
#   build_bitstream.tcl: Script to [re]build Vivado project for DA Platform
#   Run with:
#       vivado -mode batch -source build_bitstream.tcl
#
#   Warning: Use and distribution of this code is restricted.
#   This software code is distributed under the terms of the GNU General Public
#   License, version 3.  Other files in this project may be subject to
#   different licenses.  Please see the LICENSE file in the top level project
#   directory for more information.

file delete -force {*}[glob -nocomplain da_platform.*]
source init_project.tcl

launch_runs synth_1 -jobs 4
wait_on_run synth_1

launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

