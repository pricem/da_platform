""" Test jig for AD1934 DAC. """

from myhdl import *
from test_settings import *

class DAC8(object):
    def __init__(self, *args, **kwargs):
        pass
        
    def myhdl_module(self, 
        #   6-pin data bus
        data_in, data_out, 
        #   SPI for DACs and ADCs
        amcs, amclk, amdi, amdo, dmcs, dmclk, dmdi, dmdo,
        #   Control lines (deserialize using srclk cycles since reset)
        srclk, hwcon, 
        #   Status lines
        direction, chan, ovfl, ovfr,
        #   Control lines
        clk, reset
        ):
        
        return instances()

