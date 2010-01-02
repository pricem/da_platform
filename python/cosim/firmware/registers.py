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


""" Todo:
- give registers priority and groups (express in different structure?)
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
                    #   PLL/Clock control 0
                    'PLLPD': {'address': 0, 'bit_min': 0, 'bit_max': 0, 'description': 'PLL power down', 'choices': [(0b0, 'Normal'), (0b1, 'Power down')], 'help': 'Power down since there is an external clock'},
                    'CLKR': {'address': 0, 'bit_min': 1, 'bit_max': 2, 'description': 'CLK/Fs ratio', 'choices': [(0b00, '256x Fs'), (0b01, '384x Fs'), (0b10, '512x Fs'), (0b11, '768x Fs')], 'help': 'Use 256x for 44.1 kHz, 512x for 48/96/192 kHz'},
                    'CLKO': {'address': 0, 'bit_min': 3, 'bit_max': 4, 'description': 'Output clock type', 'choices': [(0b00, 'For crystal'), (0b01, '256x Fs'), (0b10, '512x Fs'), (0b11, 'Disabled')], 'help': 'Disable; pin is not connected'},
                    'PLLI': {'address': 0, 'bit_min': 5, 'bit_max': 6, 'description': 'PLL input pin', 'choices': [(0b00, 'MCLKI'), (0b01, 'DLRCLK'), (0b10, 'AUXTDMBCLK'), 'help': 'Use DLRCLK if you insist on using the PLL'},
                    'CLKE': {'address': 0, 'bit_min': 7, 'bit_max': 7, 'description': 'Internal clock enable', 'choices': [(0b0, 'Disable (idle)'), (0b1, 'Enable (active)')], 'help': None},
                    #   PLL/Clock control 1
                    'DCLKS': {'address': 1, 'bit_min': 0, 'bit_max': 0, 'description': 'DAC clock source', 'choices': [(0b0, 'PLL'), (0b1, 'MCLK')], 'help': 'Select MCLK to use external clock'},
                    'CLKS': {'address': 1, 'bit_min': 1, 'bit_max': 1, 'description': 'Other clock source', 'choices': [(0b0, 'PLL'), (0b1, 'MCLK')], 'help': 'Select MCLK to use external clock'},
                    'VREN': {'address': 1, 'bit_min': 2, 'bit_max': 2, 'description': 'Internal voltage reference', 'choices': [(0b0, 'Enabled'), (0b1, 'Disabled')], 'help': 'Enable; necessary for operation'},
                    'LOCK': {'address': 1, 'bit_min': 3, 'bit_max': 3, 'description': 'PLL lock indicator', 'choices': None, 'help': 'Reads 1 if the PLL is locked'},
                    #   DAC control 0
                    'DEN': {'address': 2, 'bit_min': 0, 'bit_max': 0, 'description': 'DAC power down', 'choices': [(0b0, 'Enabled'), (0b1, 'Disabled')], 'help': None},
                    'FS': {'address': 2, 'bit_min': 1, 'bit_max': 2, 'description': 'Sample rate (Fs)', 'choices': [(0b00, '1x (44.1/48 kHz)'), (0b01, '2x (88.2/96 kHz)'), (0b10, '4x (192 kHz)')], 'help': None},
                    'DDL': {'address': 2, 'bit_min': 3, 'bit_max': 5, 'description': 'Serial data delay', 'choices': [(0b000, '1'), (0b001, '0'), (0b010, '8'), (0b011, '12'), (0b100, '16')], 'help': 'For timing tweaks'},
                    'FMT': {'address': 2, 'bit_min': 6, 'bit_max': 7, 'description': 'Serial data format', 'choices': [(0b00, 'Stereo'), (0b01, 'TDM chained'), (0b10, 'DAC aux mode'), (0b11, 'Dual-line TDM')], 'help': 'With current hardware, stick to stereo'},
                    #   DAC control 1
                    'BAE': {'address': 3, 'bit_min': 0, 'bit_max': 0, 'description': 'BCLK active edge', 'choices': [(0b0, 'Mid-cycle'), (0b1, 'End of cycle')], 'help': 'For timing tweaks'},
                    'BFR': {'address': 3, 'bit_min': 1, 'bit_max': 2, 'description': 'BCLKs per frame', 'choices': [(0b00, '64 (2-ch)'), (0b01, '128 (4-ch)'), (0b10, '256 (8-ch)'), (0b11, '512 (16-ch)')], 'help': None},
                    'LRP': {'address': 3, 'bit_min': 3, 'bit_max': 3, 'description': 'LRCLK polarity', 'choices': [(0b0, 'Left low'), (0b1, 'Left high')], 'help': 'Use to swap channels'},
                    'LRM': {'address': 3, 'bit_min': 4, 'bit_max': 4, 'description': 'LRCLK master/slave', 'choices': [(0b0, 'Slave'), (0b1, 'Master')], 'help': 'With current hardware, stick to slave'},
                    'BM': {'address': 3, 'bit_min': 5, 'bit_max': 5, 'description': 'BCLK master/slave', 'choices': [(0b0, 'Slave'), (0b1, 'Master')], 'help': 'With current hardware, stick to slave'},
                    'BS': {'address': 3, 'bit_min': 6, 'bit_max': 6, 'description': 'BCLK source', 'choices': [(0b0, 'DBCLK'), (0b1, 'Internal')], 'help': 'Use external DBCLK'},
                    'BP': {'address': 3, 'bit_min': 7, 'bit_max': 7, 'description': 'BCLK polarity', 'choices': [(0b0, 'Normal'), (0b1, 'Inverted')], 'help': 'For timing tweaks'},
                    #   DAC control 2
                    'MUTE': {'address': 4, 'bit_min': 0, 'bit_max': 0, 'description': 'Master mute', 'choices': [(0b0, 'Unmute'), (0b1, 'Mute')], 'help': None},
                    'DEM': {'address': 4, 'bit_min': 1, 'bit_max': 2, 'description': 'De-emphasis type', 'choices': [(0b00, 'Disabled'), (0b01, 'For 48 kHz Fs'), (0b10, 'For 44.1 kHz Fs'), (0b11, 'For 32 kHz Fs')], 'help': None},
                    'WW': {'address': 4, 'bit_min': 3, 'bit_max': 4, 'description': 'Word width', 'choices': [(0b00, '24'), (0b01, '20'), (0b11, '16')], 'help': 'Selects DAC resolution'},
                    'DOP': {'address': 4, 'bit_min': 5, 'bit_max': 5, 'description': 'DAC output polarity', 'choices': [(0b0, 'Normal'), (0b1, 'Inverted')], 'help': None},
                    #   Mutes
                    'DL1M': {'address': 5, 'bit_min': 0, 'bit_max': 0, 'description': 'DAC 1 left mute', 'choices': [(0b0, 'Unmute'), (0b1, 'Mute')], 'help': None},
                    'DR1M': {'address': 5, 'bit_min': 1, 'bit_max': 1, 'description': 'DAC 1 right mute', 'choices': [(0b0, 'Unmute'), (0b1, 'Mute')], 'help': None},
                    'DL2M': {'address': 5, 'bit_min': 2, 'bit_max': 2, 'description': 'DAC 2 left mute', 'choices': [(0b0, 'Unmute'), (0b1, 'Mute')], 'help': None},
                    'DR2M': {'address': 5, 'bit_min': 3, 'bit_max': 3, 'description': 'DAC 2 right mute', 'choices': [(0b0, 'Unmute'), (0b1, 'Mute')], 'help': None},
                    'DL3M': {'address': 5, 'bit_min': 4, 'bit_max': 4, 'description': 'DAC 3 left mute', 'choices': [(0b0, 'Unmute'), (0b1, 'Mute')], 'help': None},
                    'DR3M': {'address': 5, 'bit_min': 5, 'bit_max': 5, 'description': 'DAC 3 right mute', 'choices': [(0b0, 'Unmute'), (0b1, 'Mute')], 'help': None},
                    'DL4M': {'address': 5, 'bit_min': 6, 'bit_max': 6, 'description': 'DAC 4 left mute', 'choices': [(0b0, 'Unmute'), (0b1, 'Mute')], 'help': None},
                    'DR4M': {'address': 5, 'bit_min': 7, 'bit_max': 7, 'description': 'DAC 4 right mute', 'choices': [(0b0, 'Unmute'), (0b1, 'Mute')], 'help': None},
                    #   Volume controls
                    'DL1V': {'address': 6, 'bit_min': 0, 'bit_max': 7, 'description': 'DAC 1 left attenuation', 'choices': None, 'help': '0 = 0 dB, 255 = -95 dB'},
                    'DR1V': {'address': 7, 'bit_min': 0, 'bit_max': 7, 'description': 'DAC 1 right attenuation', 'choices': None, 'help': '0 = 0 dB, 255 = -95 dB'},
                    'DL2V': {'address': 8, 'bit_min': 0, 'bit_max': 7, 'description': 'DAC 2 left attenuation', 'choices': None, 'help': '0 = 0 dB, 255 = -95 dB'},
                    'DR2V': {'address': 9, 'bit_min': 0, 'bit_max': 7, 'description': 'DAC 2 right attenuation', 'choices': None, 'help': '0 = 0 dB, 255 = -95 dB'},
                    'DL3V': {'address': 10, 'bit_min': 0, 'bit_max': 7, 'description': 'DAC 3 left attenuation', 'choices': None, 'help': '0 = 0 dB, 255 = -95 dB'},
                    'DR3V': {'address': 11, 'bit_min': 0, 'bit_max': 7, 'description': 'DAC 3 right attenuation', 'choices': None, 'help': '0 = 0 dB, 255 = -95 dB'},
                    'DL4V': {'address': 12, 'bit_min': 0, 'bit_max': 7, 'description': 'DAC 4 left attenuation', 'choices': None, 'help': '0 = 0 dB, 255 = -95 dB'},
                    'DR4V': {'address': 13, 'bit_min': 0, 'bit_max': 7, 'description': 'DAC 4 right attenuation', 'choices': None, 'help': '0 = 0 dB, 255 = -95 dB'},
                    #   Aux TDM control 0
                    'TDWW': {'address': 15, 'bit_min': 0, 'bit_max': 1, 'description': 'TDM word width', 'choices': [(0b00, '24'), (0b01, '20'), (0b11, '16')], 'help': 'Selects DAC resolution in TDM mode'},
                    'TDDDL': {'address': 15, 'bit_min': 2, 'bit_max': 4, 'description': 'TDM data delay', 'choices': [(0b000, '1'), (0b001, '0'), (0b010, '8'), (0b011, '12'), (0b100, '16')], 'help': 'For timing tweaks'},
                    'TDFMT': {'address': 15, 'bit_min': 5, 'bit_max': 6, 'description': 'TDM serial data format', 'choices': [(0b10, 'DAC aux mode'))], 'help': None},
                    'TDBAE': {'address': 15, 'bit_min': 7, 'bit_max': 7, 'description': 'TDM BCLK active edge', 'choices': [(0b0, 'Mid-cycle'), (0b1, 'End of cycle')], 'help': 'Not relevant'},
                    #   Aux TDM control 1
                    'TDLRF': {'address': 16, 'bit_min': 0, 'bit_max': 0, 'description': 'TDM LRCLK format', 'choices': [(0b0, '50/50 (auto)'), (0b1, 'Pulse (32 BCLK/ch)')], 'help': 'For timing tweaks'},
                    'TDBP': {'address': 16, 'bit_min': 1, 'bit_max': 1, 'description': 'TDM BCLK polarity', 'choices': [(0b0, 'Normal'), (0b1, 'Inverted')], 'help': 'For timing tweaks'},
                    'TDLRP': {'address': 16, 'bit_min': 2, 'bit_max': 2, 'description': 'TDM LRCLK polarity', 'choices': [(0b0, 'Left low'), (0b1, 'Left high')], 'help': 'Use to swap channels'},
                    'TDLRM': {'address': 16, 'bit_min': 3, 'bit_max': 3, 'description': 'TDM LRCLK master/slave', 'choices': [(0b0, 'Slave'), (0b1, 'Master')], 'help': 'With current hardware, stick to slave'},
                    'TDBFR': {'address': 16, 'bit_min': 4, 'bit_max': 5, 'description': 'TDM BCLKs per frame', 'choices': [(0b00, '64 (2-ch)'), (0b01, '128 (4-ch)'), (0b10, '256 (8-ch)'), (0b11, '512 (16-ch)')], 'help': None},
                    'TDBM': {'address': 16, 'bit_min': 6, 'bit_max': 6, 'description': 'TDM BCLK master/slave', 'choices': [(0b0, 'Slave'), (0b1, 'Master')], 'help': 'With current hardware, stick to slave'},
                    'TDBS': {'address': 16, 'bit_min': 7, 'bit_max': 7, 'description': 'TDM BCLK source', 'choices': [(0b0, 'DBCLK'), (0b1, 'Internal')], 'help': 'Use external DBCLK'},
                }
            },
            
#   AD1974 
            {'target': 'AD1974 8-channel ADC',
             'registers': {
                    #   PLL/Clock control 0
                    'PLLPD': {'address': 0, 'bit_min': 0, 'bit_max': 0, 'description': 'PLL power down', 'choices': [(0b0, 'Normal'), (0b1, 'Power down')], 'help': 'Power down since there is an external clock'},
                    'CLKR': {'address': 0, 'bit_min': 1, 'bit_max': 2, 'description': 'CLK/Fs ratio', 'choices': [(0b00, '256x Fs'), (0b01, '384x Fs'), (0b10, '512x Fs'), (0b11, '768x Fs')], 'help': 'Use 256x for 44.1 kHz, 512x for 48/96/192 kHz'},
                    'CLKO': {'address': 0, 'bit_min': 3, 'bit_max': 4, 'description': 'Output clock type', 'choices': [(0b00, 'For crystal'), (0b01, '256x Fs'), (0b10, '512x Fs'), (0b11, 'Disabled')], 'help': 'Disable; pin is not connected'},
                    'PLLI': {'address': 0, 'bit_min': 5, 'bit_max': 6, 'description': 'PLL input pin', 'choices': [(0b00, 'MCLKI'), (0b01, 'DLRCLK'), (0b10, 'AUXTDMBCLK'), 'help': 'Use DLRCLK if you insist on using the PLL'},
                    'CLKE': {'address': 0, 'bit_min': 7, 'bit_max': 7, 'description': 'Internal clock enable', 'choices': [(0b0, 'Disable (idle)'), (0b1, 'Enable (active)')], 'help': None},
                    #   PLL/Clock control 1
                    'DCLKS': {'address': 1, 'bit_min': 0, 'bit_max': 0, 'description': 'ADC clock source', 'choices': [(0b0, 'PLL'), (0b1, 'MCLK')], 'help': 'Select MCLK to use external clock'},
                    'CLKS': {'address': 1, 'bit_min': 1, 'bit_max': 1, 'description': 'Other clock source', 'choices': [(0b0, 'PLL'), (0b1, 'MCLK')], 'help': 'Select MCLK to use external clock'},
                    'VREN': {'address': 1, 'bit_min': 2, 'bit_max': 2, 'description': 'Internal voltage reference', 'choices': [(0b0, 'Enabled'), (0b1, 'Disabled')], 'help': 'Enable; necessary for operation'},
                    'LOCK': {'address': 1, 'bit_min': 3, 'bit_max': 3, 'description': 'PLL lock indicator', 'choices': None, 'help': 'Reads 1 if the PLL is locked'},
                    #   Auxiliary port control 0
                    'AFSM': {'address': 2, 'bit_min': 1, 'bit_max': 2, 'description': 'AUX sample rate (Fs)', 'choices': [(0b00, '1x (44.1/48 kHz)'), (0b01, '2x (88.2/96 kHz)'), (0b10, '4x (192 kHz)')], 'help': None},
                    'ADDL': {'address': 2, 'bit_min': 3, 'bit_max': 5, 'description': 'AUXDATA delay', 'choices': [(0b000, '1'), (0b001, '0'), (0b010, '8'), (0b011, '12'), (0b100, '16')], 'help': 'For timing tweaks'},
                    'AFMT': {'address': 2, 'bit_min': 6, 'bit_max': 7, 'description': 'AUX serial data format', 'choices': [(0b00, 'Stereo'), (0b10, 'ADC aux mode')], 'help': 'With current hardware, stick to stereo'},
                    #   Auxiliary port control 1
                    'ABFR': {'address': 3, 'bit_min': 1, 'bit_max': 2, 'description': 'AUXBCLKs per frame', 'choices': [(0b00, '64 (2-ch)'), (0b01, '128 (4-ch)'), (0b10, '256 (8-ch)'), (0b11, '512 (16-ch)')], 'help': None},
                    'ALRP': {'address': 3, 'bit_min': 3, 'bit_max': 3, 'description': 'AUXLRCLK polarity', 'choices': [(0b0, 'Left low'), (0b1, 'Left high')], 'help': 'Use to swap channels'},
                    'ALRM': {'address': 3, 'bit_min': 4, 'bit_max': 4, 'description': 'AUXLRCLK master/slave', 'choices': [(0b0, 'Slave'), (0b1, 'Master')], 'help': 'With current hardware, stick to slave'},
                    'ABM': {'address': 3, 'bit_min': 5, 'bit_max': 5, 'description': 'AUXBCLK master/slave', 'choices': [(0b0, 'Slave'), (0b1, 'Master')], 'help': 'With current hardware, stick to slave'},
                    'ABS': {'address': 3, 'bit_min': 6, 'bit_max': 6, 'description': 'AUXBCLK source', 'choices': [(0b0, 'DBCLK'), (0b1, 'Internal')], 'help': 'Use external DBCLK'},
                    'ABP': {'address': 3, 'bit_min': 7, 'bit_max': 7, 'description': 'AUXBCLK polarity', 'choices': [(0b0, 'Normal'), (0b1, 'Inverted')], 'help': 'For timing tweaks'},
                    #   Auxiliary port control 2
                    'AWW': {'address': 4, 'bit_min': 3, 'bit_max': 4, 'description': 'AUX word width', 'choices': [(0b00, '24'), (0b01, '20'), (0b11, '16')], 'help': 'Selects ADC resolution in AUX mode'},
                    #   ADC control 0
                    'AEN': {'address': 14, 'bit_min': 0, 'bit_max': 0, 'description': 'ADC power down', 'choices': [(0b0, 'Normal'), (0b1, 'Power down')], 'help': None},
                    'HPF': {'address': 14, 'bit_min': 1, 'bit_max': 1, 'description': 'High-pass filter', 'choices': [(0b0, 'Disabled'), (0b1, 'Enabled')], 'help': '1st-order, 1.4 Hz Fc'},
                    'AL1M': {'address': 14, 'bit_min': 2, 'bit_max': 2, 'description': 'ADC 1 left mute', 'choices': [(0b0, 'Unmute'), (0b1, 'Mute')], 'help': None},
                    'AR1M': {'address': 14, 'bit_min': 3, 'bit_max': 3, 'description': 'ADC 1 right mute', 'choices': [(0b0, 'Unmute'), (0b1, 'Mute')], 'help': None},
                    'AL2M': {'address': 14, 'bit_min': 4, 'bit_max': 4, 'description': 'ADC 2 left mute', 'choices': [(0b0, 'Unmute'), (0b1, 'Mute')], 'help': None},
                    'AR2M': {'address': 14, 'bit_min': 5, 'bit_max': 5, 'description': 'ADC 2 right mute', 'choices': [(0b0, 'Unmute'), (0b1, 'Mute')], 'help': None},
                    'FS': {'address': 14, 'bit_min': 6, 'bit_max': 7, 'description': 'Sample rate (Fs)', 'choices': [(0b00, '1x (44.1/48 kHz)'), (0b01, '2x (88.2/96 kHz)'), (0b10, '4x (192 kHz)')], 'help': None},
                    #   ADC control 1
                    'WW': {'address': 15, 'bit_min': 0, 'bit_max': 1, 'description': 'Word width', 'choices': [(0b00, '24'), (0b01, '20'), (0b11, '16')], 'help': 'Selects ADC resolution'},
                    'DDL': {'address': 15, 'bit_min': 2, 'bit_max': 4, 'description': 'Serial data delay', 'choices': [(0b000, '1'), (0b001, '0'), (0b010, '8'), (0b011, '12'), (0b100, '16')], 'help': 'For timing tweaks'},
                    'FMT': {'address': 15, 'bit_min': 5, 'bit_max': 6, 'description': 'Serial data format', 'choices': [(0b00, 'Stereo'), (0b01, 'TDM chained'), (0b10, 'ADC aux mode')], 'help': 'With current hardware, stick to stereo'},
                    'BAE': {'address': 15, 'bit_min': 7, 'bit_max': 7, 'description': 'BCLK active edge', 'choices': [(0b0, 'Mid-cycle'), (0b1, 'End of cycle')], 'help': 'For timing tweaks'},
                    #   ADC control 2
                    'LRF': {'address': 16, 'bit_min': 0, 'bit_max': 0, 'description': 'LRCLK format', 'choices': [(0b0, '50/50 (auto)'), (0b1, 'Pulse (32 BCLK/ch)')], 'help': 'For timing tweaks'},
                    'BP': {'address': 16, 'bit_min': 1, 'bit_max': 1, 'description': 'BCLK polarity', 'choices': [(0b0, 'Normal'), (0b1, 'Inverted')], 'help': 'For timing tweaks'},
                    'LRP': {'address': 16, 'bit_min': 2, 'bit_max': 2, 'description': 'LRCLK polarity', 'choices': [(0b0, 'Left low'), (0b1, 'Left high')], 'help': 'Use to swap channels'},
                    'LRM': {'address': 16, 'bit_min': 3, 'bit_max': 3, 'description': 'LRCLK master/slave', 'choices': [(0b0, 'Slave'), (0b1, 'Master')], 'help': 'With current hardware, stick to slave'},
                    'BFR': {'address': 16, 'bit_min': 4, 'bit_max': 5, 'description': 'BCLKs per frame', 'choices': [(0b00, '64 (2-ch)'), (0b01, '128 (4-ch)'), (0b10, '256 (8-ch)'), (0b11, '512 (16-ch)')], 'help': None},
                    'BM': {'address': 16, 'bit_min': 6, 'bit_max': 6, 'description': 'BCLK master/slave', 'choices': [(0b0, 'Slave'), (0b1, 'Master')], 'help': 'With current hardware, stick to slave'},
                    'BS': {'address': 16, 'bit_min': 7, 'bit_max': 7, 'description': 'BCLK source', 'choices': [(0b0, 'ABCLK'), (0b1, 'Internal')], 'help': 'Use external DBCLK'},
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
                #   Rate register
                'CLKT': {'address': 0, 'bit_min': 0, 'bit_max': 0, 'description': 'Clock domain', 'choices': [(0b0, '44.1 kHz'), (0b1, '48 kHz')]},
                'CLKM': {'address': 0, 'bit_min': 1, 'bit_max': 2, 'description': 'Fs multiplier', 'choices': [(0b00, '1x (44.1/48 kHz)'), (0b01, '2x (88.2/96 kHz)'), (0b10, '4x (192 kHz)')]},
                'OSM': {'address': 0, 'bit_min': 3, 'bit_max': 4, 'description': 'Software oversampling ratio', 'choices': [(0b00, 'None'), (0b01, '2x'), (0b10, '4x'), (0b11, '8x')]},
                #   Format register
                'DSD': {'address': 1, 'bit_min': 0, 'bit_max': 0},      #   (1) Whether to use DSD (and hence present DSD format data on DSDL/DSDR)
                'FMT': {'address': 1, 'bit_min': 1, 'bit_max': 3},      #   (3) Format (left justified, right justified, I2S)
                'DFTH': {'address': 1, 'bit_min': 4, 'bit_max': 4},     #   (1) Whether to use the DSD1792's digital filter (fixed 8x oversampling) or not
                'DFMS': {'address': 1, 'bit_min': 5, 'bit_max': 5},     #   (1) Whether to use mono (PDATA) or stereo (DSDL/DSDR) when digital filter is off
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
    
