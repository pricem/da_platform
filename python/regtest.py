"""
Simultaneous play/record for supply regulator testing.
(And maybe other testing later?)
"""

import pyaudio
import wave
import time
import sys
import numpy
from datetime import datetime
from matplotlib import pyplot
import pdb

def time_since(t1):
    t2 = datetime.now()
    td = t2 - t1
    return td.seconds + 1e-6 * td.microseconds

class StreamSource(object):
    def __init__(self):
        self.pyaudio = pyaudio.PyAudio()
        
        self.stream = self.pyaudio.open(format=pyaudio.paInt32,
            channels=1,
            rate=48000,
            input=True, output=True,
            stream_callback=self.pyaudio_callback)

        self.received_samples = ''

    def pyaudio_callback(self, in_data, frame_count, time_info, status):
        time_so_far = time_since(self.start_time)
        print 'pyaudio_callback: frame count = %d time_info = %s status = %s; time so far = %f' % (frame_count, time_info, status, time_so_far)
        if time_so_far > self.time_limit:
            print 'Time limit reached'
            return (None, pyaudio.paComplete)
        
        print 'Input data length = %d' % len(in_data)
        self.received_samples += in_data
        
        samples_float = self.get_samples(frame_count)
        raw_data = samples_float.astype(numpy.int32).tostring()
        return (raw_data, pyaudio.paContinue)
    
    def postprocess(self, data):
        return numpy.fromstring(data, dtype=numpy.int32).astype(float) / (1 << 31)
    
    def get_samples(self, num_samples):
        raise NotImplementedError

    def run(self, time_limit):
        self.time_limit = time_limit
        self.stream.start_stream()
        self.start_time = datetime.now()
        while self.stream.is_active():
            time.sleep(0.05)
        self.stream.stop_stream()
        return self.postprocess(self.received_samples)

    def close(self):
        self.stream.close()
        self.pyaudio.terminate()

class StreamSource_Sine(StreamSource):
    def __init__(self, freq, ampl_db):
        super(StreamSource_Sine, self).__init__()
        self.freq = freq
        self.ampl_db = ampl_db
        self.sample_counter = 0
        
    def get_samples(self, num_samples):
        self.sample_counter += num_samples
        data = numpy.zeros((num_samples,))
        return data

if __name__ == '__main__':
    s = StreamSource_Sine(1000, -20)
    return_data = s.run(10)
    if return_data.shape[0] > 0:
        pyplot.plot(return_data)
        pyplot.show()
        

