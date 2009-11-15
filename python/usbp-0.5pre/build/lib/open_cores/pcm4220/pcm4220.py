
from myhdl import *
from pcm4220_register_def  import *
from pcm4220_register_file import *
from pcm4220_s2p import *

def pcm4220(
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

    # --[ ADC 4420 Interface ]--
    SCLK,
    SDATA,
    LR,

    # --[ External Control Signals ]--
    NRST,           # CODEC board reset signal
    EN4V,           # Enable 4V regulator on CODEC board

    # --[ Parameters ]--
    C_DSZ      = 8,
    C_ASZ      = 16,
    C_WB_ADDR  = 0x1000
    ):
    """ Simple inteface to an external ADC
    """

    # Generate the register file and local aliases.
    rwRegisters, rwWr, rwRd, roRegisters, roRd = RF.GetRegisterFile(RegDef)
    CFG  = Signal(intbv(0)[RegDef['CFG']['width']:])  # rw configuration register
    EXT  = Signal(intbv(0)[RegDef['EXT']['width']:])  # rw external control register

    index      =  Signal(intbv(0)[5:])
    adc_data   =  Signal(intbv(0)[8:])
    adc_buf    =  [Signal(intbv(0)[8:]) for ii in range(6)]
    ChanL      =  Signal(intbv(0)[24:])
    ChanR      =  Signal(intbv(0)[24:])    

    enable     =  Signal(False)
    rmpLch     =  Signal(False)
    rmpRch     =  Signal(False)
    rmpChanL   =  Signal(intbv(0)[24:])
    rmpChanR   =  Signal(intbv(0)[24:])    
    
    sSCLK      =  Signal(False)
    sSDATA     =  Signal(False)
    sLR        =  Signal(False)
    __SCLK     =  Signal(False)
    __SDATA    =  Signal(False)
    __LR       =  Signal(False)
    
    _lr        =  Signal(False)    # Delayed LR    
    reset      =  Signal(False)
    
    @always_comb
    def rtl_reg_file_assignments():
        CFG.next = rwRegisters[0]
        EXT.next = rwRegisters[1]

    @always_comb
    def rtl_bit_assignments():
        enable.next  = CFG[0]
        rmpLch.next  = CFG[1]
        rmpRch.next  = CFG[2]

        EN4V.next    = EXT[0]
        NRST.next    = EXT[7]
        
        reset.next  = ~rst_i

        fifo_rd.next = False
        
    @always_comb
    def rtl_enable():
        if enable:
            fifo_di.next = adc_data
        else:
            fifo_di.next = 0

    @always(clk_i.posedge)
    def rtl_format_data():

        if rmpLch:
            rmpChanL.next = (rmpChanL + 1) % 2**24
            adc_buf[0].next = rmpChanL[8:0]
            adc_buf[1].next = rmpChanL[16:8]
            adc_buf[2].next = rmpChanL[24:16]
        else:
            adc_buf[0].next = ChanL[8:0]
            adc_buf[1].next = ChanL[16:8]
            adc_buf[2].next = ChanL[24:16]


        if rmpRch:
            rmpChanR.next = (rmpChanR + 1) % 2**24
            adc_buf[3].next = rmpChanR[8:0]
            adc_buf[4].next = rmpChanR[16:8]
            adc_buf[5].next = rmpChanR[24:16]
        else:
            adc_buf[3].next = ChanR[8:0]
            adc_buf[4].next = ChanR[16:8]
            adc_buf[5].next = ChanR[24:16]



    # Serial to parallel for this ADC
    pcm4220 = pcm4220_s2p(clk_i, reset, sSCLK, sSDATA, ChanL, ChanR, LR)
    
    @always(clk_i.posedge)
    def rtl_get_data():
        if reset:
            index.next     = 0
            fifo_wr.next   = False
            _lr.next       = sLR
        else:
            if enable:
                _lr.next = sLR
                if _lr:
                    index.next = 0
                    fifo_wr.next = False
                elif index < 6:
                    index.next    = index + 1
                    fifo_wr.next  = True
                else:
                    fifo_wr.next = False

            else:
                fifo_wr.next = False

    @always_comb
    def rtl_data_sel():
        adc_data.next = adc_buf[(int(index))]

    @always(clk_i.posedge)
    def rtl_syncro():
        __SCLK.next  = SCLK
        __SDATA.next = SDATA
        __LR.next    = LR

        sSCLK.next   = __SCLK
        sSDATA.next  = __SDATA
        sLR.next     = __LR


    return instances()
