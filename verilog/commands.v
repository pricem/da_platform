//  `timescale 1ns / 1ps

/*
    Command format:
    - Byte 0 = slot target index
      If this matches GLOBAL_TARGET_INDEX then the command does not pertain to a slot.
    - Byte 1 = command ID
      This selects from one of the options below.
    - Bytes 2 to N - 1 = command-specific data
*/

//  Global constants
localparam GLOBAL_TARGET_INDEX   = 8'hFF;

//  Commands pertaining to audio data
localparam AUD_FIFO_WRITE        = 8'h10;
localparam AUD_FIFO_REPORT       = 8'h11;

//  Commands pertaining to command data
localparam CMD_FIFO_WRITE        = 8'h20;
localparam CMD_FIFO_REPORT       = 8'h21;

//  Global control commands
localparam SELECT_CLOCK          = 8'h40;
localparam DIRCHAN_READ          = 8'h41;
localparam DIRCHAN_REPORT        = 8'h42;
localparam AOVF_READ             = 8'h43;
localparam AOVF_REPORT           = 8'h44;
localparam ECHO_SEND				= 8'h45;
localparam ECHO_REPORT			= 8'h46;

//  Errors
localparam CHECKSUM_ERROR		= 8'h50;

//  Slot-specific commands
localparam SPI_WRITE_REG			= 8'h60;
localparam SPI_READ_REG			= 8'h61;
localparam SPI_REPORT			= 8'h62;

localparam SLOT_START_PLAYBACK = 8'h70;
localparam SLOT_STOP_PLAYBACK = 8'h71;
localparam SLOT_START_RECORDING = 8'h72;
localparam SLOT_STOP_RECORDING = 8'h73;

//  TODO: Digital filtering control

