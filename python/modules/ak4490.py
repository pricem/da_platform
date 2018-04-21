
from modules.base import ModuleBase

class AK4490Module(ModuleBase):

    REG_CONFIG = {
        #   RSTN: write 0 to reset, normal is 1
        'RSTN': (0, 0, 1),
        #   DIF: Data interface mode (Table 20, page 34).  Write 3 for 24-bit I2S.  
        'DIF': (0, 1, 3),
        #   ECS: External digital filter clock setting.  0 for 768k, 1 for 384k.
        'ECS': (0, 5, 1),
        #   EXDF: External digital filter interface mode. 0 for internal, 1 for external.
        'EXDF': (0, 6, 1),
        #   ACKS: Master clock frequency auto setting mode.  0 for manual, 1 for auto
        'ACKS': (0, 7, 1),
        #   SMUTE: Soft mute.  0 for normal, 1 for mute.
        'SMUTE': (1, 0, 1),
        #   DEM: De-emphasis.  01 for off.
        'DEM': (0, 1, 2),
        #   DFS: Sampling speed control (Table 9, page 55).  000 for 44/48k, 001 for 88/96.
        'DFS': (0, 3, 2),
        'DFS2': (5, 1, 1),
        #   SD: Short delay filter enable (Table 14, page 55).  Default is short delay
        'SD': (0, 5, 1),
        #   DZFM: Data zero detect mode.  0 for channel separated, 1 for joint L/R zero-detect.
        'DZFM': (0, 6, 1),
        #   DZDE: Data zero detect enable (write 1 to enable)
        'DZFE': (0, 7, 1),
        #   SLOW: Slow rolloff filter enable (Table 14, page 56).  Default is slow rolloff.
        'SLOW': (2, 0, 1),
        #   SELLR: L/R select for mono mode (0 for right, 1 for left)
        'SELLR': (2, 1, 1),
        #   DZFB: Invert DZF outputs (zero-detect)
        'DZFB': (2, 2, 1),
        #   MONO: Mono mode (0 for stereo, 1 for mono)
        'MONO': (2, 3, 1),
        #   DCKB: DCLK polarity for DSD (0 for falling edge, 1 for rising)
        'DCKB': (2, 4, 1),
        #   DCKS: Master clock select for DSD (0 for 512fs, 1 for 768fs)
        'DCKS': (2, 5, 1),
        #   DP: DSD/PCM mode select (0 for PCM, 1 for DSD)
        'DP': (2, 7, 1),
        #   ATTL/ATTR: Attenuation for L/R channels (FF for max vol, 00 for mute, 0.5 dB steps)
        'ATTL': (3, 0, 8),
        'ATTR': (4, 0, 8),
        #   SSLOW: Super-slow rolloff filter (default = 0 = disabled)
        'SSLOW': (5, 0, 1),
        #   INVR/L: Output phase inversion (disabled by default)
        'INVR': (5, 6, 1),
        'INVL': (5, 7, 1),
        #   DSDSEL: DSD sampling speed control (table 16, page 58).
        'DSDSEL0': (6, 0, 1),
        'DSDSEL1': (9, 0, 1),
        #   DSDD: DSD playback path control (0 for normal, 1 for volume bypass)
        'DSDD': (6, 1, 1),
        #   DMRE: DSD mute release.  See datasheet.
        'DMRE': (6, 3, 1),
        #   DMC: DSD mute control.  See datasheet
        'DMC': (6, 4, 1),
        #   DMR/L: DSD full scale signal detection flag
        'DMR': (6, 5, 1),
        'DML': (6, 6, 1),
        #   DDM: DSD data mute (disabled by default)
        'DDM': (6, 7, 1),
        #   SYNCE: synchronization of multiple AK4490s
        'SYNCE': (7, 0, 1),
        #   SC: Sound control (table 27, page 59).  00 is default. 2 other options
        'SC': (8, 0, 2),
        #   DSDF: DSD filter control (table 18, page 59).
        'DSDF': (9, 1, 1),
    }

    def spi_summary(self, slot=0):
        print 'SPI summary for AK4490'
        reg_base = 0
        vals = [self.spi_read(slot, 0, 0, x) for x in range(0, 10)]
        result_dict = {}
        keys = AK4490Module.REG_CONFIG.keys()
        keys.sort()
        for key in keys:
            (reg_index, start_bit, num_bits) = AK4490Module.REG_CONFIG[key]
            bit_mask = 0
            for i in range(num_bits):
                bit_mask |= (1 << (start_bit + i))
            val = (vals[reg_index - reg_base] & bit_mask) >> start_bit
            result_dict[key] = val
            print '%6s = %3d' % (key, val)

        return result_dict
    
    def set_reg(self, reg_name, new_val, slot=0):
        (reg_index, start_bit, num_bits) = AK4490Module.REG_CONFIG[reg_name]
        bit_mask = 0
        for i in range(num_bits):
            bit_mask |= (1 << (start_bit + i))
        current_val = self.spi_read(slot, 0, 0, reg_index)
        new_val = (current_val & (~bit_mask)) | (new_val << start_bit)
        print 'Updating register 0x%02x from 0x%02x to 0x%02x' % (reg_index, current_val, new_val)
        self.spi_write(slot, 0, 0, reg_index, new_val)

    def set_attenuation(self, slot, atten_db):
        if atten_db == 0:
            self.set_hwcon(slot, 0x00)
        elif atten_db == 10:
            self.set_hwcon(slot, 0x08)
        elif atten_db == 20:
            self.set_hwcon(slot, 0x04)
        elif atten_db == 30:
            self.set_hwcon(slot, 0x02)
        else:
            raise Exception('Unsupported attenuation value for DAC2 AK4490 module: %s' % atten_db)

    def num_channels(self):
        return 2

    def setup(self, slot=0):
        #self.set_reg('DIF', 3, slot=slot)
        
        #self.reset_slots()
        #   Disable attenuator
        self.set_attenuation(slot, 0)
        
        #   Set DIF for 24-bit I2S
        self.spi_write(slot, 0, 0, 0x20, 0x87)
        print 'Set up for AK4490: Wrote 0x87 to register 0'
        
        #   Set traditional sharp rolloff filter (SD = 0)
        #self.spi_write(slot, 0, 0, 0x21, 0x02)  #   0x22 would be the default, 0x02 for traditional filter
        
        #   Set slow rolloff filter (SLOW = 1)
        #   self.spi_write(slot, 0, 0, 0x22, 0x01)  #   0x00 would be the default, 0x01 for slow rolloff filter
        
