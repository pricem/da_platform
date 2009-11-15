


from myhdl import *


#
# Very basic 8bit GPIO core derived from the open-cores simple_gpio.
#

def simple_gpio(
    clk_i,   # wishbone clock
    rst_i,   # wishbone reset
    cyc_i,   # cycle
    stb_i,   # strobe
    adr_i,   # address
    we_i,    # write enable
    dat_i,   # data input
    dat_o,   # data output
    ack_o,   # ack
    
    gpio_o,  # gpio output (driver)
    gpio_i,  # gpio input 
    gpio_t,  # gpio select

    C_IO_MASK  =  0x00,   # 1 == output only
    C_WB_ADDR  =  0x0100  # Wishbone base address
    ):
    """ Very basic 8bit GPIO core. 
      Registers:

        0x00: Control Register '1' == output
              bits 8:0 R/W Input/Output

        0x01: Line Register

        """

    
    ctrl   = Signal(intbv(0)[8:])
    line   = Signal(intbv(0)[8:])
    lgpio  = Signal(intbv(0)[8:])
    llgpio = Signal(intbv(0)[8:])

    _gpio_o  = Signal(intbv(0)[8:])
    _gpio_i  = Signal(intbv(0)[8:])
    _gpio_t  = Signal(intbv(0)[8:])
    mask     = Signal(intbv(0)[8:])

    wb_acc = Signal(False)
    wb_wr  = Signal(False)

    oType = type(gpio_o)
    iType = type(gpio_i)
    tType = type(gpio_t)
    
    @always_comb
    def rtl_assignments():
        wb_acc.next = cyc_i & stb_i        

    @always_comb
    def rtl_assignments2():
        wb_wr.next  = wb_acc & we_i
        mask.next   = C_IO_MASK


    @always(clk_i.posedge)
    def rtl_wishbone_registers():
        if not rst_i:
            ctrl.next = C_IO_MASK
            line.next = 0
        else:
            if wb_wr:
                if adr_i == C_WB_ADDR + 1:
                    line.next = dat_i
                elif adr_i == C_WB_ADDR:
                    ctrl.next = dat_i


    @always(clk_i.posedge)
    def rtl_wishbone_data_addr():
        if adr_i == C_WB_ADDR + 1:
            dat_o.next = llgpio
        elif adr_i == C_WB_ADDR:
            dat_o.next = ctrl
        else:
            dat_o.next = 0

    
    @always(clk_i.posedge)
    def rtl_wishbone_ack():
        if not rst_i:
            ack_o.next = False
        else:
            ack_o.next = wb_acc & ~ack_o


    @always(clk_i.posedge)
    def rtl_gpio_register_input():
        llgpio.next = lgpio

            
    @always_comb
    def rtl_gpio_select():
        for n in range(8):
            if ctrl[n] | mask[n]:
                lgpio.next[n]   = line[n]
                _gpio_o.next[n] = line[n]
                _gpio_t.next[n] = 0
            else:
                lgpio.next[n]   = _gpio_i[n]
                _gpio_o.next[n] = 0
                _gpio_t.next[n] = 1



    # Many cases only want outputs, that case the gpio_i port
    # can be set to None and the extra logic for inputs should
    # be removed
    if iType is not type(None):
        @always_comb
        def rtl_input_gen():
            _gpio_i.next = gpio_i

    if tType is not type(None):
        @always_comb
        def rtl_tristate_gen():
            gpio_t.next  = _gpio_t

    if oType is not type(None):
        @always_comb
        def rtl_output_gen():
            gpio_o.next = _gpio_o


    return instances()
