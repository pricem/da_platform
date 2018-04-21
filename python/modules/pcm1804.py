
from modules.base import ModuleBase

class PCM1804Module(ModuleBase):
    #   Use set_acon and get_aovf functions defined in ModuleBase
    """ FPGA's ACON output defaults to 0x51 = 7'b1010001:
        [6] HPFD = 1 (highpass filter disabled)
        [5:3] FS = 010 (single rate with system clock of 384 Fs--what? should probably be 256, or 011)
        [2] S/M = 0 (Master mode)
        [1:0] FMT = 01 (I2S format)
        Note: 1011001 = 0x59 which it should probably be?
        
        4 options for samplerate:
        000 : 1000001 = 41
        001 : 1001001 = 49
        010:  1010001 = 51
        011:  1011001 = 59
    """ 
    
    
    
    pass

