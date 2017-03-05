# fxclk_in
create_clock -period 20.833 -name fxclk_in [get_ports fxclk_in]
set_property PACKAGE_PIN P15 [get_ports fxclk_in]
set_property IOSTANDARD LVCMOS33 [get_ports fxclk_in]

# IFCLK
create_clock -period 20.833 -name ifclk_in [get_ports ifclk_in]
#create_clock -name ifclk_in -period 33.333 [get_ports ifclk_in]
set_property PACKAGE_PIN P17 [get_ports ifclk_in]
set_property IOSTANDARD LVCMOS33 [get_ports ifclk_in]

# PA7/FLAGD/SLCS#
set_property PACKAGE_PIN T10 [get_ports reset]
set_property IOSTANDARD LVCMOS33 [get_ports reset]

# PB[0..9], PD[0..7]
set_property PACKAGE_PIN M16 [get_ports {fx2_fd[0]}]
set_property PACKAGE_PIN L16 [get_ports {fx2_fd[1]}]
set_property PACKAGE_PIN L14 [get_ports {fx2_fd[2]}]
set_property PACKAGE_PIN M14 [get_ports {fx2_fd[3]}]
set_property PACKAGE_PIN L18 [get_ports {fx2_fd[4]}]
set_property PACKAGE_PIN M18 [get_ports {fx2_fd[5]}]
set_property PACKAGE_PIN R12 [get_ports {fx2_fd[6]}]
set_property PACKAGE_PIN R13 [get_ports {fx2_fd[7]}]
set_property PACKAGE_PIN T9 [get_ports {fx2_fd[8]}]
set_property PACKAGE_PIN V10 [get_ports {fx2_fd[9]}]
set_property PACKAGE_PIN U11 [get_ports {fx2_fd[10]}]
set_property PACKAGE_PIN V11 [get_ports {fx2_fd[11]}]
set_property PACKAGE_PIN V12 [get_ports {fx2_fd[12]}]
set_property PACKAGE_PIN U13 [get_ports {fx2_fd[13]}]
set_property PACKAGE_PIN U14 [get_ports {fx2_fd[14]}]
set_property PACKAGE_PIN V14 [get_ports {fx2_fd[15]}]

# CTL0/FLAGA
set_property PACKAGE_PIN N16 [get_ports fx2_flaga]

# CTL1/FLAGB
set_property PACKAGE_PIN N15 [get_ports fx2_flagb]

# PA2/SLOE
set_property PACKAGE_PIN T14 [get_ports fx2_sloe]

# PA4/FIFOADR0
set_property PACKAGE_PIN R11 [get_ports fx2_fifoaddr0]

# PA5/FIFOADR1
set_property PACKAGE_PIN T11 [get_ports fx2_fifoaddr1]

# PA6/PKTEND
set_property PACKAGE_PIN R10 [get_ports fx2_pktend]

# RDY0/SLRD
set_property PACKAGE_PIN V16 [get_ports fx2_slrd]

# RDY1/SLWR
set_property PACKAGE_PIN U16 [get_ports fx2_slwr]
#set_property DRIVE 4 [get_ports SLWR]
#set_property SLEW FAST [get_ports SLWR]

set_property IOSTANDARD LVCMOS33 [get_ports fx2_*]
set_property DRIVE 4 [get_ports {fx2_fd[*]}]
set_input_delay -clock ifclk_in -min 0.000 [get_ports {fx2_flag* {fx2_fd[*]}}]
set_input_delay -clock ifclk_in -max 14.000 [get_ports {fx2_flag* {fx2_fd[*]}}]
set_output_delay -clock ifclk_in -min 0.000 [get_ports {fx2_slrd fx2_slwr}]
set_output_delay -clock ifclk_in -max 14.000 [get_ports {fx2_slrd fx2_slwr}]

# Isolator interface
set_property PACKAGE_PIN M4 [get_ports {iso\.mclk}]
set_property PACKAGE_PIN N4 [get_ports {iso\.amcs}]
set_property PACKAGE_PIN M3 [get_ports {iso\.amdi}]
set_property PACKAGE_PIN M2 [get_ports {iso\.amdo}]
set_property PACKAGE_PIN K5 [get_ports {iso\.dmcs}]
set_property PACKAGE_PIN L4 [get_ports {iso\.dmdi}]
set_property PACKAGE_PIN L3 [get_ports {iso\.dmdo}]
set_property PACKAGE_PIN K3 [get_ports {iso\.dirchan}]
set_property PACKAGE_PIN R2 [get_ports {iso\.acon[1]}]
set_property PACKAGE_PIN P2 [get_ports {iso\.acon[0]}]
set_property PACKAGE_PIN R1 [get_ports {iso\.aovf}]
set_property PACKAGE_PIN N2 [get_ports {iso\.clk0}]
set_property PACKAGE_PIN L1 [get_ports {iso\.reset_out}]
set_property PACKAGE_PIN M1 [get_ports {iso\.srclk}]
set_property PACKAGE_PIN N1 [get_ports {iso\.clksel}]
set_property PACKAGE_PIN T1 [get_ports {iso\.clk1}]
set_property PACKAGE_PIN N6 [get_ports {iso\.slotdata[11]}]
set_property PACKAGE_PIN M6 [get_ports {iso\.slotdata[10]}]
set_property PACKAGE_PIN U2 [get_ports {iso\.slotdata[9]}]
set_property PACKAGE_PIN K6 [get_ports {iso\.slotdata[8]}]
set_property PACKAGE_PIN R5 [get_ports {iso\.slotdata[7]}]
set_property PACKAGE_PIN V2 [get_ports {iso\.slotdata[6]}]
set_property PACKAGE_PIN N5 [get_ports {iso\.slotdata[5]}]
set_property PACKAGE_PIN P5 [get_ports {iso\.slotdata[4]}]
set_property PACKAGE_PIN R3 [get_ports {iso\.slotdata[3]}]
set_property PACKAGE_PIN T3 [get_ports {iso\.slotdata[2]}]
set_property PACKAGE_PIN U1 [get_ports {iso\.slotdata[1]}]
set_property PACKAGE_PIN V1 [get_ports {iso\.slotdata[0]}]

#   Make it clear that clk0 and clk1 are clocks at up to 25 MHz.
create_clock -period 40 -name clk0 [get_ports {iso\.clk0}]
create_clock -period 40 -name clk1 [get_ports {iso\.clk1}]

#   Unused pins of isolator interface go to unused IOs
set_property PACKAGE_PIN U6 [get_ports {iso\.slotdata[23]}]
set_property PACKAGE_PIN V5 [get_ports {iso\.slotdata[22]}]
set_property PACKAGE_PIN T8 [get_ports {iso\.slotdata[21]}]
set_property PACKAGE_PIN V4 [get_ports {iso\.slotdata[20]}]
set_property PACKAGE_PIN R8 [get_ports {iso\.slotdata[19]}]
set_property PACKAGE_PIN T5 [get_ports {iso\.slotdata[18]}]
set_property PACKAGE_PIN R7 [get_ports {iso\.slotdata[17]}]
set_property PACKAGE_PIN T4 [get_ports {iso\.slotdata[16]}]
set_property PACKAGE_PIN T6 [get_ports {iso\.slotdata[15]}]
set_property PACKAGE_PIN U4 [get_ports {iso\.slotdata[14]}]
set_property PACKAGE_PIN R6 [get_ports {iso\.slotdata[13]}]
set_property PACKAGE_PIN U3 [get_ports {iso\.slotdata[12]}]

set_property IOSTANDARD LVCMOS33 [get_ports iso*]

# LED's
set_property PACKAGE_PIN U9 [get_ports {led_debug[0]}]
set_property PACKAGE_PIN V9 [get_ports {led_debug[1]}]
set_property PACKAGE_PIN U8 [get_ports {led_debug[2]}]
set_property PACKAGE_PIN V7 [get_ports {led_debug[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_debug[*]}]
set_property DRIVE 12 [get_ports {led_debug[*]}]


# TIG's
set_false_path -from [get_clocks *ifclk_out] -to [get_clocks *clk200_in]
set_false_path -from [get_clocks *ifclk_out] -to [get_clocks]
set_false_path -from [get_clocks *clk_pll_i] -to [get_clocks *ifclk_out]

# bitstream settings
set_property BITSTREAM.CONFIG.CONFIGRATE 66 [current_design]
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR No [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 2 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS true [current_design]


