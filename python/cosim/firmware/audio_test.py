""" Test framework for audio conversion system.

An object-oriented revision of what was in usb_toplevel_test.py.
Meant to have unit-test-like capabilities

Inputs:
-   a callback to generate any needed audio samples for the specified channels up to the specified time (if needed)
-   timestamped samples received by the converters
-   timestamped SPI reads/writes from the converters
-   timestamped error messages from the converters

Stores:
-   sequence of timed writes for each USB endpoint
-   sequence of timed reads for each USB endpoint
-   converter board objects, so it can feed ADCs with data and monitor DAC outputs

Monitors:
-   amount of buffer delta on each port

"""

from myhdl import *

from datetime import datetime

from fx2_framework import FX2Model
from usb_toplevel import USBToplevel
from converterboard import ConverterBoard
from test_settings import *


#   Control which converter boards are used by modifying these imports.
from adc_pcm4202 import ADC2
from dac_dsd1792 import DAC2
from dac_ad1934 import DAC8
from adc_ad1974 import ADC8
from dac_pmod import DAC_PMOD

from testbase import TestBase, Event, Action, RecurrentAction

class AudioTester(TestBase):
    def __init__(self, mode=0, sim_cycles=SIM_LENGTH, logfile=None):
        self.fx2 = FX2Model(parent=self)
        self.converter = ConverterBoard(parent=self)
        self.dut = USBToplevel(parent=self)
        
        self.sim_cycles = sim_cycles
        self.action_queue = []
        self.action_granularity = 10
        
        #   Set up a log file, clear its contents        
        if logfile is None:
            self.logfile = 'test_%s.log' % datetime.strftime(datetime.now(),'%Y%m%d_%H%M%S')
        else:
            self.logfile = logfile
        fd = open(self.logfile, 'w')
        fd.close()
        
        #   Set up converter board with the specified modules.
        if mode == 0:
            self.converter.add_module(DAC_PMOD, {})
        else:
            #   Initial configuration: all 2-channel DACs
            self.converter_dirs = [0, 0, 0, 0]
            self.converter_chans = [0, 0, 0, 0]
            #   Rule for assigning converters by (dir, chan) pair
            converter_rule = {(0, 0): DAC2, (0, 1): DAC8, (1, 0): ADC2, (1, 1): ADC8}
            for i in range(len(self.converter_dirs)):
                self.converter.add_module(converter_rule[(self.converter_dirs[i], self.converter_chans[i])], {})
        
        #   Set up a queue for USB command and data messages to be sent.
        t = 0
        t_step = 20
        for msg in MESSAGES_EP2:
            self.queue_action(t, self.fx2.write_ep2, [ord(x) for x in msg], recurrent=True, period=5000)
            t += t_step
        t = 0
        for msg in MESSAGES_EP4:
            self.queue_action(t, self.fx2.write_ep4, [ord(x) for x in msg])
            t += t_step
        
    def queue_action(self, time, action, *args, **kwargs):
        #   Keep a list sorted in chronological order.
        if 'recurrent' in kwargs:
            period = kwargs['period']
            del kwargs['period']
            del kwargs['recurrent']
            self.action_queue.append(RecurrentAction(period, time, action, *args, **kwargs))
        else:
            self.action_queue.append(Action(time, action, *args, **kwargs))
        self.action_queue.sort(key=lambda x: x.time)
        
    def process_actions(self):
        time = now()
        last_index = 0
        if len(self.action_queue) > 0:
            #   Iterate over actions until you find one whose time has not come.
            while (last_index < len(self.action_queue)) and (self.action_queue[last_index].time <= time):
                last_index += 1
            
            #   Execute and remove all actions from the beginning of the list up to that one.
            for i in range(last_index):
                self.action_queue[i].execute()
            for i in range(last_index):
                if not isinstance(self.action_queue[0], RecurrentAction):
                    self.action_queue.pop(0)
                
            #   Return the actions to sorted order
            self.action_queue.sort(key=lambda x: x.time)
        
    def log(self, message):
        logfile = open(self.logfile, 'a')
        logfile.write(message + '\n')
        logfile.close()
        
    def handle_event(self, event):
        self.log('%s' % unicode(event))
        
    def myhdl_module(self):
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
        
        pmod = Signal(intbv(0)[4:])

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
        
        #   Check for queued actions, but not on every clock cycle because that might
        #   be too slow.  
        @instance
        def action_checker():
            last_time = 0
            while 1:
                delta = now() - last_time
                if delta > self.action_granularity:
                    self.process_actions()
                    last_time = now()
                yield usb_ifclk.negedge

        #   Run a few cycles of reset, then run the simulation for the specified time
        @instance
        def stimulus():
        
            reset.next = True
            for i in range(2):
                yield usb_ifclk.negedge
            reset.next = False
            yield usb_ifclk.negedge
        
            for i in range(self.sim_cycles):
                yield usb_ifclk.negedge
                
            raise StopSimulation
                
        """ Logic module instances """
        
        #   FX2 processor on Nexys2 board (which is connected to USB bus from computer)
        fx2 = self.fx2.myhdl_module(usb_ifclk, reset_neg, usb_slwr, usb_slrd, usb_sloe, usb_addr, usb_data_in, usb_data_out, usb_ep2_empty, usb_ep4_empty, usb_ep6_full, usb_ep8_full)
        
        #   Firmware on FPGA
        doobie = self.dut.myhdl_module(usb_ifclk, usb_slwr, usb_slrd, usb_sloe, usb_addr, usb_data_in, usb_data_out, usb_ep2_empty, usb_ep4_empty, usb_ep6_full, usb_ep8_full, mem_addr, mem_data_in, mem_data_driven, mem_data_out, mem_oe, mem_we, mem_clk, mem_addr_valid, slot_data_in, slot_data_out, pmod, custom_dirchan, spi_adc_cs, spi_adc_mclk, spi_adc_mdi, spi_adc_mdo, spi_dac_cs, spi_dac_mclk, spi_dac_mdi, spi_dac_mdo, custom_adc_hwcon, custom_adc_ovf, custom_clk0, custom_srclk, custom_clksel, custom_clk1, reset, clk)
        
        #   Simulated converter board
        conv = self.converter.myhdl_module(slot_data_in, slot_data_out, spi_adc_cs, spi_adc_mclk, spi_adc_mdi, spi_adc_mdo, spi_dac_cs, spi_dac_mclk, spi_dac_mdi, spi_dac_mdo, custom_adc_hwcon, custom_adc_ovf, pmod, custom_clk0, custom_clk1, custom_dirchan, custom_srclk, custom_clksel, reset)

        return instances()

