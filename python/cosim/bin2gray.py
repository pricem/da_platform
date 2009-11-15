
from myhdl import *
import os

def bin2gray(B, G, width):
    """ Gray encoder.
    B -- input intbv signal, binary encoded
    G -- output intbv signal, gray encoded
    width -- bit width
    """
    @always_comb
    def logic():
        for i in range(width):
            G.next[i] = B[i+1] ^ B[i]
    
    return logic
    
cmd = "iverilog -o bin2gray -Dwidth=%s bin2gray.v dut_bin2gray.v"
def bin2gray_verilog(B, G, width):
    os.system(cmd % width)
    return Cosimulation("vvp -m ./myhdl.vpi bin2gray", B=B, G=G)
