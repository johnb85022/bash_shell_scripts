# may the force be with you....
# read a list of domains and  kick out uniq IP v4 only
# grep -o handy 
for x in $(<list.txt); do
          # no ipv6 , Ip v4, no spaces
        host "$x" |grep -v -E "[[:digit:]][:]" |grep -o -E "[[:space:]][[:digit:]]+[.][[:digit:]]+[.][[:digit:]]+[.][[:digit:]]+"|tr -d ' '
done |sort -u
