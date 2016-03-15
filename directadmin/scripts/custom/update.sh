#!/bin/sh

# 2016-02-20: Modified for PortsBuild

DA_PATH=/usr/local/directadmin
DA_SCRIPTS=${DA_PATH}/scripts
DA_TQ=${DA_PATH}/data/task.queue

#added new options to templates
#echo 'action=rewrite&value=httpd' >> $DA_TQ

{
  echo "action=cache&value=showallusers"
  echo "action=cache&value=safemode"
  echo "action=convert&value=cronbackups"
  echo "action=convert&value=suspendedmysql"
  echo "action=syscheck"
} >> $DA_TQ

## PB: Verify this:
if [ ! -d /usr/local/sysbk ]; then
  cd $DA_SCRIPTS || exit
  ./sysbk.sh
fi

grep "usertype=reseller" /usr/local/directadmin/data/users/*/user.conf | cut -d/ -f7 > /usr/local/directadmin/data/admin/reseller.list
chown diradmin:diradmin /usr/local/directadmin/data/admin/reseller.list
chmod 600 /usr/local/directadmin/data/admin/reseller.list

echo "action=addoptions" >> $DA_TQ

if [ -e /usr/local/etc/rc.d/da-popb4smtp ]; then
  /usr/local/etc/rc.d/da-popb4smtp restart
fi

/usr/local/bin/perl -pi -e 's/\sN\s/\t-\t/' /usr/local/etc/newsyslog.conf.d/directadmin.conf
/usr/local/bin/perl -pi -e 's/\sU\s/\t-\t/' /usr/local/etc/newsyslog.conf.d/directadmin.conf

## PB: Fix this:
$DA_SCRIPTS/newsyslog.sh

rm -f /usr/local/directadmin/data/skins/*/ssi_test.html 2> /dev/null
perl -pi -e 's/trusted_users = mail:majordomo:apache$/trusted_users = mail:majordomo:apache:diradmin/' /usr/local/etc/exim/exim.conf

COUNT=$(grep uid_exempt /usr/local/etc/exim/exim.pl | grep -c yes)
FILE=/usr/local/etc/exim/exim.pl.1.24.0.back
if [ "$COUNT" -eq 0 ]; then
  if [ ! -e $FILE ]; then
    cp -f /usr/local/etc/exim/exim.pl $FILE
    /usr/local/bin/wget -q -O /usr/local/etc/exim/exim.pl.new http://files.directadmin.com/services/exim.pl
    RET=$?
    if [ $RET -eq 0 ]; then
      mv -f /usr/local/etc/exim/exim.pl.new /usr/local/etc/exim/exim.pl
      chmod 755 /usr/local/etc/exim/exim.pl
      echo "action=restart&value=exim" >> $DA_TQ
    fi
  fi
fi

chmod 750 /etc/virtual/majordomo

${DA_SCRIPTS}/cron_deny.sh

if [ -e /var/spool/virtual ]; then
  chmod 1777 /var/spool/virtual
fi

/usr/local/bin/perl -pi -e "s/userlog \"%u %b\"/userlog \"%u %b %m\"/" /usr/local/etc/proftpd.conf
echo "action=proftpd&value=restart" >> /usr/local/directadmin/data/task.queue

if [ ! -e /usr/local/bin/mysqld ] && [ -e /usr/local/libexec/mysqld ]; then
  ln -s ../libexec/mysqld /usr/local/bin/mysqld
fi

if [ -e /usr/share/spamassassin/72_active.cf ]; then
  /usr/local/bin/perl -pi -e 's#header   FH_DATE_PAST_20XX.*#header   FH_DATE_PAST_20XX      Date =~ /20[2-9][0-9]/ [if-unset: 2006]#' /usr/share/spamassassin/72_active.cf
fi

# 1.37.1
# Very important update to allow DA to listen correctly on IPv4 and IPv6 interfaces.
COUNT=$(grep -c ipv6_ipv4mapping /etc/rc.conf)
if [ "$COUNT" -eq 0 ]; then
  ## PB: echo "ipv6_ipv4mapping=\"YES\"" >> /etc/rc.conf
  sysrc ipv6_ipv4mapping="YES"
fi

COUNT=$(grep -c net.inet6.ip6.v6only /etc/sysctl.conf)
if [ "$COUNT" -eq 0 ]; then
  ## PB: echo "net.inet6.ip6.v6only=0" >> /etc/sysctl.conf
  sysrc -f /etc/sysctl.conf net.inet6.ip6.v6only=0
  #/etc/rc.d/sysctl restart
  service sysctl restart
fi

/sbin/sysctl net.inet6.ip6.v6only=0 >/dev/null 2>&1

# links?
# if [ -e /usr/local/etc/exim/exim.key ]; then
#   chown mail:mail /usr/local/etc/exim/exim.key
#   chmod 600 /usr/local/etc/exim/exim.key
# fi

UKN=/etc/virtual/limit_unknown
if [ ! -e $UKN ]; then
  echo 0 > $UKN;
  chown mail:mail $UKN
  chown mail:mail /etc/virtual/limit
fi

exit 0;
