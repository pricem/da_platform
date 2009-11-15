
from myhdl import *
 
def fast_fifo(
    clk,        # sync clock
    reset,      # reset fifo
    clr,        # clear fifo
    we,         # write enable
    re,         # read enable
    full,       # FIFO full
    empty,      # FIFO empty
    di,         # data input
    do,         # data out

    C_DSZ = 8,  # Data word size
    C_ASZ = 3   # Size of the FIFO
    ):
    """ Small fast fifo
    """

    mem   = [Signal(intbv(0)[C_DSZ:]) for i in range(2**C_ASZ)]
    wp    = Signal(intbv(0, min=0, max=2**C_ASZ))
    wp_p1 = Signal(intbv(0, min=0, max=2**C_ASZ))
    rp    = Signal(intbv(0, min=0, max=2**C_ASZ))
    rp_p1 = Signal(intbv(0, min=0, max=2**C_ASZ))
    gb    = Signal(False)

    @always(clk.posedge)
    def rtl_wp_reg():
        if reset:
            wp.next = 0
        else:
            if clr:
                wp.next = 0
            else:
                wp.next = wp_p1

    @always_comb
    def rtl_wp():
        wp_p1.next = (wp + 1) % 2**C_ASZ

    @always(clk.posedge)
    def rtl_rp_reg():
        if reset:
            rp.next = 0
        else:
            if clr:
                rp.next = 0
            elif re:
                rp.next = rp_p1

    @always_comb
    def rtl_rp():
        rp_p1.next = (rp + 1) % 2**C_ASZ

    @always_comb
    def rtl_mem_output():
        do.next = mem[int(rp)]

    @always(clk.posedge)
    def rtl_mem():
        if we:
            mem[wp].next = di

    @always_comb
    def rtl_assignments():

        if wp == rp and not gb:
            empty.next = True
        else:
            empty.next = False

        if wp == rp and gb:
            full.next = True
        else:
            full.next = False

    @always(clk.posedge)
    def rtl_guard_bit():
        if reset:
            gb.next = False
        else:
            if clr:
                gb.next = False
            elif wp_p1 == rp and we:
                gb.next = True
            elif re:
                gb.next = False

    return instances()

                
    
    
