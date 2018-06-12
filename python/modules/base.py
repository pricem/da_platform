"""
    Open-source digital audio platform
    Copyright (C) 2009--2018 Michael Price

    base.py: Base class for module support.  Includes most of the functions
    needed to communicate with modules (audio, SPI, etc.) via the FPGA.
    When you implement a Python class for a new DAC/ADC module, it should
    inherit from the ModuleBase class defined here.  This should help avoid
    reinventing the wheel.
    
    Warning: Use and distribution of this code is restricted.
    This software code is distributed under the terms of the GNU General Public
    License, version 3.  Other files in this project may be subject to
    different licenses.  Please see the LICENSE file in the top level project
    directory for more information.
"""

import numpy
from datetime import datetime
import time

from backends.da_platform import DAPlatformBackend
from utils import get_elapsed_time

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
        dir_vals = numpy.zeros((4,), dtype=bool)
        chan_vals = numpy.zeros((4,), dtype=bool)
        for slot in range(4):
            dirslot = 1 * ((dval & (1 << slot)) > 0)
            chanslot = 1 * ((dval & (1 << (slot + 4))) > 0)
            print 'Slot %d: Direction = %d, Channels = %d' % (slot, dirslot, chanslot)
            dir_vals[slot] = dirslot
            chan_vals[slot] = chanslot
            #	print 'Result of get_dirchan = %s' % self.pprint(result)
        return (dir_vals, chan_vals)

    def num_channels(self):
        #   TODO: Should be able to figure this out from dir/chan
        raise NotImplementedError

    def get_aovf(self):
        result = self.transaction(numpy.array([0xFF, 0x43], dtype=self.backend.dtype), 3)
        dval = self.backend.pop_report_global(DAPlatformBackend.AOVF_REPORT)[0]
        for slot in range(4):
            ovfl = 1 * ((dval & (1 << (slot * 2))) > 0)
            ovfr = 1 * ((dval & (1 << (slot * 2 + 1))) > 0)
            print 'Slot %d: Left overflow = %d, right overflow = %d' % (slot, ovfl, ovfr)
            #	print 'Result of get_aovf = %s' % self.pprint(result)
    
    def select_clock(self, clksel):
        cmd = numpy.array([0xFF, 0x40, clksel], dtype=self.backend.dtype)
        self.backend.write(cmd)
        print 'Wrote command for clock select: %s' % cmd

    def stop_sclk(self):
        self.backend.write(numpy.array([0xFF, DAPlatformBackend.STOP_SCLK], dtype=self.backend.dtype))

    def start_sclk(self):
        self.backend.write(numpy.array([0xFF, DAPlatformBackend.START_SCLK], dtype=self.backend.dtype))

    def reset_slots(self):
        self.backend.write(numpy.array([0xFF, DAPlatformBackend.RESET_SLOTS], dtype=self.backend.dtype))

    def enter_reset(self):
        self.backend.write(numpy.array([0xFF, DAPlatformBackend.ENTER_RESET], dtype=self.backend.dtype))
        
    def leave_reset(self):
        self.backend.write(numpy.array([0xFF, DAPlatformBackend.LEAVE_RESET], dtype=self.backend.dtype))

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

    def single_byte_msg(self, slot, cmd):
        msg = numpy.array([cmd, 0], dtype=self.backend.dtype)
        self.backend.write(self.prepare_cmd(slot, DAPlatformBackend.CMD_FIFO_WRITE, msg))

    def start_playback(self, slot):
        self.single_byte_msg(slot, DAPlatformBackend.SLOT_START_PLAYBACK)
    
    def stop_playback(self, slot):
        self.single_byte_msg(slot, DAPlatformBackend.SLOT_STOP_PLAYBACK)
    
    def start_recording(self, slot):
        self.single_byte_msg(slot, DAPlatformBackend.SLOT_START_RECORDING)
    
    def stop_recording(self, slot):
        self.single_byte_msg(slot, DAPlatformBackend.SLOT_STOP_RECORDING)
    
    def stop_clocks(self, slot):
        self.single_byte_msg(slot, DAPlatformBackend.SLOT_STOP_CLOCKS)

    def start_clocks(self, slot):
        self.single_byte_msg(slot, DAPlatformBackend.SLOT_START_CLOCKS)

    def set_sample_rate(self, slot, rate):

        #   Wait for all samples to be played at the current sample rate.
        #   Doesn't do anything about recording--this is a possible future issue.
        fifo_flushed = False
        while not fifo_flushed:
            status = self.fifo_status()[slot]
            if status[0] != status[1]:
                time.sleep(0.05)
            else:
                fifo_flushed = True

        #   Select between 22.5792 MHz vs. 24.576 MHz master clock,
        #   then set the clock divide ratio.
        #   Currently supports 44.1/88.2/176.4 and 48/96/192 kHz sample rates.
        rate = int(rate)
        if rate % 44100 == 0:
            self.select_clock(0)
            rate_base = 44100
        elif rate % 48000 == 0:
            self.select_clock(1)
            rate_base = 48000
        else:
            raise Exception('Sample rate %s is not currently supported' % rate)

        if rate / rate_base == 1:
            self.set_clock_divider(slot, 512)
        elif rate / rate_base == 2:
            self.set_clock_divider(slot, 256)
        elif rate / rate_base == 4:
            self.set_clock_divider(slot, 128)
        else:
            raise Exception('Sample rate %s is not currently supported' % rate)

    def set_clock_divider(self, slot, clk_ratio):
        msg = numpy.array([DAPlatformBackend.SLOT_SET_CLK_RATIO, clk_ratio >> 8, clk_ratio & 0xFF], dtype=self.backend.dtype)
        self.backend.write(self.prepare_cmd(slot, DAPlatformBackend.CMD_FIFO_WRITE, msg))
        print 'Set clock divider for slot %d to %d' % (slot, clk_ratio)

    def set_format(self, slot, fmt):
        if fmt == DAPlatformBackend.I2S: self.single_byte_msg(slot, DAPlatformBackend.SLOT_FMT_I2S)
        elif fmt == DAPlatformBackend.MSB_JUSTIFIED: self.single_byte_msg(slot, DAPlatformBackend.SLOT_FMT_LJ)
        elif fmt == DAPlatformBackend.LSB_JUSTIFIED: self.single_byte_msg(slot, DAPlatformBackend.SLOT_FMT_RJ)
        
    def block_slots(self):
        self.backend.write(numpy.array([0xFF, 0x4A, 0x00], dtype=self.backend.dtype))
    
    def unblock_slots(self):
        self.backend.write(numpy.array([0xFF, 0x4A, 0x0F], dtype=self.backend.dtype))
    
    def set_hwcon(self, slot, val):
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
    
    def get_available_audio(self, slot, num_samples):
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
        
        return self.get_available_audio(slot, num_samples)

    def audio_read_write(self, slot_dac, slot_adc, samples, num_read_samples, timeout=100):
        #   11/17/2017: Try using async libusb.  Bypass receive state... (dangerous, one slot only)
        data_out = numpy.fromstring(samples.byteswap().tostring(), dtype=self.backend.dtype).byteswap()
        msg_out_1 = self.prepare_cmd(slot_dac, DAPlatformBackend.AUD_FIFO_WRITE, data_out)
        
        if num_read_samples > 0:
            #   No checksum on audio read cmd?
            msg_out_2 = numpy.array([slot_adc, DAPlatformBackend.AUD_FIFO_READ, num_read_samples / 65536, num_read_samples % 65536], dtype=numpy.uint16)
            #cmd_args_out = numpy.array([samples.size / 65536, samples.size % 65536], dtype=numpy.uint16)
            #msg_out_2 = self.prepare_cmd(slot_adc, DAPlatformBackend.AUD_FIFO_READ, cmd_args_out)
            msg_out = numpy.concatenate((msg_out_1, msg_out_2))
            
            use_async = True    #   Can also put in sync blocking mode with same data
            if use_async:
                data_received = self.backend.read_and_write(msg_out, num_read_samples * 2 + 6)
                self.backend.parse_report(data_received)
            else:
                self.backend.write(msg_out)
                self.backend.update_receive_state(request_size=num_read_samples * 2 + 6, timeout=timeout)

        else:
            self.backend.write(msg_out_1)

        return self.get_available_audio(slot_adc, num_read_samples)
    
    def setup(self, *args, **kwargs):
        #   Can be overridden by subclasses
        pass

