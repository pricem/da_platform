
"""
This module is the master interface to the wishbone bus.
"""

from myhdl import *
from wb_master_cmd import wb_master_cmd

def wb_master(
    clk,
    reset,

    # ---- Wishbone Bus ----
    wb_clk_o,
    wb_rst_o,
    wb_dat_o,
    wb_dat_i,
    wb_adr_o,
    wb_cyc_o,
    wb_ack_i,
    wb_err_i,
    wb_lock_o,
    wb_rty_i,
    wb_sel_o,
    wb_stb_o,
    wb_we_o,

    # FIFO interface, FIFO perspective
    wb_fifo_empty,
    wb_fifo_full,
    wb_fifo_wr,
    wb_fifo_rd,
    wb_fifo_di,
    wb_fifo_do,
    wb_fifo_do_vld,

    wb_cmd_ready,
    wb_cmd_in_prog,
    loopback,
    C_WB_DAT_SZ  = 8,
    C_WB_ADR_SZ  = 16
    ):
    """Wishbone master controller

    """

    wb_go    = Signal(False)
    wb_rd    = Signal(False)
    wb_wr    = Signal(False)
    fifo_rd  = Signal(False)
    fifo_wr  = Signal(False)
    wb_addr  = Signal(intbv(0)[C_WB_ADR_SZ:])
    wb_dat   = Signal(intbv(0)[C_WB_DAT_SZ:])
    i_dat_i  = Signal(intbv(0)[C_WB_DAT_SZ:])  # internal or'd bus
    cs_dat_i = Signal(intbv(0)[C_WB_DAT_SZ:])  # internal register read bus
    wb_ctrl0 = Signal(intbv(0)[8:])
    
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # Get data from FIFO
    # if data in the FIFO, read the data out, or if data is being
    # read from, echo back the complete command.  In the write case the
    # exact same data will be echo'd back.  In the read case the byte data
    # will be replaced with the data read from the wishbone bus.

    @always_comb
    def rtl1():
        wb_clk_o.next    = clk        # 
        wb_rst_o.next    = not reset  # 
        wb_adr_o.next    = wb_addr
        wb_dat_o.next    = wb_dat
        
        i_dat_i.next     = wb_dat_i | cs_dat_i
        wb_fifo_rd.next  = fifo_rd & ~wb_fifo_empty

    @always_comb
    def rtl2():
        if wb_ack_i and not wb_we_o: 
            wb_fifo_wr.next  = fifo_wr & ~wb_fifo_empty
            wb_fifo_di.next  = i_dat_i
        else:
            wb_fifo_wr.next  = fifo_wr & ~wb_fifo_empty & wb_fifo_do_vld
            wb_fifo_di.next  = wb_fifo_do

    @always(clk.posedge)
    def rtl3():
        if reset:
            fifo_wr.next = False
            fifo_rd.next = False
        else:
            # wb_cmd_ready == ep2_empty.  Only valid for 1 wishbone
            # command packet to be in flight at a time (simplfy flow control)
            # the complete packet should be read out of EP2 before processing
            if wb_cmd_ready and not wb_fifo_empty and not wb_fifo_full:
                if not wb_go:
                    fifo_rd.next = True
                    fifo_wr.next = True
                elif wb_go and wb_stb_o:
                    fifo_rd.next = True
                    fifo_wr.next = True

            else:
                fifo_rd.next = False
                fifo_wr.next = False


    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    wb_cmd = wb_master_cmd(clk, reset, wb_fifo_do, wb_fifo_do_vld,
                           wb_go, wb_rd,
                           wb_wr, wb_addr, wb_dat, wb_cmd_in_prog)


    @always_comb
    def rtl4():
        if wb_go and (wb_wr or wb_rd):
            wb_cyc_o.next   = True
            wb_lock_o.next  = False
            wb_stb_o.next   = True
            wb_we_o.next    = wb_wr

        else:
            wb_cyc_o.next  = False
            wb_lock_o.next = False
            wb_stb_o.next  = False
            wb_we_o.next   = False

        # byte select
        if wb_addr[1:0] == 0:
            wb_sel_o.next  = 1
        elif wb_addr[1:0] == 1:
            wb_sel_o.next  = 2
        elif wb_addr[1:0] == 2:
            wb_sel_o.next  = 4
        elif wb_addr[1:0] == 3:
            wb_sel_o.next  = 8

    
    @always(clk.posedge)
    def rtl5():
        if reset:
            wb_ctrl0.next = 0
        else:
            if wb_addr == 0 and wb_we_o:
                wb_ctrl0.next = wb_dat_o


    @always_comb
    def rtl6():
        if wb_addr == 0:
            cs_dat_i.next = wb_ctrl0
        else:
            cs_dat_i.next = 0

        loopback.next = wb_ctrl0[0]

    return instances()

