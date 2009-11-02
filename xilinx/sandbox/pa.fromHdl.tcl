
# PlanAhead Launch Script for Pre-Synthesis Floorplanning, created by Project Navigator

hdi::project new -name sandbox -dir "C:/projects/cdp/xilinx/sandbox/patmp"
hdi::project setArch -name sandbox -arch spartan3e
hdi::design setOptions -project sandbox -top nexys2_toplevel  
hdi::param set -name project.paUcfFile -svalue "nexys2_toplevel.ucf"
hdi::floorplan new -name floorplan_1 -part xc3s500efg320-5 -project sandbox
hdi::port import -project sandbox \
    -verilog {sandbox1.v work} \
    -verilog {toplevel.v work}
hdi::port export -project sandbox -file sandbox_pa_ports.v -format verilog
hdi::pconst import -project sandbox -floorplan floorplan_1 -file "nexys2_toplevel.ucf"
