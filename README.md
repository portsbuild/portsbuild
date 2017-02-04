# portsbuild


## Introduction
PortsBuild is an alternative to [DirectAdmin](http://www.directadmin.com)'s [CustomBuild](http://forum.directadmin.com/showthread.php?t=44743) for [FreeBSD](http://www.freebsd.org) installations using [Ports](http://www.freebsd.org/doc/en_US.ISO8859-1/books/handbook/ports-overview.html) and Packages to improve the relationship between two fantastic systems.

Automation and integration is achieved by using simple shell scripts, along with the recommended practices of managing a FreeBSD system according to the [FreeBSD Handbook](https://www.freebsd.org/handbook). PortsBuild will use a combination of ports (using [synth](https://github.com/jrmarino/synth) and portmaster) and packages (via pkg) while configuration options are maintained in either /etc/make.conf or /var/db/ports/*/options to install the necessary services on a FreeBSD system.

A distribution & copyright license has not been chosen yet at this time (although leaning towards BSD License).

### Supported Operating Systems
* FreeBSD 11.0 x64 (primary focus)
* FreeBSD 10.3 x64 (working)
* FreeBSD 9.3 x64 (working)

### Supported Software Stacks and Services

Service 		| Versions      | Status
--------------- | ------------- | -------
Apache          | 2.4.x         | Supported
PHP(-FPM)       | 5.5/5.6/7.0   | Supported
MariaDB         | 5.5/10.0/10.1 | Supported
MySQL           | 5.5/5.6/5.7   | Supported
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
nginx           | 1.8.x         | In progress (www/nginx)
suphp           |               | In progress (www/suphp)
fastcgi         |               | In progress (www/mod_fastcgi)
IPFW            |               | Untested (firewall scripts)
AwStats         |               | Untested (www/awstats)
Webalizer       |               | Untested (www/webalizer)
suhosin         |               | Untested (security/php-suhosin)
mod_security    |               | Untested (www/mod_security)
htscanner       |               | Untested (devel/pecl-htscanner)
Mailman         |               | Untested (mail/mailman)
PigeonHole      |               | Untested (mail/pigeonhole)


PortsBuild will NOT support:
* SquirrelMail - last release in 2011, however a fork exists in CB2 (1.4.22-20140402_0200)
* ZendOptimizer - unsupported on FreeBSD
* mod_ruid2 - unsupported on FreeBSD


### Currently known issues and limitations
* BIND (named) does not restart after adding a domain on 9.3 due to startup script location in /etc/rc.d/ instead of /usr/local/etc/rc.d/ (DirectAdmin limitation)
* PHP-FPM does not restart after adding a user due to startup script being called "php-fpm" instead of "php-fpmXX" (XX= 55, 56, 70, etc.) (DirectAdmin limitation)
* Only one instance of PHP can be installed through ports/packages (afaik). An alternative approach will be to compile the second PHP instance manually via a tarball (credit for this idea goes to wattie). This will be implemented into PortsBuild once testing is complete.

### Changes from DA/CB defaults
* PHP Sockets are now found under /var/run/php/sockets (used to be: /usr/local/php%VER%/sockets)
* The WWW directory is now /usr/local/www (used to be: /var/www/html)
* Default SQL database path has been moved to /var/db/mysql (used to be: /home/mysql) but can be changed.

## Future plans and ideas
* Poudriere package building system integration (and hosting too)
* CustomBuild to PortsBuild conversion guide
* DirectAdmin UI Plugin for PortsBuild similarly to [CustomBuild's plugin](http://forum.directadmin.com/showthread.php?t=48989)
* Failover (CARP+HAST) configurations
* Load-Balancing between multiple servers
* Best Practices Guide: Infrastructure, Design, Implementation, Maintenance, Security, Updates, Upgrades
* Additional solutions and topics: pfSense, ZFS, virtualization, performance & networking tuning


### Copyrights
Portions of this file include references from third-party authors and companies not affiliated with the PortsBuild project.
* DirectAdmin Copyright (C) 2003-2017 JBMC Software, St. Albert, AB, Canada: http://www.directadmin.com
* CustomBuild is written by DirectAdmin and Martynas Bendorius (smtalk)
* SpamBlockerTechnology is a Trademark of NoBaloney Internet Services: http://www.nobaloney.net
