#!/bin/sh
# This script will ensure that the quotas are set in the /etc/fstab file.

## 2016-05-12: Portsbuild version
## Todo:

printf "Checking quotas...\n"

PERL=/usr/local/bin/perl
FSTAB=/etc/fstab

${PERL} -pi -e 's/[\ \t]+\/home[\ \t]+ufs[\ \t]+rw[\ \t]+/\t\t\/home\t\t\tufs\trw,userquota,groupquota\t/' $FSTAB
${PERL} -pi -e 's/[\ \t]+\/[\ \t]+ufs[\ \t]+rw[\ \t]+/\t\t\t\/\t\t\tufs\trw,userquota,groupquota\t/' $FSTAB

NUM=$(cat $FSTAB | grep -c procfs)
if [ "$NUM" -eq 0 ]; then
  printf "proc\t\t\t/proc\t\tprocfs\trw\t\t0\t0\n" >> $FSTAB
  /sbin/mount_procfs procfs /proc
fi

# Hide the errors, it was confusing people
/usr/sbin/mount -u /home 2> /dev/null 1> /dev/null
/usr/sbin/mount -u / 2> /dev/null 1> /dev/null
/usr/sbin/quotaoff -a 2 > /dev/null > /dev/null
/sbin/quotacheck -avug 2> /dev/null
/usr/sbin/quotaon -a 2> /dev/null 1> /dev/null

exit 0
