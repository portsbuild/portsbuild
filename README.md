# portsbuild


## Introduction
PortsBuild is an alternative to [DirectAdmin](http://www.directadmin.com)'s [CustomBuild](http://forum.directadmin.com/showthread.php?t=44743) for [FreeBSD](http://www.freebsd.org) installations using [Ports](http://www.freebsd.org/doc/en_US.ISO8859-1/books/handbook/ports-overview.html) (and Packages) to improve the relationship between two fantastic systems.

Automation and Integration is achieved by using simple shell scripts in true open-source fashion.


### Supported Software Stacks (planned)

Support for various software stacks will be added in the following priorities:

Phase 1
* Apache 2.4.x
* php5-fpm 5.4.x/5.5.x
* MySQL/MariaDB 5.5.x
* Dovecot 2.2.x
* Exim 4.80+
* phpMyAdmin 4.2.x
* pure-FTPd
* ClamAV 0.98+
* SpamAssassin 3.4.0
* curl 7.38+
* RoundCube 1.x


Phase 2
* nginx
* PigeonHole
* Mailman
* SpamBlocker 4.2.x integration by NoBaloney
* proftpd
* MariaDB 10.x


Phase 3
* AwStats
* Webalizer


Phase 4 (no ports found / research req. / untested)
* ZendOptimizer (unknown)
* ZendOpCache (works on 8.3-amd64)
* suhosin patch (untested)
* suphp support (works / redundant vs. fpm?)
* mod_ruid2 (untested)
* ionCube loaders (third-party / loadable modules)


PortsBuild will NOT support:
* SquirrelMail - last release in 2011, however a fork exists in CB2 (1.4.22-20140402_0200)


### Supported Operating Systems (planned)
* FreeBSD 9.x x64
* FreebSD 10.x x64


### Initial Build Environment Requirements
* ports-mgmt/pkg
* ports-mgmt/portmaster
* shells/bash
* lang/perl5.16
* ftp/wget
* [...]


### Additional documentation to add
* Virtualization (FreeBSD+DA as a Guest VM)
* IPFW / Firewall integration scripts
* Performance tweaks & tunes


## Future Plans
* CustomBuild to PortsBuild conversion guide
* DirectAdmin UI Plugin for PortsBuild similarly to [CustomBuild's plugin](http://forum.directadmin.com/showthread.php?t=48989)
* Failover (CARP+HAST) configurations
* Load-Balancing between multiple servers
* Best Practices Guide (Infrastructure, Design, Implementation, Maintenance)
* Additional solutions and topics to discuss: pfSense, ZFS, FreeNAS, ESXi, hardware


### Copyrights (more to be added)
Portions of this file include references from third-party authors and companies not affiliated with Sarotech or the PortsBuild project.
* DirectAdmin Copyright (C) 2003-2011 JBMC Software, St Albert, AB, Canada: http://www.directadmin.com
* SpamBlockerTechnology is a Trademark of NoBaloney Internet Services: http://www.nobaloney.net
