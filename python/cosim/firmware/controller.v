/*  Controller module

    This central state machine communicates with EP4 and EP8 on the FX2 interface,
    the configuration memory, and the DAC/ADC I/O modules.
*/


module controller(
    //  EP4 (command input) port
    ep4_clk, ep4_cmd_id, ep4_cmd_length, ep4_ready, ep4_read, ep4_data,
    //  EP8 (command output) port
    ep8_clk, ep8_cmd_id, ep8_cmd_length, ep8_ready, ep8_write, ep8_data,
    //  Configuration memory
    cfg_clk, cfg_addr, cfg_data, cfg_write, cfg_read,
    //  Monitoring inputs
    direction, num_channels,
    //  Outputs 
    hwcons,
    //  Crapload of other stuff
    //  [TBD]
    //  System-wide control
    clk, reset
    );

    //  Including the header file for commands doesn't work:
    //  `include "commands.v"
    //  So, I'll just copy in the supported commands.
    parameter CMD_CONFIG_GET_REG = 8'h31;
    parameter CMD_CONFIG_SET_REG = 8'h32;
    parameter CMD_DATA_REG = 8'h90;
    parameter CMD_ERROR_NOT_FOUND = 8'hF0;
    
    //  Maximum length of command data in bytes
    parameter MAX_COMMAND_LENGTH = 8;
    
    //  Maximum number of registers per device
    parameter MAX_NUM_REGISTERS = 16;
    
    //  EP4 port: The FX2 interface drives the clock but this controller 
    //  (running at a faster rate) polls and reads it as necessary
    input ep4_clk;
    input [7:0] ep4_cmd_id;
    input [15:0] ep4_cmd_length;
    input ep4_ready;
    output reg ep4_read;
    input [7:0] ep4_data;
    
    //  EP8 port: The FX2 interface drives the clock but this controller
    //  (running faster) polls and writes it as necessary
    input ep8_clk;
    output [7:0] ep8_cmd_id;
    output [15:0] ep8_cmd_length;
    input ep8_ready;
    output reg ep8_write;
    output reg [7:0] ep8_data;

    //  Configuration memory: The controller reads/writes one port of a 
    //  standard dual-port RAM.
    output cfg_clk;
    output reg [10:0] cfg_addr;
    inout [7:0] cfg_data;
    output reg cfg_write;
    output reg cfg_read;
    
    //  Other inputs for monitoring
    input [3:0] direction;
    input [3:0] num_channels;
    
    //  Hardware configuration: An 8-bit register for each port
    output [31:0] hwcons;
    
    //  Control stuff
    input clk;
    input reset;
    
    /*  Internal signals */
    integer i;
    
    //  States
    reg [1:0] state;                //  Outer state
    parameter WAITING = 2'b00;
    parameter READING = 2'b01;
    parameter EXECUTING = 2'b10;
    parameter REPLYING = 2'b11;
    
    reg [1:0] ep4_state;            //  Inner state for reading/writing commands at USB clock rate
    reg [1:0] ep8_state;
    parameter IDLE = 2'b00;
    parameter ACTIVE = 2'b01;
    parameter DONE = 2'b10;
    
    reg [1:0] config_state;         //  Configuration memory state
    reg search_started;             //  Flag goes up after init->search transition
    parameter INITIALIZING = 2'b00;
    parameter SEARCHING = 2'b01;
    parameter MATCHED = 2'b10;  
    parameter FAILED = 2'b11;       //  All available configuration slots are in use and the desired register was not there.       
    reg [4:0] reg_index;            //  Index of the register currently being checked in configuration memory
    reg [7:0] reg_addr;             //  Address of the desired register to look up

    reg [7:0] read_byte_count;      //  Number of bytes read from FX2 interface on EP4
    reg [7:0] write_byte_count;     //  Number of bytes written to FX2 interface on EP8
    reg [(MAX_COMMAND_LENGTH * 8 - 1):0] cmd_in_data;
    reg [(MAX_COMMAND_LENGTH * 8 - 1):0] cmd_out_data;
    wire [7:0] cmd_out_data_bytes [(MAX_COMMAND_LENGTH - 1):0];
    wire [(MAX_COMMAND_LENGTH * 8 - 1):0] cmd_in_next;
    reg [(MAX_COMMAND_LENGTH * 8 - 1):0] cmd_out_next;
    
    reg [7:0] current_command;      //  ID of command currently being read or executed
    reg execution_complete;         
    wire [1:0] cmd_port;             //  The port that the current command pertains to, if applicable
    reg [3:0] execution_count;      //  Number of cycles since command execution began (if you want to use it)
    
    reg [7:0] outgoing_command;     //  Data for FX2 interface when assembling EP8 packet
    reg [15:0] outgoing_length;
    
    
    //  Instruction-specific registers
    reg register_read;
    reg register_set;
    
    //  Configuration data
    reg [7:0] cfg_data_out;
    assign cfg_data = cfg_write ? cfg_data_out : 8'hZZ;
    assign cfg_clk = clk;
    
    //  Hardware configuration registers (HWCON)
    genvar g;
    reg [7:0] hwcon [3:0];
    generate for (g = 0; g < 4; g = g + 1) begin:ports
            assign hwcons[((g + 1) * 8 - 1):(g * 8)] = hwcon[g];
        end
    endgenerate
    
    //  Assign outputs
    assign ep8_cmd_id = outgoing_command;
    assign ep8_cmd_length = outgoing_length;
    
    //  Assign next value of cmd_in_data
    generate for (g = 0; g < MAX_COMMAND_LENGTH; g = g + 1) begin:latches
            assign cmd_in_next[((g + 1) * 8 - 1):(g * 8)] = (g == read_byte_count) ? ep4_data : cmd_in_data[((g + 1) * 8 - 1):(g * 8)];
        end
    endgenerate
    
    //  Break out bytes of cmd_out_data for writing
    generate for (g = 0; g < MAX_COMMAND_LENGTH; g = g + 1) begin:breakouts
            assign cmd_out_data_bytes[g] = cmd_out_data[((g + 1) * 8 - 1):(g * 8)];
        end
    endgenerate
    
    //  Assign command port to come from the LSB of the data.
    //  This is always the case for commands that pertain to a particular port.
    //  It could be registered for more flexibility, but an additional delay would have to be
    //  introduced into the state machines.
    assign cmd_port = cmd_in_data[1:0];
    
    //  EP4 machine: writes into command_in buffer
    always @(posedge ep4_clk or posedge reset) begin
        if (reset) begin
            ep4_read <= 0;
            ep4_state <= IDLE;
            read_byte_count <= 0;
            cmd_in_data <= 0;
        end
        else begin
            case (ep4_state)
                IDLE: begin
                    if (state == READING) begin
                        ep4_state <= ACTIVE;
                        read_byte_count <= 0;
                        cmd_in_data <= 0;
                    end
                end
                
                ACTIVE: begin
                    if (ep4_ready) begin
                        ep4_read <= 1;
                    end
                    if (read_byte_count >= ep4_cmd_length) begin
                        ep4_read <= 0;
                        ep4_state <= DONE;
                    end
                    else if (ep4_read) begin
                        cmd_in_data <= cmd_in_next;
                        read_byte_count <= read_byte_count + 1;
                    end
                end
                
                DONE: begin
                    //  Move back to IDLE, but only after the main state machine recognizes 
                    //  that the read has finished.
                    if (state != READING) begin
                        ep4_state <= IDLE;
                    end
                end
            endcase
        end
    end
    
    //  EP8 machine: reads from command_out buffer
    always @(posedge ep8_clk or posedge reset) begin
        if (reset) begin
            ep8_write <= 0;
            ep8_state <= IDLE;
            write_byte_count <= 0;
            ep8_data <= 0;
            cmd_out_data <= 0;
        end
        else begin
            case (ep8_state)
                IDLE: begin
                    if (state == REPLYING) begin
                        //  If we have something to write, switch to "active."
                        if (ep8_cmd_id > 0) begin
                            ep8_state <= ACTIVE;
                            write_byte_count <= ep8_cmd_length;
                        end
                        else begin
                            ep8_state <= DONE;
                        end
                    end
                end
                
                ACTIVE: begin
                    //  Wait for a signal (ep8_ready) from the FX2 interface
                    if (ep8_ready) begin
                        if (ep8_cmd_length > 0) begin
                            ep8_write <= 1;
                            ep8_data <= cmd_out_data_bytes[ep8_cmd_length - 1];
                        end
                        else begin
                            ep8_state <= DONE;
                        end
                    end
                    //  Once the FX2 interface is ready, write to the end of the specified length.
                    if (ep8_write) begin
                        write_byte_count <= write_byte_count - 1;
                        ep8_data <= cmd_out_data_bytes[write_byte_count - 1];
                    end
                    if (write_byte_count <= 1) begin
                        ep8_data <= cmd_out_data_bytes[0];
                        ep8_state <= DONE;
                    end
                
                end
                
                DONE: begin
                    //  Move back to IDLE, but only after the main state machine recognizes 
                    //  that the write has finished.
                    ep8_write <= 0;
                    if (state != REPLYING) begin
                        ep8_state <= IDLE;
                    end
                end
            endcase
        end
    end
    
    //  Primary state machine
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= WAITING;
            
            current_command <= 0;
            outgoing_command <= 0;
            outgoing_length <= 0;
            execution_complete <= 0;
            execution_count <= 0;
            cmd_out_next <= 0;

            config_state <= INITIALIZING;
            search_started <= 0;
            cfg_data_out <= 0;
            cfg_addr <= 0;
            cfg_read <= 0;
            cfg_write <= 0;
            reg_addr <= 0;
            reg_index <= 0;
            
            register_set <= 0;
            register_read <= 0;

        end
        else begin
            //  Primary state machine
            case (state)
                WAITING: begin
                    //  Don't wait, just go to EP4 for the next command.
                    state <= READING;
                end
                
                READING: begin
                    //  Wait for an EP4 read to be performed
                    if (ep4_state == DONE) begin
                        current_command <= ep4_cmd_id;
                        execution_complete <= 0;
                        execution_count <= 0;
                        state <= EXECUTING;
                    end
                end
                
                EXECUTING: begin
                    execution_count <= execution_count + 1;
                    if (~execution_complete) begin
                        //  Do stuff based on command descriptions (see commands.txt)
                        case (current_command)
                        
                            //  Get the value for the specified register address from configuration memory
                            CMD_CONFIG_GET_REG: begin
                                if (execution_count == 0) begin
                                    //  Tell the configuration memory state machine to go look for our register
                                    reg_addr <= cmd_in_data[15:8];
                                    config_state <= INITIALIZING;
                                end
                                else if (config_state == MATCHED) begin
                                    //  Once the register is matched, send it back.
                                    if (register_read) begin
                                        outgoing_command <= CMD_DATA_REG;
                                        outgoing_length <= 2;
                                        cmd_out_data <= 0;
                                        cmd_out_data[7:0] <= cfg_data;
                                        register_read <= 0;
                                        execution_complete <= 1;
                                    end
                                    else begin
                                        register_read <= 1;
                                    end
                                end
                                else if (config_state == FAILED) begin
                                    outgoing_command <= CMD_ERROR_NOT_FOUND;
                                    outgoing_length <= 0;
                                    cmd_out_data <= 0;
                                    execution_complete <= 1;
                                end
                            end
                            
                            //  Set a register value in configuration memory, or create an entry if none exists for that address
                            CMD_CONFIG_SET_REG: begin
                                if (execution_count == 0) begin
                                    //  Tell the configuration memory state machine to go look for our register
                                    reg_addr <= cmd_in_data[15:8];
                                    config_state <= INITIALIZING;
                                end
                                else if (config_state == MATCHED) begin
                                    //  Once the register is matched, write it.
                                    cfg_addr <= 11'h400 + (cmd_port << 7) + (direction[cmd_port] << 6) + (num_channels[cmd_port] << 5) + (reg_index << 1);
                                    cfg_read <= 0;
                                    cfg_write <= 1;
                                    //  Write the last byte (LSB) of the command.
                                    cfg_data_out <= cmd_in_data[31:24];
                                    execution_complete <= 1;
                                end
                                else if (config_state == FAILED) begin
                                    //  If the register wasn't found, go ahead and write the first unused slot with no response.
                                    if (reg_index < MAX_NUM_REGISTERS) begin
                                        if (register_set) begin
                                            cfg_addr <= 11'h400 + (cmd_port << 7) + (direction[cmd_port] << 6) + (num_channels[cmd_port] << 5) + (reg_index << 1);
                                            //  Write the last byte (LSB) of the command.
                                            cfg_data_out <= cmd_in_data[31:24];
                                            execution_complete <= 1;
                                            register_set <= 0;
                                        end
                                        else begin
                                            cfg_addr <= 11'h400 + (cmd_port << 7) + (direction[cmd_port] << 6) + (num_channels[cmd_port] << 5) + (reg_index << 1) + 1;
                                            cfg_read <= 0;
                                            cfg_write <= 1;
                                            cfg_data_out[7] <= 1;
                                            cfg_data_out[6:0] <= reg_addr[6:0];
                                            register_set <= 1;
                                        end
                                    end
                                    //  Otherwise, die.
                                    else begin
                                        outgoing_command <= CMD_ERROR_NOT_FOUND;
                                        outgoing_length <= 0;
                                        cmd_out_data <= 0;
                                        execution_complete <= 1;
                                    end
                                end
                            end
                            
                            default: begin
                                //  Unrecognized command?  No biggie, just move on.
                                execution_complete <= 1;
                            end
                        endcase
                    end
                    else begin
                        //  Clear accesses to configuration memory
                        cfg_write <= 0;
                        cfg_read <= 0;
                        cfg_addr <= 0;
                        //  If stuff is done: move on, unless you have a command to write in response
                        if (outgoing_command > 0)
                            state <= REPLYING;
                        else
                            state <= WAITING;
                    end
                end

                REPLYING: begin
                    //  Wait for the reply to go out and then reset the outgoing command.
                    if ((ep8_state == DONE) && ep8_ready) begin
                        outgoing_command <= 0;
                        outgoing_length <= 0;
                        state <= WAITING;
                    end
                end
            endcase
            
            //  Configuration memory state machine
            //  Address = 0x400 + (port * 0x80) + (direction * 0x40) + (num_channels * 0x20) + 1  
            //      MSB is: used/unused flag, writable flag, 6-bit reg address
            //      LSB is the value
            if (state == EXECUTING) case (config_state)
                INITIALIZING: begin
                    cfg_read <= 1;
                    search_started <= 0;
                    //  On the first cycle, set up the first read (of the address and the used/unused flag).
                    reg_index <= 0;
                    cfg_addr <= 11'h400 + (cmd_port << 7) + (direction[cmd_port] << 6) + (num_channels[cmd_port] << 5) + 1;
                    config_state <= SEARCHING;
                end
            
                SEARCHING: begin
                    search_started <= 1;
                    if (search_started) begin
                        //  You found a match if the entry is set and has the proper address.
                        if ((cfg_data[5:0] == reg_addr[5:0]) && (cfg_data[7] == 1)) begin
                            config_state <= MATCHED;
                            //  Now read the data from the register.
                            cfg_addr <= 11'h400 + (cmd_port << 7) + (direction[cmd_port] << 6) + (num_channels[cmd_port] << 5) + (reg_index << 1);
                        end
                        //  If no match was found and the current register is set, continue counting.
                        else if (reg_index < MAX_NUM_REGISTERS && cfg_data[7] == 1) begin
                            reg_index <= reg_index + 1;
                            search_started <= 0;
                            cfg_addr <= 11'h400 + (cmd_port << 7) + (direction[cmd_port] << 6) + (num_channels[cmd_port] << 5) + ((reg_index + 1) << 1) + 1;
                        end
                        //  If you've tried all filled slots already, give up 
                        //  (but leave reg_index where it was so a new entry can be written)
                        else begin
                            config_state <= FAILED;
                        end
                    end
                end
                
                MATCHED: begin
                    //  Stay here until kicked out.  
                    //  Let the other state machine manage the configuration memory.
                    config_state <= MATCHED;
                end
                
                FAILED: begin
                    //  Stay here until kicked out.
                    config_state <= FAILED;
                end
            endcase
            else begin
                reg_index <= 0;
                cfg_read <= 0;
                config_state <= INITIALIZING;
            end
        
        end
    
    
    end
    
    
endmodule    
