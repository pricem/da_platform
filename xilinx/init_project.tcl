#   init_project.tcl: Script to create Vivado project for DA Platform
#   Supported Vivado version: 2017.2
#   Run with:
#       vivado -mode batch -source init_project.tcl

# Create project
create_project -force da_platform ./ -part xc7a35tcsg324-1

# Set the directory path for the new project
set proj_dir [get_property directory [current_project]]

# Reconstruct message rules
# None

# Set project properties
set obj [get_projects da_platform]
set_property -name "default_lib" -value "xil_defaultlib" -objects $obj
set_property -name "ip_cache_permissions" -value "disable" -objects $obj
set_property -name "part" -value "xc7a35tcsg324-1" -objects $obj
set_property -name "sim.ip.auto_export_scripts" -value "1" -objects $obj
set_property -name "simulator_language" -value "Mixed" -objects $obj

# Create 'sources_1' fileset (if not found)
if {[string equal [get_filesets -quiet sources_1] ""]} {
  create_fileset -srcset sources_1
}

# Set 'sources_1' fileset object
set obj [get_filesets sources_1]
set files [list \
 "[file normalize "../verilog/clk_divider.sv"]"\
 "[file normalize "../verilog/delay.sv"]"\
 "[file normalize "../verilog/deserializer.sv"]"\
 "[file normalize "../verilog/contrib/ezusb_io.v"]"\
 "[file normalize "../verilog/fifo_async.sv"]"\
 "[file normalize "../verilog/fifo_sync.sv"]"\
 "[file normalize "../verilog/serializer.sv"]"\
 "[file normalize "../verilog/commands.vh"]"\
 "[file normalize "../verilog/slot_controller.sv"]"\
 "[file normalize "../verilog/spi_master.sv"]"\
 "[file normalize "../verilog/da_platform.sv"]"\
 "[file normalize "../verilog/structures.sv"]"\
 "[file normalize "../verilog/fifo_arbiter.sv"]"\
 "[file normalize "../verilog/interfaces.sv"]"\
 "[file normalize "../verilog/mig_adapter.sv"]"\
 "[file normalize "../verilog/da_platform_wrapper.sv"]"\
 "[file normalize "ip/mig_b.prj"]"\
]
add_files -norecurse -fileset $obj $files

# Set 'sources_1' fileset file properties for remote files
set_property -name "file_type" -value "SystemVerilog" -objects [get_files -of_objects [get_filesets sources_1] [list "*.sv"]]
set_property -name "file_type" -value "Verilog Header" -objects [get_files -of_objects [get_filesets sources_1] [list "*.vh"]]

set file "ip/mig_b.prj"
set file [file normalize $file]
set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
set_property -name "scoped_to_cells" -value "mig_7series_0" -objects $file_obj

# Set 'sources_1' fileset file properties for local files
# None

# Set 'sources_1' fileset properties
set obj [get_filesets sources_1]
set_property -name "top" -value "da_platform_wrapper" -objects $obj

# Set 'sources_1' fileset object
set obj [get_filesets sources_1]
set files [list \
 "[file normalize "ip/mig_7series_0.xci"]"\
]
add_files -norecurse -fileset $obj $files

# Set 'sources_1' fileset file properties for remote files
# None

# Set 'sources_1' fileset file properties for local files
# None

# Create 'constrs_1' fileset (if not found)
if {[string equal [get_filesets -quiet constrs_1] ""]} {
  create_fileset -constrset constrs_1
}

# Set 'constrs_1' fileset object
set obj [get_filesets constrs_1]

# Add/Import constrs file and set constrs file properties
set file "[file normalize "constraints/usb_fpga_2_13a_mem.xdc"]"
set file_added [add_files -norecurse -fileset $obj $file]
set file "constraints/usb_fpga_2_13a_mem.xdc"
set file [file normalize $file]
set file_obj [get_files -of_objects [get_filesets constrs_1] [list "*$file"]]
set_property -name "file_type" -value "XDC" -objects $file_obj

# Add/Import constrs file and set constrs file properties
set file "[file normalize "constraints/da_platform.xdc"]"
set file_added [add_files -norecurse -fileset $obj $file]
set file "constraints/da_platform.xdc"
set file [file normalize $file]
set file_obj [get_files -of_objects [get_filesets constrs_1] [list "*$file"]]
set_property -name "file_type" -value "XDC" -objects $file_obj

# Add/Import constrs file and set constrs file properties
set file "[file normalize "constraints/debug.xdc"]"
set file_added [add_files -norecurse -fileset $obj $file]
set file "constraints/debug.xdc"
set file [file normalize $file]
set file_obj [get_files -of_objects [get_filesets constrs_1] [list "*$file"]]
set_property -name "file_type" -value "XDC" -objects $file_obj

# Set 'constrs_1' fileset properties
set obj [get_filesets constrs_1]
set_property -name "target_constrs_file" -value "[file normalize "constraints/debug.xdc"]" -objects $obj

# Create 'sim_1' fileset (if not found)
if {[string equal [get_filesets -quiet sim_1] ""]} {
  create_fileset -simset sim_1
}

# Set 'sim_1' fileset object
set obj [get_filesets sim_1]
set files [list \
 "[file normalize "../verilog/clk_divider.sv"]"\
 "[file normalize "../verilog/delay.sv"]"\
 "[file normalize "../verilog/deserializer.sv"]"\
 "[file normalize "../verilog/contrib/ezusb_io.v"]"\
 "[file normalize "../verilog/fifo_async.sv"]"\
 "[file normalize "../verilog/fifo_sync.sv"]"\
 "[file normalize "../verilog/mem_model_axi.sv"]"\
 "[file normalize "../verilog/serializer.sv"]"\
 "[file normalize "../verilog/commands.vh"]"\
 "[file normalize "../verilog/slot_controller.sv"]"\
 "[file normalize "../verilog/spi_master.sv"]"\
 "[file normalize "../verilog/spi_slave.sv"]"\
 "[file normalize "../verilog/da_platform.sv"]"\
 "[file normalize "../verilog/da_platform_wrapper.sv"]"\
 "[file normalize "../verilog/structures.sv"]"\
 "[file normalize "../verilog/fifo_arbiter.sv"]"\
 "[file normalize "../verilog/fx2_model.sv"]"\
 "[file normalize "../verilog/i2s_receiver.sv"]"\
 "[file normalize "../verilog/i2s_source.sv"]"\
 "[file normalize "../verilog/interfaces.sv"]"\
 "[file normalize "../verilog/isolator_model.sv"]"\
 "[file normalize "../verilog/mig_adapter.sv"]"\
 "[file normalize "../verilog/slot_model_adc2.sv"]"\
 "[file normalize "../verilog/slot_model_dac8.sv"]"\
 "[file normalize "../verilog/da_platform_tb.sv"]"\
 "[file normalize "../verilog/slot_model_dac2.sv"]"\
 "[file normalize "../verilog/slot_model_adc8.sv"]"\
]
add_files -norecurse -fileset $obj $files

# Set 'sim_1' fileset file properties for remote files
set_property -name "file_type" -value "SystemVerilog" -objects [get_files -of_objects [get_filesets sim_1] [list "*.sv"]]
set_property -name "file_type" -value "Verilog Header" -objects [get_files -of_objects [get_filesets sim_1] [list "*.vh"]]

# Set 'sim_1' fileset file properties for local files
# None

# Set 'sim_1' fileset properties
set obj [get_filesets sim_1]
set_property -name "nl.sdf_anno" -value "0" -objects $obj
set_property -name "source_set" -value "" -objects $obj
set_property -name "top" -value "da_platform_tb" -objects $obj
set_property -name "verilog_define" -value "USE_WRAPPER USE_MIG_MODEL" -objects $obj
set_property -name "xsim.simulate.runtime" -value "50us" -objects $obj

# Create 'serdes_tb' fileset (if not found)
if {[string equal [get_filesets -quiet serdes_tb] ""]} {
  create_fileset -simset serdes_tb
}

# Set 'serdes_tb' fileset object
set obj [get_filesets serdes_tb]
set files [list \
 "[file normalize "../verilog/deserializer.sv"]"\
 "[file normalize "../verilog/serializer.sv"]"\
 "[file normalize "../verilog/serdes_tb.sv"]"\
]
add_files -norecurse -fileset $obj $files

# Set 'serdes_tb' fileset file properties for remote files
set_property -name "file_type" -value "SystemVerilog" -objects [get_files -of_objects [get_filesets serdes_tb] [list "*.sv"]]

# Set 'serdes_tb' fileset file properties for local files
# None

# Set 'serdes_tb' fileset properties
set obj [get_filesets serdes_tb]
set_property -name "top" -value "serdes_tb" -objects $obj
set_property -name "xsim.simulate.runtime" -value "2us" -objects $obj

# Create 'synth_1' run (if not found)
if {[string equal [get_runs -quiet synth_1] ""]} {
  create_run -name synth_1 -part xc7a35tcsg324-1 -flow {Vivado Synthesis 2016} -strategy "Vivado Synthesis Defaults" -constrset constrs_1
} else {
  set_property strategy "Vivado Synthesis Defaults" [get_runs synth_1]
  set_property flow "Vivado Synthesis 2016" [get_runs synth_1]
}
set obj [get_runs synth_1]
set_property -name "part" -value "xc7a35tcsg324-1" -objects $obj

# set the current synth run
current_run -synthesis [get_runs synth_1]

# Create 'impl_1' run (if not found)
if {[string equal [get_runs -quiet impl_1] ""]} {
  create_run -name impl_1 -part xc7a35tcsg324-1 -flow {Vivado Implementation 2016} -strategy "Vivado Implementation Defaults" -constrset constrs_1 -parent_run synth_1
} else {
  set_property strategy "Vivado Implementation Defaults" [get_runs impl_1]
  set_property flow "Vivado Implementation 2016" [get_runs impl_1]
}
set obj [get_runs impl_1]
set_property -name "part" -value "xc7a35tcsg324-1" -objects $obj
set_property -name "steps.write_bitstream.args.readback_file" -value "0" -objects $obj
set_property -name "steps.write_bitstream.args.verbose" -value "0" -objects $obj

# set the current impl run
current_run -implementation [get_runs impl_1]

puts "INFO: Project created: da_platform"

