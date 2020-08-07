#!/bin/bash
# Who, JB
# What, Peek at nets via nmap
# When, 04 of 2020
# Why, found a server with exploit on it...

INPUT=$1
D_STR=$(date "+%Y.%m.%d")
LOG="$D_STR.scan.net.log"

## echo "Starting $(date) $(whoami) $0 ..." | tee $LOG
# Am I root ?
if ( whoami |grep -q 'root' )
then
        echo "I am root ..." | tee -a $LOG
else
        echo "I am not root, run as sudo ./script ... exiting." | tee -a $LOG
        exit 128
fi

# So I have a file to read ?
if [[ -a $INPUT ]]
then
        echo "Working with $INPUT input file ..." | tee -a $LOG
else
        echo "Missing input file? $INPUT run as sudo ./script.sh input.net.txt ... exiting." | tee -a $LOG
        exit
fi

mapfile file_array < "${INPUT}"

for ((i=0; i < ${#file_array[@]}; ++i));
do
        echo "Scanning ${file_array[$i]} ... " | tee -a $LOG
        # gen the file name for each loop
        OUTPUT="scan.output.$D_STR.$(uuidgen).txt"
        SCAN_CMD="nmap -v -sV -T4 -O -oG $OUTPUT -F --version-light"
        echo "dot dot dot"
        eval $SCAN_CMD ${file_array[$i]}

done

echo "Complete $(date) $0 ... See files scan.star.uuidgen.txt." | tee -a $LOG
exit 0
