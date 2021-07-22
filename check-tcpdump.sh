#!/bin/bash
# I see if the tcpdump is running
# 6 min under cron
# restart if needed
# Cmd is run with option for 30
# 24 min is stop and restart
# tcpdump is run with
# 1800 eg 30 min
# all the hosty should be ens192
# -G how long to run, then exit
# -w is the file name spec
# -i the card to watch
# full paths
# reminder ":" is true, is a NOOP for bash
####

##set -x

enetcard="ens160"
duration="1800"
MYTCP="/home/tcpdump"

# syslog is my log file
[ -d $MYTCP ] || {
  echo "Home tcpdump is missing, Exiting $(date)..." | logger
  exit
  }

# exit if stop file is in the folder
[ -e /home/tcpdump/stop ] && {
  echo "Stop file in the folder. Exiting..."
  echo "Stop file in the folder. Exiting..." | logger
  pkill tcpdump
  exit
}

# is it running do nothing
ps -efl | grep -q "/[u]sr/sbin/tcpdump" && {
 # echo "Debug tcpdump is running ..."
 # ps -elf |grep tcpdump
 :
}

# if not running start it up.
ps -efl | grep -q "/[u]sr/sbin/tcpdump" || {
 cd $MYTCP
 # echo "Debug tcpdump is not runing..."
 echo  "tcpdump is not running , Starting $(date)..." | logger
 nohup  /usr/sbin/tcpdump -i "$enetcard" 'port 53' -G "$duration" -w "$MYTCP"/$(uname -n).tcpdump-%m-%d-%H-%M-%S-%s.pcap > /var/log/tcpdump.log 2>&1 &

}

