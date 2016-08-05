typedef struct packed {
    logic read_not_write;
    logic [31:0] address;
    logic [31:0] length;
} MemoryCommand;
