#!/bin/bash

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
