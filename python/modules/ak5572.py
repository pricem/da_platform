
import time

from modules.base import ModuleBase

class AK5572Module(ModuleBase):

    REG_CONFIG = {
        #   PW: Power down control (1 = on, 0 = off)
        'PW': (0, 0, 2),
        #   RSTN: Write 0 to reset
        'RSTN': (1, 0, 1),
        #   MONO: Summing (table 17-19)
        'MONO': (1, 1, 2),
        #   HPFE: Highpass filter enable
        'HPFE': (2, 0, 1),
        #   DIF: Digital interface mode (table 8-9)
        'DIF': (2, 1, 2),
        #   CKS: Sampling speed and MCLK frequency select (table 5)
        'CKS': (2, 3, 4),
        #   TDM: Time division modes (table 9)
        'TDM': (3, 5, 2),
        #   SLOW: Slow rolloff filter (off by default)
        'SLOW': (4, 0, 1),
        #   SD: Short delay filter (off by default)
        'SD': (4, 1, 1),
        #   DP: DSD mode = 1, PCM = 0
        'DP': (4, 7, 1),
        #   DSDSEL: DCLK frequency select for DSD
        'DSDSEL': (5, 0, 2),
        #   DCKB: DCLK polarity for DSD (0 = falling, 1 = rising)
        'DCKB': (5, 2, 1),
        #   PMOD: DSD phase modulation mode
        'PMOD': (5, 3, 1),
        #   DCKS: DSD clock frequency select (0 = 512fs, 1 = 768fs)
        'DCKS': (5, 5, 1),
    }

    def spi_summary(self, slot=0):
        print 'SPI summary for AK5572'
        reg_base = 0
        vals = [self.spi_read(slot, 0, 0, x) for x in range(0, 8)]
        result_dict = {}
        keys = AK5572Module.REG_CONFIG.keys()
        keys.sort()
        for key in keys:
            (reg_index, start_bit, num_bits) = AK5572Module.REG_CONFIG[key]
            bit_mask = 0
            for i in range(num_bits):
                bit_mask |= (1 << (start_bit + i))
            val = (vals[reg_index - reg_base] & bit_mask) >> start_bit
            result_dict[key] = val
            print '%6s = %3d' % (key, val)

        return result_dict
    
    def set_reg(self, reg_name, new_val, slot=0):
        (reg_index, start_bit, num_bits) = AK5572Module.REG_CONFIG[reg_name]
        bit_mask = 0
        for i in range(num_bits):
            bit_mask |= (1 << (start_bit + i))
        current_val = self.spi_read(slot, 0, 0, reg_index)
        new_val = (current_val & (~bit_mask)) | (new_val << start_bit)
        print 'Updating register 0x%02x from 0x%02x to 0x%02x' % (reg_index, current_val, new_val)
        self.spi_write(slot, 0, 0, reg_index, new_val)
    
    def num_channels(self):
        return 2

    def setup(self, slot):
        #   Disabling since everything seems to be broken.
        
        #pass
        #"""
        #   Have to put AK5572 in hardware reset to initialize registers to default values.
        #self.start_sclk()
        #self.reset_slots()
        #time.sleep(0.1)
        
        #   Register 2 - Control 1
        #   [0] HPFE = 1
        #   [2:1] DIF = 01 (I2S)
        #   [6:3] CKS = 0010 - 256Fs (11.2M MCLK, 44.1k Fs)
        #   try 0011 for 128Fs (88.2k), 0110 for 512Fs (22.05k)
        self.spi_write(slot, 0, 0, 0x22, 0x13)
        
        #   Have to do a soft reset for changes to clock and format to take effect.
        self.spi_write(slot, 0, 0, 0x21, 0x00)
        time.sleep(0.1)
        self.spi_write(slot, 0, 0, 0x21, 0x01)

        print 'Setup for AK5572 in slot %d - 256Fs clk, HPF enabled, I2S format' % slot
        #"""
        
        
