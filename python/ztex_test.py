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

def get_elapsed_time(time_start):
    time_end = datetime.now()
    time_diff = time_end - time_start
    return time_diff.seconds + 1e-6 * time_diff.microseconds

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

    def read(self, num_words, fail_on_timeout=False, display=False):
        try:
            num_bytes = num_words * self.bytes_per_word
            result = self.handle.bulkRead(MemFIFOBackend.EP_IN, num_bytes, 100)
        except usb1.USBErrorTimeout:
            result = ''
            if fail_on_timeout:
                raise
        
        result = numpy.fromstring(result, dtype=self.dtype)
        if display: print 'Got %d/%d words: %s' % (len(result), num_words, result)
        return result
    
    def write(self, data, display=False):
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
    CMD_FIFO_WRITE          = 0x20
    CMD_FIFO_REPORT         = 0x21
    SELECT_CLOCK            = 0x40
    DIRCHAN_READ            = 0x41
    DIRCHAN_REPORT          = 0x42
    AOVF_READ               = 0x43
    AOVF_REPORT             = 0x44
    ECHO_SEND		        = 0x45
    ECHO_REPORT			    = 0x46
    CHECKSUM_ERROR		    = 0x50
    SPI_WRITE_REG			= 0x60
    SPI_READ_REG			= 0x61
    SPI_REPORT			    = 0x62

    def __init__(self, num_slots=4):
        super(DAPlatformBackend, self).__init__()
        self.receive_state_global = {}
        self.receive_state_slots = [{} for i in range(num_slots)]
        self.report_unparsed = numpy.array([], dtype=self.dtype)
        
        #   TODO: Figure out
        self.cur_slot_id = -1
        self.cur_report_id = -1
        
        self.reset()
        time.sleep(0.4)
    
    def parse_report(self, new_packets=()):
        all_packets = numpy.concatenate([self.report_unparsed,] + list(new_packets))
        #   print 'parse_report: %s' % all_packets
        cur_index = 0
        N = all_packets.shape[0]
        parsing_valid = True
        while parsing_valid:
            parsing_valid = False
            if N > cur_index + 2:
                #   Dumb: assume 1 word packet (SPI read seems to give this... needs to be fixed)
                slot_id = all_packets[cur_index]
                report_id = all_packets[cur_index + 1]
                result_value = all_packets[cur_index + 2]
                if slot_id >= 0:
                    if report_id not in self.receive_state_slots[slot_id]:
                        self.receive_state_slots[slot_id][report_id] = []
                    self.receive_state_slots[slot_id][report_id].append(result_value)
                else:
                    raise Exception('Warning, did not handle global response')
                cur_index += 3
                parsing_valid = True
    
    def update_receive_state(self):
        request_size = 1024
        received_packet_size = -1
        new_packets = []
        while received_packet_size != 0:
            data = self.read(request_size)
            received_packet_size = data.shape[0]
            new_packets.append(data)
        self.parse_report(new_packets)
        #   print 'Receive state slots: %s' % self.receive_state_slots

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
        result = self.transaction(numpy.array([0xFF, 0x41], dtype=self.backend.dtype), 3)
        dval = result[2]
        for slot in range(4):
            dirslot = 1 * ((dval & (1 << slot)) > 0)
            chanslot = 1 * ((dval & (1 << (slot + 4))) > 0)
            print 'Slot %d: Direction = %d, Channels = %d' % (slot, dirslot, chanslot)
            #	print 'Result of get_dirchan = %s' % self.pprint(result)

    def get_aovf(self):
        result = self.transaction(numpy.array([0xFF, 0x43], dtype=self.backend.dtype), 3)
        dval = result[2]
        for slot in range(4):
            ovfl = 1 * ((dval & (1 << (slot * 2))) > 0)
            ovfr = 1 * ((dval & (1 << (slot * 2 + 1))) > 0)
            print 'Slot %d: Left overflow = %d, right overflow = %d' % (slot, ovfl, ovfr)
            #	print 'Result of get_aovf = %s' % self.pprint(result)

    def spi_write(self, slot, addr, data):
        checksum = 0x60 + addr + data
        cmd = numpy.array([slot, 0x20, 0x00, 0x00, 0x03, 0x60, addr, data, checksum / 65536, checksum % 65536], dtype=self.backend.dtype)
        self.write(cmd)
        #	print 'Wrote command for SPI write: %s' % self.pprint(cmd)

    def spi_read(self, slot, addr):
        msg = numpy.array([DAPlatformBackend.SPI_READ_REG, addr + 0x80], dtype=self.backend.dtype)
        self.transaction(self.prepare_cmd(slot, DAPlatformBackend.CMD_FIFO_WRITE, msg), 100)
        
        data = self.backend.receive_state_slots[slot][DAPlatformBackend.CMD_FIFO_REPORT]
        assert data[0] == DAPlatformBackend.SPI_REPORT
        assert data[1] == addr + 0x80
        result = data[2]
        self.backend.receive_state_slots[slot][DAPlatformBackend.CMD_FIFO_REPORT] = []
        
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
    
    def audio_write_float(self, slot, data):
        data_int = (data * (1 << 24)).astype(numpy.int32)
        self.audio_write(slot, data_int)
    
    def audio_write(self, slot, data):
        #   2 byteswaps accomplishes a word-swap while preserving byte order within words
        #   print [hex(x) for x in data[:8]]
        msg = numpy.fromstring(data.byteswap().tostring(), dtype=self.backend.dtype).byteswap()
        self.backend.write(self.prepare_cmd(slot, DAPlatformBackend.AUD_FIFO_WRITE, msg))
    
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
    
    #tester.get_dirchan()
    #print tester.spi_read(1, 18)
    #tester.dsd1792_spi_summary(slot=1)
    
    #   Try some audio (note: 44.1 kHz)
    F_s = 44100.
    F_sine = 100.
    T = 10.
    N = F_s * T
    t = numpy.linspace(0, (N - 1) / F_s, N)
    x = 0.00390625 * ((numpy.sin(2 * numpy.pi * F_sine * t) > 0) - 0.5)
    """
    #   Alt. try some WAV data (note: should scale, max vol would be * 256)
    (F_s, data) = scipy.io.wavfile.read('/mnt/hgfs/cds/Guster/Lost and Gone Forever/05 I Spy.wav')
    block = F_s * 10
    #   data = data[block*10:block*11]
    N = data.shape[0]
    x = data.astype(numpy.int32) * 0
    """
    N = 128
    chunk_size = 128
    samples_written = 0
    while samples_written < N:
        chunk = x[samples_written:samples_written+chunk_size]
        this_chunk_size = chunk.shape[0]
        x_st = numpy.array([chunk, chunk]).T.flatten()
        tester.audio_write_float(1, x_st)
        if samples_written > 1000:
            time.sleep(this_chunk_size / F_s)
        #tester.audio_write(1, x_st)
        samples_written += this_chunk_size
        #print 'Wrote %d samples' % samples_written
    
    backend.close()
    
