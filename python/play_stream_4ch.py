
"""
12/2/2017

4 channel stream playing split over 2 slots containing DAC2s.
"""

import sys
import numpy
import os
import scipy.io.wavfile
import argparse

from backends.da_platform import DAPlatformBackend
from modules.base import ModuleBase
from modules.dsd1792 import DSD1792Module
from modules.ak4490 import AK4490Module
from modules.ad1934 import AD1934Module
from utils import get_elapsed_time

from webctrl import controls

#   We need to check the parameters of the input stream...
parser = argparse.ArgumentParser(description='Plays audio stream')
parser.add_argument('-r', '--rate', type=int, default=44100)
parser.add_argument('-c', '--channels', type=int, default=4)
parser.add_argument('-b', '--bits', type=int, default=16)
parser.add_argument('-f', '--format', default='S16_LE')
args = parser.parse_args()
print args

assert args.rate == 44100
assert args.channels == 4

#   Assumes 4 channels in.  Directs these to 2 DAC2s in the following slots.
SLOTS_DAC = [0, 1]

backend = DAPlatformBackend()

#   Autodetect DAC type and configure the module
chunk_size = 2048
base_module = ModuleBase(backend)
(dir_vals, chan_vals) = base_module.get_dirchan()

dacs = {}
for slot in SLOTS_DAC:
    if not dir_vals[slot]:
        raise Exception('No DAC in slot %d' % slot)
    elif chan_vals[slot]:
        print 'Detected AD1934, 8-channel'
        dacs[slot] = AD1934Module(backend)
        raise Exception('This is not what I was expecting')
    else:
        print 'Detected AK4490, 2-channel'
        dacs[slot] = AK4490Module(backend)
    dacs[slot].setup(slot)
    #   TODO: Attenuation
    #dacs[slot].set_hwcon(slot, 0x04)  # 20 dB
    """
    spi_atten_db = 30.0
    spi_atten_int = int(0xFF - spi_atten_db * 2)
    dac.spi_write(slot, 0, 0, 0x23, spi_atten_int)
    dac.spi_write(slot, 0, 0, 0x24, spi_atten_int)
    """

#   1/27/2018: Set slot 1 DAC to 10 dB attenuation
#   for use with Modulus-86 amp (20 dB gain vs. 32 dB on XPA-5)
#   2/4/2018: Changed to full gain on tweeter amp.
dacs[0].set_attenuation(0, 20)
dacs[1].set_attenuation(1, 0)

#  For now, assumes 44.1 kHz, 2 channels, 16 bit format
#  BUT should eventually get that from the command line (ALSA)

def play_stream(stream, chunk_size=4096):
    bytes_read = 1
    gain_db = None
    while bytes_read > 0: 
        #   Data is converted to double precision when read in.
        data = stream.read(chunk_size)
        bytes_read = len(data)
        if args.format == 'S16_LE' and args.bits == 16:
            data = numpy.fromstring(data, dtype=numpy.int16)
            #   Convert to double precision
            data = data.astype(float) / (1 << 16)
        elif args.format == 'FLOAT_LE' and args.bits == 32:
            data = numpy.fromstring(data, dtype=numpy.float32)
            data = data.astype(float)
        else:
            raise Exception('Bad input format %s with %d bits' % (args.format, args.bits))

        #  Apply global volume (gain) setting and convert to 24 bit integers.
        next_gain_db = controls.get_volume()
        if next_gain_db != gain_db:
            print 'Volume changed to %f dB' % next_gain_db
        gain_db = next_gain_db
        data_scaled = data * (10 ** (gain_db / 20.))
        data = (data_scaled * (1 << 24)).astype(numpy.int32)

        #  Distribute channels to slots:
        #  First 2 channels to first slot, second 2 channels to second slot
        orig_size = data.shape[0]

        data_slot0 = numpy.zeros((orig_size / 2), dtype=numpy.int32)
        data_slot1 = numpy.zeros((orig_size / 2), dtype=numpy.int32)

        data_slot0[::2] = data[::4]
        data_slot0[1::2] = data[1::4]
        data_slot1[::2] = data[2::4]
        data_slot1[1::2] = data[3::4]

        #print 'Got %d samples: %s' % (data.shape[0], data[:32])

        #   TODO: Time alignment by releasing a block at the same time for both...
        dacs[0].audio_write(SLOTS_DAC[0], data_slot0)
        dacs[1].audio_write(SLOTS_DAC[1], data_slot1)

play_stream(sys.stdin, chunk_size)

backend.flush(display=True)
sys.exit(0)

