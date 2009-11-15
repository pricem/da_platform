

from myhdl import *
from open_cores.spi import *

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

    fifo_di = Signal(intbv(0)[8:])
    fifo_do = Signal(intbv(0)[8:])
    fifo_do_vld = Signal(False)
    fifo_full   = Signal(False)
    fifo_empty  = Signal(False)
    fifo_rd     = Signal(False)
    fifo_wr     = Signal(False)

    SS    = Signal(intbv(0)[8:])
    SCK   = Signal(False)
    MOSI  = Signal(False)
    MISO  = Signal(False)
    

    if to == 'ver':
        toVerilog(spi, clk_i, rst_i, cyc_i, stb_i, adr_i, we_i, sel_i,
                  dat_i, dat_o, ack_o, fifo_di, fifo_do, fifo_do_vld,
                  fifo_rd, fifo_wr, fifo_full, fifo_empty, SS, SCK, MOSI, MISO)

    #spi(clk_i, rst_i, cyc_i, stb_i, adr_i, we_i, sel_i,
    #dat_i, dat_o, ack_o, fifo_di, fifo_do, fifo_do_vld,
    #fifo_rd, fifo_wr, fifo_full, fifo_empty, SS, SCK, MOSI, MISO)
    
if __name__ == '__main__':
    convert()
