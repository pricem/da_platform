

from myhdl import *
import open_cores.register_file as RF


RegDef = RF.odict()

RegDef["PRERlo"] = {"addr"    : 0x00, "width" : 8, "type" : "rw",
                    "bits"    : None,
                    "default" : 0,
                    "comment" : " Clock prescale register lo-byte"
                    }

RegDef["PRERhi"] = {"addr"    : 0x01, "width" : 8, "type" : "rw",
                    "bits"    : None,
                    "default" : 0,
                    "comment" : " Clock prescale register hi-byte"
                    }

RegDef["CTR"]    = {"addr"    : 0x02, "width" : 8, "type" : "rw",
                    "bits"    : {"en"      : {"b" : 7, "width" : 1, "comment" : "Enable core"} ,
                                 "me"      : {"b" : 6, "width" : 1, "comment" : "Master enable core 1=master, 0=slave"} ,
                                 "wb_sel"  : {"b" : 5, "width" : 1, "comment" : "Wishbone regsiters transferred or streaming"} ,
                                 },
                    "default" : 0,
                    "comment" : "Control register"
                    }


RegDef["TXR"]    = {"addr"    : 0x03, "width" : 8, "type" : "wt",
                    "bits"    : None,
                    "default" : 0,
                    "comment" : "Transmit register"
                    }

RegDef["RXR"]    = {"addr"    : 0x04, "width" : 8, "type" : "ro",
                    "bits"    : None,
                    "default" : 0,
                    "comment" : "Recieve register"
                    }

RegDef["CR"]     = {"addr"    : 0x05, "width" : 8, "type" : "rw",
                    "bits"    : { "sta" : {"b" : 7, "width" : 1, "comment" : "generate start condition"},
                                  "sto" : {"b" : 6, "width" : 1, "comment" : "generate stop condition"},
                                  "rd"  : {"b" : 5, "width" : 1, "comment" : "read from slave"},
                                  "wr"  : {"b" : 4, "width" : 1, "comment" : "write to slave"},
                                  "ack" : {"b" : 3, "width" : 1, "comment" : "ack when a receiver, sent ACK=1 or NACK=0"},
                                  },
                    "default" : 0,
                    "comment" : "Command register"
                    }

RegDef["SR"]     = {"addr"    : 0x06, "width" : 8, "type" : "ro",
                    "bits"    : { "rxack" : {"b" : 7, "width" : 1, "comment" : "received acknowledge from slave,"},
                                  "busy"  : {"b" : 6, "width" : 1, "comment" : "twi bus busy, set True after start detected, False once Stop detected"},
                                  "al"    : {"b" : 5, "width" : 1, "comment" : "Arbitration lost"},
                                  "tip"   : {"b" : 1, "width" : 1, "comment" : "transfer in progress"},
                                  "if"    : {"b" : 0, "width" : 1, "comment" : "interrup flag, interrupt pending"},
                                  },
                    "default" : 0,
                    "comment" : "Status register"
                    }



