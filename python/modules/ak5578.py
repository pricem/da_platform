"""
    Open-source digital audio platform
    Copyright (C) 2009--2018 Michael Price

    ak5578.py: Support for AK5578, 8-channel ADC module.
    
    Warning: Use and distribution of this code is restricted.
    This software code is distributed under the terms of the GNU General Public
    License, version 3.  Other files in this project may be subject to
    different licenses.  Please see the LICENSE file in the top level project
    directory for more information.
"""

import time

from modules.base import ModuleBase

class AK5578Module(ModuleBase):

    #   TODO
    REG_CONFIG = {
        
    }
    
    def set_reg(self, reg_name, new_val, slot=0):
        (reg_index, start_bit, num_bits) = AK5578Module.REG_CONFIG[reg_name]
        bit_mask = 0
        for i in range(num_bits):
            bit_mask |= (1 << (start_bit + i))
        current_val = self.spi_read(slot, 0, 0, reg_index)
        new_val = (current_val & (~bit_mask)) | (new_val << start_bit)
        print 'Updating register 0x%02x from 0x%02x to 0x%02x' % (reg_index, current_val, new_val)
        self.spi_write(slot, 0, 0, reg_index, new_val)
    
    def num_channels(self):
        return 8

    def setup(self, slot):

        self.spi_write(slot, 0, 0, 0x22, 0x13)
        
        #   Have to do a soft reset for changes to clock and format to take effect.
        self.spi_write(slot, 0, 0, 0x21, 0x00)
        time.sleep(0.1)
        self.spi_write(slot, 0, 0, 0x21, 0x01)

        print 'Setup for AK5578 in slot %d - 256Fs clk, HPF enabled, I2S format' % slot

        
        
