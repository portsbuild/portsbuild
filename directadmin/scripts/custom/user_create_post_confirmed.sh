#!/bin/sh

if [ "$spam" = "ON" ]; then
  DIR=/home/$username/.spamassassin
  /bin/mkdir $DIR
  /usr/bin/touch $DIR/user_prefs             # or this is where you'd copy the default user_prefs you want them to have instead of "touch".
  /usr/sbin/chown ${username}:mail $DIR
  /bin/chmod 771 $DIR
  /usr/sbin/chown $username:$username $DIR/user_prefs
  /bin/chmod 755 $DIR/user_prefs
  /usr/bin/touch $DIR/spam
  /usr/sbin/chown mail:$username $DIR/spam
  /bin/chmod 660 $DIR/spam
fi

## PB: Restart services after adding a user
## DA can't do this for us right now due to control script filename differences
## Also add checks to see if php-fpm/apache24 is actually installed (same for nginx)

if [ -x /usr/local/etc/rc.d/php-fpm55 ]; then
  /usr/sbin/service php-fpm55 reload
elif [ -x /usr/local/etc/rc.d/php-fpm56 ]; then
  /usr/sbin/service php-fpm56 reload
elif [ -x /usr/local/etc/rc.d/php-fpm70 ]; then
  /usr/sbin/service php-fpm70 reload
else
  /usr/sbin/service php-fpm reload
fi

/usr/sbin/service apache24 graceful
/usr/sbin/service named restart

exit 0
