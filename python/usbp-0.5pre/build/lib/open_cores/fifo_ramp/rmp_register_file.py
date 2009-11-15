from myhdl import *
def rmp_RegisterFile(
        clk_i, rst_i, cyc_i, stb_i, adr_i, we_i,
        sel_i, dat_i, dat_o, ack_o,
        wb_wr, wb_acc, 
        rwRegisters, rwWr, rwRd, roRegisters, roRd,        C_WB_BASE_ADDR=0x0000):

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
        if adr_i == (0x0 + C_WB_BASE_ADDR):
            _wb_do.next = rwRegisters[0]

    @always(clk_i.posedge)
    def rtl_selected():
        if adr_i >= (0x0 + C_WB_BASE_ADDR) and adr_i <= (0x0 + C_WB_BASE_ADDR):
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
            rwRegisters[0].next = 0x0 

        elif _wb_wr and _wb_sel: 
            if adr_i == (0x0 + C_WB_BASE_ADDR):
                rwRegisters[0].next = dat_i 

    @always(clk_i.posedge)
    def rtl_ack(): 
        if not rst_i:
            _wb_ack.next = False
        else:
            _wb_ack.next = _wb_acc & ~_wb_ack

    @always(clk_i.posedge)
    def rtl_rw_stobes(): 
        if adr_i == (0x0 + C_WB_BASE_ADDR) and _wb_ack: 
            if _wb_wr: 
                rwWr[0].next = True 
                rwRd[0].next = False 
            else: 
                rwWr[0].next = False 
                rwRd[0].next = True 
        else: 
            rwWr[0].next = False 
            rwRd[0].next = False 

    return instances()
