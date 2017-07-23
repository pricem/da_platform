#!/usr/bin/env python

from matplotlib import pyplot
import numpy
import scipy.stats
import scipy.signal
import re
import pdb

def get_pn(filename, label):
    data = open(filename).read()
    carrier_freq = float(re.findall(r'Carrier Frequency \(Hz\),([\+\-0-9\.e]+)', data)[0])
    carrier_power = float(re.findall(r'Carrier Power \(dBm\),([\+\-0-9\.e]+)', data)[0])
    data_points = re.findall(r'([\+\-0-9\.e]+),([\+\-0-9\.e]+)', data)
    freq = [float(x[0]) for x in data_points]
    pn = [float(x[1]) for x in data_points]
    return (carrier_freq, carrier_power, freq, pn, label)

def get_pn_multi(spec):
    result = []
    for item in spec:
        result.append(get_pn(item[0], item[1]))
    return result

def filter_pn(pn, tol=8, smw=10):
    #bad_inds_pos = numpy.nonzero(numpy.diff(pn) > tol)
    #bad_inds_neg = numpy.nonzero(numpy.diff(pn) < -tol)
    
    pn = numpy.array(pn)
    pn_new = numpy.array(pn).copy()
    
    """
    #   Old bad version
    bad_inds = numpy.nonzero(numpy.abs(numpy.diff(pn)) > tol)[0]
    i = 0
    s = 0
    print bad_inds
    for i in range(1, bad_inds.shape[0]):
        if bad_inds[i] > bad_inds[i - 1] + 2:
            if s != i - 1:
                print 'Removing spur from %d to %d' % (bad_inds[s], bad_inds[i-1])
                pn_new[bad_inds[s]+1:bad_inds[i-1]+1] = (pn[bad_inds[s]] + pn[bad_inds[i-1]+1]) / 2.0
            s = i
    """
    
    #   New idea.
    #   Step 0: Apply a lot of smoothing (Gaussian window, 100 samples)
    kt = numpy.linspace(-5, 5, 101)
    kx = scipy.stats.norm.pdf(kt) / 10
    pn_ext = numpy.pad(pn, 50, 'edge')
    #pn_smooth = scipy.signal.convolve(pn_ext, kx, 'valid')
    #   7/19/2017: try the minimum statistics approach
    pn_smooth = numpy.zeros(pn.shape)
    for i in range(pn.shape[0]):
        s = max(0, i - smw)
        e = min(pn.shape[0], i + smw + 1)
        pn_smooth[i] = numpy.min(pn[s:e])

    #   Step 1: Find peaks of more than 10 dB over that.
    pn_delta = pn - pn_smooth
    if numpy.sum(pn_delta > tol) > 0:
        peak_locs = numpy.nonzero(pn_delta > tol)[0]
        pn_curv_pos_inds = numpy.nonzero(numpy.diff((numpy.diff(pn) > 0).astype(int)) == 1)[0] + 1
        
        #   Add first/last...
        pn_curv_pos_inds = numpy.concatenate(((0, pn.shape[0] - 1), pn_curv_pos_inds))

        #   Step 2: Work outwards from the peaks to the next valley.
        for i in range(peak_locs.shape[0]):
            distances = pn_curv_pos_inds - peak_locs[i]
            if numpy.sum(distances > 0) == 0 or numpy.sum(distances < 0) == 0:
                continue
            dist_pos = numpy.min(distances[distances > 0])
            dist_neg = numpy.min(-distances[distances < 0])
            s = peak_locs[i] - dist_neg
            e = peak_locs[i] + dist_pos
            pn_new[s+1:e] = numpy.linspace(pn[s], pn[e], e - s - 1)

    #pdb.set_trace()
    return pn_new

def compute_jitter(f0, freq, pn, mask=None):
    freq = numpy.array(freq)
    if mask is None:
        mask = numpy.ones(freq.shape, dtype=bool)
    pn = numpy.array(pn)
    bin_width = numpy.diff(freq)
    bin_width_recentered = (numpy.pad(bin_width, ((1, 0),), 'constant') + numpy.pad(bin_width, ((0, 1),), 'constant')) * 0.5
    pwr_rel_carrier = numpy.sum((10 ** (pn[mask] / 10)) * bin_width_recentered[mask])
    jitter_rms_sec = ((2 * pwr_rel_carrier) ** 0.5) / (2 * numpy.pi * f0)
    #   pdb.set_trace()
    return jitter_rms_sec
    
def compute_rel_jitter(d1, d2, filter=False, min_freq=100):
    if filter:
        pn1 = filter_pn(d1[3])
        pn2 = filter_pn(d2[3])
    else:
        pn1 = numpy.array(d1[3])
        pn2 = numpy.array(d2[3])
    assert numpy.sum(numpy.array(d1[2]) != numpy.array(d2[2])) == 0
    mask = (pn2 >= pn1)
    j1 = compute_jitter(d1[0], d1[2], pn1, mask)
    j2 = compute_jitter(d2[0], d2[2], pn2, mask)
    dj = (j2 ** 2 - j1 ** 2) ** 0.5
    print '%s -> %s: added jitter = %.3f ps (filter = %s)' % (d1[4], d2[4], dj * 1e12, filter)
    return dj
    
def compute_jitter_multi(data, filter=False):
    result = []
    for item in data:
        if filter:
            pn = filter_pn(item[3])
        else:
            pn = item[3]
        jitter = compute_jitter(item[0], item[2], pn)
        print '%s: RMS jitter = %.3f ps (filter = %s)' % (item[4], jitter * 1e12, filter)
        result.append(jitter)
    return result

def plot_pn(data_list, filter=True, freq_min=10, freq_max=1e6):
    labels = []
    pyplot.figure(figsize=(10, 8))
    pyplot.hold(True)
    for item in data_list:
        freq = item[2]
        if filter:
            pn = filter_pn(item[3])
        else:
            pn = item[3]
        labels.append(item[4])
        pyplot.semilogx(freq, pn)
    
    pyplot.legend(labels, loc='upper right')
    pyplot.grid(True)
    pyplot.xlabel('Frequency (Hz)')
    pyplot.ylabel('Magnitude (dBc)')
    pyplot.title('Phase noise spectrum')
    pyplot.xlim(freq_min, freq_max)
    pyplot.ylim(-180, -80)

    pyplot.yticks(numpy.arange(-180, -70, 10))

if __name__ == '__main__':
    
    show = False
    save = True
    
    print '-- Crystek 24 MHz receiver comparison'
    specs = [
        ('phase_noise/crystek_24_direct.csv', 'CCHD-957, 24.576 MHz, direct'),
        ('phase_noise/crystek_24_ecl.csv', 'CCHD-957, 24.576 MHz, ECL receiver'),
        ('phase_noise/crystek_24_lvds.csv', 'CCHD-957, 24.576 MHz, LVDS receiver'),
    ]
    data = get_pn_multi(specs)
    plot_pn(data)
    """
    #   Testing 7/18/2017
    compute_jitter_multi(data, False)
    compute_jitter_multi(data, True)
    compute_rel_jitter(data[0], data[1], filter=True)
    compute_rel_jitter(data[0], data[2], filter=True)
    """
    pyplot.title('ADM7154/ADCLK948 source board')
    if save: pyplot.savefig('phase_noise/crystek_24_receivers.pdf')

    #   Testing 7/18/2017
    #plot_pn(data, True)
    #pyplot.savefig('phase_noise/crystek_24_receivers_filt.pdf')
    
    print '-- Crystek regulator comparison'
    specs = [
        ('phase_noise/crystek_22_direct.csv', 'CCHD-957, 22.5792 MHz, UA78M33 supply'),
        ('phase_noise/crystek_22_direct_analyzer_supply.csv', 'CCHD-957, 22.5792 MHz, lab supply'),
        ('phase_noise/crystek_24_direct.csv', 'CCHD-957, 24.576 MHz, ADM7154 supply'),
    ]
    data = get_pn_multi(specs)
    plot_pn(data)
    pyplot.title('CCHD-957 power supply dependence')
    if save: pyplot.savefig('phase_noise/crystek_22_regs.pdf')
    
    print '-- Crystek 22 MHz receiver comparison'
    specs = [
        ('phase_noise/crystek_22_direct.csv', 'CCHD-957, 22.5792 MHz, direct'),
        ('phase_noise/crystek_22_ecl.csv', 'CCHD-957, 22.5792 MHz, ECL'),
        ('phase_noise/crystek_22_lvds_clk3.csv', 'CCHD-957, 22.5792 MHz, LVDS'),
    ]
    data = get_pn_multi(specs)
    plot_pn(data)
    pyplot.title('UA78M33/FIN10xx source board')
    if save: pyplot.savefig('phase_noise/crystek_22_receivers.pdf')

    print '-- Sorurce B oscillator/receiver comparison'
    specs = [
        ('phase_noise/crystek_24_direct.csv', 'CCHD-957, 24.576 MHz, direct'),
        ('phase_noise/tentlabs_11_direct.csv', 'Tent XO, 11.2896 MHz, direct'),
        ('phase_noise/crystek_24_ecl.csv', 'CCHD-957, 24.576 MHz, ECL receiver'),
        ('phase_noise/tentlabs_11_ecl.csv', 'Tent XO, 11.2896 MHz, ECL receiver'),
        ('phase_noise/crystek_24_lvds.csv', 'CCHD-957, 24.576 MHz, LVDS receiver'),
        ('phase_noise/tentlabs_11_lvds.csv', 'Tent XO, 11.2896 MHz, LVDS receiver'),
    ]
    data = get_pn_multi(specs)
    plot_pn(data)
    pyplot.title('ADM7154/ADCLK948 source board')
    if save: pyplot.savefig('phase_noise/crystek_vs_tent.pdf')

    """
    #   Testing
    plot_pn(data, freq_max=5e6, filter=False)
    pyplot.savefig('phase_noise/crystek_vs_tent_5mhz.pdf')
    plot_pn(data, freq_max=5e6, filter=True)
    pyplot.savefig('phase_noise/crystek_vs_tent_5mhz_filt.pdf')
    """

    compute_jitter_multi(data, True)    
    compute_rel_jitter(data[0], data[2], filter=True)
    compute_rel_jitter(data[0], data[4], filter=True)
    compute_rel_jitter(data[1], data[3], filter=True)
    compute_rel_jitter(data[1], data[5], filter=True)

    print '-- Sorurce A oscillator/receiver comparison'
    specs = [
        ('phase_noise/crystek_22_direct.csv', 'CCHD-957, 22.5792 MHz, direct'),
        ('phase_noise/epson_22_direct.csv', 'SG-210STF, 22.5792 MHz, direct'),
        ('phase_noise/crystek_22_ecl.csv', 'CCHD-957, 22.5792 MHz, ECL receiver'),
        ('phase_noise/epson_22_ecl_clk3.csv', 'SG-210STF, 22.5792 MHz, ECL receiver'),
        ('phase_noise/crystek_22_lvds_clk3.csv', 'CCHD-957, 22.5792 MHz, LVDS receiver'),
        ('phase_noise/epson_22_lvds_clk3.csv', 'SG-210STF, 22.5792 MHz, LVDS receiver'),
    ]
    data = get_pn_multi(specs)
    plot_pn(data)
    pyplot.title('UA78M33/FIN10xx source board')
    if save: pyplot.savefig('phase_noise/crystek_vs_epson.pdf')

    """
    #   Testing
    plot_pn(data, freq_max=5e6, filter=False)
    pyplot.savefig('phase_noise/crystek_vs_epson_5mhz.pdf')
    plot_pn(data, freq_max=5e6, filter=True)
    pyplot.savefig('phase_noise/crystek_vs_epson_5mhz_filt.pdf')
    """

    compute_jitter_multi(data, True)
    compute_rel_jitter(data[0], data[2], filter=True)
    compute_rel_jitter(data[0], data[4], filter=True)
    compute_rel_jitter(data[1], data[3], filter=True)
    compute_rel_jitter(data[1], data[5], filter=True)
    
    for i in (0, 1):
        print '%s jitter (100 Hz start) = %.3f ps' % (data[i][4], compute_jitter(data[i][0], data[i][2], filter_pn(data[i][3]), mask=(numpy.array(data[i][2]) > 100)) * 1e12)

    print '-- Source B, receiver B trace length comparison'
    specs = [
        ('phase_noise/crystek_24_direct.csv', 'CCHD-957, 24.576 MHz, direct'),
        ('phase_noise/crystek_24_ecl_clkf.csv', 'CCHD-957, 24.576 MHz, ECL, CLKF trace'),
        ('phase_noise/crystek_24_ecl_clk0.csv', 'CCHD-957, 24.576 MHz, ECL, CLK0 trace'),
        ('phase_noise/crystek_24_ecl_clk1.csv', 'CCHD-957, 24.576 MHz, ECL, CLK1 trace'),
        ('phase_noise/crystek_24_ecl_clk2.csv', 'CCHD-957, 24.576 MHz, ECL, CLK2 trace'),
        ('phase_noise/crystek_24_ecl_clk3.csv', 'CCHD-957, 24.576 MHz, ECL, CLK3 trace'),
    ]
    data = get_pn_multi(specs)
    plot_pn(data)
    pyplot.title('Different trace lengths, ECL source and receiver')
    if save: pyplot.savefig('phase_noise/crystek_24_ecl_traces.pdf')
    
    compute_jitter_multi(data, True)
    for i in range(1, 6):
        compute_rel_jitter(data[0], data[i], filter=True)
    
    print '-- Source B, receiver A trace length comparison'
    specs = [
        ('phase_noise/crystek_24_direct.csv', 'CCHD-957, 24.576 MHz, direct'),
        ('phase_noise/crystek_24_lvds_clkf.csv', 'CCHD-957, 24.576 MHz, LVDS, CLKF trace'),
        ('phase_noise/crystek_24_lvds_clk0.csv', 'CCHD-957, 24.576 MHz, LVDS, CLK0 trace'),
        ('phase_noise/crystek_24_lvds_clk1.csv', 'CCHD-957, 24.576 MHz, LVDS, CLK1 trace'),
        ('phase_noise/crystek_24_lvds_clk2.csv', 'CCHD-957, 24.576 MHz, LVDS, CLK2 trace'),
        ('phase_noise/crystek_24_lvds_clk3.csv', 'CCHD-957, 24.576 MHz, LVDS, CLK3 trace'),
    ]
    data = get_pn_multi(specs)
    plot_pn(data)
    pyplot.title('Different trace lengths, ECL source, LVDS receiver')
    if save: pyplot.savefig('phase_noise/crystek_24_lvds_traces.pdf')
    
    compute_jitter_multi(data, True)
    for i in range(1, 6):
        compute_rel_jitter(data[0], data[i], filter=True)
    
    print '-- Source A, receiver A trace length comparison'
    specs = [
        ('phase_noise/crystek_22_direct.csv', 'CCHD-957, 22.5792 MHz, direct'),
        ('phase_noise/crystek_22_lvds_clkf.csv', 'CCHD-957, 22.5792 MHz, LVDS, CLKF trace'),
        ('phase_noise/crystek_22_lvds_clk0.csv', 'CCHD-957, 22.5792 MHz, LVDS, CLK0 trace'),
        ('phase_noise/crystek_22_lvds_clk1.csv', 'CCHD-957, 22.5792 MHz, LVDS, CLK1 trace'),
        ('phase_noise/crystek_22_lvds_clk2.csv', 'CCHD-957, 22.5792 MHz, LVDS, CLK2 trace'),
        ('phase_noise/crystek_22_lvds_clk3.csv', 'CCHD-957, 22.5792 MHz, LVDS, CLK3 trace'),
    ]
    data = get_pn_multi(specs)
    plot_pn(data)
    pyplot.title('Different trace lengths, LVDS source, LVDS receiver')
    if save: pyplot.savefig('phase_noise/crystek_22_lvds_traces.pdf')

    compute_jitter_multi(data, True)
    for i in range(1, 6):
        compute_rel_jitter(data[0], data[i], filter=True)
    
    print '-- Source A, receiver B trace length comparison'
    specs = [
        ('phase_noise/crystek_22_direct.csv', 'CCHD-957, 22.5792 MHz, direct'),
        ('phase_noise/crystek_22_ecl_clkf.csv', 'CCHD-957, 22.5792 MHz, ECL, CLKF trace'),
        ('phase_noise/crystek_22_ecl_clk0.csv', 'CCHD-957, 22.5792 MHz, ECL, CLK0 trace'),
        ('phase_noise/crystek_22_ecl_clk1.csv', 'CCHD-957, 22.5792 MHz, ECL, CLK1 trace'),
        ('phase_noise/crystek_22_ecl_clk2.csv', 'CCHD-957, 22.5792 MHz, ECL, CLK2 trace'),
        ('phase_noise/crystek_22_ecl_clk3.csv', 'CCHD-957, 22.5792 MHz, ECL, CLK3 trace'),
    ]
    data = get_pn_multi(specs)
    plot_pn(data)
    pyplot.title('Different trace lengths, LVDS source, ECL receiver')
    if save: pyplot.savefig('phase_noise/crystek_22_ecl_traces.pdf')
    
    compute_jitter_multi(data, True)
    for i in range(1, 6):
        compute_rel_jitter(data[0], data[i], filter=True)
    
    print '-- Crystek 24 MHz vibration comparison'
    specs = [
        ('phase_noise/crystek_24_direct.csv', 'CCHD-957, 24.576 MHz, quiet'),
        ('phase_noise/crystek_24_direct_tabletapping.csv', 'CCHD-957, 24.576 MHz, tapping table'),
    ]
    data = get_pn_multi(specs)
    plot_pn(data, filter=False)
    pyplot.title('Vibration sensitivity of CCHD-957')
    if save: pyplot.savefig('phase_noise/crystek_24_vibration.pdf')
    
    compute_rel_jitter(data[0], data[1], filter=False)
    
    if show: pyplot.show()
    