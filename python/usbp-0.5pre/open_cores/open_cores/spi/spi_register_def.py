
from myhdl import *
import open_cores.register_file as RF

"""
      Registers are on 32bit boundaries are are big-edian.  Meaning
      the most significant byte is byte 0.  Example the first register
      byte addresses are:
        LSB 3 byte == address 0x63
            2 byte == address 0x62
            1 byte == address 0x61
        MSB 0 byte == address 0x60

      Registers: (Base address +)
        0x60: SPCR control register
             Loop ------------------------------------------------+
             SPE System Enable ---------------------------------+ |
             CPOL Clock Polarity ---------------------------+   | |
             CPHA Clock Phase ----------------------------+ |   | | 
             Tx FIFO Reset -----------------------------+ | |   | |
             Rx FIFO Reset ---------------------------+ | | |   | |
             Manual Slave Select Enable ------------+ | | | |   | |             
             Freeze ------------------------------+ | | | | |   | |
             Select streaming (1) or wb --------+ | | | | | |   | |
                                                | | | | | | |   | |
                                                9 8 7 6 5 4 3 2 1 0
        0x64: SPSR status register
                                                  8 7 6 5 4 3 2 1 0
        0x68: SPTX transmit register
                                                  8 7 6 5 4 3 2 1 0
        0x6C: SPRX receive register
        0x70: SPSS slave select register
        0x74: SPTC transmit fifo count
        0x78: SPRC receive fifo count
        0x7C: SPXX SCK clock divisor (divides wb clk_i)
            0  -- 2 divisor 24 MHz (usbp == 48MHz system clock)
"""

## !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
## @todo The current "list of signals" (LOS)  is limiting (BOMK) because
##       it wants to default a "list of signals" to a memory structure (blah)
##       so it tries and enforce rules that would apply to a memory, like same
##       bitwidth etc.  I would prefer a more general handling of a "list of signals"
##       and a memory is a subset of the LOS usage.  I don't know if it is possible
##       to determine a memory is desired.
## !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

#   Internal Register Definition
#          NAME  addr width type (rw, ro, wt) default comment
RegDef = RF.odict()


# SPI Control Register
RegDef["SPCR"] = {"addr" : 0x60, "width" : 8, "type" : "rw",
                  "bits" : {"loop"   : {"b" : 0, "width" : 1, "comment" : "Internal loopback"} ,
                            "spe"    : {"b" : 1, "width" : 1, "comment" : "System enable"} ,
                            "cpol"   : {"b" : 3, "width" : 1, "comment" : "Clock Polarity"} ,
                            "cpha"   : {"b" : 4, "width" : 1, "comment" : "Clock Phase"} ,
                            "msse"   : {"b" : 5, "width" : 1, "comment" : "Manual slave select enable"},
                            "freeze" : {"b" : 6, "width" : 1, "comment" : "freeze the core"},
                            "wb_sel" : {"b" : 7, "width" : 1, "comment" : "1 = wishbone bus feeds the TX/RX fifo.  Else the streaming iterface supplies the FIFOs"},
                            },
                  "default" : 0x80,
                  "comment" : "SPI Control register"
                  }

# @todo need a home for the following control signals they should go in the control register
#       but see the @todo comment top of this file.
#  "tx_rst" : {"b" : 8,  "width" : 1, "comment" : "TX FIFO reset"} ,
#  "rx_rst" : {"b" : 9,  "width" : 1, "comment" : "RX FIFO reset"} ,
#  "msbf"   : {"b" : 10, "width" : 1, "comment" : "msb first in time (first out) or lsb first in time"},

# SPI Status Register
RegDef["SPSR"] = {"addr" : 0x64, "width" : 8, "type" : "ro",
                  "bits" : {"rxe"  : {"b" : 0, "width" : 1, "comment" : "RX FIFO empty"} ,
                            "rxf"  : {"b" : 1, "width" : 1, "comment" : "RX FIFO full"} ,
                            "txe"  : {"b" : 2, "width" : 1, "comment" : "TX FIFO empty"} ,
                            "txf"  : {"b" : 3, "width" : 1, "comment" : "TX FIFO full"} ,
                            "modf" : {"b" : 4, "width" : 1, "comment" : "SS line driven external fault"} ,
                            },
                  "default" : None,
                  "comment" : " SPI status register"
                  }
    
# SPI Transmit FIFO
RegDef["SPTX"] = {"addr"    : 0x68, "width" : 8, "type" : "wt",
                  "bits"    : None,
                  "default" : 0,
                  "comment" : " Register address to write the transmit FIFO"
                  }

# SPI Receive FIFO
RegDef["SPRX"] = {"addr"    : 0x6C, "width" : 8, "type" : "ro",
                  "bits"    : None,
                  "default" : None,
                  "comment" : " Register address to read the receive FIFO"
                  }

# SPI Slave select
RegDef["SPSS"] = {"addr"    : 0x70, "width" : 8, "type" : "rw",
                  "bits"    : None,
                  "default" : 0,
                  "comment" : " SPI slave select register.  Use this register to select an exteral device"
                  }

# SPI Transmit FIFO count
RegDef["SPTC"] = {"addr"    : 0x74, "width" : 8, "type" : "ro",
                  "bits"    : None,
                  "default" : None,
                  "comment" : " SPI current count of the transmit FIFO"
                  }
    
# SPI Receive FIFO count
RegDef["SPRC"] = {"addr"    : 0x78, "width" : 8, "type" : "ro",
                  "bits"    : None,
                  "default" : None,
                  "comment" : " SPI current count of the receive FIFO"
                  }

# SPI clock divisor
RegDef["SPXX"] = {"addr"    : 0x7C, "width" : 8, "type" : "rw",
                  "bits"    : None,
                  "default" : 0,
                  "comment" : " SPI clock divisor register.  Sets SCK period"
                  }

