from myhdl import *
import os

def tracking_fifo(clk_in, data_in, write_in, clk_out, data_out, read_out, addr_in, addr_out, reset):
    module_name = 'tracking_fifo'
    dependencies = [module_name, 'dut_' + module_name, 'bram_2k_8']
    cmd = "iverilog -o %s " % module_name + " ".join(["%s.v" % d for d in dependencies])
    os.system(cmd)
    return Cosimulation("vvp -m ../myhdl.vpi %s" % module_name, clk_in=clk_in, data_in=data_in, write_in=write_in, clk_out=clk_out, data_out=data_out, read_out=read_out, addr_in=addr_in, addr_out=addr_out, reset=reset)



