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
    //  Outputs 
    hwcons,
    //  Crapload of other stuff
    //  [TBD]
    //  System-wide control
    clk, reset
    );
    
    //  EP4 port: The FX2 interface drives the clock but this controller 
    //  (running at a faster rate) polls and reads it as necessary
    input ep4_clk;
    input [7:0] ep4_cmd_id;
    input [15:0] ep4_cmd_length;
    input ep4_ready;
    output ep4_read;
    input [7:0] ep4_data;
    
    //  EP8 port: The FX2 interface drives the clock but this controller
    //  (running faster) polls and writes it as necessary
    input ep8_clk;
    output [7:0] ep8_cmd_id;
    output [15:0] ep8_cmd_length;
    input ep8_ready;
    output ep8_write;
    output [7:0] ep8_data;

    //  Configuration memory: The controller reads/writes one port of a 
    //  standard dual-port RAM.
    output cfg_clk;
    output [10:0] cfg_addr;
    inout [7:0] cfg_data;
    output cfg_write;
    output cfg_read;
    
    //  Hardware configuration: An 8-bit register for each port
    output [31:0] hwcons;
    
    //  Control stuff
    input clk;
    input reset;
    
    //  States
    reg [1:0] state;                //  Outer state
    parameter WAITING = 2'b00;
    parameter READING = 2'b01;
    parameter EXECUTING = 2'b10;
    parameter REPLYING = 2'b11;
    
    reg [7:0] read_byte_count;      //  Number of bytes read from FX2 interface on EP4
    
    reg [7:0] current_command;      //  ID of command currently being read or executed
    
    reg [7:0] outgoing_command;     //  Data for FX2 interface when assembling EP8 packet
    reg [15:0] outgoing_length;
    
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
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= WAITING;
            read_byte_count <= 0;
            current_command <= 0;
            outgoing_command <= 0;
            outgoing_length <= 0;
        end
        else begin
            case (state)
                WAITING: state <= READING;
                READING: state <= EXECUTING;
                EXECUTING: state <= REPLYING;
                REPLYING: state <= WAITING;
            endcase
        
        end
    
    
    end
    
    
endmodule    
