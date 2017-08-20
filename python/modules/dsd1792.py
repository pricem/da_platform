
from modules.base import ModuleBase

class DSD1792Module(ModuleBase):

    REG_CONFIG = {
        'ATL': (16, 0, 8),
        'ATR': (17, 0, 8),
        'MUTE': (18, 0, 1),
        'DME': (18, 1, 1),
        'DMF': (18, 2, 2),
        'FMT': (18, 4, 3),
        'ATLD': (18, 7, 1),
        'INZD': (19, 0, 1),
        'FLT': (19, 1, 1),
        'DFMS': (19, 2, 1),
        'ZOE': (19, 3, 1),
        'OPE': (19, 4, 1),
        'ATS': (19, 5, 2),
        'REV': (19, 7, 1),
        'OS': (20, 0, 2),
        'CHSL': (20, 2, 1),
        'MONO': (20, 3, 1),
        'DFTH': (20, 4, 1),
        'DSD': (20, 5, 1),
        'SRST': (20, 6, 1),
        'PCMZ': (21, 0, 1),
        'DZ': (21, 1, 2),
        'ZFGL': (22, 0, 1),
        'ZFGR': (22, 1, 1),
        'ID': (23, 0, 5),
    }

    def spi_summary(self, slot=0):
        reg_base = 16
        vals = [self.spi_read(slot, 0, 0, x) for x in range(16, 24)]
        result_dict = {}
        keys = DSD1792Module.REG_CONFIG.keys()
        keys.sort()
        for key in keys:
            (reg_index, start_bit, num_bits) = DSD1792Module.REG_CONFIG[key]
            bit_mask = 0
            for i in range(num_bits):
                bit_mask |= (1 << (start_bit + i))
            val = (vals[reg_index - reg_base] & bit_mask) >> start_bit
            result_dict[key] = val
            print '%6s = %3d' % (key, val)

        return result_dict
    
    def set_reg(self, reg_name, new_val, slot=0):
        (reg_index, start_bit, num_bits) = DSD1792Module.REG_CONFIG[reg_name]
        bit_mask = 0
        for i in range(num_bits):
            bit_mask |= (1 << (start_bit + i))
        current_val = self.spi_read(slot, 0, 0, reg_index)
        new_val = (current_val & (~bit_mask)) | (new_val << start_bit)
        print 'Updating register 0x%02x from 0x%02x to 0x%02x' % (reg_index, current_val, new_val)
        self.spi_write(slot, 0, 0, reg_index, new_val)
    
    def num_channels(self):
        return 2

