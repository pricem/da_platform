#!/usr/bin/env python

import numpy
import numpy.random

from utils import FLDependentObject
import fl

class CellRAMDemo(FLDependentObject):

    def read(self, N):
        return numpy.fromstring(str(fl.flReadChannel(self.handle, 0x00, N)), dtype=numpy.uint8)
        
    def write(self, data):
        return fl.flWriteChannel(self.handle, 0x00, bytearray(data.tostring()))
        
    def read_mem(self, addr, num_bytes):
        assert num_bytes >= 1
        assert num_bytes < 256
        msg_data = numpy.zeros((5,), dtype=numpy.uint8)
        msg_data[0] = 0x10
        msg_data[1] = (addr >> 16) % 256
        msg_data[2] = (addr >> 8) % 256
        msg_data[3] = addr % 256
        msg_data[4] = num_bytes
        print 'Reading %d bytes from 0x%x: msg = %s' % (num_bytes, addr, msg_data)
        self.write(msg_data)
        return self.read(num_bytes)
        
    def write_mem(self, addr, data):
        assert data.shape[0] >= 1
        assert data.shape[0] < 256
        msg_data = numpy.zeros((data.shape[0] + 5,), dtype=numpy.uint8)
        msg_data[0] = 0x20
        msg_data[1] = (addr >> 16) % 256
        msg_data[2] = (addr >> 8) % 256
        msg_data[3] = addr % 256
        msg_data[4] = data.shape[0]
        msg_data[5:] = data
        print 'Writing %d bytes to 0x%x: msg = %s' % (data.shape[0], addr, msg_data)
        self.write(msg_data)
        
if __name__ == '__main__':
    c = CellRAMDemo()
    test_data = numpy.arange(16).astype(numpy.uint8)
    c.write_mem(0, test_data)
    read_data = c.read_mem(0, 16)
    print read_data

    

    