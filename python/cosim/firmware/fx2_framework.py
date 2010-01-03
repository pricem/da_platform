from myhdl import *

from usbp_cores.fx2_model.fx2 import fx2
from test_settings import *

class FX2Model(object):
    def __init__(self):
        pass

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
        

        """ Logic module instances """

        usb_processor = fx2(verbose=FX2_VERBOSITY)
        
        usb_port = usb_processor.SlaveFifo(usb_ifclk, reset_neg, usb_slwr_neg, usb_slrd_neg, usb_sloe_neg, usb_addr, usb_data_in, usb_data_out, usb_ep2_empty, usb_ep4_full, usb_ep4_empty, usb_ep8_full)
        
        @instance
        def stimulus():
            msg_index_ep2 = 0
            msg_id_ep2 = 0
            msg_index_ep4 = 0
            msg_id_ep4 = 0
            yield reset_neg.posedge
            
            while 1:
                
                if msg_index_ep2 <= len(MESSAGES_EP2[msg_id_ep2]):
                    usb_processor.Write([ord(x) for x in MESSAGES_EP2[msg_id_ep2][msg_index_ep2:(msg_index_ep2+CHUNK_SIZE)]], 2)
                    msg_index_ep2 = msg_index_ep2 + CHUNK_SIZE
                else:
                    msg_index_ep2 = 0
                    msg_id_ep2 = (msg_id_ep2 + 1) % len(MESSAGES_EP2)
                 
                if msg_index_ep4 <= len(MESSAGES_EP4[msg_id_ep4]):
                    usb_processor.Write([ord(x) for x in MESSAGES_EP4[msg_id_ep4][msg_index_ep4:(msg_index_ep4+CHUNK_SIZE)]], 4)
                    msg_index_ep4 = msg_index_ep4 + CHUNK_SIZE
                else:
                    msg_index_ep4 = 0
                    msg_id_ep4 = (msg_id_ep4 + 1) % len(MESSAGES_EP4)    
                
                for i in range(CHUNK_PERIOD):
                    yield usb_ifclk.posedge
               
                
        
        return instances()

