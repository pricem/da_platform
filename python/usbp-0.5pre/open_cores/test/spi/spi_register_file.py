from myhdl import *
def spi_RegisterFile(
        clk_i, rst_i, cyc_i, stb_i, adr_i, we_i,
        sel_i, dat_i, dat_o, ack_o,
        wb_wr, wb_acc, 
        rwRegisters, rwWr, rwRd, roRegisters, roRd):
    _wb_do  = Signal(intbv(0)[8:]) 
    _wb_sel = Signal(False) 
    _wb_acc = Signal(False) 
    _wb_wr  = Signal(False) 
    _wb_ack = Signal(False) 
    @always_comb
    def rtl_assignments1():
        _wb_acc.next = cyc_i & stb_i 
        ack_o.next   = _wb_ack
    @always_comb
    def rtl_assignments2():
        _wb_wr.next  = _wb_acc & we_i 
    @always_comb
    def rtl_assignments3():
        wb_wr.next  = _wb_wr 
        wb_acc.next = _wb_acc 
    @always(clk_i.posedge)
    def rtl_read_reg():
        if adr_i == 0x60:
            _wb_do.next = rwRegisters[0]

        elif adr_i == 0x68:
            _wb_do.next = rwRegisters[1]

        elif adr_i == 0x70:
            _wb_do.next = rwRegisters[2]

        elif adr_i == 0x7c:
            _wb_do.next = rwRegisters[3]

        if adr_i == 0x64:
            _wb_do.next = roRegisters[0]

        elif adr_i == 0x6c:
            _wb_do.next = roRegisters[1]

        elif adr_i == 0x74:
            _wb_do.next = roRegisters[2]

        elif adr_i == 0x78:
            _wb_do.next = roRegisters[3]

    @always(clk_i.posedge)
    def rtl_selected():
        if adr_i > 0x60 and adr_i < 0x7c:
            _wb_sel.next = True
        else:
            _wb_sel.next = False
    @always_comb
    def rtl_read():
        if _wb_sel:
            dat_o.next = _wb_do
        else:
            dat_o.next = 0
    @always(clk_i.posedge)
    def rtl_write_reg(): 
        if not rst_i:
            rwRegisters[0].next = 0x180 

            rwRegisters[1].next = 0x0 

            rwRegisters[2].next = 0x0 

            rwRegisters[3].next = 0x0 

        elif _wb_wr and _wb_sel: 
            if adr_i == 0x60:
                rwRegisters[0].next = dat_i 

            elif adr_i == 0x68:
                rwRegisters[1].next = dat_i 

            elif adr_i == 0x70:
                rwRegisters[2].next = dat_i 

            elif adr_i == 0x7c:
                rwRegisters[3].next = dat_i 

    @always(clk_i.posedge)
    def rtl_ack(): 
        if not rst_i:
            _wb_ack.next = False
        else:
            _wb_ack.next = _wb_acc & ~_wb_ack
    @always(clk_i.posedge)
    def rtl_rw_stobes(): 
        if adr_i == 0x60 and _wb_ack: 
            if _wb_wr: 
                rwWr[0].next = True 
                rwRd[0].next = False 
            else: 
                rwWr[0].next = False 
                rwRd[0].next = True 
        else: 
            rwWr[0].next = False 
            rwRd[0].next = False 
        if adr_i == 0x68 and _wb_ack: 
            if _wb_wr: 
                rwWr[1].next = True 
                rwRd[1].next = False 
            else: 
                rwWr[1].next = False 
                rwRd[1].next = True 
        else: 
            rwWr[1].next = False 
            rwRd[1].next = False 
        if adr_i == 0x70 and _wb_ack: 
            if _wb_wr: 
                rwWr[2].next = True 
                rwRd[2].next = False 
            else: 
                rwWr[2].next = False 
                rwRd[2].next = True 
        else: 
            rwWr[2].next = False 
            rwRd[2].next = False 
        if adr_i == 0x7c and _wb_ack: 
            if _wb_wr: 
                rwWr[3].next = True 
                rwRd[3].next = False 
            else: 
                rwWr[3].next = False 
                rwRd[3].next = True 
        else: 
            rwWr[3].next = False 
            rwRd[3].next = False 
    return instances()