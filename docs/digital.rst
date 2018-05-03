Digital design
==============

The baseline carrier design includes an FPGA, which gives it a lot of flexibility.  This section describes the digital logic that runs on the FPGA, providing up to 32 channels of audio I/O through asynchronous FIFOs, and allowing a host computer to exercise all module features via USB.

The logic is defined in SystemVerilog hardware description language (HDL).  Any future improvements will be shared with users who can simply reprogram their boards.  The design could also be retargeted to other carrier boards.  Please see the ``verilog`` directory of the repository for design and simulation sources, and the ``xilinx`` directory for build scripts.  

I started out with the `ZTEX USB-FPGA 2.13a board <https://www.ztex.de/usb-fpga-2/usb-fpga-2.13.e.html>`_, which has all of the necessary features and comes with an elegant and open-source software/firmware stack for delivering data to and from the custom logic via USB.  It is also affordable compared to other FPGA boards with similar capabilities.

The primary function of this design is to provide a bridge between a computing device and the physical interfaces (I2S, SPI, and GPIO) of the four DAC/ADC modules.  (From a digital design perspective, it would be easy to change the number of modules at build time.)  For now we are using a USB interface for the host computer, but other interfaces could be added in the future; for example, audio could be streamed over Ethernet, or control commands could be sent over a UART or SPI.

The architecture is shown in the following diagram.

.. image:: figures/digital_design.*
	:width: 100%

Each module interfaces with a "slot controller" which accepts commands and audio samples specific to that module.  The audio sample I/Os are 32 bits wide and the stream of samples can be rearranged according to runtime configuration (number of channels, I2S vs. left-justified vs. right-justified, etc).  The command interface is 8 bits wide; commands are encoded into a stream of bytes, with the first byte representing the type of command and the remaining bytes containing parameters/arguments.

Data sent over USB (broken into 16-bit words) is directed to the command handler, a state machine which examines each word and takes the appropriate action.  There are some global commands which can be dealt with immediately by the command handler, for example the command to reset all of the modules.  Other commands are addressed to a specific module and thus are delivered to the appropriate slot controller; the response is returned to the host.  

Audio samples are handled differently: we want to provide a large buffer (FIFO) so the software on the host doesn't need to keep up with the exact timing of playback or recording.  A single buffer isn't enough since there are four modules, each of which could be functioning as a DAC or ADC, or not being used at all.  But with some massaging, we can use a single fast memory (DDR3) to provide a set of 8 virtual FIFOs (one in each direction for each module).  Access to this external memory is controlled by a block called the FIFO arbiter.  To the outside world, it looks like we have several independent FIFOs.  On the ZTEX FPGA board, the DDR3 memory is 256 MB, so each virtual FIFO is big enough for 8M samples--more than a minute of stereo audio at 44.1 kHz.

There are three clock domains in the design.  

1. The USB interface provides a 48 MHz clock.  The command handler and most of the control logic is driven by this clock; it is divided down to 3 MHz for SPI and GPIO signals.
2. The DAC/ADC modules run on a clock that is a multiple of the audio sample rate.  Nominally this is 22.5792 MHz or 24.576 MHz.  This clock must have very low phase noise at the DAC or ADC itself, but the data signals to/from the carrier don't need any special treatment as long as they meet the timing constraints of the chips they are talking to.  
3. The DDR3 memory runs on a faster clock (nominally 400 MHz).  Interfacing to this memory is handled by a specialized IP block provided by the FPGA vendor.

Within the design, synchronizers and asynchronous FIFOs are used to transfer signals between different clock domains.
