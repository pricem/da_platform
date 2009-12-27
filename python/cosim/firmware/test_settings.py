
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
MESSAGES_EP4 = ['\xff\x00\x00\x04ABCD',
                '\xff\x03\x00\x05ABCDE',
                '\xff\x01\x00\x02AB',
                '\xff\x02\x00\x03ABC',
            ]  
CHUNK_SIZE = 16
CHUNK_PERIOD = 24   #   Cycles of the 48 MHz IFCLK

USE_TRACE = True
USE_UNITTEST = False

