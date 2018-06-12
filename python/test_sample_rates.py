#!/usr/bin/env python

import numpy

from backends.da_platform import DAPlatformBackend
from modules.ak4490 import AK4490Module

backend = DAPlatformBackend()
dac = AK4490Module(backend)

sample_rates = [44100, 48000, 96000, 192000]
tone_freq = 500.

slot = 0

def try_sample_rate(rate):
    dac.set_sample_rate(slot, rate)
    dac.setup(slot)

    t = numpy.linspace(0, 1, rate + 1)[:-1]    
    x = 0.1 * numpy.sin(2 * numpy.pi * t * tone_freq)
    xd = numpy.tile(x, 2)

    xdi = (xd * (1 << 23)).astype(numpy.int32)

    dac.audio_write(slot, xdi)
    print 'Wrote %d samples at rate %d' % (len(x), rate)

