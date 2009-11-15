#

"""
 This module contains the logic to interface with the FX2 Slave
 FIFO Interface.
 
 The FX2 Endpoints are a conduit between the USB bus and the FPGA.
 
 The data is sent directly to the FPGA with no interaction from
 the USB controllers embedded processor.
 
 The port listing will match the defined FIFO interface exactly
 and the signals will be assigned to signal names that match
 the actual functionality.  Also the FX2 has an 8bit (or 16bit)
 bi-dir interface.  The actual inout tristate logic has to be
 infered at the top level of the design. 
 
 FYI - The FX2 Registers associate with programming the FIFOs to 
       slave FIFO.  Endpoints 2-6, 4-8 will expected to be programmed
       as slave FIFO to the FPGA.
     
     # IFCONFIG         - Bits 1:0 Must be set to 2'b11
     # PINFLAGAB        -
     # PINFLAGCD        -
     # FIFORESET        -
     # FIFOPINPOLAR     -
     # EPxCFG           -
     # EPxFIFOCFG       -
     # EPxAUTOINLENH:L  -
     # EPxFIFOPFH:L     -
     # PORTACFG         -
     # INPKTEND         -
     # EPxFLAGIE        -
     # EPxFLAGIRQ       -
     # EPxFIFOBCH:L     -
     # EPxFLAGS         -
     # EPxBUF           - 
     
     Syncronous Mode, Data clocks in on the rising edge of IFCLK.
     8-bit mode (low pin count controllers), WORDWIDE=0 8bit mode.
     
     The FIFO Flags will be setup to use the Empty flags for the OUT FIFOS
     and Full for the IN FIFOS.
     FIFOADR[1:0]
       00 - EP2 OUT
       01 - EP4 OUT
       10 - EP6 IN 
       11 - EP8 IN
"""

from myhdl import *
from fx2_arb import fx2_arb

def fx2_sfifo_intf(
    reset,           # syncronous system reset
    # ----[ FX2 FIFO Interface ]----
    IFCLK,           # USB controller sync clock @ 48MHz
    FLAGA,           # EP2 (Out) Empty
    FLAGB,           # EP4 (Out) Empty    
    FLAGC,           # EP4 (In)  Full
    FLAGD,           # EP8 (In)  Full

    SLOE,            # Output Enable, Slave FIFO
    SLRD,            # Read Strobe
    SLWR,            # Write Strobe

    FIFOADR,         # FIFO select signals
    PKTEND,          # Packet end, inform FX2 to send data without FIFO full
    FDI,             # Fifo data in
    FDO,             # Fifo data out

    # ----[ Internal Bus ]----
    bus_di,          # input, data to FX2 from wb bus
    bus_di_vld,      # input, data valid strobe
    bus_do,          # To Bus_FIFO Port A
    bus_full,        #
    bus_empty,       #
    bus_wr,          #
    bus_rd,          #

    # ----[ Internal data stream FIFO ] ----
    fifo_di,         # input, data to FX2
    fifo_di_vld,     # input, data valid strobe
    fifo_do,         #
    fifo_full,       #
    fifo_empty,      #
    fifo_wr,         #
    fifo_rd,         #
    fifo_hold,       #
    wb_cmd_in_prog,  # Wishbone command in progress
    dbg
    ):
    """FX2 Slave FIFO interface
    """

    
    ep2_read   = Signal(False)
    ep6_write  = Signal(False)
    ep4_read   = Signal(False)
    ep8_write  = Signal(False)
    
    ep2_empty  = Signal(False)
    ep6_full   = Signal(False)
    ep4_empty  = Signal(False)
    ep8_full   = Signal(False)

    ep2_din    = Signal(intbv(0)[8:])
    ep4_din    = Signal(intbv(0)[8:])
    ep6_dout   = Signal(intbv(0)[8:])
    ep8_dout   = Signal(intbv(0)[8:])

    _fifo_wr   = Signal(False)
    _bus_wr    = Signal(False)

    _slwr      = Signal(False)
    _slrd      = Signal(False)
    _sloe      = Signal(False)
    _pktend    = Signal(False)
    _fifoadr   = Signal(intbv(0)[2:])
    _vld       = Signal(False)

    @always_comb
    def rtl_vld():
        _vld.next = bus_di_vld | fifo_di_vld
        
    @always_comb
    def rtl_assignments():
        ep2_empty.next = FLAGA
        ep6_full.next  = FLAGC
        ep4_empty.next = FLAGB
        ep8_full.next  = FLAGD

        bus_do.next  = ep2_din
        fifo_do.next = ep4_din
        dbg.next     = 0

        fifo_wr.next = _fifo_wr & ~fifo_full
        bus_wr.next  = _bus_wr & ~bus_full

        SLWR.next    = _slwr & _vld 
        SLRD.next    = _slrd
        SLOE.next    = _sloe
        PKTEND.next  = _pktend
        FIFOADR.next = _fifoadr
        
        if ep6_write:
            FDO.next = bus_di
        else:
            FDO.next = fifo_di

        if ep6_write:
            bus_rd.next = _slwr
        else:
            bus_rd.next = False

        if ep8_write:
            fifo_rd.next = _slwr
        else:
            fifo_rd.next = False

            
    # arbitration module, determine with FX2 FIFO to move data to or from
    # The arb module drives some of the wr/rd signals since it determines
    # which endpoints are being read/written
    arb = fx2_arb(reset, IFCLK, ep2_empty, ep6_full, ep4_empty, ep8_full,
                  _sloe, _slrd, _slwr, _pktend, _fifoadr,
                  bus_full, bus_empty, bus_di_vld,
                  fifo_full, fifo_empty, fifo_di_vld,
                  ep2_read, ep6_write, ep4_read, ep8_write,
                  fifo_hold, wb_cmd_in_prog)


    @always(IFCLK.posedge)
    def rtl_bus_wr():
        if reset:
            ep2_din.next = 0
            _bus_wr.next = False
        else:
            if ep2_read and _slrd:
                ep2_din.next = FDI
                _bus_wr.next = True
            else:
                _bus_wr.next = False


    @always(IFCLK.posedge)
    def rtl_data_wr():
        if reset:
            ep4_din.next  = 0
            _fifo_wr.next = False
        else:
            if ep4_read and _slrd:
                ep4_din.next  = FDI
                _fifo_wr.next = True
            elif _fifo_wr and fifo_full:
                _fifo_wr.next = False
            else:
                _fifo_wr.next = False


    return instances()

