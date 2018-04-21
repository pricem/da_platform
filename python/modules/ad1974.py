"""
    Open-source digital audio platform
    Copyright (C) 2009--2018 Michael Price

    ad1974.py: Support for AD1974, 8-channel ADC module.
    
    Warning: Use and distribution of this code is restricted.
    This software code is distributed under the terms of the GNU General Public
    License, version 3.  Other files in this project may be subject to
    different licenses.  Please see the LICENSE file in the top level project
    directory for more information.
"""

from modules.base import ModuleBase

class AD1974Module(ModuleBase):
    
    def spi_summary(self, slot=0):
        #   AD1974 SPI port seems to be same as AD1934.
        #   There are 2 chips (A, B) on the board. Note: ACON[7] is chip select
        self.set_acon(slot, 0x00)
        print 'SPI summary for AD1974 A in slot %d' % slot
        vals = [self.spi_read(slot, 1, 0, 0x0900 + x, add_offset=False) for x in range(17)]
        for x in range(17): print '%04s  %08d' % (x, int(bin(vals[x])[2:]))
        self.set_acon(slot, 0x80)
        print 'SPI summary for AD1974 B in slot %d' % slot
        vals = [self.spi_read(slot, 1, 0, 0x0900 + x, add_offset=False) for x in range(17)]
        for x in range(17): print '%04s  %08d' % (x, int(bin(vals[x])[2:]))


