"""
    Open-source digital audio platform
    Copyright (C) 2009--2018 Michael Price

    ad1934.py: Support for AD1934, 8-channel DAC module.
    
    Warning: Use and distribution of this code is restricted.
    This software code is distributed under the terms of the GNU General Public
    License, version 3.  Other files in this project may be subject to
    different licenses.  Please see the LICENSE file in the top level project
    directory for more information.
"""

from modules.base import ModuleBase

class AD1934Module(ModuleBase):
    def spi_summary(self, slot=0):
        print 'SPI summary for AD1934 in slot %d' % slot
        vals = [self.spi_read(slot, 1, 0, 0x0900 + x, add_offset=False) for x in range(17)]
        for x in range(17): print '%04s  %08d' % (x, int(bin(vals[x])[2:]))

    def setup(self, slot=0):
        #   Default setup worked out from experimentation 3/4/2017
        self.spi_write(slot, 1, 0, 0x0800, 0x80)  #   enable MCLK, select MCLK as PLL source

    def num_channels(self):
        return 8

