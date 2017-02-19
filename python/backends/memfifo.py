
import numpy
import libusb1

from backends.ezusb import EZUSBBackend
        
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

