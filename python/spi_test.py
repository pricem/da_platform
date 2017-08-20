
import sys
import numpy
import os
import scipy.io.wavfile
import time

from backends.da_platform import DAPlatformBackend
from modules.base import ModuleBase
from modules.dsd1792 import DSD1792Module
from utils import get_elapsed_time

SLOT_DAC = 0

print 'Imported everything'

backend = DAPlatformBackend()
dac = DSD1792Module(backend)
dac.setup(SLOT_DAC)

print 'Setup, now trying SPI transfer'

print dac.get_dirchan()

dac.select_clock(0)
time.sleep(1.0)


#dac.spi_write(SLOT_DAC, 0, 0, 0x47, 0xA4)



