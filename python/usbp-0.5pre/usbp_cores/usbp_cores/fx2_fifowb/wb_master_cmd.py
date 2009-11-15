
from myhdl import *

# My implementation with enums currently broken, requires modified
# version.
S_BYTE0  = 0
S_BYTE1  = 1
S_CMD    = 2
S_ADDRH  = 3
S_ADDRL  = 4
S_LEN    = 5
S_BYTE6  = 6
S_BYTE7  = 7
S_WB_BUS = 8

CMD_WRITE = 1
CMD_READ  = 2

def wb_master_cmd(
    clk,
    reset,
    fifo_do,
    fifo_do_vld,
    wb_go,
    wb_rd,
    wb_wr,
    wb_addr,
    wb_dat_o,
    wb_cmd_in_prog
    ):
    """Wishbone command packet decoder

    """

    wb_len   = Signal(intbv(0)[8:])
    wb_cnt   = Signal(intbv(0)[8:])
    wb_cmd   = Signal(intbv(0)[8:])
    sbyte0   = Signal(intbv(0)[8:])
    sbyte1   = Signal(intbv(0)[8:])
    sbyte6   = Signal(intbv(0)[8:])
    sbyte7   = Signal(intbv(0)[8:])

    wb_iaddr = Signal(intbv(0)[16:])
    wb_idat  = Signal(intbv(0)[8:])
    reg_sel  = Signal(intbv(0)[4:])


    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # Misc Registers
    addr_lo = Signal(intbv(0)[8:])
    addr_hi = Signal(intbv(0)[8:])
    
    @always(clk.posedge)
    def rtl_mregs():
        if reset:
            wb_len.next   = 1
            wb_cnt.next   = 0
            wb_cmd.next   = 0
            sbyte0.next   = 0
            sbyte1.next   = 0
            sbyte6.next   = 0
            sbyte7.next   = 0
            reg_sel.next  = S_BYTE0
            wb_idat.next  = 0
            addr_lo.next  = 0
            addr_hi.next  = 0
            wb_iaddr.next = 0
        else:

            if fifo_do_vld: #fifo_rd
                if reg_sel == S_BYTE0:
                    sbyte0.next = fifo_do
                elif reg_sel == S_BYTE1:
                    sbyte1.next = fifo_do
                elif reg_sel == S_CMD:
                    wb_cmd.next = fifo_do
                elif reg_sel == S_ADDRH:
                    addr_hi.next = fifo_do
                elif reg_sel == S_ADDRL:
                    addr_lo.next = fifo_do
                elif reg_sel == S_LEN:
                    # currently a bug with a simple always_comb
                    wb_iaddr.next = concat(addr_hi, addr_lo)
                    if fifo_do ==  0:
                        wb_len.next = 1
                    else:
                        wb_len.next = fifo_do
                elif reg_sel == S_BYTE6:
                    sbyte6.next = fifo_do
                elif reg_sel == S_BYTE7:
                    sbyte7.next = fifo_do
                elif reg_sel == S_WB_BUS:
                    wb_idat.next = fifo_do

                if reg_sel == S_WB_BUS:
                    if wb_cnt >= wb_len-1:
                        reg_sel.next = S_BYTE0
                        wb_cnt.next  = 0
                    else:
                        wb_cnt.next  = wb_cnt + 1
                else:
                    # Validate the command format
                    if reg_sel == S_BYTE0:
                        if fifo_do == 0xDE:
                            reg_sel.next = reg_sel + 1
                        else:
                            reg_sel.next = S_BYTE0

                    elif reg_sel == S_BYTE1:
                        if fifo_do == 0xCA:
                            reg_sel.next = reg_sel + 1
                        else:
                            reg_sel.next = S_BYTE0

                    elif reg_sel == S_CMD:
                        # Currently only 01 (write) or 02 (read) is implemented
                        if fifo_do > 0 and fifo_do < 3:
                            reg_sel.next = reg_sel + 1
                        else:
                            reg_sel.next = S_BYTE0

                    elif reg_sel == S_ADDRH or reg_sel == S_ADDRL:
                        reg_sel.next = reg_sel + 1

                    elif reg_sel == S_LEN:
                        reg_sel.next = reg_sel + 1

                    elif reg_sel == S_BYTE6:
                        if fifo_do == 0xFB:
                            reg_sel.next = reg_sel + 1
                        else:
                            reg_sel.next = S_BYTE0

                    elif reg_sel == S_BYTE7:
                        if fifo_do != 0xAD or (wb_cmd == CMD_READ and wb_len == 1):
                            reg_sel.next = S_BYTE0
                        else:
                            reg_sel.next = reg_sel + 1

                    # @todo The following converts with a $finish??  The
                    # XST synthesis no likey
                    #else:
                    #    raise AssertionError, "wb_master_cmd: Incorrect State"

            else: # if fifo_do_vld
                if wb_cnt >= wb_len and reg_sel > S_LEN:
                    reg_sel.next = S_BYTE0
                    wb_cnt.next  = 0


        
    @always_comb
    def rtl_addr():
        wb_addr.next  = wb_iaddr + wb_cnt

    @always_comb
    def rtl_data():
        # will fifo_do be hi fan out?? need to register?? then
        # write logic needs to change
        wb_dat_o.next = fifo_do #wb_idat


    @always_comb
    def rtl_go():
        if reg_sel >= S_BYTE7:
            wb_go.next = True
        else:
            wb_go.next = False

    @always_comb
    def rtl_control():
        
        if wb_cmd == CMD_WRITE and reg_sel >= S_WB_BUS:
            wb_wr.next = True
        else:
            wb_wr.next = False
        
        if wb_cmd == CMD_READ and reg_sel >= S_BYTE7:
            wb_rd.next = True
        else:
            wb_rd.next = False

        if reg_sel > S_BYTE0:
            wb_cmd_in_prog.next = True
        else:
            wb_cmd_in_prog.next = False

    return instances()
