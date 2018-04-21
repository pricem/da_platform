#!/bin/bash
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

