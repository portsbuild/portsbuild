#!/bin/sh

CONF=/usr/local/etc/newsyslog.conf.d/directadmin.conf
INIT_DIR=/usr/local/etc/rc.d

if [ ! -e $CONF ]; then
  printf "Creating newsyslog configuration for DirectAdmin.\n"
  printf "File: %s\n" "${CONF}"
  touch "${CONF}"
fi

## addLog /file user:group flag pid
addLog() {
  COUNT=$(grep -c "$1" ${CONF})
  if [ "$COUNT" -ne 0 ]; then
    return
  fi
  printf "%s\t%s\t600\t7\t*\t@T00\t%s\t%s\n" "$1" "$2" "$3" "$4" >> "${CONF}"
}

# addLog /var/log/chrootshell.log '' -

if [ -e "${INIT_DIR}/apache24" ]; then
  addLog /var/log/httpd/access_log apache:apache -
  addLog /var/log/httpd/fpexe_log apache:apache -
  addLog /var/log/httpd/suexec_log apache:apache -
  addLog /var/log/suphp.log '' -
  addLog /var/log/httpd/error_log apache:apache - /var/run/httpd.pid
fi

if [ -e "${INIT_DIR}/exim" ]; then
  addLog /var/log/exim/paniclog mail:mail -
  addLog /var/log/exim/exim_paniclog mail:mail -
  addLog /var/log/exim/rejectlog mail:mail -
  addLog /var/log/exim/exim_rejectlog mail:mail -
  addLog /var/log/exim/processlog mail:mail -
  addLog /var/log/exim/exim_processlog mail:mail -
  addLog /var/log/exim/mainlog mail:mail - /var/run/exim.pid
  addLog /var/log/exim/exim_mainlog mail:mail - /var/run/exim.pid
fi

if [ -e "${INIT_DIR}/proftpd" ]; then
  addLog /var/log/proftpd/auth.log '' -
  addLog /var/log/proftpd/xferlog.legacy '' -
  addLog /var/log/proftpd/access.log '' - /var/run/proftpd/proftpd.pid
fi

if [ -e "${INIT_DIR}/pureftpd" ]; then
  addLog /var/log/pureftp.log '' - /var/run/pure-ftpd.pid
fi

addLog /var/log/directadmin/error.log diradmin:diradmin -
addLog /var/log/directadmin/errortaskq.log diradmin:diradmin -
addLog /var/log/directadmin/security.log diradmin:diradmin -
addLog /var/log/directadmin/system.log diradmin:diradmin -
addLog /var/log/directadmin/login.log diradmin:diradmin -

## PB: Verify
if [ -x "${INIT_DIR}/php-fpm55" ]; then
  addLog /var/log/php-fpm55.log '' - "/var/run/php-fpm55.pid\t30"
elif [ -x "${INIT_DIR}/php-fpm56" ]; then
  addLog /var/log/php-fpm56.log '' - "/var/run/php-fpm56.pid\t30"
elif [ -x "${INIT_DIR}/php-fpm70" ]; then
  addLog /var/log/php-fpm70.log '' - "/var/run/php-fpm70.pid\t30"
else
  addLog /var/log/php-fpm.log '' - "/var/run/php-fpm.pid\t30"
fi

addLog /usr/local/www/roundcube/logs/errors webapps:webapps -
addLog /usr/local/www/phpMyAdmin/log/auth.log webapps:webapps -
# addLog /usr/local/www/squirrelmail/data/squirrelmail_access_log webapps:webapps -

exit 1
