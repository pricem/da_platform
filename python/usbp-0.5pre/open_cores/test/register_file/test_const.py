


def test_const(clk, addr, do):


    ADDR = tuple(8, 4, 6, 0)
    DO   = tuple(0xDE, 0xCA, 0xFB, 0xAD)
    
    @always(clk.posedge)
    def rtl():
        
