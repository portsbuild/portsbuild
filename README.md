# portsbuild


## Introduction
PortsBuild is an alternative to [DirectAdmin](http://www.directadmin.com)'s [CustomBuild](http://forum.directadmin.com/showthread.php?t=44743) for [FreeBSD](http://www.freebsd.org) installations using [Ports](http://www.freebsd.org/doc/en_US.ISO8859-1/books/handbook/ports-overview.html) (and Packages) to improve the relationship between two fantastic systems.

Automation and integration is achieved by using simple shell scripts, along with the recommended practices of managing a FreeBSD system according to the [FreeBSD Handbook](https://www.freebsd.org/handbook). PortsBuild will use a combination of ports (using [synth](https://github.com/jrmarino/synth) and portmaster) and packages (via pkg) while configuration options are maintained in either /etc/make.conf or /var/db/ports/*/options to install the necessary services on a FreeBSD system.

The source code for this project will be open source. A distribution & copyright license has not been chosen yet at this time.

### Supported Software Stacks (planned)

Support for various software stacks will be added in the following priorities:

Phase 1

Service 		| Status
--------------- | ---------------
Apache 2.4 | Supported
php5-fpm 5.5 | 
php5-fpm 5.6 | Supported
MariaDB 5.5 | Supported
MariaDB 10.0 | 
MySQL 5.5 | 
MySQL 5.6 | 
Dovecot 2.2.x | Supported
Exim 4.8x | Supported
SpamBlocker 4.3.x | Supported
phpMyAdmin 4.5.x | Supported
ClamAV | Supported
SpamAssassin 3.4 | Supported
curl | Supported
RoundCube 1.1.3+ | In progress
Majordomo (src) | Supported
ionCube loaders | Supported
ZendOpCache | Supported (php56-opcache)
proftpd | Supported
pure-FTPd | Supported
sysbk | Installed with DirectAdmin


Phase 2

Service 		| Status
--------------- | ---------------
nginx 1.8+ | untested (www/nginx)
AwStats | www/awstats
Webalizer | www/webalizer
Mailman | mail/mailman
suhosin | untested (security/php56-suhosin)
suphp | redundant vs. fpm?
PigeonHole | untested (mail/pigeonhole)


PortsBuild will NOT support:
* SquirrelMail - last release in 2011, however a fork exists in CB2 (1.4.22-20140402_0200)
* ZendOptimizer - unsupported on FreeBSD
* mod_ruid2 - unsupported on FreeBSD

### Supported Operating Systems
* FreeBSD 10.2 x64 (primary focus)
* FreeBSD 9.3 x64 (working)

Untested on upcoming FreeBSD 10.3 branch.

### Initial Build Environment Requirements
* ports-mgmt/pkg
* ports-mgmt/portmaster
* ports-mgmt/portconf
* shells/bash
* lang/perl5.20
* ftp/wget
* devel/autoconf
* devel/automake
* devel/libtool
* lang/pyton27
* lang/python
* ftp/curl
* devel/gettext
* lang/gcc (lang/gcc48)
* dns/bind910 (for 10.1/10.2)
* converters/libiconv
* graphics/gd
* graphics/png
* graphics/jpeg
* graphic/tiff
* textproc/libxslt
* devel/gmake
* security/cyrus-sasl2
* textproc/libxml2


### Current Known Limitations
* BIND (named) does not restart after adding a domain on 9.3 due to startup script location in /etc/rc.d/ instead of /usr/local/etc/rc.d/ (DirectAdmin limitation)
* PHP-FPM does not restart after adding a user due to startup script being called "php-fpm" instead of "php-fpmXX" (XX= 55, 56, etc.) (DirectAdmin limitation)
* Only one instance of PHP can be installed (afaik). Multiple PHP versions may be possible, but requires testing.


### Additional documentation to add
* Virtualization (FreeBSD+DA as a Guest VM)
* IPFW / Firewall integration scripts
* Performance tweaks & tunes


## Future Plans
* Poudriere package building system integration (and hosting too)
* CustomBuild to PortsBuild conversion guide
* DirectAdmin UI Plugin for PortsBuild similarly to [CustomBuild's plugin](http://forum.directadmin.com/showthread.php?t=48989)
* Failover (CARP+HAST) configurations
* Load-Balancing between multiple servers
* Best Practices Guide (Infrastructure, Design, Implementation, Maintenance, Security, Updates, Upgrades)
* Additional solutions and topics to discuss: pfSense, ZFS, FreeNAS, Nas4Free, ESXi, hardware


### Copyrights (more to be added)
Portions of this file include references from third-party authors and companies not affiliated with the author or the PortsBuild project.
* DirectAdmin Copyright (C) 2003-2015 JBMC Software, St. Albert, AB, Canada: http://www.directadmin.com
* CustomBuild is written by DirectAdmin and Martynas Bendorius (smtalk)
* SpamBlockerTechnology is a Trademark of NoBaloney Internet Services: http://www.nobaloney.net
