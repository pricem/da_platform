"""
    Open-source digital audio platform
    Copyright (C) 2009--2018 Michael Price

    play_stream.py: Example script illustrating output of audio from
    standard input to DAC modules. 

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

dac.setup(SLOT_DAC)
dac.select_clock(1)

#  For now, assumes 44.1 kHz, 2 channels, 16 bit format
#  BUT should eventually get that from the command line (ALSA)

def play_stream(stream, chunk_size=4096):
    bytes_read = 1
    while bytes_read > 0: 
        data = stream.read(chunk_size)
        bytes_read = len(data)
        data = numpy.fromstring(data, dtype=numpy.int16)
        #   Convert to 24-bit format
        data = data.astype(numpy.int32) << 8

        if multichan_mode:
            #   Hack for distributing same stereo stream to each channel pair of AD1934
            #   For now, only using channels 1,2 and 7,8 (long story)
            orig_size = data.shape[0]
            data_exp = numpy.zeros((orig_size * 4,), dtype=numpy.int32)
            data_exp[::8] = data[::2]
            data_exp[1::8] = data[1::2]
            data_exp[6::8] = data[::2]
            data_exp[7::8] = data[1::2]
            data = data_exp

        #print 'Got %d samples: %s' % (data.shape[0], data[:32])
        dac.audio_write(SLOT_DAC, data)

play_stream(sys.stdin, chunk_size)

backend.flush(display=True)
sys.exit(0)

