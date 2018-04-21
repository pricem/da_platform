
import sys
import numpy
import os
import scipy.io.wavfile
import time
import numpy.random
import pdb

from backends.da_platform import DAPlatformBackend
from modules.base import ModuleBase
#from modules.dsd1792 import DSD1792Module
from modules.ak4490 import AK4490Module
from modules.ak4458 import AK4458Module
from utils import get_elapsed_time

SLOT_DAC = 2

print 'Imported everything'

backend = DAPlatformBackend()
#dac = DSD1792Module(backend)
#dac = AK4490Module(backend)
dac = AK4458Module(backend)
dac.setup(SLOT_DAC)

print 'Setup, now trying HWCON'

for i in range(4):
    dac.set_hwcon(i, 0x00)
print 'Made all HWCON 0x00 for testing'

pdb.set_trace()

#print dac.get_dirchan()

def local_set_hwcon(val):
    print 'Setting hwcon = 0x%02x' % val
    dac.set_hwcon(SLOT_DAC, val)
    time.sleep(2)

local_set_hwcon(0)

import pdb
pdb.set_trace()

for i in range(8):
    local_set_hwcon(1 << i)

for i in range(10):
    local_set_hwcon(numpy.random.randint(0, 256))

#   At the end...
for i in range(4):
    dac.set_hwcon(i, 0xFF)
print 'Made all HWCON 0xFF for testing'

