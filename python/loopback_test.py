#!/usr/bin/env python

import numpy
import numpy.random

import fl
from utils import FLDependentObject

class LoopbackTester(FLDependentObject):
    def read(self, N):
        return numpy.fromstring(str(fl.flReadChannel(self.handle, 0x00, N)), dtype=numpy.uint8)
        
    def write(self, data):
        return fl.flWriteChannel(self.handle, 0x00, bytearray(data.tostring()))

    def test(self, N):
        data = (numpy.random.random(N) * 256).astype(numpy.uint8)
        print 'Writing data: %s' % data
        self.write(data)
        result_data = sef.read(data.shape[0])
        print 'Read data: %s' % result_data
        
if __name__ == '__main__':
    t = LoopbackTester()
    #   t.test(16)
    x = numpy.arange(16, dtype=numpy.uint8)
    #   hangs on any read operation
    