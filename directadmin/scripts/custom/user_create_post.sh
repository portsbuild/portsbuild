#!/bin/sh
if [ "$spam" = "ON" ]; then
   DIR=/home/$username/.spamassassin
   mkdir $DIR
   touch $DIR/user_prefs             #or this is where you'd copy  the default user_prefs you want them to have, instead of "touch".
   chown ${username}:mail $DIR
   chmod 771 $DIR
   chown $username:$username $DIR/user_prefs
   chmod 755 $DIR/user_prefs
   touch $DIR/spam
   chown mail:$username $DIR/spam
   chmod 660 $DIR/spam
fi

## PB: Restart services after adding a user 
## (DA can't do these for us right now due to control script filename differences)

## note to self: perhaps add a "sleep 10" here to give DA enough time to do its thing
## also add checks to see if php-fpm/apache24 is actually installed (same for nginx)
/sbin/service php-fpm reload
/sbin/service apache24 graceful
/sbin/service named reload

exit 0;
