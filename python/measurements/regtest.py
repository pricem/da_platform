"""
    Open-source digital audio platform
    Copyright (C) 2009--2018 Michael Price

    regtest.py: Script for voltage regulator testing.

    Warning: Use and distribution of this code is restricted.
    This software code is distributed under the terms of the GNU General Public
    License, version 3.  Other files in this project may be subject to
    different licenses.  Please see the LICENSE file in the top level project
    directory for more information.
"""

import sounddevice as sd
import wave
import time
import sys
import numpy
import scipy.fftpack
import scipy.signal
from datetime import datetime
from matplotlib import pyplot
import pdb
import os
import os.path

from plotting import custom_formatter

#   Device configuration.  [1, 8] is MME drievr for "line in" and "speakers"
#   [13, 20] for Directsound; [32, 26] WASAPI; [42, 45] WDM-KS
sd.default.device = [42, 45]
sd.default.samplerate = 48000

def time_since(t1):
    t2 = datetime.now()
    td = t2 - t1
    return td.seconds + 1e-6 * td.microseconds

class StreamSource(object):
    def __init__(self):
        self.F_s = 48000.
        self.received_samples = ''

    def sd_callback(self, in_data, out_data, frame_count, time_info, status):
        time_so_far = time_since(self.start_time)
        #print 'sd_callback: frame count = %d time_info = %s status = %s; time so far = %f' % (frame_count, time_info, status, time_so_far)
        
        #print 'Input data length = %d' % len(in_data)
        self.received_samples += in_data[:]
        
        samples_float = self.get_samples(frame_count)
        samples_int = (samples_float * (1 << 31)).astype(numpy.int32)
        raw_data = samples_int.tostring()
        
        out_data[:] = raw_data

    def postprocess(self, data):
        return numpy.fromstring(data, dtype=numpy.int32).astype(float) / (1 << 31)
    
    def get_samples(self, num_samples):
        raise NotImplementedError

    def run(self, time_limit):
        self.start_time = datetime.now()
        with sd.RawStream(channels=1, dtype='int32', callback=self.sd_callback):
            sd.sleep(int(time_limit * 1000))

        return self.postprocess(self.received_samples)

    """
    def close(self):
        self.stream.close()
        self.pyaudio.terminate()
    """

class StreamSource_Zero(StreamSource):
    def __init__(self):
        super(StreamSource_Zero, self).__init__()
        self.sample_counter = 0
        
    def get_samples(self, num_samples):
        self.sample_counter += num_samples
        data = numpy.zeros((num_samples,))
        return data

class StreamSource_Sine(StreamSource):
    def __init__(self, freq, ampl_db):
        super(StreamSource_Sine, self).__init__()
        self.freq = freq
        self.ampl_db = ampl_db
        self.sample_counter = 0
        
    def get_samples(self, num_samples):
        t = numpy.arange(num_samples) + self.sample_counter
        self.sample_counter += num_samples
        #   data = numpy.zeros((num_samples,))
        data = (10 ** (self.ampl_db / 20.)) * numpy.sin(2 * numpy.pi * (t / self.F_s) * self.freq)
        return data

def get_power_spectrum(data, start_sample, fft_length, num_averages, F_s):
    freq = numpy.linspace(0, F_s / 2., fft_length / 2 + 1)
    ampl = numpy.zeros((fft_length / 2 + 1,))
    
    for i in range(num_averages):
        start = start_sample + i * fft_length
        end = start + fft_length
        data_in = data[start:end] * scipy.signal.hanning(fft_length)
        data_fft = scipy.fftpack.fft(data_in)[:fft_length / 2 + 1]
        ampl += numpy.abs(data_fft) / num_averages
    
    bin_width = float(F_s) / fft_length
    
    ampl_db = 20 * numpy.log10(ampl * 4 / fft_length)   #   6 dB for fact that we have pos. freq only, 6 dB for window
    return (freq, ampl_db)

def get_sine_ampl(freq, ampl_db, f0, offset, F_s):
    ampl_db += offset
    #   Add up the energy in a small window to account for spreading
    win_half_width = 10
    freq_index = float(f0) * (freq.shape[0] - 1) / (F_s / 2)
    start = int(freq_index) - win_half_width
    end = int(freq_index) + win_half_width + 1
    ampl_within_win = ampl_db[start:end]
    return 20 * numpy.log10(numpy.sum(10 ** (ampl_within_win / 20.)))

def get_fr(stim_freqs, result_file):
    num_points = stim_freqs.shape[0]
    fr_data = numpy.zeros((num_points,))

    for i in range(num_points):

        stimulus_freq = stim_freqs[i]

        #   Level -16.2 dB with Windows volume at 50 = 100 mV RMS
        s = StreamSource_Sine(stimulus_freq, -16.2)
        
        #   Input level: 100 mV turns out to be -25.8 dB
        display_offset = 25.76
        
        fft_length = 1 << 16
        startup_latency = 24000
        F_s = 48000
        N_avg = 1
        return_data = s.run((startup_latency + fft_length * N_avg) / float(F_s))

        (freq, ampl_db) = get_power_spectrum(return_data, startup_latency, fft_length, N_avg, F_s)

        sine_ampl = get_sine_ampl(freq, ampl_db, stimulus_freq, display_offset, F_s)
        print '   Amplitude at %f Hz = %.2f dB' % (stimulus_freq, sine_ampl)
        fr_data[i] = sine_ampl

    #   Save results
    numpy.savetxt(result_file, fr_data)

def get_nsd(freq_file, result_file):
    s = StreamSource_Zero()
    display_offset = 25.76
    
    fft_length = 1 << 16
    startup_latency = 24000
    F_s = 48000
    N_avg = 40
    return_data = s.run((startup_latency + fft_length * N_avg) / float(F_s))

    (freq, ampl_db) = get_power_spectrum(return_data, startup_latency, fft_length, N_avg, F_s)

    #   Convert dB to density - 0 dB = 100 mV
    fft_bin_width = float(F_s) / fft_length
    ampl_density = (10 ** ((ampl_db + display_offset - 20) / 20.0)) / fft_bin_width

    numpy.savetxt(freq_file, freq)
    numpy.savetxt(result_file, ampl_density * 1e9)
    
def get_imp(stim_freqs, result_file):
    num_points = stim_freqs.shape[0]
    fr_data = numpy.zeros((num_points,))

    for i in range(num_points):

        stimulus_freq = stim_freqs[i]

        #   Level -16.2 dB with Windows volume at 50 = 100 mV RMS
        s = StreamSource_Sine(stimulus_freq, -16.2)
        
        #   Input level: 100 mV turns out to be -25.8 dB
        display_offset = 25.76
        
        fft_length = 1 << 16
        startup_latency = 24000
        F_s = 48000
        N_avg = 1
        return_data = s.run((startup_latency + fft_length * N_avg) / float(F_s))

        (freq, ampl_db) = get_power_spectrum(return_data, startup_latency, fft_length, N_avg, F_s)

        sine_ampl = get_sine_ampl(freq, ampl_db, stimulus_freq, display_offset, F_s)
        
        #   4 mA RMS current
        load_current = 0.1 / 25
        #   Amplitude is rel. 100 mV
        ampl_v = 10 ** ((sine_ampl - 20.) / 20.)
        imp_ohm = ampl_v / load_current

        print '   Amplitude at %f Hz = %.2f dB -> impedance = %.2f mOhm' % (stimulus_freq, sine_ampl, imp_ohm * 1e3)
        """
        #   Debug
        pyplot.figure()

        pyplot.semilogx(freq, ampl_db)
        pyplot.xlim([10, 20000])

        pyplot.grid(True)

        pyplot.xlabel('Frequency (Hz)')
        pyplot.ylabel('Magnitude (dB)')
        pyplot.title('Output imp debug')
        
        pyplot.show()
        """
        fr_data[i] = imp_ohm

    #   Save results
    numpy.savetxt(result_file, fr_data)

if __name__ == '__main__':
    #   Line rejection measurement

    #   a) Measure frequency response over desired range at input port
    points_per_octave = 3
    num_octaves = numpy.log2(20000.) - numpy.log2(10.)
    num_points = numpy.ceil(num_octaves * points_per_octave)
    max_freq = 10. * (2 ** (float(num_points - 1) / points_per_octave))
    stim_freqs = 10. * (2 ** (numpy.arange(num_points) / points_per_octave))
    
    data_dir = raw_input('Enter data dir name -> ')
    prefix = raw_input('Enter regulator prefix -> ')
    
    if not os.path.exists(data_dir):
        os.makedirs(data_dir)
    
    #data_dir = 'data/jun25'
    #prefix = 'lm317_pos2'
    
    numpy.savetxt(os.path.join(data_dir, '%s_freq.txt' % prefix), stim_freqs)
    
    #   OEVRRIDE
    #stim_freqs = numpy.array([ 1000, ])

    print '-- Calibration of input frequency response'
    raw_input('Connect soundcard output to LINE INPUT, and INPUT PORT to soundcard input and press ENTER')
    get_fr(stim_freqs, os.path.join(data_dir, '%s_cal.txt' % prefix))
    
    print '-- Line rejection measurement'
    raw_input('Connect soundcard output to LINE INPUT, and OUTPUT PORT to soundcard input and press ENTER')
    get_fr(stim_freqs, os.path.join(data_dir, '%s_linerej.txt' % prefix))

    print '-- Noise density measurement'
    raw_input('Connect soundcard output to LINE INPUT, and OUTPUT PORT to soundcard input and press ENTER')
    get_nsd(os.path.join(data_dir, '%s_noise_freq.txt' % prefix), os.path.join(data_dir, '%s_noise_nsd.txt' % prefix))

    print '-- Output impedance measurement'
    raw_input('Connect soundcard output to LOAD INPUT, and OUTPUT PORT to soundcard input and press ENTER')
    get_imp(stim_freqs, os.path.join(data_dir, '%s_outimp.txt' % prefix))
