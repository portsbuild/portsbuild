## Status of Software Stacks

The following table shows if the differently configured software stacks have been tested or not.


No. | Webserver     | PHP #1   | SQL
--- | -----------   | ---      | ---
1   | Apache 2.4    | FPM      | MariaDB 10.1
2   | Apache 2.4    | FCGI     | MariaDB 10.1


Service         | Versions      | Status
--------------- | ------------- | -------
Apache          | 2.4.x         | Supported
PHP-FPM         | 5.5/5.6/7.0   | Supported
MariaDB         | 5.5/10.0/10.1 | Supported
MySQL           | 5.5/5.6       | Supported
Dovecot         | 2.2.x         | Supported
Exim            | 4.8x          | Supported
SpamBlocker     | 4.3.x         | Supported
ClamAV          | 0.9x          | Supported
SpamAssassin    | 3.4           | Supported
RoundCube       | 1.1.x         | Supported
phpMyAdmin      | 4.5.x         | Supported
proftpd         | 1.3.5a        | Supported
pure-FTPd       | 1.0.42        | Supported
Majordomo       | 1.94.5        | Supported (via DA source copy)
nginx           | 1.8.x         | Untested (www/nginx)
suphp           |               | Untested (www/suphp)
fastcgi         |               | Untested (www/mod_fastcgi)
AwStats         |               | Untested (www/awstats)
Webalizer       |               | Untested (www/webalizer)
suhosin         |               | Untested (security/php-suhosin)
mod_security    |               | Untested (www/mod_security)
htscanner       |               | Untested (devel/pecl-htscanner)
Mailman         |               | Untested (mail/mailman)
PigeonHole      |               | Untested (mail/pigeonhole)
