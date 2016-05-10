#!/bin/sh

BF=/root/blocked_ips.txt

# /sbin/ipfw table 10 list | sed 's/\/32 0//g'

echo "havedata=1"

cat $BF

exit 0



