
from myhdl import *

def pcm4220_s2p(
    clk,
    reset,

    # ADC Signals
    SCLK,
    SDATA,
    ChanL,
    ChanR,
    LR,

    # Wishbone Interface
    ):

    _sclk    = Signal(False)
    _lr      = Signal(False)
    neg_sclk = Signal(False)
    pos_sclk = Signal(False)
    neg_lr   = Signal(False)
    pos_lr   = Signal(False)
    
    tmpL   = Signal(intbv(0)[24:])
    tmpR   = Signal(intbv(0)[24:])
    BitCnt = Signal(intbv(0)[6:])


    @always(clk.posedge)
    def rtl_sck_delay():
        _sclk.next = SCLK
        _lr.next   = LR

    @always_comb
    def rtl_sclk_edges():
        neg_sclk.next = ~SCLK & _sclk
        pos_sclk.next = SCLK & ~_sclk
        neg_lr.next   = ~LR & _lr
        pos_lr.next   = LR & ~_lr

    
    
    @always(clk.posedge)
    def rtl_data():
        if reset:
            ChanL.next  = 0
            ChanR.next  = 0
            tmpL.next   = 0
            tmpR.next   = 0
            BitCnt.next = 0

        else:
            if neg_sclk:
                if BitCnt < 24:
                    BitCnt.next = BitCnt + 1
                    if LR:
                        tmpL.next = concat(tmpL[23:0],SDATA)
                    if not LR:
                        tmpR.next = concat(tmpL[23:0],SDATA)

                if pos_lr:
                    ChanR.next  = tmpR
                    BitCnt.next = 0
                    tmpL.next   = 0

                if neg_lr:
                    ChanL.next  = tmpL
                    BitCnt.next = 0
                    tmpR.next   = 0


    return instances()
