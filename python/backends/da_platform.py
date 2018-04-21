
import numpy
import libusb1
import time

from backends.ezusb import EZUSBBackend


class DAPlatformBackend(EZUSBBackend):

    #   Commands
    GLOBAL_TARGET_INDEX     = 0xFF
    AUD_FIFO_WRITE          = 0x10
    AUD_FIFO_REPORT         = 0x11
    AUD_FIFO_READ           = 0x12
    CMD_FIFO_WRITE          = 0x20
    CMD_FIFO_REPORT         = 0x21
    SELECT_CLOCK            = 0x40
    DIRCHAN_READ            = 0x41
    DIRCHAN_REPORT          = 0x42
    AOVF_READ               = 0x43
    AOVF_REPORT             = 0x44
    ECHO_SEND		        = 0x45
    ECHO_REPORT			    = 0x46
    RESET_SLOTS             = 0x47
    FIFO_READ_STATUS        = 0x48
    FIFO_REPORT_STATUS      = 0x49
    UPDATE_BLOCKING         = 0x4A
    ENTER_RESET             = 0x4B
    LEAVE_RESET             = 0x4C
    STOP_SCLK               = 0x4D
    START_SCLK              = 0x4E
    CHECKSUM_ERROR		    = 0x50
    SPI_WRITE_REG			= 0x60
    SPI_READ_REG			= 0x61
    SPI_REPORT			    = 0x62
    SLOT_START_PLAYBACK     = 0x70
    SLOT_STOP_PLAYBACK      = 0x71
    SLOT_START_RECORDING    = 0x72
    SLOT_STOP_RECORDING     = 0x73
    SLOT_START_CLOCKS       = 0x74
    SLOT_STOP_CLOCKS        = 0x75
    SLOT_FMT_I2S            = 0x76
    SLOT_FMT_RJ             = 0x77
    SLOT_FMT_LJ             = 0x78
    SLOT_SET_ACON           = 0x80

    #   I2S formats
    I2S = 0
    MSB_JUSTIFIED = 1
    LSB_JUSTIFIED = 2

    def __init__(self, num_slots=4, reset=False):
        super(DAPlatformBackend, self).__init__()
        self.receive_state_global = {}
        self.receive_state_slots = [{} for i in range(num_slots)]
        for i in range(num_slots):
            for key in [DAPlatformBackend.AUD_FIFO_REPORT, DAPlatformBackend.CMD_FIFO_REPORT]:
                self.receive_state_slots[i][key] = []
        self.report_unparsed = numpy.array([], dtype=self.dtype)
        
        #   TODO: Figure out
        self.cur_slot_id = -1
        self.cur_report_id = -1
        
        if reset:
            self.reset()
            time.sleep(0.4)
    
    def receive_state_available(self, slot, key):
        return (len(self.receive_state_slots[slot][key]) > 0)
    
    def parse_msg(self, slot_id, report_id, msg):
        #   print 'parse_msg(%d, 0x%02x): %d words: %s ...' % (slot_id, report_id, msg.shape[0], msg)
        if slot_id == DAPlatformBackend.GLOBAL_TARGET_INDEX:
            if report_id not in self.receive_state_global:
                self.receive_state_global[report_id] = []
            self.receive_state_global[report_id].append(msg)
        elif slot_id >= 0:
            if report_id not in self.receive_state_slots[slot_id]:
                self.receive_state_slots[slot_id][report_id] = []
            self.receive_state_slots[slot_id][report_id].append(msg)

    def parse_report(self, new_packet):
        all_packets = numpy.concatenate([self.report_unparsed, new_packet])
        #   print 'parse_report: %s' % all_packets
        cur_index = 0
        N = all_packets.shape[0]
        parsing_valid = True
        while parsing_valid:
            parsing_valid = False
            if N > cur_index + 2:
                #   Pull out metadata
                slot_id = all_packets[cur_index]
                report_id = all_packets[cur_index + 1]
                msg_length = (all_packets[cur_index + 2] << 16) + all_packets[cur_index + 3]
                if N < cur_index + 6 + msg_length:
                    break
                msg = all_packets[cur_index + 4:cur_index + 4 + msg_length]
                checksum = (all_packets[cur_index + 4 + msg_length] << 16) + all_packets[cur_index + 5 + msg_length]
                
                #   TODO: check checksum
                
                #   Call parse function
                self.parse_msg(slot_id, report_id, msg)

                cur_index += 6 + msg_length
                parsing_valid = True
        self.report_unparsed = all_packets[cur_index:]
    
    def update_receive_state(self, timeout=100, request_size=2048):
        #   For up to 10 ms of CD audio, we need: 441 samples * 4 words/sample = ~1600
        #   That would be 8 512-byte packets.
        data = self.read(request_size, timeout=timeout)  #   , display=True
        self.parse_report(data)
        #   print 'Receive state slots: %s' % self.receive_state_slots
        
        #   Provide the number of bytes received - some loops want to see if any new data showed up
        return data.shape[0]

    def flush(self, display=False):
        """ Read from the device until there's nothing more to read.    """
        num_words = 1
        while num_words > 0:
            num_words = self.update_receive_state()
        if display:
            print 'After flushing, remainder is %d words: %s' % (self.report_unparsed.shape[0], self.report_unparsed)

    def pop_report_global(self, report_id):
        return self.receive_state_global[report_id].pop(0)
