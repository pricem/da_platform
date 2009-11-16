
from myhdl import *

from fx2_framework import virtual_fx2
from tracking_fifo import tracking_fifo
from test_settings import *

def tracking_fifo_test():

    """ Signals """
    
    clk0 = Signal(False)
    clk_div2 = Signal(False)
    reset = Signal(False)
    reset_neg = Signal(True)

    usb_ifclk = Signal(False)
    usb_slwr = Signal(True)
    usb_slrd = Signal(True)
    usb_sloe = Signal(True)
    usb_addr = Signal(intbv(0)[2:])
    usb_data_in = Signal(intbv(0)[8:])
    usb_data_out = Signal(intbv(0)[8:])
    usb_ep2_empty = Signal(False)
    usb_ep4_empty = Signal(False)
    usb_ep6_full = Signal(False)
    usb_ep8_full = Signal(False)
    
    fifo_ep2_write_in = Signal(False)
    fifo_ep2_read_out = Signal(False)
    fifo_ep2_read_out_prev = Signal(False)
    fifo_ep2_out_data = Signal(intbv(0)[8:])
    fifo_ep2_addr_in = Signal(intbv(0)[11:])
    fifo_ep2_addr_out = Signal(intbv(0)[11:])

    """ Local logic processes """

    @always_comb
    def update_signals():
        reset_neg.next = not reset
        
    @always(delay(CLK_PERIOD/2))
    def update_clk():
        clk0.next = not clk0
        
    @always(clk0.posedge)
    def update_divclk():
        clk_div2.next = not clk_div2
    
    @always(clk0.posedge)
    def update_usb_control():
        #   Always read EP2.
        if not usb_ep2_empty:
            usb_sloe.next = False
            usb_slwr.next = True
            usb_slrd.next = False
            fifo_ep2_write_in.next = True
        else:
            usb_sloe.next = True
            usb_slwr.next = True
            usb_slrd.next = False
            fifo_ep2_write_in.next = False
    
    @instance
    def read_fifo_output():
        readback_msg = ''
        while 1:
            if fifo_ep2_addr_in > fifo_ep2_addr_out + 1:
                fifo_ep2_read_out.next = True
            else:
                fifo_ep2_read_out.next = False
                
            fifo_ep2_read_out_prev.next = fifo_ep2_read_out
                
            if fifo_ep2_read_out_prev:
                readback_msg += chr(fifo_ep2_out_data)
                print 'Updated FIFO output data: %s' % readback_msg
                
                assert MESSAGE.startswith(readback_msg)
                assert len(readback_msg) == fifo_ep2_addr_out

            yield clk0.posedge
    
    @instance
    def stimulus():
    
        reset.next = True
        yield clk_div2.negedge
        reset.next = False
        yield clk_div2.negedge
    
        for i in range(100):
            yield clk0.negedge
            
        raise StopSimulation
            
    """ Logic module instances """
    
    fx2 = virtual_fx2(usb_ifclk, reset_neg, usb_slwr, usb_slrd, usb_sloe, usb_addr, usb_data_in, usb_data_out, usb_ep2_empty, usb_ep4_empty, usb_ep6_full, usb_ep8_full)
    
    fifo = tracking_fifo(usb_ifclk, usb_data_out, fifo_ep2_write_in, clk0, fifo_ep2_out_data, fifo_ep2_read_out, fifo_ep2_addr_in, fifo_ep2_addr_out, reset)

    return instances()

