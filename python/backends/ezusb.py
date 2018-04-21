
import numpy
import libusb1
import usb1
import time

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
        #   self.handle.resetDevice()
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

    def rw_callback(self, transfer):
        self.callback_active = True
        if transfer.getStatus() != usb1.TRANSFER_COMPLETED:
            print 'rw_callback: transfer fail, status = %s' % transfer.getStatus()
            print 'Actual length = %d buffer size = %d' % (transfer.getActualLength(), len(transfer.getBuffer()))
            raise usb1.USBError(transfer.getStatus())
        data = transfer.getBuffer()[:transfer.getActualLength()]
        #   Don't resubmit... though that would be smart
        #   NOTE: should this handle the case of an odd number of bytes?
        self.read_data_pending = numpy.frombuffer(data, dtype=self.dtype)
        self.callback_active = False

    def read_and_write(self, data, read_size, timeout=100):
        #   Simultaneously request and read back data using libusb async functions.
        #   Then (and this can be optional later?) wait for both to complete.
        transfer_list = []
        self.callback_active = False
        self.read_data_pending = None
        #   a) Write
        transfer1 = self.handle.getTransfer()
        transfer1.setBulk(EZUSBBackend.EP_OUT, data.tostring(), callback=self.rw_callback)
        transfer1.submit()
        transfer_list.append(transfer1)
        #   b) Read
        transfer2 = self.handle.getTransfer()
        transfer2.setBulk(EZUSBBackend.EP_IN, read_size * self.bytes_per_word, callback=self.rw_callback)
        transfer2.submit()
        transfer_list.append(transfer2)
        
        while any(x.isSubmitted() for x in transfer_list):
            try:
                self.context.handleEvents()
            except usb1.USBErrorInterrupted:
                print 'Got USBErrorInterrupted'
                pass
        
        while self.callback_active:
            time.sleep(0)
        
        #   Should be done now.
        return self.read_data_pending

    def reset(self):
        self.handle.controlWrite(libusb1.LIBUSB_TYPE_VENDOR, 0x60, 0, 0, '')
        #pass
