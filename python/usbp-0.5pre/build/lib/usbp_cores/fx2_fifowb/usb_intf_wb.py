
"""
  This module is the USB interface.  It contains the FX2 slave FIFO
  interface.  This module is the bridge between the USB fifos, the internal
  wishbone bus, and the straight FIFO interface.
  
  This module is also designed to translate between 2 different clock
  domains if needed.  The FX2 slave FIFO interface runs on the IFCLK (48MHz)
  clock.  The interal system clock can be a different clock rate.\
  
  NOTE: The internal naming convention for data direction is a little messed up.
"""

import sys,os
from myhdl import *
from wb_master import wb_master

from open_cores.fifo import fifo_two_port_sync

from ..fx2_sfifo import fx2_sfifo_intf

def usb_intf_wb(
    reset,             # System reset    
    ifclk,             # IFCLK from FX2
    sys_clk,           # Internal FPGA clk,
    
    # ---- FX2 FIFO Interface ----
    FLAGA,             # EP2(OUT) Empty
    FLAGB,             # EP4(OUT) Empty
    FLAGC,             # EP6(IN)  Full
    FLAGD,             # EP8(IN)  Full
    SLOE,              # Output Enable, Slave FIFO
    SLRD,              # Read Signal
    SLWR,              # Write Signal
    FIFOADR,           # Which of the 4 FIFO currently interfacing with.                       
    PKTEND,            # Packet End, Tell FX2 to send data without FIFO Full
    FDI,               # Fifo Data In
    FDO,               # Fifo Data Out 
 
    # ---- Wishbone Bus ----
    #  Note clk_i signal has been excluded.  Using sys_clk input
    wb_clk_o,          # Sync clock == sys_clk
    wb_rst_o,          # Wishbone Reset
    wb_dat_o,          # Data bus out
    wb_dat_i,          # Data bus in
    wb_adr_o,          # Address bus out
    wb_cyc_o,          # Bus cycle in process
    wb_ack_i,          # Normal termination of bus cycle
    wb_err_i,          # Bus cycle ended in error
    wb_lock_o,         # Non interruptable bus cycle, == cyc_o
    wb_rty_i,          # Retry bus cycle
    wb_sel_o,          # Valid bytes, only byte bus
    wb_stb_o,          # Strobe output
    wb_we_o,           # Write Enable
    
    #  Wishbone signals not used.
    # wb_tgd_o,wb_tdg_i,wb_tga_o,wb_tgc_o
    
    # ---- Async FIFO Interface ----
    fifo_di,           # FIFO data input    
    fifo_do,           # FIFO data output
    fifo_do_vld,       # FIFO data output valid
    fifo_full,         # Full control signal       
    fifo_empty,        # Empty control signal
    fifo_wr,           # Write Strobe
    fifo_rd,           # Read Strobe
    fifo_hold,         # Wait, enables complete packet etc.
    loopback,          # Loopback, status to the top
    dbg,               # Run-time debug signals
    C_WB_DAT_SZ = 8,   # Wishbone data width
    C_WB_ADR_SZ = 16,  # Wishbone address width
    ):
    """USB (FX2 USB Controller) Interface
    
    """

    # Async FIFO signals from FX2 interface
    fx2_wb_di      = Signal(intbv(0)[C_WB_DAT_SZ:])
    fx2_wb_di_vld  = Signal(False)
    fx2_wb_do      = Signal(intbv(0)[C_WB_DAT_SZ:])
    fx2_wb_full    = Signal(False)
    fx2_wb_empty   = Signal(True)
    fx2_wb_wr      = Signal(False)
    fx2_wb_rd      = Signal(False)
    
    fx2_fifo_di    = Signal(intbv(0)[C_WB_DAT_SZ:])
    fx2_fifo_di_vld = Signal(False)
    fx2_fifo_do    = Signal(intbv(0)[C_WB_DAT_SZ:])
    fx2_fifo_full  = Signal(False)
    fx2_fifo_empty = Signal(True)
    fx2_fifo_wr    = Signal(False)
    fx2_fifo_rd    = Signal(False)
    
    # Async FIFO interface to WB master
    wb_fifo_di     = Signal(intbv(0)[C_WB_DAT_SZ:])
    wb_fifo_do     = Signal(intbv(0)[C_WB_DAT_SZ:])
    wb_fifo_do_vld = Signal(False)
    wb_fifo_full   = Signal(False)
    wb_fifo_empty  = Signal(True)
    wb_fifo_wr     = Signal(False)
    wb_fifo_rd     = Signal(False)
    
    # External and looback async FIFO signals
    lp_fifo_di      = Signal(intbv(0)[C_WB_DAT_SZ:])
    lp_fifo_do      = Signal(intbv(0)[C_WB_DAT_SZ:])
    lp_fifo_do_vld  = Signal(False)
    lp_fifo_full    = Signal(False)
    lp_fifo_empty   = Signal(True)
    lp_fifo_wr      = Signal(False)
    lp_fifo_rd      = Signal(False)
    _lp_fifo_wr     = Signal(False)
    _lp_fifo_rd     = Signal(False)
    
    i_fifo_di      = Signal(intbv(0)[C_WB_DAT_SZ:])
    i_fifo_do      = Signal(intbv(0)[C_WB_DAT_SZ:])
    i_fifo_do_vld  = Signal(False)
    i_fifo_full    = Signal(False)
    i_fifo_empty   = Signal(True)
    i_fifo_wr      = Signal(False)
    i_fifo_rd      = Signal(False)


    # Some debug registers
    data_path_wr_ovfl  =  Signal(intbv(0)[32:])
    data_path_rd_ovfl  =  Signal(intbv(0)[32:])
    err_wr_fxfifo      =  Signal(intbv(0)[32:])
    err_rd_fxfifo      =  Signal(intbv(0)[32:])
    err_wr_ififo       =  Signal(intbv(0)[32:])
    err_rd_ififo       =  Signal(intbv(0)[32:])
    
    wb_cmd_in_prog     = Signal(False)
    fx2_dbg            = Signal(intbv(0)[8:])
    dbg_it             = Signal(False)
    ireset             = Signal(False)
    
    @always_comb
    def debug_sigs():
        dbg.next[0] = ireset
        dbg.next[1] = i_fifo_wr
        dbg.next[2] = FLAGA
        dbg.next[3] = wb_cmd_in_prog
        dbg.next[4] = fx2_wb_empty
        dbg.next[5] = wb_fifo_empty
        dbg.next[6] = wb_fifo_wr
        dbg.next[7] = dbg_it
        
    @always(ifclk.posedge)
    def dgb_it_rtl():
        if reset:
            dbg_it.next = False
        else:
            if i_fifo_wr:
                dbg_it.next = True

    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # Keep this module in reset until the FX2 is ready, the software
    # will have to make sure the IN endpoints are empty.
    @always(ifclk.posedge)
    def rtl1():
        if reset:
            ireset.next = True
        else:
            if not FLAGC and not FLAGD:
                ireset.next = False


   
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # Slave FIFO Interface
    fx2 = fx2_sfifo_intf(reset, ifclk,
                         # FX2 slave fifo control and data signals
                         FLAGA, FLAGB, FLAGC, FLAGD, SLOE,
                         SLRD, SLWR, FIFOADR, PKTEND, FDI, FDO,
                         # Wishbone data fifo signals
                         fx2_wb_di, fx2_wb_di_vld, fx2_wb_do, fx2_wb_full,
                         fx2_wb_empty, fx2_wb_wr, fx2_wb_rd,
                         # Stream data fifo signals
                         fx2_fifo_di, fx2_fifo_di_vld, fx2_fifo_do, fx2_fifo_full,
                         fx2_fifo_empty, fx2_fifo_wr, fx2_fifo_rd, fifo_hold,
                         # misc
                         wb_cmd_in_prog, fx2_dbg)
   
    # Wishbone bus controller2
    wb_controller = wb_master(sys_clk, ireset, wb_clk_o, wb_rst_o, wb_dat_o, wb_dat_i,
                              wb_adr_o, wb_cyc_o, wb_ack_i, wb_err_i, wb_lock_o, wb_rty_i,
                              wb_sel_o, wb_stb_o, wb_we_o,
                              # From/To FX2
                              wb_fifo_empty, wb_fifo_full, wb_fifo_wr, wb_fifo_rd,
                              wb_fifo_di, wb_fifo_do, wb_fifo_do_vld,
                              FLAGA, # should alias wb_cmd_ready = ep2_empty
                              wb_cmd_in_prog, loopback)

    # 512 byte wb command fifo    
    wb_fifo  = fifo_two_port_sync(ireset, ifclk,
                                  # A channel FX2 write -- internal read
                                  fx2_wb_wr, wb_fifo_rd,
                                  fx2_wb_full, wb_fifo_empty,
                                  fx2_wb_do, wb_fifo_do, wb_fifo_do_vld,
                                  # B channel internal write -- FX2 read
                                  wb_fifo_wr, fx2_wb_rd,
                                  wb_fifo_full, fx2_wb_empty,
                                  wb_fifo_di, fx2_wb_di, fx2_wb_di_vld,
                                  # @todo flush?
                                  DSZ=8, ASZ=9)
    # 1k external FIFO
    ex_fifo  = fifo_two_port_sync(ireset, ifclk,
                                  # A channel FX2 write -- internal read
                                  fx2_fifo_wr, i_fifo_rd,
                                  fx2_fifo_full, i_fifo_empty,
                                  fx2_fifo_do, i_fifo_do, i_fifo_do_vld,
                                  # B channel internal write -- FX2 read
                                  i_fifo_wr, fx2_fifo_rd,
                                  i_fifo_full, fx2_fifo_empty,
                                  i_fifo_di, fx2_fifo_di, fx2_fifo_di_vld,
                                  # @todo flush?
                                  DSZ=8, ASZ=10)

   
    @always(ifclk.posedge)
    def rtl2():
        if reset:
            err_wr_fxfifo.next = 0
            err_rd_fxfifo.next = 0
            err_wr_ififo.next  = 0
            err_rd_ififo.next  = 0
        else:
            if fx2_fifo_wr and fx2_fifo_full:
                err_wr_fxfifo.next = err_wr_fxfifo +1

            if fx2_fifo_rd and fx2_fifo_empty:
                err_rd_fxfifo.next = err_rd_fxfifo + 1

            if i_fifo_wr and i_fifo_full:
                err_wr_ififo.next = err_wr_ififo + 1

            if i_fifo_rd and i_fifo_empty:
                err_rd_ififo.next = err_rd_ififo + 1


    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # Built in loop back
    @always_comb
    def rtl3():
        if loopback:
            i_fifo_di.next      = lp_fifo_di
            i_fifo_wr.next      = lp_fifo_wr
            i_fifo_rd.next      = lp_fifo_rd
            lp_fifo_do.next     = i_fifo_do
            lp_fifo_do_vld.next = i_fifo_do_vld
            lp_fifo_full.next   = i_fifo_full
            lp_fifo_empty.next  = i_fifo_empty
            
            fifo_do.next     = 0
            fifo_do_vld.next = False
            fifo_full.next   = False
            fifo_empty.next  = False
            
        else:
            i_fifo_di.next   = fifo_di
            i_fifo_wr.next   = fifo_wr
            i_fifo_rd.next   = fifo_rd
            fifo_do.next     = i_fifo_do
            fifo_do_vld.next = i_fifo_do_vld
            fifo_full.next   = i_fifo_full
            fifo_empty.next  = i_fifo_empty

            lp_fifo_do.next     = 0
            lp_fifo_do_vld.next = False
            lp_fifo_full.next   = False
            lp_fifo_empty.next  = False


    @always_comb
    def rtl4():
        lp_fifo_di.next  = lp_fifo_do
        lp_fifo_rd.next  = _lp_fifo_rd & ~lp_fifo_full & ~lp_fifo_empty 
        lp_fifo_wr.next  = _lp_fifo_wr & ~lp_fifo_full & ~lp_fifo_empty & lp_fifo_do_vld

    @always(sys_clk.posedge)
    def rtl5():
        if ireset:
            _lp_fifo_wr.next = False
            _lp_fifo_rd.next = False
        else:
            if not lp_fifo_empty and not lp_fifo_full:
                _lp_fifo_rd.next = True
                _lp_fifo_wr.next = True
            else:
                _lp_fifo_rd.next = False
                _lp_fifo_wr.next = False

                
    return instances()


