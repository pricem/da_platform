
CLK0_PERIOD = 84         #  11.2896 MHz
CLK1_PERIOD = 38         #  24.576 MHz
CLK_PERIOD = 8           #  100 - 150 MHz
IFCLK_PERIOD = 20        #  48 MHz

MESSAGES_EP2 = ['\xff\x01\x00\x08abcdefg',
            '\xff\x00\x00\x05abcde',
            '\xff\x02\x00\x11abcdefghijk',
            '\xff\x03\x00\x08abcdefg']
MESSAGES_EP4 = ['\xff\x00\x00\x04ABCD',
            '\xff\x03\x00\x05ABCDE',
            '\xff\x01\x00\x02AB',
            '\xff\x02\x00\x03ABC']  
CHUNK_SIZE = 16
CHUNK_PERIOD = 32   #   Cycles of the 48 MHz IFCLK

USE_TRACE = True
USE_UNITTEST = False

