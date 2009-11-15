

from myhdl import *
import open_cores.register_file as RF

# This will create test_register_file.py
from test_register_def  import *
# generators for the register file
from test_register_file import *


def reg_gen(clk_i, rst_i, cyc_i, stb_i, adr_i, we_i, sel_i, dat_i, dat_o, ack_o):
    global rwRegisters, rwWr, rwRd, roRegisters, roRd
    wb_wr  = Signal(False)
    wb_acc = Signal(False) 
    regFile = test_RegisterFile(clk_i, rst_i, cyc_i, stb_i, adr_i, we_i,
                                sel_i, dat_i, dat_o, ack_o,
                                wb_wr, wb_acc,
                                rwRegisters, rwWr, rwRd, roRegisters, roRd)

    return instances()

def convert(to='ver'):
    clk_i  = Signal(False)
    rst_i  = Signal(False)
    cyc_i  = Signal(False)
    stb_i  = Signal(False)
    adr_i  = Signal(intbv(0)[16:])
    we_i   = Signal(False)
    sel_i  = Signal(False)
    dat_i  = Signal(intbv(0)[8:])
    dat_o  = Signal(intbv(0)[8:])
    ack_o  = Signal(False)

    if to == 'ver':
        toVerilog(reg_gen, clk_i, rst_i, cyc_i, stb_i, adr_i, we_i, sel_i,
                  dat_i, dat_o, ack_o)


if __name__ == '__main__':
    convert()
    
    

