
import sys
import numpy
import os
import scipy.io.wavfile

from backends.da_platform import DAPlatformBackend
from modules.base import ModuleBase
from modules.dsd1792 import DSD1792Module
from utils import get_elapsed_time

SLOT_DAC = 1

backend = DAPlatformBackend()
dac = DSD1792Module(backend)
dac.setup(SLOT_DAC)


#dac.spi_summary()
dac.spi_write(SLOT_DAC, 0, 0, 0x47, 0xA3)


