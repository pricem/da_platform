
CLK0_PERIOD = 84         #  11.2896 MHz
CLK1_PERIOD = 38         #  24.576 MHz
CLK_PERIOD = 8           #  100 - 150 MHz
IFCLK_PERIOD = 20        #  48 MHz

SIM_LENGTH = 500        #   Length of simulation in clk (100 - 150 MHz) cycles

MESSAGES_EP2 = ['\xff\x02\x00\x0babcdefghijk',
                '\xff\x00\x00\x06abcdef',
                '\xff\x03\x00\x08abcdefgh',
                '\xff\x01\x00\x07abcdefg',
            ]
MESSAGES_EP4 = ['\xff\x00\x00\x04ABCD',             #   Invalid command should be ignored
                '\xff\x31\x00\x02\x01\x54',         #   Get register: port 1, address 0x14 (should return error)
                '\xff\x32\x00\x04\x01\x54\x00\x35', #   Write register (port 1 address 0x14) value 0x35
                '\xff\x32\x00\x04\x01\x47\x00\x46', #   Write register (port 1 address 0x07) value 0x46
                '\xff\x31\x00\x02\x01\x54',         #   Get register: port 1, address 0x14 (should return 0x35)
                '\xff\x31\x00\x02\x01\x47',         #   Get register: port 1, address 0x07 (should return 0x46)
                '\xff\x32\x00\x04\x02\x47\x00\x64', #   Write register (port 2 address 0x07) value 0x64
                '\xff\x31\x00\x02\x02\x47',         #   Get register: (port 2 address 0x07) should return 0x64
            ]  
CHUNK_SIZE = 16
CHUNK_PERIOD = 24   #   Cycles of the 48 MHz IFCLK

USE_TRACE = True
USE_UNITTEST = False
FX2_VERBOSITY = False

