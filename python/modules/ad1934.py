
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

