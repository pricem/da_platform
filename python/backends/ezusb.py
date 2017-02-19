
import numpy
import libusb1
import usb1

#   Set to True for debugging
IO_DISPLAY = False

class EZUSBBackend(object):

    EP_IN = 0x82
    EP_OUT = 0x06

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
                data = self.handle.bulkRead(EZUSBBackend.EP_IN, 512, 100)
            except libusb1.USBError:
                flushed = True
        print 'Flushed FIFOs in %d iterations' % flush_count

    def close(self):
        self.handle.releaseInterface(0)
        self.handle.close()

    def read(self, num_words, fail_on_timeout=False, display=IO_DISPLAY, timeout=100):
        try:
            num_bytes = num_words * self.bytes_per_word
            result = self.handle.bulkRead(EZUSBBackend.EP_IN, num_bytes, timeout)
        except usb1.USBErrorTimeout:
            result = ''
            if fail_on_timeout:
                raise

        result = numpy.frombuffer(result, dtype=self.dtype)
        if display: print 'Got %d/%d words: %s' % (len(result), num_words, result)
        return result
    
    def write(self, data, display=IO_DISPLAY):
        num_bytes = self.handle.bulkWrite(EZUSBBackend.EP_OUT, data.tostring())
        assert num_bytes == data.shape[0] * self.bytes_per_word
        num_words = num_bytes / self.bytes_per_word
        if display: print 'Wrote %d/%d words: %s' % (num_words, data.shape[0], data)

    def reset(self):
        self.handle.controlWrite(libusb1.LIBUSB_TYPE_VENDOR, 0x60, 0, 0, '')
        #pass
