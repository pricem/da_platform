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

import argparse

parser = argparse.ArgumentParser(description='Plays audio stream')
parser.add_argument('-f', '--freq', type=float, default=1000.)
parser.add_argument('-a', '--ampl', type=float, default=-20.)
parser.add_argument('-l', '--length', type=float, default=10.)
parser.add_argument('-r', '--rate', type=int, default=44100)
parser.add_argument('-b', '--bits', type=int, default=16)
parser.add_argument('-c', '--channels', type=int, default=2)
args = parser.parse_args()


import sys
sys.stderr.write('%s\n' % args)

def gen_tone(freq_hz, ampl_db, length_sec, fmt_bits, F_s, num_channels):
    
    if fmt_bits == 16:
        dtype = numpy.int16
    elif fmt_bits == 24 or fmt_bits == 32:
        dtype = numpy.int32
    else:
        raise Exception('Unsupported format: %d bits' % fmt_bits)

    N = int(F_s * length_sec)
    t = numpy.linspace(0, (N - 1) / F_s, N)
    x = 0.5 * numpy.sin(2 * numpy.pi * freq_hz * t) * (10 ** (ampl_db / 20.0))
    x_st_int = numpy.expand_dims((x * (1 << fmt_bits)).astype(dtype), 1).repeat(num_channels, axis=1)
    
    N = x_st_int.shape[0]
    samples_written = 0
    chunk_size = (1 << 12)
    
    while samples_written < N:
        chunk = x_st_int[samples_written:samples_written+chunk_size]
        this_chunk_size = chunk.shape[0]
        #sys.stderr.write('Writing: %s\n' % chunk.flatten())
        sys.stdout.write(chunk.flatten().tostring())
        samples_written += this_chunk_size

gen_tone(args.freq, args.ampl, args.length, args.bits, args.rate, args.channels)

