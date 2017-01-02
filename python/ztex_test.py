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
from matplotlib import pyplot

def get_elapsed_time(time_start):
    time_end = datetime.now()
    time_diff = time_end - time_start
    return time_diff.seconds + 1e-6 * time_diff.microseconds

#   Set to True for debugging
IO_DISPLAY = False

class EZUSBBackend(object):
    def __init__(self, dtype=numpy.uint16):
        self.context = usb1.USBContext()
        
        self.device = self.context.getByVendorIDAndProductID(0x221a, 0x0100)
        assert self.device
        self.handle = self.device.open()
        self.handle.resetDevice()
        self.handle.setConfiguration(1)
        self.handle.claimInterface(0)
        
        self.dtype=dtype
        self.bytes_per_word = numpy.dtype(dtype).itemsize
        
    def flush(self):
        flushed = False
        flush_count = 0
        while not flushed:
            try:
                flush_count += 1
                data = self.handle.bulkRead(MemFIFOBackend.EP_IN, 512, 100)
            except libusb1.USBError:
                flushed = True
        print 'Flushed FIFOs in %d iterations' % flush_count

    def close(self):
        self.handle.releaseInterface(0)
        self.handle.close()

    def read(self, num_words, fail_on_timeout=False, display=IO_DISPLAY, timeout=100):
        try:
            num_bytes = num_words * self.bytes_per_word
            result = self.handle.bulkRead(MemFIFOBackend.EP_IN, num_bytes, timeout)
        except usb1.USBErrorTimeout:
            result = ''
            if fail_on_timeout:
                raise

        result = numpy.fromstring(result, dtype=self.dtype)
        if display: print 'Got %d/%d words: %s' % (len(result), num_words, result)
        return result
    
    def write(self, data, display=IO_DISPLAY):
        num_bytes = self.handle.bulkWrite(MemFIFOBackend.EP_OUT, data.tostring())
        assert num_bytes == data.shape[0] * self.bytes_per_word
        num_words = num_bytes / self.bytes_per_word
        if display: print 'Wrote %d/%d words: %s' % (num_words, data.shape[0], data)

    def reset(self):
        self.handle.controlWrite(libusb1.LIBUSB_TYPE_VENDOR, 0x60, 0, 0, '')
        #pass
        
class MemFIFOBackend(EZUSBBackend):

    EP_IN = 0x82
    EP_OUT = 0x06

    def __init__(self):
    
        super(MemFIFOBackend, self).__init__(dtype=numpy.uint8)

        #   Reset and set mode 0
        self.reset()
        self.set_mode(0)
        self.flush()

    def set_mode(self, mode):
        gpio_val = numpy.fromstring(self.handle.controlRead(libusb1.LIBUSB_TYPE_VENDOR, 0x61, mode & 3, 3, 1), dtype=self.dtype)
        print 'GPIO value = 0x%02x' % gpio_val[0]


class DAPlatformBackend(EZUSBBackend):

    #   Commands
    GLOBAL_TARGET_INDEX     = 0xFF
    AUD_FIFO_WRITE          = 0x10
    AUD_FIFO_REPORT         = 0x11
    AUD_FIFO_READ           = 0x12
    CMD_FIFO_WRITE          = 0x20
    CMD_FIFO_REPORT         = 0x21
    SELECT_CLOCK            = 0x40
    DIRCHAN_READ            = 0x41
    DIRCHAN_REPORT          = 0x42
    AOVF_READ               = 0x43
    AOVF_REPORT             = 0x44
    ECHO_SEND		        = 0x45
    ECHO_REPORT			    = 0x46
    RESET_SLOTS             = 0x47
    FIFO_READ_STATUS        = 0x48
    FIFO_REPORT_STATUS      = 0x49
    UPDATE_BLOCKING         = 0x4A
    CHECKSUM_ERROR		    = 0x50
    SPI_WRITE_REG			= 0x60
    SPI_READ_REG			= 0x61
    SPI_REPORT			    = 0x62
    SLOT_START_PLAYBACK     = 0x70
    SLOT_STOP_PLAYBACK      = 0x71
    SLOT_START_RECORDING    = 0x72
    SLOT_STOP_RECORDING     = 0x73
    SLOT_SET_ACON           = 0x80

    def __init__(self, num_slots=4):
        super(DAPlatformBackend, self).__init__()
        self.receive_state_global = {}
        self.receive_state_slots = [{} for i in range(num_slots)]
        for i in range(num_slots):
            for key in [DAPlatformBackend.AUD_FIFO_REPORT, DAPlatformBackend.CMD_FIFO_REPORT]:
                self.receive_state_slots[i][key] = []
        self.report_unparsed = numpy.array([], dtype=self.dtype)
        
        #   TODO: Figure out
        self.cur_slot_id = -1
        self.cur_report_id = -1
        
        self.reset()
        time.sleep(0.4)
    
    def receive_state_available(self, slot, key):
        return (len(self.receive_state_slots[slot][key]) > 0)
    
    def parse_msg(self, slot_id, report_id, msg):
        #   print 'parse_msg(%d, 0x%02x): %d words: %s ...' % (slot_id, report_id, msg.shape[0], msg)
        if slot_id == DAPlatformBackend.GLOBAL_TARGET_INDEX:
            if report_id not in self.receive_state_global:
                self.receive_state_global[report_id] = []
            self.receive_state_global[report_id].append(msg)
        elif slot_id >= 0:
            if report_id not in self.receive_state_slots[slot_id]:
                self.receive_state_slots[slot_id][report_id] = []
            self.receive_state_slots[slot_id][report_id].append(msg)

    def parse_report(self, new_packet):
        all_packets = numpy.concatenate([self.report_unparsed, new_packet])
        #   print 'parse_report: %s' % all_packets
        cur_index = 0
        N = all_packets.shape[0]
        parsing_valid = True
        while parsing_valid:
            parsing_valid = False
            if N > cur_index + 2:
                #   Pull out metadata
                slot_id = all_packets[cur_index]
                report_id = all_packets[cur_index + 1]
                msg_length = (all_packets[cur_index + 2] << 16) + all_packets[cur_index + 3]
                if N < cur_index + 6 + msg_length:
                    break
                msg = all_packets[cur_index + 4:cur_index + 4 + msg_length]
                checksum = (all_packets[cur_index + 4 + msg_length] << 16) + all_packets[cur_index + 5 + msg_length]
                
                #   TODO: check checksum
                
                #   Call parse function
                self.parse_msg(slot_id, report_id, msg)

                cur_index += 6 + msg_length
                parsing_valid = True
        self.report_unparsed = all_packets[cur_index:]
    
    def update_receive_state(self, timeout=100, request_size=2048):
        #   For up to 10 ms of CD audio, we need: 441 samples * 4 words/sample = ~1600
        #   That would be 8 512-byte packets.
        data = self.read(request_size, timeout=timeout)  #   , display=True
        self.parse_report(data)
        #   print 'Receive state slots: %s' % self.receive_state_slots
        
        #   Provide the number of bytes received - some loops want to see if any new data showed up
        return data.shape[0]

    def flush(self, display=False):
        """ Read from the device until there's nothing more to read.    """
        num_words = 1
        while num_words > 0:
            num_words = self.update_receive_state()
        if display:
            print 'After flushing, remainder is %d words: %s' % (self.report_unparsed.shape[0], self.report_unparsed)

    def pop_report_global(self, report_id):
        return self.receive_state_global[report_id].pop(0)

class FIFOTester(object):
    def __init__(self, backend):
        self.backend = backend
        self.chunk_size = (1 << 14)
        #   self.chunk_size = 512
    
    def run(self, N, tol=0):
        self.write_data = numpy.random.randint(0, 256, N).astype(numpy.uint8)
        #self.write_data = numpy.arange(N).astype(numpy.uint8)
        self.read_data = None
        
        def run_write():
            bytes_written = 0
            while bytes_written < N:
                chunk = self.write_data[bytes_written:bytes_written+self.chunk_size]
                this_chunk_size = chunk.shape[0]
                self.backend.write(chunk)
                bytes_written += this_chunk_size
            """
            #   Flush by writing zeros?
            for i in range(4):
                self.backend.write(numpy.ones((self.chunk_size,), dtype=numpy.uint8))
            """
        def run_read():
            #   self.backend.read(2)
            bytes_read = 0
            results = ''
            while bytes_read < N - tol:
                bytes_to_get = min(N - bytes_read, self.chunk_size)
                #   print 'Trying to get %d bytes' % bytes_to_get
                read_chunk = self.backend.read(bytes_to_get)
                #   print 'Got %d/%d bytes' % (len(read_chunk), bytes_to_get)
                #   print numpy.fromstring(read_chunk, dtype=numpy.uint8)
                if len(read_chunk) == 0:
                    time.sleep(0.1)
                results += read_chunk
                bytes_read += len(read_chunk)
            self.read_data = numpy.fromstring(results, dtype=numpy.uint8)

        write_thread = threading.Thread(target=run_write)
        read_thread = threading.Thread(target=run_read)
        
        time_start = datetime.now()
        write_thread.start()
        read_thread.start()
        
        write_thread.join(10.0)
        read_thread.join(10.0)
        time_elapsed = get_elapsed_time(time_start)
        
        #   Compare results
        if self.read_data is None:
            print 'Failed, received no data'
        elif len(self.read_data) < len(self.write_data) - tol:
            print 'Failed, received %d/%d bytes' % (len(self.read_data), len(self.write_data))
        else:
            #   If tol > 0, cut off end of write data
            self.write_data = self.write_data[:self.read_data.shape[0]]
            N_actual = self.write_data.shape[0]
            num_errors = numpy.sum(self.write_data != self.read_data)
            print 'Found %d errors in total of %d bytes' % (num_errors, N_actual)
            if num_errors == 0:
                data_rate = N / time_elapsed
                print 'Transferred %d bytes in %.3f sec (%.2f MB/s)' % (N_actual, time_elapsed, data_rate / 1e6)
            else:
                print 'Data sent:'
                print self.write_data
                print 'Data received:'
                print self.read_data
                pdb.set_trace()

class DSD1792Tester(object):

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

    def __init__(self, backend):
        self.backend = backend
        self.backend.flush()
        
    def transaction(self, cmd, num_words):
        self.backend.write(cmd)
        self.backend.update_receive_state()
        #   return self.backend.read(num_words)
    
    def prepare_cmd(self, destination, cmd, data):
        data = data.flatten()
        N = data.shape[0]
        checksum = numpy.sum(data)
        msg = numpy.zeros((N + 6,), dtype=self.backend.dtype)
        msg[0] = destination
        msg[1] = cmd
        msg[2] = N / 65536
        msg[3] = N % 65536
        msg[4:4+N] = data
        msg[4+N] = checksum / 65536
        msg[5+N] = checksum % 65536
        return msg
        
    def get_dirchan(self):
        self.transaction(numpy.array([0xFF, 0x41], dtype=self.backend.dtype), 3)
        dval = self.backend.pop_report_global(DAPlatformBackend.DIRCHAN_REPORT)[0]
        for slot in range(4):
            dirslot = 1 * ((dval & (1 << slot)) > 0)
            chanslot = 1 * ((dval & (1 << (slot + 4))) > 0)
            print 'Slot %d: Direction = %d, Channels = %d' % (slot, dirslot, chanslot)
            #	print 'Result of get_dirchan = %s' % self.pprint(result)

    def get_aovf(self):
        result = self.transaction(numpy.array([0xFF, 0x43], dtype=self.backend.dtype), 3)
        dval = self.backend.pop_report_global(DAPlatformBackend.AOVF_REPORT)[0]
        for slot in range(4):
            ovfl = 1 * ((dval & (1 << (slot * 2))) > 0)
            ovfr = 1 * ((dval & (1 << (slot * 2 + 1))) > 0)
            print 'Slot %d: Left overflow = %d, right overflow = %d' % (slot, ovfl, ovfr)
            #	print 'Result of get_aovf = %s' % self.pprint(result)

    def reset_slots(self):
        self.backend.write(numpy.array([0xFF, DAPlatformBackend.RESET_SLOTS], dtype=self.backend.dtype))

    def spi_write(self, slot, addr, data):
        checksum = 0x60 + addr + data
        cmd = numpy.array([slot, 0x20, 0x00, 0x00, 0x03, 0x60, addr, data, checksum / 65536, checksum % 65536], dtype=self.backend.dtype)
        self.write(cmd)
        #	print 'Wrote command for SPI write: %s' % self.pprint(cmd)

    def spi_read(self, slot, addr):
        msg = numpy.array([DAPlatformBackend.SPI_READ_REG, addr + 0x80], dtype=self.backend.dtype)
        self.transaction(self.prepare_cmd(slot, DAPlatformBackend.CMD_FIFO_WRITE, msg), 100)
        
        data = self.backend.receive_state_slots[slot][DAPlatformBackend.CMD_FIFO_REPORT][0]
        print data
        assert data[0] == DAPlatformBackend.SPI_REPORT
        assert data[2] == addr + 0x80
        result = data[4]
        self.backend.receive_state_slots[slot][DAPlatformBackend.CMD_FIFO_REPORT].pop(0)
        
        #	print 'Wrote command for SPI read: %s' % self.pprint(cmd)
        #	print 'Got response for SPI read: %s' % self.pprint(response)
        return result

    def dsd1792_spi_summary(self, slot=0):
        reg_base = 16
        vals = [self.spi_read(slot, x) for x in range(16, 24)]
        result_dict = {}
        keys = DSD1792Tester.REG_CONFIG.keys()
        keys.sort()
        for key in keys:
            (reg_index, start_bit, num_bits) = DSD1792Tester.REG_CONFIG[key]
            bit_mask = 0
            for i in range(num_bits):
                bit_mask |= (1 << (start_bit + i))
            val = (vals[reg_index - reg_base] & bit_mask) >> start_bit
            result_dict[key] = val
            print '%6s = %3d' % (key, val)

        return result_dict
    
    def start_playback(self, slot):
        msg = numpy.array([DAPlatformBackend.SLOT_START_PLAYBACK, 0], dtype=self.backend.dtype)
        self.backend.write(self.prepare_cmd(slot, DAPlatformBackend.CMD_FIFO_WRITE, msg))
    
    def stop_playback(self, slot):
        msg = numpy.array([DAPlatformBackend.SLOT_STOP_PLAYBACK, 0], dtype=self.backend.dtype)
        self.backend.write(self.prepare_cmd(slot, DAPlatformBackend.CMD_FIFO_WRITE, msg))
    
    def start_recording(self, slot):
        msg = numpy.array([DAPlatformBackend.SLOT_START_RECORDING, 0], dtype=self.backend.dtype)
        self.backend.write(self.prepare_cmd(slot, DAPlatformBackend.CMD_FIFO_WRITE, msg))
    
    def stop_recording(self, slot):
        msg = numpy.array([DAPlatformBackend.SLOT_STOP_RECORDING, 0], dtype=self.backend.dtype)
        self.backend.write(self.prepare_cmd(slot, DAPlatformBackend.CMD_FIFO_WRITE, msg))
    
    def block_slots(self):
        self.backend.write(numpy.array([0xFF, 0x4A, 0x00], dtype=self.backend.dtype))
    
    def unblock_slots(self):
        self.backend.write(numpy.array([0xFF, 0x4A, 0x0F], dtype=self.backend.dtype))
    
    def set_acon(self, slot, val):
        msg = numpy.array([DAPlatformBackend.SLOT_SET_ACON, val], dtype=self.backend.dtype)
        self.backend.write(self.prepare_cmd(slot, DAPlatformBackend.CMD_FIFO_WRITE, msg))
    
    def fifo_status(self, display=False):
        self.backend.write(numpy.array([0xFF, 0x48, 0x00], dtype=self.backend.dtype))
        data = self.backend.read(38)
        status = data[4:36].byteswap().view(numpy.uint32).byteswap().reshape((8, 2))
        if display:
            print 'DRAM FIFO status:'
            for i in range(8):
                if status[i, 0] != 0 or status[i, 1] != 0:
                    print '  Port %d: Wrote %d samples, read %d samples' % (i, status[i, 0], status[i, 1])
        
        return status
    
    def audio_write_float(self, slot, data):
        data_int = (data * (1 << 24)).astype(numpy.int32)
        self.audio_write(slot, data_int)
        return data_int
    
    def audio_write(self, slot, data):
        #   2 byteswaps accomplishes a word-swap while preserving byte order within words
        #   print [hex(x) for x in data[:8]]
        start_time = datetime.now()
        msg = numpy.fromstring(data.byteswap().tostring(), dtype=self.backend.dtype).byteswap()
        self.backend.write(self.prepare_cmd(slot, DAPlatformBackend.AUD_FIFO_WRITE, msg))
        #   print 'Wrote %d samples in %.2f ms' % (data.shape[0], get_elapsed_time(start_time) * 1e3)
    
    def audio_read(self, slot, num_samples, perform_update=True, timeout=100):
        #   Timeout is in ms
        #   TODO: Make much smarter
        
        start_time = datetime.now()
        words_received = numpy.sum([x.shape[0] for x in self.backend.receive_state_slots[slot][DAPlatformBackend.AUD_FIFO_REPORT]])
        samples_received = int(words_received / 2)
        #   print 'Samples previously received = %d' % samples_received
        
        if perform_update:
            time_float = 0
            while samples_received < num_samples and time_float < 1e-3 * timeout:
            
                samples_needed = num_samples - samples_received
            
                #   Now we have to send a command to the device to get it to send us audio
                msg = numpy.array([slot, DAPlatformBackend.AUD_FIFO_READ, samples_needed / 65536, samples_needed % 65536], dtype=numpy.uint16)
                self.backend.write(msg)
                num_words = samples_needed * 2 + 6
                self.backend.update_receive_state(request_size=num_words, timeout=timeout)
                time_float = get_elapsed_time(start_time)
                words_received = numpy.sum([x.shape[0] for x in self.backend.receive_state_slots[slot][DAPlatformBackend.AUD_FIFO_REPORT]])
                samples_received = int(words_received / 2)
                #   print 'Got to %d samples from %d words in %.2f ms' % (samples_received, num_words, (time_float * 1e3))
        
        if self.backend.receive_state_available(slot, DAPlatformBackend.AUD_FIFO_REPORT):
            all_data = numpy.concatenate(self.backend.receive_state_slots[slot][DAPlatformBackend.AUD_FIFO_REPORT])
            data = all_data[:num_samples * 2]
            other_data = all_data[num_samples * 2:]
            #   Save leftover samples back into receive state
            self.backend.receive_state_slots[slot][DAPlatformBackend.AUD_FIFO_REPORT] = [other_data,]
            
            #   Convert to integer
            #data = numpy.fromstring(data.byteswap().tostring(), dtype=numpy.int32).byteswap()
            data = numpy.fromstring(data.tostring(), dtype=numpy.int32)
        else:
            data = numpy.array([], dtype=numpy.int32)

        return data
    
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
    tester = DSD1792Tester(backend)

    #   tester.get_dirchan()
    
    #print tester.spi_read(1, 18)
    #tester.dsd1792_spi_summary(slot=1)
    
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
    F_sine = 100.
    T = 10.
    N = F_s * T
    t = numpy.linspace(0, (N - 1) / F_s, N)
    #x = 0.00390625 * ((numpy.sin(2 * numpy.pi * F_sine * t) >= 0) - 0.5)
    #x = 0.00390625 * numpy.ones(t.shape)
    #x = (-1.0 / (1 << 24)) * numpy.ones(t.shape)
    x = 0.45 * numpy.sin(2 * numpy.pi * F_sine * t) + 0.001
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
    
    #   Load a song
    #test_fn = "/mnt/hgfs/cds/Weezer/Weezer (Blue Album)/07 Say It Ain't So.wav"
    test_fn = "/mnt/hgfs/cds/Weezer/Weezer (Blue Album)/05 Undone (the Sweater Song).wav"
    (Fs_test, x_st_int) = scipy.io.wavfile.read(test_fn)
    
    #   Convert to 24-bit
    if x_st_int.dtype == numpy.int16:
        x_st_int = x_st_int.astype(numpy.int32) << 8
    else:
        raise Exception('Unexpected source data type: %s' % x_st_int.dtype)
    
    #N = int(F_s * T)
    N = x_st_int.shape[0]
    time_start = datetime.now()
    tester.start_recording(0)
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
        tester.audio_write(1, chunk.flatten())
        x_int.append(chunk.flatten())
        samples_written += this_chunk_size
        #print 'Wrote %d samples' % samples_written

        #   Delay first read so that we don't get a buffer underrun
        if start_flag == False:
            start_flag = True
        else:

            #   Read twice the chunk size--we have 2 channels
            data = tester.audio_read(0, chunk_size * 2, timeout=200)
            rec_data.append(data)
            samples_read += data.shape[0]
            #print 'samples_read = %d' % samples_read
            
        #tester.fifo_status(display=True)

    
    time.sleep(0.1) #   temporary... need to ensure everything actually gets played
    tester.stop_playback(1) #  assists with triggering
    tester.stop_recording(0)
    time.sleep(0.01)
    
    #   Get FIFO status and then retrieve any lingering samples
    status = tester.fifo_status(display=True)
    leftover_samples = status[4][0] - status[4][1]
    rec_data.append(tester.audio_read(0, leftover_samples, perform_update=True, timeout=1000))
    
    #   Flush the backend
    backend.flush(display=True)

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
    
