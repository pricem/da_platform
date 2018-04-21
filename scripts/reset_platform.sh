#!/bin/bash

#   Open-source digital audio platform
#   Copyright (C) 2009--2018 Michael Price
#
#   reset_platform.sh: Example script for full restart of an active crossover
#   using "speakers" library.  Should be run with amplifiers off, since it
#   can generate thumps at the DAC outputs.  But you normally shouldn't need
#   to use this.
#
#   Warning: Use and distribution of this code is restricted.
#   This software code is distributed under the terms of the GNU General Public
#   License, version 3.  Other files in this project may be subject to
#   different licenses.  Please see the LICENSE file in the top level project
#   directory for more information.

origdir=`pwd`

sudo supervisorctl stop all

echo "Resetting FPGA..."
cd /home/pi/software/ztex/java/FWLoader
./FWLoader -rf
./FWLoader -ru

echo "Selecting clock..."
cd /home/pi/projects/cdp/python
python setup_clock.py

echo "Restarting filters..."
sudo supervisorctl start all

echo "Done."
cd $origdir

