#!/bin/bash
# Who JB 
# What Ok so whats new today in the SWX Ip listings
# When once a day via cron
# Why ....................
# ...............................
# JB v1 , email to me
#set -x

echo "Starting $0 $(date) ..." |logger
# set a working dir
DIR="/home/aplace/SWXListCheck"
cd $DIR
HISTORY="/home/aplace/SWXListCheck/history.hits.txt"
REPORTEDHISTORY="/home/aplace/SWXListCheck/history.reports.txt"

# clean before we work
find $DIR -type f -name "list.tmp" -delete

# the list my vendor is publishing
# wget today name of the day dot txt
# 7 days of file , dont need more , no need to clean up
# take q out if need to see what wget is doing
# save wget -q "https://ws.secureworks.com/ti/v1/attackerdb-token/blackList?type=ip&listId=0&format=pan&token=9442f7c4ef1c7b50" -
O SWX.$(date +"%a").txt

wget -q "https://ws.secureworks.com/ti/v1/attackerdb-token/blackList?type=ip&listId=0&format=pan&token=9442f7c4ef1c7b50" -O SWX.$
(date +"%a").txt

# grep is cool, save to file, check to
# 
grep -vFxf SWX.$(date "+%a").txt SWX.$(date --date="1 day ago" +"%a").txt > "$DIR/list.tmp"

# is not zero then do some work
if [[ -s "$DIR/list.tmp" ]] ; then

   echo "Found Hit $0 $(date) ..." | logger
   # history of the greatest hits
   cat "$DIR/list.tmp" >> $HISTORY

   # email to a list, pints are in the body, 
   cat "$DIR/list.tmp" | mailx -s "::SWX BL Change Report::" user@fun.org, happy@fun.org 
   # reminder list form for mailx user@fun.org, happy@fun.org 

# close the if
fi

# clean post
find $DIR -type f -name "list.tmp" -delete

# make a SWX history of all things ever reported
cat $HISTORY > SWX.tosort.txt
sort -u $DIR/SWX*.txt > "$REPORTEDHISTORY"
# fusy clean up
find $DIR -type f -name "SWX.tosort.txt" -delete
