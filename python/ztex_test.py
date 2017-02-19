#!/usr/bin/env python

"""
Before running, try one of:
price@ubuntu:~/projects/cdp/python$ ~/software/ztex/java/FWLoader/FWLoader -f -uf ~/projects/cdp/xilinx/memfifo/memfifo.runs/impl_2_13a/memfifo.bit
FPGA configuration time: 149 ms
price@ubuntu:~/projects/cdp/python$ ~/software/ztex/java/FWLoader/FWLoader -f -uf ~/software/ztex/examples/memfifo/fpga-2.13/memfifo.runs/impl_2_13a/memfifo.bit

"""

import usb1
import libusb1
import threading
import time
from datetime import datetime
import numpy.random
import scipy.io.wavfile
import pdb
import sys
from matplotlib import pyplot

from backends.da_platform import DAPlatformBackend
from modules.dsd1792 import DSD1792Module
from modules.ad1934 import AD1934Module
from utils import get_elapsed_time

SLOT_DAC = 1    #   default = 1
SLOT_ADC = 0    #   default = 0

        

if __name__ == '__main__':
    """
    backend = MemFIFOBackend()
    #tester = FIFOTester(backend)
    #tester.run(1 << 20, tol=2048)
    #tester.run(1 << 20, tol=1024)
    
    #   8/10/2016
    #   Just try doing something
    #   backend.write(numpy.zeros((64,), dtype=numpy.uint8))
    """
    #   8/10/2016
    #   SPI experiments
    backend = DAPlatformBackend()
    tester = DSD1792Module(backend)
    #tester = AD1934Tester(backend)

    #   Try something: switch all slots except the DAC slot to clock 1 (24.576 MHz - not connected)
    #   to decrease loading on CLK0A net
    backend.write(numpy.array([0xFF, DAPlatformBackend.SELECT_CLOCK, 0x00], dtype=backend.dtype))

    #   tester.get_dirchan()

    SLOT_DAC = 0    #   default = 1

    #print tester.ad1934_spi_summary(slot=SLOT_DAC)
    #tester.spi_write(SLOT_DAC, 1, 0, 0x0800, 0x99)  #   turn off MCLKO pin and PLL
    #tester.spi_write(SLOT_DAC, 1, 0, 0x0801, 0x03)  #   select external MCLK source
    #tester.spi_write(SLOT_DAC, 1, 0, 0x0800, 0xA0) #    enable MCLK, and select LRCK as PLL source
    #tester.spi_write(SLOT_DAC, 1, 0, 0x0800, 0x80)  #   enable MCLK, select MCLK as PLL source
    #time.sleep(0.1)
    #print tester.ad1934_spi_summary(slot=SLOT_DAC)
    
    #print tester.spi_read(1, 0, 0, 18)
    #tester.spi_summary(slot=SLOT_DAC)
    
    #   8/12/2016
    #   Set ACON
    #tester.set_acon(0, 0x59)
    #tester.reset_slots()
    """
    msg2 = tester.prepare_cmd(0, DAPlatformBackend.CMD_FIFO_WRITE, numpy.array([DAPlatformBackend.SLOT_SET_ACON, 0x59], dtype=backend.dtype))
    msg1 = numpy.array([0xFF, DAPlatformBackend.RESET_SLOTS], dtype=backend.dtype)
    backend.write(numpy.concatenate((msg1, msg2)))
    pdb.set_trace()
    """
    
    #   Try some audio (note: 44.1 kHz)
    F_s = 44100.
    F_sine = 10000.
    T = 10.
    N = F_s * T
    t = numpy.linspace(0, (N - 1) / F_s, N)
    #x = 0.00390625 * ((numpy.sin(2 * numpy.pi * F_sine * t) >= 0) - 0.5)
    #x = 0.00390625 * numpy.ones(t.shape)
    #x = (-1.0 / (1 << 24)) * numpy.ones(t.shape)
    level_db = -20
    x = 0.5 * numpy.sin(2 * numpy.pi * F_sine * t) * (10 ** (level_db / 20.0))
    #x = (1 + numpy.arange(N)).astype(float) * 2 / (1 << 24)
    #   1/2/2017 experiment
    #x = numpy.zeros(t.shape)
    #x[335:345] = 0.001
    """
    #   Alt. try some WAV data (note: should scale, max vol would be * 256)
    (F_s, data) = scipy.io.wavfile.read('/mnt/hgfs/cds/Guster/Lost and Gone Forever/05 I Spy.wav')
    block = F_s * 10
    #   data = data[block*10:block*11]
    N = data.shape[0]
    x = data.astype(numpy.int32) * 0
    """
    """
    #N = 80
    chunk_size = min(1024, N)
    samples_written = 0
    #   Just write samples continuously until interrupt
    while samples_written < N:
    #while True:
        #chunk = x[:chunk_size]
        chunk = x[samples_written:samples_written+chunk_size]
        this_chunk_size = chunk.shape[0]
        x_st = numpy.array([chunk, chunk]).T.flatten()
        tester.audio_write_float(1, x_st)
        #if samples_written > 1000:
        #    time.sleep(this_chunk_size / F_s)
        #tester.audio_write(1, x_st)
        samples_written += this_chunk_size
        print 'Wrote %d samples' % samples_written
    
    """
    #   Try some recording... (requires I2S loopback, or an ADC card to be installed) - slot 0
    """
    #   1.  Fixed size
    N = 80
    tester.start_recording(0)
    time.sleep(0.01)
    chunk = x[:N]
    x_st = numpy.array([chunk, chunk]).T.flatten()
    x_int = tester.audio_write_float(1, x_st)
    samples_read = 0
    chunk_size = 512
    rec_data = []
    while samples_read < 4096:
        print 'samples_read = %d' % samples_read
        data = tester.audio_read(0, chunk_size)
        rec_data.append(data)
        samples_read += data.shape[0]
    tester.stop_recording(0)
    rec_data = numpy.concatenate(rec_data)
    
    #   Flush the backend
    backend.flush(display=True)
    tester.audio_read(0, 4096, perform_update=False)

    rec_st = rec_data.reshape((rec_data.shape[0] / 2, 2))
    nz_all = numpy.nonzero(rec_st)
    nz_start = nz_all[0][0]
    nz_end = nz_all[0][-1]
    
    #x_int = numpy.concatenate(x_int)
    rec_st_nz = rec_st[nz_start:nz_end+1]
    rec_nz = rec_st_nz.flatten()
    n_err = numpy.sum(rec_nz != x_int)
    print '%d/%d samples differ' % (n_err, x_int.shape[0])
    if n_err > 0:
        print 'Error inds: %s' % numpy.nonzero(rec_nz != x_int)
    
    print 'Done testing fixed data'
    """
    #   2. Continuous
    
    #   For synthetic tests...
    x_st_int = numpy.expand_dims((x * (1 << 24)).astype(numpy.int32), 1).repeat(2, axis=1)

    """
    #   Load a song instead
    test_fn = "/mnt/hgfs/cds/Weezer/Weezer (Blue Album)/07 Say It Ain't So.wav"
    #test_fn = "/mnt/hgfs/cds/Weezer/Weezer (Blue Album)/05 Undone (the Sweater Song).wav"
    (Fs_test, x_st_int) = scipy.io.wavfile.read(test_fn)
    
    
    #   Convert to 24-bit
    if x_st_int.dtype == numpy.int16:
        #   << 8 for 0 dBFS, << 4 for -24 dbFS
        x_st_int = x_st_int.astype(numpy.int32) << 8
    else:
        raise Exception('Unexpected source data type: %s' % x_st_int.dtype)
    """
    
    
    
    #N = int(F_s * T)
    do_record = False
    N = x_st_int.shape[0]
    time_start = datetime.now()
    if do_record:
        tester.start_recording(SLOT_ADC)
    samples_written = 0
    samples_read = 0
    start_flag = False
    chunk_size = (1 << 12)
    #N = min(N, 110000)
    #N = min(N, 4 * chunk_size)  #   uncomment to limit test to 1 chunk
    rec_data = []
    x_int = []
    
    while samples_written < N:
        
        chunk = x_st_int[samples_written:samples_written+chunk_size]
        this_chunk_size = chunk.shape[0]
        #x_st = numpy.array([chunk, chunk + 1.0 / (1 << 24)]).T.flatten()
        
        #x_int.append(tester.audio_write_float(1, x_st))
        tester.audio_write(SLOT_DAC, chunk.flatten())
        x_int.append(chunk.flatten())
        samples_written += this_chunk_size
        #print 'Wrote %d samples' % samples_written

        #   Delay first read so that we don't get a buffer underrun
        if start_flag == False:
            start_flag = True
        elif do_record:

            #   Read twice the chunk size--we have 2 channels
            data = tester.audio_read(SLOT_ADC, chunk_size * 2, timeout=200)
            rec_data.append(data)
            samples_read += data.shape[0]
            #print 'samples_read = %d' % samples_read
            
        #tester.fifo_status(display=True)

    
    if do_record:
        time.sleep(0.1) #   temporary... need to ensure everything actually gets played
        tester.stop_playback(SLOT_DAC) #  assists with triggering
        tester.stop_recording(SLOT_ADC)
        time.sleep(0.01)
    
    #   Get FIFO status and then retrieve any lingering samples
    status = tester.fifo_status(display=True)
    leftover_samples = status[4][0] - status[4][1]
    rec_data.append(tester.audio_read(SLOT_ADC, leftover_samples, perform_update=True, timeout=1000))
    
    #   Flush the backend
    backend.flush(display=True)

    if do_record:

        rec_data = numpy.concatenate(rec_data)
        
        print 'Runtime: %.3f sec (T = %.3f sec / N = %d)' % (get_elapsed_time(time_start), T, N)
        
        #   Now we can fiddle with the data.... at least the nonzero part
        rec_st = rec_data.reshape((rec_data.shape[0] / 2, 2))
        nz_all = numpy.nonzero(rec_st)
        nz_src = numpy.nonzero(x_st_int)
        if nz_all[0].shape[0] > 0:
            nz_start_src = nz_src[0][0]
            nz_end_src = nz_src[0][-1]
        
            nz_start = nz_all[0][0]
            nz_end = nz_all[0][-1]
            
            x_int = numpy.concatenate(x_int)
            x_int_nz = x_int[(2 * nz_start_src):(2 * nz_end_src)]
            rec_st_nz = rec_st[nz_start:nz_end+1]
            rec_nz = rec_st_nz.flatten()
            
            Nsrc = x_int_nz.shape[0]
            Ns = Nsrc
            if rec_nz.shape[0] < Nsrc:
                print 'Error: received %d/%d nonzero samples' % (rec_nz.shape[0], Ns)
                Ns = rec_nz.shape[0]
            
            #   Convert to 24-bit int
            rec_nz[rec_nz >= 0x800000] -= 0x1000000
            
            print 'First nonzero sample = %d; last nonzero sample = %d' % (nz_start, nz_end)
            n_err = numpy.sum(rec_nz[:Ns] != x_int_nz[:Ns])
            print '%d/%d samples differ' % (n_err, Ns)
            if n_err > 0:
                print 'Error inds: %s' % numpy.nonzero(rec_nz[:Ns] != x_int_nz[:Ns])

            #   Do the figure only if we have a "reasonable" number of samples
            skip = 1
            if Ns > 100000:
                skip = int(Ns / 100000)
            pyplot.figure()
            pyplot.hold(True)
            pyplot.plot(x_int_nz[::skip], 'b')
            pyplot.plot(rec_nz[::skip], 'r--')
            pyplot.grid(True)
            #pyplot.show()
            pyplot.savefig('foo.pdf')
        else:
            print 'Error, did not receive any nonzero samples'

        #pdb.set_trace()
        
    backend.close()
    
