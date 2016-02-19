#!/bin/sh

DA_PATH=/usr/local/directadmin
DA_SCRIPTS=${DA_PATH}/scripts
DA_TQ=${DA_PATH}/data/task.queue

#added new options to templates
#echo 'action=rewrite&value=httpd' >> $DA_TQ

echo "action=cache&value=showallusers" >> $DA_TQ
echo "action=cache&value=safemode" >> $DA_TQ
echo "action=convert&value=cronbackups" >> $DA_TQ
echo "action=convert&value=suspendedmysql" >> $DA_TQ
echo "action=syscheck" >> $DA_TQ

if [ ! -d /usr/local/sysbk ]; then
        cd $DA_SCRIPTS
        ./sysbk.sh
fi

grep "usertype=reseller" /usr/local/directadmin/data/users/*/user.conf | cut -d/ -f7 > /usr/local/directadmin/data/admin/reseller.list
chown diradmin:diradmin /usr/local/directadmin/data/admin/reseller.list
chmod 600 /usr/local/directadmin/data/admin/reseller.list

echo "action=addoptions" >> $DA_TQ

if [ -e /usr/local/etc/rc.d/da-popb4smtp ]; then
        /usr/local/etc/rc.d/da-popb4smtp restart
fi

perl -pi -e 's/\sN\s/\t-\t/' /etc/newsyslog.conf
perl -pi -e 's/\sU\s/\t-\t/' /etc/newsyslog.conf

$DA_SCRIPTS/newsyslog.sh
rm -f /usr/local/directadmin/data/skins/*/ssi_test.html 2> /dev/null
perl -pi -e 's/trusted_users = mail:majordomo:apache$/trusted_users = mail:majordomo:apache:diradmin/' /etc/exim.conf

COUNT=`grep uid_exempt /etc/exim.pl | grep -c yes`
FILE=/etc/exim.pl.1.24.0.back
if [ $COUNT -eq 0 ]; then
        if [ ! -e $FILE ]; then
                cp -f /etc/exim.pl $FILE
                wget -q -O /etc/exim.pl.new http://files.directadmin.com/services/exim.pl
                RET=$?
                if [ $RET -eq 0 ]; then
                        mv -f /etc/exim.pl.new /etc/exim.pl
                        chmod 755 /etc/exim.pl
                        echo "action=restart&value=exim" >> $DA_TQ
                fi
        fi
fi

chmod 750 /etc/virtual/majordomo

${DA_SCRIPTS}/cron_deny.sh

if [ -e /var/spool/virtual ]; then
        chmod 1777 /var/spool/virtual
fi

perl -pi -e "s/userlog \"%u %b\"/userlog \"%u %b %m\"/" /etc/proftpd.conf
echo "action=proftpd&value=restart" >> /usr/local/directadmin/data/task.queue

if [ ! -e /usr/local/mysql/bin/mysqld ] && [ -e /usr/local/mysql/libexec/mysqld ]; then
        ln -s ../libexec/mysqld /usr/local/mysql/bin/mysqld
fi

if [ -e /usr/share/spamassassin/72_active.cf ]; then
        perl -pi -e 's#header   FH_DATE_PAST_20XX.*#header   FH_DATE_PAST_20XX      Date =~ /20[2-9][0-9]/ [if-unset: 2006]#' /usr/share/spamassassin/72_active.cf
fi

#1.37.1
#very important update to allow DA to listen correctly on IPv4 and IPv6
COUNT=`grep -c ipv6_ipv4mapping /etc/rc.conf`
if [ "$COUNT" -eq 0 ]; then
        echo "ipv6_ipv4mapping=\"YES\"" >> /etc/rc.conf
fi

COUNT=`grep -c net.inet6.ip6.v6only /etc/sysctl.conf`
if [ "$COUNT" -eq 0 ]; then
        echo "net.inet6.ip6.v6only=0" >> /etc/sysctl.conf
        /etc/rc.d/sysctl restart
fi

/sbin/sysctl net.inet6.ip6.v6only=0 >/dev/null 2>&1

#links?
#if [ -e /etc/exim.key ]; then
#       chown mail:mail /etc/exim.key
#       chmod 600 /etc/exim.key
#fi

UKN=/etc/virtual/limit_unknown
if [ ! -e $UKN ]; then
        echo 0 > $UKN;
        chown mail:mail $UKN
        chown mail:mail /etc/virtual/limit
fi

exit 0;
