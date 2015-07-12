# portsbuild


## Introduction
PortsBuild is an alternative to [DirectAdmin](http://www.directadmin.com)'s [CustomBuild](http://forum.directadmin.com/showthread.php?t=44743) for [FreeBSD](http://www.freebsd.org) installations using [Ports](http://www.freebsd.org/doc/en_US.ISO8859-1/books/handbook/ports-overview.html) (and Packages) to improve the relationship between two fantastic systems.

Automation and Integration is achieved by using simple shell scripts, along with the recommended practices of managing a FreeBSD system according to the FreeBSD Handbook. PortsBuild will use a combination of ports (using portmaster), packages (via pkg) and a slew of port option knobs (injected into /etc/make.conf) to install the necessary services on a FreeBSD system.

The source code for this project will be open source. A distribution & copyright license has not been chosen yet at this time.

### Supported Software Stacks (planned)

Support for various software stacks will be added in the following priorities:

Phase 1
* Apache 2.4
* php5-fpm 5.4/5.5/5.6
* MySQL/MariaDB 5.5/5.6
* Dovecot 2.2
* Exim 4.8
* phpMyAdmin 4
* pure-FTPd
* ClamAV
* SpamAssassin 3.4
* curl
* RoundCube


Phase 2
* nginx
* PigeonHole
* Mailman
* SpamBlocker 4.3.x integration by NoBaloney
* proftpd
* MariaDB 10


Phase 3
* AwStats
* Webalizer


Phase 4 (no ports found / research req. / untested)
* ZendOptimizer (unknown)
* ZendOpCache (works on 8.3-amd64) or php56-opcache?
* suhosin patch (untested) php56-suhosin?
* suphp support (works / redundant vs. fpm?)
* mod_ruid2 (untested)
* ionCube loaders (third-party / loadable modules)


PortsBuild will NOT support:
* SquirrelMail - last release in 2011, however a fork exists in CB2 (1.4.22-20140402_0200)


### Supported Operating Systems
* FreeBSD 10.1 x64 (primary focus)
* FreeBSD 9.3 x64


### Initial Build Environment Requirements
* ports-mgmt/pkg
* ports-mgmt/portmaster
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
* dns/bind910
* converters/libiconv
* graphics/gd
* graphics/png
* graphics/jpeg
* graphic/tiff
* textproc/libxslt
* devel/gmake
* security/cyrus-sasl2
* textproc/libxml2


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
* Additional solutions and topics to discuss: pfSense, ZFS, FreeNAS, ESXi, hardware


### Copyrights (more to be added)
Portions of this file include references from third-party authors and companies not affiliated with the author or the PortsBuild project.
* DirectAdmin Copyright (C) 2003-2011 JBMC Software, St Albert, AB, Canada: http://www.directadmin.com
* SpamBlockerTechnology is a Trademark of NoBaloney Internet Services: http://www.nobaloney.net
