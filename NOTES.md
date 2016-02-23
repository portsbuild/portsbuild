# Notes

### Todo for first release:
* Finalize defaults.conf and options.conf
* RoundCube
* Exception handling and friendlier error messages
* Implement additional validation controls
* Refactor certain functions
* Cleanup unused variables or forgotten strings
* Setup hosted WWW repo to download files needed by PB (like files.directadmin.com)
* Final shellcheck verification
* Create HOWTO or "Get Started" guide
* Ask DirectAdmin Staff and Martynas for their blessing


### Upcoming:
* Validate selected options by the user (set in options.conf)
* Create test units via shunit2
* Test on FreeBSD 10.3
* Test Perl 5.22


### Research:
* Multiple PHP installations on the same server. Will have to prefix the target installation directory, e.g.

    /usr/local/php56
    /usr/local/php70

* Implement security/py-letsencrypt
* Multilingual support


### Initial Build Environment Requirements
* ports-mgmt/pkg
* ports-mgmt/portmaster
* ports-mgmt/portconf (removed?)
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


    killall -USR1 dataskq
    tail -n 10 /var/log/directadmin/errortaskq.log
    ln -s /etc/rc.d/named /usr/local/etc/rc.d/named
    ln -s /etc/rc.d/sshd /usr/local/etc/rc.d/sshd
    ln -s /usr/local/etc/rc.d/php-fpm /usr/local/etc/rc.d/php-fpm56
