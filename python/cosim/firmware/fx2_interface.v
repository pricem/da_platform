/*  FX2 interface

Contains glue logic that connects the FX2 USB processor to:
-   Endpoint 2: write ports of tracking FIFOs to DAC buffer
-   Endpoint 4: command decoder
-   Endpoint 6: read ports of tracking FIFOs to ADC buffer
-   Endpoint 8: status/command generator

All inputs are active high.

*/

module fx2_interface(
    //  USB interface
    usb_ifclk, usb_slwr, usb_slrd, usb_sloe, usb_addr, usb_data_in, usb_data_out, usb_ep2_empty, usb_ep4_empty, usb_ep6_full, usb_ep8_full,
    //  Endpoint ports
    ep2_port_data, ep2_port_write, ep2_port_clk, ep6_port_data, ep6_port_read, ep6_port_clk,
    //  Connection to configuration RAM
    config_addr, config_write, config_clk, config_data,
    //  Connection to command encoder
    cmd_new_command, cmd_data, cmd_clk, cmd_read,
    //  Control
    reset, clk);
    
    /*  In/out declarations  */
    
    //  USB interface
    input usb_ifclk;
    output usb_slwr;
    output usb_slrd;
    output usb_sloe;
    output [1:0] usb_addr;
    output [7:0] usb_data_in;
    input [7:0] usb_data_out;
    input usb_ep2_empty;
    input usb_ep4_empty;
    input usb_ep6_full;
    input usb_ep8_full;
    
    //  Endpoint ports to/from tracking FIFOs
    //  They share data and clock, but only one is being read or written at any given time
    output [7:0] ep2_port_data;
    output [3:0] ep2_port_write;
    output ep2_port_clk;
    input [31:0] ep6_port_datas;
    output [3:0] ep6_port_read;
    output ep6_port_clk;
    
    //  Connection to configuration RAM
    output [7:0] config_addr;
    output config_write;
    output config_clk;
    output [7:0] config_data;
    
    //  Connection to command encoder
    input cmd_new_command;
    input [7:0] cmd_data;
    output cmd_clk;
    output cmd_read;


    /*  State machine parameters   */
    
    //  USB endpoint index (state_endpoint_index)
    parameter [1:0] EP2 = 2'b00;
    parameter [1:0] EP4 = 2'b01;
    parameter [1:0] EP6 = 2'b10;
    parameter [1:0] EP8 = 2'b11;
    
    //  USB packet status (state_packet_status)
    parameter [1:0] PACKET_WAITING = 2'b00;
    parameter [1:0] PACKET_HEADER = 2'b01;
    parameter [1:0] PACKET_DATA = 2'b10;
    parameter [1:0] PACKET_DONE = 2'b11;

    //  Header byte
    parameter [7:0] HEADER_BYTE = 8'hFF;


    /*  Internal signals  */
    
    //  The endpoint currently being serviced
    reg [1:0] state_endpoint_index;
    
    //  The status of the packet being read or written at the endpoint index
    reg [1:0] state_packet_status [1:0];
    
    //  Whether this is a read or write operation (from/to the FX2).
    wire state_read;
    wire state_write;
    
    //  Break out signal lists
    wire [7:0] ep6_port_data [3:0];
    always @(ep6_port_data) for (i = 0; i < 4; i = i + 1)
        ep6_port_datas[((i + 1) * 8 - 1):(i * 8)] = ep6_port_data[i];
    
    /*  Logic processes */
    
    //  Assign read/write flags
    assign state_read = ((state_endpoint_index == EP2) || (state_endpoint_index == EP4));
    assign state_write = ((state_endpoint_index == EP6) || (state_endpoint_index == EP8));
    
    //  Tell the FX2 to always drive its outputs
    assign usb_sloe = 1;
    
    always @(posedge clk) begin
        if (reset) begin
            state_endpoint_index <= EP2;
            for (i = 0; i < 4; i++)
                state_packet_status[i] <= PACKET_WAITING;
        else begin
        
            //  Main state machine
            case (state_packet_status)
                //  If waiting, look for a header byte and, once it is received, 
                PACKET_WAITING:
                    state_packet_status <= PACKET_HEADER;
                
                //  If reading the header, 
                PACKET_HEADER:
                    state_packet_status <= PACKET_DATA;
                
                //  If data is currently being 
                PACKET_DATA:
                    state_packet_status <= PACKET_DONE;

                //  If the current packet is done, move to the next endpoint
                PACKET_DONE: begin
                    state_packet_status <= PACKET_WAITING;
                    case (state_endpoint_index)
                        EP2: state_endpoint_index <= EP4;
                        EP4: state_endpoint_index <= EP6;
                        EP6: state_endpoint_index <= EP8;
                        EP8: state_endpoint_index <= EP2;
                    endcase
                end
            endcase
            
        end
    end

endmodule

