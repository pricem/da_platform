

"""
"""

from myhdl import *
from rmp_register_def import *
from rmp_register_file import *

def fifo_ramp(
    # --[ Wishbone Bus ]--
    clk_i,          # wishbone clock
    rst_i,          # wishbone reset 
    cyc_i,          # cycle
    stb_i,          # strobe
    adr_i,          # address
    we_i,           # write enable
    sel_i,          # byte select
    dat_i,          # data input
    dat_o,          # data output
    ack_o,          # acknowledge

    # --[ Streaming Interface ]--
    fifo_di,        # Data to the FIFO
    fifo_do,        # Data from the FIFO
    fifo_do_vld,    # Data from the FIFO valid
    fifo_rd,        # read from streaming fifo
    fifo_wr,        # write to streaming fifo
    fifo_full,      # FIFO full
    fifo_empty,     # FIFO empty

    C_DSZ     = 8,      # Wishbone bus width
    C_ASZ     = 16,     # Wishbone address width
    C_WB_ADDR = 0x800   # Wishbone address
):
    """ FIFO Ramp module
    This module provides a simple 8-bit counter that will generate
    a ramp.  This ramp is fed to the USB fifo.  This can be used
    to validate the usb connection and the device to host (IN) data
    rates.
    """
    
    # Generate the register file and get the signals for the regfile.  The GenerateFunc
    # will create the rmp_register_file.
    rwRegisters, rwWr, rwRd, roRegisters, roRd = RF.GetRegisterFile(RegDef)
    CFG  = Signal(intbv(0)[RegDef['CFG']['width']:])  # rw configuration register
    
    FIFO_DSZ = 8
    enable = Signal(False)
    ramp  =  Signal(intbv(0)[FIFO_DSZ:])

    wb_acc  = Signal(False)
    wb_wr   = Signal(False)

    wcnt    = Signal(intbv(0)[10:])

    # Wishbone mapped registers
    regFile = rmp_RegisterFile(clk_i, rst_i, cyc_i, stb_i, adr_i, we_i,
                               sel_i, dat_i, dat_o, ack_o,
                               wb_wr, wb_acc,
                               rwRegisters, rwWr, rwRd, roRegisters, roRd,
                               C_WB_BASE_ADDR=C_WB_ADDR)

    @always_comb
    def rtl_reg_file_assignments():
        CFG.next = rwRegisters[0]

    @always_comb
    def rtl_bit_assignments():
        enable.next = CFG[0]
        
    @always(clk_i.posedge)
    def rtl_ramp():
        if not rst_i:
            ramp.next    = 0
            fifo_wr.next = False
            fifo_di.next = 0
            wcnt.next = 0x3FF
        else:
            if enable and not fifo_full:
                #if wcnt == 0 :
                fifo_wr.next = True
                fifo_di.next = ramp
                ramp.next    = (ramp + 1) % (2**FIFO_DSZ)
                #wcnt.next = 0x3FF
                #else:
                #    fifo_wr.next = False
                #    wcnt.next = wcnt - 1
            else:
                fifo_wr.next = False
                fifo_di.next = 0
                #wcnt.next = 0x3FF
    
    return instances()
