
from myhdl import *

from fx2_framework import virtual_fx2
from usb_toplevel import usb_toplevel
from converterboard import ConverterBoard
from test_settings import *

def usb_toplevel_test():

    """ Signals """
    
    clk = Signal(False)
    reset = Signal(False)
    reset_neg = Signal(True)

    usb_ifclk = Signal(False)
    usb_slwr = Signal(True)
    usb_slrd = Signal(True)
    usb_sloe = Signal(False)
    usb_addr = Signal(intbv(0)[2:])
    usb_data_in = Signal(intbv(0)[8:])
    usb_data_out = Signal(intbv(0)[8:])
    usb_ep2_empty = Signal(False)
    usb_ep4_empty = Signal(False)
    usb_ep6_full = Signal(False)
    usb_ep8_full = Signal(False)
    
    mem_addr = Signal(intbv(0)[23:])
    mem_data_in = Signal(intbv(0)[16:])
    mem_data_out = Signal(intbv(0)[16:])
    mem_data_driven = Signal(False)
    mem_oe = Signal(False)
    mem_we = Signal(False)
    mem_clk = Signal(False)
    mem_addr_valid = Signal(False)
    
    slot_data_in = Signal(intbv(0)[24:])
    slot_data_out = Signal(intbv(0)[24:])
    custom_dirchan = Signal(False)
    spi_adc_cs = Signal(False)
    spi_adc_mclk = Signal(False)
    spi_adc_mdi = Signal(False)
    spi_adc_mdo = Signal(False)
    spi_dac_cs = Signal(False)
    spi_dac_mclk = Signal(False)
    spi_dac_mdi = Signal(False)
    spi_dac_mdo = Signal(False)
    custom_adc_hwcon = Signal(False)
    custom_adc_ovf = Signal(False)
    custom_clk0 = Signal(False)
    custom_clk1 = Signal(False)
    custom_srclk = Signal(False)
    custom_clksel = Signal(False)

    """ Local logic processes """

    #   Maintain an active low reset signal for FX2
    @always_comb
    def update_signals():
        reset_neg.next = not reset
        
    #   Run the 100 - 150 MHz primary clock 
    #   This will be generated using a DCM multiplying the Nexys2's 50 MHz clock
    @always(delay(CLK_PERIOD/2))
    def update_clk():
        clk.next = not clk
        
    #   Run a few cycles of reset, then run the simulation for the specified time
    @instance
    def stimulus():
    
        reset.next = True
        for i in range(2):
            yield usb_ifclk.negedge
        reset.next = False
        yield usb_ifclk.negedge
    
        for i in range(SIM_LENGTH):
            yield usb_ifclk.negedge
            
        raise StopSimulation
            
    """ Logic module instances """
    
    #   FX2 processor on Nexys2 board (which is connected to USB bus from computer)
    fx2 = virtual_fx2(usb_ifclk, reset_neg, usb_slwr, usb_slrd, usb_sloe, usb_addr, usb_data_in, usb_data_out, usb_ep2_empty, usb_ep4_empty, usb_ep6_full, usb_ep8_full)
    
    #   Firmware on FPGA
    doobie = usb_toplevel(usb_ifclk, usb_slwr, usb_slrd, usb_sloe, usb_addr, usb_data_in, usb_data_out, usb_ep2_empty, usb_ep4_empty, usb_ep6_full, usb_ep8_full, mem_addr, mem_data_in, mem_data_driven, mem_data_out, mem_oe, mem_we, mem_clk, mem_addr_valid, slot_data_in, slot_data_out, custom_dirchan, spi_adc_cs, spi_adc_mclk, spi_adc_mdi, spi_adc_mdo, spi_dac_cs, spi_dac_mclk, spi_dac_mdi, spi_dac_mdo, custom_adc_hwcon, custom_adc_ovf, custom_clk0, custom_srclk, custom_clksel, custom_clk1, reset, clk)
    
    #   Simulated converter board
    conv = ConverterBoard().myhdl_module(slot_data_in, slot_data_out, spi_adc_cs, spi_adc_mclk, spi_adc_mdi, spi_adc_mdo, spi_dac_cs, spi_dac_mclk, spi_dac_mdi, spi_dac_mdo, custom_adc_hwcon, custom_adc_ovf, custom_clk0, custom_clk1, custom_dirchan, custom_srclk, custom_clksel, reset)

    return instances()


