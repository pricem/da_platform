#   build_bitstream.tcl: Script to [re]build Vivado project for DA Platform
#   Run with:
#       vivado -mode batch -source build_bitstream.tcl

file delete -force {*}[glob -nocomplain da_platform.*]
source init_project.tcl

launch_runs synth_1 -jobs 4
wait_on_run synth_1

launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

