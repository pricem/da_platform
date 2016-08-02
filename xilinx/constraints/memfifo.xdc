# fxclk_in
create_clock -period 20.833 -name fxclk_in [get_ports fxclk_in]
set_property PACKAGE_PIN P15 [get_ports fxclk_in]
set_property IOSTANDARD LVCMOS33 [get_ports fxclk_in]

# IFCLK
create_clock -period 20.833 -name ifclk_in [get_ports ifclk_in]
#create_clock -name ifclk_in -period 33.333 [get_ports ifclk_in]
set_property PACKAGE_PIN P17 [get_ports ifclk_in]
set_property IOSTANDARD LVCMOS33 [get_ports ifclk_in]

# GPIO
set_property PACKAGE_PIN R15 [get_ports gpio_clk]
set_property PACKAGE_PIN T15 [get_ports gpio_dir]
set_property PACKAGE_PIN T13 [get_ports gpio_dat]
set_property PULLUP true [get_ports gpio_dat]
set_property IOSTANDARD LVCMOS33 [get_ports gpio_*]

# PA7/FLAGD/SLCS#
set_property PACKAGE_PIN T10 [get_ports reset]
set_property IOSTANDARD LVCMOS33 [get_ports reset]

# PB[0..9], PD[0..7]
set_property PACKAGE_PIN M16 [get_ports {fd[0]}]
set_property PACKAGE_PIN L16 [get_ports {fd[1]}]
set_property PACKAGE_PIN L14 [get_ports {fd[2]}]
set_property PACKAGE_PIN M14 [get_ports {fd[3]}]
set_property PACKAGE_PIN L18 [get_ports {fd[4]}]
set_property PACKAGE_PIN M18 [get_ports {fd[5]}]
set_property PACKAGE_PIN R12 [get_ports {fd[6]}]
set_property PACKAGE_PIN R13 [get_ports {fd[7]}]
set_property PACKAGE_PIN T9 [get_ports {fd[8]}]
set_property PACKAGE_PIN V10 [get_ports {fd[9]}]
set_property PACKAGE_PIN U11 [get_ports {fd[10]}]
set_property PACKAGE_PIN V11 [get_ports {fd[11]}]
set_property PACKAGE_PIN V12 [get_ports {fd[12]}]
set_property PACKAGE_PIN U13 [get_ports {fd[13]}]
set_property PACKAGE_PIN U14 [get_ports {fd[14]}]
set_property PACKAGE_PIN V14 [get_ports {fd[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fd[*]}]
set_property DRIVE 4 [get_ports {fd[*]}]

# CTL0/FLAGA
set_property PACKAGE_PIN N16 [get_ports FLAGA]
set_property IOSTANDARD LVCMOS33 [get_ports FLAGA]

# CTL1/FLAGB
set_property PACKAGE_PIN N15 [get_ports FLAGB]
set_property IOSTANDARD LVCMOS33 [get_ports FLAGB]

# PA2/SLOE
set_property PACKAGE_PIN T14 [get_ports SLOE]
set_property IOSTANDARD LVCMOS33 [get_ports SLOE]

# PA4/FIFOADR0
set_property PACKAGE_PIN R11 [get_ports FIFOADDR0]
set_property IOSTANDARD LVCMOS33 [get_ports FIFOADDR0]

# PA5/FIFOADR1
set_property PACKAGE_PIN T11 [get_ports FIFOADDR1]
set_property IOSTANDARD LVCMOS33 [get_ports FIFOADDR1]

# PA6/PKTEND
set_property PACKAGE_PIN R10 [get_ports PKTEND]
set_property IOSTANDARD LVCMOS33 [get_ports PKTEND]

# RDY0/SLRD
set_property PACKAGE_PIN V16 [get_ports SLRD]
set_property IOSTANDARD LVCMOS33 [get_ports SLRD]

# RDY1/SLWR
set_property PACKAGE_PIN U16 [get_ports SLWR]
set_property IOSTANDARD LVCMOS33 [get_ports SLWR]
#set_property DRIVE 4 [get_ports SLWR]
#set_property SLEW FAST [get_ports SLWR]

# I/O delays
set_input_delay -clock ifclk_in -min 0.000 [get_ports {FLAG* {fd[*]}}]
set_input_delay -clock ifclk_in -max 14.000 [get_ports {FLAG* {fd[*]}}]
set_output_delay -clock ifclk_in -min 0.000 [get_ports {SLRD SLWR}]
set_output_delay -clock ifclk_in -max 14.000 [get_ports {SLRD SLWR}]

# LED's
set_property PACKAGE_PIN H15 [get_ports {led1[0]}]
set_property PACKAGE_PIN J13 [get_ports {led1[1]}]
set_property PACKAGE_PIN J14 [get_ports {led1[2]}]
set_property PACKAGE_PIN H14 [get_ports {led1[3]}]
set_property PACKAGE_PIN H17 [get_ports {led1[4]}]
set_property PACKAGE_PIN G14 [get_ports {led1[5]}]
set_property PACKAGE_PIN G17 [get_ports {led1[6]}]
set_property PACKAGE_PIN G16 [get_ports {led1[7]}]
set_property PACKAGE_PIN G18 [get_ports {led1[8]}]
set_property PACKAGE_PIN H16 [get_ports {led1[9]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led1[*]}]
set_property DRIVE 12 [get_ports {led1[*]}]

set_property PACKAGE_PIN U9 [get_ports {led2[0]}]
set_property PACKAGE_PIN V9 [get_ports {led2[1]}]
set_property PACKAGE_PIN U8 [get_ports {led2[2]}]
set_property PACKAGE_PIN V7 [get_ports {led2[3]}]
set_property PACKAGE_PIN U7 [get_ports {led2[4]}]
set_property PACKAGE_PIN V6 [get_ports {led2[5]}]
set_property PACKAGE_PIN U6 [get_ports {led2[6]}]
set_property PACKAGE_PIN V5 [get_ports {led2[7]}]
set_property PACKAGE_PIN T8 [get_ports {led2[8]}]
set_property PACKAGE_PIN V4 [get_ports {led2[9]}]
set_property PACKAGE_PIN R8 [get_ports {led2[10]}]
set_property PACKAGE_PIN T5 [get_ports {led2[11]}]
set_property PACKAGE_PIN R7 [get_ports {led2[12]}]
set_property PACKAGE_PIN T4 [get_ports {led2[13]}]
set_property PACKAGE_PIN T6 [get_ports {led2[14]}]
set_property PACKAGE_PIN U4 [get_ports {led2[15]}]
set_property PACKAGE_PIN R6 [get_ports {led2[16]}]
set_property PACKAGE_PIN U3 [get_ports {led2[17]}]
set_property PACKAGE_PIN R5 [get_ports {led2[18]}]
set_property PACKAGE_PIN V1 [get_ports {led2[19]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led2[*]}]
set_property DRIVE 12 [get_ports {led2[*]}]

# switches
#set_property PACKAGE_PIN F18 [get_ports SW7]		;# A11 / B18~IO_L11N_T1_SRCC_16
set_property PACKAGE_PIN F16 [get_ports SW8]
#set_property PACKAGE_PIN E18 [get_ports SW9]		;# A12 / B17~IO_L11P_T1_SRCC_16
set_property PACKAGE_PIN F15 [get_ports SW10]
set_property IOSTANDARD LVCMOS33 [get_ports SW*]
set_property PULLUP true [get_ports SW10]
set_property PULLUP true [get_ports SW8]

# TIG's
set_false_path -from [get_clocks *ifclk_out] -to [get_clocks *clk200_in]
set_false_path -from [get_clocks *ifclk_out] -to [get_clocks]
set_false_path -from [get_clocks *clk_pll_i] -to [get_clocks *ifclk_out]

# bitstream settings
set_property BITSTREAM.CONFIG.CONFIGRATE 66 [current_design]
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR No [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 2 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS true [current_design]


