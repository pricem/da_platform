from myhdl import *
import os

class USBToplevel(object):
    def __init__(self):
        pass
        
    def myhdl_module(self, 
        usb_ifclk, usb_slwr, usb_slrd, usb_sloe, usb_addr, usb_data_in, usb_data_out, usb_ep2_empty, usb_ep4_empty, usb_ep6_full, usb_ep8_full,
        mem_addr, mem_data_in, mem_data_driven, mem_data_out, mem_oe, mem_we, mem_clk, mem_addr_valid, 
        slot_data_in, slot_data_out, pmod, custom_dirchan, spi_adc_cs, spi_adc_mclk, spi_adc_mdi, spi_adc_mdo, spi_dac_cs, spi_dac_mclk, spi_dac_mdi, spi_dac_mdo, custom_adc_hwcon, custom_adc_ovf, custom_clk0, custom_srclk, custom_clksel, custom_clk1,
        reset, clk
        ):
        
        module_name = 'usb_toplevel'
        dependencies = [module_name, 'dut_' + module_name, 'tracking_fifo', 'memory_arbitrator', 'fx2_interface', 'bram_2k_8', 'dummy_dac', 'dummy_adc', 'bram_8m_16', 'cellram', 'delay_reg', 'dac_pmod', 'controller', 'deserializer', 'serializer', 'spi_controller', 'ioreg']
        cmd = "iverilog -o %s " % module_name + " ".join(["%s.v" % d for d in dependencies])
        os.system(cmd)
        
        return Cosimulation("vvp -m ../myhdl.vpi %s" % module_name, 
        usb_ifclk=usb_ifclk, usb_slwr=usb_slwr, usb_slrd=usb_slrd, usb_sloe=usb_sloe, usb_addr=usb_addr, usb_data_in=usb_data_in, usb_data_out=usb_data_out, usb_ep2_empty=usb_ep2_empty, usb_ep4_empty=usb_ep4_empty, usb_ep6_full=usb_ep6_full, usb_ep8_full=usb_ep8_full,
        mem_addr=mem_addr, mem_data_myhdl_driven=mem_data_driven, mem_data_myhdl_in=mem_data_in, mem_data=mem_data_out, mem_oe=mem_oe, mem_we=mem_we, mem_clk=mem_clk, mem_addr_valid=mem_addr_valid, 
        slot_data_in=slot_data_in, slot_data_out=slot_data_out, pmod=pmod, custom_dirchan=custom_dirchan, spi_adc_cs=spi_adc_cs, spi_adc_mclk=spi_adc_mclk, spi_adc_mdi=spi_adc_mdi, spi_adc_mdo=spi_adc_mdo, spi_dac_cs=spi_dac_cs, spi_dac_mclk=spi_dac_mclk, spi_dac_mdi=spi_dac_mdi, spi_dac_mdo=spi_dac_mdo, custom_adc_hwcon=custom_adc_hwcon, custom_adc_ovf=custom_adc_ovf, custom_clk0=custom_clk0, custom_srclk=custom_srclk, custom_clksel=custom_clksel, custom_clk1=custom_clk1,
        reset=reset, clk=clk)



