from myhdl import *

from usbp_cores.fx2_model.fx2 import fx2
from test_settings import *


def virtual_fx2(
    #   USB interface
    usb_ifclk, reset_neg, usb_slwr, usb_slrd, usb_sloe, usb_addr, usb_data_in, usb_data_out, usb_ep2_empty, usb_ep6_full, usb_ep4_empty, usb_ep8_full,
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

    """ Logic module instances """

    usb_processor = fx2(verbose=True)
    
    usb_port = usb_processor.SlaveFifo(usb_ifclk, reset_neg, usb_slwr_neg, usb_slrd_neg, usb_sloe_neg, usb_addr, usb_data_in, usb_data_out, usb_ep2_empty, usb_ep6_full, usb_ep4_empty, usb_ep8_full)
    
    @instance
    def stimulus():
        msg_index = 0
        yield reset_neg.posedge
        while 1:
            
            if msg_index <= len(MESSAGE):
                usb_processor.Write([ord(x) for x in MESSAGE[msg_index:(msg_index+4)]], 2)
            
            for i in range(CHUNK_PERIOD):
                yield usb_ifclk.posedge
           
            msg_index += CHUNK_SIZE
    
    return instances()

