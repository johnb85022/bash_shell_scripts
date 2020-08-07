#!/bin/bash
# Just collect and clean up NRD, New domains. 
# Who jb, who you expect
# what get nrd , clean then , other scripts can read the input
# when 05/2020
# based on
# https://github.com/Crypt-0n/Download-newly-registered-domains-list
# I did not mod his work, what I have is some extra stuff to 
# take care of the files and output, 
# Edit WORKING_DIR to make it work for you. 

#####
WORKING_DIR="/home/johnb/SecTools"
NRD_DOMAINS="domain-names.txt"
CLEAN_DOMAINS="nrd.clean.domains-unix.txt"
LOG="gather.nrd.runtime.log"
TODAY=$(date '+%Y.%m.%d')
YESTERDAY=$(date --date '1 days ago' '+%Y.%m.%d')
STATS="output.stats.txt"
#####
cd $WORKING_DIR

echo "Starting ... $0 $(date)" > $LOG
# pre start clean
[[ -f $NRD_DOMAINS ]] && rm $NRD_DOMAINS
[[ -f $CLEAN_DOMAINS ]] && rm $CLEAN_DOMAINS

# from git script

datedl=$(date --date '1 days ago' '+%Y-%m-%d')
zip="$datedl.zip"
b64=$(echo $zip | base64)
ok=$(expr $b64 : "\(.*\).$")

# was
#urlbase="https://whoisds.com//whois-database/newly-registered-domains/"
# now is, see the www
urlbase="https://www.whoisds.com//whois-database/newly-registered-domains/"
urlend="=/nrd"
allurl="$urlbase$ok$urlend"

#echo $ok
#echo "url"
#echo "$allurl"
# Ref example.
# echo "https://www.whoisds.com//whois-database/newly-registered-domains/MjAyMC0wOC0wMy56aXA=/nrd"


# Download the NRD info from one day ago.
wget -q -O $zip $allurl

##wget -O newfoo.zip $allurl
#wget -O newfoo.zip "https://www.whoisds.com//whois-database/newly-registered-domains/MjAyMC0wOC0wMy56aXA=/nrd"

if [[ ! -s $zip ]]
        then
        printf "Error $zip is zero bytes... Check the URL."
        exit 128
        fi

unzip $zip &>> $LOG

#####
# use tr to clean the file from dos to unix,
# the dos format is in the zip file from wget
# not the whole just some lines some times,
# echo "tr the domains file..."
# toss error is zero bytes

if [  ! -s  $NRD_DOMAINS ]
   then
        echo "Error the file $NRD_DOMAINS is zero size." >> $LOG
        echo "Error the file $NRD_DOMAINS is zero size."
        exit 128
   else
        tr -d '\r' < "$NRD_DOMAINS" > "$CLEAN_DOMAINS"
        # use sort as a type of copy
        #printf "$CLEAN_DOMAINS YCD -- > $YESTERDAY.$CLEAN_DOMAINS"

        sort -u "$CLEAN_DOMAINS" > "$YESTERDAY.$CLEAN_DOMAINS"
        # save some info
        date >> $STATS
        wc -l "$YESTERDAY.$CLEAN_DOMAINS" >> $STATS
        # ok we are done...
        echo "Complete ... $(date)" >> $LOG
fi

exit 0
