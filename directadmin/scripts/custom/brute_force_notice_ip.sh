#!/bin/sh
#VERSION=2.2
#
# Source: http://help.directadmin.com/item.php?id=380

###############################
NOFIY_BY_EMAIL=0

## Give your server a name for easy idenfication
SERVER=$(hostname -s)

## Where you want the email to be sent to
#EMAIL=your@address.com

###############################

if [ "${NOFIY_BY_EMAIL}" -gt 0 ]; then
  echo "IP $value has been blocked for making $count failed login attempts
  $data
  $(dig -x $value)" | mail -s "$SERVER: blocked $value for $count failed attempts" $EMAIL
fi

###############################

SCRIPT=/usr/local/directadmin/scripts/custom/block_ip.sh
ip=$value $SCRIPT

exit $?
