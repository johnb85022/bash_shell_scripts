#!/bin/bash
# I see if the tcpdump is running
# stop and start it
# clean up old files
# all the hosty should be ens192
# will have to find the ens is not ens192
# -G how long to run, then exit
# -w is the file name spec
# -i the card to watch
# full paths
#
####

# set -x

enetcard="ens160"
duration="1800"
MYTCP="/home/tcpdump"

# syslog is my log file
[ -d $MYTCP ] || {
  echo "Home tcpdump is missing, Exiting $(date)..." | logger
  exit
  }

find /home/tcpdump/ -type f  -name "*.pcap" -mtime +24 -delete

# exit if stop file is in the folder
[ -e /home/tcpdump/stop ] && {
  echo "Stop file in the folder. Exiting..."
  echo "Stop file in the folder. Exiting..."| logger
  pkill tcpdump
  exit
}



# is then stop it, sleep 1 then start it
 cd $MYTCP
 # echo "Debug tcpdump is running ..."
 pgrep tcpdump  |logger
 pkill tcpdump
 # clean up over 5 hours this job is planed for 4 hour cron
 find $MYTCP -name "nohup.out" -delete
 find /home/tcpdump/ -type f -name "*.pcap" -mmin +300 -delete
 # echo "Sleep then start..."
 echo "Sleep then start $0 $(date) ..."| logger
 sleep 1
 nohup  /usr/sbin/tcpdump -i "$enetcard" 'port 53' -G "$duration" -w "$MYTCP"/$(uname -n).tcpdump-%m-%d-%H-%M-%S-%s.pcap > /var/log/tcpdump.log 2>&1 &

## the end...##
