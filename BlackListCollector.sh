#!/bin/bash
#title           cron-job-black-list-manager.sh
#description     non interactive script for cron or manual run to run collection, uniq, and push of BL files
#author          JB, AW
#date            2019 04 and 05
#version         V2
#usage           ./v4.cron-job-black-list-manager.sh
#notes           bash, and wget are used, Linux centos
#bash_version    installed centos bash
#
######################################################
# Note
# Yes these functions are copy paste from the bl menu manager
# Output to screen is OFF
# if you see ## cmd, that is a debug line to watch things at run time,

######################################################
sync_file () {
publish_dir="/var/www/html/"
# pause, add cp
echo "Syncing all files..." >> $LOG
# For AWS we can copy...
LIST="allow-ip-meraki.txt allow-ip.txt block-ip.txt allow-url.txt block-url.txt block-ip-meraki.txt"
for file in $LIST
do
echo "$(cp $file $publish_dir )" >> $LOG
done
# adding small copy
cp fileage.txt $publish_dir

}

######################################################
uniq_file () {
## LIST="block-ip.txt block-url.txt"
LIST="block-url.txt"
TEMP=cron.uniq.temp.txt
MD5LOG="md5sum.log"
[ -a $TEMP ] && rm $TEMP
for PROD_FILE in $LIST
do
echo "Uniq $PROD_FILE ..."  >> $LOG

# no leading spaces pls...
sed -i -e 's/[[:space:]]*$//' $PROD_FILE
# lower case, no ip v6 pls...
sort -u  $PROD_FILE | tr -s "[:space:]" | tr "[:upper:]" "[:lower:]" |grep -v -E -e '#' -e '\(' -e '\?' |grep -v -E -e "\S{4,4}:\S{4,4}" > $TEMP
cat $TEMP > $PROD_FILE
[ -a $TEMP ] && rm $TEMP
echo "Counts $(wc -l $PROD_FILE)"  >> $LOG
echo "md5sum $(md5sum $PROD_FILE)" >> $LOG
echo "$(date) md5sum $(md5sum $PROD_FILE)" >> $MD5LOG
done
[ -a $TEMP ] && rm $TEMP
# to watch the age of the files via www
ls -l *.txt|grep -e allow -e block|tr -s ' '|cut -d ' ' -f6,7,8,9,10 > fileage.txt
# basic sort and uniq of the file sets, all on them, no point in picking just one
}


######################################################
meraki_file () {
#
# awk was the short cut of the week.
# calling the file by name
awk -vs1= '{S=S?S OFS s1 $0 s1:s1 $0 s1} END{print S}' OFS=, block-ip.txt > block-ip-meraki.txt

awk -vs1= '{S=S?S OFS s1 $0 s1:s1 $0 s1} END{print S}' OFS=, allow-ip.txt > allow-ip-meraki.txt

}


######################################################
# aim to make an map array and stop useing files
collect_bl_ip () {
echo "Collecting BL IP lists..." > $LOG
BL_SOURCES=blacklist.ip.sources.txt
DENY_LIST=block-ip.txt
# start off clean, else the RUS can pile on too much
[ -a $DENY_LIST ] && rm $DENY_LIST

# array is temp, subnet_map array is the target collection
array=()
declare -A subnet_map=()

for x in $(<$BL_SOURCES)
do
        # step a. put to memory and not file , x is a singles url
        echo "Wget from $x ..."  >> $LOG
        array[${#array[@]}]=$(wget -q --tries=3 --timeout=12 -O  -  $x| grep -v -e "^#" -e "^$" -e "^[ ]+$" | tr '\t' ' ' |tr -d '\r' )
        # echo "${array[*]}" > ondisk.$(uuidgen).txt
        echo "Wget from $x ..."  >> $LOG
done

# all the data landing in the array array
echo "Wget complete..." >> $LOG
echo "$(date) Sub Netting the BL lists...">> $LOG

# array is the results of the wgets sub net the IP
# step b. land the sunbet in to the map array
V6rejects="V6.rejects.txt"
for ip in ${array[@]}
do
        fix=${ip}
        fix=$(echo "${fix%-*}")
        ## echo "F $fix"
        ip=${fix}

        # Leak on ipv6, got past the wget grep filter
        v6patt=":"
         if [[ "$ip" =~ "$v6patt" ]]
         then
            # open a log file for debug
            # echo "V6 $ip" >> "$V6rejects"
            continue
         fi


        # two blocks to test if has sub net or no subnet
        # no slash no sub net
        [[ "$ip" =~ ".0/24" ]] || {
        # printf "%s\n" "${ip}"
        subnet_map[${ip%.*}.0/24]="${ip%.*}.0/24"
}
        # slash yes has sub net
        ### [[ "$ip" =~ ".0/24" ]]
        [[ "$ip" =~ "/" ]] && {
        # printf "%s\n" "Has subnet $ip"
        subnet_map[${ip}]=${ip}
}
done

# clear the temp array, give back ram for speed
array=()

# K is KEY unroll the map array to a file.
echo "$(date) Sub Netting complete...." >> $LOG
# un roll to see
counter=0
bl_limit=29500
for K in "${!subnet_map[@]}"
do
        (( counter++))
        ## echo "C $counter ..."
        if [[ $counter -gt $bl_limit ]]
          then
          echo "Break $count $bl_limit ..."
          break
         fi
        echo $K >> $DENY_LIST
done

# clear the map array
declare -A subnet_map=()
# no uniq needed , map array makes it uniq , when we saved the subnet.

}

######################################################
collect_bl_url (){
#LIST="allow-ip.txt block-ip.txt allow-url.txt block-url.txt"
echo "Collecting BL URL lists..."  >> $LOG
TEMP=cron.url.temp.txt
BL_SOURCES=blacklist.url.sources.txt
DENY_LIST=block-url.txt
[ -a $DENY_LIST ] && rm $DENY_LIST
[ -a $TEMP ] && rm $TEMP
for x in $(<$BL_SOURCES)
do
# filter out comments and blanks tabs to one space bloddy mac \r
wget -q --tries=3 --timeout=12 -O  -  $x | grep -v -e "^#" -e "^$" -e "^[ ]+$" | tr '\t' ' ' |tr -d '\r' >> $TEMP
echo "Wget $x ..." >> $LOG
done
echo "Wget complete...merge and sorting next..." >> $LOG

# filter out comments and blanks tabs to one space bloddy mac \r
sort -u $TEMP | grep -v -e "^#" -e "^$" -e "^[ ]+$" |tr '\t' ' ' |tr -d '\r' >> $DENY_LIST
[ -a $TEMP ] && rm $TEMP
IFS_SAVE=$IFS
IFS=$'\n'

# disk based loop, not mapfile yet
for url_item in $(<$DENY_LIST)
do
## echo ${url_item}
# add a collection array

# 99 perfcent of the time if it needs reformating
# is has one item to factor, packip is a new
# thing , so far if I strip the lead then the packed ip
# is next. So I can still get away with >> file
# to publish, but close to have to pass to array soon.
# JB 05/04
# this is the cut and clean section
#
[[ "${url_item}" =~ "http://" ]] && {
echo "${url_item:7}" >> $TEMP
url_temp="${url_item:7}"
#echo "HS $url_temp"
}
[[ "${url_item}" =~ "https://" ]] && {
echo "${url_item:8}" >> $TEMP
url_temp="${url_item:8}"
#echo "HS $url_temp"
}

# strip leader 0.0.0.0
# 0.0.0.0 101order.com
# 0.0.0.0 oascentral.virtualtourist.com
patt="0.0.0.0 "
[[ ${url_item} =~ ${patt} ]] && {
url_temp="${url_item:8}"
echo "$url_temp" >> $TEMP
#
}

# 0.0.0.0 102.6.87.194.dynamic.dol.ru
# will be 102.6.87.194.dynamic.dol.ru see url_temp above
patt="[0-9]+.[0-9]+.[0-9]+.[0-9]+"
[[ ${url_temp} =~ ${patt} ]] && {
# this is nuts, but works
echo "${url_temp} ::: ${url_temp#*\.*\.*\.*\.*}" >> $TEMP
}


# strip http , https , Zed , lead packip
# this was its clean so publish it
# to simple now, if did not hit a cleaner, then should be ok
[[ "${url_item}" =~ "http" ]] || {
echo "${url_item}" >> $TEMP
}

done
IFS=$IFS_SAVE

sort -u $TEMP > $DENY_LIST
[ -a $TEMP ] && rm $TEMP
echo "Md5sum $(md5sum $DENY_LIST)"       >> $LOG
echo "Count $(wc -l $DENY_LIST)"         >> $LOG
# final list is denyurl.txt ,collect the bl souces lists, uniq each, then uniq the one, reduction was about 10 to 30 perfect, fyi

}

######################################################
file_check () {

CHECK_LOG=/home/blmgr/BlackListManager/check.file.log
declare -i BLSIZE
declare -i LIMIT
LIMIT=28000
mapfile my_check < block-ip.txt
BLSIZE=${#my_check[@]}
#echo "$(date) BL $BLSIZE LM $LIMIT" >> $CHECK_LOG

if [ "$BLSIZE" -gt "$LIMIT" ]; then
  echo "$(date) Over bl size limit $BLSIZE $LIMIT ..." >> $CHECK_LOG
else
  echo "$(date) OK under bl size limit $BLSIZE $LIMIT ..." >> $CHECK_LOG
fi

}

######################################################
cron_stop () {
# touch stop.cron.txt
[ -a /home/blmgr/BlackListManager/stop.cron.txt ] && {
echo "Stoping the cron job, stop.cron.txt was seen." || tee -a LOG
## echo "stop..."
exit
}
}

######################################################
history_file () {
# keeping a history, the -o on sort helps keep the number of files used
# lower. about 60 sec run time for the function
LIST="allow-ip.txt block-ip.txt allow-url.txt block-url.txt"
for x in $LIST
do
[[ -a $(date "+%m.%d.%Y").$x ]] || touch $(date "+%m.%d.%Y").$x
sort -u "$x" "$(date "+%m.%d.%Y").$x" -o "$(date "+%m.%d.%Y").$x"
done
}


######################################################
# main, call functions,
# collect, url, ip, uniq, sync...
# few defaults as we start, touch the stop.cron.txt if we dont want it to run
# touch stop.cron.txt
# comments are off , urls not published, just domain...
# big update to IP collection, array based now.
# history added, bl limit added
WORKDIR="/home/blmgr/BlackListManager/"
cd $WORKDIR
## pwd
LOG=$(date "+%A").cron.job.black.list.manager.log
echo "Starting cron job lack list manager ...$(date) $0 $(who grep $(whoami))"|tr -s "[:space:]" >>  $LOG
cron_stop
history_file
collect_bl_url
collect_bl_ip
uniq_file
meraki_file
file_check
sync_file
echo "Complete cron job lack list manager ...$(date) $0 $(who grep $(whoami))"|tr -s "[:space:]" >>  $LOG
# Ende.
