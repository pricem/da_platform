#!/usr/bin/env python

import sys
from datetime import datetime
import numpy
import time
import numpy.random
import scipy.io.wavfile
import scipy.fftpack
import pdb
from matplotlib import pyplot

import pickle

from backends.da_platform import DAPlatformBackend
from modules.base import ModuleBase

from modules.ak4490 import AK4490Module
from modules.ak4458 import AK4458Module
from modules.ak5578 import AK5578Module
from modules.ak5572 import AK5572Module
from utils import get_color

SLOT_ADC = 3
NUM_CHANNELS_ADC = 8

SLOT_DAC = 2
NUM_CHANNELS_DAC = 8

F_s = 44100.
#F_s = 96000.

def run_loopback(x, t, dac, adc, display=False, debug_plot=False, main_channel=0):
    
    N = x.shape[0]
    x_st_int = (x * (1 << 24)).astype(numpy.int32)

    time_start = datetime.now()

    adc.start_recording(SLOT_ADC)
    
    #   4/4/2018 debug
    """
    for i in range(10):
        adc.fifo_status(display=True)
    adc.stop_recording(SLOT_ADC)
    
    pdb.set_trace()
    """
    samples_written = 0
    samples_read = 0
    do_record = True
    start_flag = False
    chunk_size = (1 << 13)
    rec_data = []

    #print adc.get_dirchan()
    #print 'N = %d, sample shape = %s' % (N, x_st_int.shape)

    #   TODO: Make this loop until DAC has read all of the samples we wrote.
    while samples_written < N:
        
        chunk = x_st_int[samples_written:samples_written+chunk_size]
        this_chunk_size = chunk.shape[0]
        """
        dac.audio_write(SLOT_DAC, chunk.flatten())

        samples_written += this_chunk_size
        if display: print 'Wrote %d samples' % samples_written

        if do_record:
            data = adc.audio_read(SLOT_ADC, chunk_size * NUM_CHANNELS_ADC, timeout=100)
            rec_data.append(data)
            samples_read += data.shape[0]
            if display: print 'samples_read = %d' % samples_read
        """
        #"""
        #   11/18 - NO REALLY, YOU GET DROPOUTS IF YOU DON'T DO THIS
        #   Delay first read so that we don't get a buffer underrun
        if start_flag:
            samples_to_read = chunk_size * NUM_CHANNELS_ADC
        else:
            samples_to_read = 0
            
        #   (self, slot_dac, slot_adc, data, timeout=100):
        data_read = adc.audio_read_write(SLOT_DAC, SLOT_ADC, chunk.flatten(), samples_to_read, timeout=1000)
        rec_data.append(data_read)
        #   print 'Data size = %s' % data_read.shape
        samples_read += data_read.shape[0]
        samples_written += chunk.shape[0]
        if display: print 'samples_read = %d, samples_written = %d' % (samples_read, samples_written)
        
        if start_flag == False:
            start_flag = True
        #"""
    
    #   Wait for DAC to flush its buffer
    time.sleep(chunk_size / F_s)
    adc.stop_recording(SLOT_ADC)

    #   Get FIFO status and then retrieve any lingering samples
    status = adc.fifo_status(display=display)
    leftover_samples = status[4+SLOT_ADC][0] - status[4+SLOT_ADC][1]
    leftover_samples -= (leftover_samples % 2)
    if display: print 'Retrieving %d leftover samples' % leftover_samples
    rec_data.append(adc.audio_read(SLOT_ADC, leftover_samples, perform_update=True, timeout=1000))
    
    time_elapsed = datetime.now() - time_start
    time_float = time_elapsed.seconds + 1e-6 * time_elapsed.microseconds

    #   TODO: Save file
    data = numpy.concatenate(rec_data)
    Ns_trunc = data.shape[0] & 0xFFFFFFF8
    data = data[:Ns_trunc]
    N = data.shape[0] / NUM_CHANNELS_ADC
    data = data.reshape((N, NUM_CHANNELS_ADC))
    data[data > (1 << 23)] -= (1 << 24)
    
    data_float = data.astype(float) / (1 << 24)
    rms_level = 20 * numpy.log10(numpy.mean(data_float ** 2) ** 0.5)
    
    #scipy.io.wavfile.write(filename, F_s, data)
    #print 'Saved %d samples (%.3f sec) to %s.  RMS level = %.2f dBFS' % (N, N / F_s, filename, rms_level)
    if display: print 'Runtime: %.3f sec to collect %.3f sec audio' % (time_float, N / F_s)

    #   Do FFT of largest 2^N sized segment
    start_ind = 1 << 12    #   11/24/2017: Set to avoid any lag issues in sweeps
    m_fft = int(numpy.floor(numpy.log2(data.shape[0] - start_ind)))
    N_fft = 2 ** m_fft
    x1 = data[start_ind:start_ind+N_fft].astype(float) / (1 << 24)
    if display: print 'FFT size: %d' % N_fft
    t = numpy.linspace(-numpy.pi, numpy.pi, N_fft)
    t = numpy.expand_dims(t, 1).repeat(data.shape[1], axis=1)
    w = 0.5 * (1 + numpy.cos(t))
    #   Try not windowing.  11/21/2017
    #X = scipy.fftpack.fft(x1, axis=0)
    X = scipy.fftpack.fft(x1 * w, axis=0)
    freq = numpy.linspace(0, F_s / 2, N_fft / 2 + 1)
    #   Note: scaling for pos-only freq, and for +/- 0.5 (rather than 1.0) range
    ampl = numpy.abs(X[:(N_fft / 2 + 1)] / N_fft * 8)
    ampl_db = 20 * numpy.log10(ampl)
    if display: print 'Hz/bin: %f' % (44100. / N_fft)
    if display: print 'Noise floor RMS in dBFS'
    if display: print 20 * numpy.log10(numpy.sum(ampl[10:(N_fft / 2), :] ** 2, axis=0) ** 0.5)

    #   Compute mask for SNDR calc.
    #   Restrict noise bandwidth for SNDR to 20--20k Hz (in particular noise floor tends to go up at LF)
    sndr_dc_cutoff = int(20 * (N_fft / F_s))
    sndr_hf_cutoff = int(20000 * (N_fft / F_s))
    #sndr_hf_cutoff = N_fft / 2  #   11/24/2017: Don't limit BW for 96k tests
    
    sndr_mask = numpy.ones((N_fft / 2 + 1,))
    sndr_mask[:sndr_dc_cutoff] = 0
    sndr_mask[sndr_hf_cutoff:] = 0
    freq_ind = numpy.argmax(ampl_db[sndr_dc_cutoff:sndr_hf_cutoff, main_channel]) + sndr_dc_cutoff
    sndr_masked_width = 15
    sndr_sig_start = max(0, freq_ind - sndr_masked_width)
    sndr_sig_end = min(N_fft / 2 + 1, freq_ind + sndr_masked_width)
    sndr_mask[sndr_sig_start:sndr_sig_end] = 0
            
    results_by_channel = {}
    #   THD/SNR/SNDR analysis
    for channel in range(NUM_CHANNELS_ADC):
        try:
            ampl_rms = numpy.mean(x1[:, channel] ** 2) ** 0.5
            if display: print '-- THD analysis for channel %d' % channel
            ampl_db_peak = numpy.max(ampl_db[:, channel])
            freq_ind = numpy.argmax(ampl_db[:, channel])
            if display: print 'THD: carrier (%.2f kHz) is %.2f dB, ind %d' % (freq[freq_ind] / 1e3, ampl_db_peak, freq_ind)
            
            sum_of_squares = 0
            sos_ho = 0
            
            thd_rel_ampl = []
            base_freq_ind = freq_ind
            harm_ind = 1
            peak_search_dist = 5
            while harm_ind < 10 and freq_ind < N_fft / 2:
                harm_ind += 1
                freq_ind = harm_ind * base_freq_ind
                if freq_ind > N_fft / 2:
                    break
                freq_ind += (numpy.argmax(ampl_db[freq_ind-peak_search_dist:freq_ind+peak_search_dist, channel]) - peak_search_dist)
                ampl_thd = ampl_db[freq_ind, channel]
                ampl_rel = ampl_thd - ampl_db_peak
                if display: print 'THD: harmonic %d (%.2f kHz) is %.2f dB, ind %d - %.2f dB abs.' % (harm_ind, freq[freq_ind] / 1e3, ampl_rel, freq_ind, ampl_thd)
                thd_rel_ampl.append(ampl_rel)
                sum_of_squares += (10 ** (ampl_rel / 10.))
                if harm_ind > 3:
                    sos_ho += (10 ** (ampl_rel / 10.))
                
            hd_total = 10 * numpy.log10(sum_of_squares)
            hd_ho = 10 * numpy.log10(sos_ho)
            if display: print '  -> THD for channel %d is %.2f dB via sum of squares (%.2f dB high order)' % (channel, hd_total, hd_ho)

            ampl_masked = ampl[:, channel] * sndr_mask
            
            rms_masked = numpy.sum(ampl_masked ** 2) ** 0.5
            sndr_db = ampl_db_peak - 20 * numpy.log10(rms_masked)
            if display: print '-- SNDR for channel %d = %.2f dB' % (channel, sndr_db)
            
            results_by_channel[channel] = {
                'ampl_rms': 20 * numpy.log10(ampl_rms * (2 ** 1.5)),
                'carrier_freq': freq[base_freq_ind],
                'carrier_ampl': ampl_db_peak,
                'total_hd_rel_ampl': hd_total,
                'other_hd_rel_ampl': hd_ho,
                'sndr': sndr_db,
            }
            if len(thd_rel_ampl) > 0:
                results_by_channel[channel]['hd2_rel_ampl'] = thd_rel_ampl[0]
            if len(thd_rel_ampl) > 1:
                results_by_channel[channel]['hd3_rel_ampl'] = thd_rel_ampl[1]
            
        except IndexError as e:
            raise
        except Exception as e:
            #   Eh, whatever.
            if display: print 'Error processing THD/SNDR for channel %d: %s' % (channel, str(e))
            pass

    if debug_plot:
        #   t_plot = numpy.linspace(0, x1.shape[0] / F_s, x1.shape[0]) 
        t_plot = numpy.arange(x1.shape[0])
        #"""
        pyplot.figure(figsize=(16, 12))
        pyplot.hold(True)
        for i in range(data.shape[1]):
            pyplot.plot(t_plot, x1[:, i])
        pyplot.xlabel('Time (samples)')
        pyplot.ylabel('Amplitude (a. u.)')
        pyplot.title('Waveform captured from DAC/ADC loopback')
        pyplot.grid(True)
        #"""
        pyplot.figure(figsize=(16, 12))
        pyplot.hold(True)
        #   temp debug
        pyplot.plot(freq, (sndr_mask - 1) * 150, 'k-')
        for i in range(data.shape[1]):
            pyplot.plot(freq, ampl_db[:, i], color=get_color(NUM_CHANNELS_ADC, i))
        pyplot.xlabel('Frequency (Hz)')
        pyplot.ylabel('Amplitude (dBFS)')
        pyplot.title('Spectrum captured from DAC/ADC loopback')
        pyplot.xlim([0, 20500])
        pyplot.xticks(numpy.arange(0, 21000, 1000))
        #pyplot.xlim([0, 40000])
        #pyplot.ylim([-150, -100])
        pyplot.ylim([-170, 10])
        pyplot.yticks(numpy.arange(-170, 20, 10))
        pyplot.grid(True)
        labels = ['Ch %d' % i for i in range(1, NUM_CHANNELS_ADC + 1)]
        pyplot.legend(labels, loc='upper right')
        print 'Plotting; results = %s' % results_by_channel
        pyplot.show()
        
    return results_by_channel

def sine_loopback(freq, level_db, dac, adc, T=1.0, freq_spread=1.0, **kwargs):
    
    #   Allow some spread in the stimulus for the different channels
    F_sine = freq * numpy.linspace(1.0, freq_spread, NUM_CHANNELS_DAC)

    #   "Snap" each frequency to an FFT bin so we get consistent amplitudes (fundamental and harmonics)
    N = F_s * T - (1 << 12)
    N_fft = 1 << int(numpy.log2(N))
    bin_width = 2 * F_s / N_fft
    for i in range(NUM_CHANNELS_DAC):
        F_sine[i] = bin_width * round(F_sine[i] / bin_width)
    
    t = numpy.expand_dims(numpy.linspace(0, (N - 1) / F_s, N), 1).repeat(NUM_CHANNELS_DAC, axis=1)
    x = 0.5 * numpy.sin(2 * numpy.pi * F_sine * t) * (10 ** (level_db / 20.0))
    
    return run_loopback(x, t, dac, adc, **kwargs)

def test_sweep(dac, adc):

    #adc.set_format(SLOT_ADC, DAPlatformBackend.I2S)
    
    #   ------------------------------
    results_dict = {}
    ch = 0
    sig_ampl = -0.1
    kwargs = {'display': False, 'debug_plot': False, 'main_channel': ch}

    def do_test(freq):
        result = sine_loopback(freq, sig_ampl, dac, adc, 1.0, **kwargs)
        if ch in result:
            r = result[ch]
            results_dict[freq] = r
            print 'Freq %.0f Hz: RMS = %.2f dB, carrier = %.2f dB, THD = %.2f dB, SNDR = %.2f dB' % (freq, r['ampl_rms'], r['carrier_ampl'], r['total_hd_rel_ampl'], r['sndr'])
        else:
            print 'Didn\'t get a valid result at freq %.0f Hz' % freq
    
    freq_start = 20.0
    freq_end = 20000.0
    num_points = 151
    retest = True
    #freq_list = numpy.logspace(1, 4, 301) * 2
    #freq_list = numpy.logspace(3, 4, 31) * 4
    freq_list = numpy.logspace(numpy.log10(freq_start), numpy.log10(freq_end), num_points)
    
    #   Dummy to get loop started
    sine_loopback(freq_list[0], sig_ampl, dac, adc, 1.0,  **kwargs)
    
    for freq in freq_list:
        do_test(freq)

    date_code = datetime.now().strftime('%Y%m%d_%H%M%S')
    save_file = 'loopback_%s_ch%d.pickle' % (date_code, ch)
    file_out = open(save_file, 'wb')
    pickle.dump(results_dict, file_out)
    file_out.close()
    print 'Saved results to %s' % save_file

    retest_counts = {}

    def extract_var(varname):
        return numpy.array([results_dict.get(freq, {}).get(varname, float('-inf')) for freq in freq_list])

    def filter_bad_inds(ind):
        #   Make sure we don't think the SNDR steps around 6.66k / 10k are "bad" and need to be retested
        bad_freqs = [2e4 / 3, 2e4 / 2]
        
        if ind not in retest_counts:
            retest_counts[ind] = 0
        retest_counts[ind] += 1
    
        if ind in retest_counts and retest_counts[ind] > 5:
            return False
        if ind == 0 or ind == num_points - 1:
            return True
        for bf in bad_freqs:
            if freq_list[ind] < bf and freq_list[ind+1] > bf:
                return False
            if freq_list[ind - 1] < bf and freq_list[ind] > bf:
                return False
        return True

    def find_bad_freqs(varname, tol):
        vals = extract_var(varname)
        bad_inds = numpy.nonzero(numpy.abs(numpy.diff(vals, n=2)) > tol)[0]
        return filter(filter_bad_inds, bad_inds + 1)

    if retest:
        #   Re-test frequencies where there are large jumps in SNDR
        #   (someday, find out why exactly this is necessary...)
        bad_inds = find_bad_freqs('sndr', 8)
        num_bad_freqs = len(bad_inds)
        while num_bad_freqs > 0:
            print 'RETEST: Bad freqs: %s' % ([freq_list[x] for x in bad_inds])
            for ind in bad_inds:
                do_test(freq_list[ind])
            bad_inds = find_bad_freqs('sndr', 8)
            num_bad_freqs = len(bad_inds)

    pyplot.figure()
    pyplot.hold(True)
    pyplot.semilogx(freq_list, extract_var('carrier_ampl') - sig_ampl)
    #pyplot.xlim([20, 20000])
    pyplot.xlabel('Frequency (Hz)')
    pyplot.ylabel('Amplitude (dBFS)')
    pyplot.title('DAC/ADC loopback frequency response')
    pyplot.grid(True)
    pyplot.savefig('%s_fr.pdf' % date_code)
    
    pyplot.figure()
    pyplot.hold(True)
    pyplot.semilogx(freq_list, extract_var('hd2_rel_ampl'))
    pyplot.semilogx(freq_list, extract_var('hd3_rel_ampl'))
    pyplot.semilogx(freq_list, extract_var('other_hd_rel_ampl'))
    pyplot.semilogx(freq_list, -extract_var('sndr'))
    #pyplot.xlim([20, 20000])
    pyplot.grid(True)
    pyplot.xlabel('Frequency (Hz)')
    pyplot.ylabel('Amplitude (dBc)')
    pyplot.title('DAC/ADC loopback distortion and noise')
    pyplot.legend(['H2', 'H3', 'H4-10', 'THD+N'], loc='lower right')
    pyplot.savefig('%s_dist.pdf' % date_code)
    
    pyplot.show()

def test_single_tone(dac, adc):
    print sine_loopback(1000, -0.1, dac, adc, 0.5, display=False, debug_plot=True, freq_spread=1.2, main_channel=0)

if __name__ == '__main__':
    backend = DAPlatformBackend(reset=True)

    if NUM_CHANNELS_DAC == 8:
        dac = AK4458Module(backend)
    elif NUM_CHANNELS_DAC == 2:
        dac = AK4490Module(backend)
    
    if NUM_CHANNELS_ADC == 8:
        adc = AK5578Module(backend)
    elif NUM_CHANNELS_ADC == 2:
        adc = AK5572Module(backend)
    dac.reset_slots()
    """
    dac.stop_clocks(SLOT_DAC)
    
    pdb.set_trace()
    dac.start_clocks(SLOT_DAC)
    """
    """
    dac.enter_reset()
    time.sleep(0.25)
    dac.leave_reset()
    """
    dac.select_clock(1) #   11.2896
    #   dac.select_clock(0)     #   24.576

    adc.setup(SLOT_ADC)
    dac.setup(SLOT_DAC)
    """
    #   4/5/2018 debug
    for i in range(4):
        adc.set_hwcon(i, 0)
    pdb.set_trace()
    """
    """
    #   11/20/2017: Disable stuff to see if that helps with glitches.
    adc.stop_sclk()
    for i in range(4):
        if i != SLOT_ADC and i != SLOT_DAC:
            adc.stop_clocks(i)
    time.sleep(1.0)
    """
    
    #   11/19/2017 - try with attenuation
    #   dac.set_attenuation(SLOT_DAC, 0)

    #test_sweep(dac, adc)
    test_single_tone(dac, adc)

