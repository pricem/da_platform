

from myhdl import *
import open_cores.register_file as RF

RegDef = RF.odict()

# Register 0
RegDef["REG0"] = {"addr" : 0x0068, "width" : 8, "type" : "rw",
                  "bits" : {"enable" : {"comment" : "Bit 0 definition"},
                            "loop"   : {"comment" : "Bit 1 definition"},
                            },
                  "default" : 0x55,
                  "comment" : "Register 0",
                  }

# Register 1
RegDef["REG1"] = {"addr" : 0x1020, "width" : 2, "type" : "ro",
                  "bits" : {"enable" : {"comment" : "Bit 0 definition"},
                            "loop"   : {"comment" : "Bit 1 definition"},
                            },
                  "default" : 0xC3,
                  "comment" : "Register 1",
                  }

# Register 2
RegDef["REG2"] = {"addr" : 0x20, "width" : 9, "type" : "rw",
                  "bits" : {"enable" : {"comment" : "Bit 0 definition"},
                            "loop"   : {"comment" : "Bit 1 definition"},
                            },
                  "default" : 0x3C,
                  "comment" : "Register 2",
                  }

# Generate the read and write logic for the register file
rwRegisters, rwWr, rwRd, roRegisters, roRd = RF.GenerateFunc(RegDef, 'test')
