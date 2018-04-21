"""
    Open-source digital audio platform
    Copyright (C) 2009--2018 Michael Price

    generate_tone.py: Simple, 2 channel 16/44 tone generator.
    Writes samples to stdout (e.g. for play_stream.py).

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

def gen_tone(freq, ampl_db, T=60.):
    
    num_channels = 2
    F_s = 44100.
    N = int(F_s * T)
    t = numpy.linspace(0, (N - 1) / F_s, N)
    x = 0.5 * numpy.sin(2 * numpy.pi * freq * t) * (10 ** (ampl_db / 20.0))
    x_st_int = numpy.expand_dims((x * (1 << 16)).astype(numpy.int16), 1).repeat(num_channels, axis=1)
    
    N = x_st_int.shape[0]
    samples_written = 0
    chunk_size = (1 << 12)
    
    while samples_written < N:
        chunk = x_st_int[samples_written:samples_written+chunk_size]
        this_chunk_size = chunk.shape[0]
        #sys.stderr.write('Writing: %s\n' % chunk.flatten())
        sys.stdout.write(chunk.flatten().tostring())
        samples_written += this_chunk_size

if len(sys.argv) > 1:
    freq = float(sys.argv[1])
else:
    freq = 1000.

if len(sys.argv) > 2:
    ampl_db = float(sys.argv[2])
else:
    ampl_db = -20.

T0 = 60
gen_tone(freq, ampl_db, T=T0)

