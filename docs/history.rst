History
-------

This project has been in the works for a while.  It was originally conceived in 2008 as a CD player built around a mini-ITX PC.  In 2009 I designed a set of PCBs and a custom chassis to hold everything.  Some of the design principles were established then: galvanic isolation of all digital signals, 2-channel and 8-channel DACs and ADCs, 4 modules per chassis.  I acquired a Digilent Nexys2 FPGA board for the digital interfaces.  However, my FPGA skills lagged behind my ambitions and the PCBs I had designed weren't very well thought out.  I more-or-less abandoned the project and, for my own stereo system, continued using a CD player and an analog active crossover.  

A few years later, I ended up doing research in digital circuits.  This made the digital design for the FPGA seem much less intimidating.  In 2013, I decided to finish the missing pieces and resurrected the original years-old hardware.  I was able to demonstrate the concept of an FPGA-controlled USB DAC with the DSD1792A.  However, I found many problems with the original PCB designs and my architecture was complex and unwieldy.  Also, the Nexys2 FPGA platform was no longer supported by current tools; in 2015 I switched to a ZTEX board with a modern FPGA.  In 2016, after finishing graduate school, I decided to revise the PCBs and construct a complete chassis.  This became the "baseline" implementation of the project, with plans to add other interchangeable components in the future.  In December 2017 I started using the device as a digital crossover and streaming server in my main stereo system.  I rewrote some of the HDL code that was license-encumbered and published the project on GitHub in April 2018.

.. figure:: photos/DSC_0234.jpg
    :width: 75%
    :align: center

    Testing of an earlier version of the platform in early 2017.  On the left side are prototype Jung regulators with a 3-terminal form factor; they were later integrated onto the bottom side of the backplane.  At right is a 2-channel DAC module based on the DSD1792 and a new discrete I/V stage.  (This DAC worked quite well and I plan to port it to the current platform.)  In the background is the ZTEX FPGA development board connected by a ribbon cable.

Progress has been slow due to work and family commitments, but I intend to continue soliciting community input, making improvements, and for those brave enough to build their own version, supporting the project indefinitely.

Fun facts
=========

This list will be periodically updated with stories and lessons learned from building and testing this project.

* You may be wondering, where does the name "Samoyed" come from?  When I was working on many of the boards you see here, my wife would comment with enthusiasm about samoyeds.  A samoyed is a `large, playful, fluffy white dog <https://en.wikipedia.org/wiki/Samoyed_dog>`_.  She talked about them so much that I decided to name the project after them.

* Don't try to drill out your own holes for XLR connectors unless you are comfortable with: nasty vibration, chuck falling out of the spindle, and irregular holes larger than you wanted.  This happens even with the `cloth trick <http://www.giangrandi.ch/mechanics/sheetmetaldrill/sheetmetaldrill.shtml>`_.  Send them to the CNC shop.

* When I tested the current set of baseline modules, I wired the XLR connectors with pins 1 and 2 for differential signals and pin 3 for chassis ground.  This is wrong; pin 1 should be chassis ground and pin 3 should be a signal pin.  However, because I was doing loopback tests between the DACs and ADCs (both wired in the same incorrect way), everything seemed fine.  It was only when I connected the DAC outputs to an amplifier and asked "why is there still ground loop hum?" and "why is there so little gain?" that I recognized the problem.
