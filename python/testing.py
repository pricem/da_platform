import fpgalink2 as fpgalink
import wave
import numpy
import numpy.random
import time
import threading

USB_VIDPID = "1443:0005"

class Tester(object):
	"""
	thread_stop = False
	thread_buf_active = None
	thread_buf_next = None
	"""

	REG_CONFIG = {
		'ATL': (16, 0, 8),
		'ATR': (17, 0, 8),
		'MUTE': (18, 0, 1),
		'DME': (18, 1, 1),
		'DMF': (18, 2, 2),
		'FMT': (18, 4, 3),
		'ATLD': (18, 7, 1),
		'INZD': (19, 0, 1),
		'FLT': (19, 1, 1),
		'DFMS': (19, 2, 1),
		'ZOE': (19, 3, 1),
		'OPE': (19, 4, 1),
		'ATS': (19, 5, 2),
		'REV': (19, 7, 1),
		'OS': (20, 0, 2),
		'CHSL': (20, 2, 1),
		'MONO': (20, 3, 1),
		'DFTH': (20, 4, 1),
		'DSD': (20, 5, 1),
		'SRST': (20, 6, 1),
		'PCMZ': (21, 0, 1),
		'DZ': (21, 1, 2),
		'ZFGL': (22, 0, 1),
		'ZFGR': (22, 1, 1),
		'ID': (23, 0, 5),
	}

	def __init__(self, *args, **kwargs):
		self.handle = fpgalink.flOpen(USB_VIDPID)
		self.select_clocks(0)

	def write(self, array):
		fpgalink.flWriteChannel(self.handle, 100, 0x00, bytearray(array.tostring()))

	def read(self, num_bytes):
		return numpy.fromstring(str(fpgalink.flReadChannel(self.handle, 100, 0x00, num_bytes)), dtype=numpy.uint8)

	def close(self):
		fpgalink.flClose(self.handle)

	def recover(self):
		#	Reset link in case of a timeout
		self.close()
		time.sleep(1)
		self.handle = fpgalink.flOpen(USB_VIDPID)
		
	def pprint(self, packet):
		return '[%s]' % ' '.join(['%02X' % x for x in packet])
		
	def transaction(self, cmd, num_bytes):
		self.write(cmd)
		return self.read(num_bytes)
		
	def get_dirchan(self):
		result = self.transaction(numpy.array([0xFF, 0x41], dtype=numpy.uint8), 3)
		dval = result[2]
		for slot in range(4):
			dirslot = 1 * ((dval & (1 << slot)) > 0)
			chanslot = 1 * ((dval & (1 << (slot + 4))) > 0)
			print 'Slot %d: Direction = %d, Channels = %d' % (slot, dirslot, chanslot)
		#	print 'Result of get_dirchan = %s' % self.pprint(result)

	def get_aovf(self):
		result = self.transaction(numpy.array([0xFF, 0x43], dtype=numpy.uint8), 3)
		dval = result[2]
		for slot in range(4):
			ovfl = 1 * ((dval & (1 << (slot * 2))) > 0)
			ovfr = 1 * ((dval & (1 << (slot * 2 + 1))) > 0)
			print 'Slot %d: Left overflow = %d, right overflow = %d' % (slot, ovfl, ovfr)
		#	print 'Result of get_aovf = %s' % self.pprint(result)

	def spi_write(self, slot, addr, data):
		checksum = 0x60 + addr + data
		cmd = numpy.array([slot, 0x20, 0x00, 0x00, 0x03, 0x60, addr, data, checksum / 256, checksum % 256], dtype=numpy.uint8)
		self.write(cmd)
		#	print 'Wrote command for SPI write: %s' % self.pprint(cmd)

	def spi_read(self, slot, addr):
		checksum = 0x61 + addr + 0x80
		cmd = numpy.array([slot, 0x20, 0x00, 0x00, 0x02, 0x61, addr + 0x80, checksum / 256, checksum % 256], dtype=numpy.uint8)
		response = self.transaction(cmd, 7)
		#	print 'Wrote command for SPI read: %s' % self.pprint(cmd)
		#	print 'Got response for SPI read: %s' % self.pprint(response)
		return response[-1]

	def dsd1792_spi_summary(self, slot=0):
		reg_base = 16
		vals = [self.spi_read(slot, x) for x in range(16, 24)]
		result_dict = {}
		keys = Tester.REG_CONFIG.keys()
		keys.sort()
		for key in keys:
			(reg_index, start_bit, num_bits) = Tester.REG_CONFIG[key]
			bit_mask = 0
			for i in range(num_bits):
				bit_mask |= (1 << (start_bit + i))
			val = (vals[reg_index - reg_base] & bit_mask) >> start_bit
			result_dict[key] = val
			print '%6s = %3d' % (key, val)

		return result_dict

	def dsd1792_set_reg(self, reg_name, new_val, slot=0):
		(reg_index, start_bit, num_bits) = Tester.REG_CONFIG[reg_name]
		bit_mask = 0
		for i in range(num_bits):
			bit_mask |= (1 << (start_bit + i))
		current_val = self.spi_read(slot, reg_index)
		new_val = (current_val & (~bit_mask)) | (new_val << start_bit)
		print 'Updating register 0x%02x from 0x%02x to 0x%02x' % (reg_index, current_val, new_val)
		self.spi_write(slot, reg_index, new_val)

	def audio_write(self, slot, samples):
		#	Samples should be an Nx2 array of floats on [-1, 1) - this function handles conversion
		assert(len(samples.shape) == 2)
		assert(samples.shape[1] == 2)
		N = samples.shape[0]
		num_bits = 24
		min_val = -(2 ** (num_bits - 1))
		max_val = (2 ** (num_bits - 1)) - 1
		scale = 2 ** (num_bits - 1)
		samples_int = (samples * scale).astype(int)	#	now from 0 to 2 ** N
		print samples_int[:4]
		samples_int[samples_int > max_val] = max_val
		samples_int[samples_int < min_val] = min_val
		print samples_int[:4]
		
		num_bytes = N * 6
		
		cmd = numpy.zeros((N * 6 + 7,), dtype=numpy.uint8)
		cmd[0] = slot
		cmd[1] = 0x10
		cmd[2] = num_bytes / 65536
		cmd[3] = (num_bytes / 256) % 256
		cmd[4] = num_bytes % 256
		for i in range(N):
			cmd[5 + i * 6 + 0] = samples_int[i][0] / 65536
			cmd[5 + i * 6 + 1] = (samples_int[i][0] / 256) % 256
			cmd[5 + i * 6 + 2] = samples_int[i][0] % 256
			cmd[5 + i * 6 + 3] = samples_int[i][1] / 65536
			cmd[5 + i * 6 + 4] = (samples_int[i][1] / 256) % 256
			cmd[5 + i * 6 + 5] = samples_int[i][1] % 256
	
		checksum = numpy.sum(cmd[5:]) % 65536
			
		cmd[5 + N * 6] = checksum / 256
		cmd[6 + N * 6] = checksum % 256
		
		self.write(cmd)
		"""
		try:
			response = self.read(6)
			if response.shape[0] == 6:
				print 'Got checksum error: %s' % self.pprint(response)
		except:
			self.recover()
		"""
		#	print 'Wrote command for audio samples: %s' % self.pprint(cmd)

	def play_tone(self, freq=1000.0, duration=1.0, amplitude=1.0, slot=0):
		Fs = 44100.
		Ns = duration * Fs
		t = numpy.linspace(0, (Ns - 1) / Fs, Ns)
		y = amplitude * numpy.cos(2 * numpy.pi * t * freq)
		data = numpy.repeat(numpy.atleast_2d(y).T, 2, axis=1)
		
		max_samples = 3000
		num_chunks = (int(Ns) - 1) / max_samples + 1
		print 'Breaking %d samples into %d chunks' % (Ns, num_chunks)
		for i in range(num_chunks):
			start_index = i * max_samples
			end_index = (i + 1) * max_samples
			if end_index > Ns:
				end_index = Ns
			self.audio_write(slot, data[start_index:end_index])
			print 'Wrote %d samples avg = %f' % ((end_index - start_index), numpy.mean(data[start_index:end_index, 0]))
			#	print 'ZFG reg = 0x%02x' % self.spi_read(0, 0x96)

	def play_square(self, duration=1.0, amplitude=1.0, slot=0):
		Fs = 44100.
		Ns = duration * Fs
		t = numpy.linspace(0, (Ns - 1) / Fs, Ns)
		y = amplitude * numpy.ones((Ns,))
		y[::2] *= -1
		data = numpy.repeat(numpy.atleast_2d(y).T, 2, axis=1)
		
		max_samples = 3000
		num_chunks = (int(Ns) - 1) / max_samples + 1
		print 'Breaking %d samples into %d chunks' % (Ns, num_chunks)
		for i in range(num_chunks):
			start_index = i * max_samples
			end_index = (i + 1) * max_samples
			if end_index > Ns:
				end_index = Ns
			self.audio_write(slot, data[start_index:end_index])
			print 'Wrote %d samples avg = %f' % ((end_index - start_index), numpy.mean(data[start_index:end_index, 0]))
			#	print 'ZFG reg = 0x%02x' % self.spi_read(0, 0x96)

	def select_clocks(self, clksel):
		cmd = numpy.array([0xFF, 0x40, clksel], dtype=numpy.uint8)
		self.write(cmd)
		print 'Wrote command for clock select: %s' % self.pprint(cmd)

	def random_data(self, N):
		return (numpy.random.random(N) * 256).astype(numpy.uint8)

	def echo(self, data):
		N = data.shape[0]
		cmd = numpy.zeros((N+3,), dtype=numpy.uint8)
		cmd[0] = 0xFF
		cmd[1] = 0x45
		cmd[2] = N
		cmd[3:N+3] = data
		response = self.transaction(cmd, N + 3)
		if response[0] != 0xFF or response[1] != 0x46 or response[2] != N:
			raise Exception('Unexpected header from echo: %s' % response)
		
		data_returned = response[3:N+3]
		if numpy.sum(data_returned != data) == 0:
			print 'Echo of %d bytes succeeded' % N
		else:
			print 'Echo of %d bytes incorrect: sent %s, received %s' % (N, data, data_returned)

if __name__ == '__main__':
	Fs = 44100.
	Ft = 1000.
	Ns = 100
	t = Tester()
	#	dirchan_read_msg = numpy.array()
	example_audio_samples = numpy.array([[0.1, 0.05], [0.05, 0.02], [-0.05, -0.08]])
	st = numpy.linspace(0, (Ns - 1) / Fs, Ns)
	y = 0.1 * numpy.sin(2 * numpy.pi * st * Ft)		# -60 dB at freq Ft
	audio_2 = numpy.repeat(numpy.atleast_2d(y).T, 2, axis=1)
	
	echo_data = numpy.array([0x45, 0x81, 0xC4, 0x49], dtype=numpy.uint8)
	spi_write_msg = numpy.array([0x00, 0x20, 0x00, 0x00, 0x03, 0x60, 0x10, 0x58, 0x00, 0xC8], dtype=numpy.uint8)
	audio_write_msg = numpy.array([0x00, 0x10, 0x00, 0x00, 0x06, 0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC, 0x02, 0x6A], dtype=numpy.uint8)
	