"""
    Open-source digital audio platform
    Copyright (C) 2009--2018 Michael Price

    utils.py: Assorted utility functions.

    Warning: Use and distribution of this code is restricted.
    This software code is distributed under the terms of the GNU General Public
    License, version 3.  Other files in this project may be subject to
    different licenses.  Please see the LICENSE file in the top level project
    directory for more information.
"""

from datetime import datetime

import numpy
from matplotlib import colors

def get_elapsed_time(time_start):
    time_end = datetime.now()
    time_diff = time_end - time_start
    return time_diff.seconds + 1e-6 * time_diff.microseconds

def get_color(N, i):
    color_hsv = numpy.array([float(i) / N * 0.8, 1.0, 0.7])
    color_hsv.shape = (1, 1, 3)
    trace_color = colors.hsv_to_rgb(color_hsv)
    trace_color.shape = (3,)
    return trace_color

