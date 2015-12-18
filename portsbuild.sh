#!/bin/sh
# *************************************************************************************************
# >>> PortsBuild
#
#  Scripted by -sg/mmx.
#
#  Based on the work of CustomBuild 2.x, written by DirectAdmin and Martynas Bendorius (smtalk).
#  CB2 thread: http://forum.directadmin.com/showthread.php?t=44743
#  CB2 DA Plugin: http://forum.directadmin.com/showthread.php?t=48989
#
#  DirectAdmin Homepage : http://www.directadmin.com
#  DirectAdmin Forums   : http://forums.directadmin.com/
#
#  PortsBuild WWW       : http://www.portsbuild.org (coming soon)
#  PortsBuild GitHub    : http://github.com/portsbuild/portsbuild
#
# *************************************************************************************************
#
#  Requirements:
#  - DirectAdmin 1.46 and above (with a valid license).
#  - FreeBSD 10.2-amd64
#  - Patience.
#
#  Installation:
#  - New installs, run: ./portsbuild install
#
#  Existing users:
#  - Update: ./portsbuild update
#  - Verify: ./portsbuild verify
#
# Changelog and History: see CHANGELOG for more details
#
# *************************************************************************************************
#

# Script is incomplete. :)
exit;

### PortsBuild ###

OS=`uname`
OS_VER=`uname -r | cut -d- -f1`
OS_B64=`uname -m | grep -c 64`
OS_BSD=`uname -r | cut -d. -f1`
HOST=`hostname`;

if [ ${OS} = "FreeBSD" ]; then
	if [ ${OS_B64} -eq 1 ]; then
		if [ "$OS_VER" -eq 10.1 ] || [ "$OS_VER" -eq 10.2 ] || [ "$OS_VER" -eq 9.3 ]; then
			echo "FreeBSD $OS_VER x64 operating system detected.";
		else
			echo "Warning: Unsupported FreeBSD operating system detected."
			echo "PortsBuild is tested to work with FreeBSD versions 9.3, 10.1 and 10.2 amd64 only.";
			echo "You can press CLTR+C within 5 seconds to quit the PortsBuild script now, or proceed at your own risk.";
			sleep 5;
		fi
	else
		echo "Error: i386 (x86) systems are not supported.";
		echo "PortsBuild requires FreeBSD 9.3+ amd64 (x64).";
		exit 1;
	fi
else
	echo "PortsBuild is for FreeBSD systems only. Please use CustomBuild for your Linux needs.";
	echo "Visit: http://forum.directadmin.com/showthread.php?t=44743";
	exit 1;
fi

## FreeBSD Ports path
PORTS_BASE=/usr/ports

## Automate this?
## Verify if /usr/ports exists.
if [ ! -d ${PORTS_BASE}/ ]; then
	if [ ${AUTO_MODE} -eq 0]; then
		echo "Error: FreeBSD Ports system not installed. PortsBuild needs this to continue.";
		echo "Please run the following command to install Ports:";
		echo "  portsnap fetch extract";
		echo "or visit: https://www.freebsd.org/doc/en_US.ISO8859-1/books/handbook/ports-using.html";
		exit 1;
	else
		## Automatically install & update /usr/ports/
		/usr/sbin/portsnap fetch extract
	fi
fi


## System Binary/Application paths and variables. Needed?
## Perhaps replace with `which bin` and perform a sanity check
CHOWN=/usr/sbin/chown
CHMOD=/bin/chmod
BOOT_DIR=/usr/local/etc/rc.d/
PERL=/usr/local/bin/perl
PKG_BIN=/usr/sbin/pkg
PKG_FLAGS="install -y"
PKG="${PKG_BIN} ${PKG_FLAGS}"
PORTSNAP=/usr/sbin/portsnap
PORTMASTER=/usr/local/sbin/portmaster
SERVICE=/usr/sbin/service
WGET=/usr/local/bin/wget
TAR=/usr/bin/tar

## Ports: Dependencies
PORT_PORTMASTER=${PORTS_BASE}/ports-mgmt/portmaster
PORT_PERL=${PORTS_BASE}/lang/perl5.20
PORT_AUTOCONF=${PORTS_BASE}/devel/autoconf
PORT_AUTOMAKE=${PORTS_BASE}/devel/automake
PORT_CURL=${PORTS_BASE}/ftp/curl
PORT_WGET=${PORTS_BASE}/ftp/wget
PORT_LIBTOOL=${PORTS_BASE}/devel/libtool
PORT_LIBXML2=${PORTS_BASE}/textproc/libxml2
PORT_LIBXSLT=${PORTS_BASE}/textproc/libxslt
PORT_FREETYPE2=${PORTS_BASE}/print/freetype2
PORT_CYRUSSASL2=${PORTS_BASE}/security/cyrus-sasl2
PORT_PYTHON=${PORTS_BASE}/lang/python
PORT_CCACHE=${PORTS_BASE}/devel/ccache

## Ports: WWW and PHP
PORT_APACHE24=${PORTS_BASE}/www/apache24
PORT_NGINX=${PORTS_BASE}/www/nginx
PORT_PHP55=${PORTS_BASE}/lang/php55
PORT_PHP56=${PORTS_BASE}/lang/php56
PORT_PHPMYADMIN4=${PORTS_BASE}/databases/phpmyadmin
PORT_IONCUBE=${PORTS_BASE}/devel/ioncube
PORT_PCRE=${PORTS_BASE}/devel/pcre

## Ports: Mail & Related Services
PORT_EXIM=${PORTS_BASE}/mail/exim
PORT_SPAMASSASSIN=${PORTS_BASE}/mail/p5-Mail-SpamAssassin
PORT_DOVECOT2=${PORTS_BASE}/mail/dovecot2
PORT_PIGEONHOLE=${PORTS_BASE}/mail/dovecot2-pigeonhole
PORT_CLAMAV=${PORTS_BASE}/security/clamav
PORT_ROUNDCUBE=${PORTS_BASE}/mail/roundcube
PORT_MAILMAN=${PORTS_BASE}/mail/mailman
## Ports: FTPd
PORT_PUREFTPD=${PORTS_BASE}/ftp/pure-ftpd
PORT_PROFTPD=${PORTS_BASE}/ftp/proftpd

## Ports: Databases
PORT_MYSQL55=${PORTS_BASE}/databases/mysql55-server
PORT_MYSQL56=${PORTS_BASE}/databases/mysql56-server
PORT_MARIADB55=${PORTS_BASE}/databases/mariadb55-server
PORT_MARIADB100=${PORTS_BASE}/databases/mariadb100-server

## Ports: Stats
PORT_AWSTATS=${PORTS_BASE}/www/awstats
PORT_WEBALIZER=${PORTS_BASE}/www/webalizer

## Ports: Misc.
# PORT_MEMCACHED=${PORTS_BASE}/databases/memcached
# PORT_PECLMEMCACHE=${PORTS_BASE}/databases/pecl-memcache
# PORT_PECLMEMCACHED=${PORTS_BASE}/databases/pecl-memcached

## Ports: Unsupported
# PORT_MYSQL51=${PORTS_BASE}/databases/mysql51-server
# PORT_PHP54=${PORTS_BASE}/lang/php5
# PORT_SQUIRRELMAIL=${PORTS_BASE}/mail/squirrelmail
# PORT_ATMAIL=${PORTS_BASE}/mail/atmail
# PORT_UEBIMIAU=${PORTS_BASE}/mail/uebimiau

### --- --- --- ###

### Configuration Files & Paths

## DirectAdmin Paths & Files
DA_PATH="/usr/local/directadmin"
DA_SCRIPTS="${DA_PATH}/scripts"
DA_CRON=${DA_SCRIPTS}/directadmin_cron
DA_CONF=${DA_PATH}/conf/directadmin.conf
DA_CONF_TEMPLATE=${DA_PATH}/data/templates/directadmin.conf
DA_MYSQL_CONF=${DA_PATH}/conf/mysql.conf
DA_MYSQL_CNF=${DA_PATH}/conf/my.cnf
DA_LICENSE=${DA_PATH}/conf/license.key

## CustomBuild Paths & Files
CB_PATH=/usr/local/directadmin/custombuild
CB_OPTIONS=${CB_PATH}/options.conf

## Virtual Mail Directory (keeping this path as-is for simplicity).
VIRTUAL=/etc/virtual

## Apache (HTTPD)
HTTPD_DIR=/usr/local/etc/httpd
HTTPD_CONF_DIR=${HTTPD_DIR}/conf
HTTPD_CONF=${HTTPD_CONF_DIR}/httpd.conf

## Nginx (untested)
NGINX_DIR=/usr/local/etc/nginx
NGINX_CONF=${NGINX_DIR}/nginx.conf

## Global WWW Directory (for webmail scripts)
WWW_DIR=/usr/local/www
ROUNDCUBE_DIR=${WWW_DIR}/roundcube
PMA_DIR=${WWW_DIR}/phpmyadmin

## DirectAdmin System Configuration Files
# redundant: DACONF_FILE=/usr/local/directadmin/conf/directadmin.conf
# redundant: DACONF_TEMPLATE_FILE=/usr/local/directadmin/data/templates/directadmin.conf
SERVICES=${DA_PATH}data/admin/services.status
TASK_QUEUE=${DA_PATH}/data/task.queue.cb

## System User Accounts
ADMIN_USER=admin
DB_USER=da_admin
APACHE_USER=apache
APACHE_GROUP=apache
WEBAPPS_USER=webapps
WEBAPPS_GROUP=webapps
EXIM_USER=mail
EXIM_GROUP=mail

## MySQL/MariaDB Paths and Credentials
# DA Default: /home/mysql
MYSQL_DATA=/var/db/mysql
MYSQL_BIN=/usr/local/bin/mysql
MYSQLDUMP_BIN=/usr/local/bin/mysqldump

### --- --- --- ###

## doChecks
## A lot of these checks are unnecessary, since they're already installed in FreeBSD by default.
do_checks() {

	RET=0;

	#DA_CONF=/usr/local/directadmin/data/templates/directadmin.conf

	# Check for a separate /home partition (for quota support).
	HOME_YES=`cat /etc/fstab | grep -c /home`;
	if [ $HOME_YES -lt "1" ]; then
		echo 'quota_partition=/' >> ${DA_CONF_TEMPLATE};
	fi

	# Detect the ethernet interface that is available on the system.
	ETH_DEV="`cat /etc/rc.conf | grep ifconfig | cut -d= -f1 | cut -d_ -f2`"
	if [ "$ETH_DEV" != "" ]; then
		COUNT=`cat $DA_CONF_TEMPLATE | grep -c ethernet_dev`;
		if [ $COUNT -eq 0 ]; then
			echo ethernet_dev=${ETH_DEV} >> $DA_CONF_TEMPLATE;
		fi
	fi

	if [ ! -e /usr/sbin/pkg ]; then
		if [ ${AUTO_MODE} -eq 1 ]; then
			echo "Warning: pkg not found. Attempting to auto-install."
			setup_pkg;
		else
			echo "*** Error: cannot find pkg (/usr/sbin/pkg). Please make sure that pkg is installed. ***";
			RET=1;
		fi
	fi

	if [ ! -e /usr/local/sbin/named ]; then
		echo "*** Error: cannot find the named binary. Please install: dns/bind910 ***";
		RET=1;
	fi

	# if [ ! -e /usr/local/etc/namedb/named.conf ]; then
	# 	echo "*** Error: Cannot find /usr/local/etc/namedb/named.conf.  Make sure Bind is completely installed. ***";
	# 	RET=1;
	# fi

	# if [ ! -e /usr/local/bin/gcc ]; then
	# 	echo "*** Error: gcc not found. Please install: lang/gcc48 ***";
	# 	RET=1;
	# fi

	if [ ! -e /usr/bin/flex ]; then
		echo "*** Error: flex not found in the Base System, which is odd. ***";
		RET=1;
	fi

	if [ ! -e /usr/local/bin/bison ]; then
		echo "*** Error: bison not found. Please install: devel/bison ***";
		RET=1;
	fi

	if [ ! -e /usr/include/openssl/ssl.h ]; then
		echo "*** Error: Base System OpenSSL libraries were not found (specifically: /usr/include/openssl/ssl.h). ***";
		RET=1;
	fi

	# if [ ! -e /usr/bin/patch ]; then
	# 	echo "*** Error: patch not found in the Base System (/usr/bin/patch), which is odd. ***";
	# 	RET=1;
	# fi

	if [ ! -e /usr/sbin/edquota ]; then
		echo "*** Error: cannot find /usr/sbin/edquota. Please make sure that quota is installed. ***";
		RET=1;
	fi

	if [ $RET = 0 ]; then
		echo "All pre-install checks have passed.";
	else
		if [ ${AUTO_MODE} -eq 1 ]; then
			echo "Auto-Installing required dependencies.";
			install_Deps;
		else
			echo "*** Error: Pre-install checks failed. Please look above to see what has failed and apply the necessary fixes.";
			echo "Once requirements are met, run the following to continue the install:";
			echo "  cd /usr/local/directadmin/scripts";
			echo "  ./portsbuild.sh";
		fi
	fi
}


## pkg bootstrap
setup_pkg() {
	echo "Bootstrapping and updating pkg";
	env ASSUME_ALWAYS_YES=YES pkg bootstrap
	/usr/sbin/pkg update
}

## pkg update
update_pkg() {
		${PKG} update
}

## Setup /usr/ports
setup_ports() {
	/usr/sbin/portsnap fetch extract
}

## Pre-Install Tasks
pre_install() {

	## Need to create a blank /etc/auth.conf file for DA compatibility.
	if [ ! -e /etc/auth.conf ]; then
		echo "Pre-Install Task: creating /etc/auth.conf"
		/usr/bin/touch /etc/auth.conf;
		/bin/chmod 644 /etc/auth.conf;
	fi

	## Symlink Perl for DA compat
	if [ ! -e /usr/bin/perl ]; then
		if [ -e /usr/local/bin/perl ]; then
			ln -s /usr/local/bin/perl /usr/bin/perl
		else
			${PKG} ${PORT_PERL}
			if [ $? eq 0 ]; then
				ln -s /usr/local/bin/perl /usr/bin/perl
			fi
		fi
	fi

	# pkg install -y gcc gmake perl5 wget bison flex cyrus-sasl cmake python autoconf libtool libarchive iconv bind99 mailx

	# Make sure pkg is installed. Check ports?
	# if [ ! -e /usr/sbin/pkg ]; then
	# 	pkg
	# fi

}

## Post-Install Tasks
post_install() {
	# cleanup leftover files?
	exit 0;
}

## Install Dependencies
install_deps() {
	if [ ${OS_BSD} -eq 10 ]; then
		/usr/sbin/pkg install -y devel/gmake lang/perl5.20 ftp/wget devel/bison textproc/flex graphics/gd security/cyrus-sasl2 devel/cmake lang/python devel/autoconf devel/libtool archivers/libarchive mail/mailx dns/bind910
	else if [ ${OS_BSD} -eq 9 ]; then
		/usr/sbin/pkg install -y devel/gmake lang/perl5.20 ftp/wget devel/bison textproc/flex graphics/gd security/cyrus-sasl2 devel/cmake lang/python devel/autoconf devel/libtool archivers/libarchive mail/mailx
	fi
}

## Install Compat Libraries
install_compats() {
	if [ ${OS_BSD} -eq 10 ]; then
		pkg install -y misc/compat4x misc/compat5x misc/compat6x misc/compat8x misc/compat9x
	else if [ ${OS_BSD} -eq 9 ]; then
		pkg install -y misc/compat4x misc/compat5x misc/compat6x misc/compat8x
	fi	
}

install_ccache() {
	${PKG} ${PORT_CCACHE}
}

disable_sendmail() {
    echo "sendmail_enable=\"NONE\"" >> /etc/rc.conf
    echo "sendmail_submit_enable=\"NO\"" >> /etc/rc.conf
    echo "sendmail_outbound_enable=\"NO\"" >> /etc/rc.conf
    echo "sendmail_msp_queue_enable=\"NO\"" >> /etc/rc.conf

    ${SERVICE} sendmail stop
}

## /etc/rc.conf
update_rc() {

	echo "ipv6_ipv4mapping=\"YES\"" >> /etc/rc.conf

	disable_sendmail();

}

## /etc/sysctl.conf
update_sysctl() {

	echo "net.inet6.ip6.v6only=0" >> /etc/sysctl.conf

	sysctl net.inet6.ip6.v6only=0
}

## /etc/make.conf
update_make() {

	if [ ! -e /etc/make.conf ]; then
		touch /etc/make.conf
	fi


}



## ./portsbuild selection screen
case "$1" in
	"") use_all_settings_toggle ;;
	create_options) use_all_settings_toggle ;;
	set) use_all_settings_toggle ;;
	check_options) use_all_settings_toggle ;;
	update) use_all_settings_toggle ;;
	update_script) use_all_settings_toggle ;;
	all) use_all_settings_toggle ;;
esac