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
    ep2_port_data, ep2_port_write, ep2_port_clk, ep6_port_addr_ins, ep6_port_addr_outs, ep6_port_datas, ep6_port_read, ep6_port_clk,
    //  Connection to command decoder
    cmd_in_id, cmd_in_length, cmd_in_data, cmd_in_clk, cmd_in_ready, cmd_in_read,
    //  Connection to command encoder
    cmd_out_id, cmd_out_length, cmd_out_data, cmd_out_clk, cmd_out_ready, cmd_out_write,
    //  Control
    reset, clk);
    
    /*  In/out declarations  */
    
    //  USB interface
    input usb_ifclk;
    output reg usb_slwr;        //  Active low
    output usb_slrd;            //  Active low
    output usb_sloe;            //  Active low
    output [1:0] usb_addr;
    output reg [7:0] usb_data_in;
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
    input [43:0] ep6_port_addr_ins;          //  EP6 tracking FIFO has address lines so FX2 interface knows when to start and stop reading
    input [43:0] ep6_port_addr_outs;
    input [31:0] ep6_port_datas;
    output reg [3:0] ep6_port_read;
    output ep6_port_clk;
    
    //  Connection to command decoder (writes configuration RAM)
    //  This module drives cmd_in_clk with the USB clock.
    //  The cmd_in_ready line will be asserted once the ID and length have been pulled and the data is about to be pulled.
    //  Then the command decoder asserts cmd_in_read to read each byte of data.
    output [7:0] cmd_in_id;
    output [15:0] cmd_in_length;
    output [7:0] cmd_in_data;
    output cmd_in_clk;
    output cmd_in_ready;
    input cmd_in_read;
    
    //  Connection to command encoder (reads configuration RAM)
    //  Works much like the command decoder connection, except the encoder supplies the command ID and length and
    //  cmd_out_ready is asserted once those have been written to the USB endpoint.  Then the encoder asserts
    //  cmd_out_write while placing the appropriate data on the cmd_out_data lines.
    input [7:0] cmd_out_id;
    input [15:0] cmd_out_length;
    input [7:0] cmd_out_data;
    output cmd_out_clk;
    output cmd_out_ready;
    input cmd_out_write;
    
    input clk;
    input reset;


    /*  State machine parameters   */
    
    //  USB endpoint index (state_endpoint_index)
    parameter [1:0] EP2 = 2'b00;
    parameter [1:0] EP4 = 2'b01;
    parameter [1:0] EP6 = 2'b10;
    parameter [1:0] EP8 = 2'b11;
    
    //  USB packet status (state_packet_status)
    parameter [2:0] PACKET_WAITING = 3'b000;
    parameter [2:0] PACKET_HEADER_COMMAND = 3'b001;
    parameter [2:0] PACKET_HEADER_LENGTH_UPPER = 3'b010;
    parameter [2:0] PACKET_HEADER_LENGTH_LOWER = 3'b011;
    parameter [2:0] PACKET_DATA = 3'b100;
    parameter [2:0] PACKET_DONE = 3'b101;

    //  Header byte
    parameter [7:0] HEADER_BYTE = 8'hFF;
    parameter [7:0] UNSET_BYTE = 8'h76;
    
    //  Command stuff
    parameter [7:0] COMMAND_NOP = 8'h00;


    /*  Internal signals  */
    integer i;
    genvar g;
    
    //  Global 
    reg [1:0] state_endpoint_index;         //  The index of the current tracking FIFO
    reg [2:0] state_packet_status [3:0];    //  The status of the packet being read or written at the endpoint index
    
    //  State for when a data packet is coming in from EP2:
    reg [1:0] ep2_port_index;           //  The port selected
    reg [15:0] ep2_data_length;         //  The amount of data to write to a tracking FIFO
    reg [15:0] ep2_byte_counter;        //  Counter of bytes written so far to a tracking FIFO
    
    //  State for when a command packet is coming in from EP4:
    reg [7:0] ep4_command_index;        //  The command selected.
    reg [15:0] ep4_command_length;      //  The amount of data to write to a tracking FIFO
    reg [15:0] ep4_byte_counter;        //  Counter of bytes written so far to a tracking FIFO
    
    //  State for when a data packet is going out via EP6:
    reg [1:0] ep6_port_index;           //  The index of the current tracking FIFO
    reg [10:0] ep6_destination_length;  //  The number of bytes to read from the tracking FIFO
    reg [10:0] ep6_destination_byte;    //  The target end address for the tracking FIFO
    
    //  State for when a command packet is going out via EP8:
    reg [7:0] ep8_command_length;
    reg [7:0] ep8_byte_counter;
    reg [3:0] ep8_cycle_counter;        //  Counter for number of cycles spent waiting for controller to write on EP8 
    parameter EP8_WAIT_CYCLES = 4;      //  Number of cycles to wait before giving up.
    
    //  Whether this is a read or write operation (from/to the FX2).
    wire state_read;
    wire state_write;
    
    //  Whether this is a data or command operation
    wire state_data;
    wire state_command;
    
    //  Whether EP6 ports should be used.
    wire state_ep6_active [3:0];
    
    //  Break out signal lists
    wire [7:0] ep6_port_data [3:0];
    wire [10:0] ep6_port_addr_in [3:0];
    wire [10:0] ep6_port_addr_out [3:0];
    generate for (g = 0; g < 4; g = g + 1) begin:ep6_ports
        assign ep6_port_data[g] = ep6_port_datas[((g + 1) * 8 - 1):(g * 8)];
        assign ep6_port_addr_in[g] = ep6_port_addr_ins[((g + 1) * 11 - 1):(g * 11)];
        assign ep6_port_addr_out[g] = ep6_port_addr_outs[((g + 1) * 11 - 1):(g * 11)];       
        end
    endgenerate
    
    //  Non-array signals for monitoring
    wire [2:0] state_packet_status_ep2 = state_packet_status[0];
    wire [2:0] state_packet_status_ep4 = state_packet_status[1];
    wire [2:0] state_packet_status_ep6 = state_packet_status[2];
    wire [2:0] state_packet_status_ep8 = state_packet_status[3];
    wire state_ep6_active_port0 = state_ep6_active[0];
    wire state_ep6_active_port1 = state_ep6_active[1];
    wire state_ep6_active_port2 = state_ep6_active[2];
    wire state_ep6_active_port3 = state_ep6_active[3];
    
    /*  Logic processes */
    
    //  Assign read/write flags
    assign state_read = ((state_endpoint_index == EP2) || (state_endpoint_index == EP4));
    assign state_write = ((state_endpoint_index == EP6) || (state_endpoint_index == EP8));
    assign state_data = ((state_endpoint_index == EP2) || (state_endpoint_index == EP6));
    assign state_command = ((state_endpoint_index == EP4) || (state_endpoint_index == EP8));
    generate for (g = 0; g < 4; g = g + 1) begin:ep6_states
            assign state_ep6_active[g] = (ep6_port_addr_out[g] != ep6_port_addr_in[g]);
        end
    endgenerate
    
    //  Assign audio port outputs
    assign ep2_port_clk = usb_ifclk;
    //  assign ep2_port_data = ep2_port_write[ep2_port_index] ? usb_data_out : 8'b0;
    assign ep2_port_data = usb_data_out;
    generate for (g = 0; g < 4; g = g + 1) begin:ep2_ports
            assign ep2_port_write[g] = ((ep2_port_index == g) && ((state_endpoint_index == EP2) && (state_packet_status[state_endpoint_index] == PACKET_DATA)));
        end
    endgenerate
    
    assign ep6_port_clk = usb_ifclk;
    
    //  Assign command decoder outputs
    assign cmd_in_id = ep4_command_index;
    assign cmd_in_length = ep4_command_length;
    assign cmd_in_data = usb_data_out;
    assign cmd_in_ready = ((state_endpoint_index == EP4) && (state_packet_status[state_endpoint_index] == PACKET_DATA));
    assign cmd_in_clk = usb_ifclk;
    
    //  Assign command encoder control lines
    assign cmd_out_ready = ((state_endpoint_index == EP8) && (state_packet_status[state_endpoint_index] == PACKET_DATA));
    assign cmd_out_clk = usb_ifclk;
    
    //  Tell the FX2 to always drive its outputs
    assign usb_sloe = 0;
    //  Tell the FX2 to read when the correct endpoint is selected and the FIFO is not empty
    assign usb_slrd = ~(state_read && ~((state_endpoint_index == EP2) ? usb_ep2_empty : (usb_ep4_empty || (state_packet_status[state_endpoint_index] == PACKET_DATA && ~cmd_in_read))) && state_packet_status[state_endpoint_index] != PACKET_DONE);
    
    //  Use the currently selected endpoint
    assign usb_addr = state_endpoint_index;
    
    always @(posedge usb_ifclk) begin
        if (reset) begin
            //  Handle a reset by switching to the beginning state.
            state_endpoint_index <= EP2;
            for (i = 0; i < 4; i = i + 1)
                state_packet_status[i] <= PACKET_WAITING;
                
            ep2_port_index <= 0;
            ep2_data_length <= 0;
            ep2_byte_counter <= 0;
            
            ep4_command_index <= COMMAND_NOP;
            ep4_command_length <= 0;
            ep4_byte_counter <= 0;
            
            ep6_destination_byte <= 0;
            ep6_destination_length <= 0;
            ep6_port_index <= 0;
            ep6_port_read <= 0;

            ep8_command_length <= 0;
            ep8_byte_counter <= 0;
            ep8_cycle_counter <= 0;

            usb_slwr <= 1;
        end
        else begin
            //  To do: these conditions will need to be made more specific to avoid data corruption.
            //  Read if EP2 or EP4 is selected and the endpoint is not empty.
            
            //  Control of usb_slwr is handled within the state machine
            
            //  Main state machine
            case (state_packet_status[state_endpoint_index])
                //  If waiting, wait for a header byte and, once it is received, move on to the header state. 
                PACKET_WAITING: begin
                    case (state_endpoint_index)
                        EP2, 
                        EP4: begin
                            if (~usb_slrd && (usb_data_out == HEADER_BYTE))
                                //  If a packet starts arriving, move on to reading the header.
                                state_packet_status[state_endpoint_index] <= PACKET_HEADER_COMMAND;
                            else 
                                //  Otherwise, go on to service the next endpoint.
                                state_packet_status[state_endpoint_index] <= PACKET_DONE;
                        end
                        EP6: begin
                            if ((state_ep6_active[ep6_port_index]) && ~usb_ep6_full) begin
                                //  If the tracking FIFO for the current port has data, write a header byte and move on.
                                usb_slwr <= 0;
                                usb_data_in <= HEADER_BYTE;
                                state_packet_status[state_endpoint_index] <= PACKET_HEADER_COMMAND;
                            end
                            else begin
                                //  Otherwise, call it a day and move on to the next endpoint.
                                //  Also increment the port index so we check the next port next time.
                                ep6_port_index <= ep6_port_index + 1;
                                state_packet_status[state_endpoint_index] <= PACKET_DONE;
                            end
                        end
                        EP8: begin
                            //  We are servicing EP8. Do something only if there is a valid command waiting.
                            if ((cmd_out_id > 0) && ~usb_ep8_full) begin
                                usb_slwr <= 0;
                                usb_data_in <= HEADER_BYTE;
                                state_packet_status[state_endpoint_index] <= PACKET_HEADER_COMMAND;
                            end
                            else
                                state_packet_status[state_endpoint_index] <= PACKET_DONE;
                        end
                    endcase
                end
                
                //  If the header is coming in or going, store the data in the appropriate location.
                //  While dealing with a packet, you can abandon an endpoint temporarily by switching the state_endpoint_index
                //  and leaving the state_packet_status for the current state_endpoint_index intact.
                PACKET_HEADER_COMMAND: begin
                    case (state_endpoint_index)
                        EP2: begin
                            if (~usb_slrd) begin
                                ep2_port_index <= usb_data_out;
                                state_packet_status[state_endpoint_index] <= PACKET_HEADER_LENGTH_UPPER;
                            end
                            else
                                state_endpoint_index <= state_endpoint_index + 1;
                        end
                        EP4: begin
                            if (~usb_slrd) begin
                                ep4_command_index <= usb_data_out;
                                state_packet_status[state_endpoint_index] <= PACKET_HEADER_LENGTH_UPPER;
                            end
                            else
                                state_endpoint_index <= state_endpoint_index + 1;
                        end
                        EP6: begin
                            //  At this point we need to set a target address to read up to in the appropriate tracking FIFO.
                            //  Because the amount of data to be written is known, we do not allow abandoning the endpoint until the packet is done.
                            usb_slwr <= 0;
                            usb_data_in <= ep6_port_index;
                            ep6_destination_byte <= ep6_port_addr_in[ep6_port_index];
                            ep6_destination_length <= ep6_port_addr_in[ep6_port_index] - ep6_port_addr_out[ep6_port_index];
                            state_packet_status[state_endpoint_index] <= PACKET_HEADER_LENGTH_UPPER;
                        end
                        EP8: begin
                            //  Collect the command ID, move to next state.
                            usb_slwr <= 0;
                            usb_data_in <= cmd_out_id;
                            state_packet_status[state_endpoint_index] <= PACKET_HEADER_LENGTH_UPPER;
                        end
                    endcase
                end
                PACKET_HEADER_LENGTH_UPPER: begin
                    case (state_endpoint_index)
                        EP2: begin
                            //  Save the upper byte of the packet data length if it has arrived, otherwise abandon the endpoint.
                            if (~usb_slrd) begin
                                ep2_data_length[15:8] <= usb_data_out;
                                state_packet_status[state_endpoint_index] <= PACKET_HEADER_LENGTH_LOWER;
                            end
                            else
                                state_endpoint_index <= state_endpoint_index + 1;
                        end
                        EP4: begin
                            //  Save the upper byte of the packet command length if it has arrived, otherwise abandon the endpoint.
                            if (~usb_slrd) begin
                                ep4_command_length[15:8] <= usb_data_out;
                                state_packet_status[state_endpoint_index] <= PACKET_HEADER_LENGTH_LOWER;
                            end
                            else
                                state_endpoint_index <= state_endpoint_index + 1;
                        end
                        EP6: begin
                            //  Write the upper byte of the packet data length and move on.
                            usb_slwr <= 0;
                            usb_data_in <= ep6_destination_length[10:8];
                            //  Set up a read from the appropriate tracking FIFO (2 cycles early).
                            ep6_port_read[ep6_port_index] <= 1;
                            state_packet_status[state_endpoint_index] <= PACKET_HEADER_LENGTH_LOWER;
                        end
                        EP8: begin
                            //  Collect the upper byte of the length, move to next state.
                            usb_slwr <= 0;
                            usb_data_in <= cmd_out_length[15:8];
                            ep8_command_length <= cmd_out_length;
                            state_packet_status[state_endpoint_index] <= PACKET_HEADER_LENGTH_LOWER;
                        end
                    endcase
                end
                PACKET_HEADER_LENGTH_LOWER: begin
                    case (state_endpoint_index)
                        EP2: begin
                            //  Save the lower byte of the packet data length if it has arrived; abandon the endpoint otherwise.
                            if (~usb_slrd) begin
                                ep2_data_length[7:0] <= usb_data_out;
                                ep2_byte_counter <= 0;
                                state_packet_status[state_endpoint_index] <= PACKET_DATA;
                            end
                            else
                                state_endpoint_index <= state_endpoint_index + 1;
                        end
                        EP4: begin
                            //  Save the lower byte of the packet command length if it has arrived; abandon the endpoint otherwise.
                            if (~usb_slrd) begin
                                ep4_command_length[7:0] <= usb_data_out;
                                ep4_byte_counter <= 0;
                                state_packet_status[state_endpoint_index] <= PACKET_DATA;
                            end
                            else
                                state_endpoint_index <= state_endpoint_index + 1;
                        end
                        EP6: begin
                            //  Write the lower byte of the packet data length and start on data.
                            usb_data_in <= ep6_destination_length[7:0];
                            state_packet_status[state_endpoint_index] <= PACKET_DATA;
                        end
                        EP8: begin
                            //  Collect the command ID, move to next state.
                            usb_slwr <= 0;
                            usb_data_in <= cmd_out_length[7:0];
                            ep8_byte_counter <= 0;
                            ep8_cycle_counter <= 0;
                            state_packet_status[state_endpoint_index] <= PACKET_DATA;
                        end
                    endcase
                end
                
                //  If data is currently being read/written, move it to the appropriate destination buffer
                //  while keeping count of the number of bytes against the total for this packet.  The endpoint may be abandoned.
                PACKET_DATA: begin
                    case (state_endpoint_index)
                        EP2: begin
                            if (~usb_slrd) begin
                                if (ep2_byte_counter >= ep2_data_length - 1)
                                    state_packet_status[state_endpoint_index] <= PACKET_DONE;
                                ep2_byte_counter <= ep2_byte_counter + 1;
                            end
                        end
                        EP4: begin
                            if (~usb_slrd) begin
                                if (ep4_byte_counter >= ep4_command_length - 1)
                                    state_packet_status[state_endpoint_index] <= PACKET_DONE;
                                ep4_byte_counter <= ep4_byte_counter + 1;
                            end
                        end
                        EP6: begin
                            usb_slwr <= 0;
                            usb_data_in <= ep6_port_data[ep6_port_index];
                            if (ep6_port_addr_out[ep6_port_index] >= ep6_destination_byte - 1) begin
                                ep6_port_read[ep6_port_index] <= 0;
                            end
                            if (ep6_port_addr_out[ep6_port_index] >= ep6_destination_byte) begin
                                state_packet_status[state_endpoint_index] <= PACKET_DONE;
                            end
                        end
                        EP8: begin
                            //  Move on if the proper number of bytes were received or the write timed out.
                            if ((ep8_byte_counter > ep8_command_length) || (ep8_cycle_counter >= EP8_WAIT_CYCLES) || (ep8_command_length == 0)) begin
                                usb_slwr <= 1;
                                
                                state_packet_status[state_endpoint_index] <= PACKET_DONE;
                            end
                            //  Increment byte counter and write data to FX2 if controller elects to write.
                            else if (cmd_out_write) begin
                                //  Add a cycle of lag so the controller can fetch its data.
                                //  This means that ep8_byte_counter is actually 1 higher than the number of bytes written.
                                if (ep8_byte_counter >= 1)
                                    usb_slwr <= 0;
                                else
                                    usb_slwr <= 1;
                                usb_data_in <= cmd_out_data;
                                ep8_byte_counter <= ep8_byte_counter + 1;
                            end
                            //  Otherwise wait and see if the controller wants to write.
                            else begin
                                usb_slwr <= 1;
                                ep8_cycle_counter <= ep8_cycle_counter + 1; 
                            end
                        end
                    endcase
                end
                
                //  If the current packet is done, move to the next endpoint
                PACKET_DONE: begin
                    usb_slwr <= 1;
                    state_packet_status[state_endpoint_index] <= PACKET_WAITING;
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

