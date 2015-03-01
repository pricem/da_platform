#!/usr/bin/env python

import usb1
import libusb1
import threading
import time
from datetime import datetime
import numpy.random
import pdb

def get_elapsed_time(time_start):
    time_end = datetime.now()
    time_diff = time_end - time_start
    return time_diff.seconds + 1e-6 * time_diff.microseconds

class MemFIFOBackend(object):

    EP_IN = 0x82
    EP_OUT = 0x06

    def __init__(self):
        self.context = usb1.USBContext()
        
        self.device = self.context.getByVendorIDAndProductID(0x221a, 0x0100)
        assert self.device
        self.handle = self.device.open()
        self.handle.resetDevice()
        self.handle.claimInterface(0)

        #   Reset and set mode 0
        self.reset()
        #   self.set_mode(1)
        self.set_mode(0)

    def reset(self):
        self.handle.controlWrite(libusb1.LIBUSB_TYPE_VENDOR, 0x81, 0, 0, '')
        time.sleep(0.1)
        flushed = False
        flush_count = 0
        while not flushed:
            try:
                flush_count += 1
                data = self.handle.bulkRead(MemFIFOBackend.EP_IN, 4096, 100)
            except libusb1.USBError:
                flushed = True
        print 'Flushed FIFOs in %d iterations' % flush_count
        time.sleep(0.1)

    def set_mode(self, mode):
        self.handle.controlWrite(libusb1.LIBUSB_TYPE_VENDOR, 0x80, mode & 3, 0, '')

    def close(self):
        self.handle.releaseInterface(0)
        self.handle.close()

    def read(self, num_bytes):
        try:
            result = self.handle.bulkRead(MemFIFOBackend.EP_IN, num_bytes, 100)
        except libusb1.USBError:
            result = ''
            raise
        if len(result) != num_bytes:
            #   print 'Got %d/%d bytes' % (len(result), num_bytes)
            pass
        return result
    
    def write(self, data):
        num_bytes = self.handle.bulkWrite(MemFIFOBackend.EP_OUT, data.tostring())
        assert num_bytes == data.shape[0]
        #   print 'Wrote %d bytes' % num_bytes

class FIFOTester(object):
    def __init__(self, backend):
        self.backend = backend
        self.chunk_size = (1 << 18)
    
    def run(self, N):
        self.write_data = numpy.random.randint(0, 256, N).astype(numpy.uint8)
        #   self.write_data = numpy.arange(N).astype(numpy.uint8)
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
            while bytes_read < N:
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
        elif len(self.read_data) != len(self.write_data):
            print 'Failed, received %d/%d bytes' % (len(self.read_data), len(self.write_data))
        else:
            num_errors = numpy.sum(self.write_data != self.read_data)
            print 'Found %d errors in total of %d bytes' % (num_errors, N)
            if num_errors == 0:
                data_rate = N / time_elapsed
                print 'Transferred %d bytes in %.3f sec (%.2f MB/s)' % (N, time_elapsed, data_rate / 1e6)
            else:
                print 'Data sent:'
                print self.write_data
                print 'Data received:'
                print self.read_data

if __name__ == '__main__':
    backend = MemFIFOBackend()
    tester = FIFOTester(backend)
    tester.run(1 << 24)
    backend.close()
    
