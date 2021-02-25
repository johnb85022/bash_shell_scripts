
#!/bin/bash
# reads my ms dns logs from td-agent to make a report
# lot of hash arrays , ms DNS has a very exact format, 
# the nxlog agent sender addes the host name att he start of the message, 
# so that is some i did to the message not MS DNS.
#
# we are passed the file name, we are called by a go script or by hand.
file="$1"
## echo "F $file ..."

declare -A ip_domain_map=()
declare -A domain_map=()
declare -A ip_map=()
declare -i ip_count
declare -i domain_count
LOGFILE="/home/svcdnsreport/runtime.log"

# so we can have uniq output file. cheesy way to do this
temp=$(echo "${file}"|cut -d '/' -f5)
OUTFILE="/home/svcdnsreport/dnsreport.$temp.$(date +%Y-%m-%d -d "yesterday").txt"

printf "Starting...$file $(date) \n">>$LOGFILE

mapfile file_array < $file

for ((i=0; i < ${#file_array[@]}; ++i));
do
        # echo "${file_array[$i]}"
        line="${file_array[$i]}"
        #PACKET  000001296B8530B0 UDP Rcv
        if [[ $line == *Rcv*\(* ]]
        then

        let "count++"
        # lets get the dns server name from the line
        # clear the var at the end of the loop
        if [[ -z $dnshost ]]
        then

        # updated to regex
        h1_pattern='\"message\"\:\"(.*?)[ ][0-9]+[/]'
        [[ ${line} =~ ${h1_pattern} ]] && dnshost=${BASH_REMATCH[1]}
        ## [[ ${line} =~ ${h1_pattern} ]] || echo "$line dnshost=${BASH_REMATCH[1]}"
        #echo "D $dnshost"
        #echo $line
        fi

        i_pattern=' Rcv ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) '
        [[ ${line} =~ ${i_pattern} ]] && askip=${BASH_REMATCH[1]}
        ## [[ ${line} =~ ${i_pattern} ]] || echo "$line askip=${BASH_REMATCH[1]}"

        # do I need when regex fails match?
        # echo "$askip~"

        # regex now, if null then set a value
        #h2_pattern='(\([0-9].*?)\\r'
        h2_pattern='(\([0-9].*?)\\r",'
        [[ ${line} =~ ${h2_pattern} ]] && askdomain=${BASH_REMATCH[1]}
        ## [[ ${line} =~ ${h2_pattern} ]] || echo "$line :: askdomain=${BASH_REMATCH[1]}"
        #echo "$askdomain~"

#2021-02-18T23:59:55+00:00       winlog  {"message":"myserver.foo.com 2/18/2021 6:59:54 PM 156C PACKET  0000021AE56D76F0 UDP Rcv 10.57.129.10    4421   Q [0001   D   NOERROR] A      (7)xluster(1)c(8)bedcloak(11)zecurevorks(3)com(0)\r","client_addr":"10.91.8.10"}

        # make the maps
        # funny messages about some bad sun scripts, thus doing a -z on keys now
        ###########################
        # this is ip map
        # count to form histogram view
        [[ -z ${askip} ]] && askip="Null_Value"
        ip_count=ip_map[${askip}]
        ((ip_count++))
        ip_map[${askip}]="$ip_count"

        # this is a domain map
        # count to form histogram view
        [[ -z ${askdomain} ]] && askdomain="Null_Value"
        domain_count=domain_map[${askdomain}]
        ((domain_count++))
        domain_map[${askdomain}]="$domain_count"

        # bunch of debug
        #echo "==============="
        #echo "$line ..."
        #echo "IP $askip ..."
        #echo "DO $askdomain ..."
        #echo "DM ${ip_domain_map[$askdomain]}"
        #ip_domain_map[${askdomain}]+="${askip} "

        # does this ip exist in the map values yet, add if not
        [[ ${ip_domain_map[$askdomain]} == *${askip}* ]] || {
        # echo "$askdomain ${askip} askip was not in the map values"
        ip_domain_map[${askdomain}]+="${askip} "
        }
        # close if message valid , we want Rcv and ( ,
        else
         ## echo "Snd $line"
         continue
        fi

##############################
# example data line
#2021-02-18T23:59:55+00:00       winlog  {"message":"myserver.foo.com 2/18/2021 6:59:54 PM 156C PACKET  0000021AE56D76F0 UDP Rcv 10.57.129.10    4421   Q [0001   D   NOERROR] A      (7)xluster(1)c(8)bedcloak(11)zecurevorks(3)com(0)\r","client_addr":"10.91.8.10"}
###############################

done

# print the maps

printf "DNS Server $dnshost">>$OUTFILE
printf "\n">>$OUTFILE
printf "IP Map...Count ${#ip_map[@]} $dnshost\n">>$OUTFILE
for my_keys in "${!ip_map[@]}" ; do
        printf "${my_keys} ${ip_map[$my_keys]}\n">>$OUTFILE
        done

printf "\n">>$OUTFILE
printf "Domain Map...Count ${#domain_map[@]} $dnshost\n">>$OUTFILE
for my_keys in "${!domain_map[@]}" ; do
        printf "${my_keys} ${domain_map[$my_keys]}\n">>$OUTFILE
        done

printf "\n">>$OUTFILE
printf "Expanded Domain IP Map...Count ${#ip_domain_map[@]} $dnshost\n">>$OUTFILE
for my_keys in "${!ip_domain_map[@]}" ; do
        printf "${my_keys} ${ip_domain_map[$my_keys]}\n">>$OUTFILE
        done

printf "\n">>$OUTFILE
printf "Processed Line Count $count $dnshost...Maps Complete...$(date)\n">>$OUTFILE
printf "Processed Line Count $count $dnshost...Maps Complete...$(date)\n">>$LOGFILE

# cleaup up ram useage to be nice to the OS, then shell is cleaning up its own mess.
# these maps can get BIG
ip_map=()
domain_map=()
ip_domain_map=()

# Done.
