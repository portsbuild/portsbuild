# portsbuild


## Introduction
PortsBuild is an alternative to [DirectAdmin](http://www.directadmin.com)'s [CustomBuild](http://forum.directadmin.com/showthread.php?t=44743) for [FreeBSD](http://www.freebsd.org) installations using [Ports](http://www.freebsd.org/doc/en_US.ISO8859-1/books/handbook/ports-overview.html) (and Packages) to improve the relationship between two fantastic systems.

Automation and Integration is achieved by using simple shell scripts in true open-source fashion.


### Supported Software Stacks (planned)

Support for various software stacks will be added in the following priorities:

Phase 1
* Apache 2.4.x
* php5-fpm 5.4.x
* MySQL/MariaDB 5.5.x
* Dovecot 2.2.x
* Exim 4.80+
* phpMyAdmin 4.x
* pure-FTPd
* ClamAV
* SpamAssassin
* curl
* RoundCube


Phase 2
* nginx
* PigeonHole
* Mailman
* SpamBlocker 4.x integration by NoBaloney
* proftpd


Phase 3
* AwStats
* Webalizer


Phase 4 (no ports found / research req. / untested)
* ZendOptimizer
* ZendOpCache
* suhosin patch
* suphp support
* mod_ruid2 (untested)
* ionCube loaders (third-party / loadable modules)


PortsBuild will NOT support:
* SquirrelMail - last release in 2011


### Supported Operating Systems (planned)
* FreeBSD 9.x x64
* FreebSD 10.x x64


### Initial Build Environment Requirements
* ports-mgmt/pkg
* ports-mgmt/portmaster
* shells/bash
* [...] 


### Additional documentation to add
* Virtualization (FreeBSD+DA as a Guest VM)
* IPFW / Firewall integration scripts
* Performance tweaks & tunes


## Future Plans
* CustomBuild to PortsBuild conversion guide
* DirectAdmin UI Plugin for PortsBuild similarly to [CustomBuild](http://forum.directadmin.com/showthread.php?t=48989)
* Failover (CARP+HAST) configurations
* Load-Balancing between multiple servers
* Best Practices Guide (Infrastructure, Design, Implementation, Maintenance)
* Additional solutions and topics to discuss: pfSense, ZFS, FreeNAS, ESXi, hardware
