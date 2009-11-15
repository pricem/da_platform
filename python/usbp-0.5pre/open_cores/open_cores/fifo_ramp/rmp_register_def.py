

from myhdl import *
import open_cores.register_file as RF

RegDef = RF.odict()

RegDef["CFG"] = {"addr" : 0x00, "width" : 8, "type" : "rw",
                 "bits" : {"en" : {"b" : 0, "width" : 1, "comment" : "Enable the fifo ramp to feed the USB fifo"}
                           },
                 "default" : 0,
                 "comment" : "Fifo ramp configuration register"
                 }
