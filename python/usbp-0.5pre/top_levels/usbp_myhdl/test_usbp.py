#
#
#

import sys, os, time
from myhdl import *

import usbp_cores
from usbp_cores.fx2_fifowb import usb_intf_wb
from usbp_cores.fx2_model  import fx2

from usbp_myhdl import usbp_myhdl

def TracePrint(str):
    print '        ** ', str, ' **'
    
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Self Checking TestBench 
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~        
def cmdLineTestBench(run='trace'):

    # --[ Simulation Constants ]--
    
    # --[ Signals ]--
    reset   = Signal(False)
    sys_clk  = Signal(False)
    RST     = Signal(True)
    IFCLK   = Signal(False)
    FLAGA   = Signal(False)
    FLAGB   = Signal(False)
    FLAGC   = Signal(False)
    FLAGD   = Signal(False)
    SLOE    = Signal(False)
    SLRD    = Signal(False)
    SLWR    = Signal(False)
    FIFOADR = Signal(intbv(0)[2:])
    PKTEND  = Signal(False)
    mFDI    = Signal(intbv(0)[8:])
    mFDO    = Signal(intbv(0)[8:])

    SS        = Signal(intbv(0)[8:])
    SCK       = Signal(False)
    MOSI      = Signal(False)
    MISO      = Signal(False)
    SCL_o     = Signal(False)
    SCL_i     = Signal(False)
    SDA_o     = Signal(False)
    SDA_i     = Signal(False)
    
    LEDs    = Signal(intbv(0)[8:])
    TP_HDR  = Signal(intbv(0)[16:])
    
    
    # Determine the type of simulation to run
    if run is 'trace':
        dut = traceSignals(usbp_myhdl, reset, sys_clk, IFCLK, FLAGA, FLAGB, FLAGC, FLAGD,
                           SLOE, SLRD, SLWR, FIFOADR, PKTEND, mFDO, mFDI,
                           LEDs, SS, SCK, MOSI, MISO,
                           SCL_i, SCL_o, SDA_i, SDA_o)
    elif run is 'cver':
        print 'TODO'
        return
    elif run is 'run':
        dut = usbp_myhdl(reset, sys_clk, IFCLK, FLAGA, FLAGB, FLAGC, FLAGD,
                         SLOE, SLRD, SLWR, FIFOADR, PKTEND, mFDO, mFDI,
                         LEDs, SS, SCK, MOSI, MISO,
                         SCL_i, SCL_o, SDA_i, SDA_o)
    else:
        print 'Invalid Run Type'
        return

    fx2Model    = fx2(verbose=False)
    fx2ModelRtl = fx2Model.SlaveFifo(IFCLK, RST, SLWR, SLRD, SLOE, FIFOADR,
                                     mFDI, mFDO, FLAGA, FLAGC, FLAGB, FLAGD)


    @always_comb
    def misc_tb():
        sys_clk.next = IFCLK
        RST.next     = not reset
        
    @instance
    def stimulus():
        rbuf = [0]
        wbuf = [0]
        
        TracePrint('Start Testbench')
        test_data1 = [0xAA, 0x55, 0x0B, 0x0C, 0x0D]
        #test_data2 = range(511) # @todo constraint random
        #test_data3 = range(512) # @todo make constraint random
        #test_data4 = range(513) # @todo make constraint random
        
        reset.next = False
        yield IFCLK.posedge

        TracePrint('Reset')
        reset.next = True
        for w in range(10):
            yield IFCLK.posedge
        reset.next = False
        TracePrint('End Reset')

        TracePrint('Write Wishbone LEDs')
        yield fx2Model.WriteAddress(0x0101, 1)
        print "    %x" % (LEDs)
        yield fx2Model.WriteAddress(0x0103, 0xAA)
        print "    %x" % (LEDs)        

        TracePrint('Read Wishbone LEDs')
        yield fx2Model.ReadAddress(0x0103, rbuf)
        print "    GPIO read %x " % (rbuf[0])

        # Setup for RAMP Test input
        yield fx2Model.WriteAddress(0x0800, 0x01)

        TracePrint('  Check Ramp Data')
        rmpData = 0
        r1 = []; r2=[]
        for jj in range(100):
            yield fx2Model.WaitData(fx2Model.EP8, 1024)
            yield delay(128 * fx2Model.IFCLK_TICK)
            print ".", 
            if jj % 48 == 0:
                print " "
            sys.stdout.flush()
            
            for ii in range(512):
                rdata = fx2Model.Read(fx2Model.EP8)
                r1.append(rdata); r2.append(rmpData)
                if rdata != rmpData:
                    print r1
                    print r2
                    raise AssertionError, 'Ramp Data Error [%d] %x != %x' % (ii, rdata, rmpData)
                rmpData = (rmpData + 1) % 256

        print " "    
        yield delay(20*fx2Model.IFCLK_TICK)

        TracePrint('  Disable Ramp')
        yield fx2Model.WriteAddress(0x0800, 0x00)

        #@todo flush FIFOs
        
        #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        #TracePrint('Test Reads and Writes 1')
        #for dat in test_data1:
        #    fx2Model.Write(dat, fx2Model.EP4)        
        #
        #TracePrint('Wait for write fifo empty')
        #while not fx2Model.IsEmpty(fx2Model.EP4):
        #    yield delay(2*fx2Model.IFCLK_TICK)
        #
        #TracePrint('Wait for data in read fifo')
        #while not fx2Model.IsData(fx2Model.EP8, 5):
        #    yield delay(2*fx2Model.IFCLK_TICK)
        #
        #for dat in test_data1:
        #    rdata = fx2Model.Read(fx2Model.EP8)
        #    assert rdata == dat, \
        #     "Testbench FAILED return data %x expected %x" % (rdata, dat)
        #    #print "return data %x expected %x" % (rdata, dat)
        #
        #yield delay(20*fx2Model.IFCLK_TICK)


        #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        #-#TracePrint('Test Reads and Writes 2')
        #-#for dat in test_data2:
        #-#    fx2Model.Write(dat, fx2Model.EP4)        
        #-#
        #-#TracePrint('Wait for write fifo empty')
        #-#while not fx2Model.IsEmpty(fx2Model.EP4):
        #-#    yield delay(2*fx2Model.IFCLK_TICK)
        #-#
        #-#TracePrint('Wait for data in read fifo')
        #-#while not fx2Model.IsData(fx2Model.EP8, 5):
        #-#    yield delay(2*fx2Model.IFCLK_TICK)
        #-#
        #-#for dat in test_data2:
        #-#    rdata = fx2Model.Read(fx2Model.EP8)
        #-#    assert rdata == dat, \
        #-#     "Testbench FAILED return data %x expected %x" % (rdata, dat)
        #-#    #print "return data %x expected %x" % (rdata, dat)

        yield delay(20*fx2Model.IFCLK_TICK)
        
        raise StopSimulation

    #print instances()
    return instances()


if __name__ == '__main__':
    tb = cmdLineTestBench(run='trace')       
    sim = Simulation(tb)
    sim.run()
