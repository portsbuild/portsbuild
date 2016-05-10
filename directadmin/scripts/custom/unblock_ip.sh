#!/bin/sh
#VERSION=2.2
#
# Source: http://help.directadmin.com/item.php?id=380

BF=/root/blocked_ips.txt
OS=$(uname)

BLOCK_CHAIN=blocked_ips

if [ "$ip" = "" ]; then
  printf "Usage:\n"
  echo "  $0 1.2.3.4"
  exit 1
fi

if [ ! -e "$BF" ]; then
  echo "cannot find $BF to unblock the IP"
  exit 2
fi

COUNT=$(grep -c "^$ip=" $BF);

if [ "$COUNT" -eq 0 ]; then
  echo "$1 was not in $BF. Not unblocking"
  exit 2
fi

## Unblock
printf "Unblocking %s" $IP

cat $BF | grep -v "^$ip=" > $BF.temp
mv $BF.temp $BF

chmod 600 $BF

if [ "$OS" = "FreeBSD" ]; then
  /sbin/ipfw -q table 10 delete $ip
else
  /sbin/iptables -D ${BLOCK_CHAIN} -s $ip -j DROP
fi

exit 0
