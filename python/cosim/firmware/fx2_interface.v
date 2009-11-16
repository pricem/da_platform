//  FX2 interface
//  Contains glue logic that connects the FX2 USB processor to:
//  -   Endpoint 2: write ports of tracking FIFOs to DAC buffer
//  -   Endpoint 4: command decoder
//  -   Endpoint 6: read ports of tracking FIFOs to ADC buffer
//  -   Endpoint 8: status/command generator


module fx2_interface(
    //  USB interface
    usb_ifclk, usb_slwr, usb_slrd, usb_sloe, usb_addr, usb_data_in, usb_data_out, usb_ep2_empty, usb_ep4_empty, usb_ep6_full, usb_ep8_full,
    //  Control
    reset);


endmodule

