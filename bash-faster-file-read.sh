#!/bin/bash

# just grep
# xargs to speed it up some


# faster grep
export LC_ALL=C

D_STR=$(date --date '1days ago' "+%Y.%m.%d")
FILES=$(ls -tr /home/syslog-ng/remote/{10.92.15.1.$(date --date '1days ago' '+%Y.%m.%d').log,10.91.15.1.$(date --date '1days ago' '+%Y.%m.%d').log} )
OUTFILE="/home/vpninfo/history/vpninfo.$D_STR.$(uuidgen).txt"


for x in $FILES;
do
        ## echo $x ;
        echo $x | xargs -n1 -P 12 grep -F 'client_vpn_connect' >> $OUTFILE;
        # grep -F 'client_vpn_connect' $x >> $OUTFILE;
done
