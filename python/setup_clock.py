
import sys
import numpy
import os
import scipy.io.wavfile
import time

from backends.da_platform import DAPlatformBackend
from modules.base import ModuleBase
from modules.dsd1792 import DSD1792Module
from modules.ad1934 import AD1934Module
from utils import get_elapsed_time

SLOT_DAC = 0
multichan_mode = False

backend = DAPlatformBackend()

#   Autodetect DAC type and configure the module
chunk_size = 4096
base_module = ModuleBase(backend)
(dir_vals, chan_vals) = base_module.get_dirchan()
if not dir_vals[SLOT_DAC]:
    raise Exception('No DAC in slot %d' % SLOT_DAC)
elif chan_vals[SLOT_DAC]:
    print 'Detected AD1934, 8-channel'
    dac = AD1934Module(backend)
    multichan_mode = True
    chunk_size = 1024
else:
    print 'Detected DSD1792, 2-channel'
    dac = DSD1792Module(backend)
#"""
#  AK4490 - max attenuation to minimize impact of clock/reset 
for slot in [0, 1]:
    dac.set_hwcon(slot, 0x02)
time.sleep(0.1)
#"""

#dac.setup(SLOT_DAC)
dac.select_clock(1)

#  Don't undo the attenuation.  It's up to play_stream to do that.
#dac.spi_summary()
#dac.set_attenuation(0)
#dac.set_hwcon(SLOT_DAC, 0)
