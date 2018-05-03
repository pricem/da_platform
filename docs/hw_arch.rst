Hardware architecture
---------------------

The platform is divided into several components on PCBs.  Different functions may be implemented on each PCB, but the interfaces should stay the same to keep them interoperable.  These PCBs are illustrated in the figure below.

.. image:: figures/hw_arch.*
    :width: 100%

The following sections briefly describe the function of each PCB and their interfaces to the other PCBs.

**Modules**: An audio ADC or DAC.  The basic requirement of a module is an I2S input (or output).  The module interface provides for:

* Up to 4 lanes of I2S data (nominally 8 channels of audio)
* Regulated and unregulated power supplies
* SPI interface for software control of audio converters and other peripherals
* GPIO interface: 8 bits in and 8 bits out

If you design a new module complying to the module interface specification, you can write some high-level software to control it, but won't have to change any of the other links in the chain.

**Carrier**: A digital source/sink for the signals that go to each module.  Can include or interface to a computing device (whether embedded or separate) to improve flexibility.  Carriers don't necessarily have to support every possible feature.

**Backplane**: Interconnect between the carrier and the modules.  Also distributes power from the PSU to the modules.  The carrier can be powered by the same power supply as the modules, or have its own power supply.  The backplane also contains supply regulators for any modules that don't have local regulation.

**Clock source**: Supply of the necessary clocks for audio converters, at a nominal frequency of 22.5792 MHz or 24.576 MHz.  Clocks are distributed differentially by the backplane.  The clock source has separate output pins for 5 loads: one for each of the four modules, and one for the carrier.

**PSU**: An unregulated power supply.  Generates separate +7 V rails for the digital and analog sections, and +/- 22 V rails for the analog sections of modules.

.. include:: boards.rst

.. include:: interfaces.rst

.. include:: digital.rst
