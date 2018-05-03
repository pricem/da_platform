Introduction
----------

Motivation
==========

There are many options for DIY digital audio, especially 2-channel DACs.  
You can buy complete kits or building blocks like USB I2S interfaces, power supplies, and DAC boards.
But there are some more complicated choices and compromises to make for other applications, like home theather, digital crossovers, music recording, and measurements.
This project aims to provide a common platform to support this variety of applications with minimal hardware or software re-design.
All of its PCB designs, FPGA firmware, and software code are open-source and included in the GitHub repository.

Features
========

The baseline design allows you to build a box with up to 32 channels of audio I/O at standard sample rates (44.1--192 kHz).  The main capabilities I pursued are: 

- **Removable DAC/ADC modules with a common mechanical and electrical specification**

  The modules can be swapped out based on system configuration needs, budget limitations, or listening preferences.
  DIYers can contribute novel converter and analog designs by designing a module, without "reinventing the wheel" for everything else.
  The platform carries up to 4 modules with up to 8 channels each.
  PCB designs are provided for 2-channel and 8-channel DACs and ADCs with recent AKM parts.

- **Support for FPGA-based asynchronous FIFO**

  The digital interfaces in the platform can be controlled by a ZTEX USB-FPGA 2.13a board containing a Xilinx XC7A35T FPGA and 256 MB of DRAM.
  I provide firmware for the FPGA to act as a set of large asynchronous FIFOs in both directions.
  This allows the use of a local master clock and makes performance independent of software and USB behavior.
  
- **Support for built-in music streaming server and real-time FIR filtering using Raspberry Pi**

  The Raspberry Pi can connect to a wired or wireless Ethernet network.
  MPD is used as a music server that can be controlled by an Android mobile app.
  It can play music stored on another computer or NAS, and stream music from another device.
  ALSA configuration options allow some channels to be directed through the speakers library or another filtering engine.

- **Support for galvanic isolation of modules**

  The complex digital portions of the system (typically Raspberry Pi and FPGA) have a separate power supply from the modules and clock sources.
  Digital signals (e.g. I2S, SPI) are routed through Analog Devices transformer isolators which allow these supplies to use separate grounds.
  The purpose of this is to reduce the currents flowing in the grounds (both digital and analog) used by the modules and clock sources.

- **Stuffing options for different budgets**

  In order to broaden the accessibility of this platform, different versions can be built with different capabilities.
  The only constant is the underlying PCBs, which are inexpensive.
  If an asynchronous FIFO and low-jitter clocking are not needed, a USBStreamer or Ministreamer I2S interface could be used.
  The baseline backplane can be built with jumpers in place of the galvanic isolators.
  Different DAC and ADC modules, clock sources, power supplies, and chassis can also be chosen for the desired system cost.

- **Moderate performance limitations**

  This platform probably won't achieve the same performance as a carefully designed and tweaked, purpose-built setup for a particular application.
  However, I believe it can get close.
  The backplane PCB does not carry analog audio signals.
  EMI can be suppressed by installing a conductive divider that places the ADC/DAC modules in a Faraday cage.
  Modules can provide their own supply regulation.
  The differential clock distribution scheme limits excess phase noise added to that of the clock sources.

These features are justified and explained in more detail in the following sections.
