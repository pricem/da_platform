"""
    Open-source digital audio platform
    Copyright (C) 2009--2018 Michael Price

    spi_test.py: Sanity check of per-module SPI master functionality.
    
    Warning: Use and distribution of this code is restricted.
    This software code is distributed under the terms of the GNU General Public
    License, version 3.  Other files in this project may be subject to
    different licenses.  Please see the LICENSE file in the top level project
    directory for more information.
"""

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



