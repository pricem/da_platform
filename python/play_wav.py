
import sys
import numpy
import os
import scipy.io.wavfile

from backends.da_platform import DAPlatformBackend
from modules.dsd1792 import DSD1792Module
from modules.ad1934 import AD1934Module
from utils import get_elapsed_time

SLOT_DAC = 1

backend = DAPlatformBackend()
dac = DSD1792Module(backend)

test_fn = sys.argv[1]

def play_file(filename):
    
    (Fs_test, x_st_int) = scipy.io.wavfile.read(filename)
    #   Convert to 24-bit
    if x_st_int.dtype == numpy.int16:
        #   << 8 for 0 dBFS, << 4 for -24 dbFS
        x_st_int = x_st_int.astype(numpy.int32) << 8
    elif x_st_int.dtype == numpy.int32:
        #   fine, accept int32 as if it's 24 bit
        #   hopefully it isn't actually 32 bit
        pass
    else:
        raise Exception('Unexpected source data type: %s' % x_st_int.dtype)
    
    N = x_st_int.shape[0]
    print 'Num. samples = %d' % N
    samples_written = 0
    chunk_size = (1 << 12)
    
    while samples_written < N:
        chunk = x_st_int[samples_written:samples_written+chunk_size]
        this_chunk_size = chunk.shape[0]
        dac.audio_write(SLOT_DAC, chunk.flatten())
        samples_written += this_chunk_size
        print 'ASAA %d' % samples_written

if os.path.isdir(test_fn):
    x_st_arr = []
    all_fn = os.listdir(test_fn)
    all_fn = filter(lambda x: x.endswith('.wav'), all_fn)
    all_fn.sort()
    
    if len(sys.argv) > 2:
        start_track = int(sys.argv[2])
        all_fn = all_fn[start_track:]
        
        for fn in all_fn:
            fn_full = os.path.join(test_fn, fn)
            print 'Loading: %s' % fn_full
            play_file(fn_full)
else:
    play_file(test_fn)
            
backend.flush(display=True)
sys.exit(0)
