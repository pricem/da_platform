Boards designed so far
======================

This section describes the features of the PCB designs that have been completed and tested so far.  Eagle 5.x files for the boards can be found in the ``pcb`` directory.

Some modules were developed for an earlier version of the platform, and have been tested with the current version using an adapter PCB.  These older modules would need to be revised to meet the current interface specification, and don't fit within a reasonably sized chassis with the current backplane (because they are mounted vertically).

**Modules**

More detailed information about modules (explaining the design process) will be added later.  For now, here is a short summary of what is on each board.  The baseline implementations use AKM parts because they are readily available (with full datasheets), perform well, and the DACs conveniently have voltage outputs.

* DAC2 (2 channel DAC)

  * DSD1792_ (tested on earlier platform only)
  
    * No local regulation; uses regulated supplies from backplane
    * Two iterations of a common-base I/V stage
    
      * `Revision A`__ with simple BJT current sources and MOSFET follower output 
      * `Revision B`__ with improved PSRR, 3rd-order antialising filter and diamond buffer output
      
  * AK4490_

    * LT3042 local regulators for VDDL/R and VREFL/R; ADM7160 regulators for AVDD and DVDD
    * AD9515 LVPECL clock receiver powered by ADM7154 regulator
    * ADA4899-1 output buffer/filter powered by ADP7142/ADP7182 regulators
    * 2 V differential (1 V single-ended) full-scale output
    * 0/10/20/30 dB resistive attenuator controlled by GPIO

.. _DSD1792: https://github.com/pricem/da_platform/raw/master/docs/schematics/dac2_v1.pdf
.. __: https://github.com/pricem/da_platform/raw/master/docs/schematics/dac2_v1_iv_a.pdf
.. __: https://github.com/pricem/da_platform/raw/master/docs/schematics/dac2_v1_iv_b.pdf
.. _AK4490: https://github.com/pricem/da_platform/raw/master/docs/schematics/dac2_v2.pdf

* ADC2 (2 channel ADC)

  * AK5572_

    * LT3042 local regulators for AVDD and VREFL/R; ADM7160 regulator for DVDD
    * AD9515 LVPECL clock receiver powered by ADM7154 regulator
    * ADA4004-4 input buffer; ADA4932-2 ADC driver powered by ADP7142/ADP7182 regulators
    * 2.25 V full-scale input (differential or single-ended)

* DAC8 (8 channel DAC)

  * AD1934_ (tested on earlier platform only)
  
    * No local regulation; uses regulated supplies from backplane
    * Two iterations of a voltage gain / antialiasing filter stage
    
      `Revision A`_, `Revision B`_
      
  * AK4458_
  
    * ADP7118 regulators for AVDD and VREF; ADM7160 regulator for DVDD
    * LS90LV012 LVDS clock receiver powered by ADP7118 regulator
    * OPA1664 output buffer/filter
    * 2 V single-ended full-scale output (no differential output)
    * 0/10/20 dB resistive attenuator controlled by SPI

* ADC8 (8 channel ADC)

  * AK5578_
  
    * ADP7118 regulators for AVDD and VREF; ADM7160 regulator for DVDD
    * LS90LV012 LVDS clock receiver powered by ADP7118 regulator
    * OPA1664 input buffer; THS4524 ADC driver
    * 2.25 V full-scale input (differential or single-ended)


.. _AK5572: https://github.com/pricem/da_platform/raw/master/docs/schematics/adc2_v2.pdf
.. _AD1934: https://github.com/pricem/da_platform/raw/master/docs/schematics/dac8_v1.pdf
.. _Revision A: https://github.com/pricem/da_platform/raw/master/docs/schematics/dac8_v1_scaler_a.pdf
.. _Revision B: https://github.com/pricem/da_platform/raw/master/docs/schematics/dac8_v1_scaler_b.pdf
.. _AK4458: https://github.com/pricem/da_platform/raw/master/docs/schematics/dac8_v2.pdf
.. _AK5578: https://github.com/pricem/da_platform/raw/master/docs/schematics/adc8_v2.pdf

**Clock source**

* `Initial version`__ with multiple stuffing options
  
  * One clock is on and one is powered down at all times (selected by carrier)
  * Damped ferrite bead supply filters leading to each oscillator and to logic
  * Low cost stuffing example:
  
    * ADM7160 regulator
    * Epson SG-210STF oscillators
    * 74xx CMOS mux and FIN10xx LVDS buffer
  
  * High performance stuffing example:
  
    * ADM7154 regulator
    * Crystek CCHD-957 oscillators
    * ADCLK948 LVPECL clock mux/buffer
    
  Note that you can use any combination of oscillator, regulator and buffer.  There are SMD footprints which would fit (for example) the NDK NZ2520SD, and DIP footprints that fit (for example) the Tentlabs XO.
  
.. __: https://github.com/pricem/da_platform/raw/master/docs/schematics/clock_v2.pdf

**Backplane**

* `Initial version`__

  * Stuffing options for digital interconnect:
  
    * ADUM340x / ADUM14xE0 transformer isolators
    * Resistor/jumper bypass option for non-isolated system

  * Global regulation (+5 V, +3.3 V, +/- 15 V) with stuffing options:
  
    * LM317/LM337 with Vadj bypass
    * Jung regulators with LM317/LM337 preregulator

.. __: https://github.com/pricem/da_platform/raw/master/docs/schematics/isolator_v2.pdf

**Carrier**

* `Initial version`__ contains:

  * ZTEX USB-FPGA 2.13a (Xilinx Artix-7 XC7A35T FPGA, 256 MB memory)
  
    This project includes an HDL design and build scripts for the FPGA to function as the carrier, exercising all features of the module interface.  It also acts as a deep (8M sample) asynchronous FIFO, since the USB interface clock is unrelated to the audio clocks.  Much more information about this can be found in the `Digital design`_ section.
  
  * Raspberry Pi (optional)
  
    I use MPD running on the Raspberry Pi as a streaming server for audio files stored on a NAS.  The Raspberry Pi is mounted on the carrier card within the chassis, and has an extension cable to an Ethernet jack on the back.  However, you can leave out the Raspberry Pi and connect any computing device to the FPGA board using USB (with a similar extension cable).  It's possible to use a USB Wi-fi adapter.
  
  * External 5 V DC wall wart supply (can be isolated from audio supplies, if backplane is equipped with isolators)

  * Debug/expansion header (0.1" pitch) for prototyping

.. __: https://github.com/pricem/da_platform/raw/master/docs/schematics/carrier_v2.pdf

**PSU**

* `Initial version`_

  * 60 Hz linear supply with diode rectifiers
  * Dual 5 V (Triad VPS10-2500) and 28 Vct (Triad FD7-28) transformers
  * +7 V unregulated outputs for analog and digital sections
  * +/- 22 V unregulated outputs for analog sections
  * 10,000 uF decoupling for each rail
  * At least 1 A load is allowed for all supplies simultaneously

.. _`Initial version`: https://github.com/pricem/da_platform/raw/master/docs/schematics/psu_v2.pdf

