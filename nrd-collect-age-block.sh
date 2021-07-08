#!/bin/bash
# Get NRD, age them
# Who jb, who you expect
# what get nrd , age records, make a block nrd
# when 05/2020
# why to stop the common fraud domains
# based on
# https://github.com/Crypt-0n/Download-newly-registered-domains-list
#


WORKING_DIR="/home/blmgr/nrd-block"
ACTIVE_TABLE="active.table.txt"
NRD_DOMAINS="domain-names.txt"
DECAY_DOMAINS="decay-domain-names.txt"
CLEAN_DOMAINS="domain-unix.txt"
NRD_PUBLISH="block-nrd.txt"
TEMP="updated.tmp.table.txt"
LOG="runtime.log"
now=$(date -u "+%s")
array_domains=()

cd $WORKING_DIR

# pre start clean
[[ -f $NRD_DOMAINS ]] && rm $NRD_DOMAINS
[[ -f $CLEAN_DOMAINS ]] && rm $CLEAN_DOMAINS
[[ -f $TEMP ]] && rm $TEMP
[[ -f $NRD_PUBLISH ]] && rm $NRD_PUBLISH

# from git script

datedl=$(date --date '1 days ago' '+%Y-%m-%d')
zip="$datedl.zip"
b64=$(echo $zip | base64)
ok=$(expr $b64 : "\(.*\).$")

urlbase="https://whoisds.com//whois-database/newly-registered-domains/"
urlend="=/nrd"

allurl="$urlbase$ok$urlend"

# comment to pause downloading
wget -q -O $zip $allurl
unzip $zip &> $LOG

# use tr to clean the file from dos to unix
# the dos format is in the zip file from wget
tr -d '\r' < "$NRD_DOMAINS" > "$CLEAN_DOMAINS"

##################
# load NRD table
declare -A nrd_map
mapfile array_domains < "$CLEAN_DOMAINS"

for x in ${array_domains[@]}
do
nrd_map[$x]="$x,$now"
done
array_domains=()

#echo "NM ${#nrd_map[@]}"
#printf "%s\n" "${!nrd_map[@]}"
#printf "%s\n" "${nrd_map[@]}"
# NRD loaded

##################
# Load active table

ACTIVE_TABLE="active.table.txt"
declare -A active_map
mapfile array_active < "$ACTIVE_TABLE"

for x in ${array_active[@]}
do
record_name=${x%,*}
active_map[$record_name]="$x"
done
array_active=()

#echo "AM ${#active_map[@]}"
#printf "%s\n" "${!active_map[@]}"
#printf "%s\n" "${active_map[@]}"
# Active loaded

####################################
# Now, loop over NRD update active table , update values
# no need to test values just update based on key

##echo "Keys Values Active Map Update"
for my_keys in "${!nrd_map[@]}"
do
        active_map[$my_keys]="${nrd_map[$my_keys]}"
        done
## printf "%s\n" "${active_map[@]}"
# Active updated
# Toss the mem of the NRD table
nrd_map=()

####################################
# Last age the active table post update

# echo "Keys Values Active Map Decay"
decay_factor=604800

for my_keys in "${!active_map[@]}"
do
        active_name=${my_keys}
        active_age=${active_map[$my_keys]#*,}

# shift out records based on age
decay="$(( $now-${active_age} ))"

if (( decay > decay_factor )) ;
then

        # echo "$active_record D $decay > $decay_factor"
        ## printf "%s ..\n" "Record Decay $active_name"
        printf "$active_name\n" >> $DECAY_DOMAINS
else
        ## printf "Record Active $active_name ${active_map[$my_keys]}"
        printf "%s,%s\n" $active_name $active_age >> $TEMP
fi

done

####################################
# temp to active
# printf "Sorting ...\n"
#wc -l $TEMP
# sort with uniq of temp table, makes new table
sort -u $TEMP > $ACTIVE_TABLE
## this is so lazy, just need basic IO, so eh,
cat $ACTIVE_TABLE |cut -d , -f1 |sort -u > $NRD_PUBLISH
# Ende.

