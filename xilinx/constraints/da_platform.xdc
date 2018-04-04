# fxclk_in - nominal period is 20.833 (48 MHz)
create_clock -period 20.833 -name fxclk_in [get_ports fxclk_in]
set_property PACKAGE_PIN P15 [get_ports fxclk_in]
set_property IOSTANDARD LVCMOS33 [get_ports fxclk_in]

# IFCLK - nominal period is 20.833 (48 MHz)
create_clock -period 20.833 -name ifclk_in [get_ports ifclk_in]
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
set fx2_ports_in [get_ports {fx2_flag* {fx2_fd[*]}}]
set_input_delay -clock ifclk_in -min 0 $fx2_ports_in
set_input_delay -clock ifclk_in -max 12 $fx2_ports_in
set fx2_ports_out [get_ports {fx2_slrd fx2_slwr fx2_sloe fx2_fifoaddr0 fx2_fifoaddr1 fx2_pktend {fx2_fd[*]}}]
set_output_delay -clock ifclk_in -min 0 $fx2_ports_out
set_output_delay -clock ifclk_in -max 12 $fx2_ports_out

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

#   Explicitly name the internally generated clocks
#   The period of 166.664 is 8x that of the 48 MHz fxclk/ifclk, so Vivado knows they're synchronous
create_clock -period 166.664 -name sclk [get_nets main/sclk_ungated]

#   Set I/O delays for remaining signals
set_input_delay -clock sclk -min 0 [get_ports [list {iso\.dirchan} {iso\.hwflag} {iso\.miso}]]
set_input_delay -clock sclk -max 70 [get_ports [list {iso\.dirchan} {iso\.hwflag} {iso\.miso}]]
set_output_delay -clock sclk -min 0 [get_ports [list {iso\.hwcon} {iso\.cs_n} {iso\.mosi}]]
set_output_delay -clock sclk -min 70 [get_ports [list {iso\.hwcon} {iso\.cs_n} {iso\.mosi}]]

set_output_delay -clock ifclk_out -min 0 [get_ports [list {iso\.clksel} {iso\.reset_n}]]
set_output_delay -clock ifclk_out -max 10 [get_ports [list {iso\.clksel} {iso\.reset_n}]]

#   Set contraints for BCK inputs which can be up to... 12.2 MHz for 192 kHz?
create_clock -period 80 -name slot0_bck [get_ports {iso\.slotdata[0]}]
set slot0_data_pins [get_ports [list {iso\.slotdata[1]} {iso\.slotdata[2]} {iso\.slotdata[3]} {iso\.slotdata[4]} {iso\.slotdata[5]}]]
set_input_delay -clock slot0_bck -min 0 $slot0_data_pins
set_input_delay -clock slot0_bck -max 40 $slot0_data_pins
set_output_delay -clock slot0_bck -min 0 $slot0_data_pins
set_output_delay -clock slot0_bck -max 25 $slot0_data_pins

create_clock -period 80 -name slot1_bck [get_ports {iso\.slotdata[6]}]
set slot1_data_pins [get_ports [list {iso\.slotdata[7]} {iso\.slotdata[8]} {iso\.slotdata[9]} {iso\.slotdata[10]} {iso\.slotdata[11]}]]
set_input_delay -clock slot1_bck -min 0 $slot1_data_pins
set_input_delay -clock slot1_bck -max 40 $slot1_data_pins
set_output_delay -clock slot1_bck -min 0 $slot1_data_pins
set_output_delay -clock slot1_bck -max 25 $slot1_data_pins

create_clock -period 80 -name slot2_bck [get_ports {iso\.slotdata[12]}]
set slot2_data_pins [get_ports [list {iso\.slotdata[13]} {iso\.slotdata[14]} {iso\.slotdata[15]} {iso\.slotdata[16]} {iso\.slotdata[17]}]]
set_input_delay -clock slot2_bck -min 0 $slot2_data_pins
set_input_delay -clock slot2_bck -max 40 $slot2_data_pins
set_output_delay -clock slot2_bck -min 0 $slot2_data_pins
set_output_delay -clock slot2_bck -max 25 $slot2_data_pins

create_clock -period 80 -name slot3_bck [get_ports {iso\.slotdata[18]}]
set slot3_data_pins [get_ports [list {iso\.slotdata[19]} {iso\.slotdata[20]} {iso\.slotdata[21]} {iso\.slotdata[22]} {iso\.slotdata[23]}]]
set_input_delay -clock slot3_bck -min 0 $slot3_data_pins
set_input_delay -clock slot3_bck -max 40 $slot3_data_pins
set_output_delay -clock slot3_bck -min 0 $slot3_data_pins
set_output_delay -clock slot3_bck -max 25 $slot3_data_pins

#   Vivado needs to be chill about BCK pins and clock routing.
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets -of_objects [get_pins -of_objects [get_cells -of_objects [get_nets {iso\.slotdata[0]}]] -filter {REF_PIN_NAME == O}]]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets -of_objects [get_pins -of_objects [get_cells -of_objects [get_nets {iso\.slotdata[6]}]] -filter {REF_PIN_NAME == O}]]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets -of_objects [get_pins -of_objects [get_cells -of_objects [get_nets {iso\.slotdata[12]}]] -filter {REF_PIN_NAME == O}]]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets -of_objects [get_pins -of_objects [get_cells -of_objects [get_nets {iso\.slotdata[18]}]] -filter {REF_PIN_NAME == O}]]

set_property IOSTANDARD LVCMOS33 [get_ports iso*]

set_property -dict {DRIVE 8 SLEW SLOW} [get_ports {iso\.slotdata[*]}]
set_property -dict {DRIVE 4 SLEW SLOW} [get_ports {iso\.hwcon}]
set_property -dict {DRIVE 12 SLEW SLOW} [get_ports {iso\.reset_n}]
set_property -dict {DRIVE 12 SLEW SLOW} [get_ports {iso\.clksel}]
set_property -dict {DRIVE 4 SLEW SLOW} [get_ports {iso\.srclk2}]
set_property -dict {DRIVE 4 SLEW SLOW} [get_ports {iso\.srclk}]

set_property -dict {DRIVE 8 SLEW FAST} [get_ports {iso\.cs_n}]
set_property -dict {DRIVE 8 SLEW FAST} [get_ports {iso\.mosi}]
set_property -dict {DRIVE 8 SLEW FAST} [get_ports {iso\.sclk}]

# LED's
set_property PACKAGE_PIN U9 [get_ports {led_debug[0]}]
set_property PACKAGE_PIN V9 [get_ports {led_debug[1]}]
set_property PACKAGE_PIN U8 [get_ports {led_debug[2]}]
set_property PACKAGE_PIN V7 [get_ports {led_debug[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_debug[*]}]
set_property DRIVE 12 [get_ports {led_debug[*]}]

# TIG's
set_clock_groups -group {ifclk_in ifclk_out srclk_sync sclk} -group clk_pll_i -group {clk0 slot0_bck slot1_bck slot2_bck slot3_bck} -asynchronous

# bitstream settings
set_property BITSTREAM.CONFIG.CONFIGRATE 66 [current_design]
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR No [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 2 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS true [current_design]


