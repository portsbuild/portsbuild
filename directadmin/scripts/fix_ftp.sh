#!/bin/sh
# Script written by DirectAdmin
# URL: http://www.directadmin.com
# Source: http://help.directadmin.com/item.php?id=205
#
# Usage:
#   chmod 755 fix_ftp.sh
#   ./fix_ftp.sh >> /etc/proftpd.passwd
#   chown root:ftp /etc/proftpd.passwd
#   chmod 640 /etc/proftpd.passwd

PF=/etc/proftpd.passwd

cd /usr/local/directadmin/data/users || exit

for u in $(ls); do {
  if [ ! -d "$u" ]; then
    continue
  fi

  SHADOW=/home/$u/.shadow
  if [ ! -e "$SHADOW" ]; then
    continue
  fi

  ## DA: Make sure it doesn't already exist
  COUNT=$(grep -c -e "^${u}:" $PF)
  if [ "$COUNT" -ne 0 ]; then
    continue
  fi

  UUID=$(id -u "$u")
  UGID=$(id -g "$u")

  echo "${u}:$(cat "/home/$u/.shadow"):${UUID}:${UGID}:system:/home/${u}:/bin/false"
}
done

exit 0
