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

#   New pin assignments as of 8/8/2017
set_property PACKAGE_PIN F18 [get_ports {iso\.hwflag}]
set_property PACKAGE_PIN F16 [get_ports {iso\.hwcon}]
set_property PACKAGE_PIN G17 [get_ports {iso\.cs_n}]
set_property PACKAGE_PIN G16 [get_ports {iso\.dirchan}]
set_property PACKAGE_PIN H17 [get_ports {iso\.srclk2}]
set_property PACKAGE_PIN G14 [get_ports {iso\.srclk}]
set_property PACKAGE_PIN J14 [get_ports {iso\.mosi}]
set_property PACKAGE_PIN H14 [get_ports {iso\.miso}]
set_property PACKAGE_PIN J13 [get_ports {iso\.clksel}]
set_property PACKAGE_PIN J15 [get_ports {iso\.sclk}]
set_property PACKAGE_PIN K13 [get_ports {iso\.reset_n}]
set_property PACKAGE_PIN H16 [get_ports {iso\.mclk}]

set_property PACKAGE_PIN E18 [get_ports {iso\.slotdata[23]}]
set_property PACKAGE_PIN F15 [get_ports {iso\.slotdata[22]}]
set_property PACKAGE_PIN D18 [get_ports {iso\.slotdata[21]}]
set_property PACKAGE_PIN E17 [get_ports {iso\.slotdata[20]}]
set_property PACKAGE_PIN G13 [get_ports {iso\.slotdata[19]}]
set_property PACKAGE_PIN D17 [get_ports {iso\.slotdata[18]}]

set_property PACKAGE_PIN F13 [get_ports {iso\.slotdata[17]}]
set_property PACKAGE_PIN F14 [get_ports {iso\.slotdata[16]}]
set_property PACKAGE_PIN E16 [get_ports {iso\.slotdata[15]}]
set_property PACKAGE_PIN E15 [get_ports {iso\.slotdata[14]}]
set_property PACKAGE_PIN C17 [get_ports {iso\.slotdata[13]}]
set_property PACKAGE_PIN C16 [get_ports {iso\.slotdata[12]}]

set_property PACKAGE_PIN C15 [get_ports {iso\.slotdata[11]}]
set_property PACKAGE_PIN D15 [get_ports {iso\.slotdata[10]}]
set_property PACKAGE_PIN B17 [get_ports {iso\.slotdata[9]}]
set_property PACKAGE_PIN B16 [get_ports {iso\.slotdata[8]}]
set_property PACKAGE_PIN C14 [get_ports {iso\.slotdata[7]}]
set_property PACKAGE_PIN D14 [get_ports {iso\.slotdata[6]}]

set_property PACKAGE_PIN A16 [get_ports {iso\.slotdata[5]}]
set_property PACKAGE_PIN A15 [get_ports {iso\.slotdata[4]}]
set_property PACKAGE_PIN B14 [get_ports {iso\.slotdata[3]}]
set_property PACKAGE_PIN B13 [get_ports {iso\.slotdata[2]}]
set_property PACKAGE_PIN B12 [get_ports {iso\.slotdata[1]}]
set_property PACKAGE_PIN C12 [get_ports {iso\.slotdata[0]}]

#   Make it clear that mclk input is a clock at up to 25 MHz.
#   And that it's unrelated to the USB clock.
create_clock -period 40 -name clk0 [get_ports {iso\.mclk}]
set_false_path -from [get_clocks clk0] -to [get_clocks ifclk_out]
set_false_path -to [get_clocks clk0] -from [get_clocks ifclk_out]

#   Vivado needs to be chill about BCK pins and clock routing.
#set_property CLOCK_DEDICATED_ROUTE FALSE [get_ports {iso\.slotdata[0]}
#set_property CLOCK_DEDICATED_ROUTE FALSE [get_ports {iso\.slotdata[6]}
#set_property CLOCK_DEDICATED_ROUTE FALSE [get_ports {iso\.slotdata[12]}
#set_property CLOCK_DEDICATED_ROUTE FALSE [get_ports {iso\.slotdata[18]}
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets main/slots[0].ctl/slot_data_IOBUF[0]_inst/O]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets main/slots[1].ctl/slot_data_IOBUF[0]_inst/O]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets main/slots[2].ctl/slot_data_IOBUF[0]_inst/O]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets main/slots[3].ctl/slot_data_IOBUF[0]_inst/O]

set_property IOSTANDARD LVCMOS33 [get_ports iso*]
set_property DRIVE 4 [get_ports {iso\.slotdata[*]}]

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


