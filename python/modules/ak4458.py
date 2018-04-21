"""
    Open-source digital audio platform
    Copyright (C) 2009--2018 Michael Price

    ak4458.py: Support for AK4458, 8-channel DAC module.
    
    Warning: Use and distribution of this code is restricted.
    This software code is distributed under the terms of the GNU General Public
    License, version 3.  Other files in this project may be subject to
    different licenses.  Please see the LICENSE file in the top level project
    directory for more information.
"""

from modules.base import ModuleBase

class AK4458Module(ModuleBase):

    #   TODO:
    REG_CONFIG = {

    }

    def set_reg(self, reg_name, new_val, slot=0):
        (reg_index, start_bit, num_bits) = AK4458Module.REG_CONFIG[reg_name]
        bit_mask = 0
        for i in range(num_bits):
            bit_mask |= (1 << (start_bit + i))
        current_val = self.spi_read(slot, 0, 0, reg_index)
        new_val = (current_val & (~bit_mask)) | (new_val << start_bit)
        print 'Updating register 0x%02x from 0x%02x to 0x%02x' % (reg_index, current_val, new_val)
        self.spi_write(slot, 0, 0, reg_index, new_val)
    
    def num_channels(self):
        return 8

    def set_attenuation(self, slot, atten_db):
        #   Right now, applies same attenuation to all 8 channels.
        #   Independent attenuation per channel is possible.
        self.set_hwcon(slot, 0xFF)
        if atten_db == 0:
            self.spi_write(slot, 0, 0, 0x00, 0x00)
        elif atten_db == 10:
            self.spi_write(slot, 0, 0, 0x55, 0x55)
        elif atten_db == 20:
            self.spi_write(slot, 0, 0, 0xAA, 0xAA)
        else:
            raise Exception('Unsupported attenuation value for DAC8 AK4458 module: %s' % atten_db)
        self.set_hwcon(slot, 0x00)

    def setup(self, slot=0):
        
        #   HWCON = 0 for DAC
        #   HWCON = 0xFF for atten.
        
        #   Configure DAC
        self.set_hwcon(slot, 0)
        
        #   Set DIF for 24-bit I2S
        self.spi_write(slot, 0, 0, 0x20, 0x87)
        print 'Set up for AK4458: Wrote 0x87 to register 0'
        
        #   Configure attenuator - all off
        self.set_attenuation(slot, 0)


