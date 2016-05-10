#!/bin/sh

CHMOD=/bin/chmod
CHOWN=/usr/sbin/chown
MKDIR=/bin/mkdir
SERVICE=/usr/sbin/service
TOUCH=/usr/bin/touch

INIT_DIR=/usr/local/etc/rc.d

## Can also copy user_prefs instead of creating (touch'ing) a new one
if [ "$spam" = "ON" ]; then
  DIR=/home/$username/.spamassassin
  ${MKDIR} "${DIR}"
  ${TOUCH} "${DIR}/user_prefs"
  ${CHOWN} ${username}:mail "${DIR}"
  ${CHMOD} 771 "${DIR}"
  ${CHOWN} $username:$username "${DIR}/user_prefs"
  ${CHMOD} 755 "${DIR}/user_prefs"
  ${TOUCH} "${DIR}/spam"
  ${CHOWN} mail:$username "${DIR}/spam"
  ${CHMOD} 660 "${DIR}/spam"
fi

## PB: Restart services after adding a user
## DA can't do this for us right now due to control script filename differences
## Also add checks to see if php-fpm/apache24 is actually installed (same for nginx)

if [ -x "${INIT_DIR}/php-fpm55" ]; then
  ${SERVICE} php-fpm55 reload
elif [ -x "${INIT_DIR}/php-fpm56" ]; then
  ${SERVICE} php-fpm56 reload
elif [ -x "${INIT_DIR}/php-fpm70" ]; then
  ${SERVICE} php-fpm70 reload
else
  ${SERVICE} php-fpm reload
fi

${SERVICE} apache24 graceful
${SERVICE} named restart

exit 0
