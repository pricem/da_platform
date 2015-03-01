
#   DSD1792A
#   25 individual settings
#   8 bytes
settings = {'target': 'DSD1792A',
                'registers':
                {   'ATL': {'writeable': True, 'address': 16, 'bit_min': 0, 'bit_max': 7, 'description': 'Attenuation for left channel (0 dB to -120 dB then mute)', 'choices': None, 'help': '255 = 0 dB, 15 = -120 dB, < 15 = mute'},
                    'ATR': {'writeable': True, 'address': 17, 'bit_min': 0, 'bit_max': 7, 'description': 'Attenuation for right channel (0 dB to -120 dB then mute)', 'choices': None, 'help': '255 = 0 dB, 15 = -120 dB, < 15 = mute'},
                    'ATLD': {'writeable': True, 'address': 18, 'bit_min': 7, 'bit_max': 7, 'description': 'Attenuation load control', 'choices': [(0b0, 'Do nothing'), (0b1, 'Load new values of ATL and ATR')], 'help': None},            
                    'FMT': {'writeable': True, 'address': 18, 'bit_min': 4, 'bit_max': 6, 'description': 'Audio data format', 'choices': [(0b000, '16-bit right justified'), (0b001, '20-bit right justified'), (0b010, '24-bit right justified'), (0b011, '24-bit MSB-first left-justified'), (0b100, '16-bit I2S format'), (0b101, '24-bit I2S format')], 'help': None},
                    'DMF': {'writeable': True, 'address': 18, 'bit_min': 2, 'bit_max': 3, 'description': 'De-emphasis sampling frequency', 'choices': [(0b00, 'No de-emphasis'), (0b01, '48 kHz'), (0b10, '44.1 kHz'), (0b11, '32 kHz')], 'help': None},
                    'DME': {'writeable': True, 'address': 18, 'bit_min': 1, 'bit_max': 1, 'description': 'De-emphasis filter', 'choices': [(0b0, 'Off'), (0b1, 'On')], 'help': None},
                    'MUTE': {'writeable': True, 'address': 18, 'bit_min': 0, 'bit_max': 0, 'description': 'Soft muting', 'choices': [(0b0, 'Off'), (0b1, 'On')], 'help': None},
                    'REV': {'writeable': True, 'address': 19, 'bit_min': 7, 'bit_max': 7, 'description': 'Output phase reversal', 'choices': [(0b0, 'Off'), (0b1, 'On')], 'help': None},
                    'ATS': {'writeable': True, 'address': 19, 'bit_min': 5, 'bit_max': 6, 'description': 'Rate of attenuation change', 'choices': [(0b00, 'Sampling frequency'), (0b01, '1/2 of sampling frequency'), (0b10, '1/4 of sampling frequency'), (0b11, '1/8 of sampling frequency')], 'help': None},
                    'OPE': {'writeable': True, 'address': 19, 'bit_min': 4, 'bit_max': 4, 'description': 'Audio output', 'choices': [(0b0, 'On'), (0b1, 'Off')], 'help': None},
                    'ZOE': {'writeable': True, 'address': 19, 'bit_min': 3, 'bit_max': 3, 'description': 'Zero flag pin mode for DSDL/DSDR', 'choices': [(0b0, 'Off (standard data input)'), (0b1, 'On (zero flag output)')], 'help': 'Don\'t use this'},
                    'DFMS': {'writeable': True, 'address': 19, 'bit_min': 2, 'bit_max': 2, 'description': 'Mono/stereo switch for DF bypass mode', 'choices': [(0b0, 'Mono'), (0b1, 'Stereo')], 'help': 'Only relevant when digital filter is bypassed'},
                    'FLT': {'writeable': True, 'address': 19, 'bit_min': 1, 'bit_max': 1, 'description': 'Digital filter slope', 'choices': [(0b0, 'Sharp'), (0b1, 'Slow')], 'help': None},
                    'INZD': {'writeable': True, 'address': 19, 'bit_min': 0, 'bit_max': 0, 'description': 'Infinite zero mute detection', 'choices': [(0b0, 'Disabled'), (0b1, 'Enabled')], 'help': 'Mutes outputs after 1024 sampling periods of zeros'},
                    'SRST': {'writeable': True, 'address': 20, 'bit_min': 6, 'bit_max': 6, 'description': 'Reset configuration', 'choices': [(0b0, 'Normal'), (0b1, 'Reset DSD1792 configuration')], 'help': 'Use to reset all registers'},
                    'DSD': {'writeable': True, 'address': 20, 'bit_min': 5, 'bit_max': 5, 'description': 'Audio interface mode', 'choices': [(0b0, 'PCM'), (0b1, 'DSD')], 'help': None},
                    'DFTH': {'writeable': True, 'address': 20, 'bit_min': 4, 'bit_max': 4, 'description': 'Digital filter', 'choices': [(0b0, 'Enabled'), (0b1, 'Disabled (bypass)')], 'help': None},
                    'MONO': {'writeable': True, 'address': 20, 'bit_min': 3, 'bit_max': 3, 'description': 'Mono/stereo switch', 'choices': [(0b0, 'Stereo'), (0b1, 'Mono')], 'help': None},
                    'CHSL': {'writeable': True, 'address': 20, 'bit_min': 2, 'bit_max': 2, 'description': 'Mono channel selection', 'choices': [(0b0, 'Left'), (0b1, 'Right')], 'help': None},
                    'OS': {'writeable': True, 'address': 20, 'bit_min': 0, 'bit_max': 1, 'description': 'Oversampling ratio', 'choices': [(0b00, '64x Fs'), (0b01, '32x Fs'), (0b11, '128x Fs')], 'help': 'Should be set in conjunction with sampling frequency'},
                    'DZ': {'writeable': True, 'address': 21, 'bit_min': 1, 'bit_max': 2, 'description': 'DSD zero output flag enable', 'choices': [(0b00, 'Disabled'), (0b01, 'Enable on 01010101'), (0b10, 'Enable on 10010110')], 'help': None},
                    'PCMZ': {'writeable': True, 'address': 21, 'bit_min': 0, 'bit_max': 0, 'description': 'PCM zero output flag enable', 'choices': [(0b00, 'Disabled'), (0b01, 'Enabled')], 'help': None},
                    'ZFGR': {'writeable': False, 'address': 22, 'bit_min': 1, 'bit_max': 1, 'description': 'Right channel zero output flag', 'choices': [(0b0, 'Not zero'), (0b1, 'Zero')], 'help': None},
                    'ZFGL': {'writeable': False, 'address': 22, 'bit_min': 0, 'bit_max': 0, 'description': 'Left channel zero output flag', 'choices': [(0b0, 'Not zero'), (0b1, 'Zero')], 'help': None},
                    'ID': {'writeable': False, 'address': 23, 'bit_min': 0, 'bit_max': 4, 'description': 'Device ID', 'choices': None, 'help': 'For TMDCA mode only'},
                }
            }
