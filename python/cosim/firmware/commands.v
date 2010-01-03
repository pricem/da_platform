/*  Header file: Command definitions

Each command has an 8-bit ID.  Commands from 0x00 to 0x7F are imperative,
meaning that an action (sometimes including a reply) is expected.  Commands
from 0x80 to 0xFF are status or informational messages.  The description
and data format for each command is documented in commands.txt.
*/

//  Meta commands
parameter CMD_META_SELECT_SOURCE = 8'h01;
parameter CMD_META_GET_SOURCE = 8'h02;
parameter CMD_META_NEXT_SOURCE = 8'h03;

//  Seek commands
parameter CMD_SEEK_SELECT_TRACK = 8'h10;
parameter CMD_SEEK_PREV_TRACK = 8'h11;
parameter CMD_SEEK_NEXT_TRACK = 8'h12;
parameter CMD_SEEK_SELECT_PLAYLIST = 8'h13;
parameter CMD_SEEK_PREV_PLAYLIST = 8'h14;
parameter CMD_SEEK_NEXT_PLAYLIST = 8'h15;
parameter CMD_SEEK_FAST_FORWARD = 8'h16;
parameter CMD_SEEK_FAST_REWIND = 8'h17;
parameter CMD_SEEK_SELECT_TIME = 8'h18;

//  Power management commands
parameter CMD_POWER_STANDBY = 8'h20;
parameter CMD_POWER_SHUTDOWN = 8'h21;
parameter CMD_POWER_WAKEUP = 8'h22;

//  Configuration commands
parameter CMD_CONFIG_GET_ALL = 8'h30;
parameter CMD_CONFIG_GET_REG = 8'h31;
parameter CMD_CONFIG_SET_REG = 8'h32;
parameter CMD_CONFIG_GET_HWCON = 8'h33;
parameter CMD_CONFIG_SET_HWCON = 8'h34;
parameter CMD_CONFIG_GET_IOREG = 8'h35;
parameter CMD_CONFIG_SET_IOREG = 8'h36;

//  Synchronization commands
parameter CMD_SYNC_GET_TIMEBASE = 8'h40;
parameter CMD_SYNC_SET_TIMEBASE = 8'h41;
parameter CMD_SYNC_FLUSH = 8'h42;

//  Status with respect to timing and data rates
parameter CMD_STATUS_TIMEBASE = 8'h81;

//  Register read values
parameter CMD_DATA_REG = 8'h90;
parameter CMD_DATA_HWCON = 8'h91;
parameter CMD_DATA_IOREG = 8'h92;

//  Other status
parameter CMD_INFO_SOURCE = 8'hA0;

//  Error codes
parameter CMD_ERROR_NOT_FOUND = 8'hF0;
