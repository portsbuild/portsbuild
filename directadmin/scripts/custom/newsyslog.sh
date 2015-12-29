#!/bin/sh

CONF=/usr/local/etc/newsyslog.conf.d/directadmin.conf

if [ ! -e $CONF ]; then
        echo "Creating newsyslog configuration for DirectAdmin.";
        touch ${CONF}
fi

#addLog /file user:group flag pid
addLog()
{
        COUNT=`grep -c $1 $CONF`
        if [ $COUNT -ne 0 ]; then
                return;
        fi
        echo -e "$1\t$2\t600\t4\t*\t@T00\t$3\t$4" >> $CONF
}

#addLog /var/log/chrootshell.log '' -
addLog /var/log/proftpd/auth.log '' -
addLog /var/log/proftpd/xferlog.legacy '' -
addLog /var/log/proftpd/access.log '' - /var/run/proftpd.pid

addLog /var/log/pureftp.log '' - /var/run/pure-ftpd.pid

addLog /var/log/httpd/access_log apache:apache -
addLog /var/log/httpd/fpexe_log apache:apache -
addLog /var/log/httpd/suexec_log apache:apache -
addLog /var/log/suphp.log '' -
addLog /var/log/httpd/error_log apache:apache - /var/run/httpd.pid

addLog /var/log/exim/paniclog mail:mail -
addLog /var/log/exim/exim_paniclog mail:mail -
addLog /var/log/exim/rejectlog mail:mail -
addLog /var/log/exim/exim_rejectlog mail:mail -
addLog /var/log/exim/processlog mail:mail -
addLog /var/log/exim/exim_processlog mail:mail -
addLog /var/log/exim/mainlog mail:mail - /var/run/exim.pid
addLog /var/log/exim/exim_mainlog mail:mail - /var/run/exim.pid

addLog /var/log/directadmin/error.log diradmin:diradmin -
addLog /var/log/directadmin/errortaskq.log diradmin:diradmin -
addLog /var/log/directadmin/security.log diradmin:diradmin -
addLog /var/log/directadmin/system.log diradmin:diradmin -
addLog /var/log/directadmin/login.log diradmin:diradmin -

#addLog /usr/local/php53/var/log/php-fpm.log '' - "/var/run/php-fpm53.pid\t30"
#addLog /usr/local/php54/var/log/php-fpm.log '' - "/var/run/php-fpm54.pid\t30"
#addLog /usr/local/php60/var/log/php-fpm.log '' - "/var/run/php-fpm60.pid\t30"

addLog /usr/local/www/roundcube/logs/errors webapps:webapps -
addLog /usr/local/www/squirrelmail/data/squirrelmail_access_log webapps:webapps -
addLog /usr/local/www/phpMyAdmin/log/auth.log webapps:webapps -

exit 1;
