/*
    FX2 firmware for CD player project
    Michael Price
    
    Based on usb_jtag and Cypress FX2 examples.
    License: GPL v2
*/

#include "isr.h"
#include "usb_common.h"
#include "usb_requests.h"
#include "fx2regs.h"
#include "fx2utils.h"
#include "syncdelay.h"

void fx2_init()
{
    /*  Set up registers for the desired FX2 behavior.
        The FX2 is in slave FIFO mode with the following endpoints:
          - EP2 OUT 512 bytes double buffered
          - EP4 OUT 512 bytes double buffered
          - EP6 IN  512 bytes double buffered
          - EP8 IN  512 bytes double buffered
        The clock runs at 48 MHz and an 8-bit data bus (port B) is
        connected to the FPGA.
    */
    
    CPUCS = 0x10;       //  48 MHz clock, don't use CLKOUT pin  
    
    IFCONFIG = 0xE3;    //  48 MHz, drive IFCLK, slave FIFOs
    
    PINFLAGSAB = 0x98; SYNCDELAY;  //  Flag A: Endpoint 2 empty
                                   //  Flag B: Endpoint 4 empty
    PINFLAGSCD = 0xFE; SYNCDELAY;  //  Flag C: Endpoint 6 full
                                   //  Flag D: Endpoint 8 full
    /* 
        Flag D isn't connected, so we need another way (firmward, protocol)
        of telling if endpoint 8 is full. 
    */
    
    //  NAK all incoming packets for the time being so we can configure
    //  the endpoints.
    FIFORESET = 0x80; SYNCDELAY;
    
    //  Disable auto-arming of endpoints and enable firmware control over endpoint data.
    REVCTL = 0x03; SYNCDELAY;
    
    /*  
        The EPxCFG register settings must match the description in 
        dscr.a51.
    */
    EP2CFG = 0xA2; SYNCDELAY;      //  EP2 BULK OUT 512 bytes double-buffered
    EP4CFG = 0xA0; SYNCDELAY;      //  EP4 BULK OUT 512 bytes double-buffered
    EP6CFG = 0xE2; SYNCDELAY;      //  EP6 BULK IN  512 bytes double-buffered
    EP8CFG = 0xE0; SYNCDELAY;      //  EP8 BULK IN  512 bytes double-buffered
    
    /*
        Enable autocommit on all endpoints with 1 byte minimum
        (e.g. every piece of data is passed on as soon as possible).
        Also, set WORDWIDE = 0 (8-bit data bus).
    */
    EP2FIFOCFG = 0x14; SYNCDELAY;
    EP4FIFOCFG = 0x14; SYNCDELAY;
    EP6FIFOCFG = 0x0C; SYNCDELAY;
    EP8FIFOCFG = 0x0C; SYNCDELAY;
    EP6AUTOINLENH = 0x00; SYNCDELAY;
    EP6AUTOINLENL = 0X01; SYNCDELAY;
    EP8AUTOINLENH = 0x00; SYNCDELAY;
    EP8AUTOINLENL = 0X01; SYNCDELAY; 
    
    //  Reset endpoint FIFOs now that they have been configured.
    FIFORESET = 0x02; SYNCDELAY;            
    FIFORESET = 0x04; SYNCDELAY;            
    FIFORESET = 0x06; SYNCDELAY;            
    FIFORESET = 0x08; SYNCDELAY;    
    
    //  Stop NAKing packets in order to restore normal behavior.        
    FIFORESET = 0x00; SYNCDELAY;            
    
    //  Arm EP2 and EP4 by writing to PKTEND ('skipping' sending of actual data)
    OUTPKTEND = 0x82; SYNCDELAY;   
    OUTPKTEND = 0x84; SYNCDELAY;   

    //  Note: no FIFO interrupts enabled yet.
}

unsigned char app_vendor_cmd(void)
{
    // OUT requests. Pretend we handle them all...

    if ((bRequestType & bmRT_DIR_MASK) == bmRT_DIR_OUT)
    {
        return 1;
    }

    // IN requests.  Provide dummy data since there's no EEPROM.
    if(bRequest == 0x90)
    {
        BYTE addr = (wIndexL<<1) & 0x7F;
        EP0BUF[0] = 0x35;
        EP0BUF[1] = 0x82;
    }
    else
    {
        // dummy data
        EP0BUF[0] = 0x36;
        EP0BUF[1] = 0x83;
    }

    EP0BCH = 0;
    EP0BCL = (wLengthL<2) ? wLengthL : 2; // Arm endpoint with # bytes to transfer

    return 1;
}

void main()
{
    //  Disable interrupts
    EA = 0;

    //  Set up registers
    fx2_init();
    
    //  Set up autovectors (initially all NOPs)
    setup_autovectors();
    
    //  Initialize interrupt handlers
    usb_install_handlers();
    
    //  Enable interrupts
    EA = 1;
    
    //  Switch identities to new firmware
    fx2_renumerate();
    
    //  Sit around waiting for a setup packet
    //  and let the slave FIFOs do their job.
    while(1)
    {
        if(usb_setup_packet_avail()) 
            usb_handle_setup_packet();
    }
}

