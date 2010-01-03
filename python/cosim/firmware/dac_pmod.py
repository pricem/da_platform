""" Test jig for PMOD-DA2 DAC. 

    Consumes data in accordance with the National Semiconductor DAC121S101 chip.
    See datasheet.
"""

from myhdl import *
from test_settings import *

class DAC_PMOD(object):
    def __init__(self, *args, **kwargs):
        pass
        
    def myhdl_module(self, 
        #   4-pin data bus
        bclk, sync, dina, dinb
        ):
        
        sync_last = Signal(False)
        clk_counter = Signal(intbv(0)[5:])
        sample_left = Signal(intbv(0)[12:])
        sample_right = Signal(intbv(0)[12:])

        time_last = [0]

        @always(bclk.posedge)
        def please_work():
            sync_last.next = sync
            if (not sync):
                if sync_last:
                    clk_counter.next = 0
                else:
                    clk_counter.next = clk_counter + 1
                val_left = sample_left._val
                val_right = sample_right._val
                index = int(14 - clk_counter._val._val)
                if index >= 0 and index < 12:
                    val_left[index] = dina
                    val_right[index] = dinb
                sample_left.next = val_left
                sample_right.next = val_right
            else:
                if not sync_last:
                    print 'T = %s (dT = %s): PMOD-DA2 output L = 0x%03x, R = 0x%03x' % (now(), now() - time_last[0], sample_left, sample_right)
                    time_last[0] = now()
            
        return instances()

