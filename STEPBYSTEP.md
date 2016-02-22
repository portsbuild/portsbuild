# PortsBuild Step-by-Step Guide

Step-by-step guide on how to install DirectAdmin on FreeBSD 10.2 with ports and packages.

**NOTE**: This guide is being cleaned up and worked on as you plow through it. A lot of redundant steps are being consolidated and/or removed. I'm in the middle of formatting the guide too, so don't mind the misaligned headers and whatnot. Also, it's **incomplete**, so your installation won't finish as some steps contradict themselves. Think of this guide as being 85% complete.

Furthermore, this guide was originally written for "internal use" while I was in the middle of taking apart the entire DirectAdmin + CB2 installation process. As such, it's long and totally not easy to follow, especially since I'm still in the middle of moving sections around. Lines prefixed with "Reference" or "Scripted Reference" are there for copy&paste use to make your life easier.

Lastly, for those willing to wait a bit longer, the actual scripted / totally automated method to set a system up ("portsbuild.sh") is on its way. This guide was put together for those wishing to setup a FreeBSD + DirectAdmin system from scratch to supplement their own style/methods of administering a server.

I welcome all types of feedback. If something is missing, doesn't make sense, is totally wrong, goes against best practices, or you feel you can help me in any way possible with this project, please let me know. If you have a spare DA license to test this guide out, please feel free to let me know how it works out.

On with the show.


Table of Contents

[TOC]


## Overview

This guide is primarily written for FreeBSD 10.2 and 9.3 amd64 only.

PortsBuild makes heavy use of the [optionsNG](Review: https://www.freebsd.org/doc/en/books/porters-handbook/makefile-options.html) framework.

While this whole solution is considered stable, it is absolutely not ready for production use, so please be warned that things will most likely break.

Also, this whole thing is not supported by DirectAdmin in any shape or form, so don't contact them for support.


### Requirements

* Extensive knowledge of FreeBSD, the ports tree, packages, and general system administration tasks is an absolute must for those wishing to setup DirectAdmin with nothing but ports and packages.
* A valid DirectAdmin license is required.
* The ability to accept the risks involved of following this guide.
* Patience, the ability to follow instructions, and more patience.

### Good to Know

* CustomBuild is no longer used to maintain your system's packages.
* Updating your system is now taken care of `pkg` and `portmaster`.
* DirectAdmin requires `options.conf` to be present in /usr/local/directadmin/custombuild/` so do not delete it.

### Supported Services

The following services are known to be working and are currently referenced in this guide:

* Apache 2.4.17
* PHP 5.6 FPM
* Exim 4.80+ with BC and ESF
* Dovecot 2.25+
* MariaDB 5.5/10.0 or MySQL 5.5/5.6
* BIND 9.9.5
* ProFTPd
* ClamAV
* SpamAssassin

The RoundCube and phpMyAdmin sections are incomplete and require some changes (but they both work).

### Known Limitations

Here is a list of known limitations of setting up DirectAdmin with the PortsBuild method (this guide):

* It comes with absolutely zero support from DirectAdmin.
* You can only run one instance of PHP on a server.
* You can only run one web server (Apache for now, nginx to come soon) so that also means no support for reverse proxy situations.
* There are issues and conflicts with the startup control scripts (rc.d) installed from ports or packages. They do not interface with DirectAdmin at this time out of the box. There is a (hopefully) temporary workaround for this problem. More information about this issue is described at the end of this guide.


### Where to get help

You can request for help in the following ways:

* Submitting an issue through GitHub
* Visiting the DirectAdmin forums and posting in this thread (<link here>)

## Install FreeBSD

Install FreeBSD as it's normally done. This guide has based its initial installation medium by using FreeBSD 10.2-RELEASE (DISC1) approximately 700 MB in size. The filename is `FreeBSD-10.2-RELEASE-amd64-disc1.iso` and can be downloaded directly from [ftp.freebsd.org](ftp://ftp.freebsd.org/pub/FreeBSD/releases/amd64/amd64/ISO-IMAGES/10.2/FreeBSD-10.2-RELEASE-amd64-disc1.iso).


#### Installation options

This applies for both FreeBSD 10.2 and 9.3.

* Unselect `lib32` and `games`
* Select `ports` and `src`
* `doc` is optional

Make sure to set the correct hostname during installation (e.g. myserver.example.com).

On FreeBSD 10.2, do **not** install the Unbound DNS server.


#### Example partition layout

This is for reference only and is only one of many examples out there to structure your filesystem on a FreeBSD system. You can keep everything under / if you wish, but you might miss out on quota support and the ability to move/remount partitions in the future.

| Mountpoint 	| Space |
|---------------|-------|
| /	   			| 2 GB  |
| /tmp 			| 2 GB  |
| /var 			| 10 GB |
| swap 			| RAM * 2, max 16384MB |
| /usr 			| remaining |


Reference: Example `/etc/fstab` contents:

| Device      | Mountpoint   | FStype | Options 				| Dump | Pass# |
|-------------|--------------|--------|-------------------------|------|-------|
| /dev/da0s1b |none          | swap   | sw      				| 0 | 0 |
| /dev/da0s1a | /            | ufs    | rw,userquota,groupquota | 1 | 1 |
| /dev/da0s1e | /tmp         | ufs    | rw,nosuid 				| 2 | 2 |
| /dev/da0s1f | /usr         | ufs    | rw 						| 2 | 2 |
| /dev/da0s1d | /var         | ufs    | rw 						| 2 | 2 |
| /dev/acd0   | /cdrom       | cd9660 | ro,noauto 				| 0 | 0 |
| proc        | /proc        | procfs | rw 						| 0 | 0 |


#### Post-Installation Tasks

At this point, your network stack must be fully configured and working. Your server must be able to communicate with the rest of the internet. For now, network configuration is out of the scope of this guide, but will be included in the future.

##### Update FreeBSD

Of course, it's always a good idea to update the system first before moving forward.

	freebsd-update fetch && freebsd-update install
	reboot

##### Setup ports and Packages

The following is an automated bootstrap method to install `pkg` without prompting the user to confirm (great for scripted installs). You can also run `pkg update` manually to install and update as well.

	env ASSUME_ALWAYS_YES=YES pkg bootstrap

Update the ports tree and the packages repo:

	portsnap fetch extract
    pkg update

##### Install required dependencies

The following is the bare minimum required to get started (according to DirectAdmin's installation guide). Additional packages (about 33 in total) will also be installed when the following full command is executed.

FreeBSD 10.2 users:

	pkg install -y devel/gmake lang/perl5.20 ftp/wget devel/bison textproc/flex graphics/gd security/cyrus-sasl2 devel/cmake lang/python devel/autoconf devel/libtool archivers/libarchive mail/mailx textproc/libxml2 dns/bind99

FreeBSD 9.3 users:

	pkg install -y devel/gmake lang/perl5.20 ftp/wget devel/bison textproc/flex graphics/gd security/cyrus-sasl2 devel/cmake lang/python devel/autoconf devel/libtool archivers/libarchive mail/mailx textproc/libxml2


We'll need to install the compat libraries so the `directadmin` binary can run.

FreeBSD 10.2, install compat4x to compat9x:

	pkg install -y misc/compat4x misc/compat5x misc/compat6x misc/compat8x misc/compat9x

FreeBSD 9.3, install compat4x to compat8x:

	pkg install -y misc/compat4x misc/compat5x misc/compat6x misc/compat8x

##### Install portmaster (required)

	pkg install -y ports-mgmt/portmaster

##### Optional/Recommended Software

###### Install Bash (optional)

	pkg install -y shells/bash

###### Install sudo (optional)

	pkg install -y security/sudo

###### Install ccache (recommended)

Installing `devel/ccache` helps speed up (re)compilations. Highly recommended.

	pkg install -y devel/ccache

Enable `ccache` for ports by updating `/etc/make.conf`:

	WITH_CCACHE_BUILD=yes

More information: /usr/local/share/doc/ccache/ccache-howto-freebsd.txt

##### Virtualization considerations

If the OS is a guest VM (virtualization, e.g. running on ESXi) then update `/boot/loader.conf` and add at the very top:

	kern.hz=100

Also, now is a good time to install guest VM tools, e.g. VMware-tools. Note that you need to symlink the Perl binary first unless you want to modify the installation scripts (see below).

It's also not a bad idea to increase `vfs.read_max` (default: 32) in `/etc/sysctl.conf` for better performance in virtual environments:

	vfs.read_max=256

#### System Preparation

##### Symlink Perl Binary

This is done for compatability reasons.

	ln -s /usr/local/bin/perl /usr/bin/perl

##### Create `/etc/auth.conf`

==To verify==: At one point in time (when FreeBSD 9.1 was released) DirectAdmin was looking for the existence of this file. This may not be necessary anymore.

	touch /etc/auth.conf

##### Update `/etc/rc.conf`

Some recommended defaults. Change the *ntpdate* host to a mirror or server of your choice.

    ntpdate_hosts="pool.ntp.org"
    ntpdate_enable="YES"
    fsck_y_enable="YES"
    ipv6_ipv4mapping="YES"

If Exim is being used, add the following to `/etc/rc.conf` to disable sendmail:

	sendmail_enable="NONE"
    sendmail_submit_enable="NO"
    sendmail_outbound_enable="NO"
    sendmail_msp_queue_enable="NO"

Stop the sendmail service now:

	service sendmail stop

Scripted reference:

    echo "sendmail_enable=\"NONE\"" >> /etc/rc.conf
    echo "sendmail_submit_enable=\"NO\"" >> /etc/rc.conf
    echo "sendmail_outbound_enable=\"NO\"" >> /etc/rc.conf
    echo "sendmail_msp_queue_enable=\"NO\"" >> /etc/rc.conf
	service sendmail onestop

##### Update `/etc/sysctl.conf`

The first two lines are for security. The third line (re: v6only) is required by DirectAdmin.

	security.bsd.see_other_uids=0
	security.bsd.see_other_gids=0
	net.inet6.ip6.v6only=0

Update `sysctl` now to avoid having to reboot the system:

	sysctl net.inet6.ip6.v6only=0

##### Customize `/etc/make.conf`

This is where the magic happens. Think of `make.conf` as the equivalent to CB's `options.conf`, where you essentially set the versions and options you wish to have installed on your system.

First, let's create the file:

	touch /etc/make.conf

Now it's time to customize `make.conf` and adjust it according to your needs. The example file below shows how you pre-define port options and essentially create a "statically" configured system. The default options below are similar to how DirectAdmin initially sets up a new system (Apache, PHP, Exim, Dovecot). If you want to know what options are available to you for a particular port, please see the particular section in this guide (TBD).

	## Set default versions
	#DEFAULT_VERSIONS= php=5.6 mysql=5.6 apache=2.4 perl=5.20

	## PB: Global Port Options
	## Prevent the installation of DOCS, HTMLDOCS, EXAMPLES, NLS and X11 stuff.
    OPTIONS_UNSET= DOCS HTMLDOCS EXAMPLES HTMLDOCS NLS X11 TESTS DEBUG GUI MANPAGES

    ## LIBGB: FONTCONFIG (to skip X11 stuff)

    ## PB: Apache 2.4 Options
    www_apache24_SET= SUEXEC MPM_EVENT
    www_apache24_UNSET= MPM_PREFORK

    ## PB: Nginx Options
    # www_nginx_SET=
    # www_nginx_UNSET=

    ## PB: PHP 5.6 Options
    lang_php56_SET= CLI CGI FPM IPV6 MAILHEAD LINKTHR
    # lang_php56_UNSET=

    ## PB: PHP 5.6 Extensions (Meta Port)
    lang_php56-extensions_SET = BCMATH BZ2 CALENDAR CTYPE CURL DOM EXIF
    lang_php56-extensions_SET+= FILEINFO FILTER FTP GD GETTEXT HASH ICONV IIMAP
    lang_php56-extensions_SET+= JSON MBSTRING MCRYPT MYSQL MY
    lang_php56-extensions_SET+= OPCACHE OPENSSL
    lang_php56-extensions_SET+= PDF PDO PDO_MYSQL PDO_SQLITE PHAR POSIX PSPELL
    lang_php56-extensions_SET+= READLINE RECODE SESSION SIMPLEXML SOAP SOCKETS SQLITE3
    lang_php56-extensions_SET+= WDDX XML XMLREADER XMLRPC XMLWRITER XSL ZIP ZLIB


    ## PB: PHP 5.5 Options
    lang_php55_SET= CLI CGI FPM MAILHEAD LINKTHR
    # lang_php55_UNSET=

    ## PB: PHP 5.5 Extensions (Meta Port)
    lang_php55-extensions_SET = BCMATH BZ2 CALENDAR CTYPE CURL DOM EXIF
    lang_php55-extensions_SET+= FILEINFO FILTER FTP GD GETTEXT HASH ICONV IIMAP
    lang_php55-extensions_SET+= JSON MBSTRING MCRYPT MYSQL MY
    lang_php55-extensions_SET+= OPCACHE OPENSSL
    lang_php55-extensions_SET+= PDF PDO PDO_MYSQL PDO_SQLITE PHAR POSIX PSPELL
    lang_php55-extensions_SET+= READLINE RECODE SESSION SIMPLEXML SOAP SOCKETS SQLITE3
    lang_php55-extensions_SET+= WDDX XML XMLREADER XMLRPC XMLWRITER XSL ZIP ZLIB
    # lang_php55-extensions_UNSET=

	## PB: MariaDB 5.5 Options (Defaults)
    # databases_mariadb55-server_SET=
    # databases_mariadb55-server_UNSET=
    # databases_mariadb55-client_SET=
    # databases_mariadb55-client_UNSET=

	## PB: MariaDB 10.0 Options (Defaults)
    # databases_mariadb100-server_SET=
    # databases_mariadb100-server_UNSET=
    # databases_mariadb100-client_SET=
    # databases_mariadb100-client_UNSET=

	## PB: MySQL 5.5 Options (Defaults)
    # databases_mysql55-server_SET= SSL
    # databases_mysql55-server_UNSET= FASTMTX
    # databases_mysql55-client_SET=
    # databases_mysql55-client_UNSET=

	## PB: MySQL 5.6 Options (Defaults)
    # databases_mysql56-server_SET=
    # databases_mysql56-server_UNSET=
    # databases_mysql56-client_SET=
    # databases_mysql56-client_UNSET=

	## PB: Exim
    mail_exim_SET= DCC DMARC SPF SRS
	# mail_exim_UNSET=

    ## PB: Dovecot2 Options
    # mail_dovecot2_SET=
    # mail_dovecot2_UNSET=

	## PB: Dovecot2 + Pigeonhole
    #mail_dovecot2-pigeonhole_SET=
    #mail_dovecot2-pigeonhole_UNSET=

	## PB: RoundCube Webmail Options
    mail_roundcube_SET= GD PSPELL SSL

	## PB: ClamAV Options (Untested)
    # security_clamav_SET= MILTER
    # security_clamav_UNSET=

	## PB: SpamAssassin Options
    mail_spamassassin_SET= DCC DKIM PYZOR RAZOR RELAY_COUNTRY SPF_QUERY
    # mail_spamassassin_UNSET=

	## PB: ProFTPd Options
    # ftp_proftpd_SET=
    # ftp_proftpd_UNSET=

	## PB: Pure-FTPd Options (Untested)
    ftp_pure-ftpd_SET= UPLOADSCRIPT LARGEFILE
    # ftp_pure-ftpd_UNSET=

	## PB: phpMyAdmin Options
    # databases_phpmyadmin_SET=
    # databases_phpmyadmin_UNSET=

	## PB: Awstats Options (Unused)
    # www_awstats_SET=
    # www_awstats_UNSET=

    ## PB: Webalizer Options (Unused)
    # www_webalizer_SET= GEOIP GEPDB
    # www_webalizer_UNSET=

	## PB: Suhosin Options
    # security_php-suhosin_SET=
    # devel_pecl-htscanner_UNSET=

    ## PB: ModSecurity Options (Untested)
	# www_modsecurity_SET=
    # www_modsecurity_UNSET=


	## PB: FreeType2 Options (Unused)
	# print_freetype2_SET=
  	# print_freetype2_UNSET=

	## PB: GD Options (Unused)
	# graphics_gd_SET=
    # graphics_gd_UNSET= FONTCONFIG

Reference:

    [CATEGORY]_[PORT]_[SET|UNSET]=OPTION1 OPTION2 ...

### Prepare DirectAdmin Directories

Start of setup.sh specific stuff (move this or consolidate):

	mkdir -p /usr/local/directadmin/scripts/packages

### REVISE: Install CustomBuild2

**Note**: do not run CustomBuild2. I'm working/testing to see if I can simply get rid of CB2 altogether.

Set the CB v2 flag:

	echo "2.0" > /root/.custombuild

Download and Extract CustomBuild2 for DirectAdmin compatability reasons:

    mkdir -p /usr/local/directadmin/custombuild
    wget -O /usr/local/directadmin/custombuild.tar.gz http://files.directadmin.com/services/custombuild/2.0/custombuild.tar.gz
    tar zxvf /usr/local/directadmin/custombuild.tar.gz -C /usr/local/directadmin/
    chmod 755 /usr/local/directadmin/custombuild/build
    cd /usr/local/directadmin/custombuild
    #SKIP: ./build update
    #SKIP: ./build create_options


SKIP: These options must be set because DirectAdmin queries CB2's `options.conf`:

	## Skip all for now:
    #./build set php1_release 5.6
    #./build set php2_release no
    #./build set php1_mode php-fpm
    #./build set mod_ruid2 no
    #./build set use_hostname_for_alias yes

Disable certain libs, deps & services so a user doesn't accidentally execute the CB commands:

    touch /usr/local/directadmin/custombuild/custom_versions.txt
    printf "pcre:0:\nlibpng:0:\nlibxml:0:\niconv:0:\nfreetype:0:" >> /usr/local/directadmin/custombuild/custom_versions.txt

### Setup PortsBuild

PortsBuild flag in case future scripts become aware of PB :)

	echo "1.0" > /root/.portsbuild


#### BIND/named configuration

Notes:

* On FreeBSD 9.3, BIND 9.9.5 is already installed by default in the base system. You do not have to install anything else.
* On FreeBSD 10.x, BIND was removed from the base system. As such, it must be installed via packages separately.
* Unbound DNS is currently not supported.

On FreeBSD 10.2, install `dns/bind99` (untested: `dns/bind910`). FreeBSD 9.3 users skip this part:

	pkg install -y dns/bind99

FreeBSD 9.3/10.2: Generate `rndc.key` using your server's IP address:

	rndc-confgen -a -s YOUR_IP_ADDRESS

This will generate the key and create the file `/usr/local/etc/namedb/rndc.key` or `/etc/namedb/rndc.key` on 10.2 and 9.3 respectively.


##### Replace `named.conf`

10.2: /var/named/etc/namedb/named.conf
9.3: /etc/namedb/named.conf

Replace with version from GitHub repo.

FreeBSD 10.2 with BIND 9.9.5 from ports:

	wget --no-check-certificate -O /var/named/etc/namedb/named.conf https://raw.githubusercontent.com/portsbuild/portsbuild/master/conf/named.100.conf

FreeBSD 9.3 with BIND 9.9.5 from base:

	wget --no-check-certificate -O /etc/namedb/named.conf https://raw.githubusercontent.com/portsbuild/portsbuild/master/conf/named.93.conf


### MOVE THIS: DirectAdmin Installation

Update `/etc/aliases`:

	echo "diradmin: :blackhole:" >> /etc/aliases

Run `newaliases` to refresh:

	newaliases


Alternative - beta binaries (did not use)
Downloaded pre-release binaries and extracted them to /usr/local/directadmin:

    cd /usr/local
    mkdir /usr/local/directadmin
    wget http://files1.directadmin.com/963018346/packed_freebsd91_64.tar.gz
    tar zxvf packed_freebsd91_64.tar.gz

Create the DirectAdmin directory:

	mkdir /usr/local/directadmin

Download DirectAdmin

Regular way (replace SERVER_IP_ADDRESS, USER_ID, and LICENSE_ID):

	wget --no-check-certificate -S -O /usr/local/directadmin/update.tar.gz --bind-address=SERVER_IP_ADDRESS "https://www.directadmin.com/cgi-bin/daupdate?uid=USER_ID&lid=LICENSE_ID"

If on LAN (internal IP) then remove the --bind-address argument:

	wget --no-check-certificate -S -O /usr/local/directadmin/update.tar.gz "https://www.directadmin.com/cgi-bin/daupdate?uid=USER_ID&lid=LICENSE_ID"

Extract `update.tar.gz` into /usr/local/directadmin:

	cd /usr/local/directadmin
	tar zxvf update.tar.gz

Verify: User Welcome message not created?

	touch /usr/local/directadmin/data/users/admin/u_welcome.txt

Todo: Download default message templates from PB GitHub repo (they were missing on my last install).

Verfy: Create backup.conf (wasn't created?)

	chown diradmin:diradmin /usr/local/directadmin/data/users/admin/backup.conf

From setup.sh: generate setup.txt
Pre-fetched through setup.sh prompts to the user (done)
Replace the following with your info:

    echo "hostname=myserver.example.com"        >  /usr/local/directadmin/scripts/setup.txt;
    echo "email=root@example.com"          >> /usr/local/directadmin/scripts/setup.txt;
    echo "mysql=YOUR_SQL_PASSWORD"   >> /usr/local/directadmin/scripts/setup.txt;
    echo "mysqluser=da_admin"    >> /usr/local/directadmin/scripts/setup.txt;
    echo "adminname=admin" >> /usr/local/directadmin/scripts/setup.txt;
    echo "adminpass=YOUR_ADMIN_PASSWORD" >> /usr/local/directadmin/scripts/setup.txt;
    echo "ns1=ns1.example.com"              >> /usr/local/directadmin/scripts/setup.txt;
    echo "ns2=ns2.example.com"              >> /usr/local/directadmin/scripts/setup.txt;
    echo "ip=YOUR_IP_ADDRESS"                >> /usr/local/directadmin/scripts/setup.txt;
    echo "netmask=255.255.255.0"           >> /usr/local/directadmin/scripts/setup.txt;
    echo "uid=USER_ID"              >> /usr/local/directadmin/scripts/setup.txt;
    echo "lid=LICENSE_ID"              >> /usr/local/directadmin/scripts/setup.txt;
    echo "services=services_freebsd90_64.tar.gz"    >> /usr/local/directadmin/scripts/setup.txt;


Scripted reference (look for ethernet interface):

	COUNT=`cat /usr/local/directadmin/data/templates/directadmin.conf | grep -c ethernet_dev=`

Add default ethernet device in directadmin.conf (replace vmx3f0):

	echo "ethernet_dev=vmx3f0" >> /usr/local/directadmin/data/templates/directadmin.conf

Set permission:

	chmod 600 /usr/local/directadmin/scripts/setup.txt

Modify /usr/local/directdamin/conf/directadmin.conf

    ## Defaults for reference:
    # apacheconf=/etc/httpd/conf/httpd.conf
    # apacheips=/etc/httpd/conf/ips.conf
    # apachemimetypes=/etc/mime.types
    # apachecert=/etc/httpd/conf/ssl.crt/server.crt
    # apachekey=/etc/httpd/conf/ssl.key/server.key
    # apacheca=/etc/httpd/conf/ssl.crt/server.ca
    # nameddir=/etc/namedb

Add/Change to:

    apacheconf=/usr/local/etc/apache24/httpd.conf
    apacheips=/usr/local/etc/apache24/ips.conf
    apachemimetypes=/usr/local/etc/apache24/mime.types
    apachecert=/usr/local/etc/apache24/ssl/server.crt
    apachekey=/usr/local/etc/apache24/ssl/server.key
    apacheca=/usr/local/etc/apache24/ssl/server.ca

On FreeBSD 10.2:

    nameddir=/usr/local/etc/namedb

On FreeBSD 9.3:

    nameddir=/etc/namedb

If using proftpd/pureftpd (untested):

    #ftpconfig=/etc/proftpd.conf
    #ftpvhosts=/etc/proftpd.vhosts.conf
    #ftppasswd=/etc/proftpd.passwd
    ftpconfig=/usr/local/etc/proftpd.conf
    ftpvhosts=/usr/local/etc/proftpd.vhosts.conf
    ftppasswd=/usr/local/etc/proftpd.passwd


Verify (I think this was OK):

	emailspoolvirtual=/var/spool/virtual


Reference: scripts/doChecks.sh:

If no /home is mounted, use / as the quota partition:

	echo 'quota_partition=/' >> /usr/local/directadmin/data/templates/directadmin.conf;



SKIP: Set hostname for system (didn't use it, installation already sets this):

	/bin/hostname myserver.example.com;

SKIP: Add hostname to /etc/hosts (done):

    #echo -e "${IP}\t\t${1}" >> /etc/hosts
    echo -e "SERVERIPADDRESS\t\tmyserver.example.com" >> /etc/hosts

SKIP: Set permissions (done by default):

	chmod 644 /etc/hosts

SKIP: Set hostname in /etc/rc.conf if not already done so:

	hostname="myserver.example.com"

SKIP: Scripted reference to update hostname:

	#STR="/usr/local/bin/perl -pi -e 's/hostname=(.*)/hostname=\"${1}\"/' /etc/rc.conf;";
	#eval $STR;



##### DirectAdmin Installation (cont.)

-


##### Setup Exim Directories

Create `/etc/virtual`:

    mkdir -p /etc/virtual;
    chown mail:mail /etc/virtual;
    chmod 755 /etc/virtual;

    skip#echo "`hostname`" >> /etc/virtual/domains;`
    echo "1000" > /etc/virtual/limit
    echo "150" > /etc/virtual/limit_unknown

    chmod 755 /etc/virtual/*
    mkdir /etc/virtual/usage
    chmod 750 /etc/virtual/usage

Add server hostname to `/etc/virtual/domains` if not already done (for Exim):

    echo myserver.example.com >> /etc/virtual/domains;

Create necessary directories in /etc/virtual per hostname for Exim 4 filters:

    mkdir -p /etc/virtual/myserver.example.com
    chown mail:mail /etc/virtual/myserver.example.com
    chmod 711 /etc/virtual/myserver.example.com

Create Exim log files directory:

	mkdir -p /var/log/exim
	chown -R mail:mail /var/log/exim/

Symlink config for compat:

	ln -s /usr/local/etc/exim/exim.conf /usr/local/etc/exim/configure

Update exim.conf, add user/group info at the top so Exim can run as "mail" instead of "mailnull"

    #EDIT#0:
    exim_user = mail
    exim_group = mail

Create RBL stuff

Quick way (reference for scripted use):

	for i in domains domainowners pophosts blacklist_domains whitelist_from use_rbl_domains bad_sender_hosts bad_sender_hosts_ip blacklist_senders whitelist_domains whitelist_hosts whitelist_hosts_ip whitelist_senders skip_av_domains skip_rbl_domains; do
		touch /etc/virtual/$i;
		chmod 600 /etc/virtual/$i;
	done

Long way:

    touch /etc/virtual/domains
    touch /etc/virtual/domainowners
    touch /etc/virtual/pophosts
    touch /etc/virtual/blacklist_domains
    touch /etc/virtual/whitelist_from
    touch /etc/virtual/use_rbl_domains
    touch /etc/virtual/bad_sender_hosts
    touch /etc/virtual/bad_sender_hosts_ip
    touch /etc/virtual/blacklist_senders
    touch /etc/virtual/whitelist_domains
    touch /etc/virtual/whitelist_hosts
    touch /etc/virtual/whitelist_hosts_ip
    touch /etc/virtual/whitelist_senders
    touch /etc/virtual/skip_av_domains
    touch /etc/virtual/skip_rbl_domains

    chmod 600 /etc/virtual/domains
    chmod 600 /etc/virtual/domainowners
    chmod 600 /etc/virtual/pophosts
    chmod 600 /etc/virtual/blacklist_domains
    chmod 600 /etc/virtual/whitelist_from
    chmod 600 /etc/virtual/use_rbl_domains
    chmod 600 /etc/virtual/bad_sender_hosts
    chmod 600 /etc/virtual/bad_sender_hosts_ip
    chmod 600 /etc/virtual/blacklist_senders
    chmod 600 /etc/virtual/whitelist_domains
    chmod 600 /etc/virtual/whitelist_hosts
    chmod 600 /etc/virtual/whitelist_hosts_ip
    chmod 600 /etc/virtual/whitelist_senders
    chmod 600 /etc/virtual/skip_av_domains
    chmod 600 /etc/virtual/skip_rbl_domains

    chown mail:mail /etc/virtual/*;



##### Quota Support

Reference: scripts/fstab.sh:

Ensure that the quotas are set in the fstab file:

	/usr/local/bin/perl -pi -e 's/[\ \t]+\/home[\ \t]+ufs[\ \t]+rw[\ \t]+/\t\t\/home\t\t\tufs\trw,userquota,groupquota\t/' /etc/fstab
	/usr/local/bin/perl -pi -e 's/[\ \t]+\/[\ \t]+ufs[\ \t]+rw[\ \t]+/\t\t\t\/\t\t\tufs\trw,userquota,groupquota\t/' /etc/fstab

Add entry to /etc/fstab:

	echo -e "proc\t\t\t/proc\t\tprocfs\trw\t\t0\t0" >> /etc/fstab;

-sg: Did not work, so skip this:

	#/sbin/mount_procfs procfs /proc

Reference: Hide the errors, it was confusing people (skipped):

    /usr/sbin/mount -u /home 2> /dev/null 1> /dev/null
    /usr/sbin/mount -u / 2> /dev/null 1> /dev/null
    /usr/sbin/quotaoff -a 2 > /dev/null > /dev/null
    /sbin/quotacheck -avug 2> /dev/null
    /usr/sbin/quotaon -a 2> /dev/null 1> /dev/null

Create crontab deny list:

    echo apache >> /var/cron/deny
    echo webapps >> /var/cron/deny
    echo www >> /var/cron/deny
    chmod 600 /var/cron/deny


##### Update Newsyslog entries

From: scripts/newsyslog.sh (done):

FreeBSD paths to remember:
/etc/newsyslog.conf.d/*
/usr/local/etc/newsyslog.conf.d/*

	mkdir -p /usr/local/etc/newsyslog.conf.d/
	touch /usr/local/etc/newsyslog.conf.d/directadmin.conf

Added all entries below to /usr/local/etc/newsyslog.conf.d/directadmin.conf

Reference: (created log.sh):

    addLog /file user:group flag pid

    addLog()
    {
        COUNT=`grep -c $1 /usr/local/etc/newsyslog.conf.d/directadmin.conf`
        if [ $COUNT -ne 0 ]; then
            return;
        fi
        echo -e "$1\t$2\t600\t4\t*\t@T00\t$3\t$4" >> /usr/local/etc/newsyslog.conf.d/directadmin.conf
    }

```
echo -e "$1\t$2\t600\t4\t*\t@T00\t$3\t$4" >> /usr/local/etc/newsyslog.conf.d/directadmin.conf

addLog /var/log/chrootshell.log '' -
addLog /var/log/proftpd/auth.log '' -
addLog /var/log/proftpd/xferlog.legacy '' -
addLog /var/log/proftpd/access.log '' - /var/run/proftpd.pid
addLog /var/log/pureftp.log '' - /var/run/pure-ftpd.pid

addLog /var/log/httpd/access_log apache:apache -
addLog /var/log/httpd/fpexe_log apache:apache -
addLog /var/log/httpd/suexec_log apache:apache -
addLog /var/log/suphp.log '' -
addLog /var/log/httpd/error_log apache:apache - /var/run/httpd.pid

addLog /var/log/exim/paniclog mail:mail -
addLog /var/log/exim/exim_paniclog mail:mail -
addLog /var/log/exim/rejectlog mail:mail -
addLog /var/log/exim/exim_rejectlog mail:mail -
addLog /var/log/exim/processlog	mail:mail -
addLog /var/log/exim/exim_processlog mail:mail -
addLog /var/log/exim/mainlog mail:mail - /var/run/exim.pid
addLog /var/log/exim/exim_mainlog mail:mail - /var/run/exim.pid

addLog /var/log/directadmin/error.log diradmin:diradmin -
addLog /var/log/directadmin/errortaskq.log diradmin:diradmin -
addLog /var/log/directadmin/security.log diradmin:diradmin -
addLog /var/log/directadmin/system.log diradmin:diradmin -
addLog /var/log/directadmin/login.log diradmin:diradmin -
```

```
## Modify the next bit according to your system:
#addLog /usr/local/php53/var/log/php-fpm.log '' - "/var/run/php-fpm53.pid\t30"
#addLog /usr/local/php54/var/log/php-fpm.log '' - "/var/run/php-fpm54.pid\t30"
#addLog /usr/local/php60/var/log/php-fpm.log '' - "/var/run/php-fpm60.pid\t30"
#addLog /usr/local/php56/var/log/php-fpm.log '' - "/var/run/php-fpm.pid\t30"
```

php-fpm (currently in use):

	addLog /var/log/php-fpm.log '' - "/var/run/php-fpm.pid\t30"


    ## Change /var/www/html/ to /usr/local/www/
    # addLog /var/www/html/roundcube/logs/errors webapps:webapps -
    # addLog /var/www/html/squirrelmail/data/squirrelmail_access_log webapps:webapps -
    # addLog /var/www/html/phpMyAdmin/log/auth.log webapps:webapps -

Update newsyslog.conf:

    addLog /usr/local/www/roundcube/logs/errors webapps:webapps -
    addLog /usr/local/www/squirrelmail/data/squirrelmail_access_log webapps:webapps -
    addLog /usr/local/www/phpMyAdmin/log/auth.log webapps:webapps -


##### Fetch DirectAdmin License

Replace USER_ID, LICENSE_ID and SERVER_IP variables accordingly.

Regular method:

	/usr/local/directadmin/scripts/getLicense.sh USER_ID LICENSE_ID SERVER_IP

LAN mode:

	/usr/local/directadmin/scripts/getLicense.sh USER_ID LICENSE_ID

Set permissions:

	chown diradmin:diradmin /usr/local/directadmin/conf/license.key
	chmod 600 /usr/local/directadmin/conf/license.key

##### Install SQL Database Server

DirectAdmin works with both MySQL and MariaDB SQL database services. My personal recommendation is to go with MariaDB 10.

Notes:

* This guide uses the term MySQL interchangeably: it represents both MySQL and MariaDB database servers as they both operate the same way. MariaDB is considered a drop-in replacement to MySQL.
* By default, DirectAdmin creates and stores SQL databases in /home/mysql. This guide, however, does not follow this tradition. Instead, the default path for SQL databases will now be /var/db/mysql. Please adjust your third-party scripts and configuration files accordingly (e.g. backup scripts) to reflect this new path.
* Installation can be performed via pkg exclusively, as the ports method does not offer any additional option used by DirectAdmin.
* The `mysql` binary path is now `/usr/local/bin/mysql` and NOT in `/usr/local/mysql/bin`
* Your `my.cnf` configuration file cannot be in /etc/ or else MySQL won't start. The correct path is `/usr/local/etc/my.cnf`
* You can only install one SQL server: either MySQL or MariaDB only, not both.

###### Option 1: MariaDB

Install MariaDB 5.5:

	pkg install -y databases/mariadb55-server databases/mariadb55-client

or MariaDB 10.0:

	pkg install -y databases/mariadb100-server databases/mariadb100-client

###### Option 2: MySQL

Install MySQL 5.5:

	pkg install -y databases/mysql55-server databases/mysql55-client

or MySQL 5.6:

	pkg install -y databases/mysql56-server databases/mysql56-client


###### Post-Installation Tasks

Run the MySQL/MariaDB secure installation script to set a password on the `root` user, disable anonymous logons and to get rid of the `test` database:

	/usr/local/bin/mysql_secure_installation

For scripted reference; `mysql_secure_installation` takes care of all this:

    /usr/local/bin/mysqladmin --user=root password YOURSQLPASSWORD 1> /dev/null 2> /dev/null
    echo "UPDATE mysql.user SET password=PASSWORD('YOURSQLPASSWORD') WHERE user='root';"> mysql.temp;
    echo "UPDATE mysql.user SET password=PASSWORD('YOURSQLPASSWORD') WHERE password='';">> mysql.temp;
    echo "DROP DATABASE IF EXISTS test;" >> mysql.temp
    echo "FLUSH PRIVILEGES;" >> mysql.temp;
    /usr/local/bin/mysql mysql --user=root --password=YOURSQLPASSWORD < mysql.temp;
    rm -f mysql.temp;

Note: there are two (2) users (with different passwords): root and da_admin

Add the `da_admin` user to MySQL (replace the variables!):

Scripted reference:

	echo "GRANT CREATE, DROP ON *.* TO da_admin@localhost IDENTIFIED BY 'YOURSQLPASSWORD' WITH GRANT OPTION;" > mysql.temp;
    echo "GRANT ALL PRIVILEGES ON *.* TO da_admin@localhost IDENTIFIED BY 'YOURSQLPASSWORD' WITH GRANT OPTION;" >> mysql.temp;
    /usr/local/bin/mysql --user=root --password=YOURSQLPASSWORD < mysql.temp;
    rm -f mysql.temp;


	# CLI method (incomplete):
	#	/usr/local/bin/mysql --user=root --password=ROOT_SQL_PASSWORD "GRANT CREATE, DROP ON *.* TO da_admin@localhost IDENTIFIED BY 'DA_ADMIN_SQL_PASSWORD' WITH GRANT OPTION;"


Add DirectAdmin `da_admin` SQL database credentials to `mysql.conf`:

    echo "user=da_admin" > /usr/local/directadmin/conf/mysql.conf
    echo "passwd=DA_ADMIN_SQL_PASSWORD" >> /usr/local/directadmin/conf/mysql.conf
    chown diradmin:diradmin /usr/local/directadmin/conf/mysql.conf;
    chmod 400 /usr/local/directadmin/conf/mysql.conf;

Create and update `/usr/local/etc/my.cnf`:

    touch /usr/local/etc/my.cnf
    echo "[mysqld]" > /usr/local/etc/my.cnf;
    echo "local-infile=0" >> /usr/local/etc/my.cnf;
    echo "innodb_file_per_table" >> /usr/local/etc/my.cnf;


Symlink the `mysqldump` binary for compat. This is used by DirectAdmin during SQL backup functions (may not be needed since we can set the binary path in directadmin.conf):

	mkdir -p /usr/local/mysql/bin
	ln -s /usr/local/bin/mysqldump /usr/local/mysql/bin/mysqldump



##### Install PHP

Currently, this guide only supports installing a single version & instance of PHP on a server. You're welcome to install a version of your choice, either 5.5 or 5.6 (with the latter preferred). The quickest way to install is via `pkg`, however if you wish to enable the Mail Header patch, then we have to install PHP from the ports tree.

###### Option 1: PHP 5.6

Installation via packages (no Mail Header patch):

	pkg install php56 php56-bz2 php56-ctype php56-curl php56-dba php56-dom php56-fileinfo php56-filter php56-gd php56-gettext php56-hash php56-iconv php56-imap php56-json php56-mbstring php56-mcrypt php56-mysql php56-mysqli php56-openssl php56-pdo php56-pdo_mysql php56-opcache php56-phar php56-readline php56-redis-2.2.4 php56-soap ftp/php56-ftp sysutils/php56-posix php56-sqlite3 php56-session php56-simplexml php56-snmp php56-sockets php56-tidy php56-tokenizer php56-wddx php56-xml php56-xmlreader php56-xmlrpc php56-xmlwriter php56-zip php56-zlib

Installation via ports (to enable Mail header path):

	portmaster -d lang/php56


###### Option 2: PHP 5.5

Installation via pkg (no Mail Header patch):

	pkg install php55 php55-bz2 php55-ctype php55-curl php55-dba php55-dom php55-fileinfo php55-filter php55-gd php55-gettext php55-hash php55-iconv php55-imap php55-json php55-mbstring php55-mcrypt php55-mysql php55-mysqli php55-openssl php55-pdo php55-pdo_mysql php55-opcache php55-phar php55-readline php55-redis-2.2.4 php55-soap ftp/php55-ftp sysutils/php55-posix php55-sqlite3 php55-session php55-simplexml php55-snmp php55-sockets php55-tidy php55-tokenizer php55-wddx php55-xml php55-xmlreader php55-xmlrpc php55-xmlwriter php55-zip php55-zlib

Installation via ports (to enable Mail header path):

	portmaster -d lang/php55


###### Install ioncube (optional)

	pkg install -y devel/ioncube

Replace or Modify /usr/local/etc/php.ini with production version:

	cp /usr/local/etc/php.ini-production /usr/local/etc/php.ini

Changes from CB2 for php.ini:

    # echo "date.timezone = \"${PHP_TIMEZONE_OPT}\"" >> php.ini-${PHP_INI_TYPE_OPT}
    # /usr/bin/perl -pi -e 's/upload_max_filesize = 2M/upload_max_filesize = 64M/' php.ini-${PHP_INI_TYPE_OPT}
    # /usr/bin/perl -pi -e 's/post_max_size = 8M/post_max_size = 64M/' php.ini-${PHP_INI_TYPE_OPT}
    # perl -pi -e 's/^short_open_tag = Off/short_open_tag = On/' php.ini-${PHP_INI_TYPE_OPT}
    # /usr/bin/perl -pi -e 's/mail.add_x_header = Off/mail.add_x_header = On/' php.ini-${PHP_INI_TYPE_OPT}
    # /usr/bin/perl -pi -e 's/mail.add_x_header = 0/mail.add_x_header = On/' php.ini-${PHP_INI_TYPE_OPT}

Update `/usr/local/etc/php.ini`:

	date.timezone = 'America/Montreal'
    upload_max_filesize =64M
    post_max_size = 64M
    short_open_tag = On
    mail.add_x_header = On

Replace default php-fpm.conf with DirectAdmin/CB2 version:

    cp -f /usr/local/directadmin/custombuild/configure/fpm/conf/php-fpm.conf.56 /usr/local/etc/php-fpm.conf

###### Update php-fpm.conf

Add pid path:

	pid = run/php-fpm.pid

Uncomment (optional):

    syslog.facility = daemon
    syslog.ident = php-fpm

Create CB2/DA directories for compat (replace php56 with your appropriate version):

    mkdir -p /usr/local/php56
    mkdir -p /usr/local/php56/bin
    mkdir -p /usr/local/php56/etc
    mkdir -p /usr/local/php56/include
    mkdir -p /usr/local/php56/lib
    mkdir -p /usr/local/php56/php
    mkdir -p /usr/local/php56/sbin
    mkdir -p /usr/local/php56/sockets
    mkdir -p /usr/local/php56/var/log/
    mkdir -p /usr/local/php56/var/run
    #mkdir -p /usr/local/php56/lib/php.conf.d/
    mkdir -p /usr/local/php56/lib/php/

Symlink for compat (replace php56 with your appropriate version):

    ln -s /usr/local/bin/php /usr/local/php56/bin/php
    ln -s /usr/local/bin/php-cgi /usr/local/php56/bin/php-cgi
    ln -s /usr/local/bin/php-config /usr/local/php56/bin/php-config
    ln -s /usr/local/bin/phpize /usr/local/php56/bin/phpize
    ln -s /usr/local/sbin/php-fpm /usr/local/php56/sbin/php-fpm
    ln -s /var/log/php-fpm.log /usr/local/php56/var/log/php-fpm.log
    ln -s /usr/local/include/php /usr/local/php56/include

    ## Scan directory for PHP ini files:
    ln -s /usr/local/etc/php /usr/local/php56/lib/php.conf.d
    ln -s /usr/local/etc/php.ini /usr/local/php56/lib/php.ini
    ln -s /usr/local/etc/php-fpm.conf /usr/local/php56/etc/php-fpm.conf
    ln -s /usr/local/lib/php/build /usr/local/php56/lib/php/build
    ln -s /usr/local/lib/php/20131226 /usr/local/php56/lib/php/extensions

Reference: Example DA template tokens for /usr/local/directadmin/data/templates/custom/php-fpm.conf

    |*if USER="username"|
    php_admin_value[php_directive] = value
    |*endif|

Additional system-level php.ini files to load. Must be placed in /usr/local/etc/php/ instead of /usr/local/php56/lib/php.conf.d/

The following was "10-directadmin.ini" (verify):

    extension_dir=/usr/local/php55/lib/php/extensions/no-debug-non-zts-20121212
    zend_extension=/usr/local/lib/ioncube/ioncube_loader_fre_5.5.so
    zend_extension=/usr/local/php55/lib/php/extensions/no-debug-non-zts-20121212/opcache.so
    opcache.enable=1
    opcache.memory_consumption=128
    opcache.interned_strings_buffer=8
    opcache.max_accelerated_files=5000
    opcache.revalidate_freq=3600
    opcache.fast_shutdown=1
    opcache.enable_cli=1

Update /usr/local/etc/php/extensions.ini and add these lines for Zend Extensions (Ioncube loader, OpCache) support:

    --------------------------------------------------------------------------------
    [Zend]
    zend_extension="/usr/local/lib/php/20131226/ioncube/ioncube_loader.so"
    zend_extension_ts="/usr/local/lib/php/20131226/ioncube/ioncube_loader_ts.so"
    --------------------------------------------------------------------------------
    #zend_extension=/usr/local/lib/ioncube/ioncube_loader_fre_5.5.so
    #zend_extension=/usr/local/php55/lib/php/extensions/no-debug-non-zts-20121212/opcache.so

Set permissions:

    chmod 700 /usr/local/php56/sockets
	chown -R apache:apache /usr/local/php56/sockets/

Symlink rc.d script for CB2:

	ln -s /usr/local/etc/rc.d/php-fpm /usr/local/etc/rc.d/php-fpm56

Not sure about this -sg:
WARNING: Nothing matches the include pattern
'/usr/local/directadmin/data/users/*/php/php-fpm56.conf' from /usr/local/etc/php-fpm.conf at line 68.


Scripted reference (from CB2):

    echo "Making PHP ${INT_RELEASE} installation compatible with php.ini file"
    /usr/local/bin/perl -pi -e 's/^register_long_arrays/;register_long_arrays/' ${PHP_INI_INT}
    /usr/local/bin/perl -pi -e 's/^magic_quotes_gpc/;magic_quotes_gpc/' ${PHP_INI_INT}
    /usr/local/bin/perl -pi -e 's/^safe_mode/;safe_mode/' ${PHP_INI_INT}
    /usr/local/bin/perl -pi -e 's/^register_globals/;register_globals/' ${PHP_INI_INT}
    /usr/local/bin/perl -pi -e 's/^register_long_arrays/;register_long_arrays/' ${PHP_INI_INT}
    /usr/local/bin/perl -pi -e 's/^allow_call_time_pass_reference/;allow_call_time_pass_reference/' ${PHP_INI_INT}
    /usr/local/bin/perl -pi -e 's/^define_syslog_variables/;define_syslog_variables/' ${PHP_INI_INT}
    /usr/local/bin/perl -pi -e 's/^highlight.bg/;highlight.bg/' ${PHP_INI_INT}
    /usr/local/bin/perl -pi -e 's/^session.bug_compat_42/;session.bug_compat_42/' ${PHP_INI_INT}
    /usr/local/bin/perl -pi -e 's/^session.bug_compat_warn/;session.bug_compat_warn/' ${PHP_INI_INT}
    /usr/local/bin/perl -pi -e 's/^y2k_compliance/;y2k_compliance/' ${PHP_INI_INT}
    /usr/local/bin/perl -pi -e 's/^magic_quotes_runtime/;magic_quotes_runtime/' ${PHP_INI_INT}
    /usr/local/bin/perl -pi -e 's/^magic_quotes_sybase/;magic_quotes_sybase/' ${PHP_INI_INT}

##### TODO: Control Script Fix

TODO: Add the command `service php-fpm restart` after a new user is added to the system. Script will be in /usr/local/directadmin/scripts/custom/add_user_post.sh (or similarly named).

#### Install Web Server

Currently, only Apache 2.4 has been tested with this guide. Nginx will be documented very soon.

##### Apache 2.4

Notes:

* By default, DirectAdmin/CB2 install Apache configuration files in `/etc/httpd`. This is now changed to `/usr/local/etc/apache24`
* Accordingly, SSL certificates are now moved to `/usr/local/etc/apache24/ssl/`
* FreeBSD uses `www:www` as the default user & group for Apache, but for now we'll have to use `apache:apache` for compatability reasons.
* Default path to webapps will be `/usr/local/www` instead of `/var/www/html`

Installing Apache from packages doesn't include `suexec` support unfortunately, so we must build from ports:

	#portmaster -d www/apache24

Use:

    portmaster -d -G --no-confirm

Reference for `/etc/make.conf`:

	www_apache24_SET= SUEXEC MPM_EVENT
    www_apache24_UNSET= MPM_PREFORK

Symlink for backwards compatability:

	mkdir -p /etc/httpd/conf
	ln -s /usr/local/etc/apache24 /etc/httpd/conf

CustomBuild2 looking for Apache modules in /usr/lib/apache*
Symlink for backcomp (done):

	mkdir -p /usr/lib/apache
	ln -s /usr/local/libexec/apache24 /usr/lib/apache

Since DirectAdmin/CB2 reference/var/www/html often, we'll symlink for compat:

    mkdir -p /var/www
    ln -s /usr/local/www /var/www/html
    chown -h webapps:webapps /var/www/html

CustomBuild2 reference /etc/httpd/conf/ssl
Create empty files for CB2 to generate

Symlink for compat (done):

    mkdir -p /etc/httpd/conf/ssl.crt
    mkdir -p /etc/httpd/conf/ssl.key
    mkdir -p /usr/local/etc/apache24/ssl

    #touch /etc/httpd/conf/ssl.crt/server.crt
    #touch /etc/httpd/conf/ssl.key/server.key

    touch /usr/local/etc/apache24/ssl/server.crt
    touch /usr/local/etc/apache24/ssl/server.key

    ln -s /usr/local/etc/apache24/ssl/server.crt /etc/httpd/conf/ssl.crt/server.crt
    ln -s /usr/local/etc/apache24/ssl/server.ca /etc/httpd/conf/ssl.crt/server.ca
    ln -s /usr/local/etc/apache24/ssl/server.key /etc/httpd/conf/ssl.key/server.key

    ln -s /usr/local/etc/apache24/ssl/server.crt /usr/local/etc/apache24/ssl.crt/server.crt
    ln -s /usr/local/etc/apache24/ssl/server.ca /usr/local/etc/apache24/ssl.crt/server.ca
    ln -s /usr/local/etc/apache24/ssl/server.key /usr/local/etc/apache24/ssl.key/server.key

    /usr/bin/openssl req -x509 -newkey rsa:2048 -keyout /usr/local/etc/apache24/ssl/server.key -out /usr/local/etc/apache24/ssl/server.crt -days 9999 -nodes -config ./custom/ap2/cert_config.txt

Set permissions:

	chmod 600 /usr/local/etc/apache24/ssl/server.crt
	chmod 600 /usr/local/etc/apache24/ssl/server.key

Symlink for DA compat:

	ln -s /usr/local/sbin/httpd /usr/sbin/httpd

SKIP FOR NOW: Symlink startup script for DA compat (done, but deleted as it causes conflict):

	#ln -s /usr/local/etc/rc.d/apache24 /usr/local/etc/rc.d/httpd


Todo/verify: Create custombuild/conf/custom configuration files then trigger ./build rewrite_confs at the end:

	ap2/
	ap2/conf/

httpd.conf (has to be default):

	ServerRoot "/usr/local"


DA default: DocumentRoot "/var/www/html"
Apache default: DocumentRoot "/usr/local/www/apache24/data"
Switch to /usr/local/www
Using 'apache' user for now

Update httpd.conf

	DocumentRoot "/usr/local/www"

    <IfModule unixd_module>
    User apache
    Group apache
    #User www
    #Group www
    </IfModule>



Copy over modified (custom) CB2 conf files to conf/:

    cp -rf /usr/local/directadmin/custombuild/custom/ap2/conf/ /usr/local/etc/apache24/
    cp -f /usr/local/directadmin/custombuild/custom/ap2/conf/httpd.conf /usr/local/etc/apache24/
    cp -f /usr/local/directadmin/custombuild/custom/ap2/conf/extra/httpd-mpm.conf /usr/local/etc/apache24/extra/httpd-mpm.conf


Already done (default):

	perl -pi -e 's/^DefaultType/#DefaultType/' /usr/local/etc/apache24/httpd.conf
	chmod 710 /usr/local/etc/apache24/


Rewrite Apache 2.4 configuration files
Perhaps skip this? No need I think -sg

    cd /usr/local/directadmin/custombuild
    ./build rewrite_confs

Add these to /boot/loader.conf:

    accf_httpd_load="YES"
    accf_data_load="YES"


Not installed: `/usr/ports/www/mod_security`



##### Webapps Installation

From scripts/webmail.sh

Create user and group:

	pw groupadd webapps
	pw useradd -g webapps -n webapps -b /usr/local/www -s /sbin/nologin


Set permissions on temp directory:

	chmod 777 /usr/local/www/tmp

Temp path: /usr/local/www/webmail/tmp

Reference:

	$TAR xzf ${FILE} -C ${DEST}

Create webmail directory:

    mkdir -p /usr/local/www/webmail/tmp
    chmod -R 770 /usr/local/www/webmail/tmp;
    chown -R webapps:webapps /usr/local/www/webmail
    chown -R apache:webapps /usr/local/www/webmail/tmp;
	echo "Deny from All" >> $TMPDIR/.htaccess

Increase the timeout from 10 minutes to 24

	perl -pi -e 's/idle_timeout = 10/idle_timeout = 24/' ${DEST}/webmail/inc/config.security.php

    perl -pi -e 's#\$temporary_directory = "./database/";#\$temporary_directory = "./tmp/";#' ${DEST}/webmail/inc/config.php
    perl -pi -e 's/= "ONE-FOR-EACH";/= "ONE-FOR-ALL";/' ${DEST}/webmail/inc/config.php
    perl -pi -e 's#\$smtp_server = "SMTP.DOMAIN.COM";#\$smtp_server = "localhost";#' ${DEST}/webmail/inc/config.php
    #perl -pi -e 's#\$default_mail_server = "POP3.DOMAIN.COM";#\$default_mail_server = "localhost";#' ${DEST}/webmail/inc/config.php
    perl -pi -e 's/POP3.DOMAIN.COM/localhost/' ${DEST}/webmail/inc/config.php

	rm -rf ${DEST}/webmail/install



Copy redirect.php (done):

	cp -f /usr/local/directadmin/scripts/redirect.php /usr/local/www/redirect.php


##### Install phpMyAdmin

Install via packages:

	pkg install -y databases/phpmyadmin

Reference:
	# Alias /phpmyadmin/ "/usr/local/www/phpMyAdmin/"

    # <Directory "/usr/local/www/phpMyAdmin/">
    # 	Options None
    # 	AllowOverride Limit

    # 	Require local
    # 	Require host .example.com
    # </Directory>

Custom config (if present):

	PMA_CONFIG=${CWD}/custom/phpmyadmin/config.inc.php
	PMA_THEMES=${CWD}/custom/phpmyadmin/themes

Reference: Paths:

    WWWDIR=/usr/local/www`
    ##REALPATH=${WWWDIR}/phpMyAdmin-${PHPMYADMIN_VER}
    REALPATH=/usr/local/www/phpMyAdmin
    ALIASPATH=${WWWDIR}/phpMyAdmin
    CONFIG=${REALPATH}/config.inc.php

Scripted reference:

	# If custom config exists
	if [ -e ${PMA_CONFIG} ]; then
		echo "Installing custom PhpMyAdmin Config: ${PMA_CONFIG}"
		cp -f ${PMA_CONFIG} ${REALPATH}/config.inc.php
	else
		cp -f ${REALPATH}/config.sample.inc.php ${REALPATH}/config.inc.php
		perl -pi -e "s#\['host'\] = 'localhost'#\['host'\] = '${MYSQLHOST}'#" ${REALPATH}/config.inc.php
		perl -pi -e "s#\['host'\] = ''#\['host'\] = '${MYSQLHOST}'#" ${REALPATH}/config.inc.php
		perl -pi -e "s#\['auth_type'\] = 'cookie'#\['auth_type'\] = 'http'#" ${REALPATH}/config.inc.php
		perl -pi -e "s#\['extension'\] = 'mysql'#\['extension'\] = 'mysqli'#" ${REALPATH}/config.inc.php
	fi

Copy sample config:

	cp /usr/local/www/phpMyAdmin/config.sample.inc.php /usr/local/www/phpMyAdmin/config.inc.php

Update phpMyAdmin configuration file:

	perl -pi -e "s#\['host'\] = 'localhost'#\['host'\] = 'localhost'#" /usr/local/www/phpMyAdmin/config.inc.php
	perl -pi -e "s#\['host'\] = ''#\['host'\] = 'localhost'#" /usr/local/www/phpMyAdmin/config.inc.php
	perl -pi -e "s#\['auth_type'\] = 'cookie'#\['auth_type'\] = 'http'#" /usr/local/www/phpMyAdmin/config.inc.php
	perl -pi -e "s#\['extension'\] = 'mysql'#\['extension'\] = 'mysqli'#" /usr/local/www/phpMyAdmin/config.inc.php

	# Copy custom themes:
	if [ -d ${PMA_THEMES} ]; then
		echo "Installing custom PhpMyAdmin themes: ${PMA_THEMES}"
		cp -Rf ${PMA_THEMES} ${REALPATH}
	fi

	# Update alias path via symlink (not done):
	rm -f ${ALIASPATH} >/dev/null 2>&1
	ln -s ${REALPATH} ${ALIASPATH}


	# Create logs directory:
	if [ ! -d ${REALPATH}/log ]; then
		mkdir -p ${REALPATH}/log
	fi

	# Set permissions:
	chown -R ${APPUSER}:${APPUSER} ${REALPATH}
	chown -h ${APPUSER}:${APPUSER} ${ALIASPATH}
	chmod 755 ${REALPATH}


Set permissions:

	chown -R webapps:webapps /usr/local/www/phpMyAdmin
	chown -h webapps:webapps /usr/local/www/phpMyAdmin
	chmod 755 /usr/local/www/phpMyAdmin

Symlink:

    ln -s /usr/local/www/phpMyAdmin /usr/local/www/phpmyadmin
    ln -s /usr/local/www/phpMyAdmin /usr/local/www/pma

Reference:

	# Disable scripts directory (path doesn't exist):
	if [ -d ${REALPATH}/scripts ]; then
		chmod 000 ${REALPATH}/scripts
	fi

	# Disable setup directory (done):
	if [ -d ${REALPATH}/setup ]; then
		chmod 000 ${REALPATH}/setup
	fi

	# Auth log patch for BFM compat (not done):
	# Currently outputs to /var/log/auth.log
	getFile patches/pma_auth_logging.patch pma_auth_logging.patch

	if [ -e patches/pma_auth_logging.patch ]; then
		echo "Patching phpMyAdmin to log failed authentications for BFM..."
		cd ${REALPATH}
		patch -p0 < ${WORKDIR}/patches/pma_auth_logging.patch
	fi


Update /etc/groups (verify):

	#access:*:1164:apache,nobody,mail,majordomo,daemon,clamav


##### Install FTP Daemon


Modify: /usr/local/directadmin/data/templates/proftpd.conf
Copy to custom/?


Note: When starting directadmin with the "i" switch, it tries to copy itself to /etc/proftpd.conf later

Install proftpd via packages:

	pkg install -y proftpd

Remove stock configuration file:

	rm -f /usr/local/etc/proftpd.conf

    # Create password file (not done, leaving it in /etc/):
    # touch /usr/local/etc/proftpd/proftpd.passwd
    # chown root:ftp /usr/local/etc/proftpd/proftpd.passwd
    # chmod 640 /usr/local/etc/proftpd/proftpd.passwd

Symlink:

    ln -s /usr/local/etc/proftpd.conf /etc/proftpd.conf
    ln -s /usr/local/etc/proftpd/proftpd.passwd /etc/proftpd.passwd
    #ln -s /usr/local/etc/proftpd/proftpd.vhosts.conf /etc/proftpd.vhosts.conf


Create password file (Note: Decided to leave files in /etc/)

    # touch /usr/local/etc/proftpd/proftpd.passwd
    # chown root:ftp /usr/local/etc/proftpd/proftpd.passwd;
    # chmod 640 /usr/local/etc/proftpd/proftpd.passwd
    #chmod 644 /usr/local/etc/proftpd/proftpd.vhosts.conf

    touch /etc/proftpd.passwd
    chown root:ftp /etc/proftpd.passwd;
    chmod 640 /etc/proftpd.passwd

Create log directory (and apply permissions?)
	mkdir -p /var/log/proftpd


###### Install PureFTPd


Install via packages:

	pkg install -y ftp/pure-ftpd

Install via ports (needed to enable uploadscript support):

	portmaster -d ftp/pure-ftpd

Update /etc/rc.conf:

	pureftpd_enable="YES"
	#pureftpd_flags=""

Startup flags reference (for /etc/rc.conf):

    OPTIONS="-B -A -C 4 -H -k 95 -L 2000:8 -O stats:${LOG} -l puredb:${DB} -p 35000:35999 -u 100 -U 133:022 -w -Z"
    OPTIONS="${OPTIONS} -Y 1 -J HIGH:MEDIUM:+TLSv1:!SSLv2:+SSLv3"


#### Install Exim

Exim can be installed via pkg, however you it won't support or integrate with SpamAssassin, DCC, DMARC, SPF, or SRS.

Install via pkg (doesn't support SPF and other goodies):

	pkg install mail/exim

Install via ports for advanced features:

	portmaster -d mail/exim

Options enabled:

	DCC, DMARC, SPF, SA_EXIM, SRS

Note: these get installed too:

    mail/libsrs_alt
    mail/opendmarc

Update directadmin.conf with correct Exim binary path:

	echo "mq_exim_bin=/usr/local/sbin/exim" >> /usr/local/directadmin/conf/directadmin.conf

Update /etc/mail/mailer.conf:

	ee /etc/mail/mailer.conf

Change to:

    sendmail /usr/local/sbin/exim
    send-mail /usr/local/sbin/exim
    mailq /usr/local/sbin/exim -bp
    newaliases /usr/bin/true
    #hoststat /usr/libexec/sendmail/sendmail
    #purgestat /usr/libexec/sendmail/sendmail
    rmail /usr/local/sbin/exim -i -oee

Adjust /etc/periodic.conf

    touch /etc/periodic.conf
    echo "daily_status_include_submit_mailq=\"NO\"" >> /etc/periodic.conf
    echo "daily_clean_hoststat_enable=\"NO\"" >> /etc/periodic.conf


```

Configuration file path: /usr/local/etc/exim
Changes done to /usr/local/etc/exim/exim.conf

#2:
# was: .include_if_exists /etc/exim.clamav.load.conf
av_scanner = clamd:/var/run/clamav/clamd
#.include_if_exists /usr/local/etc/exim/exim.clamav.load.conf

# Block Cracking variables
.include_if_exists /usr/local/etc/exim/exim.blockcracking/variables.conf

# Easy Spam Figher variables
.include_if_exists /usr/local/etc/exim/exim.easy_spam_fighter/variables.conf

#4:
perl_startup = do '/usr/local/etc/exim/exim.pl'

#5:
system_filter = /usr/local/etc/exim/system_filter.exim

#8:
.include /usr/local/etc/exim/exim.variables.conf
.include /usr/local/etc/exim/exim.strings.conf
.include_if_exists /usr/local/etc/exim/exim.strings.conf.custom

#23:
tls_certificate = /usr/local/etc/ssl/exim.cert
tls_privatekey = /usr/local/etc/ssl/exim.key

#24:
.include_if_exists /usr/local/etc/exim/exim.easy_spam_fighter/connect.conf

#25:
.include_if_exists /usr/local/etc/exim/exim.blockcracking/script.conf

#26:
.include_if_exists /usr/local/etc/exim/exim.blockcracking/auth.conf


#31:
.include_if_exists /usr/local/etc/exim/exim.easy_spam_fighter/check_mail.conf

#42:
.include_if_exists /usr/local/etc/exim/exim.easy_spam_fighter/check_rcpt.conf

#45:
.include_if_exists /usr/local/etc/exim/exim.easy_spam_fighter/check_dkim.conf

.include_if_exists /usr/local/etc/exim/exim.easy_spam_fighter/check_message.conf

#46:
#.include_if_exists /usr/local/etc/exim/exim.clamav.conf

#49:
.include_if_exists /usr/lcoal/etc/exim/exim.spamassassin.conf

#54:
  command = /usr/local/sbin/exim -oMr spam-scanned -bS
  transport_filter = /usr/local/bin/spamc -u ${lookup{$domain}lsearch*{/etc/virtual/domainowners}{$value}}

#61:
.include_if_exists /usr/local/etc/exim/exim.dkim.conf

#62:
.include_if_exists /usr/local/etc/exim/exim.cagefs.pipe.conf
```


Fetch latest exim.conf & exim.pl (Note: 4.4.0 is alpha right now):

    wget -O /usr/local/etc/exim/exim.conf http://files.directadmin.com/services/SpamBlocker/4.4.0/exim.conf-SpamBlockerTechnology-v4.4.0.txt
    wget -O /usr/local/etc/exim/exim.pl http://files.directadmin.com/services/SpamBlocker/4.4.0/exim.pl
    wget -O /usr/local/etc/exim/exim.strings.conf http://files.directadmin.com/services/SpamBlocker/4.4.0/exim.strings.conf
    wget -O /usr/local/etc/exim/exim.variables.conf.default http://files.directadmin.com/services/SpamBlocker/4.4.0/exim.variables.conf.default

    wget -O /usr/local/etc/exim/exim.dkim.conf http://files.directadmin.com/services/exim.dkim.conf
    wget -O /usr/local/etc/exim/exim.spamassassin.conf http://files.directadmin.com/services/exim.spamassassin.conf
    wget -O /usr/local/etc/exim/exim.clamav.conf http://files.directadmin.com/services/exim.clamav.conf
    wget -O /usr/local/etc/exim/exim.clamav.load.conf http://files.directadmin.com/services/exim.clamav.load.conf
    wget -O /usr/local/etc/exim/system_filter.exim http://files.directadmin.com/services/system_filter.exim

Set execute permission:

	chmod +x /usr/local/etc/exim/exim.pl


-sg: Already done via /etc/rc.conf switches:

	/usr/local/bin/perl -pi -e 's/sendmail_enable=\"YES\"/sendmail_enable=\"NONE\"/' /etc/rc.conf
	/usr/local/bin/perl -pi -e 's/sendmail_enable=\"NO\"/sendmail_enable=\"NONE\"/' /etc/rc.conf

By Default, Exim uses mail:mailnull as the user & group (FreeBSD default) but DirectAdmin prefers mail:mail.

Set permissions:

	chown -R mail:mail /var/spool/exim

Symlink for compat:

	ln -s /usr/local/etc/exim/exim.conf /etc/exim.conf

Generate Self-Signed SSL Certificates
See: http://help.directadmin.com/item.php?id=245

	/usr/bin/openssl req -x509 -newkey rsa:2048 -keyout /usr/local/etc/exim/exim.key -out /usr/local/etc/exim/exim.cert -days 9000 -nodes

Symlink for compat:

	ln -s /usr/local/etc/exim/exim.key /etc/exim.key
	ln -s /usr/local/etc/exim/exim.cert /etc/exim.cert

Set permissions:

	chown mail:mail /usr/local/etc/exim/exim.key
	chmod 644 /usr/local/etc/exim/exim.key
	chmod 644 /usr/local/etc/exim/exim.cert

Restart Exim for the changes to take effect:

	service exim restart

Reference: Verify Exim config:

	exim -C /usr/local/etc/exim/exim.conf -bV`


#### Install Dovecot 2

Install via packages:

	pkg install -y mail/dovecot2

Install via ports:

	portmaster -d mail/dovecot2


Configuration files path: /usr/local/etc/dovecot

Fetch latest config:

	wget -O /usr/local/etc/dovecot/dovecot.conf http://files.directadmin.com/services/custombuild/dovecot.conf.2.0

Update directadmin.conf:

	echo "add_userdb_quota=1" >> /usr/local/directadmin/conf/directadmin.conf
	echo "dovecot=1" >> /usr/local/directadmin/conf/directadmin.conf


Reference: doRestartDA:

	echo "action=rewrite&value=email_passwd" >> ${TASK_QUEUE}
	#run_dataskq d

Add Dovecot quota support to the directadmin.conf template:

	echo "add_userdb_quota=1" >> /usr/local/directadmin/data/templates/directadmin.conf

Update dovecot.conf for SSL support using existing Apache 2.4 certs:

    # ssl_cert = </usr/local/etc/apache24/ssl/server.crt
    # ssl_key = </usr/local/etc/apache24/ssl/server.key

or using existing Exim certs:

    # ssl_cert = </usr/local/etc/exim/exim.crt
    # ssl_key = </usr/local/etc/exim/exim.key

or using your own custom certs:

	# ssl_cert = </usr/local/etc/ssl/server.crt
    # ssl_key = </usr/local/etc/ssl/server.key

Prepare Dovecot directories:

    mkdir -p /etc/dovecot/
    mkdir -p /usr/local/etc/dovecot/conf
    mkdir -p /usr/local/etc/dovecot/conf.d


Symlink for compat:

	ln -s /usr/local/etc/dovecot/dovecot.conf /etc/dovecot/dovecot.conf
    # Skipped: ln -s /etc/dovecot/dovecot.conf /etc/dovecot.conf

	cp -rf /usr/local/directadmin/custombuild/configure/dovecot/conf /usr/local/etc/dovecot/

	echo 'mail_plugins = $mail_plugins quota' > /usr/local/etc/dovecot/conf/lmtp_mail_plugins.conf
	perl -pi -e "s|HOSTNAME|`hostname`|" /usr/local/etc/dovecot/conf/lmtp.conf

Log files (not done):

    touch /var/log/dovecot-lmtp.log /var/log/dovecot-lmtp-errors.log
    chown root:wheel /var/log/dovecot-lmtp.log /var/log/dovecot-lmtp-errors.log
    chmod 600 /var/log/dovecot-lmtp.log /var/log/dovecot-lmtp-errors.log

Modifications (done):

    perl -pi -e 's#transport = dovecot_lmtp_udp#transport = virtual_localdelivery#' /usr/local/etc/exim/exim.conf
    perl -pi -e 's/driver = shadow/driver = passwd/' /usr/local/etc/dovecot/dovecot.conf
    perl -pi -e 's/passdb shadow/passdb passwd/' /usr/local/etc/dovecot/dovecot.conf

    echo 'mail_plugins = $mail_plugins quota' > /usr/local/etc/dovecot/conf/mail_plugins.conf
    echo 'mail_plugins = $mail_plugins quota imap_quota' > /usr/local/etc/dovecot/conf/imap_mail_plugins.conf

```
# # Check for IPV6 compatability (not done):
# if [ "${IPV6}" = "1" ]; then
# 	perl -pi -e 's|^listen = \*$|#listen = \*|' /usr/local/etc/dovecot/dovecot.conf
# 	perl -pi -e 's|^#listen = \*, ::$|listen = \*, ::|' /usr/local/etc/dovecot/dovecot.conf
# else
# 	perl -pi -e 's|^#listen = \*$|listen = \*|' /usr/local/etc/dovecot/dovecot.conf
# 	perl -pi -e 's|^listen = \*, ::$|#listen = \*, ::|' /usr/local/etc/dovecot/dovecot.conf
# fi
```

	echo "listen = *, ::" > /usr/local/etc/dovecot/conf/ip.conf





##### Todo: Install nginx

Update directadmin.conf:

    nginxconf=/usr/local/etc/nginx/directadmin-vhosts.conf
    nginxlogdir=/var/log/nginx/domains
    nginxips=/usr/local/etc/nginx/directadmin-ips.conf
    nginx_pid=/var/run/nginx.pid
    nginx_cert=/usr/local/etc/nginx/ssl/server.crt
    nginx_key=/usr/local/etc/nginx/ssl/server.key
    nginx_ca=/usr/local/etc/nginx/ssl/server.ca


##### Install ClamAV

Install via packages:

	pkg install -y security/clamav

Install via ports:

	portmaster -d security/clamav

    # Configuration Options
    # ===> The following configuration options are available for clamav-0.98.7:
    #      ARC=on: Enable arch archives support
    #      ARJ=on: Enable arj archives support
    #      DMG_XAR=on: Enable DMG and XAR archives support
    #      DOCS=on: Build and/or install documentation
    #      EXPERIMENTAL=off: Build experimental code
    #      ICONV=off: Encoding conversion support via iconv
    #      IPV6=on: IPv6 protocol support
    #      LDAP=off: LDAP protocol support
    #      LHA=on: Enable lha archives support
    #      LLVM=on: Enable JIT Bytecode compiler (bundled LLVM)
    #      MILTER=off: Compile the milter interface
    #      STDERR=off: Print logs to stderr instead of stdout
    #      TESTS=off: Run compile-time tests (req. python)
    #      UNRAR=on: Enable rar archives support
    #      UNZOO=on: Enable zoo archives support
    # ===> Use 'make config' to modify these settings


Config file path: /usr/local/etc/clamd.conf

Run freshclam first

	freshclam

Update /etc/rc.conf:

	clamav_enable="YES"
	# also add freshclam service

Start ClamAV:

	service clamav-clamd start




##### Install Majordomo

Unfortunately, this is the only service that we cannot install from ports because it has been marked broken for a while. Eventually, Majordomo will be replaced by `mail/mailman` (I hope).

    cd /usr/local/directadmin/scripts/packages/
    wget http://files.directadmin.com/services/all/majordomo-1.94.5.tar.gz
    tar zxvf majordomo-1.94.5.tar.gz
    /usr/local/directadmin/scripts/majordomo.sh



-sg: These were skipped?
other files for exim.
```
#cp -f /usr/local/directadmin/data/templates/system_filter.exim /etc/system_filter.exim
#chown -f mail.mail /etc/system_filter.exim
#chmod -f 644 /etc/system_filter.exim

#cp -f /usr/local/directadmin/data/templates/exim.pl /etc/exim.pl
#chown -f mail.mail /etc/exim.pl
#chmod -f 755 /etc/exim.pl
```

##### Enable POP Before SMTP

Enable POP before SMTP (default):

    cp -f /usr/local/directadmin/data/templates/da-popb4smtp /usr/local/etc/rc.d
    chmod 755 /usr/local/etc/rc.d/da-popb4smtp
    /usr/local/etc/rc.d/da-popb4smtp start


#### Webmail Services

##### Install RoundCube

Installation via packages:

	pkg install -y mail/roundcube

Installation via ports:

	portmaster -d mail/roundcube

Might need to use ports instead due to SSL= option:

    # DOCS=on: Build and/or install documentation
    # GD=off: Enable GD support (image conversion)
    # LDAP=off: Enable LDAP support (address book)
    # NSC=off: Install network spellchecker
    # PSPELL=off: Enable PSpell support (internal spellcheck)
    # SSL=off: Enable SSL support (imaps or google spellcheck)
    # ====> Options available for the single DB: you have to select exactly one of them
    # MYSQL=on: Use MySQL backend
    # PGSQL=off: Use PostgreSQL backend
    # SQLITE=off: Use SQLite backend


Reference:

	ROUNDCUBE_DB=da_roundcube
	ROUNDCUBE_DB_USER=da_roundcube
	ROUNDCUBE_DB_PASS=`random_pass`
	ROUNDCUBE_DES_KEY=`random_pass 24`
	ROUNDCUBE_MY_CNF=${REALPATH}/config/my.cnf

	ROUNDCUBE_CONFIG=${CWD}/custom/roundcube/config.inc.php
	ROUNDCUBE_CONFIG_DB=${ROUNDCUBE_CONFIG}
	ROUNDCUBE_CONFIG_OLD=${CWD}/custom/roundcube/main.inc.php
	ROUNDCUBE_CONFIG_DB_OLD=${CWD}/custom/roundcube/db.inc.php
	if [ "${ROUNDCUBE_MAJOR_VER}" = "0" ]; then
		ROUNDCUBE_CONFIG=${ROUNDCUBE_CONFIG_OLD}
		ROUNDCUBE_CONFIG_DB=${ROUNDCUBE_CONFIG_DB_OLD}
	fi
	ROUNDCUBE_PLUGINS=${CWD}/custom/roundcube/plugins
	ROUNDCUBE_SKINS=${CWD}/custom/roundcube/skins
	ROUNDCUBE_PROGRAM=${CWD}/custom/roundcube/program
	ROUNDCUBE_HTACCESS=${CWD}/custom/roundcube/.htaccess

Add webmail= option in directadmin.conf:

	echo "webmail_link=roundcube" >> /usr/local/directadmin/conf/directadmin.conf

Symlink:

    ln -s /usr/local/www/roundcube /usr/local/www/webmail
    chown -R webapps:webapps /usr/local/www/roundcube
    chown -h webapps:webapps /usr/local/www/webmail

Note: Moved the rest of the code to roundcube.sh for now -sg


##### Install SpamAssassin

For DCC, DKIM, PYZOR, RAZOR and SPF_QUERY support, must compile from ports:

Install via packages:

	pkg install -y mail/spamassassin

Install via ports:

	portmaster -d mail/spamassassin

Install SpamAssassin Utilities (recommended):

	pkg install mail/sa-utils

Reference Config: /usr/local/etc/mail/spamassassin/init.pre
Startup flags: spamd -d -c -m 5

Todo: Apply necessary exim.conf changes


Symlink for compat:

	ln -s /usr/local/etc/mail/spamassassin /etc/mail/spamassassin

Additional packages to install for anti-spam control (may have installed via ports):

	pkg install -y mail/pyzor mail/razor-agents mail/dcc-dccd

Todo: dkim_create.sh

Verify: getDA.sh
Verify: atmail.sh
Verify: squirrelmail.sh (skipped)

Dependencies for Anti-Spam stuff (may have installed via ports):

	pkg install -y mail/p5-Mail-SPF mail/p5-Mail-DKIM

Enable DKIM support in directadmin.conf:

	echo "dkim=1" >> /usr/local/directadmin/conf/directadmin.conf


Install libspf2 if BlockCracking and EasySpamFighter is wanted

	pkg install -y mail/libspf2


##### Install BlockCracking
See: http://files.directadmin.com/services/custombuild/blockcracking/
See: https://github.com/Exim/exim/wiki/BlockCracking

    mkdir -p /usr/local/etc/exim/exim.blockcracking
    wget -O /usr/local/etc/exim/exim.blockcracking/exim.blockcracking-1.3.tar.gz http://files.directadmin.com/services/custombuild/blockcracking/exim.blockcracking-1.3.tar.gz

	cp /usr/local/etc/exim/exim.blockcracking/script.denied_paths.default.txt /usr/local/etc/exim/exim.blockcracking/script.denied_paths.txt

##### Install Easy Spam Fighter

See: http://files.directadmin.com/services/custombuild/easy_spam_fighter/

	mkdir -p /usr/local/etc/exim/exim.easy_spam_fighter
    wget -O /usr/local/etc/exim/exim.easy_spam_fighter/exim.easy_spam_fighter-1.9.tar.gz http://files.directadmin.com/services/custombuild/easy_spam_fighter/exim.easy_spam_fighter-1.9.tar.gz

    tar xzf exim.easy_spam_fighter-${EASY_SPAM_FIGHTER_VER}.tar.gz -C /etc/exim.easy_spam_fighter

Modify: exim.easy_spam_fighter/variables.conf
	.include_if_exists /usr/local/etc/exim/exim.easy_spam_fighter/variables.conf.custom
	echo -n "hide srs_config = " > /usr/local/etc/exim/exim.srs.conf
	/usr/bin/openssl rand -base64 48 >> /usr/local/etc/exim/exim.srs.conf





### Startup Scripts


Update /etc/rc.conf with the following entries (modify according to the services you installed):

    sshd_enable="YES"
    named_enable="YES"

    mysql_enable="YES"

    apache24_enable="YES"
    apache24_http_accept_enable="YES"

    php_fpm_enable="YES"

    spamd_enable="YES"
    spamd_flags="-c -m 15"

    clamav_clamd_enable="YES"
    clamav_freshclam_enable="YES"

    exim_enable="YES"
    exim_flags="-bd -q1h"
    #exim_user="mail"
    #exim_group="mail"

    dovecot_enable="YES"
    #dovecot_config="/usr/local/etc/dovecot/dovecot.conf"

    proftpd_enable="YES"

    Distributed Checksum Clearinghouse
    dccd_enable="YES"
    dccifd_enable="YES"


Reference:
	#/usr/bin/limits -U mysql /usr/local/mysql/bin/mysqld_safe --user=mysql --datadir=${DB_DIR} --pid-file=${PIDFILE}


DirectAdmin-specific startup scripts:

Copy:

	# NOTE: Verify boot.sh and adjust as necessary
    cp -f boot.sh /usr/local/etc/rc.d/
	cp -f directadmin /usr/local/etc/rc.d/
    cp -f startips /usr/local/etc/rc.d/
    cp -f functions /usr/local/etc/rc.d/
    cp -f pidof /usr/local/etc/rc.d/

Set permissions:
    chmod 755 /usr/local/etc/rc.d/directadmin
    chmod 755 /usr/local/etc/rc.d/startips
    chmod 755 /usr/local/etc/rc.d/functions
    chmod 755 /usr/local/etc/rc.d/pidof
    chmod 755 /usr/local/etc/rc.d/boot.sh



#### Misc / Issues

##### Services Status

Limitations exist

Update /usr/local/directadmin/data/admin/services.status

Change httpd to apache24 (didn't work)
Change php-fpm56 to php-fpm? (didn't work)
Disable vm-pop3d (done)

This part is buggy, had to disable apache24/httpd/php-fpm/php-fpm56 (all set to OFF)
or else DirectAdmin kept trying to restart the services over and over
Might be PID related, perhaps DA can't find the locations of the files. For now, need to set these off until DA can allow us to set the appropriate paths to the service control scripts.

    da-popb4smtp=ON
    directadmin=ON
    exim=ON
    apache24=ON
    mysqld=ON
    named=ON
    proftpd=ON
    sshd=ON
    vm-pop3d=OFF
    php-fpm56=ON


Install DirectAdmin crontab entries:

	cat /usr/local/directadmin/scripts/directadmin_cron >> /etc/crontab

Set permissions:

    mkdir -p /usr/local/directadmin/data/users/admin/packages
    chown diradmin:diradmin /usr/local/directadmin/data/users/admin/packages
    chmod 700 /usr/local/directadmin/data/users/admin/packages

Install DirectAdmin (skipped):

    cd /usr/local/directadmin
    ./directadmin i

Fix permissions:

    cd /usr/local/directadmin
    ./directadmin p


directadmin.conf updates:

	## Defaults:
	# brute_force_roundcube_log=/var/www/html/roundcube/logs/errors
    # brute_force_squirrelmail_log=/var/www/html/squirrelmail/data/squirrelmail_access_log
    # brute_force_pma_log=/var/www/html/phpMyAdmin/log/auth.log
    brute_force_roundcube_log=/usr/local/www/roundcube/logs/errors
    brute_force_squirrelmail_log=/usr/local/www/squirrelmail/data/squirrelmail_access_log
    brute_force_pma_log=/usr/local/www/phpMyAdmin/log/auth.log

    #pure_pw=/usr/bin/pure-pw
    pure_pw=/usr/bin/pure-pw



Once installation is complete, DirectAdmin says:

    echo "System Security Tips:";
    echo "  http://help.directadmin.com/item.php?id=247";



##### Post install.sh

Check /etc/virtual (again?)

	mkdir /etc/virtual
	chown mail:mail /etc/virtual
	chmod 711 /etc/virtual

-sg: redundant?

Scripted reference:

	for i in blacklist_domains whitelist_from use_rbl_domains bad_sender_hosts blacklist_senders whitelist_domains whitelist_hosts whitelist_senders; do
        touch /etc/virtual/$i;
        chown mail:mail /etc/virtual/$i;
        chmod 644 /etc/virtual/$i;
    done

Manual method:

    touch /etc/virtual/blacklist_domains
    touch /etc/virtual/whitelist_from
    touch /etc/virtual/use_rbl_domains
    touch /etc/virtual/bad_sender_hosts
    touch /etc/virtual/blacklist_senders
    touch /etc/virtual/whitelist_domains
    touch /etc/virtual/whitelist_hosts
    touch /etc/virtual/whitelist_senders

    chown mail:mail /etc/virtual/

    chmod 644 /etc/virtual


Todo (skipped): Install sysbk (see: sysbk.sh)
/usr/local/sysbk

For options knobs in /etc/make.conf: /usr/ports/Mk/bsd.options.mk

Reference: Random Password Generator (from CB2):

	random_pass() {
        tr -cd 'a-zA-Z0-9' < /dev/urandom 2>/dev/null | head -c${1:-`perl -le 'print int rand(7) + 10'`}
    }
