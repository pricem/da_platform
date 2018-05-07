Measurements
------------

This section provides some measured performance results.  Currently all results pertain to the baseline boards.  These measurements are not enough to provide a complete picture, but hopefully illustrate the potential for good audio performance.

DAC2 and ADC2
=============

**Differential**: The following figures show the combined performance of the DAC2 (AK4490 based) and ADC2 (AK5572 based) with loopback via XLR cables.  It is not possible to separate the contributions of the DAC from those of the ADC, since I don't have any better ADCs or test equipment at home.  Note that the ADC module includes 1 dB of attenuation for overload margin.  

.. figure:: figures/dac2_adc2_loopback_fr.*
    :width: 75%
    :align: center

    Frequency response of DAC2/ADC2 loopback at 44.1 kHz sample rate. 

The rolloff above 10 kHz is larger than expected.  The frequency response is down by about 0.7 dB at 20 kHz.  I built a second DAC2 module with different capacitor values in the output filter, in an effort to flatten the response.  However, this has not yet been tested.

.. figure:: figures/dac2_adc2_loopback_m3db_dist_noise.*
    :width: 75%
    :align: center

    Distortion and noise of DAC2/ADC2 loopback at -3 dBFS.  The top curve is the THD+N ratio or (inverse) SNDR. 

The level of various harmonics seems to be relatively independent of frequency.  The measurement bandwidth is limited to 20 kHz, which causes the steps in 3rd harmonic at 6.7 kHz and in 2nd harmonic at 10 kHz.  The 3rd harmonic lies at about -110 dB and higher order harmonics are lower in level.  I don't know if the bumps in THD+N (noise) below 100 Hz are related to the data analysis, but at least it's below -100 dB at most frequencies.

**Single ended**: The following figures were generated with RCA cable loopback.  Only the "positive" (in-phase) output of the DAC2 is used.
    
.. figure:: figures/dac2_adc2_se_fr.*
    :width: 75%
    :align: center

    Frequency response of DAC2 single-ended output into ADC2. 

The frequency response is the same except for a 6 dB loss, as expected.

.. figure:: figures/dac2_adc2_se_dist_noise.*
    :width: 75%
    :align: center

    Distortion and noise at -3 dBFS. 

In single-ended mode the 2nd harmonic is higher at around -100 dB, and in combination with higher noise this results in SNDR around 90 dB.

DAC8 and ADC8
=============

The ADC8 module has sharply rising THD at high input levels, and the board design will need to be examined and revised.  To illustrate the behavior of the DAC8 board, I used the 10 dB attenuator setting on the DAC8.  This reduces the input level and thus the contribution of ADC nonlinearity to distortion.

The DAC8 module does not have differential outputs.  These measurements were performed with loopback via RCA cables.

.. figure:: figures/dac8_adc8_loopback_fr.*
    :width: 75%
    :align: center

    Frequency response of DAC8/ADC8 loopback at -3 dBFS, with 10 dB additional attenuation. 

This is as expected given the 10 dB attenuation from the DAC8 and 1 dB attenuation from the ADC8.  Unlike the DAC2, there is no rolloff (beyond the expected digital filter ripple) at high frequencies.

.. figure:: figures/dac8_adc8_loopback_att10db_dist_noise.*
    :width: 75%
    :align: center

    Distortion and noise at -3 dBFS with 10 dB resistive attenuation. 

Supply-related spurs (multiples of 60 Hz) may be compromising the measurement at low frequencies, but the measurement floor is relatively low.  Distortion is characterized by a rising 2nd harmonic (and to a lesser extent, 3rd harmonic) at high frequencies.  The higher order harmonics also increase somewhat (up to around -108 dB).  Overall SNDR is around 93 dB below 3 kHz and degrades to 88 dB (mostly due to 2nd harmonic) at 10 kHz.


Development discussions
=======================

The following documents provide exploratory, but more detailed, discussions about the performance of baseline system components:

* `Clock distribution`_ (phase noise and integrated jitter)
* `Voltage regulators`_ (on backplane)

.. _`Clock distribution`: https://github.com/pricem/da_platform/raw/master/docs/phase_noise_testing.pdf
.. _`Voltage regulators`: https://github.com/pricem/da_platform/raw/master/docs/reg_testing.pdf

I hope to perform more measurements of clock distribution performance on a completed project.  The voltage regulators are less of a focus since the highest-performing modules will rely on local regulation.


