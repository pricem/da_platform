#

"""
"""

from myhdl import *
from open_cores.fifo import fast_fifo

from twi_register_def import *
from twi_register_file import *

def twi(
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
    
    # --[ External TWI Interface ]--
    scl_pad_i,
    scl_pad_o,
    sda_pad_i,
    sda_pad_o,
    
    # --[ Module Parameters ]--
    C_DSZ           = 8,      # Wishbone Bus width
    C_ASZ           = 16,     # Wishbone Address width
    C_INCLUDE_FIFO  = True ,  # 8 byte deep FIFO present
    C_WB_ADDR       = 0x0600  # Wishbone base address
    ):
    """ TWI (Two Wire Interface) controller


    """

    rwRegisters, rwWr, rwRd, roRegisters, roRd = RF.GetRegisterFile(RegDef)
        
    # Local aliases to the register file
    PRERlo  = Signal(intbv(0)[RegDef['PRERlo']['width']:]) # rw register
    PRERhi  = Signal(intbv(0)[RegDef['PRERhi']['width']:]) # rw register
    CTR     = Signal(intbv(0)[RegDef['CTR']['width']:])    # rw register
    TXR     = Signal(intbv(0)[RegDef['TXR']['width']:])    # rw register
    RXR     = Signal(intbv(0)[RegDef['RXR']['width']:])    # rw register
    CR      = Signal(intbv(0)[RegDef['CR']['width']:])     # rw register
    SR      = Signal(intbv(0)[RegDef['SR']['width']:])     # rw register

    wb_acc  = Signal(False)
    wb_wr   = Signal(False)
    reset   = Signal(False)

    # Control register signals
    ctr_en     = Signal(False)
    ctr_me     = Signal(False)
    ctr_wb_sel = Signal(False)
    ctr_rxrst  = Signal(False)
    ctr_txrst  = Signal(False)
    
    # Command register signals
    cmd_sta    = Signal(False)
    cmd_sto    = Signal(False)
    cmd_rd     = Signal(False)
    cmd_wr     = Signal(False)
    cmd_ack    = Signal(False)

    # Status register
    sts_rxack  = Signal(False)
    sts_busy   = Signal(False)
    sts_al     = Signal(False)    
    sts_tip    = Signal(False)
    sts_if     = Signal(False)
    
    # Wishbone data transfer 
    rx_reset       = Signal(False)
    rx_fifo_wr     = Signal(False)
    rx_fifo_rd     = Signal(False)
    rx_fifo_full   = Signal(False)
    rx_fifo_empty  = Signal(False)
    rx_fifo_di     = Signal(intbv(0)[8:])
    rx_fifo_do     = Signal(intbv(0)[8:])

    tx_reset       = Signal(False)
    tx_fifo_wr     = Signal(False)
    tx_fifo_rd     = Signal(False)
    tx_fifo_full   = Signal(False)
    tx_fifo_empty  = Signal(False)
    tx_fifo_di     = Signal(intbv(0)[8:])
    tx_fifo_do     = Signal(intbv(0)[8:])

    _fifo_rd    = Signal(False)
    _fifo_wr    = Signal(False)
    _fifo_full  = Signal(False)
    _fifo_empty = Signal(False)
    _fifo_di    = Signal(intbv(0)[8:])
    _fifo_do    = Signal(intbv(0)[8:])
    
    # TWI states
    S_IDLE   = 0
    S_START  = 1
    S_READ   = 2
    S_WRITE  = 3
    S_ACK    = 4
    S_STOP   = 5
    state = Signal(intbv(0, min=0, max=6))

    core_cmd  = Signal(intbv(0)[4:])
    core_txd  = Signal(False)
    core_ack  = Signal(False)
    core_rxd  = Signal(False)

    sr        = Signal(intbv(0)[8:])
    shift     = Signal(False)
    ld        = Signal(False)
    go        = Signal(False)
    dcnt      = Signal(intbv(0, min=0, max=8))
    cnt_done  = Signal(False)
    
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # Wishbone mapped registers
    regFile = twi_RegisterFile(clk_i, rst_i, cyc_i, stb_i, adr_i, we_i,
                               sel_i, dat_i, dat_o, ack_o,
                               wb_wr, wb_acc,
                               rwRegisters, rwWr, rwRd, roRegisters, roRd,
                               C_WB_BASE_ADDR=C_WB_ADDR)
 

    # FIFO for the wishbone data transfer
    if C_INCLUDE_FIFO:
        rxFifo = fast_fifo(reset, clk_i, ctr_rxrst,
                           rx_fifo_wr, rx_fifo_rd,
                           rx_fifo_full, rx_fifo_empty,
                           rx_fifo_di, rx_fifo_do,
                           C_DSZ=8, C_ASZ=3)
        
        txFifo = fast_fifo(reset, clk_i, ctr_txrst,
                           tx_fifo_wr, tx_fifo_rd,
                           tx_fifo_full, tx_fifo_empty,
                           tx_fifo_di, tx_fifo_do, 
                           C_DSZ=8, C_ASZ=3)


    # Assign command signal from command register
    # @todo need a method to do this automatically or cross check
    #       with the register definition
    @always_comb
    def rtl_reg_assigments1():
        PRERhi.next = rwRegisters[0]
        PRERlo.next = rwRegisters[1]
        CTR.next    = rwRegisters[2]
        TXR.next    = rwRegisters[3]
        CR.next     = rwRegisters[4]

        roRegisters[0].next = RXR
        roRegisters[1].next = SR

    @always_comb
    def rtl_sig_assignments1():
        ctr_rxrst.next = CTR[3]
        ctr_txrst.next = CTR[4]
        
    return instances()
