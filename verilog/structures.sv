
typedef struct packed {
    logic read_not_write;
    logic [31:0] address;
    logic [31:0] length;
} MemoryCommand;

typedef enum logic [1:0] { DAC2, ADC2, DAC8, ADC8 } SlotMode;
