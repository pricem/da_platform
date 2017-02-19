
import numpy
from datetime import datetime

from backends.da_platform import DAPlatformBackend

class ModuleBase(object):

    def __init__(self, backend):
        self.backend = backend
        self.backend.flush()
        
    def transaction(self, cmd, num_words):
        self.backend.write(cmd)
        self.backend.update_receive_state()
        #   return self.backend.read(num_words)
    
    def prepare_cmd(self, destination, cmd, data):
        data = data.flatten()
        N = data.shape[0]
        checksum = numpy.sum(data)
        msg = numpy.zeros((N + 6,), dtype=self.backend.dtype)
        msg[0] = destination
        msg[1] = cmd
        msg[2] = N / 65536
        msg[3] = N % 65536
        msg[4:4+N] = data
        msg[4+N] = checksum / 65536
        msg[5+N] = checksum % 65536
        return msg
        
    def get_dirchan(self):
        self.transaction(numpy.array([0xFF, 0x41], dtype=self.backend.dtype), 3)
        dval = self.backend.pop_report_global(DAPlatformBackend.DIRCHAN_REPORT)[0]
        for slot in range(4):
            dirslot = 1 * ((dval & (1 << slot)) > 0)
            chanslot = 1 * ((dval & (1 << (slot + 4))) > 0)
            print 'Slot %d: Direction = %d, Channels = %d' % (slot, dirslot, chanslot)
            #	print 'Result of get_dirchan = %s' % self.pprint(result)

    def get_aovf(self):
        result = self.transaction(numpy.array([0xFF, 0x43], dtype=self.backend.dtype), 3)
        dval = self.backend.pop_report_global(DAPlatformBackend.AOVF_REPORT)[0]
        for slot in range(4):
            ovfl = 1 * ((dval & (1 << (slot * 2))) > 0)
            ovfr = 1 * ((dval & (1 << (slot * 2 + 1))) > 0)
            print 'Slot %d: Left overflow = %d, right overflow = %d' % (slot, ovfl, ovfr)
            #	print 'Result of get_aovf = %s' % self.pprint(result)

    def reset_slots(self):
        self.backend.write(numpy.array([0xFF, DAPlatformBackend.RESET_SLOTS], dtype=self.backend.dtype))

    def spi_write(self, slot, addr_size, data_size, addr, data):
        config_word = (addr_size << 1) + data_size
        msg = numpy.array([DAPlatformBackend.SPI_WRITE_REG, config_word, addr / 256, addr % 256, data / 256, data % 256], dtype=self.backend.dtype)
        cmd = self.prepare_cmd(slot, DAPlatformBackend.CMD_FIFO_WRITE, msg)
        self.backend.write(cmd)
        #print 'Wrote command for SPI write: %s' % cmd

    def spi_read(self, slot, addr_size, data_size, addr, add_offset=True):
        #   Previous version added 0x80 to address to force a read.  But not all peripherals need this.
        if add_offset:
            addr += 0x80
        config_word = (addr_size << 1) + data_size
        msg = numpy.array([DAPlatformBackend.SPI_READ_REG, config_word, addr / 256, addr % 256], dtype=self.backend.dtype)
        cmd = self.prepare_cmd(slot, DAPlatformBackend.CMD_FIFO_WRITE, msg)
        #print 'Wrote command for SPI read: %s' % cmd
        self.transaction(cmd, 100)
        
        data = self.backend.receive_state_slots[slot][DAPlatformBackend.CMD_FIFO_REPORT][0]
        #print data
        assert data[0] == DAPlatformBackend.SPI_REPORT
        #assert data[2] == addr + 0x80
        result = data[4]
        self.backend.receive_state_slots[slot][DAPlatformBackend.CMD_FIFO_REPORT].pop(0)
        
        #print 'Got response for SPI read: %s' % data
        return result

    def start_playback(self, slot):
        msg = numpy.array([DAPlatformBackend.SLOT_START_PLAYBACK, 0], dtype=self.backend.dtype)
        self.backend.write(self.prepare_cmd(slot, DAPlatformBackend.CMD_FIFO_WRITE, msg))
    
    def stop_playback(self, slot):
        msg = numpy.array([DAPlatformBackend.SLOT_STOP_PLAYBACK, 0], dtype=self.backend.dtype)
        self.backend.write(self.prepare_cmd(slot, DAPlatformBackend.CMD_FIFO_WRITE, msg))
    
    def start_recording(self, slot):
        msg = numpy.array([DAPlatformBackend.SLOT_START_RECORDING, 0], dtype=self.backend.dtype)
        self.backend.write(self.prepare_cmd(slot, DAPlatformBackend.CMD_FIFO_WRITE, msg))
    
    def stop_recording(self, slot):
        msg = numpy.array([DAPlatformBackend.SLOT_STOP_RECORDING, 0], dtype=self.backend.dtype)
        self.backend.write(self.prepare_cmd(slot, DAPlatformBackend.CMD_FIFO_WRITE, msg))
    
    def block_slots(self):
        self.backend.write(numpy.array([0xFF, 0x4A, 0x00], dtype=self.backend.dtype))
    
    def unblock_slots(self):
        self.backend.write(numpy.array([0xFF, 0x4A, 0x0F], dtype=self.backend.dtype))
    
    def set_acon(self, slot, val):
        msg = numpy.array([DAPlatformBackend.SLOT_SET_ACON, val], dtype=self.backend.dtype)
        self.backend.write(self.prepare_cmd(slot, DAPlatformBackend.CMD_FIFO_WRITE, msg))
    
    def fifo_status(self, display=False):
        self.backend.write(numpy.array([0xFF, 0x48, 0x00], dtype=self.backend.dtype))
        data = self.backend.read(38)
        status = data[4:36].byteswap().view(numpy.uint32).byteswap().reshape((8, 2))
        if display:
            print 'DRAM FIFO status:'
            for i in range(8):
                if status[i, 0] != 0 or status[i, 1] != 0:
                    print '  Port %d: Wrote %d samples, read %d samples' % (i, status[i, 0], status[i, 1])
        
        return status
    
    def audio_write_float(self, slot, data):
        data_int = (data * (1 << 24)).astype(numpy.int32)
        self.audio_write(slot, data_int)
        return data_int
    
    def audio_write(self, slot, data):
        #   2 byteswaps accomplishes a word-swap while preserving byte order within words
        #   print [hex(x) for x in data[:8]]
        start_time = datetime.now()
        msg = numpy.fromstring(data.byteswap().tostring(), dtype=self.backend.dtype).byteswap()
        self.backend.write(self.prepare_cmd(slot, DAPlatformBackend.AUD_FIFO_WRITE, msg))
        #   print 'Wrote %d samples in %.2f ms' % (data.shape[0], get_elapsed_time(start_time) * 1e3)
    
    def audio_read(self, slot, num_samples, perform_update=True, timeout=100):
        #   Timeout is in ms
        #   TODO: Make much smarter
        
        start_time = datetime.now()
        words_received = numpy.sum([x.shape[0] for x in self.backend.receive_state_slots[slot][DAPlatformBackend.AUD_FIFO_REPORT]])
        samples_received = int(words_received / 2)
        #   print 'Samples previously received = %d' % samples_received
        
        if perform_update:
            time_float = 0
            while samples_received < num_samples and time_float < 1e-3 * timeout:
            
                samples_needed = num_samples - samples_received
            
                #   Now we have to send a command to the device to get it to send us audio
                msg = numpy.array([slot, DAPlatformBackend.AUD_FIFO_READ, samples_needed / 65536, samples_needed % 65536], dtype=numpy.uint16)
                self.backend.write(msg)
                num_words = samples_needed * 2 + 6
                self.backend.update_receive_state(request_size=num_words, timeout=timeout)
                time_float = get_elapsed_time(start_time)
                words_received = numpy.sum([x.shape[0] for x in self.backend.receive_state_slots[slot][DAPlatformBackend.AUD_FIFO_REPORT]])
                samples_received = int(words_received / 2)
                #   print 'Got to %d samples from %d words in %.2f ms' % (samples_received, num_words, (time_float * 1e3))
        
        if self.backend.receive_state_available(slot, DAPlatformBackend.AUD_FIFO_REPORT):
            all_data = numpy.concatenate(self.backend.receive_state_slots[slot][DAPlatformBackend.AUD_FIFO_REPORT])
            data = all_data[:num_samples * 2]
            other_data = all_data[num_samples * 2:]
            #   Save leftover samples back into receive state
            self.backend.receive_state_slots[slot][DAPlatformBackend.AUD_FIFO_REPORT] = [other_data,]
            
            #   Convert to integer
            #data = numpy.fromstring(data.byteswap().tostring(), dtype=numpy.int32).byteswap()
            data = numpy.fromstring(data.tostring(), dtype=numpy.int32)
        else:
            data = numpy.array([], dtype=numpy.int32)

        return data
        
