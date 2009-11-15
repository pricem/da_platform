

from myhdl import *
import open_cores.register_file as RF

RegDef = RF.odict()

RegDef["CFG"] = {"addr" : 0x00, "width" : 8, "type" : "rw",
                 "bits" : {"en"  : {"b" : 0, "width" : 1, "comment" : "Enable the Audio CODEC to feed the USB fifo"},
                           "erl" : {"b" : 1, "width" : 1, "comment" : "Enable ramp on left channel"},
                           "err" : {"b" : 2, "width" : 1, "comment" : "Enable ramp on right channel"} 
                           },
                 "default" : 0,
                 "comment" : "PCM4220 CODEC Configuration Register"
                 }

RegDef["EXT"] = {"addr" : 0x01, "width" : 8, "type" : "rw",
                 "bits" : {"en4v"  : {"b" : 0, "width" : 1, "comment" : "Enable the 4.0V regulator on CODEC board"},
                           "nrst"  : {"b" : 7, "width" : 1, "comment" : "Active-low CODEC board reset"} 
                           },
                 "default" : 0,
                 "comment" : "External control for CODEC board"
                 }
