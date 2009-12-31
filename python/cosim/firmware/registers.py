""" Documentation and storage of all configurable settings for converter board. 

There are many settings controlling operation of the audio converters.  Each converter chip exposes
its own feature set through registers that are each broken down into single- or multi-bit values.
There is also an 8-bit parallel hardware configuration value that can be set for each of the 4 ports.

I/O modules that moderate communication between the audio buffers and converter chips also have
registers.  These values must be linked to the configuration of the converters themselves, since
they relate to clock selection, data size and format, oversampling ratio, etc.

To handle this issue, registers with the same name will be simultaneously updated to have the same
value.  So you can define a hardware register 'FOO' with some address and bit range, and also an 
I/O module register 'FOO' with a different address and bit range.  The two (or more) registers will only
show up once to the user and are treated identically.  Only one instance of the register should define
the 'description' and 'choices' keys.

Hooks for checking constraints on register values (i.e. can't use X oversampling with Y clock)
have not yet been added.

Other software code changing settings for audio playback is responsible for updating the appropriate
registers.
"""

settings_hwreg = [
#   DSD1792A
            {'target': 'DSD1792A 2-channel DAC',
                'registers':
                {   'ATL': {'address': 16, 'bit_min': 0, 'bit_max': 7, 'description': 'Attenuation for left channel (0 dB to -120 dB then mute)', 'choices': None, 'help': '255 = 0 dB, 15 = -120 dB, < 15 = mute'},
                    'ATR': {'address': 17, 'bit_min': 0, 'bit_max': 7, 'description': 'Attenuation for right channel (0 dB to -120 dB then mute)', 'choices': None, 'help': '255 = 0 dB, 15 = -120 dB, < 15 = mute'},
                    'ATLD': {'address': 18, 'bit_min': 7, 'bit_max': 7, 'description': 'Attenuation load control', 'choices': [(0b0, 'Do nothing'), (0b1, 'Load new values of ATL and ATR')], 'help': None},            
                    'FMT': {'address': 18, 'bit_min': 4, 'bit_max': 6, 'description': 'Audio data format', 'choices': [(0b000, '16-bit right justified'), (0b001, '20-bit right justified'), (0b010, '24-bit right justified'), (0b011, '24-bit MSB-first left-justified'), (0b100, '16-bit I2S format'), (0b101, '24-bit I2S format')], 'help': None},
                    'DMF': {'address': 18, 'bit_min': 2, 'bit_max': 3, 'description': 'De-emphasis sampling frequency', 'choices': [(0b00, 'No de-emphasis'), (0b01, '48 kHz'), (0b10, '44.1 kHz'), (0b11, '32 kHz')], 'help': None},
                    'DME': {'address': 18, 'bit_min': 1, 'bit_max': 1, 'description': 'De-emphasis filter', 'choices': [(0b0, 'Off'), (0b1, 'On')], 'help': None},
                    'MUTE': {'address': 18, 'bit_min': 0, 'bit_max': 0, 'description': 'Soft muting', 'choices': [(0b0, 'Off'), (0b1, 'On')], 'help': None},
                    'REV': {'address': 19, 'bit_min': 7, 'bit_max': 7, 'description': 'Output phase reversal', 'choices': [(0b0, 'Off'), (0b1, 'On')], 'help': None},
                    'ATS': {'address': 19, 'bit_min': 5, 'bit_max': 6, 'description': 'Rate of attenuation change', 'choices': [(0b00, 'Sampling frequency'), (0b01, '1/2 of sampling frequency'), (0b10, '1/4 of sampling frequency'), (0b11, '1/8 of sampling frequency')], 'help': None},
                    'OPE': {'address': 19, 'bit_min': 4, 'bit_max': 4, 'description': 'Audio output', 'choices': [(0b0, 'On'), (0b1, 'Off')], 'help': None},
                    'ZOE': {'address': 19, 'bit_min': 3, 'bit_max': 3, 'description': 'Zero flag pin mode for DSDL/DSDR', 'choices': [(0b0, 'Off (standard data input)'), (0b1, 'On (zero flag output)')], 'help': 'Don\'t use this'},
                    'DFMS': {'address': 19, 'bit_min': 2, 'bit_max': 2, 'description': 'Mono/stereo switch for DF bypass mode', 'choices': [(0b0, 'Mono'), (0b1, 'Stereo')], 'help': 'Only relevant when digital filter is bypassed'},
                    'FLT': {'address': 19, 'bit_min': 1, 'bit_max': 1, 'description': 'Digital filter slope', 'choices': [(0b0, 'Sharp'), (0b1, 'Slow')], 'help': None},
                    'INZD': {'address': 19, 'bit_min': 0, 'bit_max': 0, 'description': 'Infinite zero mute detection', 'choices': [(0b0, 'Disabled'), (0b1, 'Enabled')], 'help': 'Mutes outputs after 1024 sampling periods of zeros'},
                    'SRST': {'address': 20, 'bit_min': 6, 'bit_max': 6, 'description': 'Reset configuration', 'choices': [(0b0, 'Normal'), (0b1, 'Reset DSD1792 configuration')], 'help': 'Use to reset all registers'},
                    'DSD': {'address': 20, 'bit_min': 5, 'bit_max': 5, 'description': 'Audio interface mode', 'choices': [(0b0, 'PCM'), (0b1, 'DSD')], 'help': None},
                    'DFTH': {'address': 20, 'bit_min': 4, 'bit_max': 4, 'description': 'Digital filter', 'choices': [(0b0, 'Enabled'), (0b1, 'Disabled (bypass)')], 'help': None},
                    'MONO': {'address': 20, 'bit_min': 3, 'bit_max': 3, 'description': 'Mono/stereo switch', 'choices': [(0b0, 'Stereo'), (0b1, 'Mono')], 'help': None},
                    'CHSL': {'address': 20, 'bit_min': 2, 'bit_max': 2, 'description': 'Mono channel selection', 'choices': [(0b0, 'Left'), (0b1, 'Right')], 'help': None},
                    'OS': {'address': 20, 'bit_min': 0, 'bit_max': 1, 'description': 'Oversampling ratio', 'choices': [(0b00, '64x Fs'), (0b01, '32x Fs'), (0b11, '128x Fs')], 'help': 'Should be set in conjunction with sampling frequency'},
                    'DZ': {'address': 21, 'bit_min': 1, 'bit_max': 2, 'description': 'DSD zero output flag enable', 'choices': [(0b00, 'Disabled'), (0b01, 'Enable on 01010101'), (0b10, 'Enable on 10010110')], 'help': None},
                    'PCMZ': {'address': 21, 'bit_min': 0, 'bit_max': 0, 'description': 'PCM zero output flag enable', 'choices': [(0b00, 'Disabled'), (0b01, 'Enabled')], 'help': None},
                    'ZFGR': {'address': 22, 'bit_min': 1, 'bit_max': 1, 'description': 'Right channel zero output flag', 'choices': [(0b0, 'Not zero'), (0b1, 'Zero')], 'help': None},
                    'ZFGL': {'address': 22, 'bit_min': 0, 'bit_max': 0, 'description': 'Left channel zero output flag', 'choices': [(0b0, 'Not zero'), (0b1, 'Zero')], 'help': None},
                    'ID': {'address': 23, 'bit_min': 0, 'bit_max': 4, 'description': 'Device ID', 'choices': None, 'help': 'For TMDCA mode only'},
                }
            },

#   AD1934
            {'target': 'AD1934 8-channel DAC',
             'registers': {
             
                }
            },
            
#   AD1974 
            {'target': 'AD1974 8-channel ADC',
             'registers': {
             
                }
            },
        ]
        
        
""" Settings for HWCON registers. """
settings_hwreg = [
#   PCM4202
        {'target': 'PCM4202 2-channel ADC',
         'registers': {
         
            }
        }
    ]

""" Settings for I/O modules. """
settings_ioreg = [
#   DSD1792A
        {'target': 'DSD1792A 2-channel DAC',
         'registers':
            {
                'DSD': {'address': 20, 'bit_min': 5, 'bit_max': 5},     #   (1) Whether to use DSD (and hence present DSD format data on DSDL/DSDR)
                'FMT': {'address': 18, 'bit_min': 4, 'bit_max': 6},     #   (2) Format (left justified, right justified, I2S)
                'DFTH': {'address': 20, 'bit_min': 4, 'bit_max': 4},    #   (1) Whether to use the DSD1792's digital filter (fixed 8x oversampling) or not
                'DFMS': {'address': 19, 'bit_min': 2, 'bit_max': 2},    #   (1) Whether to use mono (PDATA) or stereo (DSDL/DSDR) when digital filter is off
                'CLKS': {},                                             #   (2) Base audio rate: 44.1, 48, 88.2, 96, 192 kHz 
                'OSR': {},                                              #   (2) Fs multiplier exponent: 1, 2, 4, 8 (for external oversampling)
            }
        },
        
#   PCM4202
        {'target': 'PCM4202 2-channel ADC',
         'registers': {
         
            }
        },
        
#   AD1934
        {'target': 'AD1934 8-channel DAC',
         'registers': {
         
            }
        },
            
#   AD1974 
        {'target': 'AD1974 8-channel ADC',
         'registers': {
         
            }
        },
    ]
    
