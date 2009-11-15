

from myhdl import *

def fifo_mem_generic(
    clk,          # sync clock
    wr,           # Write strobe
    din,          # data in (write data)
    dout,         # data out (write data)
    addr_w,       # write address   
    addr_r,       # read address
    DSZ = 8,      # Data Size
    ASZ = 9       # Address Size
    ):
    """
    Timing Diagram:
    """
    mem = [Signal(intbv(0)[DSZ:]) for ii in range(2**ASZ)]
    #_addr_r = Signal(intbv(0)[ASZ:])
    _addr_w = Signal(intbv(0)[ASZ:])
    _din    = Signal(intbv(0)[DSZ:])
    _dout   = Signal(intbv(0)[DSZ:])
    _wr     = Signal(False)

    @always_comb
    def dout_rtl():
        dout.next = _dout
        
    @always(clk.posedge)
    def rd_rtl():
        _dout.next = mem[int(addr_r)]

    @always(clk.posedge)
    def wr_rtl():
        _wr.next     = wr
        _addr_w.next = addr_w
        _din.next    = din
        if _wr:
            mem[int(_addr_w)].next = _din

    return rd_rtl, wr_rtl, dout_rtl


# @todo if needed create fifo memory for different devices
# To directly instantiate a device specific memory use the
#  __verilog__ or __vhdl__ here instead.
# @todo example
#
# def fifo_mem_XS3
# def fifo_mem_XS3E
# def fifo_mem_CYC3
# ....

def convert():
    DSZ = 8
    ASZ = 9

    clk     = Signal(False)
    wr      = Signal(False)
    din     = Signal(intbv(0)[DSZ:])
    dout    = Signal(intbv(0)[DSZ:])
    addr_w  = Signal(intbv(0)[ASZ:])
    addr_r  = Signal(intbv(0)[ASZ:])

    toVerilog(fifo_mem_generic, clk, wr, din, dout, addr_w, addr_r)
    toVHDL(fifo_mem_generic, clk, wr, din, dout, addr_w, addr_r)

if __name__ == '__main__':
    convert()


