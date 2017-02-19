
from modules.base import ModuleBase

class AD1934Module(ModuleBase):
    def spi_summary(self, slot=0):
        print 'SPI summary for AD1934 in slot %d' % slot
        vals = [self.spi_read(slot, 1, 0, 0x0900 + x, add_offset=False) for x in range(17)]
        for x in range(17): print '%04s  %08d' % (x, int(bin(vals[x])[2:]))

