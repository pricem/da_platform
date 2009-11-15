#
#
#

import sys, os
from collections import deque
from myhdl import *

class fx2():
    """
    This is a model of the FX2 USB processor.
    """
    EP2 = 2
    EP4 = 4
    EP6 = 6
    EP8 = 8
    
    def __init__(self, verbose=False):

        self.IFCLK_TICK = 20
        self.EP2 = 2
        self.EP4 = 4
        self.EP6 = 6
        self.EP8 = 8
        self.WrFifo26 = deque()  # Write FIFO (this) writes the fifo
        self.RdFifo26 = deque()  # Read FIFO

        self.WrFifo48 = deque()  # Write FIFO
        self.RdFifo48 = deque()  # Read FIFO
        # 
        self.wrToggle = Signal(False)
        self.Verbose  = verbose

    def TracePrint(self, str):
        if self.Verbose:
            print str
            sys.stdout.flush()
            
            
    def SlaveFifo(self,
                  IFCLK,     # Output, 48MHz clock
                  RST,       # Input, system reset
                  SLWR,      # Slave write signal
                  SLRD,      # Slave read signal
                  SLOE,      # FIFO output enable
                  ADDR,      # FIFO Address Select
                  FDI,       # External Data bus, data in
                  FDO,       # External Data but, data out
                  EP2_EMPTY, # EndPoint 2 Empty,  ADDR = 00, FLAGA
                  EP6_FULL,  # EndPoint 6 Full,   ADDR = 10, FLAGC
                  EP4_EMPTY, # EndPoint 4 Empty,  ADDR = 01, FLAGB
                  EP8_FULL,  # EndPoint 8 Full,   ADDR = 11, FLAGD
                  ):
        """
        This function will drive the FX2 Slave FIFO interface.  This is intended
        to be part of a MyHDL simulation
        """

        fdi = Signal(intbv(0)[8:])
        fdo = Signal(intbv(0)[8:])

        @always(delay(self.IFCLK_TICK/2))
        def clkgen():
            IFCLK.next = not IFCLK
                            

        @always(IFCLK.posedge)
        def rtl_fifo_rw():
            if not RST:
                self.TracePrint('Slave Fifo Reset')
                EP2_EMPTY.next = True   # Empty
                EP6_FULL.next  = False  # Not Full
                EP4_EMPTY.next = True   # Empty
                EP8_FULL.next  = False  # Not Full

            else:
                #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                # Do Read / Writes to FIFOs
                #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                assert (SLWR and not SLRD) or (not SLWR and SLRD) or (not SLWR and not SLRD)
                if SLWR and not SLOE:                    
                    if ADDR == 2:
                        if len(self.RdFifo26) < 512:
                            self.RdFifo26.append(int(fdi.val))
                    elif ADDR == 3:
                        if len(self.RdFifo48) < 512:
                            self.RdFifo48.append(int(fdi.val))
                elif SLOE and SLRD:
                    if ADDR == 0:
                        if len(self.WrFifo26) > 0:
                            self.TracePrint("%s" % (self.WrFifo26))
                            self.WrFifo26.popleft()
                    elif ADDR == 1:
                        if len(self.WrFifo48) > 0:
                            self.TracePrint("%s" % (self.WrFifo48))
                            self.WrFifo48.popleft()

                if len(self.RdFifo48) == 128 or len(self.RdFifo48) == 256 or len(self.RdFifo48) == 512:
                    self.TracePrint("RdFifo46 len %d" % (len(self.RdFifo48)))
                    
                #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                # FIFOs have been modified, adjust flags
                #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                if len(self.WrFifo26) > 0:
                    EP2_EMPTY.next = False
                else:
                    EP2_EMPTY.next = True
                    
                if len(self.WrFifo48) > 0:
                    EP4_EMPTY.next = False
                else:
                    EP4_EMPTY.next = True

                if len(self.RdFifo26) >= 512:
                    EP6_FULL.next = True
                else:
                    EP6_FULL.next = False
                    
                if len(self.RdFifo48) >= 512:
                    EP8_FULL.next = True
                else:
                    EP8_FULL.next = False

        @always_comb
        def rtl_dio():
            FDO.next = fdo
            fdi.next = FDI

        #or self.wrToggle.posedge or self.wrToggle.negedge)
        @always(IFCLK.posedge or IFCLK.negedge)
        def rtl_do():
            if ADDR == 0:
                if len(self.WrFifo26) > 0:
                    self.TracePrint('fdo26 --> %s (%s)' % (fdo, type(self.WrFifo26[0])))
                    fdo.next = self.WrFifo26[0]
                else:
                    fdo.next = 0
            elif ADDR == 1:
                if len(self.WrFifo48) > 0:
                    self.TracePrint('fdo48 --> %s (%s)' % (fdo, type(self.WrFifo48[0])))
                    fdo.next = self.WrFifo48[0]
                else:
                    fdo.next = 0
                
        return clkgen, rtl_fifo_rw, rtl_dio, rtl_do
                

    def Read(self, ep):
        rd = None
        if ep == self.EP6:
            if len(self.RdFifo26) > 0:
                rd = self.RdFifo26.popleft()
            else:
                print 'FX2: Error Read Fifo26'
        elif ep == self.EP8:
            if len(self.RdFifo48) > 0:
                rd = self.RdFifo48.popleft()
            else:
                print 'FX2: Error Read Fifo48'

        self.TracePrint('FX2: Read EP %s --> %s f26 %d f48 %d' % (ep, rd, len(self.RdFifo26), len(self.RdFifo48)))
        self.TracePrint('  FX2: Read f26 %s' % (self.RdFifo26))
        self.TracePrint('  FX2: Read f48 %s' % (self.RdFifo48))
        return rd


    def Write(self, data, ep):
        self.TracePrint('FX2: Write EP %s' % (ep))
        if type(data) is list:
            for d in data:
                self.TracePrint("fill fifo %s with %d " % (ep, d))
                if ep == self.EP2:
                    self.WrFifo26.append(d)
                elif ep == self.EP4:
                    self.WrFifo48.append(d)
        elif isinstance(data, (int, long)):
            if ep == self.EP2:
                self.WrFifo26.append(data)
            elif ep == self.EP4:
                self.WrFifo48.append(data)
        else:
            raise TypeError
                
        self.wrToggle.next = not self.wrToggle
    
        
    def IsEmpty(self, ep):
        self.TracePrint('FX2: Wait Empty EP %s' % (ep))
        if ep == self.EP2:
            if len(self.WrFifo26) > 0:
                return False
        elif ep == self.EP4:
            self.TracePrint('FX2: Length WrFifo48 %d' % (len(self.WrFifo48)))
            if len(self.WrFifo48) > 0:
                return False
                    
        return True



    def IsData(self, ep, Num=1):
        self.TracePrint('FX2: Wait Data EP %s' % (ep))
        if ep == self.EP6:
            if len(self.RdFifo26) < Num:
                return False
        elif ep == self.EP8:
            if len(self.RdFifo48) < Num:
                return False

        return True

    def WaitEmpty(self, ep):
        while not self.IsEmpty(ep):
            yield delay(2*self.IFCLK_TICK)

    def WaitData(self, ep, Num=1):
        while not self.IsData(ep, Num):
            yield delay(2*self.IFCLK_TICK)
                        
    def WriteAddress(self, addr, data):

        wbuf = [0xDE, 0xCA, 0x01, 0x00, 0x00, 0x01, 0xFB, 0xAD, 0x00]
        rbuf = [0]*9
        
        wbuf[3]  = (addr >> 8) & 0xFF
        wbuf[4]  = addr & 0xFF
        wbuf[5]  = 1
        wbuf[8]  = data

        self.Write(wbuf, self.EP2)
        while not self.IsEmpty(self.EP2):
            yield delay(2*self.IFCLK_TICK)
        while not self.IsData(self.EP6, 9):
            yield delay(2*self.IFCLK_TICK)
            
        for i in range(9):
            rbuf[i] = self.Read(self.EP6)        

        for i in range(9):
            assert wbuf[i] == rbuf[i]
            


    def ReadAddress(self, addr, data):

        wbuf = [0xDE, 0xCA, 0x02, 0x00, 0x00, 0x01, 0xFB, 0xAD, 0x00]
        rbuf = [0]*9
        
        wbuf[3]  = (addr >> 8) & 0xFF
        wbuf[4]  = addr & 0xFF
        wbuf[5]  = 1

        self.Write(wbuf, self.EP2)
        while not self.IsEmpty(self.EP2):
            yield delay(2*self.IFCLK_TICK)
            
        while not self.IsData(self.EP6, 9):
            yield delay(2*self.IFCLK_TICK)

        for i in range(9):
            rbuf[i] = self.Read(self.EP6)

        for i in range(8):
            if wbuf[i] != rbuf[i]:
                print '[%d] wbuf %s' % (i, wbuf)
                print '[%d] rbuf %s' % (i, rbuf)
                raise AssertionError

        data[0] = rbuf[8]

            

        

        
