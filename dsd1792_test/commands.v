
/*
    Command format:
    - Byte 0 = slot target index
      If this matches GLOBAL_TARGET_INDEX then the command does not pertain to a slot.
    - Byte 1 = command ID
      This selects from one of the options below.
    - Bytes 2 to N - 1 = command-specific data
*/

//  Global constants
parameter GLOBAL_TARGET_INDEX   = 8'hFF;

//  Commands pertaining to audio data
parameter AUD_FIFO_WRITE        = 8'h10;
parameter AUD_FIFO_REPORT       = 8'h11;

//  Commands pertaining to command data
parameter CMD_FIFO_WRITE        = 8'h20;
parameter CMD_FIFO_REPORT       = 8'h21;

//  Global control commands
parameter SELECT_CLOCK          = 8'h40;
parameter DIRCHAN_READ          = 8'h41;
parameter DIRCHAN_REPORT        = 8'h42;
parameter AOVF_READ             = 8'h43;
parameter AOVF_REPORT           = 8'h44;
parameter ECHO_SEND				= 8'h45;
parameter ECHO_REPORT			= 8'h46;

//  Errors
parameter CHECKSUM_ERROR		= 8'h50;

//  Slot-specific commands
parameter SPI_WRITE_REG			= 8'h60;
parameter SPI_READ_REG			= 8'h61;
parameter SPI_REPORT			= 8'h62;

//  TODO: Digital filtering control
