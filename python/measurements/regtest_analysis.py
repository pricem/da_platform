"""
    Open-source digital audio platform
    Copyright (C) 2009--2018 Michael Price

    regtest_analysis.py: Script for interpreting and plotting voltage
    regulator measurement results.

    Warning: Use and distribution of this code is restricted.
    This software code is distributed under the terms of the GNU General Public
    License, version 3.  Other files in this project may be subject to
    different licenses.  Please see the LICENSE file in the top level project
    directory for more information.
"""

import numpy
from matplotlib import pyplot
import os.path
import os

from plotting import custom_formatter

#   Change these settings per-run
"""
sources = [
    ('jung_pos2', 'data/jul2a', 'Jung +15 V', 'r-'),
    ('jung_pos3', 'data/jul2e', 'Jung +5 V', 'b-'),
    ('jung_pos4', 'data/jul2d', 'Jung +3.3 V', 'g-'),
    ('jung_neg2', 'data/jul2b', 'Jung -15 V', 'm-'),
    ('floor', 'data/jul2b', 'Meas. floor', 'k--'),
]

plots_dir = 'plots/jul2_plots'
plots_name = 'jung_all'
"""

sources = [
    ('lm317_pos2', 'data/jun25b', 'LM317 +15 V', 'r-'),
    ('lm317_pos3', 'data/jun25b', 'LM317 +5 V', 'b-'),
    ('lm317_pos4', 'data/jun25b', 'LM317 +3.3 V', 'g-'),
    ('lm317_neg2', 'data/jun25b', 'LM337 -15 V', 'm-'),
    ('floor', 'data/jul2b', 'Meas. floor', 'k--'),
]

plots_dir = 'plots/jul2_plots'
plots_name = 'lm317_all'

"""
sources = [
    ('jung_pos4', 'data/jun25c', 'jun25c', 'r-'),
    ('jung_pos4', 'data/jun27a', 'jun27a', 'b-'),
    ('jung_pos4', 'data/jun27b', 'jun27b', 'g-'),
    ('jung_pos4', 'data/jul1a', 'jul1a', 'm-'),
    ('jung_pos4', 'data/jul1b', 'jul1b', 'c-'),
    ('jung_pos4', 'data/jul2b', 'jul2b', 'k-'),
    ('jung_pos4', 'data/jul2c', 'jul2c', 'y-'),
]

plots_dir = 'plots/jul2_plots'
plots_name = 'jung_pos4_mods'
"""
"""
sources = [
    #('jung_neg2', 'data/jun25c', 'jun25c', 'r-'),
    #('jung_neg2', 'data/jun27b', 'jun27b', 'g-'),
    ('jung_neg2', 'data/jul2a', 'Original', 'k-'),
    ('jung_neg2', 'data/jul2b', 'With ground wire', 'r-'),
]

plots_dir = 'plots/jul2_plots'
plots_name = 'jung_neg2_mods'
"""
"""
sources = [
    #('jung_neg2', 'data/jun25c', 'jun25c', 'r-'),
    #('jung_neg2', 'data/jun27b', 'jun27b', 'g-'),
    ('jung_pos4', 'data/jul2c', 'With ground wire', 'r-'),
    ('jung_pos4', 'data/jul2b', 'Original', 'k-'),
]

plots_dir = 'plots/jul2_plots'
plots_name = 'jung_pos4_mods_2'
"""
"""
sources = [
    #('jung_neg2', 'data/jun25c', 'jun25c', 'r-'),
    #('jung_neg2', 'data/jun27b', 'jun27b', 'g-'),
    ('jung_pos4', 'data/jul2c', 'Same PCB', 'r-'),
    ('jung_pos4', 'data/jul2d', 'Separate PCB', 'b-'),
    ('jung_pos4', 'data/jul2e', 'No filter caps', 'g-'),
]

plots_dir = 'plots/jul2_plots'
plots_name = 'jung_pos4_mods_3'
"""
"""
sources = [
    #('jung_neg2', 'data/jun25c', 'jun25c', 'r-'),
    #('jung_neg2', 'data/jun27b', 'jun27b', 'g-'),
    ('jung_pos3', 'data/jul1b', 'Same PCB', 'r-'),
    ('jung_pos3', 'data/jul2e', 'Separate/No filter', 'b-'),
]

plots_dir = 'plots/jul2_plots'
plots_name = 'jung_pos3_mods'
"""
if not os.path.exists(plots_dir):
    os.makedirs(plots_dir)

def get_data_fn(source, name):
    reg_prefix = source[0]
    data_dir = source[1]
    return os.path.join(data_dir, '%s_%s.txt' % (reg_prefix, name))

def get_plot_fn(name):
    return os.path.join(plots_dir, '%s_%s.pdf' % (plots_name, name))

def plot_fr(sources, cal_mode=False):
    pyplot.figure()
    pyplot.hold(True)

    for source in sources:
        freq = numpy.loadtxt(get_data_fn(source, 'freq'))
        if cal_mode:
            resp_db = numpy.loadtxt(get_data_fn(source, 'cal'))
        else:
            resp_db = numpy.loadtxt(get_data_fn(source, 'linerej'))
        pyplot.semilogx(freq, resp_db, source[3])

    pyplot.xlim([10, 20000])
    if cal_mode:
        pyplot.ylim([-20, 5])
        pyplot.legend([x[2] for x in sources], loc='lower right')
    else:
        pyplot.ylim([-120, -40])
        pyplot.legend([x[2] for x in sources], loc='upper left')

    pyplot.grid(True)

    pyplot.xlabel('Frequency (Hz)')
    pyplot.ylabel('Magnitude (dB)')
    if cal_mode:
        pyplot.title('Frequency response at input port')
        pyplot.savefig(get_plot_fn('cal'))
    else:
        pyplot.title('Line rejection')
        pyplot.savefig(get_plot_fn('linerej'))

def plot_noise(sources):
    (fig, ax) = pyplot.subplots(1, 1)
    pyplot.hold(True)

    for source in sources:
        freq = numpy.loadtxt(get_data_fn(source, 'noise_freq'))
        ampl_density = numpy.loadtxt(get_data_fn(source, 'noise_nsd'))

        #   Figure out RMS
        num_points = freq.shape[0]
        F_s = 48000.
        bin_spacing = (float(F_s) / 2) / (num_points - 1)
        
        rms_ampl = numpy.sum(ampl_density * bin_spacing) / (num_points ** 0.5)
        avg_density = (rms_ampl / (F_s / 2) ** 0.5)
        print '  %s: Noise RMS ampl = %f uV, avg %f nV/rt(Hz)' % (source[0], rms_ampl / 1e3, avg_density)
        
        inds_valid = (freq >= 100) * (freq <= 20000)
        num_points = numpy.sum(inds_valid)
        print '    Freq limiting to 100-20k: %d/%d points used' % (num_points, freq.shape[0])
        
        rms_ampl = numpy.sum(ampl_density[inds_valid] * bin_spacing) / (num_points ** 0.5)
        avg_density = (rms_ampl / (20000 - 100.) ** 0.5)
        print '  %s: Noise RMS ampl (BW limited) = %f uV, avg %f nV/rt(Hz)' % (source[0], rms_ampl / 1e3, avg_density)

        ax.loglog(freq, ampl_density, source[3])
        
    ax.set_xlim([10, 20000])
    pyplot.ylim([1, 10000])
    pyplot.legend([x[2] for x in sources], loc='lower right')

    ax.yaxis.set_major_formatter(custom_formatter)

    pyplot.grid(True)

    pyplot.xlabel('Frequency (Hz)')
    pyplot.ylabel('PSD (nV / sqrt(Hz))')
    pyplot.title('Output noise spectral density')

    pyplot.savefig(get_plot_fn('nsd'))

def plot_imp(sources):

    pyplot.figure()
    pyplot.hold(True)
    
    for source in sources:
        freq = numpy.loadtxt(get_data_fn(source, 'freq'))
        resp_ohm = numpy.loadtxt(get_data_fn(source, 'outimp'))
        pyplot.loglog(freq, resp_ohm * 1e3, source[3])
    
    pyplot.xlim([10, 20000])
    pyplot.ylim([1, 1000])
    pyplot.legend([x[2] for x in sources], loc='upper right')

    pyplot.grid(True)

    pyplot.xlabel('Frequency (Hz)')
    pyplot.ylabel('Magnitude (mOhm)')
    pyplot.title('Output impedance')

    pyplot.savefig(get_plot_fn('outimp'))

def gen_plots(sources):
    plot_fr(sources, True)
    plot_fr(sources, False)
    plot_noise(sources)
    plot_imp(sources)

if __name__ == '__main__':
    gen_plots(sources)
