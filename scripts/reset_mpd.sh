#!/bin/bash

#   Open-source digital audio platform
#   Copyright (C) 2009--2018 Michael Price
#
#   reset_mpd.sh: Example script for starting up (or killing and restarting)
#   an MPD installation.
#
#   Warning: Use and distribution of this code is restricted.
#   This software code is distributed under the terms of the GNU General Public
#   License, version 3.  Other files in this project may be subject to
#   different licenses.  Please see the LICENSE file in the top level project
#   directory for more information.

sudo modprobe snd-aloop
sudo killall -9 mpd
sudo rm /var/log/mpd/mpd.log
sudo rm -r /var/run/mpd
sudo rm -r /var/lib/mpd
sudo mkdir /var/run/mpd
sudo mkdir /var/lib/mpd
sudo chown -R mpd /var/run/mpd
sudo chown -R mpd /var/lib/mpd
sudo mount -a
sudo -u mpd mpd /etc/mpd.conf
#python /home/pi/projects/cdp/python/setup_clock.py

echo "Ready to start speakers"

