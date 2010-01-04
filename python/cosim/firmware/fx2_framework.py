from myhdl import *

from usbp_cores.fx2_model.fx2 import fx2
from test_settings import *

from testbase import TestBase, Event

class FX2Model(TestBase):

    def __init__(self, *args, **kwargs):
        super(FX2Model, self).__init__(*args, **kwargs)
        self.fx2 = fx2(verbose=FX2_VERBOSITY)

    def write_ep2(self, data):
        self.handle_event(Event('usb_queued', {'endpoint': 'EP2', 'data': [intbv(x)[8:] for x in data]}))
        self.fx2.Write(data, 2)
        
    def write_ep4(self, data):
        self.handle_event(Event('usb_queued', {'endpoint': 'EP4', 'data': [intbv(x)[8:] for x in data]}))
        self.fx2.Write(data, 4)

    def myhdl_module(self,
        #   USB interface
        usb_ifclk, reset_neg, usb_slwr, usb_slrd, usb_sloe, usb_addr, usb_data_in, usb_data_out, usb_ep2_empty, usb_ep4_full, usb_ep4_empty, usb_ep8_full,
        ):

        usb_sloe_neg = Signal(False)
        usb_slwr_neg = Signal(False)
        usb_slrd_neg = Signal(False)

        #   Negate control signals since the FX2 model has them active high whereas the real FX2 is active low.
        @always_comb
        def set_neg_ctrl():
            usb_sloe_neg.next = not usb_sloe
            usb_slrd_neg.next = not usb_slrd
            usb_slwr_neg.next = not usb_slwr
            #   print 'FX2-framework: SLOE %s->%s' % (usb_sloe, usb_sloe_neg.next)
            
        #   Monitor the USB bus and print out a message at the end of each read or write.
        endpoint_labels = {0: 'EP2', 1: 'EP4', 2: 'EP6', 3: 'EP8'}
        transfer_labels = {0: 'BULK   ', 1: 'CONTROL', 2: 'BULK   ', 3: 'CONTROL'}
        
        @instance
        def usb_monitor():
            port = -1
            msg = []
            state = 'idle'
            while 1:
                yield usb_ifclk.posedge
                if state == 'idle':
                    if not usb_slrd:
                        port = usb_addr._val._val
                        state = 'read'
                        msg = [usb_data_out._val]
                    elif not usb_slwr:
                        port = usb_addr._val._val
                        state = 'write'
                        msg = [usb_data_in._val]
                elif state == 'read':
                    if not usb_slrd:
                        msg.append(usb_data_out._val)
                    else:
                        self.handle_event(Event('usb_xfer  ', {'endpoint': endpoint_labels[port], 'data': msg}))
                        state = 'idle'
                elif state == 'write':
                    if not usb_slwr:
                        msg.append(usb_data_in._val)
                    else:
                        self.handle_event(Event('usb_xfer  ', {'endpoint': endpoint_labels[port], 'data': msg}))
                        state = 'idle'

        """ Logic module instances """
        usb_port = self.fx2.SlaveFifo(usb_ifclk, reset_neg, usb_slwr_neg, usb_slrd_neg, usb_sloe_neg, usb_addr, usb_data_in, usb_data_out, usb_ep2_empty, usb_ep4_full, usb_ep4_empty, usb_ep8_full)
        
        
        return instances()

