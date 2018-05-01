Interfaces
----------

This section describes the electrical interfaces in the initial version of the DA platform.  The idea is that different PCBs can be designed for each function (carrier, backplane, modules, etc.) and safely interchanged if they meet the interface specifications.  All of the board-to-board connections are made with standard 0.1" pitch headers.  It's possible to stack boards, or (except for modules) to put the boards side by side and make the connection with an appropriately sized ribbon cable.

** PSU to backplane ** : 12 pins (6x2 header)

In the baseline design, the PSU has transformers directly screwed to the chassis, and a small rectifier/filter board that mounts to the right of the backplane.  They are connected via a ribbon cable.

TODO: image of pins in proper orientation

.. table:: PSU interface pins

==========	====	===========
Pin number	Name	Description
==========  ====	===========
1			D7VU	Unregulated +7 V for digital section
2			DGND	Digital ground
3			D7VU	Unregulated +7 V for digital section
4			DGND	Digital ground
5			A7VU	Unregulated +7 V for analog section
6			AGND	Analog ground
7			A7VU	Unregulated +7 V for analog section
8			AGND	Analog ground
9			AP22VU	Unregulated +22 V for analog section
10			AGND	Analog ground
11			AN22VU	Unregulated -22 V for analog section
12			AGND	Analog ground
==========  ====	===========

** Carrier to backplane ** :

In the baseline design, the backplane has a female header on top, and the carrier has a male header on the bottom.  The carrier stacks on top of the backplane.


TODO: image of pins in proper orientation

.. table:: Carrier interface pins

==========	====		===========
Pin number	Name		Description
==========  ====		===========
1			S0_LRCK		I2S word clock for module slot 0
2			S0_BCK		I2S bit clock for module slot 0
3			S0_D1		I2S data lane 1 for module slot 0
4			S0_D0		I2S data lane 0 for module slot 0
5			S0_D3		I2S data lane 3 for module slot 0
6			S0_D2		I2S data lane 2 for module slot 0
7			DGND		Digital ground
8			DGND		Digital ground
9			S1_LRCK		I2S word clock for module slot 1
10			S1_BCK		I2S bit clock for module slot 1
11			S1_D1		I2S data lane 1 for module slot 1
12			S1_D0		I2S data lane 0 for module slot 1
13			S1_D3		I2S data lane 3 for module slot 1
14			S1_D2		I2S data lane 2 for module slot 1
15			DGND		Digital ground
16			DGND		Digital ground
17			S2_LRCK		I2S word clock for module slot 2
18			S2_BCK		I2S bit clock for module slot 2
19			S2_D1		I2S data lane 1 for module slot 2
20			S2_D0		I2S data lane 0 for module slot 2
21			S2_D3		I2S data lane 3 for module slot 2
22			S2_D2		I2S data lane 2 for module slot 2
23			DGND		Digital ground
24			DGND		Digital ground
25			S3_LRCK		I2S word clock for module slot 3
26			S3_BCK		I2S bit clock for module slot 3
27			S3_D1		I2S data lane 1 for module slot 3
28			S3_D0		I2S data lane 0 for module slot 3
29			S3_D3		I2S data lane 3 for module slot 3
30			S3_D2		I2S data lane 2 for module slot 3
31			DGND		Digital ground
32			DGND		Digital ground
33			HWFLAG		Serialized GPIO input from modules
34			HWCON		Serialized GPIO output to modules
35			CS_n		Serialized SPI chip select (active low)
36			DIRCHAN		Serialized module configuration indicator
37			SRCLK2		2nd level (64 bit) deserializer clock
38			SRCLK		1st level (8 bit) deserializer clock
39			MOSI		SPI data output to modules
40			MISO		SPI data input from modules
41			DGND		Digital ground
42			CLKSEL		Clock select (e.g. 22.5792 vs. 24.576 MHz)
43			SCLK		SPI and serializer clock
44			RESET_n		Module reset (active low)
45			DGND		Digital ground
46			C3V3		3.3 V digital supply from carrier
47			MCLK		Audio clock for I2S masters
48			C3V3		3.3 V digital supply from carrier
==========  ====		===========

** Clock source to backplane ** :

In the baseline design, the backplane has a female header on top, and the clock source has a male header on the bottom.  The clock source stacks on top of the backplane, hanging over the lower edge.


TODO: image of pins in proper orientation

.. table:: Clock source interface pins

==========	====		===========
Pin number	Name		Description
==========  ====		===========
1			D7VU		Unregulated 7 V supply
2			DGND		Ground
3			DGND		Ground
4			S0_MCLKP	Differential clock output to module slot 0
5			DGND		Ground
6			S0_MCLKP	Differential clock output to module slot 0
7			D7VU		Unregulated 7 V supply
8			DGND		Ground
9			DGND		Ground
10			S1_MCLKP	Differential clock output to module slot 1
11			DGND		Ground
12			S1_MCLKP	Differential clock output to module slot 1
13			D3V3		Regulated 3.3 V supply
14			DGND		Ground
15			DGND		Ground
16			S2_MCLKP	Differential clock output to module slot 2
17			DGND		Ground
18			S2_MCLKP	Differential clock output to module slot 2
19			D3V3		Regulated 3.3 V supply
20			DGND		Ground
21			DGND		Ground
22			S3_MCLKP	Differential clock output to module slot 3
23			DGND		Ground
24			S3_MCLKP	Differential clock output to module slot 3
25			D3V3		Regulated 3.3 V supply
26			DGND		Ground
27			DGND		Ground
28			C_MCLKP		Differential clock output to carrier
29			DGND		Ground
30			C_MCLKP		Differential clock output to carrier
31			CLKSEL		Selects active oscillator (22.5792 or 24.576 MHz)
32			DGND		Ground
==========  ====	===========

** Module to backplane ** : 54 pins (2x 27x1 header, with 2.0" spacing)

The module has some additional mechanical requirements because they sit on top of the backplane.  

TODO: Drawing of mechanical footprint of module

If you can't fit all the necessary circuitry on one board of this size, consider vertical stacking.  You could also design an extra-wide module that takes up 2, 3, or 4 slots.

TODO: image of pins in proper orientation

.. table:: Module interface pins

==========	====		===========
Pin number	Name		Description
==========  ====		===========
1L			AP15V		Regulated +15 V supply for analog section
2L			AGND		Analog ground
3L			AGND		Analog ground
4L			AN15V		Regulated -15 V supply for analog section
5L			AGND		Analog ground
6L			A5V			Regulated 5 V supply for analog section
7L			D3V3		Regulated 3.3 V supply for digital section
8L			DGND		Digital ground
9L			BCK			I2S bit clock
10L			DGND		Digital ground
11L			LRCK		I2S word clock
12L			SDATA0		I2S data lane 0
13L			SDATA1		I2S data lane 1
14L			SDATA2		I2S data lane 2
15L			SDATA3		I2S data lane 3
16L			DGND		Digital ground
17L			CS_n		SPI chip select (active low)
18L			MOSI		SPI data input
19L			MISO		SPI data output
20L			DGND		Digital ground
21L			D7VU		Unregulated 7 V supply for digital section
22L			A7VU		Unregulated 7 V supply for analog section
23L			AGND		Analog ground
24L			AN22VU		Unregulated -22 V supply for analog section
25L			AGND		Analog ground
26L			AGND		Analog ground
27L			AP22VU		Unregulated +22 V supply for analog section
==========  ====	===========
1R			AP15V		Regulated +15 V supply for analog section
2R			AGND		Analog ground
3R			AGND		Analog ground
4R			AN15V		Regulated -15 V supply for analog section
5R			AGND		Analog ground
6R			A5V			Regulated 5 V supply for analog section
7R			D3V3		Regulated 3.3 V supply for digital section
8R			DGND		Digital ground
9R			HWCON		Serialized GPIO input
10R			HWFLAG		Serialized GPIO output	
11R			DIR			Module direction: 1 = DAC, 0 = ADC
12R			CHAN		Number of channels: 1 = 8-ch, 0 = 2-ch
13R			SCLK		SPI and serializer clock
14R			SRCLK		1st level deserializer clock
15R			SRCLK2		2nd level deserializer clock
16R			RESET_n		Reset (active low)
17R			DGND		Digital ground
18R			MCLKN		Differential audio clock input
19R			MCLKP		Differential audio clock input
20R			DGND		Digital ground
21R			D7VU		Unregulated 7 V supply for digital section
22R			A7VU		Unregulated 7 V supply for analog section
23R			AGND		Analog ground
24R			AN22VU		Unregulated -22 V supply for analog section
25R			AGND		Analog ground
26R			AGND		Analog ground
27R			AP22VU		Unregulated +22 V supply for analog section
==========  ====	===========