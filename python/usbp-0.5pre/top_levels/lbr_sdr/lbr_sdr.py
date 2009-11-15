#
#
#

from myhdl import *

import usbp_cores
from usbp_cores.fx2_sfifo.fx2_sfifo_intf import *
from usbp_cores.fx2_fifowb.usb_intf_wb import *

import open_cores
from open_cores.gpio import *
from open_cores.spi  import *
from open_cores.twi  import *
from open_cores.fifo_ramp import *
from open_cores.pcm4220 import *

def lbr_sdr(
    reset,         # System sync reset
    sys_clk,       # System clock, most cases sys_clk == IFCLK

    # External FX2 Slave FIFO Interface
    IFCLK,         # FX2 48MHz source syncronouos clock
    FLAGA,         # EP2 Empty flag
    FLAGB,         # EP4 Empty flag
    FLAGC,         # EP6 Full flag
    FLAGD,         # EP8 Full flag
    SLOE,          # Output enable, slave fifo
    SLRD,          # Read Signal
    SLWR,          # Write Signal
    FIFOADR,       # FIFO address select, FIFOADR[1:0]
    PKTEND,        # Packet end, Tell FX2 to send data
    FDI,           # FIFO data in FDI[7:0]
    FDO,           # FIFO data out FDO[7:0]

    # External Peripherals
    LEDs,          #

    # SPI external signals
    SS,
    SCK,
    MOSI,
    MISO,

    # TWI external signals
    SCL_i,
    SCL_o,
    SDA_i,
    SDA_o,

    # PCM4220 ADC external signals
    SCLK,
    SDATA,
    LR,

    # LBR SDR Board Control Signals
    EN4V,
    NRST, 
    
#    TP_HDR         #
    ):
    """
    """
    
    # Internal signals
    fifo_wr     = Signal(False)
    fifo_rd     = Signal(False)
    fifo_full   = Signal(False)
    fifo_empty  = Signal(False)
    fifo_hold   = Signal(False)
    fifo_di     = Signal(intbv(0)[8:])
    fifo_do     = Signal(intbv(0)[8:])
    fifo_do_vld = Signal(False)

    fifo_di_spi = Signal(intbv(0)[8:])
    fifo_wr_spi = Signal(False)
    fifo_rd_spi = Signal(False)
    
    fifo_di_twi = Signal(intbv(0)[8:])
    fifo_wr_twi = Signal(False)
    fifo_rd_twi = Signal(False)

    fifo_di_rmp = Signal(intbv(0)[8:])
    fifo_wr_rmp = Signal(False)
    fifo_rd_rmp = Signal(False)

    fifo_di_pcm = Signal(intbv(0)[8:])
    fifo_wr_pcm = Signal(False)
    fifo_rd_pcm = Signal(False)

    
    wb_clk      = Signal(False)
    wb_rst      = Signal(False)
    wb_dat_o    = Signal(intbv(0)[8:])
    wb_dat_i    = Signal(intbv(0)[8:])
    wb_adr      = Signal(intbv(0)[16:])
    wb_cyc      = Signal(False)
    wb_ack      = Signal(False)
    wb_err      = Signal(False)
    wb_lock     = Signal(False)
    wb_rty      = Signal(False)
    wb_sel      = Signal(intbv(0)[4:])
    wb_stb      = Signal(False)
    wb_we       = Signal(False)
    loopback    = Signal(False)
    fx2_dbg     = Signal(intbv(0)[8:])

    # local signals
    led        = Signal(intbv(0)[8:])
    led_gpio   = Signal(intbv(0)[8:])
    led_sel    = Signal(intbv(0)[8:])

    @always_comb
    def rtl_assignments():
        LEDs.next          = led
        #TP_HDR.next[?:?]  = SS
        #TP_HDR.next[???]  = SCK
        #TP_HDR.next[???]  = MOSI
        #MISO.next         = TP???
        #
        #TP_HDR.next[8:]    = fx2_dbg
        #TP_HDR.next[16:8]  = 0
        
    # FX2 Slave FIFO Interface
    fifo_intf  = usb_intf_wb(reset, sys_clk, IFCLK, FLAGA, FLAGB, FLAGC, FLAGD,
                             SLOE, SLRD, SLWR, FIFOADR, PKTEND, FDI, FDO,
                             wb_clk, wb_rst, wb_dat_o, wb_dat_i, wb_adr,
                             wb_cyc, wb_ack, wb_err, wb_lock, wb_rty, wb_sel,
                             wb_stb, wb_we,
                             fifo_di, fifo_do, fifo_do_vld, fifo_full, fifo_empty,
                             fifo_wr, fifo_rd, fifo_hold, 
                             loopback, fx2_dbg)


    # @todo hook the fifo up to something useful.
    @always_comb
    def rtl_fifo_sigs():
        fifo_wr.next  = fifo_wr_spi | fifo_wr_twi | fifo_wr_rmp | fifo_wr_pcm
        fifo_rd.next  = fifo_rd_spi | fifo_rd_twi | fifo_rd_rmp | fifo_rd_pcm
        fifo_di.next  = fifo_di_spi | fifo_di_twi | fifo_di_rmp | fifo_di_pcm
        
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # Wishbone memory mapped components
    #   Memory Map
    #     0x0100   GPIO_0.ctrl
    #     0x0101   GPIO_0.data  -- LED Select  (output only)
    #     0x0102   GPIO_1.ctrl
    #     0x0103   GPIO_1.data  -- LED
    #
    #     0x0200   SPI
    #     0x0400   TWI
    #     0x0800   RAMP
    #     0x1000   pcm4220

    g0_dat_i  = Signal(intbv(0)[8:])
    g0_ack    = Signal(False)
    g1_dat_i  = Signal(intbv(0)[8:])
    g1_ack    = Signal(False)
    spi_dat_i = Signal(intbv(0)[8:])
    spi_ack   = Signal(False)
    twi_dat_i = Signal(intbv(0)[8:])
    twi_ack   = Signal(False)
    rmp_dat_i = Signal(intbv(0)[8:])
    rmp_ack   = Signal(False)
    pcm_dat_i = Signal(intbv(0)[8:])
    pcm_ack   = Signal(False)

    
    @always_comb
    def rtl_wb_bus_or():
        wb_dat_i.next = g0_dat_i | g1_dat_i | spi_dat_i | twi_dat_i | rmp_dat_i | pcm_dat_i
        wb_ack.next   = g0_ack   | g1_ack   | spi_ack   | twi_ack   | rmp_ack   | pcm_ack

    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # Wishbone bus peripherals
    
    # ----[ GPIOs ]----
    # @todo all gIO defined via register_file, DO IT 
    gpio0 = gpio8(wb_clk, wb_rst, wb_cyc, wb_stb,
                 wb_adr, wb_we, wb_dat_o, g0_dat_i,
                 g0_ack, led_sel, None, None,
                 C_IO_MASK = 0xFF, C_WB_ADDR = 0x0100)

    gpio1 = gpio8(wb_clk, wb_rst, wb_cyc, wb_stb,
                 wb_adr, wb_we, wb_dat_o, g1_dat_i,
                 g1_ack, led_gpio, None, None,
                 C_IO_MASK = 0xFF, C_WB_ADDR = 0x0102)


    # ----[ SPI Controller ]----
    spi0  = spi(wb_clk, wb_rst, wb_cyc, wb_stb,
                wb_adr, wb_we, wb_sel, wb_dat_o, spi_dat_i,
                spi_ack, fifo_di_spi, fifo_do, fifo_do_vld, fifo_rd_spi,
                fifo_wr_spi, fifo_full, fifo_empty, SS, SCK, MOSI, MISO,
                C_WB_ADDR = 0x0200)

    # ----[ TWI Controller ]----
    twi0  = twi(wb_clk, wb_rst, wb_cyc, wb_stb,
                wb_adr, wb_we, wb_sel, wb_dat_o, twi_dat_i,
                twi_ack, fifo_di_twi, fifo_do, fifo_do_vld, fifo_rd_twi,
                fifo_wr_twi, fifo_full, fifo_empty, SS, SCK, MOSI, MISO,
                C_WB_ADDR = 0x0400)

    # ----[ Ramp Generator ]----
    rmp0 = fifo_ramp(wb_clk, wb_rst, wb_cyc, wb_stb,
                     wb_adr, wb_we, wb_sel, wb_dat_o, rmp_dat_i, rmp_ack,
                     fifo_di_rmp, fifo_do, fifo_do_vld, fifo_rd_rmp,
                     fifo_wr_rmp, fifo_full, fifo_empty,
                     C_WB_ADDR = 0x0800)

    # ----[ PCM4220 ADC Interface ]----
    pcm0 = pcm4220(wb_clk, wb_rst, wb_cyc, wb_stb,
                   wb_adr, wb_we, wb_sel, wb_dat_o, pcm_dat_i, pcm_ack,
                   fifo_di_pcm, fifo_do, fifo_do_vld, fifo_rd_pcm,
                   fifo_wr_pcm, fifo_full, fifo_empty,
                   SCLK, SDATA, LR, EN4V, NRST,
                   C_WB_ADDR = 0x1000)

    # @todo(s)
    # ----[ PRN Generator ]----
    # ----[ CIC Filter    ]----
    # ----[ DDC / DUC     ]----
    # ----[ Cng Sig Path  ]----

    @always(sys_clk.posedge)
    def rtl_led_select():
        if led_sel == 0:
            led.next = 0x55
        elif led_sel == 1:
            led.next = led_gpio
        elif led_sel == 2:
            led.next = fx2_dbg
        else:
            led.next = 0xBD
            
    return instances()


def convert(to = 'ver'):
    reset     = Signal(False)
    IFCLK     = Signal(False)
    FLAGA     = Signal(False)
    FLAGB     = Signal(False)
    FLAGC     = Signal(False)
    FLAGD     = Signal(False)
    SLOE      = Signal(False)
    SLRD      = Signal(False)
    SLWR      = Signal(False)
    FIFOADR   = Signal(intbv(0)[2:])
    PKTEND    = Signal(False)
    FDI       = Signal(intbv(0)[8:])    
    FDO       = Signal(intbv(0)[8:])
    
    LEDs      = Signal(intbv(0)[8:])
    SS        = Signal(intbv(0)[8:])
    SCK       = Signal(False)
    MOSI      = Signal(False)
    MISO      = Signal(False)
    SCL_o     = Signal(False)
    SCL_i     = Signal(False)
    SDA_o     = Signal(False)
    SDA_i     = Signal(False)

    SCLK      = Signal(False)
    SDATA     = Signal(False)
    LR        = Signal(False)
    EN4V      = Signal(False)
    NRST      = Signal(False)
    
    
    TP_HDR    = Signal(intbv(0)[16:])
    sys_clk   = Signal(False)
    
    if to == 'ver':
        toVerilog(lbr_sdr, reset, sys_clk,
                  IFCLK, FLAGA, FLAGB, FLAGC, FLAGD,
                  SLOE, SLRD, SLWR,
                  FIFOADR, PKTEND, FDI, FDO, LEDs,
                  SS, SCK, MOSI, MISO,
                  SCL_i, SCL_o, SDA_i, SDA_o,
                  SCLK, SDATA, LR, EN4V, NRST) #, TP_HDR)
        
    elif to == 'vhd':
        toVHDL(lbr_sdr, reset, sys_clk,
               IFCLK, FLAGA, FLAGB, FLAGC, FLAGD,
               SLOE, SLRD, SLWR,
               FIFOADR, PKTEND, FDI, FDO, LEDs,
               SS, SCK, MOSI, MISO,
               SCL_I, SCL_o, SDA_i, SDA_o,
               SCLK, SDATA, LR, EN4V, NRST) #, TP_HDR)
        

if __name__ == '__main__':
    convert('ver')
    #convert('vhd') Broke??
