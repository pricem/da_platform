
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


