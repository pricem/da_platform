
from distutils.core import setup



setup(name          = "usbp",
      version       = "0.5pre",
      description   = "Collection of packages for USBP",
      author        = "Christopher L. Felton",
      author_email  = "cfelton@ieee.org",
      url           = "http://www.myhdl.org/doku.php/users:cfelton:projects:usbp",
      license       = "MIT",
      platforms     = ["Any"],
      keywords      = "Python HDL MyHDL USB FPGA",
      
      # Python Packages which are part of the USBP project.  The Python packages
      # usbp_cores and open_cores have their own setup files and are release
      # separately as well.  Provide a simple "one stop shop" release for the project
      packages = ["open_cores",
                  "open_cores.gpio",
                  "open_cores.spi",
                  "open_cores.twi",
                  "open_cores.usart",
                  "open_cores.register_file",
                  "open_cores.fifo",
                  "open_cores.fifo_ramp",
                  "open_cores.pcm4220",

                  "usbp_cores",
                  "usbp_cores.fx2_sfifo",
                  "usbp_cores.fx2_fifowb",
                  "usbp_cores.fx2_model"
                  ],

      package_dir = {"open_cores"                : "open_cores/open_cores",
                     "open_cores.gpio"           : "open_cores/open_cores/gpio",
                     "open_cores.spi"            : "open_cores/open_cores/spi",
                     "open_cores.twi"            : "open_cores/open_cores/twi",
                     "open_cores.usart"          : "open_cores/open_cores/usart",
                     "open_cores.register_file"  : "open_cores/open_cores/register_file",
                     "open_cores.fifo"           : "open_cores/open_cores/fifo",
                     "open_cores.fifo_ramp"      : "open_cores/open_cores/fifo_ramp",
                     "open_cores.pcm4220"        : "open_cores/open_cores/pcm4220",
                     
                     "usbp_cores"                : "usbp_cores/usbp_cores",
                     "usbp_cores.fx2_sfifo"      : "usbp_cores/usbp_cores/fx2_sfifo",
                     "usbp_cores.fx2_fifowb"     : "usbp_cores/usbp_cores/fx2_fifowb",
                     "usbp_cores.fx2_model"      : "usbp_cores/usbp_cores/fx2_model"
                     }      
      )
      
      
