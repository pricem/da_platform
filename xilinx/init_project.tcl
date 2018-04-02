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

#   Create two main simulation filesets:
#   a) sim_fake_mig - Simulate a behavioral model of AXI slave memory, bypassing the MIG and DDR3 model.
#   b) sim_real_mig - Simulate with full MIG and DDR3 memory RTL models.
create_fileset -simset sim_fake_mig
create_fileset -simset sim_real_mig
current_fileset -simset [get_filesets sim_fake_mig]
delete_fileset sim_1

set base_sim_files [list \
    "[file normalize "../verilog/clk_divider.sv"]" \
    "[file normalize "../verilog/delay.sv"]" \
    "[file normalize "../verilog/deserializer.sv"]" \
    "[file normalize "../verilog/contrib/ezusb_io.v"]" \
    "[file normalize "../verilog/fifo_async.sv"]" \
    "[file normalize "../verilog/fifo_sync.sv"]" \
    "[file normalize "../verilog/serializer.sv"]" \
    "[file normalize "../verilog/commands.vh"]" \
    "[file normalize "../verilog/slot_controller.sv"]" \
    "[file normalize "../verilog/spi_master.sv"]" \
    "[file normalize "../verilog/spi_slave.sv"]" \
    "[file normalize "../verilog/da_platform.sv"]" \
    "[file normalize "../verilog/da_platform_wrapper.sv"]" \
    "[file normalize "../verilog/structures.sv"]" \
    "[file normalize "../verilog/fifo_arbiter.sv"]" \
    "[file normalize "../verilog/fx2_model.sv"]" \
    "[file normalize "../verilog/i2s_receiver.sv"]" \
    "[file normalize "../verilog/i2s_source.sv"]" \
    "[file normalize "../verilog/interfaces.sv"]" \
    "[file normalize "../verilog/isolator_model.sv"]" \
    "[file normalize "../verilog/mig_adapter.sv"]" \
    "[file normalize "../verilog/slot_model.sv"]" \
    "[file normalize "../verilog/da_platform_tb.sv"]" \
]
add_files -norecurse -fileset sim_fake_mig $base_sim_files
add_files -norecurse -fileset sim_real_mig $base_sim_files

set fake_mig_sim_files [list \
    "[file normalize "../verilog/mem_model_axi.sv"]" \
]
add_files -norecurse -fileset sim_fake_mig $fake_mig_sim_files

set real_mig_sim_files [list \
    "[file normalize "../verilog/contrib/ddr3_model/ddr3_model.sv"]"\
    "[file normalize "./ip/mig_7series_0/user_design/rtl/axi/mig_7series_v4_0_axi_mc_cmd_translator.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/axi/mig_7series_v4_0_axi_mc_wr_cmd_fsm.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/axi/mig_7series_v4_0_axi_ctrl_reg.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/axi/mig_7series_v4_0_axi_ctrl_read.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/axi/mig_7series_v4_0_ddr_axi_upsizer.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/axi/mig_7series_v4_0_axi_mc_b_channel.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/axi/mig_7series_v4_0_ddr_a_upsizer.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/axi/mig_7series_v4_0_ddr_axic_register_slice.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/axi/mig_7series_v4_0_ddr_carry_latch_and.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/axi/mig_7series_v4_0_axi_mc_cmd_arbiter.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/axi/mig_7series_v4_0_axi_ctrl_write.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/axi/mig_7series_v4_0_ddr_carry_latch_or.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/axi/mig_7series_v4_0_axi_mc_ar_channel.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/axi/mig_7series_v4_0_axi_mc_simple_fifo.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/axi/mig_7series_v4_0_ddr_comparator.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/axi/mig_7series_v4_0_ddr_command_fifo.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/axi/mig_7series_v4_0_axi_mc_fifo.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/axi/mig_7series_v4_0_axi_mc_r_channel.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/axi/mig_7series_v4_0_axi_mc_incr_cmd.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/axi/mig_7series_v4_0_axi_mc_cmd_fsm.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/axi/mig_7series_v4_0_axi_ctrl_top.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/axi/mig_7series_v4_0_axi_mc.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/axi/mig_7series_v4_0_axi_mc_w_channel.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/axi/mig_7series_v4_0_axi_ctrl_addr_decode.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/axi/mig_7series_v4_0_ddr_axi_register_slice.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/axi/mig_7series_v4_0_axi_mc_wrap_cmd.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/axi/mig_7series_v4_0_ddr_comparator_sel_static.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/axi/mig_7series_v4_0_ddr_comparator_sel.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/axi/mig_7series_v4_0_ddr_carry_and.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/axi/mig_7series_v4_0_axi_ctrl_reg_bank.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/axi/mig_7series_v4_0_axi_mc_aw_channel.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/axi/mig_7series_v4_0_ddr_w_upsizer.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/axi/mig_7series_v4_0_ddr_r_upsizer.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/axi/mig_7series_v4_0_ddr_carry_or.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/mig_7series_0.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/clocking/mig_7series_v4_0_tempmon.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/clocking/mig_7series_v4_0_infrastructure.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/clocking/mig_7series_v4_0_iodelay_ctrl.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/clocking/mig_7series_v4_0_clk_ibuf.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/ui/mig_7series_v4_0_ui_rd_data.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/ui/mig_7series_v4_0_ui_cmd.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/ui/mig_7series_v4_0_ui_top.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/ui/mig_7series_v4_0_ui_wr_data.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/controller/mig_7series_v4_0_bank_queue.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/controller/mig_7series_v4_0_bank_state.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/controller/mig_7series_v4_0_rank_mach.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/controller/mig_7series_v4_0_round_robin_arb.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/controller/mig_7series_v4_0_bank_mach.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/controller/mig_7series_v4_0_arb_mux.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/controller/mig_7series_v4_0_rank_common.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/controller/mig_7series_v4_0_bank_compare.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/controller/mig_7series_v4_0_bank_cntrl.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/controller/mig_7series_v4_0_arb_select.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/controller/mig_7series_v4_0_arb_row_col.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/controller/mig_7series_v4_0_col_mach.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/controller/mig_7series_v4_0_bank_common.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/controller/mig_7series_v4_0_mc.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/controller/mig_7series_v4_0_rank_cntrl.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/phy/mig_7series_v4_0_ddr_phy_top.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/phy/mig_7series_v4_0_ddr_prbs_gen.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/phy/mig_7series_v4_0_ddr_phy_init.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/phy/mig_7series_v4_0_ddr_of_pre_fifo.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/phy/mig_7series_v4_0_ddr_phy_dqs_found_cal.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/phy/mig_7series_v4_0_ddr_mc_phy_wrapper.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/phy/mig_7series_v4_0_ddr_if_post_fifo.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/phy/mig_7series_v4_0_ddr_mc_phy.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/phy/mig_7series_v4_0_poc_top.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/phy/mig_7series_v4_0_ddr_phy_ck_addr_cmd_delay.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/phy/mig_7series_v4_0_ddr_byte_lane.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/phy/mig_7series_v4_0_ddr_phy_wrlvl.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/phy/mig_7series_v4_0_ddr_phy_wrcal.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/phy/mig_7series_v4_0_ddr_phy_oclkdelay_cal.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/phy/mig_7series_v4_0_ddr_phy_ocd_mux.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/phy/mig_7series_v4_0_poc_meta.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/phy/mig_7series_v4_0_ddr_phy_ocd_lim.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/phy/mig_7series_v4_0_poc_pd.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/phy/mig_7series_v4_0_ddr_byte_group_io.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/phy/mig_7series_v4_0_ddr_phy_ocd_edge.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/phy/mig_7series_v4_0_ddr_phy_ocd_cntlr.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/phy/mig_7series_v4_0_ddr_phy_ocd_samp.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/phy/mig_7series_v4_0_ddr_phy_wrlvl_off_delay.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/phy/mig_7series_v4_0_poc_edge_store.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/phy/mig_7series_v4_0_poc_tap_base.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/phy/mig_7series_v4_0_ddr_phy_dqs_found_cal_hr.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/phy/mig_7series_v4_0_ddr_calib_top.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/phy/mig_7series_v4_0_ddr_phy_ocd_po_cntlr.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/phy/mig_7series_v4_0_ddr_phy_prbs_rdlvl.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/phy/mig_7series_v4_0_ddr_skip_calib_tap.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/phy/mig_7series_v4_0_ddr_phy_4lanes.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/phy/mig_7series_v4_0_poc_cc.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/phy/mig_7series_v4_0_ddr_phy_tempmon.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/phy/mig_7series_v4_0_ddr_phy_ocd_data.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/phy/mig_7series_v4_0_ddr_phy_rdlvl.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/mig_7series_0_mig_sim.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/ip_top/mig_7series_v4_0_mem_intfc.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/ip_top/mig_7series_v4_0_memc_ui_top_axi.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/ip_top/mig_7series_v4_0_memc_ui_top_std.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/ecc/mig_7series_v4_0_ecc_dec_fix.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/ecc/mig_7series_v4_0_ecc_merge_enc.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/ecc/mig_7series_v4_0_fi_xor.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/ecc/mig_7series_v4_0_ecc_gen.v"]" \
    "[file normalize "./ip/mig_7series_0/user_design/rtl/ecc/mig_7series_v4_0_ecc_buf.v"]" \
]
add_files -norecurse -fileset sim_real_mig $real_mig_sim_files

foreach fset [get_filesets sim*] {
    puts "Preparing configuration for fileset $fset"

    add_files -fileset $fset [file normalize "./da_platform_tb_behav.wcfg"]

    set_property -name "file_type" -value "SystemVerilog" -objects [get_files -of_objects $fset [list "*.sv"]]
    set_property -name "file_type" -value "Verilog Header" -objects [get_files -of_objects $fset [list "*.vh"]]
    
    set_property -name "nl.sdf_anno" -value "0" -objects $fset
    set_property -name "source_set" -value "" -objects $fset
    set_property -name "top" -value "da_platform_tb" -objects $fset
    set_property -name "xsim.simulate.runtime" -value "3000us" -objects $fset
}

set_property -name "verilog_define" -value "USE_WRAPPER USE_MIG_MODEL" -objects [get_fileset sim_fake_mig]
set_property -name "verilog_define" -value "USE_WRAPPER" -objects [get_fileset sim_real_mig]

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

