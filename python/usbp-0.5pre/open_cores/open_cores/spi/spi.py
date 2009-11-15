#
#  Simple SPI interface
#
#  This module is controlled / configured from the wishbone bus.
#  data can either be transferred from the wishbone bus or
#  it can be transferred from the streaming interface.
#
#  This module is register compatible with the Xilinx OPB SPI
#  controller.  The interrupt register has been removed and replaced
#  with a clock divide register.

"""
"""

from myhdl import *
from open_cores.fifo import fast_fifo

from spi_register_def  import *
from spi_register_file import *

def spi(
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
    
    # --[ External SPI Interface ]--
    SS,             # SPI chip enable
    SCK,            # SPI clock
    MOSI,           # SPI master out slave in
    MISO,           # SPI master in slave out

    # --[ Module Parameters ]--
    C_DSZ           = 8,      # Wishbone Bus width
    C_ASZ           = 16,     # Wishbone Address width
    C_INCLUDE_FIFO  = True ,  # 8 byte deep FIFO present
    C_WB_ADDR       = 0x0400  # Wishbone base address
    ):
    """ SPI (Serial Peripheral Interface) module

      This is an implementation of a SPI controller that is wishbone
      enabled.  The control registers have common SPI names and are
      similar to the registers in the Xilinx OCB SPI controller.

    """
    
    # Local aliases to the register file
    rwRegisters, rwWr, rwRd, roRegisters, roRd = RF.GetRegisterFile(RegDef)
    SPCR  = Signal(intbv(0)[RegDef['SPCR']['width']:])  # rw register
    SPSR  = Signal(intbv(0)[RegDef['SPSR']['width']:])  # ro register
    SPTX  = Signal(intbv(0)[RegDef['SPTX']['width']:])  # wt register
    SPRX  = Signal(intbv(0)[RegDef['SPRX']['width']:])  # ro register also need the address for this register
    SPSS  = Signal(intbv(0)[RegDef['SPSS']['width']:])  # rw register 
    SPTC  = Signal(intbv(0)[RegDef['SPTC']['width']:])  # ro register
    SPRC  = Signal(intbv(0)[RegDef['SPRC']['width']:])  # ro register
    SPXX  = Signal(intbv(0)[RegDef['SPXX']['width']:])  # rw register

    print '**** ', len(SPTX), len(rwRegisters[1])
    
    wb_acc  = Signal(False)
    wb_wr   = Signal(False)
    reset   = Signal(False)

    # control signal aliases
    cr_loop    = Signal(False)  # Internal loopback, MISO = MOSI
    cr_spe     = Signal(False)  # Controller (system) enable
    cr_cpol    = Signal(False)  # Clock polarity
    cr_cpha    = Signal(False)  # Clock phase
    cr_txrst   = Signal(False)  # Reset the Transmit FIFO
    cr_rxrst   = Signal(False)  # Reset the Receive FIFO
    cr_msse    = Signal(False)  # Manual slave select. SS will reflect this register
    cr_freeze  = Signal(False)  # Freeze (stop) controller
    cr_wb_sel  = Signal(False)  # Select wishbone RX/TX or streaming FIFO
    
    # Addition status signals
    modf       = Signal(False)  # Set if the SS signal goes active (low) i.e. driven by something else
                                
    # Wishbone data transfer FIFOS
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
    
    ena    = Signal(False)
    clkcnt = Signal(intbv(0, min=0, max=2**12))
    bcnt   = Signal(intbv(0, min=0, max=8))
    treg   = Signal(intbv(0)[8:])
    
    _sck   = Signal(False)
    _ss    = Signal(False)
    _miso  = Signal(False)
    
    # I like the MyHDL model for creating state machines but many synthesis tools
    # don't support mixed assignments (block, non-blocking) for Verilog.
    S_IDLE       = 0
    S_SCK_PHASE1 = 1
    S_SCK_PHASE2 = 3
    S_UNUSED     = 2
    state  = Signal(intbv(0, min=0, max=4))

    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # Wishbone mapped registers
    regFile = spi_RegisterFile(clk_i, rst_i, cyc_i, stb_i, adr_i, we_i,
                               sel_i, dat_i, dat_o, ack_o,
                               wb_wr, wb_acc,
                               rwRegisters, rwWr, rwRd, roRegisters, roRd,
                               C_WB_BASE_ADDR=C_WB_ADDR)
 

    # FIFO for the wishbone data transfer
    if C_INCLUDE_FIFO:
        rxFifo = fast_fifo(reset, clk_i, cr_rxrst,
                           rx_fifo_wr, rx_fifo_rd,
                           rx_fifo_full, rx_fifo_empty,
                           rx_fifo_di, rx_fifo_do,
                           C_DSZ=8, C_ASZ=3)
        
        txFifo = fast_fifo(reset, clk_i, cr_txrst,
                           tx_fifo_wr, tx_fifo_rd,
                           tx_fifo_full, tx_fifo_empty,
                           tx_fifo_di, tx_fifo_do, 
                           C_DSZ=8, C_ASZ=3)


    # local aliases these will not generate logic / hardware
    #  will generate continuous assignments.
    # @todo some method to assert correct assignment ??.  Don't like
    #       the following too much, need to know the order of the register
    #       creation.  Need to think about this a some more!
    @always_comb
    def rtl_reg_file_assignments():
        # rw registers
        SPCR.next = rwRegisters[0]
        SPTX.next = rwRegisters[1]
        SPSS.next = rwRegisters[2]
        SPXX.next = rwRegisters[3]

        # ro registers
        roRegisters[0].next = SPSR
        roRegisters[1].next = SPRX
        roRegisters[2].next = SPTC
        roRegisters[3].next = SPRC
        #SPSR.next = roRegisters[0]
        #SPRX.next = roRegisters[1]
        #SPTC.next = roRegisters[2]
        #SPRC.next = roRegisters[3]


    # local aliases bits of the registers
    @always_comb
    def rtl_bit_assignments():
        cr_loop.next   = SPCR[0]
        cr_spe.next    = SPCR[1]
        cr_cpol.next   = SPCR[3]
        cr_cpha.next   = SPCR[4]
        cr_txrst.next  = SPCR[5]
        cr_rxrst.next  = SPCR[6]
        cr_msse.next   = SPCR[7]
        #cr_freeze.next = SPCR[8]
        #cr_wb_sel.next = SPCR[9]

        #print SPSR, type(SPSR)
        SPSR.next[0]   = rx_fifo_empty
        SPSR.next[1]   = rx_fifo_full
        SPSR.next[2]   = tx_fifo_empty
        SPSR.next[3]   = tx_fifo_full
        SPSR.next[4]   = False


    @always_comb
    def rtl_assignment():
        reset.next  = not rst_i
        
        if clkcnt > 0:
            ena.next = False
        else:
            ena.next = True

        
    @always(clk_i.posedge)
    def rtl_clk_div():
        if cr_spe and clkcnt != 0 and state != 0:
            clkcnt.next = (clkcnt - 1) % 2**12
        else:
            if   SPXX == 0:   clkcnt.next = 0    # 2
            elif SPXX == 1:   clkcnt.next = 1    # 4
            elif SPXX == 2:   clkcnt.next = 3    # 8
            elif SPXX == 3:   clkcnt.next = 7    # 16
            elif SPXX == 4:   clkcnt.next = 15   # 32 
            elif SPXX == 5:   clkcnt.next = 31   # 64
            elif SPXX == 6:   clkcnt.next = 63   # 128
            elif SPXX == 7:   clkcnt.next = 127  # 256
            elif SPXX == 8:   clkcnt.next = 255  # 512
            elif SPXX == 9:   clkcnt.next = 511  # 1024
            elif SPXX == 10:  clkcnt.next = 1023 # 2048
            elif SPXX == 11:  clkcnt.next = 2047 # 4096


    @always(clk_i.posedge)
    def rtl_state_and_more():
        if not cr_spe:
            state.next = 0
            bcnt.next  = 0
            treg.next  = 0
            
            _fifo_rd.next  = False
            _fifo_wr.next  = False

            _sck.next = False
            _ss.next  = False
        elif not cr_freeze:
            # Idle state
            if state == S_IDLE:
                bcnt.next = 7
                treg.next = _fifo_do
                _sck.next = cr_cpol
                _ss.next  = True

                if not _fifo_empty and not _fifo_full:
                    _fifo_rd.next = True
                    state.next = 1
                    _ss.next = False
                    if cr_cpha:
                        _sck.next = not _sck
                        
            # Clock phase 1 state
            if state == S_SCK_PHASE1:
                if ena:
                    state.next = S_SCK_PHASE2
                    _sck.next  = not _sck

            # Clock phase 2 state
            if state == S_SCK_PHASE2:
                if ena:
                    treg.next = concat(_miso, treg[8:1])
                    bcnt.next = bcnt - 1

                if bcnt == 0:
                    state.next = S_IDLE
                    _sck.next  = cr_cpol
                    _ss.next   = True
                    _fifo_wr.next = True
                else:
                    state.next = S_SCK_PHASE1
                    _sck.next  = not _sck

            # unused state
            if state == S_UNUSED:
                state.next = S_IDLE

    @always_comb
    def rtl_fifo_sigs():
        tx_fifo_di.next = SPTX
        SPRX.next       = rx_fifo_do
        
    @always_comb
    def rtl_fifo_sel():
        if cr_wb_sel:
            _fifo_empty.next = tx_fifo_empty
            _fifo_full.next  = rx_fifo_full
            _fifo_do.next    = tx_fifo_do
            
            tx_fifo_rd.next = _fifo_rd
            rx_fifo_wr.next = _fifo_wr            
            rx_fifo_di.next = treg
            tx_fifo_wr.next = rwWr[1] 
            rx_fifo_rd.next = roRd[1]            
            
            fifo_rd.next    = False
            fifo_wr.next    = False
            fifo_di.next    = 0  # or'd bus must be 0
        else:
            _fifo_empty.next = fifo_empty
            _fifo_full.next  = fifo_full
            _fifo_do.next    = fifo_do
            
            tx_fifo_rd.next = False
            rx_fifo_wr.next = False
            rx_fifo_di.next = 0 # or'd bus must be 0
            tx_fifo_wr.next = False
            rx_fifo_rd.next = False


            fifo_rd.next    = _fifo_rd
            fifo_wr.next    = _fifo_wr
            fifo_di.next    = treg
            
    @always_comb
    def rtl_spi_sigs():
        SCK.next   = _sck

        if cr_loop:
            MOSI.next  = False
            _miso_next = treg[0]
        else:
            MOSI.next  = treg[0]
            _miso.next = MISO

        if cr_msse:
            SS.next = ~SPSS
        else:
            if _ss:
                SS.next = 0xFF
            else:
                SS.next = ~SPSS

                
    return instances()
