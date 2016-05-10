#!/bin/sh
#VERSION=2.2
#
# Source: http://help.directadmin.com/item.php?id=380

BF=/root/blocked_ips.txt
EF=/root/exempt_ips.txt
OS=$(uname)

BLOCK_CHAIN=blocked_ips

## Current IPs in Table
curriptables() {

  printf "<br><br><textarea cols=160 rows=60>\n"

  if [ "$OS" = "FreeBSD" ]; then
    /sbin/ipfw table 10 list
  else
    /sbin/iptables -nL
  fi

  printf "</textarea>\n"
}

if [ "$ip" = "" ]; then
  printf "No IP address has been passed via env.\n"
  exit 1
fi

### Do we have a block file?
if [ ! -e "$BF" ]; then
  printf "Cannot find %s\n" $BF
  exit 1
fi

### Do we have an exempt file?
if [ ! -e "$EF" ]; then
  printf "Cannot find %s\n" $EF
  exit 1
fi

### Make sure it's not exempt
COUNT=$(grep -c "^${ip}\$" $EF)
if [ "$COUNT" -ne 0 ]; then
  printf "%s in the exempt list (%s). Not blocking.\n" $ip $EF
  curriptables
  exit 2
fi

### Make sure it's not alreaday blocked
COUNT=$(grep -c "^${ip}=" $BF)
if [ "$COUNT" -ne 0 ]; then
  printf "%s already exists in %s (%s). Not blocking.\n" $ip $BF $COUNT
  curriptables
  exit 2
fi

printf "Blocking %s<br>\n" $ip
echo "$ip=dateblocked=$(date +%s)" >> $BF

if [ "$OS" = "FreeBSD" ]; then
  /sbin/ipfw -q table 10 add $ip
else
  printf "Adding %s into %s chain...\n" $ip ${BLOCK_CHAIN}
  /sbin/iptables -A ${BLOCK_CHAIN} -s $ip -j DROP
fi

printf "<br><br>Result:\n"

curriptables

exit 0
