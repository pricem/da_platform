import fpgalink2 as fpgalink
import wave
import numpy
import threading

USB_VIDPID = "1443:0005"

class AudioPlayer(object):
	"""
	thread_stop = False
	thread_buf_active = None
	thread_buf_next = None
	"""

	def __init__(self, *args, **kwargs):
		self.handle = fpgalink.flOpen(USB_VIDPID)

	def map_chunk(self, data):
		#	Convert to floating point
		values = numpy.fromstring(data, dtype=numpy.int16).astype(float) / 32768.0
		
		#	Volume control
		values /= 5
		print 'Max amplitude = %f' % numpy.max(numpy.abs(values))
		
		#	Convert to fixed point
		values = (values * 32768.0).astype(int)
		print 'Max int value = %d min = %d' % (numpy.max(values), numpy.min(values))
		
		print values
		
		values = ((32768 + values) >> 4).astype(numpy.uint16)
		print 'Max uint value = %d min = %d' % (numpy.max(values), numpy.min(values))
		
		#	Reorder bytes - LSB first
		#	return bytearray(values.byteswap().tostring())
		return bytearray(values.tostring())

	def play_tone(self):
		freq = 1000
		t = numpy.linspace(0, 1.0 * 44099 / 44100, 44100)
		print t
		values_left = 0.1 * numpy.sin(t * 2 * numpy.pi * freq)
		values = numpy.repeat(values_left, 2)
		print values
		
		#	Convert to fixed point
		values = (values * 32768.0).astype(int)
		print 'Max int value = %d min = %d' % (numpy.max(values), numpy.min(values))
		
		print values
		
		values = ((32768 + values) >> 4).astype(numpy.uint16)
		print 'Max uint value = %d min = %d' % (numpy.max(values), numpy.min(values))
		
		fpgalink.flWriteChannel(self.handle, 32760, 0x00, bytearray(values.tostring()))

	def play(self, filename, max_chunks=1000):
		#	Read a string of samples from a WAV file
		wf = wave.open(filename, 'rb')
		chunk = 44100
		data_all = ''
		data = wf.readframes(chunk)
		
		print 'Wrote %d bytes = %d samples = %d sec' % (len(data_all), len(data_all) / 4, len(data_all) / 4.41e4 / 4)
		i = 1
		while data != '' and i < max_chunks:
			data_all += data
			data = wf.readframes(chunk)
			fpgalink.flWriteChannel(self.handle, 32760, 0x00, self.map_chunk(data))
			print 'Wrote %d bytes = %d samples = %d sec' % (len(data_all), len(data_all) / 4, len(data_all) / 4.41e4 / 4)
			i += 1

	def close(self):
		fpgalink.flClose(self.handle)

if __name__ == '__main__':
	ap = AudioPlayer()
	ap.play('baskets.wav')
	#	ap.play_tone()
	ap.close()