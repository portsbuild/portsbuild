#!/bin/sh
# Fun fact: root's shell is actually /bin/tcsh
# *************************************************************************************************
# >>> PortsBuild
#
#  Scripted by mmx aka -sg aka sarog aka Saro.
#
#  Based on the work of CustomBuild 2.x, written by DirectAdmin and Martynas Bendorius (smtalk).
#
#  CustomBuild2 thread: http://forum.directadmin.com/showthread.php?t=44743
#
#  DirectAdmin Homepage : http://www.directadmin.com
#  DirectAdmin Forums   : http://forums.directadmin.com
#
#  PortsBuild WWW       : https://www.portsbuild.org (coming soon)
#  PortsBuild GitHub    : https://github.com/portsbuild/portsbuild
#
# *************************************************************************************************
#
#  ** Need help? Visit the DirectAdmin Forums and look for the PB thread *URL here*
#
#  ** Found a bug? Please submit an issue: https://github.com/portsbuild/portsbuild/issues
#
#  ** Want to contribute or improve PortsBuild? Please fork and submit a pull request. :)
#
# *************************************************************************************************
#
#  Requirements:
#  - DirectAdmin 1.46 and above (with a valid license)
#  - FreeBSD 9.3 or 10.2 (amd64 only)
#  - chmod +x portsbuild.sh
#  - (optional) mv portsbuild.sh portsbuild
#  - Patience.
#
#  New Installations:
#  - Modify: options.conf
#  - Setup : ./portsbuild.sh setup <USER_ID> <LICENSE_ID> <SERVER_HOSTNAME> <ETH_DEV> <IP_ADDRESS> <IP_NETMASK>
#
#  Existing users:
#  - Update : ./portsbuild.sh update
#  - Upgrade: ./portsbuild.sh upgrade <package|port|service>
#  - Rewrite: ./portsbuild.sh rewrite <configuration>
#  - Verify : ./portsbuild.sh verify
#
#  Changelog/History: see CHANGELOG for more details
#
# *************************************************************************************************
#
# *** If you want to modify PortsBuild settings, please check out 'options.conf' ***
#
################################################################################################################################

### PortsBuild ###

PB_VER="0.1.0"
PB_BUILD_DATE=20160323

IFS="$(printf '\n\t')"
LANG=C

if [ "$(id -u)" != "0" ]; then
  echo "*** Error: Must run this script as the root user."
  exit 1
fi

## $OSTYPE = FreeBSD
## $VENDOR = amd
## $MACHTYPE = x86_64

OS=$(uname)
OS_VER=$(uname -r | cut -d- -f1) # 9.3, 10.1, 10.2, 10.3
OS_B64=$(uname -m | grep -c 64)  # 0, 1
OS_MAJ=$(uname -r | cut -d. -f1) # 9, 10
OS_HOST=$(hostname)
OS_DOMAIN=$(echo "${OS_HOST}" | cut -d. -f2,3,4,5,6)

if [ "${OS}" = "FreeBSD" ]; then
  if [ "${OS_B64}" -eq 1 ]; then
    if [ "${OS_VER}" = "10.1" ] || [ "${OS_VER}" = "10.2" ] || [ "${OS_VER}" = "10.3" ] || [ "${OS_VER}" = "9.3" ]; then
      # echo "FreeBSD $OS_VER x64 operating system detected."
      echo ""
    else
      echo "Warning: Unsupported FreeBSD operating system detected."
      echo "PortsBuild has been tested to work with FreeBSD versions 9.3, 10.1 and 10.2 amd64 only."
      echo "You can press CTRL+C within 5 seconds to quit the PortsBuild script now, or proceed at your own risk."
      sleep 5
    fi
  else
    echo "Error: i386 (x86) systems are not supported."
    echo "PortsBuild requires the 64-bit version (amd64) of FreeBSD."
    exit 1
  fi
else
  echo "PortsBuild is for FreeBSD systems only. Please use CustomBuild for your Linux needs."
  echo "Visit: http://forum.directadmin.com/showthread.php?t=44743"
  exit 1
fi

################################################################################################################################

###
### defaults.conf
###

## System & User Accounts
DA_ADMIN_USERNAME=admin
DA_SQLDB_USERNAME=da_admin
DA_SRV_USER=diradmin
DA_SRV_GROUP=diradmin
APACHE_USER=apache ## www
APACHE_GROUP=apache ## www
NGINX_USER=nginx ## www
NGINX_GROUP=nginx ## www
WEBAPPS_USER=webapps
WEBAPPS_GROUP=webapps
EXIM_USER=mail ## mailnull
EXIM_GROUP=mail ## mail

## System Binary/Application paths and variables
CHOWN=/usr/sbin/chown
CHMOD=/bin/chmod
BOOT_DIR=/usr/local/etc/rc.d
FETCH=/usr/bin/fetch
file_mtime="stat -f %m"
PERL=/usr/local/bin/perl
PKG=/usr/sbin/pkg
# PKGI="${PKG} install -y"
PORTSNAP=/usr/sbin/portsnap
PORTMASTER=/usr/local/sbin/portmaster
SERVICE=/usr/sbin/service
SYNTH=/usr/local/bin/synth
SYSCTL=/sbin/sysctl
WGET=/usr/local/bin/wget
WGET_CONNECT_OPTIONS="--connect-timeout=5 --read-timeout=10 --tries=3"
TAR=/usr/bin/tar

## PortsBuild Paths & Files
PB_PATH=/usr/local/portsbuild
if [ ! -e ${PB_PATH} ] || [ "$(pwd)" != "${PB_PATH}" ]; then
  PB_PATH=$(pwd)
fi

PB_CONF=${PB_PATH}/options.conf
# PB_FILES_PATH=${PB_PATH}/files
# PB_PATH=${PB_PATH}

## PortsBuild Remote File Repository
PB_MIRROR1="http://s3.amazonaws.com/portsbuild/files"
PB_MIRROR=${PB_MIRROR1}

## DirectAdmin Paths & Files
DA_PATH=/usr/local/directadmin
DA_BIN=${DA_PATH}/directadmin
DA_SCRIPTS_PATH=${DA_PATH}/scripts
DA_CRON_FILE=${DA_SCRIPTS}/directadmin_cron
DA_CONF_FILE=${DA_PATH}/conf/directadmin.conf
# DA_CONF=${DA_CONF_FILE}
DA_CONF_TEMPLATE_FILE=${DA_PATH}/data/templates/directadmin.conf
DA_MYSQL_CONF=${DA_PATH}/conf/mysql.conf
DA_MYSQL_CNF=${DA_PATH}/conf/my.cnf
DA_LICENSE_FILE=${DA_PATH}/conf/license.key
# DA_MY_CNF=${DA_MYSQL_CNF}
# DACONF_FILE=${DA_CONF_FILE}
# DACONF_TEMPLATE_FILE=${DA_CONF_TEMPLATE_FILE}

DA_ADMIN_EMAIL=${DA_ADMIN_USERNAME}@${SERVER_DOMAIN}
DA_SETUP_TXT=${DA_SCRIPTS}/setup.txt
# SETUP_TXT=${DA_SETUP_TXT}

DA_SERVICES=${DA_PATH}/data/admin/services.status
DA_TASK_QUEUE=${DA_PATH}/data/task.queue.cb

DA_SSL_KEY=${DA_PATH}/conf/cakey.pem
DA_SSL_CRT=${DA_PATH}/conf/cacert.pem
DA_SSL_CA=${DA_PATH}/conf/carootcert.pem

DA_FREEBSD_SERVICES="services_freebsd90_64.tar.gz"

DA_LAN=0
DA_INSECURE=0
HTTP=https
EXTRA_VALUE=""
BIND_ADDRESS=--bind-address=$IP

## CustomBuild Paths & Files
CB_PATH=${DA_PATH}/custombuild
CB_CONF=${CB_PATH}/options.conf

## Min and Max password lengths when used by random_pass()
MIN_PASS_LENGTH=12
MAX_PASS_LENGTH=16

## Virtual Mail Directory (keeping this path as-is for simplicity)
VIRTUAL_PATH=/etc/virtual
# VIRTUAL=/etc/virtual
# VIRTUAL_DIR=${VIRTUAL_PATH}

## Custom SSL Certificates
SSL_CUSTOM_KEY=/usr/local/etc/ssl/server.key
SSL_CUSTOM_CRT=/usr/local/etc/ssl/server.crt
SSL_CUSTOM_CA=/usr/local/etc/ssl/server.ca

## Apache 2.4
APACHE_PATH=/usr/local/etc/apache24
# APACHE_DIR=${APACHE_PATH}
# APACHE_HTTPD_BIN=/usr/sbin/httpd
APACHE_EXTRA_PATH=${APACHE_PATH}/extra
APACHE_LIB_PATH=/usr/local/libexec/apache24
APACHE_CONF=${APACHE_PATH}/httpd.conf
APACHE_HOST_CONF=${APACHE_PATH}/extra/httpd-hostname.conf
APACHE_MIME_TYPES=${APACHE_PATH}/mime.types

APACHE_SSL_KEY=${APACHE_PATH}/ssl/server.key
APACHE_SSL_CRT=${APACHE_PATH}/ssl/server.crt
APACHE_SSL_CA=${APACHE_PATH}/ssl/server.ca
APACHE_PID=/var/run/httpd.pid

## Nginx (untested)
NGINX_PATH=/usr/local/etc/nginx
NGINX_CONF=${NGINX_PATH}/nginx.conf
NGINX_VHOSTS_PATH=${NGINX_PATH}/vhosts

NGINX_SSL_KEY=${NGINX_PATH}/ssl/server.key
NGINX_SSL_CRT=${NGINX_PATH}/ssl/server.crt
NGINX_SSL_CA=${NGINX_PATH}/ssl/server.ca

## Needed?
NGINX_VHOSTS_CONF=${NGINX_PATH}/directadmin-vhosts.conf
NGINX_LOG_DIR=/var/log/nginx/domains
NGINX_IPS_CONF=${NGINX_PATH}/directadmin-ips.conf
#NGINX_PID=/var/run/nginx.pid

## Global WWW Directory (for webmail scripts)
WWW_DIR=/usr/local/www ## Ports uses "${WWWDIR}"
WWW_TMP_DIR=${WWW_DIR}/tmp

WEBMAIL_DIR=${WWW_DIR}/webmail
WEBMAIL_TMP_DIR=${WEBMAIL_DIR}/tmp

## RoundCube
ROUNDCUBE_PATH=${WWW_DIR}/roundcube
ROUNDCUBE_CONF=${ROUNDCUBE_PATH}/config/config.inc.php
ROUNDCUBE_CONFIG_CUSTOM=${ROUNDCUBE_CONF}

## Custom configuration files from CB2
ROUNDCUBE_PLUGINS=${PB_PATH}/custom/roundcube/plugins
ROUNDCUBE_SKINS=${PB_PATH}/custom/roundcube/skins
ROUNDCUBE_PROGRAM=${PB_PATH}/custom/roundcube/program
ROUNDCUBE_HTACCESS=${PB_PATH}/custom/roundcube/.htaccess

## phpMyAdmin
PMA_PATH=${WWW_DIR}/phpMyAdmin
# PMA_DIR=${PMA_PATH}
PMA_CONFIG=${PMA_PATH}/config.inc.php

## PHP
PHP1_VERSION=56
PHP1_MODE=fpm
# PHP2_VERSION=70
# PHP2_MODE=fpm
PHP1_RELEASE_SET="55 56 70"
OPT_PHP1_VERSION_SET="$(echo "${PHP1_RELEASE_SET}" | tr -d '.')"

PHP_ETC_PATH=/usr/local/etc/php
# PHP_DIR=${PHP_ETC_PATH}
PHP_INI=/usr/local/etc/php.ini
PHP_INI_EXTENSIONS=${PHP_ETC_PATH}/extensions.ini
PHP_INI_OPCACHE=${PHP_ETC_PATH}/opcache.ini
PHP_INI_WEBAPPS=${PHP_ETC_PATH}/50-webapps.ini
PHP_INI_DIRECTADMIN=${PHP_ETC_PATH}/10-directadmin.ini

## Exim
EXIM_BIN=/usr/local/sbin/exim
EXIM_PATH=/usr/local/etc/exim
# EXIM_DIR=${EXIM_PATH}
EXIM_CONF=${EXIM_PATH}/configure ## verify
EXIM_RECIPIENTS_MAX=150

EXIM_SSL_KEY=${EXIM_PATH}/ssl/exim.key
EXIM_SSL_CRT=${EXIM_PATH}/ssl/exim.crt
EXIM_SSL_CA=${EXIM_PATH}/ssl/exim.ca

EXIM_BC_PATH=${EXIM_PATH}/blockcracking
EXIM_ESF_PATH=${EXIM_PATH}/easyspamfigther

## Dovecot
DOVECOT_PATH=/usr/local/etc/dovecot
# DOVECOT_DIR=${DOVECOT_PATH}
DOVECOT_CONF=${DOVECOT_PATH}/dovecot.conf
DOVECOT_CONF_SIEVE=

DOVECOT_SSL_KEY=${DOVECOT_PATH}/ssl/dovecot.key
DOVECOT_SSL_CRT=${DOVECOT_PATH}/ssl/dovecot.crt
DOVECOT_SSL_CA=${DOVECOT_PATH}/ssl/dovecot.ca

## ClamAV
CLAMD_CONF=/usr/local/etc/clamd.conf
FRESHCLAM_CONF=/usr/local/etc/freshclam.conf
CLAMDSCAN_BIN=/usr/local/bin/clamdscan

## PureFTPD
PATH_TO_UPLOADSCAN=/usr/local/bin/pureftpd_uploadscan.sh
PUREFTPD_UPLOADSCAN_SCRIPT=${PB_PATH}/configure/pureftpd/pureftpd_uploadscan.sh
if [ -e "${PB_PATH}/custom/pureftpd/pureftpd_uploadscan.sh" ]; then
  PUREFTPD_UPLOADSCAN_SCRIPT=${PB_PATH}/custom/pureftpd/pureftpd_uploadscan.sh
fi

## ProFTPD
PROFTPD_CONF=/usr/local/etc/proftpd.conf
PROFTPD_CLAMAV_CONF=/usr/local/etc/proftpd.clamav.conf

## MySQL/MariaDB
## DA default data path is: /home/mysql
SQL_DATA_PATH=/var/db/mysql
# MYSQL_DATA=${SQL_DATA_PATH}
MYSQL_HOST=localhost
MYSQL_CNF=/usr/local/etc/my.cnf
MYSQL_BIN=/usr/local/bin/mysql
MYSQLADMIN_BIN=/usr/local/bin/mysqladmin
MYSQLCHECK_BIN=/usr/local/bin/mysqlcheck
MYSQLD_BIN=/usr/local/libexec/mysqld
MYSQLD_SAFE_BIN=/usr/local/bin/mysqld_safe
MYSQLDUMP_BIN=/usr/local/bin/mysqldump
MYSQLIMPORT_BIN=/usr/local/bin/mysqlimport
MYSQLSECURE_BIN=/usr/local/bin/mysql_secure_installation
MYSQLSHOW_BIN=/usr/local/bin/mysqlshow
MYSQLUPGRADE_BIN=/usr/local/bin/mysql_upgrade

MYSQL=${MYSQL_BIN}
MYSQLADMIN=${MYSQLADMIN_BIN}
MYSQLCHECK=${MYSQLCHECK_BIN}
MYSQLD=${MYSQLD_BIN}
MYSQLD_SAFE=${MYSQLD_SAFE_BIN}
MYSQLDUMP=${MYSQLDUMP_BIN}
MYSQLIMPORT=${MYSQLIMPORT_BIN}
MYSQLSECURE=${MYSQLSECURE_BIN}
MYSQLSHOW=${MYSQLSHOW_BIN}
MYSQLUPGRADE=${MYSQLUPGRADE_BIN}

NEWSYSLOG_FILE=/usr/local/etc/newsyslog.d/directadmin.conf
NEWSYSLOG_DAYS=10

INITDDIR=/usr/local/etc/rc.d

################################################################################################################################

###
### ports.conf
###

## FreeBSD Ports path
PORTS_BASE=/usr/ports
# PORTS_VAR_DB=/var/db/ports
# PKG_VAR_DB=/var/db/pkgs

## Ports: Dependencies
PORT_PORTMASTER=ports-mgmt/portmaster
PORT_SYNTH=ports-mgmt/synth
PORT_GCC6=lang/gcc6-aux
PORT_NCURSES=devel/ncurses
PORT_PERL=lang/perl5.20
PORT_AUTOCONF=devel/autoconf
PORT_AUTOMAKE=devel/automake
PORT_CURL=ftp/curl
PORT_LIBTOOL=devel/libtool
PORT_LIBXML2=textproc/libxml2
PORT_LIBXSLT=textproc/libxslt
PORT_FREETYPE2=print/freetype2
PORT_CYRUSSASL2=security/cyrus-sasl2
PORT_PYTHON=lang/python
PORT_CCACHE=devel/ccache
PORT_CMAKE=devel/cmake
PORT_GMAKE=devel/gmake
PORT_WGET=ftp/wget

## Ports: Web Servers
PORT_APACHE24=www/apache24
PORT_NGINX=www/nginx
# PORT_NGHTTP2=www/nghttp2

PORT_LETSENCRYPT=security/letsencrypt.sh

## Ports: PHP
PORT_PHP55=lang/php55
PORT_PHP55_EXT=lang/php55-extensions
PORT_PHP56=lang/php56
PORT_PHP56_EXT=lang/php56-extensions
PORT_PHP70=lang/php70
PORT_PHP70_EXT=lang/php70-extensions
PORT_MOD_PHP55=www/mod_php55
PORT_MOD_PHP56=www/mod_php56
PORT_MOD_PHP70=www/mod_php70

PORT_PHPMYADMIN=databases/phpmyadmin
PORT_IONCUBE=devel/ioncube
PORT_SUHOSIN=security/suhosin
# PORT_PCRE=devel/pcre

## Ports: Mail & Related Services
PORT_EXIM=mail/exim
PORT_SPAMASSASSIN=mail/spamassassin
PORT_SPAMASSASSIN_UTILITIES=mail/sa-utils
PORT_DOVECOT2=mail/dovecot2
PORT_PIGEONHOLE=mail/dovecot2-pigeonhole
PORT_CLAMAV=security/clamav
PORT_ROUNDCUBE=mail/roundcube
# PORT_MAILMAN=mail/mailman
PORT_LIBSPF2=mail/libspf2
PORT_LIBDKIM=mail/libdkim

## Ports: FTPd
PORT_PUREFTPD=ftp/pure-ftpd
PORT_PROFTPD=ftp/proftpd
PORT_PROFTPD_CLAMAV=security/proftpd-mod_clamav

## Ports: Database Servers
PORT_MYSQL55=databases/mysql55-server
PORT_MYSQL56=databases/mysql56-server
PORT_MYSQL57=databases/mysql57-server
PORT_MARIADB55=databases/mariadb55-server
PORT_MARIADB100=databases/mariadb100-server

## Ports: Database Clients
PORT_MYSQL55_CLIENT=databases/mysql55-client
PORT_MYSQL56_CLIENT=databases/mysql56-client
PORT_MYSQL57_CLIENT=databases/mysql56-client
PORT_MARIADB55_CLIENT=databases/mariadb55-client
PORT_MARIADB100_CLIENT=databases/mariadb100-client

## Ports: Web Stats
PORT_AWSTATS=www/awstats
PORT_WEBALIZER=www/webalizer

################################################################################################################################

###
### make.conf
###

### Global (default) make options

# DEFAULT_VERSIONS= apache=2.4 php=56
# APACHE_PORT= www/apache24
# USE_APACHE=24
# DEFAULT_PHP_VER=56
# PHP1_VER=56

## These variables are included every time 'make' is called. Default is to source /etc/make.conf.
GLOBAL_MAKE_VARIABLES="" # e.g. WITH_OPENSSL_PORT=YES BATCH=YES WITH_CCACHE_BUILD=YES

## These options are included every time a Port is built via 'make'.
GLOBAL_MAKE_SET=""
GLOBAL_MAKE_UNSET="" # EXAMPLES X11 HTMLDOCS CUPS TESTS DOCS NLS

APACHE24_MAKE_SET="SUEXEC MPM_EVENT"
APACHE24_MAKE_UNSET="MPM_PREFORK"

## Todo: Harden symlinks patch?
# APACHE24_EXTRA_PATCHES=""

NGINX_MAKE_SET=""
NGINX_MAKE_UNSET=""

PHP55_MAKE_SET="" # MAILHEAD
PHP55_MAKE_UNSET=""
PHP55_EXT_MAKE_SET="BCMATH BZ2 CALENDAR CTYPE CURL DOM EXIF FILEINFO FILTER FTP GD GETTEXT HASH ICONV IMAP JSON MBSTRING MCRYPT MYSQL MYSQLI OPCACHE OPENSSL PDF PDO PDO_MYSQL PDO_SQLITE PHAR POSIX PSPELL READLINE RECODE SESSION SIMPLEXML SOAP SOCKETS SQLITE3 TOKENIZER WDDX XML XMLREADER XMLRPC XMLWRITER XSL ZIP ZLIB"
PHP55_EXT_MAKE_UNSET=""

PHP56_MAKE_SET="" # MAILHEAD
PHP56_MAKE_UNSET=""
PHP56_EXT_MAKE_SET="BCMATH BZ2 CALENDAR CTYPE CURL DOM EXIF FILEINFO FILTER FTP GD GETTEXT HASH ICONV IMAP JSON MBSTRING MCRYPT MYSQL MYSQLI OPCACHE OPENSSL PDF PDO PDO_MYSQL PDO_SQLITE PHAR POSIX PSPELL READLINE RECODE SESSION SIMPLEXML SOAP SOCKETS SQLITE3 TOKENIZER WDDX XML XMLREADER XMLRPC XMLWRITER XSL ZIP ZLIB"
PHP56_EXT_MAKE_UNSET=""

PHP70_MAKE_SET=""
PHP70_MAKE_UNSET=""
PHP70_EXT_MAKE_SET="BCMATH BZ2 CALENDAR CTYPE CURL DOM EXIF FILEINFO FILTER FTP GD GETTEXT HASH ICONV IMAP INTL JSON MBSTRING MCRYPT MYSQLI OPCACHE OPENSSL PDF PDO PDO_MYSQL PDO_SQLITE PHAR POSIX PSPELL READLINE RECODE SESSION SIMPLEXML SOAP SOCKETS SQLITE3 TOKENIZER WDDX XML XMLREADER XMLRPC XMLWRITER XSL ZIP ZLIB"
PHP70_EXT_MAKE_UNSET=""

## Todo/Untested: Prefixes for multi-PHP installations:
PHP55_PREFIX=/usr/local/php55
PHP56_PREFIX=/usr/local/php56
PHP70_PREFIX=/usr/local/php70

MOD_PHP55_MAKE_SET="" # MAILHEAD  AP2FILTER
MOD_PHP55_MAKE_UNSET=""
MOD_PHP56_MAKE_SET="" # MAILHEAD
MOD_PHP56_MAKE_UNSET=""
MOD_PHP70_MAKE_SET=""
MOD_PHP70_MAKE_UNSET=""

ROUNDCUBE_MAKE_SET="" # SSL
ROUNDCUBE_MAKE_UNSET=""

PMA_MAKE_SET=""
PMA_MAKE_UNSET=""

EXIM_MAKE_SET="DMARC SPF SA_EXIM SRS" # DCC MILTER
EXIM_MAKE_UNSET=""

SPAMASSASSIN_MAKE_SET="DKIM SPF_QUERY" # DCC PYZOR RAZOR RELAY_COUNTRY
SPAMASSASSIN_MAKE_UNSET=""

SPAMASSASSIN_UTILITIES_MAKE_SET="SACOMPILE"
SPAMASSASSIN_UTILITIES_MAKE_UNSET=""

DOVECOT2_MAKE_SET="" #
DOVECOT2_MAKE_UNSET=""

CLAMAV_MAKE_SET="" # MILTER
CLAMAV_MAKE_UNSET=""

PROFTPD_MAKE_SET=""
PROFTPD_MAKE_UNSET=""

PUREFTPD_MAKE_SET="UPLOADSCRIPT LARGEFILE" # PERUSERLIMITS THROTTLING
PUREFTPD_MAKE_UNSET=""

# MARIADB55_MAKE_SET=""
# MARIADB55_MAKE_UNSET=""
# MARIADB100_MAKE_SET=""
# MARIADB100_MAKE_UNSET=""
# MYSQL55_MAKE_SET=""
# MYSQL55_MAKE_UNSET=""
# MYSQL56_MAKE_SET=""
# MYSQL56_MAKE_UNSET=""
# MYSQL57_MAKE_SET=""
# MYSQL57_MAKE_UNSET=""

################################################################################################################################

# if [ ! -f options.conf ]; then
# # recreate them # exit;
# fi


## See if IPV6 is enabled in DirectAdmin:
IPV6_ENABLED=0
if [ -e "${DA_BIN}" ]; then
  IPV6_ENABLED=$(${DA_BIN} c | grep -m1 '^ipv6=' | cut -d= -f2)
fi

## Verify:
## OPT_WITH_OPENSSL_PORT=$(sysrc -n -f /etc/make.conf WITH_OPENSSL_PORT)

## Use either BASE or PORT OpenSSL libraries.
## The latter only if make.conf contains WITH_OPENSSL_PORT=YES
if [ -x /usr/local/bin/openssl ] && [ "$(uc "$(getVal WITH_OPENSSL_PORT /etc/make.conf)")" = "YES" ]; then
  OPENSSL_BIN=/usr/local/bin/openssl
  # GLOBAL_MAKE_VARIABLES="${GLOBAL_MAKE_VARIABLES} WITH_OPENSSL_PORT=YES"
elif [ -x /usr/bin/openssl ]; then
  OPENSSL_BIN=/usr/bin/openssl
  # GLOBAL_MAKE_VARIABLES="${GLOBAL_MAKE_VARIABLES} WITH_OPENSSL_BASE=YES"
fi

## Verify:
## Check for this file and append to OpenSSL calls using -config:
# OPENSSL_EXTRA="-config ${PB_PATH}/custom/ap2/cert_config.txt"
# -config ${PB_PATH}/custom/ap2/cert_config.txt
OPENSSL_EXTRA=""

################################################################################################################################

## Source (include) additional files into the script:
. options.conf

################################################################################################################################

## Get DirectAdmin Option Values (copied from CB2)
## Retrieves values from directadmin/conf/options.conf
getDA_Opt() {
  ## $1 is option name
  ## $2 is default value

  ## Make sure directadmin.conf exists and is greater than zero bytes.
  if [ ! -s "${DA_CONF_FILE}" ]; then
    echo "$2"
    return
  fi

  ## Check for value in ./directadmin c
  if ! "${DA_BIN}" c | grep -m1 -q -e "^$1="; then
    echo "$2"
    return
  fi

  ## Retrieve DirectAdmin's default value:
  ${DA_BIN} c | grep -m1 "^$1=" | cut -d= -f2
}

################################################################################################################################

## Emulate ${!variable} (copied from CB2)
eval_var() {
  var=${1}
  if [ -z "${var}" ]; then
    echo ""
  else
    eval newval="\$${var}"
    echo "${newval}"
  fi
}

################################################################################################################################

## Get Option (copied from CB2)
## Used to retrieve CB options.conf
getOpt() {
  ## $1 = option name
  ## $2 = default value

  ## CB2: Added "grep -v" to workaround many lines with empty options
  GET_OPTION=$(grep -v "^$1=$" "${OPTIONS_CONF}" | grep -m1 "^$1=" | cut -d= -f2)
  if [ "${GET_OPTION}" = "" ]; then
    echo "$1=$2" >> "${OPTIONS_CONF}"
  fi

  echo "${GET_OPTION}"
}

################################################################

## Set Option (copied from CB2)
## Used to manipulate CB options.conf
setOpt() {
  ## $1 = option name
  ## $2 = value
  ## PB Note: no eval_var

  ## Option Validation
  VAR=$(echo "$1" | tr "'a-z'" "'A-Z'")
  if [ -z "$(eval_var ${VAR}_DEF)" ]; then
    echo "${1} is not a valid option."
    #EXIT_CODE=50
    return
  fi

  VALID="no"
  ## Revalidate by asking user
  for i in $(eval_var "${VAR}_SET"); do
    if [ "${i}" = "${2}" ] || [ "${i}" = "userinput" ]; then
      VALID="YES"
      break
    fi
  done

  ## Invalid option
  if [ "${VALID}" = "no" ]; then
    echo "${2} is not a valid setting for ${1} option."
    #EXIT_CODE=51
    return
  fi

  OPT_VALUE=$(grep -m1 "^$1=" "${PB_CONF}" | cut -d= -f2)
  ${PERL} -pi -e "s#$1=${OPT_VALUE}#$1=$2#" "${PB_CONF}"
}

################################################################################################################################

## Set Value ($1) to ($2) in file ($3) (copied from CB2)
## (might deprecate this with sysrc as a replacement)
setVal() {
  ## Check if file exists.
  if [ ! -e "$3" ]; then
    return
  fi

  ## Can't put [brackets] around the statement else grep flips out.
  if ! grep -m1 -q "${1}"= "${3}" ; then
    ## It's not there, so add it.
    echo "$1=$2" >> "$3"
    return
  else
    ## The value is already in the file $3, so use perl regex to replace it.
    ${PERL} -pi -e "s/$(grep "${1}"= "${3}")/${1}=${2}/" "${3}"
  fi
}

################################################################

## Get Value ($1) from file ($2)
## (might deprecate this with sysrc as a replacement)
getVal() {
  ## $1 = option
  ## $2 = file to parse

  ## Returns 0 if option is undefined (doesn't exist or blank)

  ## Check if file exists:
  if [ ! -e "$2" ]; then
    return
  fi

  GET_VALUE=$(grep -v "^$1=$" "$2" | grep -m1 "^$1=" | cut -d= -f2 | tr -d '"')
  if [ "${GET_VALUE}" = "" ]; then
    echo "0"
    #GET_VALUE=0
    return
  else
    echo "${GET_VALUE}"
    return
  fi

  #echo "${GET_VALUE}"

  return
}

################################################################################################################################

## Used to set values ON/OFF in the services.status (copied from CB2)
## set_service name ON|OFF|delete
set_service() {
  if [ ! -e ${DA_SERVICES} ]; then
    return
  fi

  SERVICE_COUNT=$(grep -m1 -c "^$1=" ${DA_SERVICES})

  if [ "$2" = "delete" ]; then
    if [ "${SERVICE_COUNT}" -eq 0 ]; then
      return
    else
      perl -pi -e "s/^${1}=.*\n//" ${DA_SERVICES}
    fi
    return
  fi

  if [ "$2" = "ON" ] || [ "$2" = "OFF" ]; then
    if [ "${SERVICE_COUNT}" -eq 0 ]; then
      echo "$1=$2" >> ${DA_SERVICES}
    else
      perl -pi -e "s/^$1=.*/$1=$2/" ${DA_SERVICES}
    fi

    return
  fi

  echo "setService $1: unknown option: $2"
}

################################################################################################################################

## Get File from PB Mirror
# e.g. getFile configure/proftpd/proftpd.conf ${PROFTPD_CONF}
getfile() {
  ## $2 = source (input, from PB mirror)
  ## $3 = target (output)
  ## $4 = (optional)

  "${WGET}" "${WGET_CONNECT_OPTIONS}" -O "${3}" "${PB_MIRROR}/${2}"

  return
}
################################################################################################################################

## Convert string to lowercase
lc() {
  local char="$*"
  out=$(echo $char | tr [:upper:] [:lower:])
  local retval=$?
  echo "$out"
  unset out
  unset char
  return $retval
}

## Convert string to uppercase
uc() {
  local char="$*"
  out=$(echo $char | tr [:lower:] [:upper:])
  local retval=$?
  echo "$out"
  unset out char
  return $retval
}

################################################################################################################################

## Ask User a Question
ask_user() {
  ## $1 = question string
  ## not done: $2 = expected answer: "yn", "custom", etc. (optional)
  ## not done: $3 = execute command (optional)

  RESPONSE=""

  if [ "${1}" = "" ]; then
    ASK_QUESTION="Do you want to continue?"
  else
    ASK_QUESTION=${1}
  fi

  while true; do
    read -p "${ASK_QUESTION} (y/n): " -r RESPONSE
    case $RESPONSE in
      [Yy]* ) return 1; break ;;
      [Nn]* ) return 0; break ;;
      * ) echo "Please answer with Yes or No." ;;
    esac
  done
}

################################################################################################################################

## pkg update
pkg_update() {
  echo "Updating FreeBSD packages index"
  ${PKG} update
}

################################################################

## Install packages without prompts
pkgi() {
  ${PKG} install -y "$@"
}

################################################################

## Update /usr/ports
ports_update() {
  echo "Updating /usr/ports"
  ${PORTSNAP} fetch update
}

################################################################

## Todo: Rinse & Repeat
## (Need to work with eval)
make_install_clean() {
  ## $1 = category?
  ## $2 = port?

  ## Origin: category/portname
  CHOSEN_PORT=$1

  # if [ options_set blank] && [ options_unset blank ]; then
  # # install via pkg
  # pkg install -y ${CHOSEN_PORT}
  # elif
  # # install via ports:

  ## /usr/bin/make
  make -DNO_DIALOG -C "${PORTS_BASE}/${CHOSEN_PORT}" rmconfig
  make -DNO_DIALOG -C "${PORTS_BASE}/${CHOSEN_PORT}" OPTIONS_SET="${_MAKE_SET}" OPTIONS_UNSET="${_MAKE_UNSET}" reinstall clean
  # fi
}

################################################################

## Clean stale ports (deprecate soon)
clean_stale_ports() {
  echo "Cleaning stale ports"
  ${PORTMASTER} -s
}

################################################################

## Reinstall all ports "in place" (deprecate soon)
## Todo: migrate this process to synth
reinstall_all_ports() {
  ## Consider -R
  ${PORTMASTER} -a -f -d

  ## Synth command
  # synth upgrade-system
}

################################################################

## Update /etc/hosts
update_hosts() {
  COUNT=$(grep 127.0.0.1 /etc/hosts | grep -c localhost)
  if [ "$COUNT" -eq 0 ]; then
    echo "Updating /etc/hosts"
    printf "127.0.0.1\t\tlocalhost" >> /etc/hosts
  fi
}

################################################################

## Backup a file before performing an operation.
backup_file() {
  return
}

################################################################################################################################

## Get System Timezone (copied from CB2)
getTimezone() {
  if [ -d /usr/share/zoneinfo ] && [ -e /etc/localtime ]; then
    MD5_LOCALTIME=$(md5 /etc/localtime | awk '{print $4}')
    # we don't use 'grep -m1' here to fix: "xargs: md5: terminated with signal 13; aborting"
    DATETIMEZONE=$(find /usr/share/zoneinfo -type f -print0 | xargs -0 md5 | grep "${MD5_LOCALTIME}" | awk '{print $2}' | cut -d\( -f2 | cut -d\) -f1 | perl -p0 -e 's#/usr/share/zoneinfo/##')
  fi

  if [ "${DATETIMEZONE}" = "" ]; then
    DATETIMEZONE="America/Toronto"
  fi

  echo ${DATETIMEZONE}
}

################################################################################################################################

## Add (new) User to (new) Group (copied from CB2)
addUserGroup() {
  ## $1 = user
  ## $2 = group

  if ! /usr/bin/grep -q "^${2}:" < /etc/group; then
    /usr/sbin/pw groupadd "${2}"
  fi
  if ! /usr/bin/id "${1}" > /dev/null; then
    /usr/sbin/pw useradd -g "${2}" -n "${1}" -s /sbin/nologin
  fi
}

################################################################################################################################

## Random Password Generator (from CB2)
random_pass() {
  ## $1 = length (default: 12)

  if [ "$1" = "" ]; then
    MIN_PASS_LENGTH=12
  else
    MIN_PASS_LENGTH=$1
  fi

  ${PERL} -le"print map+(A..Z,a..z,0..9)[rand 62],0..${MIN_PASS_LENGTH}"
}

################################################################################################################################

## Setup PortsBuild and DirectAdmin
## Possible arguments: <USER_ID> <LICENSE_ID> <SERVER_HOSTNAME> <ETH_DEV> (<IP_ADDRESS>)"
global_setup() {
  ## $1 = setup
  ## $2 = user_id
  ## $3 = license_id
  ## $4 = server_hostname
  ## $5 = eth_dev
  ## $6 = ip_address
  ## $7 = ip_netmask

  if [ "${DA_ADMIN_EMAIL}" = "" ]; then
    DA_ADMIN_EMAIL="${DA_ADMIN_USERNAME}@${SERVER_DOMAIN}"
  fi

  ## Make sure all inputs are entered (get rid of IP?)
  if [ "${1}" = "" ] || [ "${2}" = "" ] || [ "${3}" = "" ] || [ "${4}" = "" ] || [ "${5}" = "" ] || [ "${6}" = "" ] || [ "${7}" = "" ]; then
    show_menu_setup
    return
  else
    DA_USER_ID=$2
    DA_LICENSE_ID=$3
    DA_SERVER_HOSTNAME=$4
    ETHERNET_DEV=$5
    DA_SERVER_IP=$6
    DA_SERVER_IP_MASK=$7
  fi

  printf "Setup arguments received:\n User ID: %s\n License ID: %s\n Hostname: %s\n Ethernet Device: %s\n Server IP Address: %s\n Server IP Netmask: %s\n\n" $2 $3 $4 $5 $6 $7

  echo "Please make sure these values are correct and that they match the records in your DirectAdmin Client License Portal."
  echo "If in doubt, visit: https://www.directadmin.com/clients/"
  echo ""
  echo "About to setup PortsBuild and install DirectAdmin for the first time."
  echo "This will install, setup and configure the following services:"
  ## Todo: Process chosen options

  printf "  DirectAdmin"
  if [ "${OPT_NAMED}" = "YES" ]; then ( printf ", Named" ); fi
  if [ "${OPT_EXIM}" = "YES" ]; then ( printf ", Exim" ); fi
  if [ "${OPT_DOVECOT}" = "YES" ]; then ( printf ", Dovecot" ); fi
  if [ "${OPT_WEBSERVER}" = "apache" ]; then ( printf ", Apache" ); else ( printf ", Nginx"); fi
  if [ "${OPT_PHP1_MODE}" != "NO" ]; then ( printf ", %s %s" "${OPT_PHP1_MODE}" "${OPT_PHP1_VERSION}" ); fi
  if [ "${OPT_SQL_DB}" != "NO" ]; then ( printf ", %s" "${OPT_SQL_DB}" ); fi
  if [ "${OPT_PHPMYADMIN}" = "YES" ]; then ( printf ", phpMyAdmin" ); fi
  if [ "${OPT_ROUNDCUBE}" = "YES" ]; then ( printf ", RoundCube" ); fi
  if [ "${OPT_SPAMASSASSIN}" = "YES" ]; then ( printf ", SpamAssassin" ); fi
  if [ "${OPT_CLAMAV}" = "YES" ]; then ( printf ", ClamAV" ); fi
  if [ "${OPT_FTPD}" != "NO" ]; then ( printf ", %s" "${OPT_FTPD}" ); fi
  printf "\n"

  printf "The following features will be enabled: \n  "
  if [ "${OPT_CLAMAV_WITH_EXIM}" = "YES" ]; then ( printf "Exim w/ClamAV" ); fi
  if [ "${OPT_BLOCKCRACKING}" = "YES" ]; then ( printf ", BlockCracking" ); fi
  if [ "${OPT_EASY_SPAM_FIGHTER}" = "YES" ]; then ( printf ", Easy Spam Fighter" ); fi
  if [ "${OPT_SPAMASSASSIN_UTILITIES}" = "YES" ]; then ( printf ", SpamAssassin Utilities" ); fi
  if [ "${OPT_AWSTATS}" = "YES" ]; then ( printf ", Awstats" ); fi
  if [ "${OPT_WEBALIZER}" = "YES" ]; then ( printf ", Webalizer" ); fi
  if [ "${OPT_PROFTPD_UPLOADSCAN}" = "YES" ]; then ( printf ", ProFTPD w/ Upload Scanning" ); fi
  if [ "${OPT_PUREFTPD_UPLOADSCAN}" = "YES" ]; then ( printf ", PureFTPD w/ Upload Scanning" ); fi
  if [ "${OPT_SUHOSIN}" = "YES" ]; then ( printf ", Suhosin" ); fi
  if [ "${OPT_SUHOSIN_UPLOADSCAN}" = "YES" ]; then ( printf ", Suhosin w/ Upload Scanning" ); fi
  if [ "${OPT_MODSECURITY}" = "YES" ]; then ( printf ", ModSecurity" ); fi

  # echo "PHP ini Type: ${OPT_PHP_INI_TYPE}"
  # echo "Webapps Inbox Prefix: ${OPT_WEBAPPS_INBOX_PREFIX}"
  # echo "Spam Inbox Prefix: ${OPT_SPAM_INBOX_PREFIX}"
  # echo "Majordomo: ${OPT_MAJORDOMO}"
  # echo "Install CCache: ${OPT_INSTALL_CCACHE}"
  # echo "Install Synth: ${OPT_INSTALL_SYNTH}"

  printf "\n"

  ask_user "Do you want to continue?"

  ## Let's go! ##

  if [ $? -eq 1 ]; then
    echo "Bootstrapping and updating pkg"
    /usr/bin/env ASSUME_ALWAYS_YES=YES pkg bootstrap

    pkg_update

    if [ ! -d "${PORTS_BASE}/" ]; then
      echo "Setting up /usr/ports for the first time"
      ${PORTSNAP} fetch extract
    fi

    ports_update

    ## Install Dependencies (replace with $PORT_*)
    echo "Installing required dependencies"
    if [ "${OS_MAJ}" -eq 10 ]; then
      /usr/sbin/pkg install -y devel/gmake lang/perl5.20 ftp/wget devel/bison textproc/flex graphics/gd security/cyrus-sasl2 devel/cmake lang/python devel/autoconf devel/libtool archivers/libarchive mail/mailx dns/bind99
    elif [ "${OS_MAJ}" -eq 9 ]; then
      /usr/sbin/pkg install -y devel/gmake lang/perl5.20 ftp/wget devel/bison textproc/flex graphics/gd security/cyrus-sasl2 devel/cmake lang/python devel/autoconf devel/libtool archivers/libarchive mail/mailx
    fi

    ## Install Compat Libraries
    echo "Installing misc/compats"
    if [ "${OS_MAJ}" -eq 10 ]; then
      /usr/sbin/pkg install -y misc/compat4x misc/compat5x misc/compat6x misc/compat8x misc/compat9x
    elif [ "${OS_MAJ}" -eq 9 ]; then
      /usr/sbin/pkg install -y misc/compat4x misc/compat5x misc/compat6x misc/compat8x
    fi

    ## Check for /etc/rc.conf
    if [ ! -e /etc/rc.conf ]; then
      echo "Creating /etc/rc.conf"
      touch /etc/rc.conf
    fi

    ## Check for /etc/make.conf
    if [ ! -e /etc/make.conf ]; then
      echo "Creating /etc/make.conf"
      touch /etc/make.conf
    fi

    if [ "${OPT_INSTALL_CCACHE}" = "YES" ]; then
      echo "Installing devel/ccache"
      pkgi ${PORT_CCACHE}

      if [ $? = 0 ]; then
        sysrc -f /etc/make.conf WITH_CCACHE_BUILD=yes
      fi
    fi

    echo "Installing ${PORT_PORTMASTER}"
    pkgi ${PORT_PORTMASTER}

    ## Install Synth (https://github.com/jrmarino/synth)
    ## Successor to portmaster
    ## Usage examples:
    ##  synth just-build editors/joe editors/nano editors/libreoffice
    ##  synth just-build /tmp/build.list
    ##  synth upgrade-system
    ##  synth prepare-system

    if [ "${OPT_INSTALL_SYNTH}" = "YES" ]; then
      echo "Installing ports-mgmt/synth"
      /usr/sbin/pkg install -y lang/gcc6-aux devel/ncurses

      if [ ! -e /usr/local/bin/synth ]; then
        cd /usr/ports/ports-mgmt/synth && make install clean
      fi

      ## Todo: Configure synth (copy Live system profile?)
      # synth configure
    fi

    ## Symlink Perl for DA compat
    echo "Pre-Install Task: checking for /usr/bin/perl symlink"
    if [ ! -e /usr/bin/perl ]; then
      if [ -e /usr/local/bin/perl ]; then
        ln -s /usr/local/bin/perl /usr/bin/perl
      else
        pkgi ${PORT_PERL}
        if [ $? -eq 0 ]; then
            ln -s /usr/local/bin/perl /usr/bin/perl
        fi
      fi
    fi

    ## IPV6 settings suggested by DA
    echo "Setting ipv6_ipv4mapping=YES in /etc/rc.conf"
    sysrc ipv6_ipv4mapping="YES"
    sysrc -f /etc/sysctl.conf net.inet6.ip6.v6only=0
    ${SYSCTL} net.inet6.ip6.v6only=0

    ## Disable sendmail if Exim is enabled
    if [ "${OPT_EXIM}" = "YES" ] || [ "${OPT_DISABLE_SENDMAIL}" = "YES" ] ; then
      echo "Disabling sendmail from running (updating /etc/rc.conf)"
      sysrc sendmail_enable="NONE"
      sysrc sendmail_submit_enable="NO"
      sysrc sendmail_outbound_enable="NO"
      sysrc sendmail_msp_queue_enable="NO"

      ${SERVICE} sendmail onestop
    fi

    ## Ethernet Device checking here
    ## Skipping/avoiding this step as it's not that reliable of a process,
    ## especially if you have multiple interfaces.

    ## Make sure sshd is enabled
    echo "Enabling sshd in /etc/rc.conf"
    sysrc sshd_enable="YES"

    ${SERVICE} sshd start

    ## Install and configure services & applications
    if [ "${OPT_NAMED}" = "YES" ]; then ( bind_setup ); fi
    if [ "${OPT_EXIM}" = "YES" ]; then ( exim_install); fi
    if [ "${OPT_MAJORDOMO}" = "YES" ]; then ( majordomo_install); fi
    if [ "${OPT_DOVECOT}" = "YES" ]; then ( dovecot_install ); fi
    if [ "${OPT_WEBSERVER}" = "apache" ]; then ( apache_install ); fi
    if [ "${OPT_PHP1_MODE}" != "NO" ]; then ( php_install ); fi
    if [ "${OPT_SQL_DB}" != "NO" ]; then ( install_app "${OPT_SQL_DB}" ); fi
    if [ "${OPT_PHPMYADMIN}" = "YES" ]; then ( phpmyadmin_install ); fi
    if [ "${OPT_ROUNDCUBE}" = "YES" ]; then ( roundcube_install ); fi
    if [ "${OPT_SPAMASSASSIN}" = "YES" ]; then ( spamassassin_install ); fi
    if [ "${OPT_CLAMAV}" = "YES" ]; then ( clamav_install ); fi
    if [ "${OPT_FTPD}" != "NO" ]; then ( install_app "${OPT_FTPD}" ); fi
    if [ "${OPT_BLOCKCRACKING}" = "YES" ]; then ( blockcracking_install ); fi
    if [ "${OPT_EASY_SPAM_FIGHTER}" = "YES" ]; then ( easyspamfighter_install ); fi

    ## Go for the main attraction
    directadmin_install

    ## Create a spoof CustomBuild2 options.conf for DirectAdmin compatibility.
    if [ ! -d "${CB_PATH}" ]; then
      mkdir -p ${CB_PATH}
    fi

    if [ ! -e "${CB_CONF}" ]; then
      if [ ! -e "${PB_PATH}/custombuild/options.conf" ]; then
        ${WGET} -O ${CB_CONF} "${PB_MIRROR}/custombuild/options.conf"
      else
        cp "${PB_PATH}/custombuild/options.conf" ${CB_CONF}
      fi
    fi

    chown -f diradmin:diradmin ${CB_CONF}
    chmod 755 "${CB_CONF}"

    ## Skiped for now: DirectAdmin Install
    # cd ${DA_PATH} || exit
    # ./directadmin i

    ## Set DirectAdmin Permissions
    cd ${DA_PATH} || exit
    ./directadmin p

    # ${SERVICE} directadmin start

    basic_system_security

    global_post_install

  else
    printf "PortsBuild installation canceled\n\n"
    show_main_menu
  fi
}

## Global Post-Install Tasks
global_post_install() {
  echo "All done!"
  # exit 0
}

################################################################################################################################

## Update System Startup Scripts
## Modifies /etc/rc.conf, /boot/loader.conf, /etc/periodic.conf, etc.
update_rc() {
  ## Go through installed/enabled services and make sure they're all enabled.
  ## Perhaps rename this function to verify_rc?

  ## Todo: refactor with "${SERVICE_NAME}_enable"
  ## Todo: directadmin rc script

  if [ "${OPT_NAMED}" = "YES" ]; then
    sysrc named_enable="YES"
  else
    sysrc -x named_enable
  fi

  if [ "${OPT_WEBSERVER}" = "apache" ]; then
    sysrc apache24_enable="YES"
    sysrc apache24_http_accept_enable="YES"
    sysrc -f /boot/loader.conf accf_http_load="YES"
    sysrc -f /boot/loader.conf accf_data_load="YES"
    sysrc -x nginx_enable
  else
    sysrc -x apache24_enable
    sysrc -x apache24_http_accept_enable
    sysrc -f /boot/loader.conf -x accf_http_load
    sysrc -f /boot/loader.conf -x accf_data_load
  fi

  if [ "${OPT_WEBSERVER}" = "nginx" ]; then
    sysrc nginx_enable="YES"
    sysrc -x apache24_enable
    sysrc -x apache24_http_accept_enable
    sysrc -f /boot/loader.conf -x accf_http_load
    sysrc -f /boot/loader.conf -x accf_data_load
  else
    sysrc -x nginx_enable
  fi

  if [ "${OPT_SQL_DB}" != "NO" ]; then
    sysrc mysql_enable="YES"
    sysrc mysql_dbdir="${SQL_DATA_PATH}"
    sysrc mysql_optfile="/usr/local/etc/my.cnf"
  fi

  if [ "${OPT_PHP1_MODE}" = "php-fpm" ]; then
    sysrc php_fpm_enable="YES"
  else
    sysrc -x php_fpm_enable
  fi

  if [ "${OPT_EXIM}" = "YES" ]; then
    sysrc exim_enable="YES"
    sysrc exim_flags="-bd -q1h"
    sysrc -f /etc/periodic.conf daily_status_include_submit_mailq="NO"
    sysrc -f /etc/periodic.conf daily_clean_hoststat_enable="NO"
  else
    sysrc -x exim_enable
    sysrc -x exim_flags
    sysrc -f /etc/periodic.conf -x daily_status_include_submit_mailq
    sysrc -f /etc/periodic.conf -x daily_clean_hoststat_enable
  fi

  if [ "${OPT_DOVECOT}" = "YES" ]; then
    sysrc dovecot_enable="YES"
  else
    sysrc -x dovecot_enable
  fi

  if [ "${OPT_FTPD}" = "pureftpd" ]; then
    sysrc ftpd_enable="NO"
    sysrc pureftpd_enable="YES"
    sysrc -x proftpd_enable
  else
    sysrc -x pureftpd_enable
  fi

  if [ "${OPT_FTPD}" = "proftpd" ]; then
    sysrc ftpd_enable="NO"
    sysrc proftpd_enable="YES"
    sysrc -x pureftpd_enable
  else
    sysrc -x proftpd_enable
  fi

  if [ "${OPT_SPAMASSASSIN}" = "YES" ]; then
    sysrc spamd_enable="YES"
    sysrc spamd_flags="-c -m 15"
  else
    sysrc -x spamd_enable
    sysrc -x spamd_flags
  fi

  if [ "${OPT_SPAMASSASSIN_UTILITIES}" = "YES" ] && [ "${OPT_SPAMASSASSIN}" = "YES" ]; then
    sysrc -f /etc/periodic.conf daily_sa_enable="YES"
    sysrc -f /etc/periodic.conf daily_sa_quiet="NO"
    sysrc -f /etc/periodic.conf daily_sa_compile_nice="YES"
    sysrc -f /etc/periodic.conf daily_sa_restart_spamd="YES"
    # daily_sa_update_flags="" ## -D --nogpg
    # daily_sa_compile_flags=""
    # daily_sa_compile_nice_flags=""
  else
    sysrc -f /etc/periodic.conf -x daily_sa_enable
    sysrc -f /etc/periodic.conf -x daily_sa_quiet
    sysrc -f /etc/periodic.conf -x daily_sa_compile_nice
    sysrc -f /etc/periodic.conf -x daily_sa_restart_spamd
  fi

  if [ "${OPT_CLAMAV}" = "YES" ]; then
    sysrc clamav_clamd_enable="YES"
    sysrc clamav_freshclam_enable="YES"
  else
    sysrc -x clamav_clamd_enable
    sysrc -x clamav_freshclam_enable
  fi

  return
}

################################################################################################################################

## Setup BIND (named)
bind_setup() {

  if [ "${OPT_NAMED}" != "YES" ]; then
    echo "*** Notice: Skipping named (BIND) DNS setup."
    return
  fi

  ## Todo: change to PB mirrors instead of using github repo for file storage

  if [ "${OS_MAJ}" -eq 10 ]; then
    if [ ! -e /usr/local/sbin/named ]; then
      echo "*** Error: Cannot find the named binary.";
      return
    fi

    if [ ! -e /usr/local/etc/namedb/named.conf ]; then
      echo "*** Warning: Cannot find /usr/local/etc/namedb/named.conf."

      if [ -e "${PB_PATH}/configure/named/named.100.conf" ]; then
        cp "${PB_PATH}/configure/named/named.100.conf" /etc/namedb/named.conf
      else
        ${WGET} -O /var/named/etc/namedb/named.conf ${PB_MIRROR}/configure/named/named.100.conf
      fi
    fi

    if [ ! -e /usr/local/etc/namedb/rndc.key ]; then
      echo "*** Notice: Generating the rndc.key for the first time"
      /usr/local/sbin/rndc-confgen -a -s "${DA_SERVER_IP}"
    fi
  elif [ "$OS_MAJ" -eq 9 ]; then
    if [ ! -e /usr/sbin/named ]; then
      echo "*** Error: Cannot find the named binary."
      return
    fi

    if [ ! -e /var/named/etc/namedb/named.conf ]; then
      echo "*** Warning: Cannot find /var/named/etc/namedb/named.conf."

      if [ -e "${PB_PATH}/configure/named/named.93.conf" ]; then
        cp "${PB_PATH}/configure/named/named.93.conf" /etc/namedb/named.conf
      else
        ${WGET} -O /etc/namedb/named.conf ${PB_MIRROR}/configure/named/named.93.conf
      fi
    fi

    if [ ! -e /etc/namedb/rndc.key ]; then
      echo "*** Notice: Generating the rndc.key for the first time"
      /usr/sbin/rndc-confgen -a -s "${DA_SERVER_IP}"
    fi
  fi

  echo "Updating /etc/rc.conf with named_enable=YES"
  sysrc named_enable="YES"

  echo "Starting named"
  ${SERVICE} named start

  return
}

################################################################################################################################

## DirectAdmin Installation
## Install DirectAdmin (replaces scripts/install.sh)
directadmin_install() {

  ### Pre-Installation Tasks (replaces setup.sh)

  ## 2016-03-07: Need to create a blank /etc/auth.conf file for DA compatibility
  echo "Checking for /etc/auth.conf"
  if [ ! -e /etc/auth.conf ]; then
    /usr/bin/touch /etc/auth.conf
    /bin/chmod 644 /etc/auth.conf
  fi

  ## Update /etc/aliases:
  if [ -e /etc/aliases ]; then
    COUNT=$(grep -c diradmin /etc/aliases)
    if [ "$COUNT" -eq 0 ]; then
      echo "diradmin: :blackhole:" >> /etc/aliases
    fi
    ## Update aliases database
    echo "Updating /etc/aliases"
    /usr/bin/newaliases
  fi

  mkdir -p ${DA_PATH}

  ## Get DirectAdmin binary:
  if [ ! -e "${DA_PATH}/update.tar.gz" ]; then
    if [ "${DA_LAN}" -eq 0 ]; then
      ${WGET} --no-check-certificate -S -O ${DA_PATH}/update.tar.gz --bind-address="${DA_SERVER_IP}" "${HTTP}://www.directadmin.com/cgi-bin/daupdate?uid=${DA_USER_ID}&lid=${DA_LICENSE_ID}"
    elif [ "${DA_LAN}" -eq 1 ]; then
      ${WGET} --no-check-certificate -S -O ${DA_PATH}/update.tar.gz "${HTTP}://www.directadmin.com/cgi-bin/daupdate?uid=${DA_USER_ID}&lid=${DA_LICENSE_ID}"
    fi
  fi

  if [ ! -e "${DA_PATH}/update.tar.gz" ]; then
    printf "\n*** Error: Unable to download %s\n" "${DA_PATH}/update.tar.gz"
    exit 3
  fi

  COUNT=$(head -n 4 ${DA_PATH}/update.tar.gz | grep -c "* You are not allowed to run this program *");
  if [ "$COUNT" -ne 0 ]; then
    printf "*** \nError: You are not authorized to download the update package with that Client ID and License ID from this IP address.\n"
    exit 4
  fi

  ## Extract update.tar.gz into /usr/local/directadmin:
  tar xvf ${DA_PATH}/update.tar.gz -C "${DA_PATH}"

  ## See if the binary exists:
  if [ ! -e "${DA_PATH}/directadmin" ]; then
    printf "\n*** Error: Cannot find the DirectAdmin binary. Extraction failed.\n"
    exit 5
  fi

  ## PB: Update addip and startips scripts with improved versions
  if [ ! -e ${DA_PATH}/scripts/custom/addip ]; then
    if [ -e "${PB_PATH}/directadmin/scripts/custom/addip" ]; then
      cp "${PB_PATH}/directadmin/scripts/custom/addip" ${DA_PATH}/scripts/custom/addip
    else
      echo "Downloading missing file"
      ## download file
    fi
  fi

  echo "addip=${DA_PATH}/scripts/custom/addip" >> "${DA_CONF_FILE}"
  echo "addip=${DA_PATH}/scripts/custom/addip" >> "${DA_CONF_TEMPLATE_FILE}"

  ## The following lines were in DA's install/setup do_checks():
  ## Check for a separate /home partition (for quota support)
  HOME_YES=$(grep -c /home < /etc/fstab)
  if [ "$HOME_YES" -lt "1" ]; then
    echo "quota_partition=/" >> ${DA_CONF_TEMPLATE_FILE}
  fi

  ## Detect the ethernet interfaces that are available on the system (or use the one supplied by the user)
  ## NOTE: can return more than 1 interface (even ones commented out) from /etc/rc.conf
  if [ ! -e "${ETHERNET_DEV}" ]; then
    ETH_DEV="$(grep ifconfig < /etc/rc.conf | cut -d= -f1 | cut -d_ -f2)"
    if [ "$ETH_DEV" != "" ]; then
      COUNT=$(grep -c ethernet_dev < $DA_CONF_TEMPLATE_FILE)
      if [ "$COUNT" -eq 0 ]; then
        echo "ethernet_dev=${ETH_DEV}" >> ${DA_CONF_TEMPLATE_FILE}
      fi
    fi
  fi

  # DB_ROOT_PASS=`perl -le'print map+(A..Z,a..z,0..9)[rand 62],0..7'`;
  DA_SQLDB_PASSWORD=$(random_pass)
  DA_ADMIN_PASSWORD=$(random_pass)

  ## From DA/setup.sh: generate setup.txt
  {
    echo "hostname=${SERVER_FQDN}"
    echo "email=${DA_ADMIN_USERNAME}@${SERVER_DOMAIN}"
    echo "mysql=${DA_SQLDB_PASSWORD}"
    echo "mysqluser=${DA_SQLDB_USERNAME}"
    echo "adminname=${DA_ADMIN_USERNAME}"
    echo "adminpass=${DA_ADMIN_PASSWORD}"
    echo "ns1=ns1.${SERVER_DOMAIN}"
    echo "ns2=ns2.${SERVER_DOMAIN}"
    echo "ip=${DA_SERVER_IP}"
    echo "netmask=${DA_SERVER_IP_MASK}"
    echo "uid=${DA_USER_ID}"
    echo "lid=${DA_LICENSE_ID}"
    echo "services=${DA_FREEBSD_SERVICES}"
  } > "${DA_SETUP_TXT}"

  chmod 600 "${DA_SETUP_TXT}"

  ## Add the DirectAdmin user & group:
  /usr/sbin/pw groupadd diradmin 2>&1
  /usr/sbin/pw useradd -g diradmin -n diradmin -d ${DA_PATH} -s /sbin/nologin 2>&1

  ## Mail User & Group creation
  ## NOTE: FreeBSD already comes with a "mail" group (ID: 6) and a "mailnull" user (ID: 26)
  /usr/sbin/pw groupadd mail 2> /dev/null
  /usr/sbin/pw useradd -g mail -u 12 -n mail -d /var/mail -s /sbin/nologin 2> /dev/null

  ## NOTE: FreeBSD already includes a "ftp" group (ID: 14)
  # /usr/sbin/pw groupadd ftp 2> /dev/null
  # /usr/sbin/pw useradd -g ftp -n ftp -s /sbin/nologin 2> /dev/null

  ## Apache user/group creation (changed /var/www to /usr/local/www)
  ## NOTE: Using "apache" user instead of "www" for now
  /usr/sbin/pw groupadd apache 2> /dev/null
  /usr/sbin/pw useradd -g apache -n apache -d ${WWW_DIR} -s /sbin/nologin 2> /dev/null

  ## Set DirectAdmin Folder permissions:
  chmod -f 755 ${DA_PATH}
  chown -f diradmin:diradmin ${DA_PATH}

  ## Create directories and set permissions:
  mkdir -p /var/log/directadmin
  mkdir -p ${DA_PATH}/conf

  chown -f diradmin:diradmin ${DA_PATH}/*
  chown -f diradmin:diradmin /var/log/directadmin
  chmod -f 700 ${DA_PATH}/conf
  chmod -f 700 /var/log/directadmin

  #mkdir -p ${DA_PATH}/scripts/packages
  mkdir -p ${DA_PATH}/data/admin

  ## Set permissions
  chown -R diradmin:diradmin ${DA_PATH}/scripts/
  chown -R diradmin:diradmin ${DA_PATH}/data/

  ## No conf files in a fresh install:
  chown -f diradmin:diradmin ${DA_PATH}/conf/* 2> /dev/null > /dev/null
  chmod -f 600 ${DA_PATH}/conf/* 2> /dev/null > /dev/null

  ## Create logs directory:
  mkdir -p /var/log/httpd/domains
  chmod 700 /var/log/httpd

  ## NOTE: /home => /usr/home
  mkdir -p /home/tmp
  chmod -f 1777 /home/tmp
  chmod 711 /home

  ## PB: Create User and Reseller Welcome message (need to download/copy these files):
  ## 2016-03-22: Needed?
  # touch ${DA_PATH}/data/users/admin/u_welcome.txt
  # touch ${DA_PATH}/data/admin/r_welcome.txt

  ## PB: Create backup.conf (wasn't created? need to verify)
  # chown -f diradmin:diradmin ${DA_PATH}/data/users/admin/backup.conf

  SSHROOT=$(grep -c 'AllowUsers root' < /etc/ssh/sshd_config)
  if [ "${SSHROOT}" = 0 ]; then
    echo "*** Notice: Adding the 'root' user to the sshd configuration's AllowUsers list."
    {
      echo "AllowUsers root"
      echo "AllowUsers ${DA_ADMIN_USERNAME}"
      echo "AllowUsers $(logname)"
      ## echo "AllowUsers YOUR_OTHER_ADMIN_ACCOUNT" >> /etc/ssh/sshd_config
    } >> /etc/ssh/sshd_config

    ## Set SSH folder permissions (needed?):
    chmod 710 /etc/ssh
  fi

  ## Download DirectAdmin License file (untested)
  if [ ! -e "${DA_LICENSE_FILE}" ]; then
    ${WGET} "${HTTP}://www.directadmin.com/cgi-bin/licenseupdate?lid=${DA_LICENSE_ID}\&uid=${DA_LICENSE_ID}${EXTRA_VALUE}" -O "${DA_LICENSE_FILE}" "${BIND_ADDRESS}"

    if [ $? -ne 0 ]; then
      echo "*** Error: Unable to download the DirectAdmin license file."
      da_myip
      echo "Trying the license relay server..."

      ${WGET} "${HTTP}://license.directadmin.com/licenseupdate.php?lid=${DA_LICENSE_ID}\&uid=${DA_LICENSE_ID}${EXTRA_VALUE}" -O "${DA_LICENSE_FILE}" "${BIND_ADDRESS}"

      if [ $? -ne 0 ]; then
        echo "*** Error: Unable to download the DirectAdmin license file from relay server as well."
        da_myip
        exit 2
      fi
    fi

    COUNT=$(grep -c "* You are not allowed to run this program *" ${DA_LICENSE_FILE})
    if [ "${COUNT}" -ne 0 ]; then
      echo "*** Error: You are not authorized to download the DirectAdmin license"
      echo "           with that Client ID and License ID (and/or IP address)."
      echo "           Please email sales@directadmin.com"
      echo ""
      echo "If you are having connection issues, please see this guide:"
      echo "    http://help.directadmin.com/item.php?id=30"
      echo ""
      da_myip
      exit 3
    fi
  fi

  ## Set permissions on license.key
  chmod 600 ${DA_LICENSE_FILE}
  chown diradmin:diradmin ${DA_LICENSE_FILE}

  ## DirectAdmin Post-Installation Tasks
  mkdir -p ${DA_PATH}/data/users/admin/packages
  chown diradmin:diradmin ${DA_PATH}/data/users/admin/packages
  chmod 700 ${DA_PATH}/data/users/admin/packages

  return
}

################################################################

## Copied from DA/scripts/getLicense.sh
da_myip() {
  IP=$(${WGET} "${BIND_ADDRESS}" -qO - "${HTTP}://myip.directadmin.com")

  if [ "${IP}" = "" ]; then
    echo "*** Error: Cannot determine the server's IP address via myip.directadmin.com"
    return
  fi

  echo "IP used to connect out: ${IP}"
}

################################################################

## DirectAdmin Upgrade
directadmin_upgrade() {
  return
}

## DirectAdmin Restart
directadmin_restart() {
  echo "action=directadmin&value=reload" >> "${DA_TASK_QUEUE}"
  run_dataskq
}

################################################################################################################################

## Basic System Security Tasks
basic_system_security() {
  sysrc -f /etc/sysctl.conf security.bsd.see_other_uids=0
  sysrc -f /etc/sysctl.conf security.bsd.see_other_gids=0
}

################################################################################################################################

## Install DA cron (from: scripts/install.sh)
install_cron() {

  ## Use printf
  # printf "*\t*\t*\*\t*\troot\t/usr/lcoal/directadmin/datasqk" >> /etc/crontab

  ## Need to add:
  # * * * * * root /usr/local/directadmin/dataskq
  # 2 0-23/6 * * * root echo 'action=vacation&value=all' >> /usr/local/directadmin/data/task.queue;
  # 5 0 * * * root /usr/sbin/quotaoff -a; /sbin/quotacheck -aug; /usr/sbin/quotaon -a;
  # 30 0 * * * root echo 'action=tally&value=all' >> /usr/local/directadmin/data/task.queue
  # 40 1 1 * * root echo 'action=reset&value=all' >> /usr/local/directadmin/data/task.queue
  # 0 4 * * * root echo 'action=check&value=license' >> /usr/local/directadmin/data/task.queue

  COUNT=$(grep -c dataskq < /etc/crontab)
  if [ "$COUNT" = 0 ]; then
    if [ -s "${DA_CRON_FILE}" ]; then
      cat "${DA_CRON_FILE}" >> /etc/crontab;
    else
      echo "*** Error: Could not find ${DA_CRON_FILE} or it is empty."
    fi
  fi
}

################################################################################################################################

## Setup newsyslog configuration
## Additional include directories in /etc/newsyslog.conf are:
## <include> /etc/newsyslog.conf.d/*
## <include> /usr/local/etc/newsyslog.conf.d/*
setup_newsyslog() {
  #fix this
  #cp /etc/newsyslog.conf.d/directadmin.conf /usr/local/etc/newsyslog.conf.d/

  ## See what's enabled/installed on the system and update the newsyslog with the appropriate services
  ##

  /usr/sbin/newsyslog
}


################################################################################################################################

## FreeBSD Set NewSyslog (Copied from CB2)
freebsd_set_newsyslog() {
  NSL_L=$1
  NSL_V=$2

  if [ ! -e ${NEWSYSLOG_FILE} ]; then
    touch ${NEWSYSLOG_FILE}
  fi

  if [ ! ${NEWSYSLOG_DAYS} -gt 0 ]; then
    NEWSYSLOG_DAYS=10
  fi

  if ! grep -q "${NSL_L}" "${NEWSYSLOG_FILE}"; then
    printf "%s\t$%s\t600\t%d\t*\t@T00\t-" "${NSL_L}" "${NSL_V}" "${NEWSYSLOG_DAYS}" >> "${NEWSYSLOG_FILE}"
  fi

  #replace whatever we may have with whatever we need, eg:
  #/var/www/html/roundcube/logs/errors  webapps:webapps 600     4       *       @T00    -
  #/var/www/html/roundcube/logs/errors  apache:apache 600     4       *       @T00    -
  #/var/www/html/roundcube/logs/errors      600     4       *       @T00    -

  ${PERL} -pi -e "s|^${NSL_L}\s+webapps:webapps\s+|${NSL_L}\t${NSL_V}\t|" "${NEWSYSLOG_FILE}"
  ${PERL} -pi -e "s|^${NSL_L}\s+apache:apache\s+|${NSL_L}\t${NSL_V}\t|" "${NEWSYSLOG_FILE}"
  ${PERL} -pi -e "s|^${NSL_L}\s+600\s+|${NSL_L}\t${NSL_V}\t600\t|" "${NEWSYSLOG_FILE}"
}

################################################################

## Verify Webapps Log Rotation (copied from CB2)
verify_webapps_logrotate() {

    # By default it sets each log to webapps:webapps.
    # Swap it to apache:apache if needed
    # else swap it to webapps:webapps from apache:apache... or do nothing

    NSL_VALUE=${WEBAPPS_USER}:${WEBAPPS_GROUP}

    if [ "${OPT_PHP1_MODE}" = "mod_php" ]; then
      NSL_VALUE=${APACHE_USER}:${APACHE_GROUP}
    fi

    if [ "${OPT_ROUNDCUBE}" = "YES" ]; then
      freebsd_set_newsyslog "${WWW_DIR}/roundcube/logs/errors" ${NSL_VALUE}
    fi

    if [ "${OPT_SQUIRRELMAIL}" = "YES" ]; then
      freebsd_set_newsyslog "${WWW_DIR}/squirrelmail/data/squirrelmail_access_log" ${NSL_VALUE}
    fi

    if [ "${OPT_PHPMYADMIN}" = "YES" ]; then
      freebsd_set_newsyslog "${WWW_DIR}/phpMyAdmin/log/auth.log" ${NSL_VALUE}
    fi

    return
}

################################################################################################################################

## Exim Installation
exim_install() {

  if [ "${OPT_EXIM}" != "YES" ]; then
    echo "*** Notice: EXIM is disabled in options.conf"
    return
  fi

  ### Main Installation (verify: exim_user/exim_group arguments)
  if [ "${EXIM_MAKE_SET}" = "" ] && [ "${EXIM_MAKE_UNSET}" = "" ] ; then
    pkgi ${PORT_EXIM}
  else
    make -DNO_DIALOG -C "${PORTS_BASE}/${PORT_EXIM}" rmconfig
    make -DNO_DIALOG -C "${PORTS_BASE}/${PORT_EXIM}" mail_exim_SET="${EXIM_MAKE_SET}" mail_exim_UNSET="${EXIM_MAKE_UNSET}" OPTIONS_SET="${GLOBAL_MAKE_SET}" OPTIONS_UNSET="${GLOBAL_MAKE_UNSET}" reinstall clean
  fi
  # EXIM_USER="${EXIM_USER}" EXIM_GROUP="${EXIM_GROUP}"

  ### Pre-Installation Tasks

  ## From: DA's scripts/install.sh
  mkdir -p ${VIRTUAL_PATH}
  chown -f ${EXIM_USER}:${EXIM_GROUP} ${VIRTUAL_PATH}
  chmod 755 ${VIRTUAL_PATH}

  if [ ! -s "${VIRTUAL_PATH}/limit" ]; then
    echo "${LIMIT_DEFAULT}" > "${VIRTUAL_PATH}/limit"
  fi

  if [ ! -s "${VIRTUAL_PATH}/limit_unknown" ]; then
    echo "${LIMIT_UNKNOWN}" > "${VIRTUAL_PATH}/limit_unknown"
  fi

  chmod 755 ${VIRTUAL_PATH}/*
  mkdir ${VIRTUAL_PATH}/usage
  chmod 750 ${VIRTUAL_PATH}/usage

  virtual_files="\
    domains \
    domainowners \
    pophosts \
    blacklist_domains \
    whitelist_from \
    use_rbl_domains \
    bad_sender_hosts \
    bad_sender_hosts_ip \
    blacklist_senders \
    whitelist_domains \
    whitelist_hosts \
    whitelist_hosts_ip \
    whitelist_senders \
    skip_av_domains \
    skip_rbl_domains \
  "

  ## Verify: IFS= modified
  for file in ${virtual_files}; do
    touch "${VIRTUAL_PATH}/${file}"
    chmod 600 "${VIRTUAL_PATH}/${file}"
  done

  ## Todo: add check first before adding 'hostname'
  ## Verify: replace $(hostname)
  hostname >> ${VIRTUAL_PATH}/domains

  chown -f ${EXIM_USER}:${EXIM_GROUP} ${VIRTUAL_PATH}/*

  ### Post-Install Tasks

  ## Set permissions
  chown -R ${EXIM_USER}:${EXIM_GROUP} /var/spool/exim

  ## Symlink for compat:
  ln -s ${EXIM_CONF} /etc/exim.conf

  ## Generate Self-Signed SSL Certificates
  ## See: http://help.directadmin.com/item.php?id=245
  ${OPENSSL_BIN} req -x509 -newkey rsa:2048 -keyout ${EXIM_SSL_KEY} -out ${EXIM_SSL_CRT} -days 9000 -nodes "${OPENSSL_EXTRA}"

  ## Symlink for DA compat:
  ln -s ${EXIM_SSL_KEY} /etc/exim.key
  ln -s ${EXIM_SSL_CRT} /etc/exim.cert

  ## Set permissions:
  chown ${EXIM_USER}:${EXIM_GROUP} ${EXIM_SSL_KEY}
  chmod 644 ${EXIM_SSL_KEY}
  chmod 644 ${EXIM_SSL_CRT}

  ## Reference: Verify Exim config:
  ${EXIM_BIN} -C ${EXIM_CONF} -bV

  ## Update /etc/rc.conf
  echo "Enabling Exim startup (updating /etc/rc.conf)"
  sysrc exim_enable="YES"
  sysrc exim_flags="-bd -q1h"

  if [ ! -e /etc/periodic.conf ]; then
    touch /etc/periodic.conf
  fi

  echo "Updating /etc/periodic.conf"
  sysrc -f /etc/periodic.conf daily_status_include_submit_mailq="NO"
  sysrc -f /etc/periodic.conf daily_clean_hoststat_enable="NO"

  echo "Starting Exim"
  ${SERVICE} exim start

  ## Tel DA new path to Exim binary.
  setVal mq_exim_bin ${EXIM_BIN} ${DA_CONF_FILE}

  ## Todo:
  ## Replace sendmail programs with Exim binaries.
  if [ ! -e /etc/mail/mailer.conf ]; then
    echo "Creating /etc/mail/mailer.conf"
    touch /etc/mail/mailer.conf

    # cp "${PB_PATH}/configure/etc/mailer.93.conf" /etc/mail/mailer.conf
    # cp "${PB_PATH}/configure/etc/mailer.100.conf" /etc/mail/mailer.conf

  # else
    ## Update /etc/mail/mailer.conf:
    #sendmail       /usr/libexec/sendmail/sendmail
    #send-mail      /usr/libexec/sendmail/sendmail
    #mailq          /usr/libexec/sendmail/sendmail
    #newaliases     /usr/libexec/sendmail/sendmail
    #hoststat       /usr/libexec/sendmail/sendmail
    #purgestat      /usr/libexec/sendmail/sendmail

  fi

  {
    printf "%s\t%s\n" "sendmail" "/usr/local/sbin/exim"
    printf "%s\t%s\n" "send-mail" "/usr/local/sbin/exim"
    printf "%s\t%s\n" "mailq" "/usr/local/sbin/exim -bp"
    printf "%s\t%s\n" "newaliases" "/usr/bin/true"
    printf "%s\t%s\n" "rmail" "/usr/local/sbin/exim -i -oee"
  } > /etc/mail/mailer.conf

}

################################################################################################################################

## SpamAssassin Installation Tasks
spamassassin_install() {

  ### Main Installation
  if [ "${SPAMASSASSIN_MAKE_SET}" = "" ] && [ "${SPAMASSASSIN_MAKE_UNSET}" = "" ] ; then
    pkgi ${PORT_SPAMASSASSIN}
  else
    make -DNO_DIALOG -C "${PORTS_BASE}/${PORT_SPAMASSASSIN}" rmconfig
    make -DNO_DIALOG -C "${PORTS_BASE}/${PORT_SPAMASSASSIN}" mail_spamassassin_SET="${SPAMASSASSIN_MAKE_SET}" mail_spamassassin_UNSET="${SPAMASSASSIN_MAKE_UNSET}" OPTIONS_SET="${GLOBAL_MAKE_SET}" OPTIONS_UNSET="${GLOBAL_MAKE_UNSET}" reinstall clean
  fi

  ## SpamAssassin Post-Installation Tasks
  sysrc spamd_enable="YES"
  sysrc spamd_flags="-c -m 15"

  ## Start SpamAssassin
  ${SERVICE} sa-spamd start

  ## Update rules via 'sa-update' (or using sa-utils):
  # sa-update
}

################################################################

## SpamAssassin Utilities Installation Tasks
spamassassin_utilities_install() {

  ### Main Installation
  if [ "${SPAMASSASSIN_UTILITIES_MAKE_SET}" = "" ] && [ "${SPAMASSASSIN_UTILITIES_MAKE_UNSET}" = "" ] ; then
    pkgi ${PORT_SPAMASSASSIN_UTILITIES}
  else
    make -DNO_DIALOG -C "${PORTS_BASE}/${PORT_SPAMASSASSIN_UTILITIES}" rmconfig
    make -DNO_DIALOG -C "${PORTS_BASE}/${PORT_SPAMASSASSIN_UTILITIES}" mail_sa-utils_SET="${SPAMASSASSIN_UTILITIES_MAKE_SET}" mail_sa-utils_UNSET="${SPAMASSASSIN_UTILITIES_MAKE_UNSET}" OPTIONS_SET="${GLOBAL_MAKE_SET}" OPTIONS_UNSET="${GLOBAL_MAKE_UNSET}" reinstall clean
  fi

  ## SpamAssassin Post-Installation Tasks
  # sysrc spamd_enable="YES"
  # sysrc spamd_flags="-c -m 15"

  ## Start SpamAssassin
  # ${SERVICE} sa-spamd start

  ## Update rules via 'sa-update' (or using sa-utils):
  # sa-update
}


################################################################################################################################

## Install Exim BlockCracking (BC)
blockcracking_install() {

  ## Check for Exim
  pkg query %n "exim"

  if [ -x ${EXIM_BIN} ]; then

    echo "Downloading BlockCracking"

    ${WGET} -O "${PB_PATH}/files/exim.blockcracking.tar.gz" "${PB_MIRROR}/files/exim.blockcracking.tar.gz"

    ## used to include: -${BLOCKCRACKING_VER}

    if [ -e "${PB_PATH}/files/exim.blockcracking.tar.gz" ]; then
      ## Path was: ${EXIM_PATH}/exim.blockcracking
      mkdir -p ${EXIM_BC_PATH}

      echo "Extracting exim.blockcracking.tar.gz"
      tar xvf "${PB_PATH}/files/exim.blockcracking.tar.gz" -C ${EXIM_BC_PATH}

      BC_DP_SRC=${EXIM_BC_PATH}/script.denied_paths.default.txt

      if [ -e ${EXIM_BC_PATH}/script.denied_paths.custom.txt ]; then
        echo "Using custom BlockCracking script.denied_paths.custom.txt"
        BC_DP_SRC=${EXIM_BC_PATH}/script.denied_paths.custom.txt
      fi

      cp -fp ${BC_DP_SRC} ${EXIM_BC_PATH}/script.denied_paths.txt

      echo "Restarting Exim"

      ${SERVICE} exim restart

      echo "BlockCracking is now enabled."
    else
      printf "\*** Error: Unable to find exim.blockcracking.tar.gz for extraction. Aborting.\n"
      exit 1
    fi
  else
    echo "*** Error: Exim is not installed. Cannot continue as the binary was not found."
  fi

  return
}

################################################################################################################################

## Install Easy Spam Figter (ESF)
easyspamfighter_install() {

  ## Check for Exim
  pkg query %n "exim"

  if [ -x ${EXIM_BIN} ]; then
    ## See if SPF and SRS has been compiled in:
    EXIM_SPF_SUPPORT="$(${EXIM_BIN} --version | grep -m1 -c SPF)"
    EXIM_SRS_SUPPORT="$(${EXIM_BIN} --version | grep -m1 -c SRS)"

    if [ "${EXIM_SPF_SUPPORT}" = "0" ]; then
      echo "*** Error: Your version of Exim does not support SPF. This is needed for Easy Spam Fighter."
      echo "Please reinstall Exim with SPF support."
      exit 1
    fi

    if [ "${EXIM_SRS_SUPPORT}" = "0" ]; then
      echo "*** Error: Your version of Exim does not support SRS. This is needed for Easy Spam Fighter."
      echo "Please reinstall Exim with SRS support."
      exit 1
    fi

    ## Check exim.conf version
    # if [ "${EXIMCONF_RELEASE_OPT}" = "2.1" ] || [ "${EXIMCONF_RELEASE_OPT}" = "4.2" ]; then
    #   echo "${boldon}WARNING:${boldoff} Your exim.conf version might be incompatible with Easy Spam Fighter. Please make sure that your exim.conf release is 4.3 or higher."
    # fi

    ## ESF work directry under portsbuild/
    # if [ ! -d ${PB_PATH}/easy_spam_fighter ]; then
    #   mkdir -p ${PB_PATH}/easy_spam_fighter
    #   chmod 700 ${PB_PATH}/easy_spam_fighter
    # fi

    # cd ${PB_PATH} || exit

    ## Download ESF files
    # getFile easy_spam_fighter/exim.easy_spam_fighter-${EASY_SPAM_FIGHTER_VER}.tar.gz easy_spam_figther exim.easy_spam_fighter-${EASY_SPAM_FIGHTER_VER}.tar.gz

    ## Todo: grab latest version
    ${WGET} -O "${PB_PATH}/files/esf.tar.gz" ${PB_MIRROR}/files/esf.tar.gz

    if [ -e "${PB_PATH}/files/esf.tar.gz" ]; then

      ## path was: ${EXIM_PATH}/exim.easy_spam_fighter
      mkdir -p ${EXIM_ESF_PATH}

      echo "Extracting Easy Spam Fighter"
      tar xvf "${PB_PATH}/files/esf.tar.gz" -C ${EXIM_ESF_PATH}

      echo "Restarting Exim"

      ${SERVICE} exim restart

      echo "Easy Spam Fighter is now enabled."
    else
      printf "\*** Error: Unable to find esf.tar.gz for extraction. Aborting.\n"
      exit 1
    fi
  else
    echo "*** Error: Exim is not installed. Cannot continue as the binary was not found."
    exit 1
  fi

  return
}

################################################################################################################################

## Dovecot2 Installation Tasks
dovecot_install() {

  ### Main Installation
  if [ "${DOVECOT2_MAKE_SET}" = "" ] && [ "${DOVECOT2_MAKE_UNSET}" = "" ] ; then
    pkgi ${PORT_DOVECOT2}
  else
    make -DNO_DIALOG -C "${PORTS_BASE}/${PORT_DOVECOT2}" rmconfig
    make -DNO_DIALOG -C "${PORTS_BASE}/${PORT_DOVECOT2}" mail_dovecot2_SET="${DOVECOT2_MAKE_SET}" mail_dovecot2_UNSET="${DOVECOT2_MAKE_UNSET}" OPTIONS_SET="${GLOBAL_MAKE_SET}" OPTIONS_UNSET="${GLOBAL_MAKE_UNSET}" reinstall clean
  fi

  ### Post-Installation Tasks

  ## Update directadmin.conf:
  COUNT=0
  if [ -e "${DA_CONF_FILE}" ]; then
    COUNT="$(grep -m1 -c -e '^add_userdb_quota=1' ${DA_CONF_FILE})"
    if [ "${COUNT}" = "0" ]; then
      # echo "Adding add_userdb_quota=1 to the ${DA_CONF_FILE} file to enable Dovecot quota support"
      echo "add_userdb_quota=1" >> ${DA_CONF_FILE}
      directadmin_restart
      echo "action=rewrite&value=email_passwd" >> ${DA_TASK_QUEUE}
      run_dataskq d
    fi
  fi

  ## Update directadmin.conf (template):
  COUNT_TEMPLATE="$(grep -m1 -c -e '^add_userdb_quota=1' ${DA_CONF_TEMPLATE_FILE})"
  if [ "${COUNT_TEMPLATE}" = "0" ] && [ -e ${DA_CONF_TEMPLATE_FILE} ]; then
    # echo "Adding add_userdb_quota=1 to the ${DA_CONF_TEMPLATE_FILE} (template) file"
    echo "add_userdb_quota=1" >> ${DA_CONF_TEMPLATE_FILE}
  fi

  ## Prepare Dovecot directories:
  if [ ! -d "${DOVECOT_PATH}" ]; then
    mkdir -p ${DOVECOT_PATH}
  fi

  if [ ! -d "${DOVECOT_PATH}/conf" ]; then
    mkdir -p ${DOVECOT_PATH}/conf
  fi

  if [ ! -d "${DOVECOT_PATH}/conf.d" ]; then
    mkdir -p ${DOVECOT_PATH}/conf.d
  fi

  ## Copy default configuration files:
  cp -rf "${PB_PATH}/configure/dovecot/conf" ${DOVECOT_PATH}/conf
  cp -rf "${PB_PATH}/configure/dovecot/conf.d" ${DOVECOT_PATH}/conf.d

  ## Setup config:
  if [ -e "${PB_PATH}/configure/dovecot/dovecot.conf" ]; then
    cp "${PB_PATH}/configure/dovecot/dovecot.conf" ${DOVECOT_CONF}
  # else
   # ${WGET} -O ${DOVECOT_CONF} http://files.directadmin.com/services/custombuild/dovecot.conf.2.0
  fi

  ## Symlink for compat:
  mkdir -p /etc/dovecot
  ln -s ${DOVECOT_CONF} ${DOVECOT_PATH}/dovecot.conf
  ## Skipped: ln -s /etc/dovecot/dovecot.conf /etc/dovecot.conf

  #cp -f ${PB_PATH}/configure/dovecot/conf.d/90-quote.conf ${DOVECOT_PATH}/conf.d/90-quota.conf

  ## PigeonHole (not done yet):
  if [ "${PIGEONHOLE_OPT}" = "YES" ]; then
    ## Todo: Install PigeonHole:
    # pigeonhole_install

    ${PERL} -pi -e 's#transport = virtual_localdelivery#transport = dovecot_lmtp_udp#' ${EXIM_CONF}

    cp -f "${DOVECOT_CONF_SIEVE}" ${DOVECOT_PATH}/conf.d/90-sieve.conf
    echo "protocols = imap pop3 lmtp sieve" > ${DOVECOT_PATH}/conf/protocols.conf
    echo "mail_plugins = \$mail_plugins quota sieve" > ${DOVECOT_PATH}/conf/lmtp_mail_plugins.conf
  else
    rm -f "${DOVECOT_PATH}/conf.d/90-sieve.conf"
    echo "mail_plugins = \$mail_plugins quota" > ${DOVECOT_PATH}/conf/lmtp_mail_plugins.conf
  fi

  if [ -e ${DOVECOT_PATH}/conf/lmtp.conf ]; then
    ${PERL} -pi -e "s|HOSTNAME|$(hostname)|" ${DOVECOT_PATH}/conf/lmtp.conf
  fi

  touch /var/log/dovecot-lmtp.log /var/log/dovecot-lmtp-errors.log
  chown root:wheel /var/log/dovecot-lmtp.log /var/log/dovecot-lmtp-errors.log
  chmod 600 /var/log/dovecot-lmtp.log /var/log/dovecot-lmtp-errors.log

  #${PERL} -pi -e 's#transport = dovecot_lmtp_udp#transport = virtual_localdelivery#' ${EXIM_CONF}
  ${PERL} -pi -e 's/driver = shadow/driver = passwd/' ${DOVECOT_CONF}
  ${PERL} -pi -e 's/passdb shadow/passdb passwd/' ${DOVECOT_CONF}

  echo "mail_plugins = \$mail_plugins quota"            > ${DOVECOT_PATH}/conf/mail_plugins.conf
  echo "mail_plugins = \$mail_plugins quota imap_quota" > ${DOVECOT_PATH}/conf/imap_mail_plugins.conf

  ## Check for IPV6 compatibility:
  if [ "${IPV6_ENABLED}" = "1" ]; then
    ${PERL} -pi -e 's|^listen = \*$|#listen = \*|' ${DOVECOT_PATH}/conf/ip.conf
    ${PERL} -pi -e 's|^#listen = \*, ::$|listen = \*, ::|' ${DOVECOT_PATH}/conf/ip.conf
  else
    ${PERL} -pi -e 's|^#listen = \*$|listen = \*|' ${DOVECOT_PATH}/conf/ip.conf
    ${PERL} -pi -e 's|^listen = \*, ::$|#listen = \*, ::|' ${DOVECOT_PATH}/conf/ip.conf
  fi

  #echo "listen = *, ::" > ${DOVECOT_PATH}/conf/ip.conf

  ##
  ## Todo: Add custom configuration file handling here
  ##

  ## Update conf/ssl.conf with appropriate SSL certificates:
  if [ "${OPT_PREFER_APACHE_SSL_CERTS}" = "YES" ]; then
    ## using existing Apache certs:
    echo "ssl_cert = <${APACHE_SSL_CRT}" > "${DOVECOT_PATH}/conf/ssl.conf"
    echo "ssl_key = <${APACHE_SSL_KEY}" >> "${DOVECOT_PATH}/conf/ssl.conf"
  elif [ "${OPT_PREFER_EXIM_SSL_CERTS}" = "YES" ]; then
    ## or using existing Exim certs:
    echo "ssl_cert = <${EXIM_SSL_CRT}" > "${DOVECOT_PATH}/conf/ssl.conf"
    echo "ssl_key = <${EXIM_SSL_KEY}" >> "${DOVECOT_PATH}/conf/ssl.conf"
  elif [ "${OPT_PREFER_CUSTOM_SSL_CERTS}" = "YES" ]; then
    ## or using your own custom certs:
    echo "ssl_cert = <${SSL_CUSTOM_CRT}" > "${DOVECOT_PATH}/conf/ssl.conf"
    echo "ssl_key = <${SSL_CUSTOM_KEY}" >> "${DOVECOT_PATH}/conf/ssl.conf"
  else
    ## (not done) Create self-signed certs just for Dovecot:
    echo "ssl_cert = <${DOVECOT_SSL_CRT}" > "${DOVECOT_PATH}/conf/ssl.conf"
    echo "ssl_key = <${DOVECOT_SSL_KEY}" >> "${DOVECOT_PATH}/conf/ssl.conf"
  fi

  echo "ssl_protocols = !SSLv2 !SSLv3" >> "${DOVECOT_PATH}/conf/ssl.conf"
  echo "ssl_cipher_list = ALL:!ADH:RC4+RSA:+HIGH:+MEDIUM:-LOW:-SSLv2:-EXP" >> "${DOVECOT_PATH}/conf/ssl.conf"

  verify_dovecot_logrotate

  freebsd_set_newsyslog /var/log/dovecot-lmtp-errors.log root:wheel
  freebsd_set_newsyslog /var/log/dovecot-lmtp.log root:wheel

  echo "Enabling Dovecot startup (upating /etc/rc.conf)"
  sysrc dovecot_enable="YES"

  ${SERVICE} dovecot restart
}

################################################################

## Dovecot Uninstall
dovecot_uninstall() {

  ${SERVICE} dovecot stop

  sysrc -x dovecot_enable

  return
}

################################################################################################################################

## Webalizer Installation (incomplete)
webalizer_install() {

  if [ "${OPT_WEBALIZER}" != "YES" ]; then
    echo "***"
    return
  fi

  ### Main Installation
  if [ "${WEBALIZER_MAKE_SET}" = "" ] && [ "${WEBALIZER_MAKE_UNSET}" = "" ] ; then
    pkgi ${PORT_WEBALIZER}
  else
    make -DNO_DIALOG -C "${PORTS_BASE}/${PORT_WEBALIZER}" rmconfig
    make -DNO_DIALOG -C "${PORTS_BASE}/${PORT_WEBALIZER}" www_webalizer_SET="${WEBALIZER_MAKE_SET}" www_webalizer_UNSET="${WEBALIZER_MAKE_UNSET}" OPTIONS_SET="${GLOBAL_MAKE_SET}" OPTIONS_UNSET="${GLOBAL_MAKE_UNSET}" reinstall clean
  fi

  ### Post-Installation Tasks

  if [ "${OPT_AWSTATS}" = "no" ]; then
    setVal awstats 0 ${DA_CONF_TEMPLATE_FILE}
    setVal awstats 0 ${DA_CONF_FILE}
  else
    setVal awstats 1 ${DA_CONF_TEMPLATE_FILE}
    setVal awstats 1 ${DA_CONF_FILE}
  fi

  directadmin_restart

  if [ -e /etc/webalizer.conf ]; then
    mv -f /etc/webalizer.conf /etc/webalizer.conf.moved 2> /dev/null > /dev/null
  fi
}

################################################################

## AwStats Installation (incomplete)
awstats_install() {

  if [ "${OPT_AWSTATS}" != "YES" ]; then
    echo "***"
    return
  fi

  ### Main Installation
  if [ "${AWSTATS_MAKE_SET}" = "" ] && [ "${AWSTATS_MAKE_UNSET}" = "" ] ; then
    pkgi ${PORT_AWSTATS}
  else
    make -DNO_DIALOG -C "${PORTS_BASE}/${PORT_AWSTATS}" rmconfig
    make -DNO_DIALOG -C "${PORTS_BASE}/${PORT_AWSTATS}" www_awstats_SET="${AWSTATS_MAKE_SET}" www_awstats_UNSET="${AWSTATS_MAKE_UNSET}" OPTIONS_SET="${GLOBAL_MAKE_SET}" OPTIONS_UNSET="${GLOBAL_MAKE_UNSET}" reinstall clean
  fi
  ### Post-Installation Tasks

  ## Setup directadmin.conf
  setVal awstats 1 ${DA_CONF_TEMPLATE_FILE}
  setVal awstats 1 ${DA_CONF_FILE}

  if [ "${OPT_WEBALIZER}" = "no" ]; then
    setVal webalizer 0 ${DA_CONF_TEMPLATE_FILE}
    setVal webalizer 0 ${DA_CONF_FILE}
  else
    setVal webalizer 1 ${DA_CONF_TEMPLATE_FILE}
    setVal webalizer 1 ${DA_CONF_FILE}
  fi

  directadmin_restart
}

################################################################################################################################

## Verify my.cnf (copied from CB2)
verify_my_cnf() {
  ## $1 = Path to current .cnf file
  ## $2 = Username
  ## $3 = Password
  ## $4 = Optional source file to compare with. Update $1 if $4 is newer.

  ## CB2 Note: SQL server hostname will be on the command line (that's how DA does it).

  EXISTING_MY_CNF=$1

  ## See if file exist, else we'll create a new one
  W=0
  if [ ! -s "${EXISTING_MY_CNF}" ]; then
    W=1
  fi

  ## Compare
  if [ "${W}" = "0" ] && [ "${4}" != "" ]; then
    if [ ! -s "${4}" ]; then
      echo "*** Notice: verify_my_cnf(): Cannot find $4"
      W=1
    else
      MY_CNF_TIMESTAMP=$("${file_mtime} ${EXISTING_MY_CNF}")
      SRC_CNF_TIMESTAMP=$("${file_mtime} ${4}")

      if [ "${MY_CNF_TIMESTAMP}" -lt "${SRC_CNF_TIMESTAMP}" ]; then
        echo "*** Notice: Found outdated ${EXISTING_MY_CNF}. Rewriting from ${4}."
        W=1
      fi
    fi
  fi

  ## Create new .cnf file
  if [ "${W}" = "1" ]; then
    echo '[client]' > "${EXISTING_MY_CNF}"
    chmod 600 "${EXISTING_MY_CNF}"
    echo "user=${2}" >> "${EXISTING_MY_CNF}"
    echo "password=${3}" >> "${EXISTING_MY_CNF}"
  fi
}

################################################################################################################################

## Initialize SQL Parameters (copied from CB2)
get_sql_settings() {
  ## DA_MYSQL=/usr/local/directadmin/conf/mysql.conf
  ## Use: ${DA_MYSQL_CONF}

  if [ -s "${DA_MYSQL_CONF}" ]; then
    MYSQL_USER=$(grep -m1 "^user=" ${DA_MYSQL_CONF} | cut -d= -f2)
    MYSQL_PASS=$(grep -m1 "^passwd=" ${DA_MYSQL_CONF} | cut -d= -f2)
  else
    MYSQL_USER='da_admin'
    MYSQL_PASS='nothing'
  fi

  if [ -s "${DA_MYSQL_CONF}" ] && [ "$(grep -m1 -c -e "^host=" ${DA_MYSQL_CONF})" -gt "0" ]; then
    MYSQL_HOST=$(grep -m1 "^host=" ${DA_MYSQL_CONF} | cut -d= -f2)
  else
    MYSQL_HOST=localhost
  fi

  # Where connections to MySQL are coming from. Usualy the server IP, unless on a LAN.
  MYSQL_ACCESS_HOST=localhost
  if [ "$MYSQL_HOST" != "localhost" ]; then
    SERVER_HOSTNAME=$(hostname)
    MYSQL_ACCESS_HOST="$(grep -r -l -m1 '^status=server$' /usr/local/directadmin/data/admin/ips | cut -d/ -f8)"
    if [ "${MYSQL_ACCESS_HOST}" = "" ]; then
      MYSQL_ACCESS_HOST=$(grep -m1 "${SERVER_HOSTNAME}" /etc/hosts | awk '{print $1}')
      if [ "${MYSQL_ACCESS_HOST}" = "" ]; then
        if [ -s "${DA_PATH}/scripts/setup.txt" ]; then
          MYSQL_ACCESS_HOST=$(grep -m1 -e '^ip=' "${DA_PATH}/scripts/setup.txt" | cut -d= -f2)
        fi
        if [ "${MYSQL_ACCESS_HOST}" = "" ]; then
          echo "Unable to detect your server IP in /etc/hosts. Please enter it: "
          read -r MYSQL_ACCESS_HOST
        fi
      fi
    fi
  fi

  verify_my_cnf "${DA_MYSQL_CNF}" "${MYSQL_USER}" "${MYSQL_PASS}" "${DA_MYSQL_CONF}"
  chown diradmin:diradmin "${DA_MYSQL_CNF}"
}

################################################################################################################################

## Todo:
## SQL Post-Installation Tasks
sql_post_install() {

  if [ "${OPT_SQL_DB}" = "NO" ]; then
    return
  fi

  if [ ! -e "${MYSQL_BIN}" ]; then
    echo "*** Error: MySQL binary not found at ${MYSQL_BIN}"
    echo "Aborting post-installation tasks."
    exit 1
  fi

  ## Todo: Check for mysql.conf values
  # if [ "$MYSQL_USER" = "" ] || [ "$MYSQL_PASSWORD" = "" ]; then
  #   echo "*** Error: MySQL username or password is blank in ${DA_MYSQL_CONF}"
  #   echo "Aborting post-installation tasks."
  #   exit 1
  # fi

  ## Remove /etc/my.cnf if it exists (not compliant with FreeBSD's hier(7)):
  if [ -e /etc/my.cnf ]; then
      mv /etc/my.cnf /etc/my.cnf.disabled
  fi

  echo "Updating /etc/rc.conf"
  sysrc mysql_enable="YES"
  sysrc mysql_dbdir="${SQL_DATA_PATH}"
  sysrc mysql_optfile="/usr/local/etc/my.cnf"

  echo "Starting ${OPT_SQL_DB}"
  ${SERVICE} mysql-server start

  ## Secure Installation (replace it with scripted method below)
  ## /usr/local/bin/mysql_secure_installation
  # echo "Securing SQL installation"
  # ${MYSQLSECURE_BIN}

  if [ -e "${MYSQLUPGRADE_BIN}" ]; then
    ${MYSQLUPGRADE_BIN} --defaults-extra-file=${DA_MYSQL_CNF}
  elif [ -e "${MYSQLFIX_BIN}" ]; then
    ${MYSQLFIX_BIN} --defaults-extra-file=${DA_MYSQL_CNF}
  fi

  ## From CB2 (skipped, 5.1 is outdated):
  # if [ -e /usr/local/mysql/bin/mysqlcheck ] && [ "${OPT_MYSQL}" = "5.1" ] && [ "${OPT_MYSQL_INST}" != "mariadb" ]; then
  #   /usr/local/mysql/bin/mysqlcheck --defaults-extra-file=${DA_MY_CNF} --fix-db-names --fix-table-names -A
  # fi

  ## Manual/CLI method:
  # '/usr/local/bin/mysqladmin' -u root password 'new-password'
  # '/usr/local/bin/mysqladmin' -u root -h myserver.example.com password 'new-password'
  # ${MYSQLADMIN_BIN} --user=root --password="${DA_SQLDB_PASSWORD}" 1> /dev/null 2> /dev/null

  ## Verify: Note: there are two (2) users (with different passwords): root+adminpass (setup.txt) and da_admin+passwd (mysql.conf/my.cnf)

  ## Prepare a temporary file with the root password
  {
    echo "UPDATE mysql.user SET password=PASSWORD('${DA_SQLDB_PASSWORD}') WHERE user='root';"
    echo "UPDATE mysql.user SET password=PASSWORD('${DA_SQLDB_PASSWORD}') WHERE password='';"
    echo "DROP DATABASE IF EXISTS test;"
    echo "FLUSH PRIVILEGES;"
  } > mysql.temp

  #${MYSQL_BIN} --user=root --password="${DA_SQLDB_PASSWORD}" < mysql.temp
  ${MYSQL_BIN} --user=root < mysql.temp

  rm -f mysql.temp

  ## Add the `da_admin` user to MySQL (replace the variables!):
  echo "GRANT CREATE, DROP ON *.* TO ${DA_SQLDB_USERNAME}@${MYSQL_ACCESS_HOST} IDENTIFIED BY '${DA_SQLDB_PASSWORD}' WITH GRANT OPTION;" > mysql.temp
  echo "GRANT ALL PRIVILEGES ON *.* TO ${DA_SQLDB_USERNAME}@${MYSQL_ACCESS_HOST} IDENTIFIED BY '${DA_SQLDB_PASSWORD}' WITH GRANT OPTION;" >> mysql.temp

  ${MYSQL_BIN} --user=root --password="${DA_SQLDB_PASSWORD}" < mysql.temp
  rm -f mysql.temp

  ## CLI method (incomplete):
  # /usr/local/bin/mysql --user=root --password="${DA_SQLDB_PASSWORD}" "GRANT CREATE, DROP ON *.* TO ${DA_SQLDB_USERNAME}@${MYSQL_ACCESS_HOST} IDENTIFIED BY '${DA_SQLDB_PASSWORD}' WITH GRANT OPTION;"

  ## Add DirectAdmin 'da_admin' SQL database credentials to 'mysql.conf':
  {
   echo "user=${DA_SQLDB_USERNAME}"
   echo "passwd=${DA_SQLDB_PASSWORD}"
  } > ${DA_MYSQL_CONF}

  chown diradmin:diradmin ${DA_MYSQL_CONF}
  chmod 400 ${DA_MYSQL_CONF}

  ## Reference CNF files: /usr/local/share/mysql/*.cnf

  if [ ! -e "${MYSQL_CNF}" ]; then
    case ${DEFAULT_MY_CNF} in
      my-huge.cnf|my-medium.cnf|my-innodb-heavy-4G.cnf|my-small.cnf|my-large.cnf) cp /usr/local/share/mysql/${DEFAULT_MY_CNF} "${MYSQL_CNF}" ;;
      my-huge|my-medium|my-innodb-heavy-4G|my-small|my-large) cp /usr/local/share/mysql/${DEFAULT_MY_CNF}.cnf "${MYSQL_CNF}" ;;
      custom) cp -f "${CUSTOM_MYSQL_CNF}" "${MYSQL_CNF}" ;;
      *)
        touch ${MYSQL_CNF}
        echo "[mysqld]" > ${MYSQL_CNF}
        echo "local-infile=0" >> ${MYSQL_CNF}
        echo "innodb_file_per_table" >> ${MYSQL_CNF}
        ;;
    esac
    chown root:wheel ${MYSQL_CNF}
  fi

  ## Todo: comment out thread_concurrency in my.cnf to prevent deprecation warnings
  ## thread_concurrency = 8

  DA_MYSQL_PATH=/usr/local/mysql/bin
  if [ ! -e ${DA_MYSQL_PATH}/mysql ]; then
    echo "Symlinking the MySQL/MariaDB binaries for DirectAdmin compatibility:"
    mkdir -p /usr/local/mysql/bin
    ln -s ${MYSQL_BIN} ${DA_MYSQL_PATH}/mysql
    ln -s ${MYSQLDUMP_BIN} ${DA_MYSQL_PATH}/mysqldump
    ln -s ${MYSQLD_BIN} ${DA_MYSQL_PATH}/mysqld
    ln -s ${MYSQLD_SAFE_BIN} ${DA_MYSQL_PATH}/mysqld_safe
    ln -s ${MYSQLADMIN_BIN} ${DA_MYSQL_PATH}/mysqladmin
    ln -s ${MYSQLIMPORT_BIN} ${DA_MYSQL_PATH}/mysqlimport
    ln -s ${MYSQLSHOW_BIN} ${DA_MYSQL_PATH}/mysqlshow
    ln -s ${MYSQLUPGRADE_BIN} ${DA_MYSQL_PATH}/mysql_upgrade
    ln -s ${MYSQLCHECK_BIN} ${DA_MYSQL_PATH}/mysqlcheck
    ln -s ${MYSQLSECURE_BIN} ${DA_MYSQL_PATH}/mysql_secure_installation
  else
    echo "*** Notice: MySQL/MariaDB binaries already symlinked in ${DA_MYSQL_PATH}"
  fi

  echo "Restarting ${OPT_SQL_DB}"
  ${SERVICE} mysql-server restart
}

################################################################################################################################

## PHP Installation Tasks
php_install() {

  case ${OPT_PHP1_VERSION} in
    55) PORT_PHP="${PORT_PHP55}"
        PORT_PHP_EXT="${PORT_PHP55_EXT}"
        PORT_MOD_PHP="${PORT_MOD_PHP55}"
        PHP_MAKE_SET="${PHP55_MAKE_SET}"
        PHP_MAKE_UNSET="${PHP55_MAKE_UNSET}"
        PHP_EXT_MAKE_SET="${PHP55_EXT_MAKE_SET}"
        PHP_EXT_MAKE_UNSET="${PHP55_EXT_MAKE_UNSET}"
        PHP_MOD_MAKE_SET="${MOD_PHP55_MAKE_SET}"
        PHP_MOD_MAKE_UNSET="${MOD_PHP55_MAKE_UNSET}"
        PHP_EXT_LIST="math/php55-bcmath archivers/php55-bz2 misc/php55-calendar textproc/php55-ctype ftp/php55-curl textproc/php55-dom graphics/php55-exif sysutils/php55-fileinfo security/php55-filter ftp/php55-ftp graphics/php55-gd devel/php55-gettext security/php55-hash converters/php55-iconv mail/php55-imap devel/php55-json converters/php55-mbstring security/php55-mcrypt databases/php55-mysql databases/php55-mysqli databases/php55-odbc www/php55-opcache security/php55-openssl databases/php55-pdo databases/php55-pdo_mysql databases/php55-pdo_sqlite archivers/php55-phar sysutils/php55-posix textproc/php55-pspell devel/php55-readline converters/php55-recode www/php55-session textproc/php55-simplexml net-mgmt/php55-snmp net/php55-soap net/php55-sockets databases/php55-sqlite3 www/php55-tidy devel/php55-tokenizer textproc/php55-wddx textproc/php55-xml textproc/php55-xmlreader net/php55-xmlrpc textproc/php55-xmlwriter textproc/php55-xsl archivers/php55-zip archivers/php55-zlib"
        ;;
    56) PORT_PHP="${PORT_PHP56}"
        PORT_PHP_EXT="${PORT_PHP56_EXT}"
        PORT_MOD_PHP="${PORT_MOD_PHP56}"
        PHP_MAKE_SET="${PHP56_MAKE_SET}"
        PHP_MAKE_UNSET="${PHP56_MAKE_SET}"
        PHP_EXT_MAKE_SET="${PHP56_EXT_MAKE_SET}"
        PHP_EXT_MAKE_UNSET="${PHP56_EXT_MAKE_UNSET}"
        PHP_MOD_MAKE_SET="${MOD_PHP56_MAKE_SET}"
        PHP_MOD_MAKE_UNSET="${MOD_PHP56_MAKE_UNSET}"
        PHP_EXT_LIST="math/php56-bcmath archivers/php56-bz2 misc/php56-calendar textproc/php56-ctype ftp/php56-curl textproc/php56-dom graphics/php56-exif sysutils/php56-fileinfo security/php56-filter ftp/php56-ftp graphics/php56-gd devel/php56-gettext security/php56-hash converters/php56-iconv mail/php56-imap devel/php56-json converters/php56-mbstring security/php56-mcrypt databases/php56-mysql databases/php56-mysqli databases/php56-odbc www/php56-opcache security/php56-openssl databases/php56-pdo databases/php56-pdo_mysql databases/php56-pdo_sqlite archivers/php56-phar sysutils/php56-posix textproc/php56-pspell devel/php56-readline converters/php56-recode www/php56-session textproc/php56-simplexml net-mgmt/php56-snmp net/php56-soap net/php56-sockets databases/php56-sqlite3 www/php56-tidy devel/php56-tokenizer textproc/php56-wddx textproc/php56-xml textproc/php56-xmlreader net/php56-xmlrpc textproc/php56-xmlwriter textproc/php56-xsl archivers/php56-zip archivers/php56-zlib"
        ;;
    70) PORT_PHP="${PORT_PHP70}"
        PORT_PHP_EXT="${PORT_PHP70_EXT}"
        PORT_MOD_PHP="${PORT_MOD_PHP70}"
        PHP_MAKE_SET="${PHP70_MAKE_SET}"
        PHP_MAKE_UNSET="${PHP70_MAKE_SET}"
        PHP_EXT_MAKE_SET="${PHP70_EXT_MAKE_SET}"
        PHP_EXT_MAKE_UNSET="${PHP70_EXT_MAKE_UNSET}"
        PHP_MOD_MAKE_SET="${MOD_PHP70_MAKE_SET}"
        PHP_MOD_MAKE_UNSET="${MOD_PHP70_MAKE_UNSET}"
        PHP_EXT_LIST="math/php70-bcmath archivers/php70-bz2 misc/php70-calendar textproc/php70-ctype ftp/php70-curl textproc/php70-dom graphics/php70-exif sysutils/php70-fileinfo security/php70-filter ftp/php70-ftp graphics/php70-gd devel/php70-gettext security/php70-hash converters/php70-iconv mail/php70-imap devel/php70-json converters/php70-mbstring security/php70-mcrypt databases/php70-mysqli databases/php70-odbc www/php70-opcache security/php70-openssl databases/php70-pdo databases/php70-pdo_mysql databases/php70-pdo_sqlite archivers/php70-phar sysutils/php70-posix textproc/php70-pspell devel/php70-readline converters/php70-recode www/php70-session textproc/php70-simplexml net-mgmt/php70-snmp net/php70-soap net/php70-sockets databases/php70-sqlite3 www/php70-tidy devel/php70-tokenizer textproc/php70-wddx textproc/php70-xml textproc/php70-xmlreader net/php70-xmlrpc textproc/php70-xmlwriter textproc/php70-xsl archivers/php70-zip archivers/php70-zlib"
        ;;
    *) ;;
  esac

  if [ "${PHP_MAKE_SET}" = "" ] && [ "${PHP_MAKE_UNSET}" = "" ] ; then
    case ${OPT_PHP1_MODE} in
      fpm) pkgi ${PORT_PHP} "${PHP_EXT_LIST}"
        ;;
    esac
  else
    case ${OPT_PHP1_MODE} in
      fpm)
          make -DNO_DIALOG -C "${PORTS_BASE}/${PORT_PHP}" rmconfig
          make -DNO_DIALOG -C "${PORTS_BASE}/${PORT_PHP}" OPTIONS_SET="${PHP_MAKE_SET} ${GLOBAL_MAKE_SET}" OPTIONS_UNSET="${PHP_MAKE_UNSET} ${GLOBAL_MAKE_UNSET}" reinstall clean
          make -DNO_DIALOG -C "${PORTS_BASE}/${PORT_PHP_EXT}" rmconfig
          make -DNO_DIALOG -C "${PORTS_BASE}/${PORT_PHP_EXT}" OPTIONS_SET="${PHP_EXT_MAKE_SET} ${GLOBAL_MAKE_SET}" OPTIONS_UNSET="${PHP_EXT_MAKE_UNSET} ${GLOBAL_MAKE_UNSET}" reinstall clean
          ;;
      mod_php)
          make -DNO_DIALOG -C "${PORTS_BASE}/${PORT_MOD_PHP}" rmconfig
          make -DNO_DIALOG -C "${PORTS_BASE}/${PORT_MOD_PHP}" OPTIONS_SET="${PHP_MOD_MAKE_SET} ${GLOBAL_MAKE_SET}" OPTIONS_UNSET="${PHP_MOD_MAKE_UNSET} ${GLOBAL_MAKE_UNSET}" reinstall clean
          make -DNO_DIALOG -C "${PORTS_BASE}/${PORT_PHP_EXT}" OPTIONS_SET="${PHP_EXT_MAKE_SET} ${GLOBAL_MAKE_SET}" OPTIONS_UNSET="${PHP_EXT_MAKE_UNSET} ${GLOBAL_MAKE_UNSET}" reinstall clean
          ;;
      fastcgi) ;;
      suphp)
          # /usr/ports/www/suphp
          ;;
      *) echo "*** Error: Wrong PHP version selected. (Script error?)"; exit ;;
    esac
  fi

  # make -DNO_DIALOG -C "${PORT_PHP_EXT}" reinstall clean

  ## Replace default php-fpm.conf with DirectAdmin/CB2 version:
  cp -f "${PB_PATH}/configure/fpm/conf/php-fpm.conf.${OPT_PHP1_VERSION}" /usr/local/etc/php-fpm.conf

  if [ "${OPT_PHP_INI_TYPE}" = "production" ]; then
    cp -f /usr/local/etc/php.ini-production /usr/local/etc/php.ini
  elif [ "${OPT_PHP_INI_TYPE}" = "development" ]; then
    cp -f /usr/local/etc/php.ini-development /usr/local/etc/php.ini
  fi

  ## e.g. PHP1_VER="56"
  PHP1_PATH="/usr/local/php${OPT_PHP1_VERSION}"

  ## Create directories for DA compat:
  mkdir -p "${PHP1_PATH}"
  mkdir -p "${PHP1_PATH}/bin"
  mkdir -p "${PHP1_PATH}/etc"
  mkdir -p "${PHP1_PATH}/include"
  mkdir -p "${PHP1_PATH}/lib"
  mkdir -p "${PHP1_PATH}/php"
  mkdir -p "${PHP1_PATH}/sbin"
  mkdir -p "${PHP1_PATH}/sockets"
  mkdir -p "${PHP1_PATH}/var/log/"
  mkdir -p "${PHP1_PATH}/var/run"
  # mkdir -p "${PHP_PATH}/lib/php.conf.d/"
  mkdir -p "${PHP1_PATH}/lib/php/"

  ## Symlink for compat
  ln -s /usr/local/bin/php "${PHP1_PATH}/bin/php"
  ln -s /usr/local/bin/php-cgi "${PHP1_PATH}/bin/php-cgi"
  ln -s /usr/local/bin/php-config "${PHP1_PATH}/bin/php-config"
  ln -s /usr/local/bin/phpize "${PHP1_PATH}/bin/phpize"
  ln -s /usr/local/sbin/php-fpm "${PHP1_PATH}/sbin/php-fpm"
  ln -s /var/log/php-fpm.log "${PHP1_PATH}/var/log/php-fpm.log"
  ln -s /usr/local/include/php "${PHP1_PATH}/include"

  ## php.conf.d: directory for additional PHP ini files loaded by FPM:
  ln -s /usr/local/etc/php "${PHP1_PATH}/lib/php.conf.d"
  ln -s /usr/local/etc/php.ini "${PHP1_PATH}/lib/php.ini"
  ln -s /usr/local/etc/php-fpm.conf "${PHP1_PATH}/etc/php-fpm.conf"
  ln -s /usr/local/lib/php/build "${PHP1_PATH}/lib/php/build"

  ## Verify: extension_dir "YYYYMMDD" is different across PHP versions:
  ## This call returns e.g. "/usr/local/lib/php/20131226"
  PHP_EXTENSION_DIR=$(/usr/local/bin/php-config --extension-dir)

  ln -s "${PHP_EXTENSION_DIR}" "${PHP1_PATH}/lib/php/extensions"

  ## Old method (to remove):
  # if [ ${PHP1_VERSION} = "55" ]; then
  #   ln -s /usr/local/lib/php/20121212 ${PHP1_PATH}/lib/php/extensions
  # elif [ ${PHP1_VERSION} = "56" ]; then
  #   ln -s /usr/local/lib/php/20131226 ${PHP1_PATH}/lib/php/extensions
  # elif [ ${PHP1_VERSION} = "70" ]; then
  #   ln -s /usr/local/lib/php/20151012 ${PHP1_PATH}/lib/php/extensions
  # fi

  ## Scripted reference (from CB2):
  echo "Making PHP installation compatible with php.ini file"
  ${PERL} -pi -e 's/^register_long_arrays/;register_long_arrays/' ${PHP_INI}
  ${PERL} -pi -e 's/^magic_quotes_gpc/;magic_quotes_gpc/' ${PHP_INI}
  ${PERL} -pi -e 's/^safe_mode/;safe_mode/' ${PHP_INI}
  ${PERL} -pi -e 's/^register_globals/;register_globals/' ${PHP_INI}
  ${PERL} -pi -e 's/^register_long_arrays/;register_long_arrays/' ${PHP_INI}
  ${PERL} -pi -e 's/^allow_call_time_pass_reference/;allow_call_time_pass_reference/' ${PHP_INI}
  ${PERL} -pi -e 's/^define_syslog_variables/;define_syslog_variables/' ${PHP_INI}
  ${PERL} -pi -e 's/^highlight.bg/;highlight.bg/' ${PHP_INI}
  ${PERL} -pi -e 's/^session.bug_compat_42/;session.bug_compat_42/' ${PHP_INI}
  ${PERL} -pi -e 's/^session.bug_compat_warn/;session.bug_compat_warn/' ${PHP_INI}
  ${PERL} -pi -e 's/^y2k_compliance/;y2k_compliance/' ${PHP_INI}
  ${PERL} -pi -e 's/^magic_quotes_runtime/;magic_quotes_runtime/' ${PHP_INI}
  ${PERL} -pi -e 's/^magic_quotes_sybase/;magic_quotes_sybase/' ${PHP_INI}

  secure_php_ini ${PHP_INI}

  echo "Enabling PHP-FPM startup (updating /etc/rc.conf)"
  sysrc php_fpm_enable="YES"
}

################################################################

## Upgrade PHP and related components
php_upgrade() {
  pkg upgrade "$(pkg query %o | grep "php${OPT_PHP1_VERSION}")"

  #pkg query -i -x "%o %v" '(php)'
}

################################################################

## Have PHP System (copied from CB2)
## Needed?
have_php_system() {
  ## Checks to see if we can use system() based on the disable_functions
  if [ ! -s "${PHP_INI}" ]; then
    echo 1
    return
  fi

  C=$(grep -m1 -c ^disable_functions "${PHP_INI}")
  if [ "${C}" -eq 0 ]; then
    echo 1
    return
  fi

  C=$(grep -m1 ^disable_functions "${PHP_INI}" | grep -m1 -c system)
  if [ "${C}" -eq 1 ]; then
    echo 0
    return
  fi

  echo 1
  return
}


################################################################################################################################

## phpMyAdmin Installation
phpmyadmin_install() {

  if [ "${OPT_PHPMYADMIN}" != "YES" ]; then
    echo "***"
    return
  fi

  ### Main Installation
  if [ "${PMA_MAKE_SET}" = "" ] && [ "${PMA_MAKE_UNSET}" = "" ] ; then
    pkgi ${PORT_PHPMYADMIN}
  else
    make -DNO_DIALOG -C "${PORTS_BASE}/${PORT_PHPMYADMIN}" rmconfig
    make -DNO_DIALOG -C "${PORTS_BASE}/${PORT_PHPMYADMIN}" databases_phpmyadmin_SET="${PMA_MAKE_SET}" databases_phpmyadmin_UNSET"${PMA_MAKE_UNSET}" OPTIONS_SET="${GLOBAL_MAKE_SET}" OPTIONS_UNSET="${GLOBAL_MAKE_UNSET}" reinstall clean
  fi

  ### Post-Installation Tasks

  ## Reference for virtualhost entry:
  # Alias /phpmyadmin/ "/usr/local/www/phpMyAdmin/"
  # <Directory "/usr/local/www/phpMyAdmin/">
  #   Options None
  #   AllowOverride Limit
  #   Require local
  #   Require host .example.com
  # </Directory>

  ## Custom config from cb2/custom directory (if present):
  CUSTOM_PMA_CONFIG="${PB_PATH}/custom/phpmyadmin/config.inc.php"
  CUSTOM_PMA_THEMES="${PB_PATH}/custom/phpmyadmin/themes"

  ##REALPATH=${WWWDIR}/phpMyAdmin-${PHPMYADMIN_VER}
  #REALPATH=${WWW_DIR}/phpMyAdmin
  PMA_ALIAS_PATH="${WWW_DIR}/phpmyadmin"


  ## Scripted reference:

  ## If custom config exists:
  if [ -e "${CUSTOM_PMA_CONFIG}" ]; then
    echo "Installing custom phpMyAdmin configuration file: ${CUSTOM_PMA_CONFIG}"
    cp -f "${CUSTOM_PMA_CONFIG}" ${PMA_CONFIG}
  else
    cp -f ${PMA_PATH}/config.sample.inc.php ${PMA_CONFIG}
    ${PERL} -pi -e "s#\['host'\] = 'localhost'#\['host'\] = '${MYSQL_HOST}'#" ${PMA_CONFIG}
    ${PERL} -pi -e "s#\['host'\] = ''#\['host'\] = '${MYSQL_HOST}'#" ${PMA_CONFIG}
    ${PERL} -pi -e "s#\['auth_type'\] = 'cookie'#\['auth_type'\] = 'http'#" ${PMA_CONFIG}
    ${PERL} -pi -e "s#\['extension'\] = 'mysql'#\['extension'\] = 'mysqli'#" ${PMA_CONFIG}
  fi

  ## Copy sample config:
  cp ${PMA_PATH}/config.sample.inc.php ${PMA_CONFIG}

  ## Update phpMyAdmin configuration file:
  ${PERL} -pi -e "s#\['host'\] = 'localhost'#\['host'\] = 'localhost'#" ${PMA_CONFIG}
  ${PERL} -pi -e "s#\['host'\] = ''#\['host'\] = 'localhost'#" ${PMA_CONFIG}
  ${PERL} -pi -e "s#\['auth_type'\] = 'cookie'#\['auth_type'\] = 'http'#" ${PMA_CONFIG}
  ${PERL} -pi -e "s#\['extension'\] = 'mysql'#\['extension'\] = 'mysqli'#" ${PMA_CONFIG}

  # Copy custom themes (not implemented):
  if [ -d "${CUSTOM_PMA_THEMES}" ]; then
    echo "Installing custom phpMyAdmin themes: ${PMA_THEMES}"
    cp -Rf "${CUSTOM_PMA_THEMES}" ${PMA_PATH}
  fi

  ## Update alias path via symlink (not done):
  rm -f ${PMA_ALIAS_PATH} >/dev/null 2>&1
  ln -s ${PMA_PATH} ${PMA_ALIAS_PATH}

  ## Create logs directory:
  if [ ! -d ${PMA_PATH}/log ]; then
    mkdir -p ${PMA_PATH}/log
  fi

  ## Set permissions:
  chown -R ${WEBAPPS_USER}:${WEBAPPS_GROUP} ${PMA_PATH}
  chown -h ${WEBAPPS_USER}:${WEBAPPS_GROUP} ${PMA_ALIAS_PATH}
  chmod 755 ${PMA_PATH}

  ## Symlink:
  ln -s ${PMA_PATH} ${WWW_DIR}/phpmyadmin
  ln -s ${PMA_PATH} ${WWW_DIR}/pma

  ## Verify:
  ## Disable/lockdown scripts directory (this might not even exist):
  if [ -d ${PMA_PATH}/scripts ]; then
    chmod 000 ${PMA_PATH}/scripts
  fi

  ## Disable/lockdown setup directory (done):
  if [ -d ${PMA_PATH}/setup ]; then
    chmod 000 ${PMA_PATH}/setup
  fi

  ## Auth log patch for BFM compat (not done):
  ## Currently outputs to /var/log/auth.log
  if [ ! -e "${PB_DIR}/patches/pma_auth_logging.patch" ]; then
    ${WGET} -O "${PB_DIR}/patches/pma_auth_logging.patch" "${PB_MIRROR}/patches/pma_auth_logging.patch"
  fi

  if [ -e "${PB_DIR}/patches/pma_auth_logging.patch" ]; then
    echo "Patching phpMyAdmin for BFM to log failed authentications"
    cd ${PMA_PATH} || exit
    patch -p0 < "${PB_DIR}/patches/pma_auth_logging.patch"
  fi

  ## Update /etc/groups (verify):
  #access:*:1164:apache,nobody,mail,majordomo,daemon,clamav
}

## Upgrade phpMyAdmin
phpmyadmin_upgrade() {
  return
}

################################################################################################################################

## Apache 2.4 Installation
apache_install() {

  if [ "${OPT_WEBSERVER}" != "apache" ]; then
    echo "***"
    return
  fi

  ### Main Installation
  if [ "${APACHE24_MAKE_SET}" = "" ] && [ "${APACHE24_MAKE_UNSET}" = "" ] ; then
    pkgi ${PORT_APACHE24}
  else
    make -DNO_DIALOG -C "${PORTS_BASE}/${PORT_APACHE24}" rmconfig
    make -DNO_DIALOG -C "${PORTS_BASE}/${PORT_APACHE24}" www_apache24_SET="${APACHE24_MAKE_SET}" www_apache24_UNSET="${APACHE24_MAKE_UNSET}" OPTIONS_SET="${GLOBAL_MAKE_SET}" OPTIONS_UNSET="${GLOBAL_MAKE_UNSET}" reinstall clean
  fi

  ## Todo:
  # USERS=${APACHE_USER} GROUPS=${APACHE_GROUP}

  ### Post-Installation Tasks

  ## Symlink for backwards compatibility:
  ## 2016-03-05: no longer needed?
  mkdir -p /etc/httpd/conf
  ln -s ${APACHE_PATH} /etc/httpd/conf

  ## CustomBuild2 looking for Apache modules in ${APACHE_LIB_PATH}*
  ## Symlink for backcomp (done):
  ## 2016-03-05: no longer needed?
  # mkdir -p ${APACHE_LIB_PATH}
  # ln -s /usr/local/libexec/apache24 ${APACHE_LIB_PATH}

  ## Since DirectAdmin/CB2 reference /var/www/html often, we'll symlink for compat:
  mkdir -p /var/www
  ln -s ${WWW_DIR} /var/www/html
  chown -h ${WEBAPPS_USER}:${WEBAPPS_GROUP} /var/www/html

  mkdir -p ${APACHE_PATH}/ssl

  # touch /etc/httpd/conf/ssl.crt/server.crt
  # touch /etc/httpd/conf/ssl.key/server.key

  # touch ${APACHE_DIR}/ssl/server.crt
  # touch ${APACHE_DIR}/ssl/server.key

  ## Generate self-signed SSL certificate for Apache:
  ${OPENSSL_BIN} req -x509 -newkey rsa:2048 -keyout ${APACHE_SSL_KEY} -out ${APACHE_SSL_CRT} -days 9999 -nodes "${OPENSSL_EXTRA}"

  ## Set permissions:
  chmod 600 ${APACHE_PATH}/ssl/server.crt
  chmod 600 ${APACHE_PATH}/ssl/server.key

  ## Create & symlink SSL directories for CB2 compat
  ## 2016-03-05: no longer needed?
  mkdir -p /etc/httpd/conf/ssl.crt
  mkdir -p /etc/httpd/conf/ssl.key

  ln -s ${APACHE_SSL_CRT} /etc/httpd/conf/ssl.crt/server.crt
  ln -s ${APACHE_SSL_KEY} /etc/httpd/conf/ssl.key/server.key
  ln -s ${APACHE_SSL_CA} /etc/httpd/conf/ssl.crt/server.ca

  ln -s ${APACHE_SSL_CRT} ${APACHE_PATH}/ssl.crt/server.crt
  ln -s ${APACHE_SSL_KEY} ${APACHE_PATH}/ssl.key/server.key
  ln -s ${APACHE_SSL_CA} ${APACHE_PATH}/ssl.crt/server.ca

  ## Symlink for DA compat:
  ln -s /usr/local/sbin/httpd /usr/sbin/httpd

  ## Copy over modified (custom) configuration files to conf/:
  cp -rf "${PB_PATH}/custom/ap2/conf/" ${APACHE_PATH}/
  cp -f "${PB_PATH}/custom/ap2/conf/httpd.conf" ${APACHE_PATH}/
  cp -f "${PB_PATH}/custom/ap2/conf/extra/httpd-mpm.conf" ${APACHE_EXTRA_PATH}/httpd-mpm.conf

  ## This is already done (Apache default):
  ${PERL} -pi -e 's/^DefaultType/#DefaultType/' ${APACHE_PATH}/httpd.conf

  chmod 710 ${APACHE_PATH}

  ## Update directadmin.conf with new paths
  setVal apacheconf ${APACHE_PATH}/httpd.conf ${DA_CONF_FILE}
  setVal apacheips ${APACHE_PATH}/ips.conf ${DA_CONF_FILE}
  setVal apachemimetypes ${APACHE_PATH}/mime.types ${DA_CONF_FILE}
  setVal apachecert ${APACHE_SSL_CRT} ${DA_CONF_FILE}
  setVal apachekey ${APACHE_SSL_KEY} ${DA_CONF_FILE}
  setVal apacheca ${APACHE_SSL_CA} ${DA_CONF_FILE}

  ## Rewrite Apache 2.4 configuration files
  ## cd /usr/local/directadmin/custombuild
  ## ./build rewrite_confs

  apache_rewrite_confs

  ## Update /boot/loader.conf
  sysrc -f /boot/loader.conf accf_http_load="YES"
  sysrc -f /boot/loader.conf accf_data_load="YES"

  ## Update /etc/rc.conf
  sysrc apache24_enable="YES"
  sysrc apache24_http_accept_enable="YES"

  ## Start Apache
  ${SERVICE} apache24 start

  ## Remove nginx startup if defined
  ## Soon: verify if nginx_apache reverse proxy is configured
  sysrc -x nginx_enable
}

################################################################

## Apache Uninstall
apache_uninstall() {

  ${SERVICE} apache24 stop

  pkg -f delete apache24

  sysrc -x apache24_enable
  sysrc -x apache24_http_accept_enable

  return
}

################################################################################################################################

## Todo: NGINX Installation
nginx_install() {

  if [ "${OPT_WEBSERVER}" != "nginx" ]; then
    echo "***"
    return
  fi

  ### Main Installation
  if [ "${NGINX_MAKE_SET}" = "" ] && [ "${NGINX_MAKE_UNSET}" = "" ] ; then
    pkgi ${PORT_NGINX}
  else
    make -DNO_DIALOG -C "${PORTS_BASE}/${PORT_NGINX}" rmconfig
    make -DNO_DIALOG -C "${PORTS_BASE}/${PORT_NGINX}" www_nginx_SET="${NGINX_MAKE_SET}" www_nginx_UNSET="${NGINX_MAKE_UNSET}" OPTIONS_SET="${GLOBAL_MAKE_SET}" OPTIONS_UNSET="${GLOBAL_MAKE_UNSET}" reinstall clean
  fi

  ### Post-Installation Tasks

  ## Update directadmin.conf with new paths
  setVal nginxconf ${NGINX_PATH}/directadmin-vhosts.conf ${DA_CONF_FILE}
  setVal nginxlogdir /var/log/nginx/domains ${DA_CONF_FILE}
  setVal nginxips ${NGINX_PATH}/directadmin-ips.conf ${DA_CONF_FILE}
  setVal nginx_pid /var/run/nginx.pid ${DA_CONF_FILE}
  setVal nginx_cert ${NGINX_PATH}/ssl/server.crt ${DA_CONF_FILE}
  setVal nginx_key ${NGINX_PATH}/ssl/server.key ${DA_CONF_FILE}
  setVal nginx_ca ${NGINX_PATH}/ssl/server.ca ${DA_CONF_FILE}

  ## Update /etc/rc.conf
  sysrc nginx_enable="YES"

  ## Add 'nginx' user into 'access' group
  usermod -G access nginx

  ## Start nginx
  ${SERVICE} nginx start

  ## Remove Apache24 startup if defined
  ## Soon: verify if nginx_apache reverse proxy is configured
  sysrc -x apache24_enable
  sysrc -x apache24_http_accept_enable

  return
}

################################################################

## Copied from CB2
# addNginxToAccess() {
#   ## Check for nginx user in access group
#   if grep -m1 -q "^access" /etc/group; then
#     if ! grep -m1 "^access" /etc/group | grep -q nginx; then
#       usermod -G access nginx
#     fi
#   fi
#}


################################################################

## Uninstall nginx
nginx_uninstall() {

  ${SERVICE} nginx stop

  pkg -f delete nginx

  sysrc -x nginx_enable

  return
}

################################################################################################################################

## Majordomo Uninstall
majordomo_install() {

  if [ "${OPT_MAJORDOMO}" = "NO" ]; then
    echo "*** Error: Majordomo not enabled in options.conf"
    return
  fi

  ## Verify: majordomo.sh script
  ./scripts/majordomo.sh

  return
}

################################################################

## Majordomo Uninstall
majordomo_uninstall() {
  return
}

################################################################################################################################

## PureFTPD Installation
pureftpd_install() {

  if [ "${OPT_FTPD}" != "pureftpd" ]; then
    echo "*** Error: PureFTPD not set in options.conf"
    return
  fi

  ### Main Installation
  if [ "${PUREFTPD_MAKE_SET}" = "" ] && [ "${PUREFTPD_MAKE_UNSET}" = "" ] ; then
    pkgi ${PORT_PUREFTPD}
  else
    make -DNO_DIALOG -C "${PORTS_BASE}/${PORT_PUREFTPD}" rmconfig
    make -DNO_DIALOG -C "${PORTS_BASE}/${PORT_PUREFTPD}" ftp_pure_ftpd_SET="${PUREFTPD_MAKE_SET}" ftp_pure_ftpd_UNSET="${PUREFTPD_MAKE_UNSET}" OPTIONS_SET="${GLOBAL_MAKE_SET}" OPTIONS_UNSET="${GLOBAL_MAKE_UNSET}" reinstall clean
  fi

  if [ "${OPT_PUREFTPD_UPLOADSCAN}" = "YES" ] && [ "${OPT_CLAMAV}" = "YES" ]; then
    if [ ! -e ${CLAMDSCAN_BIN} ]; then
      clamav_install
    fi

    if [ ! -e ${CLAMDSCAN_BIN} ]; then
      echo "*** Error: Cannot enable upload scanning in Pure-FTPD because there is no ClamAV (${CLAMDSCAN_BIN}) on the system."
      exit 1
    fi

    echo "Enabling Pure-FTPD upload scanning script..."
    cp -f "${PUREFTPD_UPLOADSCAN_SCRIPT}" ${PATH_TO_UPLOADSCAN}
    chmod 711 ${PATH_TO_UPLOADSCAN}

    sysrc pureftpd_upload_enable="YES"
    sysrc pureftpd_uploadscript="${PATH_TO_UPLOADSCAN}"
  else
    rm -f ${PATH_TO_UPLOADSCAN}
    sysrc -x pureftpd_upload_enable
    sysrc -x pureftpd_uploadscript
  fi

  return

  PUREFTPD_LOG=/var/log/pureftpd.log
  PUREFTPD_DB=/etc/pureftpd.pdb

  sysrc pureftpd_enable="YES"
  sysrc pureftpd_flags="-B -A -C 15 -E -H -k 99 -L 10000:8 -O stats:${PUREFTPD_LOG} -l puredb:${PUREFTPD_DB} -p 35000:35999 -u 100 -U 133:022 -w -Z -Y 1 -J -S:HIGH:MEDIUM:+TLSv1:!SSLv2:+SSLv3"

  ## Update directadmin.conf
  setVal pureftp 1 ${DA_CONF_TEMPLATE_FILE}
  setVal pureftp 1 ${DA_CONF_FILE}

  # ${SERVICE} directadmin restart
  directadmin_restart

  ## Update services.status
  set_service proftpd delete
  set_service pure-ftpd ON

  ## Verify:
  /usr/local/bin/pure-pw mkdb /usr/local/etc/pureftpd.pdb -f /usr/local/etc/proftpd.passwd

  echo "Restarting PureFTPD"
  ${SERVICE} pureftpd restart

  return
}


################################################################

## PureFTPD Uninstall
pureftpd_uninstall() {

  ${SERVICE} pureftpd stop

  sysrc -x pureftpd_enable
  sysrc -x pureftpd_flags
  sysrc -x pureftpd_upload_enable
  sysrc -x pureftpd_uploadscript

  rm -f ${PATH_TO_UPLOADSCAN}

  return
}

################################################################################################################################

## ProFTPD Installation
proftpd_install() {

  if [ "${OPT_FTPD}" != "proftpd" ]; then
    echo "*** Error: ProFTPD not set in options.conf"
    return
  fi

  ### Main Installation
  if [ "${PROFTPD_MAKE_SET}" = "" ] && [ "${PROFTPD_MAKE_UNSET}" = "" ] ; then
    pkgi ${PORT_PROFTPD}
  else
    make -DNO_DIALOG -C "${PORTS_BASE}/${PORT_PROFTPD}" rmconfig
    make -DNO_DIALOG -C "${PORTS_BASE}/${PORT_PROFTPD}" ftp_proftpd_SET="${PROFTPD_MAKE_SET}" ftp_proftpd_UNSET="${PROFTPD_MAKE_UNSET}" OPTIONS_SET="${GLOBAL_MAKE_SET}" OPTIONS_UNSET="${GLOBAL_MAKE_UNSET}" reinstall clean
  fi

  sysrc -x pureftpd_enable

  ## Update directadmin.conf
  setVal pureftp 0 ${DA_CONF_TEMPLATE_FILE}
  setVal pureftp 0 ${DA_CONF_FILE}

  ## Update services.status
  set_service pure-ftpd delete
  set_service proftpd ON

  ## Stop PureFTPD if it's running
  ${SERVICE} pure-ftpd onestop

  if [ "${OPT_PROFTPD_UPLOADSCAN}" = "YES" ] && [ "${OPT_CLAMAV}" = "YES" ]; then
    if [ ! -e "${CLAMDSCAN_BIN}" ]; then
      clamav_install
    fi

    if [ ! -e "${CLAMDSCAN_BIN}" ]; then
      echo "*** Error: Cannot enable upload scanning in ProFTPD because there is no ClamAV (${CLAMDSCAN_BIN}) on the system."
      exit 1
    fi

    pkgi ${PORT_PROFTPD_CLAMAV}

    ## Verify:
    if ! grep -m1 -q "^Include ${PROFTPD_CLAMAV_CONF}" /usr/local/etc/proftpd.conf; then
      perl -pi -e 's#</Global>#</Global>\n\nInclude ${PROFTPD_CLAMAV_CONF}#' /usr/local/etc/proftpd.conf
    fi

    /usr/local/bin/prxs -c -i -d mod_clamav.c

    {
      #echo -n ''
      echo '<IfModule mod_dso.c>'
      echo '  LoadModule mod_clamav.c'
      echo '</IfModule>'
      echo '<IfModule mod_clamav.c>'
      echo '  ClamAV on'
      echo '  ClamServer 127.0.0.1'
      echo '  ClamPort 3310'
      echo '  ClamMaxSize 5 Mb'
      echo '</IfModule>'
    } > ${PROFTPD_CLAMAV_CONF}

    # <IfModule mod_clamav.c>
    #   ClamAV on
    #   ClamServer localhost
    #   ClamPort 3310
    # </IfModule>

  else
    ## Truncate the configuration file
    echo "" > ${PROFTPD_CLAMAV_CONF}
  fi

  # /usr/local/libexec/proftpd --configtest

  echo "Starting ProFTPD"
  ${SERVICE} proftpd restart

  return
}

################################################################

## ProFTPD Uninstall
proftpd_uninstall() {

  ${SERVICE} proftpd stop

  pkg delete -f proftpd

  sysrc -x proftpd_enable
  sysrc -x proftpd_flags

  return
}

################################################################################################################################

## ClamAV Installation Tasks
clamav_install() {

  if [ "${OPT_CLAMAV}" = "NO" ]; then
    echo "*** Error: ClamAV not enabled in options.conf"
    return
  fi

  ### Main Installation
  if [ "${CLAMAV_MAKE_SET}" = "" ] && [ "${CLAMAV_MAKE_UNSET}" = "" ] ; then
    pkgi ${PORT_CLAMAV}
  else
    make -DNO_DIALOG -C "${PORTS_BASE}/${PORT_CLAMAV}" rmconfig
    make -DNO_DIALOG -C "${PORTS_BASE}/${PORT_CLAMAV}" security_clamav_SET="${CLAMAV_MAKE_SET}" security_clamav_UNSET="${CLAMAV_MAKE_UNSET}" OPTIONS_SET="${GLOBAL_MAKE_SET}" OPTIONS_UNSET="${GLOBAL_MAKE_UNSET}" reinstall clean
  fi

  ## Verify:
  if [ "${OPT_CLAMAV_WITH_EXIM}" = "YES" ]; then
    ${WGET} -O /usr/local/etc/exim/exim.clamav.load.conf "${PB_MIRROR}/exim/exim.clamav.load.conf"
    ${WGET} -O /usr/local/etc/exim/exim.clamav.conf "${PB_MIRROR}/exim/exim.clamav.conf"
  fi

  ## Verify:
  if [ ! -e "${CLAMD_CONF}" ]; then
    if [ ! -s "${CLAMD_CONF}" ] && [ -s /usr/local/etc/clamd.conf.sample ]; then
      cp -f /usr/local/etc/clamd.conf.sample "${CLAMD_CONF}"
    fi

    ${PERL} -pi -e 's|Example|#Example|' "${CLAMD_CONF}"
    ${PERL} -pi -e 's|#PidFile /var/run/clamd.pid|PidFile /var/run/clamd/clamd.pid|' "${CLAMD_CONF}"
    ${PERL} -pi -e 's|#TCPSocket 3310|TCPSocket 3310|' "${CLAMD_CONF}"
    ${PERL} -pi -e 's|#TCPAddr 127.0.0.1|TCPAddr 127.0.0.1|' "${CLAMD_CONF}"
    ${PERL} -pi -e 's|^LocalSocket|#LocalSocket|' "${CLAMD_CONF}"
  fi

  ## Verify:
  if [ ! -e "${FRESHCLAM_CONF}" ]; then
    if [ ! -s "${FRESHCLAM_CONF}" ] && [ -s /usr/local/etc/freshclam.conf.sample ]; then
      cp -f /usr/local/etc/freshclam.conf.sample "${FRESHCLAM_CONF}"
    fi

    ${PERL} -pi -e 's|Example|#Example|' "${FRESHCLAM_CONF}"
    ${PERL} -pi -e 's|#LogSyslog yes|LogSyslog yes|' "${FRESHCLAM_CONF}"
    ${PERL} -pi -e 's|#PidFile /var/run/freshclam.pid|PidFile /var/run/clamd/freshclam.pid|' "${FRESHCLAM_CONF}"
    ${PERL} -pi -e 's|#Checks 24|#Checks 24|' "${FRESHCLAM_CONF}"
    ${PERL} -pi -e 's|#NotifyClamd /path/to/clamd.conf|#NotifyClamd /usr/local/etc/clamd.conf|' "${FRESHCLAM_CONF}"
  fi

  ## Verify:
  if [ "${OPT_CLAMAV_WITH_EXIM}" = "YES" ]; then
    ${PERL} -pi -e 's|#.include_if_exists /usr/local/etc/exim.clamav.load.conf|.include_if_exists /usr/local/etc/exim/exim.clamav.load.conf|' "${EXIM_CONF}"
    ${PERL} -pi -e 's|#.include_if_exists /usr/local/etc/exim.clamav.conf|.include_if_exists /usr/local/etc/exim/exim.clamav.conf|' "${EXIM_CONF}"
  fi

  sysrc clamav_clamd_enable="YES"
  sysrc clamav_freshclam_enable="YES"

  ${SERVICE} clamav-clamd start
  ${SERVICE} clamav-freshclam start

  if [ "${OPT_CLAMAV_WITH_EXIM}" = "YES" ]; then
    echo "Restarting Exim"
    ${SERVICE} exim restart
  fi

  return
}

################################################################

## ClamAV Uninstall
clamav_uninstall() {

  ${SERVICE} clamav-clamd stop
  ${SERVICE} clamav-freshclam stop

  ${PKG} delete -f clamav

  sysrc -x clamav_clamd_enable
  sysrc -x clamav_freshclam_enable

  return
}

################################################################################################################################

## RoundCube Installation
roundcube_install() {

  if [ "${OPT_ROUNDCUBE}" = "NO" ]; then
    echo "*** Error: RoundCube not enabled in options.conf"
    return
  fi

  ### Main Installation
  if [ "${ROUNDCUBE_MAKE_SET}" = "" ] && [ "${ROUNDCUBE_MAKE_UNSET}" = "" ] ; then
    pkgi ${PORT_ROUNDCUBE}
  else
    make -DNO_DIALOG -C "${PORTS_BASE}/${PORT_ROUNDCUBE}" rmconfig
    make -DNO_DIALOG -C "${PORTS_BASE}/${PORT_ROUNDCUBE}" mail_roundcube_SET="${ROUNDCUBE_MAKE_SET}" mail_roundcube_UNSET="${ROUNDCUBE_MAKE_UNSET}" OPTIONS_SET="${GLOBAL_MAKE_SET}" OPTIONS_UNSET="${GLOBAL_MAKE_UNSET}" reinstall clean
  fi

  ### Post-Installation Tasks

  ## Clarifications
  # _CONF = RC's config.inc.php
  # _CNF  = RC's SQL settings
  # _PATH = path to RC

  ## PB: Verify:
  ## CB2: verify_webapps_logrotate

  ## Fetch MySQL Settings from directadmin/conf/my.cnf
  get_sql_settings

  ## ROUNDCUBE_ALIAS_PATH=${WWW_DIR}/roundcube
  ## ROUNDCUBE_CONFIG_DB= custom config from CB2
  #ROUNDCUBE_PATH=${WWW_DIR}/roundcube

  ## Generate new credentials for the database:
  ROUNDCUBE_DB=da_roundcube
  ROUNDCUBE_DB_USER=da_roundcube
  ROUNDCUBE_DB_PASS=$(random_pass 12)
  ROUNDCUBE_DES_KEY=$(random_pass 24)
  ROUNDCUBE_MY_CNF=${ROUNDCUBE_PATH}/config/my.cnf
  ROUNDCUBE_CONF_SAMPLE=${ROUNDCUBE_PATH}/config/config.inc.php.sample

  if [ ! -e "${ROUNDCUBE_PATH}" ]; then
    echo "*** Error: RoundCube does not exist at: ${ROUNDCUBE_PATH}"
    exit 1
  fi

  ## PB: Verify:
  ## Copy log files and temp directory from Alias to Real path
  # if [ -e ${ROUNDCUBE_PATH_ALIAS} ]; then
  #     if [ -d ${ROUNDCUBE_PATH_ALIAS}/logs ]; then
  #         cp -fR ${ROUNDCUBE_PATH_ALIAS}/logs ${ROUNDCUBE_PATH} >/dev/null 2>&1
  #     fi
  #     if [ -d ${ROUNDCUBE_PATH_ALIAS}/temp ]; then
  #         cp -fR ${ROUNDCUBE_PATH_ALIAS}/temp ${ROUNDCUBE_PATH} >/dev/null 2>&1
  #     fi
  # fi

  ## PB: 2016-03-12: not needed since ports/pkg always installs RC in the same place
  ## CB2: Delete alias (symlink) and relink it from a fake (new alias) path:
  # /bin/rm -f ${ALIASPATH}
  # /bin/ln -sf roundcubemail-${ROUNDCUBE_VER} ${ALIASPATH}

  ## Set permissions (use -h on alias path):
  chown ${WEBAPPS_USER}:${WEBAPPS_USER} ${ROUNDCUBE_PATH}

  cd ${ROUNDCUBE_PATH} || exit

  #EDIT_CONFIG=config.inc.php
  # Use: ${ROUNDCUBE_CONF}
  #CONFIG_DIST=config.inc.php.sample
  # EDIT_DB=${EDIT_CONFIG}
  # DB_DIST=${CONFIG_DIST}

  ## New installations of RoundCube
  if ! ${MYSQLSHOW} --defaults-extra-file=${DA_MYSQL_CNF} --host=${MYSQL_HOST} | grep -m1 -q ' da_roundcube '; then
    ## Insert data to SQL DB and create RoundCube database and user
    if [ -d "${ROUNDCUBE_PATH}/SQL" ]; then
      echo "Creating RoundCube SQL user and database."
      ${MYSQL} --defaults-extra-file=${DA_MYSQL_CNF} -e "CREATE DATABASE ${ROUNDCUBE_DB};" --host=${MYSQL_HOST} 2>&1
      ${MYSQL} --defaults-extra-file=${DA_MYSQL_CNF} -e "GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,ALTER,LOCK TABLES,INDEX ON ${ROUNDCUBE_DB}.* TO '${ROUNDCUBE_DB_USER}'@'${MYSQL_ACCESS_HOST}' IDENTIFIED BY '${ROUNDCUBE_DB_PASS}';" --host=${MYSQL_HOST} 2>&1

      ## External SQL server
      if [ "${MYSQL_HOST}" != "localhost" ]; then
        grep '^access_host.*=' ${DA_MYSQL_CONF} | cut -d= -f2 | while IFS= read -r access_host_ip
        do
          ${MYSQL} --defaults-extra-file=${DA_MYSQL_CNF} -e "GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,ALTER,LOCK TABLES,INDEX ON ${ROUNDCUBE_DB}.* TO '${ROUNDCUBE_DB_USER}'@'${access_host_ip}' IDENTIFIED BY '${ROUNDCUBE_DB_PASS}';" --host=${MYSQL_HOST} 2>&1
        done
      fi

      ## PB: Needed?
      ## Recreate RoundCube sql.cnf
      rm -f ${ROUNDCUBE_MY_CNF}
      verify_my_cnf ${ROUNDCUBE_MY_CNF} "${ROUNDCUBE_DB_USER}" "${ROUNDCUBE_DB_PASS}"

      ## Import RoundCube's initial.sql file to initialize the necessary database tables
      ${MYSQL} --defaults-extra-file=${ROUNDCUBE_MY_CNF} -e "use ${ROUNDCUBE_DB}; source ${ROUNDCUBE_PATH}/SQL/mysql.initial.sql;" --host=${MYSQL_HOST} 2>&1

      echo "Database created, ${ROUNDCUBE_DB_USER} password is ${ROUNDCUBE_DB_PASS}"
    else
      echo "*** Error: Cannot find the SQL directory in ${ROUNDCUBE_PATH}"
      exit 1
    fi
  else ## Existing RoundCube database found
    ## RoundCube config & database already exists, so fetch existing values (from custom configuration?):
    if [ -e "${ROUNDCUBE_CONF}" ]; then
      COUNT_MYSQL=$(grep -m1 -c 'mysql://' ${ROUNDCUBE_CONF})
      if [ "${COUNT_MYSQL}" -gt 0 ]; then
          PART1=$(grep -m1 "\$config\['db_dsnw'\]" ${ROUNDCUBE_CONF} | awk '{print $3}' | cut -d\@ -f1 | cut -d'/' -f3)
          ROUNDCUBE_DB_USER=$(echo "${PART1}" | cut -d\: -f1)
          ROUNDCUBE_DB_PASS=$(echo "${PART1}" | cut -d\: -f2)
          PART2=$(grep -m1 "\$config\['db_dsnw'\]" ${ROUNDCUBE_CONF} | awk '{print $3}' | cut -d\@ -f2 | cut -d\' -f1)
          MYSQL_ACCESS_HOST=$(echo "${PART2}" | cut -d'/' -f1)
          ROUNDCUBE_DB=$(echo "${PART2}" | cut -d'/' -f2)
      fi
    fi

    ## Grant access and set password
    ${MYSQL} --defaults-extra-file=${DA_MYSQL_CNF} -e "GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,ALTER,LOCK TABLES,INDEX ON ${ROUNDCUBE_DB}.* TO '${ROUNDCUBE_DB_USER}'@'${MYSQL_ACCESS_HOST}' IDENTIFIED BY '${ROUNDCUBE_DB_PASS}';" --host=${MYSQL_HOST} 2>&1
    ${MYSQL} --defaults-extra-file=${DA_MYSQL_CNF} -e "SET PASSWORD FOR '${ROUNDCUBE_DB_USER}'@'${MYSQL_ACCESS_HOST}' = PASSWORD('${ROUNDCUBE_DB_PASS}');" --host=${MYSQL_HOST}

    ## External SQL server
    if [ "${MYSQL_HOST}" != "localhost" ]; then
      grep '^access_host.*=' ${DA_MYSQL_CONF} | cut -d= -f2 | while IFS= read -r access_host_ip
      do
        ${MYSQL} --defaults-extra-file=${DA_MYSQL_CNF} -e "GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,ALTER,LOCK TABLES,INDEX ON ${ROUNDCUBE_DB}.* TO '${ROUNDCUBE_DB_USER}'@'${access_host_ip}' IDENTIFIED BY '${ROUNDCUBE_DB_PASS}';" --host=${MYSQL_HOST} 2>&1
        ${MYSQL} --defaults-extra-file=${DA_MYSQL_CNF} -e "SET PASSWORD FOR '${ROUNDCUBE_DB_USER}'@'${access_host_ip}' = PASSWORD('${ROUNDCUBE_DB_PASS}');" --host=${MYSQL_HOST} 2>&1
      done
    fi

    ## PB: needed?
    ## Recreate RoundCube sql.cnf
    ## CB2: delete existing file, in case anyone uses it for backups
    rm -f ${ROUNDCUBE_MY_CNF}
    verify_my_cnf ${ROUNDCUBE_MY_CNF} "${ROUNDCUBE_DB_USER}" "${ROUNDCUBE_DB_PASS}"
  fi

  ## PB2: Verify:
  ## CB2: Cleanup editing config
  #rm -f ${ROUNDCUBE_CONF}

  ## Install the proper config (e.g. stock or custom):
  if [ -d "${ROUNDCUBE_PATH}" ]; then
    echo "Editing roundcube configuration..."

    cd ${ROUNDCUBE_PATH}/config || exit

    ## PB: Todo: RoundCube Custom Configuration
    if [ -e "${CUSTOM_ROUNDCUBE_CONFIG}" ]; then
      echo "Installing custom RoundCube configuration file: ${CUSTOM_ROUNDCUBE_CONFIG}"
     cp -f "${CUSTOM_ROUNDCUBE_CONFIG}" ${ROUNDCUBE_CONF}
    fi

    if [ -e "${ROUNDCUBE_CONFIG_DB}" ]; then
      if [ ! -e ${ROUNDCUBE_CONF} ]; then
        /bin/cp -f "${ROUNDCUBE_CONFIG_DB}" ${ROUNDCUBE_CONF}
      fi

      if [ "${COUNT_MYSQL}" -eq 0 ]; then ## if no "mysql://"" is found (tested above)
        echo "\$config['db_dsnw'] = 'mysql://${ROUNDCUBE_DB_USER}:${ROUNDCUBE_DB_PASS}@${MYSQL_HOST}/${ROUNDCUBE_DB}';" >> ${ROUNDCUBE_CONF}
      fi
    else
      if [ ! -e ${ROUNDCUBE_CONF} ]; then
        /bin/cp -f ${ROUNDCUBE_CONF_SAMPLE} ${ROUNDCUBE_CONF}
        ${PERL} -pi -e "s|mysql://roundcube:pass\@localhost/roundcubemail|mysql://${ROUNDCUBE_DB_USER}:\\Q${ROUNDCUBE_DB_PASS}\\E\@${MYSQL_HOST}/${ROUNDCUBE_DB}|" ${ROUNDCUBE_CONF} > /dev/null
        ${PERL} -pi -e "s/\'mdb2\'/\'db\'/" ${ROUNDCUBE_CONF} > /dev/null
      fi
    fi

    SPAM_INBOX_PREFIX=$(getDA_Opt spam_inbox_prefix 1)
    SPAM_FOLDER="INBOX.spam"

    if [ "${SPAM_INBOX_PREFIX}" = "0" ]; then
      SPAM_FOLDER="Junk"
    fi

    ${PERL} -pi -e "s|rcmail-\!24ByteDESkey\*Str|\\Q${ROUNDCUBE_DES_KEY}\\E|" ${ROUNDCUBE_CONF}

    if [ ! -e "${ROUNDCUBE_CONF}" ]; then
      ## CB2: These ones are already in config.inc.php.sample file, so we just use perl-regex to change them
      ${PERL} -pi -e "s|\['smtp_port'] = 25|\['smtp_port'] = 587|" ${ROUNDCUBE_CONF} > /dev/null
      ${PERL} -pi -e "s|\['smtp_server'] = ''|\['smtp_server'] = 'localhost'|" ${ROUNDCUBE_CONF} > /dev/null
      ${PERL} -pi -e "s|\['smtp_user'] = ''|\['smtp_user'] = '%u'|" ${ROUNDCUBE_CONF} > /dev/null
      ${PERL} -pi -e "s|\['smtp_pass'] = ''|\['smtp_pass'] = '%p'|" ${ROUNDCUBE_CONF} > /dev/null

      ## CB2: Changing default options that are set in defaults.inc.php
      ## Add "Inbox" prefix to IMAP folders (if requested)
      if [ "${OPT_WEBAPPS_INBOX_PREFIX}" = "YES" ]; then
        {
          echo "\$config['drafts_mbox'] = 'INBOX.Drafts';"
          echo "\$config['junk_mbox'] = '${SPAM_FOLDER}';"
          echo "\$config['sent_mbox'] = 'INBOX.Sent';"
          echo "\$config['trash_mbox'] = 'INBOX.Trash';"
          echo "\$config['default_folders'] = array('INBOX', 'INBOX.Drafts', 'INBOX.Sent', '${SPAM_FOLDER}', 'INBOX.Trash');"
        } >> ${ROUNDCUBE_CONF}
      else
        echo "\$config['junk_mbox'] = '${SPAM_FOLDER}';" >> ${ROUNDCUBE_CONF}
        echo "\$config['default_folders'] = array('INBOX', 'Drafts', 'Sent', '${SPAM_FOLDER}', 'Trash');" >> ${ROUNDCUBE_CONF}
      fi

      ## Hostname used for SMTP helo host:
      HN_T=$(hostname)

      {
        echo "\$config['smtp_helo_host'] = '${HN_T}';"
        echo "\$config['smtp_auth_type'] = 'LOGIN';"
        echo "\$config['create_default_folders'] = true;"
        echo "\$config['protect_default_folders'] = true;"
        echo "\$config['login_autocomplete'] = 2;"
        echo "\$config['quota_zero_as_unlimited'] = true;"
        echo "\$config['enable_spellcheck'] = false;"
        echo "\$config['email_dns_check'] = true;"
      } >> ${ROUNDCUBE_CONF}

      ## Get recipients_max from exim.conf
      if grep -q '^recipients_max' ${EXIM_CONF}; then
        EXIM_RECIPIENTS_MAX="$(grep -m1 '^recipients_max' ${EXIM_CONF} | cut -d= -f2 | tr -d ' ')"
        echo "\$config['max_recipients'] = ${EXIM_RECIPIENTS_MAX};" >> ${ROUNDCUBE_CONF}
        echo "\$config['max_group_members'] = ${EXIM_RECIPIENTS_MAX};" >> ${ROUNDCUBE_CONF}
      fi

      ## mime.types
      if [ ! -s "${ROUNDCUBE_PATH}/config/mime.types" ]; then
        if [ "${OPT_WEBSERVER}" = "apache" ] || [ "${OPT_WEBSERVER}" = "litespeed" ] || [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
          if [ -s ${APACHE_MIME_TYPES} ]; then
            if grep -m1 -q 'application/java-archive' ${APACHE_MIME_TYPES}; then
              cp -f ${APACHE_MIME_TYPES} ${ROUNDCUBE_PATH}/config/mime.types
            fi
          fi
        fi
      fi

      ## Download a fresh copy of mime.types from Apache's repo
      if [ ! -s "${ROUNDCUBE_PATH}/config/mime.types" ]; then
        ${WGET} -O "${ROUNDCUBE_PATH}/config/mime.types" http://svn.apache.org/repos/asf/httpd/httpd/trunk/docs/conf/mime.types 2> /dev/null
      fi

      echo "\$config['mime_types'] = '${ROUNDCUBE_PATH}/config/mime.types';" >> ${ROUNDCUBE_CONF}

      ## DirectAdmin Password plugin
      if [ -e ${ROUNDCUBE_PATH}/plugins/password ]; then
        ${PERL} -pi -e "s|\['plugins'] = array\(\n|\['plugins'] = array\(\n    'password',\n|" ${ROUNDCUBE_CONF} > /dev/null

        cd ${ROUNDCUBE_PATH}/plugins/password || exit

        if [ ! -e config.inc.php ]; then
          cp config.inc.php.dist config.inc.php
        fi

        ${PERL} -pi -e "s|\['password_driver'] = 'sql'|\['password_driver'] = 'directadmin'|" ${ROUNDCUBE_CONF} > /dev/null

        if [ -e ${DA_BIN} ]; then
          DA_PORT=$(/usr/local/directadmin/directadmin c | grep -m1 -e '^port=' | cut -d= -f2)
          ${PERL} -pi -e "s|\['password_directadmin_port'] = 2222|\['password_directadmin_port'] = $DA_PORT|" ${ROUNDCUBE_CONF} > /dev/null

          DA_SSL=$(/usr/local/directadmin/directadmin c | grep -m1 -e '^ssl=' | cut -d= -f2)
          if [ "$DA_SSL" -eq 1 ]; then
            ${PERL} -pi -e "s|\['password_directadmin_host'] = 'tcp://localhost'|\['password_directadmin_host'] = 'ssl://localhost'|" ${ROUNDCUBE_CONF} > /dev/null
          fi
        fi
        cd ${ROUNDCUBE_PATH}/config || exit
      fi

      ## Pigeonhole plugin (untested):
      if [ "${OPT_PIGEONHOLE}" = "YES" ]; then
        if [ -d ${ROUNDCUBE_PATH}/plugins/managesieve ]; then

          if [ "$(grep -m1 -c "'managesieve'" ${ROUNDCUBE_CONF})" -eq 0 ]; then
              ${PERL} -pi -e "s|\['plugins'] = array\(\n|\['plugins'] = array\(\n    'managesieve',\n|" ${ROUNDCUBE_CONF} > /dev/null
          fi

          cd ${ROUNDCUBE_PATH}/plugins/managesieve || exit

          if [ ! -e config.inc.php ]; then
            cp config.inc.php.dist config.inc.php
          fi

          ${PERL} -pi -e "s|\['managesieve_port'] = null|\['managesieve_port'] = 4190|" config.inc.php > /dev/null

          cd ${ROUNDCUBE_PATH}/config || exit
        fi
      fi
    fi

    ## Custom configurations for RoundCube:
    if [ -d "${ROUNDCUBE_PLUGINS}" ]; then
      echo "Copying files from ${ROUNDCUBE_PLUGINS} to ${ROUNDCUBE_PATH}/plugins"
      cp -Rp "${ROUNDCUBE_PLUGINS}/*" ${ROUNDCUBE_PATH}/plugins
    fi

    if [ -d "${ROUNDCUBE_SKINS}" ]; then
      echo "Copying files from ${ROUNDCUBE_SKINS} to ${ROUNDCUBE_PATH}/skins"
      cp -Rp "${ROUNDCUBE_SKINS}/*" ${ROUNDCUBE_PATH}/skins
    fi

    if [ -d "${ROUNDCUBE_PROGRAM}" ]; then
      echo "Copying files from ${ROUNDCUBE_PROGRAM} to ${ROUNDCUBE_PATH}/program"
      cp -Rp "${ROUNDCUBE_PROGRAM}/*" ${ROUNDCUBE_PATH}/program
    fi

    if [ -e "${ROUNDCUBE_HTACCESS}" ]; then
      echo "Copying .htaccess file from ${ROUNDCUBE_HTACCESS} to ${ROUNDCUBE_PATH}/.htaccess"
      cp -pf "${ROUNDCUBE_HTACCESS}" ${ROUNDCUBE_PATH}/.htaccess
    fi

    #echo "Roundcube ${ROUNDCUBE_VER} has been installed successfully."
  fi

  ## CB2: systems with "system()" in disable_functions need to use no php.ini:
  if [ "$(have_php_system)" = "0" ]; then
    ${PERL} -pi -e 's#^\#\!/usr/bin/env php#\#\!/usr/local/bin/php \-n#' "${ROUNDCUBE_PATH}/bin/update.sh"
  fi

  ## Systems with suhosin cannot have PHP memory_limit set to -1. Must prevent suhosin from loading for RoundCube's .sh scripts
  if [ "${OPT_SUHOSIN}" = "YES" ]; then
    ${PERL} -pi -e 's#^\#\!/usr/bin/env php#\#\!/usr/local/bin/php \-n#' ${ROUNDCUBE_PATH}/bin/msgimport.sh
    ${PERL} -pi -e 's#^\#\!/usr/bin/env php#\#\!/usr/local/bin/php \-n#' ${ROUNDCUBE_PATH}/bin/indexcontacts.sh
    ${PERL} -pi -e 's#^\#\!/usr/bin/env php#\#\!/usr/local/bin/php \-n#' ${ROUNDCUBE_PATH}/bin/msgexport.sh
  fi

  ## Update if needed:
  # ${ROUNDCUBE_PATH}/bin/update.sh '--version=?'

  ## Cleanup:
  rm -rf ${ROUNDCUBE_PATH}/installer

  ## Set the permissions:
  chown -R ${WEBAPPS_USER}:${WEBAPPS_USER} ${ROUNDCUBE_PATH}

  ## PB: Verify this (770 compatible with FPM?):
  if [ "${WEBAPPS_GROUP}" = "apache" ]; then
    chown -R apache ${ROUNDCUBE_PATH}/temp ${ROUNDCUBE_PATH}/logs
    /bin/chmod -R 770 ${ROUNDCUBE_PATH}/temp
    /bin/chmod -R 770 ${ROUNDCUBE_PATH}/logs
  fi

  ## Secure the configuration file:
  if [ -s ${ROUNDCUBE_CONF} ]; then
    chmod 440 ${ROUNDCUBE_CONF}

    # if [ "${WEBAPPS_GROUP}" = "apache" ]; then
    #   echo "**********************************************************************"
    #   echo "* "
    #   echo "* SECURITY: ${ROUNDCUBE_PATH}/config/${EDIT_DB} is readable by apache."
    #   echo "* Recommended: use a php type that runs php scripts as the User, then re-install roundcube."
    #   echo "*"
    #   echo "**********************************************************************"
    # fi

    chown ${WEBAPPS_USER}:${WEBAPPS_GROUP} ${ROUNDCUBE_CONF}

    if [ "${WEBAPPS_GROUP}" = "apache" ]; then
      ls -la ${ROUNDCUBE_PATH}/config/${ROUNDCUBE_CONF}
      sleep 5
    fi
  fi

  RC_HTACCESS=${ROUNDCUBE_PATH}/.htaccess

  if [ -s "${RC_HTACCESS}" ]; then
    if grep -m1 -q upload_max_filesize ${RC_HTACCESS}; then
      ${PERL} -pi -e 's/^php_value\supload_max_filesize/#php_value       upload_max_filesize/' ${RC_HTACCESS}
      ${PERL} -pi -e 's/^php_value\spost_max_size/#php_value       post_max_size/' ${RC_HTACCESS}
    fi

    ${PERL} -pi -e 's/FollowSymLinks/SymLinksIfOwnerMatch/' ${RC_HTACCESS}
  fi

  verify_webapps_tmp

  #cd ${CWD}
}

################################################################################################################################

## Webapps Installation
webapps_install() {

  ### Pre-Installation Tasks

  ## Create user and group:
  /usr/sbin/pw groupadd ${WEBAPPS_GROUP}
  /usr/sbin/pw useradd -g ${WEBAPPS_GROUP} -n ${WEBAPPS_USER} -b ${WWW_DIR} -s /sbin/nologin

  ## Set permissions on temp directory:
  if [ "${OPT_PHP1_MODE}" = "php-fpm" ]; then
    chmod 755 ${WWW_DIR}/tmp
  else
    chmod 777 ${WWW_DIR}/tmp
  fi

  ## Temp path: /usr/local/www/webmail/tmp
  ## Create webmail/tmp directory:
  ## Verify whether 770 will work or not (750 for FPM?)
  mkdir -p ${WWW_DIR}/webmail/tmp
  chmod -R 770 ${WWW_DIR}/webmail/tmp
  chown -R ${WEBAPPS_USER}:${WEBAPPS_GROUP} ${WWW_DIR}/webmail
  chown -R ${APACHE_USER}:${WEBAPPS_GROUP} ${WWW_DIR}/webmail/tmp
  echo "Deny from All" >> ${WWW_DIR}/webmail/tmp/.htaccess

  ### Main Installation



  ### Post-Installation Tasks

  ## Increase the timeout from 10 minutes to 24
  ${PERL} -pi -e 's/idle_timeout = 10/idle_timeout = 24/' "${WWW_DIR}/webmail/inc/config.security.php"
  ${PERL} -pi -e 's#\$temporary_directory = "./database/";#\$temporary_directory = "./tmp/";#' "${WWW_DIR}/webmail/inc/config.php"
  ${PERL} -pi -e 's/= "ONE-FOR-EACH";/= "ONE-FOR-ALL";/' "${WWW_DIR}/webmail/inc/config.php"
  ${PERL} -pi -e 's#\$smtp_server = "SMTP.DOMAIN.COM";#\$smtp_server = "localhost";#' "${WWW_DIR}/webmail/inc/config.php"
  # ${PERL} -pi -e 's#\$default_mail_server = "POP3.DOMAIN.COM";#\$default_mail_server = "localhost";#' "${WWW_DIR}/webmail/inc/config.php"
  ${PERL} -pi -e 's/POP3.DOMAIN.COM/localhost/' "${WWW_DIR}/webmail/inc/config.php"

  ## Get rid of installation directory:
  rm -rf "${WWW_DIR}/webmail/install"

  ## Copy redirect.php (done):
  cp -f ${DA_PATH}/scripts/redirect.php ${WWW_DIR}/redirect.php
}

################################################################################################################################

## Secure php.ini (copied from CB2)
## $1 = php.ini file to update
secure_php_ini() {
  if [ -e "$1" ]; then
    if grep -m1 -q -e disable_functions "$1"; then
      CURRENT_DISABLE_FUNCT="$(grep -m1 'disable_functions' "$1")"
      NEW_DISABLE_FUNCT="exec,system,passthru,shell_exec,escapeshellarg,escapeshellcmd,proc_close,proc_open,dl,popen,show_source,posix_kill,posix_mkfifo,posix_getpwuid,posix_setpgid,posix_setsid,posix_setuid,posix_setgid,posix_seteuid,posix_setegid,posix_uname"
      ${PERL} -pi -e "s#${CURRENT_DISABLE_FUNCT}#disable_functions \= ${NEW_DISABLE_FUNCT}#" "$1"
    else
      echo "disable_functions = ${NEW_DISABLE_FUNCT}" >> "$1"
    fi

    ${PERL} -pi -e 's/^register_globals = On/register_globals = Off/' "$1"
    ${PERL} -pi -e 's/^mysql.allow_local_infile = On/mysql.allow_local_infile = Off/' "$1"
    ${PERL} -pi -e 's/^mysqli.allow_local_infile = On/mysqli.allow_local_infile = Off/' "$1"
    ${PERL} -pi -e 's/^;mysqli.allow_local_infile = On/mysqli.allow_local_infile = Off/' "$1"
    ${PERL} -pi -e 's/^expose_php = On/expose_php = Off/' "$1"
  fi
}

################################################################################################################################

## Ensure Webapps php.ini (copied from CB2)
verify_webapps_php_ini() {

  # ${PHP_INI_WEBAPPS} = /usr/local/etc/php/50-webapps.ini
  # ${WWW_TMP_DIR} = /usr/local/www/tmp

  if [ "${OPT_PHP1_MODE}" = "mod_php" ]; then
      PHP_INI_WEBAPPS=/usr/local/lib/php.conf.d/50-webapps.ini
      mkdir -p /usr/local/lib/php.conf.d
  else
      PHP_INI_WEBAPPS=/usr/local/php${OPT_PHP1_VERSION}/lib/php.conf.d/50-webapps.ini
      mkdir -p "/usr/local/php${OPT_PHP1_VERSION}/lib/php.conf.d"
  fi

  ## Copy custom/ file (not implemented)
  if [ -e "${PHP_CUSTOM_PHP_CONF_D_INI_PATH}/50-webapps.ini" ]; then
    echo "Using custom ${PHP_CUSTOM_PHP_CONF_D_INI_PATH}/50-webapps.ini for ${PHP_INI_WEBAPPS}"
    cp -f "${PHP_CUSTOM_PHP_CONF_D_INI_PATH}/50-webapps.ini" "${PHP_INI_WEBAPPS}"
  else
    {
      echo "[PATH=${WWW_DIR}]"
      echo "session.save_path=${WWW_TMP_DIR}"
      echo "upload_tmp_dir=${WWW_TMP_DIR}"
      echo "disable_functions=exec,system,passthru,shell_exec,escapeshellarg,escapeshellcmd,proc_close,proc_open,dl,popen,show_source,posix_kill,posix_mkfifo,posix_getpwuid,posix_setpgid,posix_setsid,posix_setuid,posix_setgid,posix_seteuid,posix_setegid,posix_uname"
    } >> "${PHP_INI_WEBAPPS}"
  fi
}

################################################################################################################################

## Verify Webapps Temp Directory (copied from CB2)
verify_webapps_tmp() {
  if [ ! -d "{$WWW_TMP_DIR}" ]; then
    mkdir -p ${WWW_TMP_DIR}
  fi

  ## Verify: 770 compatible with FPM?
  chmod 770 ${WWW_TMP_DIR}
  chown ${WEBAPPS_USER}:${WEBAPPS_GROUP} ${WWW_TMP_DIR}

  verify_webapps_php_ini
}

################################################################################################################################

## Apache Host Configuration (copied from CB2)
#do_ApacheHostConf() {
apache_rewrite_confs() {

  if [ "${OPT_WEBSERVER}" = "apache" ]; then

    APACHE_HOST_CONF=${APACHE_EXTRA_PATH}/httpd-hostname.conf

    ## Copy custom/ file
    ## APACHE_HOST_CONF_CUSTOM
    if [ -e "${PB_PATH}/custom/ap2/conf/extra/httpd-hostname.conf" ]; then
      cp -pf "${PB_PATH}/custom/ap2/conf/extra/httpd-hostname.conf" ${APACHE_HOST_CONF}
    else
      {
        if [ "${HAVE_FPM_CGI}" = "YES" ]; then
          echo 'SetEnvIfNoCase ^Authorization$ "(.+)" HTTP_AUTHORIZATION=$1'
        fi
        echo "<Directory ${WWW_DIR}>"
        if [ "${OPT_PHP1_MODE}" = "php-fpm" ]; then
            echo '<FilesMatch "\.(inc|php|php3|php4|php44|php5|php52|php53|php54|php55|php56|php70|php6|phtml|phps)$">'
            echo "  AddHandler \"proxy:unix:/usr/local/php${OPT_PHP1_VERSION}/sockets/webapps.sock|fcgi://localhost\" .inc .php .php5 .php${OPT_PHP1_VERSION} .phtml"
            echo "</FilesMatch>"
        fi
        echo "  Options +SymLinksIfOwnerMatch +IncludesNoExec"
        echo "  AllowOverride AuthConfig FileInfo Indexes Limit Options=Includes,IncludesNOEXEC,Indexes,ExecCGI,MultiViews,SymLinksIfOwnerMatch,None"
        echo ""
        echo "  Order Allow,Deny"
        echo "  Allow from all"
        echo "  <IfModule mod_suphp.c>"
        echo "    suPHP_Engine On"
        echo "    suPHP_UserGroup ${WEBAPPS_USER} ${WEBAPPS_GROUP}"
        echo "  </IfModule>"
      } > ${APACHE_HOST_CONF}

      ## Unsupported:
      # {
      #  echo '    <IfModule mod_ruid2.c>'
      #  echo '        RUidGid webapps webapps'
      #  echo '    </IfModule>'
      #  echo '    <IfModule mod_lsapi.c>'
      #  echo '        lsapi_user_group webapps webapps'
      #  echo '    </IfModule>'
      # } >> ${APACHE_HOST_CONF}

      verify_webapps_tmp

      # WEBAPPS_FCGID_DIR=/var/www/fcgid
      SUEXEC_PER_DIR="0"

      if [ -s /usr/local/sbin/suexec ]; then
        SUEXEC_PER_DIR=$(/usr/local/sbin/suexec -V 2>&1 | grep -c 'AP_PER_DIR')
      fi

      ## PHP1: FastCGI:
      if [ "${OPT_PHP1_MODE}" = "fastcgi" ]; then
        {
          echo "  <IfModule mod_fcgid.c>"
          echo "    FcgidWrapper /usr/local/safe-bin/fcgid${OPT_PHP1_VERSION}.sh .php"
          if [ "${SUEXEC_PER_DIR}" -gt 0 ]; then
            printf "  SuexecUserGroup %s %s" "${WEBAPPS_USER}" "${WEBAPPS_GROUP}"
          fi
          echo '    <FilesMatch "\.(inc|php|php3|php4|php44|php5|php52|php53|php54|php55|php56|php70|php6|phtml|phps)$">'
          echo "      Options +ExecCGI"
          echo "      AddHandler fcgid-script .php"
          echo "    </FilesMatch>"
          echo "  </IfModule>"
        } >> ${APACHE_HOST_CONF}
      fi

      ## PHP2: FastCGI:
      if [ "${OPT_PHP2_MODE}" = "fastcgi" ] && [ "${OPT_PHP2_RELEASE}" != "no" ]; then
        {
          echo "  <IfModule mod_fcgid.c>"
          echo "    FcgidWrapper /usr/local/safe-bin/fcgid${OPT_PHP2_VERSION}.sh .php${OPT_PHP2_VERSION}"
          if [ "${SUEXEC_PER_DIR}" -gt 0 ]; then
            printf "  SuexecUserGroup %s %s" "${WEBAPPS_USER}" "${WEBAPPS_GROUP}"
          fi
          echo "  <FilesMatch \"\.php${OPT_PHP2_VERSION}\$\">"
          echo "      Options +ExecCGI"
          echo "      AddHandler fcgid-script .php${OPT_PHP2_VERSION}"
          echo "    </FilesMatch>"
          echo "  </IfModule>"
          } >> ${APACHE_HOST_CONF}
      fi

      echo "</Directory>" >> ${APACHE_HOST_CONF}
    fi
  fi
}

################################################################################################################################

## Verify: Todo:
## Rewrite httpd Alias (copied from CB2: do_rewrite_httpd_alias)
do_rewrite_httpd_alias() {

  if [ -e "${PB_PATH}/custom/ap2/conf/extra/httpd-alias.conf" ]; then
    cp -pf "${PB_PATH}/custom/ap2/conf/extra/httpd-alias.conf" "${APACHE_EXTRA_PATH}/httpd-alias.conf"
  else
    HA="${APACHE_EXTRA_PATH}/httpd-alias.conf"

    ## Truncate file
    echo -n "" > ${HA}

    if [ "${OPT_USE_HOSTNAME_FOR_ALIAS}" = "YES" ]; then
      echo "RewriteEngine On" >> ${HA}
    fi

    add_alias_redirect ${HA} config redirect.php

    if [ "${OPT_SQUIRRELMAIL}" = "YES" ]; then
      add_alias_redirect ${HA} squirrelmail squirrelmail
    fi

    if [ "${OPT_ROUNDCUBE}" = "YES" ]; then
      add_alias_redirect ${HA} roundcube roundcube
    fi

    WEBMAILLINK=$(get_webmail_link)
    if [ -e "${WWW_DIR}/${WEBMAILLINK}" ]; then
      add_alias_redirect ${HA} webmail "${WEBMAILLINK}"
    fi

    if [ "${OPT_PHPMYADMIN}" = "YES" ]; then
      add_alias_redirect ${HA} phpMyAdmin phpMyAdmin
      add_alias_redirect ${HA} phpmyadmin phpMyAdmin
      add_alias_redirect ${HA} pma phpMyAdmin
    fi

    ## For Let's Encrypt challenges
    LETSENCRYPT=$(getDA_Opt letsencrypt 0)
    if [ "${LETSENCRYPT}" = "1" ]; then
      add_alias_redirect ${HA} .well-known .well-known
    fi

    if [ -s "${WEBAPPS_LIST}" ]; then
      # CB2: http://forum.directadmin.com/showthread.php?t=48203&p=247343#post247343
      echo "Adding custom webapps from ${WEBAPPS_LIST}"

      ## Verify:
      while read l < "${WEBAPPS_LIST}"; do
        app=$(echo "$l" | cut -d= -f1)
        app_path=$(echo "$l" | cut -d= -f2)

        if [ "${app}" = "" ] || [ "${app_path}" = "" ]; then
          echo "Check your ${WEBAPPS_LIST}. A name or path is blank."
          echo "name=$app"
          echo "path=$app_path"
          continue
        fi

        if [ ! -e "${WWW_DIR}/${app_path}" ]; then
          echo "Cannot find path ${WWW_DIR}/${app_path} for alias ${app}"
          continue
        fi

        add_alias_redirect ${HA} "${app}" "${app_path}"
        echo "Added ${app} pointing to ${app_path}"
      done
    fi
  fi
}

################################################################################################################################

## Verify: Todo:
## Add Nginx Alias Redirect (copied from CB2: add_nginx_alias_redirect)
add_nginx_alias_redirect() {
  ## CB2: A fake P real
  FILE=$1
  A=$2
  P=$3

  {
    printf "\tlocation /%s {\n" "${A}"
    printf "\t\trewrite ^/* /%s last;\n" "${P}"
    printf "\t}\n"
  } >> "${FILE}"
}

################################################################################################################################

## Verify: Todo:
## Add Nginx Alias (copied from CB2: add_nginx_alias)
add_nginx_alias() {
  F=$1
  A=$2

  if [ "${OPT_WEBSERVER}" = "nginx" ]; then
    {
      printf "\tlocation /%s {\n" "${A}"
      printf "\t\troot %s;\n" "${WWW_DIR}"
      printf "\t\tindex index.php index.html index.htm;\n"
      printf "\t\tlocation ~ ^/%s/(.+\.php)\$ {\n" "${A}"
      printf "\t\t\tinclude %s/webapps_settings.conf;\n" "${NGINX_PATH}"
      printf "\t\t}\n"
      printf "\t\tlocation ~* ^/%s/(.+\\.(jpg|jpeg|gif|css|png|js|ico|html|xml|txt))\$ {\n" "${A}"
      printf "\t\t\troot /usr/local/www/;\n"
      printf "\t\t}\n"
      printf "\t}\n"
    } >> "${F}"
  elif [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
    {
      printf "\tlocation /%s {\n" "${A}"
      printf "\t\troot %s/;\n" "${WWW_DIR}"
      printf "\t\tindex index.php index.html index.htm;\n"
      printf "\t\tlocation ~ ^/%s/ {\n" "${A}"
      printf "\t\t\taccess_log off;\n"
      printf "\t\tset \$my_server_addr \$server_addr;\n"
      printf "\t\tif (\$server_addr ~ ^[0-9a-fA-F:]+$) { set \$my_server_addr [\$server_addr]; }\n"
      printf "\t\t\tproxy_pass http://\$my_server_addr:%s;\n" "${PORT_8080}"
      printf "\t\t\tproxy_set_header X-Client-IP      \$remote_addr;\n"
      printf "\t\t\tproxy_set_header X-Accel-Internal /%s/nginx_static_files;\n" "${A}"
      printf "\t\t\tproxy_set_header Host\t     \$host;\n"
      printf "\t\t\tproxy_set_header X-Forwarded-For  \$proxy_add_x_forwarded_for;\n"
      printf "\t\t}\n"
      printf "\t\tlocation ~ ^/%s/nginx_static_files/ {\n" "${A}"
      printf "\t\t\taccess_log  /var/log/nginx/access_log_proxy;\n"
      printf "\t\t\talias       %s/;\n" "${WWW_DIR}"
      printf "\t\t\tinternal;\n"
      printf "\t\t}\n"
      printf "\t}\n"
    } >> "${F}"
  fi
}

################################################################################################################################

## Verify: Todo:
## Rewrite Nginx Webapps (copied from CB2: do_rewrite_nginx_webapps)
do_rewrite_nginx_webapps() {
  if [ -e "${PB_PATH}/custom/nginx/conf/webapps.conf" ] && [ "${OPT_WEBSERVER}" = "nginx" ]; then
    cp -pf "${PB_PATH}/custom/nginx/conf/webapps.conf" ${NGINX_PATH}/webapps.conf
  elif [ -e "${PB_PATH}/custom/nginx_reverse/conf/webapps.conf" ] && [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
    cp -pf "${PB_PATH}/custom/nginx_reverse/conf/webapps.conf" ${NGINX_PATH}/webapps.conf
  else
    NW=${NGINX_PATH}/webapps.conf

    : > ${NW}

    ## For Let's Encrypt challenges
    LETSENCRYPT=$(getDA_Opt letsencrypt 0)
    if [ "${LETSENCRYPT}" = "1" ]; then
      add_nginx_alias ${NW} .well-known
    fi

    if [ "${OPT_SQUIRRELMAIL}" = "YES" ]; then
      add_nginx_alias ${NW} squirrelmail
    fi

    if [ "${OPT_ROUNDCUBE}" = "YES" ]; then
      add_nginx_alias ${NW} roundcube
    fi

    if [ "${OPT_PHPMYADMIN}" = "YES" ]; then
      add_nginx_alias ${NW} phpMyAdmin
      add_nginx_alias_redirect ${NW} phpmyadmin phpMyAdmin
      add_nginx_alias_redirect ${NW} pma phpMyAdmin
    fi

    WEBMAILLINK=$(get_webmail_link)
    if [ -e "${WWW_DIR}/${WEBMAILLINK}" ]; then
      add_nginx_alias_redirect ${NW} webmail "${WEBMAILLINK}"
    fi

    {
      printf '\tif ($request_method !~ ^(GET|HEAD|POST)$ ) {\n'
      printf '\t\treturn 444;\n'
      printf '\t}\n'
      ## CB2: block .htaccess and .user.ini
      printf '\tlocation ~ /(\\.htaccess|\\.htpasswd|\\.user\\.ini) {\n'
      printf '\t\tdeny all;\n'
      printf '\t}\n'
    } >> ${NW}
  fi

  if [ -e "${PB_PATH}/custom/nginx/conf/webapps.hostname.conf" ] && [ "${OPT_WEBSERVER}" = "nginx" ]; then
    cp -pf "${PB_PATH}/custom/nginx/conf/webapps.hostname.conf" ${NGINX_PATH}/webapps.hostname.conf
  elif [ -e "${PB_PATH}/custom/nginx_reverse/conf/webapps.conf" ] && [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
    cp -pf "${PB_PATH}/custom/nginx_reverse/conf/webapps.hostname.conf" ${NGINX_PATH}/webapps.hostname.conf
  else
    ## CB2: In nginx-vhosts.conf we don't need to have "real" alias specified, because they already exist when acessing http://IP or http://hostname
    NW_HOSTNAME=${NGINX_PATH}/webapps.hostname.conf
    : > ${NW_HOSTNAME}

    if [ "${OPT_PHPMYADMIN}" = "YES" ]; then
      add_nginx_alias_redirect ${NW_HOSTNAME} phpmyadmin phpMyAdmin
      add_nginx_alias_redirect ${NW_HOSTNAME} pma phpMyAdmin
    fi

    WEBMAILLINK=$(get_webmail_link)
    if [ -e "${WWW_DIR}/${WEBMAILLINK}" ]; then
      add_nginx_alias_redirect ${NW_HOSTNAME} webmail "${WEBMAILLINK}"
    fi

    {
      printf '\tif ($request_method !~ ^(GET|HEAD|POST)$ ) {\n'
      printf '\t\treturn 444;\n'
      printf '\t}\n'
      ## CB2: block .htaccess and .user.ini
      printf '\tlocation ~ /(\\.htaccess|\\.htpasswd|\\.user\\.ini) {\n'
      printf '\t\tdeny all;\n'
      printf '\t}\n'
    } >> ${NW_HOSTNAME}
  fi

  cp -pf ${NGINX_PATH}/webapps.conf ${NGINX_PATH}/webapps.ssl.conf
  ${PERL} -pi -e "s|:${PORT_8080}|:${PORT_8081}|" ${NGINX_PATH}/webapps.ssl.conf
  ${PERL} -pi -e 's|http:|https:|' ${NGINX_PATH}/webapps.ssl.conf

  if [ "${HAVE_FPM_CGI}" = "YES" ]; then
    ## CB2: update the webapps_settings.conf
    ##      swap "fastcgi_pass unix:/usr/local/php54/sockets/webapps.sock;" if needed
    ##      might be a better way to do this, other checks. Close enough for now.

    PHP_REPLACE_STRING="$(grep -m1 '^fastcgi_pass unix:/usr/local/php../sockets/webapps.sock;' ${NGINX_PATH}/webapps_settings.conf | cut -d/ -f4)"
    if [ "${PHP_REPLACE_STRING}" = "" ]; then
      PHP_REPLACE_STRING=php54
    fi
    if [ "${OPT_PHP1_MODE}" = "php-fpm" ]; then
      ${PERL} -pi -e "s#${PHP_REPLACE_STRING}#php${OPT_PHP1_VERSION}#" ${NGINX_PATH}/webapps_settings.conf
    fi
  fi
}

################################################################################################################################

## Verify: Todo:
## Create httpd Nginx (copied from CB2: create_httpd_nginx)
create_httpd_nginx() {
  CONF_FILE="${APACHE_EXTRA_PATH}/httpd-nginx.conf"
  echo -n "" > "${CONF_FILE}"

  if [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
    # if [ ! -e /usr/local/libexec/apache24/mod_aclr2.so ]; then
    #   doModAclr2
    # elif [ -s ${STRINGS} ]; then
    #   if ! ${STRINGS} /usr/local/libexec/apache24/mod_aclr2.so | grep -q -m1 'memmove'; then
    #     doModAclr2
    #   fi
    # fi
    # echo 'LoadModule aclr_module  /usr/local/libexec/apache24/mod_aclr2.so' >> ${CONF_FILE}
    {
      echo 'AccelRedirectSet On'
      echo 'AccelRedirectSize 1k'
      echo 'RemoteIPHeader X-Client-IP'
      echo 'RemoteIPInternalProxy 127.0.0.1'
      if [ "${IPV6}" = "1" ]; then
        echo 'RemoteIPInternalProxy ::1'
      fi
      echo 'RemoteIPInternalProxyList /usr/local/directadmin/data/admin/ip.list'
    } >> ${CONF_FILE}
  fi
}

################################################################################################################################

## Rewrite Confs (copied from CB2: doRewriteConfs)
rewrite_confs() {

  if [ "${OPT_WEBSERVER}" = "apache" ] || [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then

    # Copy the new configs
    cp -rf "${PB_PATH}/configure/ap2/" "${APACHE_PATH}"
    cp -f "${PB_PATH}/configure/ap2/httpd.conf" "${APACHE_CONF}"
    cp -f "${PB_PATH}/configure/ap2/extra/httpd-mpm.conf" "${APACHE_EXTRA_PATH}/httpd-mpm.conf"

    ${PERL} -pi -e 's/^DefaultType/#DefaultType/' "${APACHE_CONF}"

    HDC=${APACHE_EXTRA_PATH}/httpd-directories-old.conf

    ln -sf $HDC "${APACHE_EXTRA_PATH}/httpd-directories.conf"

    apache_rewrite_confs

    ## Todo: Custom configurations
    if [ "${APCUSTOMCONFDIR}" != "0" ]; then
      cp -rf "${APCUSTOMCONFDIR}" "${APACHE_PATH}"
    fi

    chmod 710 "${APACHE_EXTRA_PATH}"

    ## Swap the |WEBAPPS_PHP_RELEASE| token
    if [ "${OPT_PHP1_MODE}" = "php-fpm" ] || [ "${OPT_PHP2_MODE}" = "php-fpm" ]; then
      PHPV=""

      if [ "${OPT_PHP1_MODE}" = "php-fpm" ]; then
        PHPV=$(${PERL} -e "print ${OPT_PHP1_VERSION}")
      elif [ "${OPT_PHP2_VERSION}" != "" ]; then
        PHPV=$(${PERL} -e "print ${OPT_PHP2_VERSION}")
      fi

      if [ "${PHPV}" != "" ]; then
        ${PERL} -pi -e "s/\|WEBAPPS_PHP_RELEASE\|/${PHPV}/" "${APACHE_EXTRA_PATH}/${HDC}"
      fi
    fi

    ## Todo:
    verify_server_ca

    # Verify we have the correct apache_ver
    if [ "$(grep -m1 -c apache_ver=2.0 ${DA_CONF_TEMPLATE_FILE})" -eq "0" ]; then
      echo "apache_ver=2.0" >> ${DA_CONF_TEMPLATE_FILE}
    elif [ "$(grep -m1 -c apache_ver= ${DA_CONF_TEMPLATE_FILE})" -ne "0" ]; then
      ${PERL} -pi -e "s/`grep apache_ver= ${DA_CONF_TEMPLATE_FILE}`/apache_ver=2.0/" ${DA_CONF_TEMPLATE_FILE}
    fi

    if [ "$(grep -m1 -c apache_ver=2.0 ${DA_CONF_FILE})" -eq "0" ]; then
      echo "apache_ver=2.0" >> ${DA_CONF_FILE}
      echo "action=rewrite&value=httpd" >> "${DA_TASK_QUEUE}"
    elif [ "$(grep -m1 -c apache_ver= ${DA_CONF_FILE})" -ne "0" ]; then
      ${PERL} -pi -e "s/`grep apache_ver= ${DA_CONF_FILE}`/apache_ver=2.0/" ${DA_CONF_FILE}
      echo "action=rewrite&value=httpd" >> "${DA_TASK_QUEUE}"
    fi

    ## Verify:
    do_rewrite_httpd_alias

    ## Rewrite ips.conf
    echo "action=rewrite&value=ips" >> "${DA_TASK_QUEUE}"

    run_dataskq

    # CB2: Tokenize the IP and ports
    tokenize_IP
    tokenize_ports

    ## Add all the Include lines if they do not exist
    if [ "$(grep -m1 -c 'Include' "${APACHE_EXTRA_PATH}/directadmin-vhosts.conf")" = "0" ] || [ ! -e "${APACHE_EXTRA_PATH}/directadmin-vhosts.conf" ]; then
      doVhosts
      ##PB: cd "${CWD}/httpd-${APACHE2_VER}" || exit
    fi

    ## Generate SSL Key & Certificate if they don't exist
    if [ ! -e "${APACHE_SSL_KEY}" ] || [ ! -e "${APACHE_SSL_CRT}" ]; then
      ## Generate the SSL certificate and key:
      ${OPENSSL_BIN} req -x509 -newkey rsa:2048 -keyout ${APACHE_SSL_KEY} -out ${APACHE_SSL_CRT} -days 9999 -nodes "${OPENSSL_EXTRA}"
      ## /usr/bin/openssl req -x509 -newkey rsa:2048 -keyout "${APACHE_SSL_KEY}" -out "${APACHE_SSL_CRT}" -days 9999 -nodes -config ./${APCERTCONF}

      chmod 600 "${APACHE_SSL_CRT}"
      chmod 600 "${APACHE_SSL_KEY}"
    fi

    ## Todo:
    doApacheCheck

    PHPMODULES=${APACHE_EXTRA_PATH}/httpd-phpmodules.conf

    echo -n "" > "${APACHE_EXTRA_PATH}/httpd-nginx.conf"

    echo -n "" > "${PHPMODULES}"

    if [ "${HAVE_SUPHP_CGI}" = "YES" ]; then
      ${PERL} -pi -e 's|^LoadModule suphp_module|#LoadModule suphp_module|' "${APACHE_CONF}"
      echo "LoadModule  suphp_module    ${APACHE_LIB_PATH}/mod_suphp.so" >> "${PHPMODULES}"
    fi

    ## mod_security (not done):
    if [ "${OPT_MODSECURITY}" = "YES" ] && [ "${OPT_WEBSERVER}" = "apache" ]; then
      ${PERL} -pi -e 's|^LoadModule security2_module|#LoadModule security2_module|' "${APACHE_CONF}"
      echo "Include ${APACHE_EXTRA_PATH}/httpd-modsecurity.conf" >> "${PHPMODULES}"
      cp -pf "${MODSECURITY_APACHE_INCLUDE}" ${APACHE_EXTRA_PATH}/httpd-modsecurity.conf
      doModSecurityRules norestart
    fi

    ## HTScanner (not done):
    if [ "${HTSCANNER_OPT}" = "YES" ]; then
      if [ "${HAVE_FCGID}" = "YES" ] || [ "${HAVE_FPM_CGI}" = "YES" ] || [ "${HAVE_SUPHP_CGI}" = "YES" ]; then
        ${PERL} -pi -e 's|^LoadModule htscanner_module|#LoadModule htscanner_module|' "${APACHE_CONF}"
        echo "LoadModule  htscanner_module    ${APACHE_LIB_PATH}/mod_htscanner2.so" >> "${PHPMODULES}"
      fi
    fi

    ## Example: /usr/local/libexec/apache24/mod_mpm_event.so

    ## Verfiy:
    if ! grep -m1 -q "${APACHE_LIB_PATH}/mod_mpm_" "${PHPMODULES}"; then
      ## Use event MPM for php-fpm and prefork for mod_php
      if [ "${OPT_APACHE_MPM}" = "auto" ]; then
        if [ "${HAVE_CLI}" = "no" ]; then
          ## Add to httpd-phpmodules.conf
          echo "LoadModule mpm_event_module ${APACHE_LIB_PATH}/mod_mpm_event.so" >> "${PHPMODULES}"
        else
          ## Add to httpd-phpmodules.conf
          echo "LoadModule mpm_prefork_module ${APACHE_LIB_PATH}/mod_mpm_prefork.so" >> "${PHPMODULES}"
        fi
      elif [ "${OPT_APACHE_MPM}" = "event" ]; then
        echo "LoadModule mpm_event_module ${APACHE_LIB_PATH}/mod_mpm_event.so" >> "${PHPMODULES}"
      elif [ "${OPT_APACHE_MPM}" = "worker" ]; then
        echo "LoadModule mpm_worker_module ${APACHE_LIB_PATH}/mod_mpm_worker.so" >> "${PHPMODULES}"
      else
        echo "LoadModule mpm_prefork_module ${APACHE_LIB_PATH}/mod_mpm_prefork.so" >> "${PHPMODULES}"
      fi
    fi

    ## ${PERL} -pi -e 's/^LoadModule php4/\#LoadModule php4/' "${APACHE_CONF}"
    ${PERL} -pi -e 's/^LoadModule php5/\#LoadModule php5/' "${APACHE_CONF}"
    ${PERL} -pi -e 's/^LoadModule php7/\#LoadModule php7/' "${APACHE_CONF}"

    ## Add correct PHP module to httpd-phpmodules.conf

    ## PHP1: mod_php
    if [ "${OPT_PHP1_MODE}" = "mod_php" ]; then
      if [ "${OPT_PHP1_VERSION}" = "70" ]; then
        echo "LoadModule  php7_module   ${APACHE_LIB_PATH}/libphp7.so" >> "${PHPMODULES}"
      else
        echo "LoadModule  php5_module   ${APACHE_LIB_PATH}/libphp5.so" >> "${PHPMODULES}"
      fi
    fi

    ## PHP2: mod_php
    if [ "${OPT_PHP2_MODE}" = "mod_php" ] && [ "${OPT_PHP2_VERSION}" != "" ]; then
      if [ "${OPT_PHP2_VERSION}" = "70" ]; then
        echo "LoadModule    php7_module             ${APACHE_LIB_PATH}/libphp7.so" >> "${PHPMODULES}"
      else
        echo "LoadModule    php5_module             ${APACHE_LIB_PATH}/libphp5.so" >> "${PHPMODULES}"
      fi
    fi

    ## fcgid
    if [ "${HAVE_FCGID}" = "YES" ]; then
      if [ -e ${PHPMODULES} ]; then
        if ! grep -m1 -c 'fcgid_module' ${PHPMODULES}; then
          ${PERL} -pi -e 's|^LoadModule  fcgid_module|#LoadModule  fcgid_module|' ${APACHE_CONF}
          echo "LoadModule fcgid_module ${APACHE_LIB_PATH}/mod_fcgid.so" >> ${PHPMODULES}
        fi
        if ! grep -m1 -c 'httpd-fcgid.conf' ${PHPMODULES}; then
          echo "Include ${APACHE_EXTRA_PATH}/httpd-fcgid.conf" >> ${PHPMODULES}
        fi
      fi

    ## PB: Doesn't exist on FreeBSD
    #   if [ ! -d /usr/local/safe-bin ]; then
    #     mkdir -p /usr/local/safe-bin
    #     chmod 511 /usr/local/safe-bin
    #     chown apache:apache /usr/local/safe-bin
    #   fi

    #   for php_shortrelease in `echo ${OPT_PHP1_VERSION_SET}`; do
    #     EVAL_CHECK_VAR=HAVE_FCGID${php_shortrelease}
    #     if [ "$(eval_var ${EVAL_CHECK_VAR})" = "YES" ]; then
    #       cp -f ${CWD}/configure/fastcgi/fcgid${php_shortrelease}.sh /usr/local/safe-bin/fcgid${php_shortrelease}.sh
    #       if [ -e ${CWD}/custom/fastcgi/fcgid${php_shortrelease}.sh ]; then
    #         cp -f ${CWD}/custom/fastcgi/fcgid${php_shortrelease}.sh /usr/local/safe-bin/fcgid${php_shortrelease}.sh
    #       fi
    #       chown apache:apache /usr/local/safe-bin/fcgid${php_shortrelease}.sh
    #       chmod 555 /usr/local/safe-bin/fcgid${php_shortrelease}.sh
    #     fi
    #   done
    fi

    if [ "${HAVE_SUPHP_CGI}" = "YES" ]; then
      if [ -e "${PHPMODULES}" ]; then
        if ! grep -m1 -q 'suphp_module' "${PHPMODULES}"; then
          echo "LoadModule  suphp_module    ${APACHE_LIB_PATH}/mod_suphp.so" >> "${PHPMODULES}"
        fi
      fi
    fi

    if [ "${NEWCONFIGS}" = "1" ]; then
      ${PERL} -pi -e 's/^LoadModule mod_php/\#LoadModule mod_php/' "${APACHE_CONF}"
      ${PERL} -pi -e 's/^LoadModule php/\#LoadModule php/' "${APACHE_CONF}"
      ${PERL} -pi -e 's/^LoadModule suphp/\#LoadModule suphp/' "${APACHE_CONF}"
    fi

    WEBMAILLINK=$(get_webmail_link)
    ${PERL} -pi -e "s#Alias /webmail \"/usr/local/www/roundcube/\"#Alias /webmail \"/usr/local/www/${WEBMAILLINK}/\"#" ${APACHE_EXTRA_PATH}/httpd-alias.conf

    doPhpConf
    # if [ "${CLOUDLINUX_OPT}" = "no" ] || [ "${OPT_PHP1_MODE}" != "lsphp" ]; then
      doModLsapi 0
    # fi

    ## Disable UserDir access if userdir_access=no is set in the options.conf file
    if [ "${USERDIR_ACCESS_OPT}" = "no" ]; then
      ${PERL} -pi -e 's#UserDir public_html#UserDir disabled#' ${APACHE_EXTRA_PATH}/httpd-vhosts.conf
    else
      ${PERL} -pi -e 's#UserDir disabled#UserDir public_html#' ${APACHE_EXTRA_PATH}/httpd-vhosts.conf
    fi

    ## Todo:
    create_httpd_nginx

    if [ "${OPT_WEBSERVER}" = "apache" ] || [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
      echo "Restarting Apache"
      ${SERVICE} apachectl restart
    fi
  fi

  ## Todo: Nginx:
  if [ "${OPT_WEBSERVER}" = "nginx" ] || [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
    # Copy the new configs
    cp -rf "${NGINXCONFDIR}/*" "${NGINX_CONF}"

    for php_shortrelease in $(echo ${OPT_PHP1_VERSION_SET}); do
      ${PERL} -pi -e "s|/usr/local/php${php_shortrelease}/sockets/webapps.sock|/usr/local/php${OPT_PHP1_VERSION}/sockets/webapps.sock|" ${NGINXCONF}/nginx.conf
    done

    do_rewrite_nginx_webapps
    verify_server_ca
    ensure_dhparam "${NGINX_CONF}/ssl.crt/dhparams.pem"

    ## Todo:
    if [ "${OPT_MODSECURITY}" = "YES" ]; then
      doModSecurityRules norestart
    fi

    # Rewrite ips.conf
    echo "action=rewrite&value=nginx" >> "${TASK_QUEUE}"
    echo "action=rewrite&value=ips" >> "${TASK_QUEUE}"

    run_dataskq

    # Add all the Include lines if they do not exist
    if [ "$(grep -m1 -c 'Include' "${NGINXCONF}/directadmin-vhosts.conf")" = "0" ] || [ ! -e "${NGINXCONF}/directadmin-vhosts.conf" ]; then
      doVhosts
    fi

    if [ ! -e "${NGINXCONF}/directadmin-settings.conf" ]; then
      touch "${NGINXCONF}/directadmin-settings.conf"
    fi

    if [ ! -e "${NGINXCONF}/directadmin-ips.conf" ]; then
      touch "${NGINXCONF}/directadmin-ips.conf"
    fi

    if [ ! -e "${NGINXCONF}/nginx-includes.conf" ]; then
      touch "${NGINXCONF}/nginx-includes.conf"
    fi

    if [ ! -e "${NGINXCONF}/nginx-modsecurity-enable.conf" ]; then
      touch "${NGINXCONF}/nginx-modsecurity-enable.conf"
    elif [ "${MODSECURITY_OPT}" = "no" ]; then
      echo -n '' > "${NGINXCONF}/nginx-modsecurity-enable.conf"
    fi

    if [ "${NGINXCUSTOMCONFDIR}" != "0" ]; then
      cp -rf "${NGINXCUSTOMCONFDIR}/*" "${NGINXCONF}/"
    fi

    chmod 710 "${NGINXCONF}"

    if [ "${IPV6}" = "0" ]; then
      ${PERL} -pi -e 's| listen       \[::1\]:| #listen       \[::1\]:|' "${NGINXCONF}/nginx-vhosts.conf"
      ${PERL} -pi -e 's| listen       \[::1\]:| #listen       \[::1\]:|' "${NGINXCONF}/nginx.conf"
    else
      ${PERL} -pi -e 's| #listen       \[::1\]:| listen       \[::1\]:|' "${NGINXCONF}/nginx-vhosts.conf"
      ${PERL} -pi -e 's| #listen       \[::1\]:| listen       \[::1\]:|' "${NGINXCONF}/nginx.conf"
    fi

    ${PERL} -pi -e "s#worker_processes  1;#worker_processes  ${CPU_CORES};#" "${NGINXCONF}/nginx.conf"

    tokenize_IP
    tokenize_ports

    # Disable UserDir access if userdir_access=no is set in the options.conf file
    if [ "${OPT_USERDIR_ACCESS}" = "no" ]; then
      ${PERL} -pi -e "s| include ${NGINX_PATH}/nginx-userdir.conf;| #include ${NGINX_PATH}/nginx-userdir.conf;|" "${NGINXCONF}/nginx-vhosts.conf"
    else
      ${PERL} -pi -e "s| #include ${NGINX_PATH}/nginx-userdir.conf;| include ${NGINX_PATH}/nginx-userdir.conf;|" "${NGINXCONF}/nginx-vhosts.conf"
    fi

    doPhpConf

    echo "Restarting nginx."
    # /usr/sbin/nginx -s stop >/dev/null 2>&1
    # control_service nginx start
    ${SERVICE} nginx restart
  fi

  if [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
    setVal nginx 0 ${DA_CONF_TEMPLATE_FILE}
    setVal nginx 0 ${DA_CONF_FILE}
    setVal nginx_proxy 1 ${DA_CONF_TEMPLATE_FILE}
    setVal nginx_proxy 1 ${DA_CONF_FILE}
  fi

  verify_webapps_tmp

  directadmin_restart

}
################################################################################################################################

## Run DirectAdmin Task Query (copied from CB2)
run_dataskq() {
  ## $1 = argument (e.g. "d" for debug)

  DATASKQ_OPT=$1
  if [ -s "${DA_CONF_FILE}" ]; then
    /usr/local/directadmin/dataskq "${DATASKQ_OPT}" --custombuild
  fi
}

################################################################################################################################

## Rewrite directadmin-vhosts.conf (copied from CB2: doVhosts)
rewrite_vhosts() {
  PATHNAME=${APACHE_EXTRA_PATH}

  if [ "${OPT_WEBSERVER}" = "nginx" ]; then
    PATHNAME="${NGINXCONF}"
  fi

  if [ ! -d "${PATHNAME}" ]; then
    mkdir -p "${PATHNAME}"
  fi

  echo -n '' > ${APACHE_EXTRA_PATH}/directadmin-vhosts.conf

  if [ "${OPT_WEBSERVER}" = "nginx" ]; then
    for i in $(ls /usr/local/directadmin/data/users/*/nginx.conf); do
      echo "include $i;" >> "${APACHE_EXTRA_PATH}/directadmin-vhosts.conf"
    done
  elif [ "${OPT_WEBSERVER}" = "apache" ]; then
    for i in $(ls /usr/local/directadmin/data/users/*/httpd.conf); do
      echo "Include $i" >> "${APACHE_EXTRA_PATH}/directadmin-vhosts.conf"
    done
  elif [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
    echo -n '' > "${NGINXCONF}/directadmin-vhosts.conf"
    for i in $(ls /usr/local/directadmin/data/users/*/nginx.conf); do
      echo "include $i;" >> "${NGINXCONF}/directadmin-vhosts.conf"
    done
    for i in $(ls /usr/local/directadmin/data/users/*/httpd.conf); do
      echo "Include $i" >> "${APACHE_EXTRA_PATH}/directadmin-vhosts.conf"
    done
  fi
}

################################################################################################################################

## Suhosin Installation
suhosin_install() {

  ## Main Installation
  pkgi "${PORT_SUHOSIN}"

  ## Add support for scanning uploads using ClamAV
  if [ "${OPT_SUHOSIN_UPLOADSCAN}" = "YES" ] && [ ! -e "${CLAMDSCAN_BIN}" ]; then
    if [ "${OPT_CLAMAV}" = "NO" ]; then
      echo "*** Error: Cannot install suhosin with PHP upload scan using ClamAV, because ${CLAMDSCAN_BIN} does not exist on the system and CLAMAV=NO is set in the options.conf file."
      return #exit
    fi

    clamav_install
  fi
}

################################################################################################################################

## Tokenize the IP (copied from CB2)
tokenize_IP() {
  TOKENFILE_APACHE=${APACHE_EXTRA_PATH}/httpd-vhosts.conf

  TOKENFILE_NGINX=${NGINXCONF}/nginx.conf
  if [ -e "${TOKENFILE_NGINX}" ]; then
    if grep -q -m1 'nginx-vhosts\.conf' "${TOKENFILE_NGINX}"; then
      TOKENFILE_NGINX=${NGINXCONF}/nginx-vhosts.conf
    fi
  fi

  TOKENFILE_NGINX_USERDIR=${NGINXCONF}/nginx-userdir.conf

  HOSTNAME=$(hostname)
  IP="$(grep -r -l -m1 '^status=server$' /usr/local/directadmin/data/admin/ips | cut -d/ -f8)"
  if [ "${IP}" = "" ]; then
    IP="$(grep -m1 "${HOSTNAME}" /etc/hosts | awk '{print $1}')"
    if [ "${IP}" = "" ]; then
      echo "Unable to detect your server IP in /etc/hosts. Please enter it: "
      read IP
    fi
  fi
  if [ "${IP}" = "" ]; then
    echo "Unable to detect your server IP. Exiting..."
    exit 0 # was: do_exit 0
  fi

  if [ "$(echo "${IP}" | grep -m1 -c ':')" -gt 0 ]; then
    IP="[${IP}]"
  fi

  echo "Using $IP for your server IP"

  LAN_IP=$(getDA_Opt lan_ip "")

  if [ "${OPT_WEBSERVER}" = "apache" ] || [ "${OPT_WEBSERVER}" = "litespeed" ] || [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
    if [ -e ${TOKENFILE_APACHE} ]; then
      if [ "$(grep -m1 -c '|IP|' ${TOKENFILE_APACHE})" -gt "0" ]; then
        STR="perl -pi -e 's/\|IP\|/$IP/' ${TOKENFILE_APACHE}"
        eval "${STR}"
      fi
    fi
  fi

  if [ "${OPT_WEBSERVER}" = "nginx" ] || [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
    if [ -e "${TOKENFILE_NGINX}" ]; then
      if [ "$(grep -m1 -c '|IP|' "${TOKENFILE_NGINX}")" -gt "0" ]; then
        if [ "${LAN_IP}" != "" ]; then
          echo "Using lan_ip=$LAN_IP as a secondary server IP";
          STR="perl -pi -e 's/\|IP\|:\|PORT_80\|;/\|IP\|:\|PORT_80\|;\n\tlisten\t\t$LAN_IP:\|PORT_80\|;/' ${TOKENFILE_NGINX}"
          eval "${STR}"

          STR="perl -pi -e 's/\|IP\|:\|PORT_443\| ssl;/\|IP\|:\|PORT_443\| ssl;\n\tlisten\t\t$LAN_IP:\|PORT_443\| ssl;/' ${TOKENFILE_NGINX}"
          eval "${STR}"
        fi

        echo "Using $IP for your server IP"
        STR="perl -pi -e 's/\|IP\|/$IP/' ${TOKENFILE_NGINX}"
        eval "${STR}"
      fi
    fi

    if [ -e "${TOKENFILE_NGINX_USERDIR}" ]; then
      if [ "$(grep -m1 -c '|IP|' "${TOKENFILE_NGINX_USERDIR}")" -gt "0" ]; then
        if [ "${LAN_IP}" != "" ]; then
          STR="perl -pi -e 's/\|IP\|:\|PORT_80\|;/\|IP\|:\|PORT_80\|;\n\tlisten\t\t$LAN_IP:\|PORT_80\|;/' ${TOKENFILE_NGINX_USERDIR}"
          eval "${STR}"

          STR="perl -pi -e 's/\|IP\|:\|PORT_443\| ssl;/\|IP\|:\|PORT_443\| ssl;\n\tlisten\t\t$LAN_IP:\|PORT_443\| ssl;/' ${TOKENFILE_NGINX_USERDIR}"
          eval "${STR}"
        fi

        STR="perl -pi -e 's/\|IP\|/$IP/' ${TOKENFILE_NGINX_USERDIR}"
        eval "${STR}"
      fi
    fi
  fi
}

################################################################################################################################

## Tokenize Ports (copied from CB2)
tokenize_ports() {

  TOKENFILE_APACHE="${APACHE_EXTRA_PATH}/httpd-vhosts.conf"

  TOKENFILE_NGINX=${NGINXCONF}/nginx.conf
  if [ -e "${TOKENFILE_NGINX}" ]; then
    if grep -q -m1 'nginx-vhosts\.conf' "${TOKENFILE_NGINX}"; then
      TOKENFILE_NGINX=${NGINXCONF}/nginx-vhosts.conf
    fi
  fi
  TOKENFILE_NGINX_USERDIR=${NGINXCONF}/nginx-userdir.conf

  ## Apache:
  if [ "${OPT_WEBSERVER}" = "apache" ] || [ "${OPT_WEBSERVER}" = "litespeed" ]; then
    if [ -e ${TOKENFILE_APACHE} ]; then
      if [ "$(grep -m1 -c '|PORT_80|' ${TOKENFILE_APACHE})" -gt "0" ]; then
        STR="${PERL} -pi -e \"s/\|PORT_80\|/${PORT_80}/\" ${TOKENFILE_APACHE}"
        eval "${STR}"
      else
        ${PERL} -pi -e "s/:${PORT_8080}\>/:${PORT_80}\>/" ${TOKENFILE_APACHE}
        ${PERL} -pi -e "s/^Listen ${PORT_8080}$/Listen ${PORT_80}/" ${TOKENFILE_APACHE}
      fi
      if [ "$(grep -m1 -c '|PORT_443|' ${TOKENFILE_APACHE})" -gt "0" ]; then
        STR="${PERL} -pi -e \"s/\|PORT_443\|/${PORT_443}/\" ${TOKENFILE_APACHE}"
        ${PERL} "${STR}"
      else
        ${PERL} -pi -e "s/:${PORT_8081}\>/:${PORT_443}\>/" ${TOKENFILE_APACHE}
        ${PERL} -pi -e "s/^Listen ${PORT_8081}$/Listen ${PORT_443}/" ${TOKENFILE_APACHE}
      fi

      SSLFILE=${APACHE_EXTRA_PATH}/httpd-ssl.conf
      STR="${PERL} -pi -e \"s/\|PORT_443\|/${PORT_443}/\" ${SSLFILE}"
      eval "${STR}"
      ${PERL} -pi -e "s/:${PORT_8081}\>/:${PORT_443}\>/" ${SSLFILE}
      ${PERL} -pi -e "s/^Listen ${PORT_8081}$/Listen ${PORT_443}/" ${SSLFILE}

      ${PERL} -pi -e "s/:${PORT_8080}\>/:${PORT_80}\>/" "${HTTPD_CONF}"
      ${PERL} -pi -e "s/^Listen ${PORT_8080}$/Listen ${PORT_80}/" "${HTTPD_CONF}"
    fi
  fi

  ## Nginx:
  if [ "${OPT_WEBSERVER}" = "nginx" ]; then
    if [ -e "${TOKENFILE_NGINX}" ]; then
      if [ "$(grep -m1 -c '|PORT_80|' "${TOKENFILE_NGINX}")" -gt "0" ]; then
        STR="${PERL} -pi -e \"s/\|PORT_80\|/${PORT_80}/\" ${TOKENFILE_NGINX}"
        eval "${STR}"
      fi
      if [ "$(grep -m1 -c '|PORT_443|' "${TOKENFILE_NGINX}")" -gt "0" ]; then
        STR="${PERL} -pi -e \"s/\|PORT_443\|/${PORT_443}/\" ${TOKENFILE_NGINX}"
        eval "${STR}"
      fi
    fi

    if [ -e "${TOKENFILE_NGINX_USERDIR}" ]; then
      if [ "$(grep -m1 -c '|PORT_80|' "${TOKENFILE_NGINX_USERDIR}")" -gt "0" ]; then
        STR="${PERL} -pi -e \"s/\|PORT_80\|/${PORT_80}/\" ${TOKENFILE_NGINX_USERDIR}"
        eval "${STR}"
      fi
      if [ "$(grep -m1 -c '|PORT_443|' "${TOKENFILE_NGINX_USERDIR}")" -gt "0" ]; then
        STR="${PERL} -pi -e \"s/\|PORT_443\|/${PORT_443}/\" ${TOKENFILE_NGINX_USERDIR}"
        eval "${STR}"
      fi
    fi
  fi

  ## Nginx+Apache:
  if [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
    if [ -e "${TOKENFILE_NGINX}" ]; then
      if [ "$(grep -m1 -c '|PORT_80|' "${TOKENFILE_NGINX}")" -gt "0" ]; then
        STR="${PERL} -pi -e \"s/\|PORT_80\|/${PORT_80}/\" ${TOKENFILE_NGINX}"
        eval "${STR}"
      fi

      if [ "$(grep -m1 -c '|PORT_443|' "${TOKENFILE_NGINX}")" -gt "0" ]; then
        STR="${PERL} -pi -e \"s/\|PORT_443\|/${PORT_443}/\" ${TOKENFILE_NGINX}"
        eval "${STR}"
      fi

      if [ "$(grep -m1 -c '|PORT_8080|' "${TOKENFILE_NGINX}")" -gt "0" ]; then
        STR="${PERL} -pi -e \"s/\|PORT_8080\|/${PORT_8080}/\" ${TOKENFILE_NGINX}"
        eval "${STR}"
      fi

      if [ "$(grep -m1 -c '|PORT_8081|' "${TOKENFILE_NGINX}")" -gt "0" ]; then
        STR="${PERL} -pi -e \"s/\|PORT_8081\|/${PORT_8081}/\" ${TOKENFILE_NGINX}"
        eval "${STR}"
      fi
    fi

    if [ -e "${TOKENFILE_NGINX_USERDIR}" ]; then
      if [ "$(grep -m1 -c '|PORT_80|' "${TOKENFILE_NGINX_USERDIR}")" -gt "0" ]; then
        STR="${PERL} -pi -e \"s/\|PORT_80\|/${PORT_80}/\" ${TOKENFILE_NGINX_USERDIR}"
        eval "${STR}"
      fi

      if [ "$(grep -m1 -c '|PORT_443|' "${TOKENFILE_NGINX_USERDIR}")" -gt "0" ]; then
        STR="${PERL} -pi -e \"s/\|PORT_443\|/${PORT_443}/\" ${TOKENFILE_NGINX_USERDIR}"
        eval "${STR}"
      fi

      if [ "$(grep -m1 -c '|PORT_8080|' "${TOKENFILE_NGINX_USERDIR}")" -gt "0" ]; then
        STR="${PERL} -pi -e \"s/\|PORT_8080\|/${PORT_8080}/\" ${TOKENFILE_NGINX_USERDIR}"
        eval "${STR}"
      fi

      if [ "$(grep -m1 -c '|PORT_8081|' "${TOKENFILE_NGINX_USERDIR}")" -gt "0" ]; then
        STR="${PERL} -pi -e \"s/\|PORT_8081\|/${PORT_8081}/\" ${TOKENFILE_NGINX_USERDIR}"
        eval "${STR}"
      fi
    fi

    ## Apache:
    if [ -e ${TOKENFILE_APACHE} ]; then
      if [ "$(grep -m1 -c '|PORT_80|' ${TOKENFILE_APACHE})" -gt "0" ]; then
        STR="${PERL} -pi -e \"s/\|PORT_80\|/${PORT_8080}/\" ${TOKENFILE_APACHE}"
        eval "${STR}"
      else
        ${PERL} -pi -e "s/:${PORT_80}\>/:${PORT_8080}\>/" ${TOKENFILE_APACHE}
      fi

      if [ "$(grep -m1 -c '|PORT_443|' ${TOKENFILE_APACHE})" -gt "0" ]; then
        STR="${PERL} -pi -e \"s/\|PORT_443\|/${PORT_8081}/\" ${TOKENFILE_APACHE}"
        eval "${STR}"
      else
        ${PERL} -pi -e "s/:${PORT_443}\>/:${PORT_8081}\>/" ${TOKENFILE_APACHE}
      fi

      if [ "$(grep -m1 -c "^Listen ${PORT_80}$" "${HTTPD_CONF}")" -gt 0 ]; then
        STR="${PERL} -pi -e \"s/^Listen ${PORT_80}$/Listen ${PORT_8080}/\" ${HTTPD_CONF}"
        eval "${STR}"
      else
        ${PERL} -pi -e "s/:${PORT_80}\>/:${PORT_8080}\>/" "${HTTPD_CONF}"
      fi

      SSLFILE=${APACHE_EXTRA_PATH}/httpd-ssl.conf
      STR="${PERL} -pi -e \"s/\|PORT_443\|/${PORT_8081}/\" ${SSLFILE}"
      eval "${STR}"
      ${PERL} -pi -e "s/:${PORT_443}\>/:${PORT_8081}\>/" ${SSLFILE}
      ${PERL} -pi -e "s/^Listen ${PORT_443}$/Listen ${PORT_8081}/" ${SSLFILE}
    fi
  fi
}

################################################################################################################################

## Verify: Todo:
## Rewrite PHP Configuration (copied from CB2: doPhpConf)
rewrite_php_confs() {

  if [ "${HAVE_FPM_CGI}" = "YES" ]; then
    for php_shortrelease in $(echo ${OPT_PHP1_VERSION_SET}); do
      set_service "php-fpm${php_shortrelease}" OFF
    done
  else
    for php_shortrelease in $(echo ${OPT_PHP1_VERSION_SET}); do
      set_service "php-fpm${php_shortrelease}" delete
    done
  fi

  ## Verify:
  fpmChecks

  if [ "${OPT_WEBSERVER}" = "apache" ] || [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then

    ## Verify:
    doApacheHostConf

    ## Writing data to httpd-php-handlers.conf
    {
      echo '<FilesMatch "\.(inc|php|php3|php4|php44|php5|php52|php53|php54|php55|php56|php70|php6|phtml|phps)$">'
      if [ "${OPT_PHP1_MODE}" = "mod_php" ]; then
        echo "AddHandler application/x-httpd-php .inc .php .php5 .php${OPT_PHP1_VERSION} .phtml"
      fi
      if [ "${OPT_PHP2_MODE}" = "mod_php" ] && [ "${OPT_PHP2_RELEASE}" != "no" ]; then
        echo "AddHandler application/x-httpd-php .php${OPT_PHP2_VERSION}"
      fi
      if [ "${OPT_PHP1_MODE}" = "mod_php" ] || [ "${OPT_PHP2_MODE}" = "mod_php" ]; then
        echo "AddHandler application/x-httpd-php-source .phps"
      fi
      echo "</FilesMatch>"
      echo "AddType text/html .php"
    } >> "${PHP_HANDLERS_HTTPD}"
  fi

  for php_shortrelease in $(echo ${OPT_PHP1_VERSION_SET}); do
    eval $(echo "HAVE_FPM${php_shortrelease}=no")
  done

  if [ "${OPT_PHP1_MODE}" = "php-fpm" ]; then
    ## Todo: multiple-PHP versions
    ## PB: "${INITDDIR}/php-fpm${OPT_PHP1_VERSION}" restart
    ## PB: ${SERVICE} "php-fpm${OPT_PHP1_VERSION}" restart
    ${SERVICE} php-fpm restart
    set_service php-fpm${OPT_PHP1_VERSION} ON
    eval $(echo "HAVE_FPM${OPT_PHP1_VERSION}=YES")
  fi

  if [ "${OPT_PHP2_MODE}" = "php-fpm" ] && [ "${OPT_PHP2_RELEASE}" != "NO" ]; then
     ${INITDDIR}/php-fpm${OPT_PHP2_VERSION} restart
     # set_service php-fpm${OPT_PHP2_VERSION} ON
    # eval `echo "HAVE_FPM${OPT_PHP2_VERSION}=YES"`
  fi

  for php_shortrelease in $(echo ${OPT_PHP1_VERSION_SET}); do
    EVAL_FPM_VAR=HAVE_FPM${php_shortrelease}
    HAVE_SHORTRELEASE="$(eval_var ${EVAL_FPM_VAR})"

    if [ "${HAVE_SHORTRELEASE}" = "NO" ]; then
        if [ -e "${INITDDIR}/php-fpm${php_shortrelease}" ]; then
          "${INITDDIR}/php-fpm${php_shortrelease}" stop
        else
          ${SERVICE} php-fpm stop
        fi
        # set_service php-fpm${php_shortrelease} delete
        # boot/init script: rm -f ${INITDDIR}/php-fpm${php_shortrelease}
    fi
  done

  if [ "${OPT_WEBSERVER}" = "apache" ] || [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
    if [ "${HAVE_SUPHP_CGI}" = "YES" ]; then
      ## Writing data to suphp.conf:
      (
        echo "[global]"
        echo ";Path to logfile"
        echo "logfile=/var/log/suphp.log"
        echo ""
        echo ";Loglevel"
        echo "loglevel=warn"
        echo ""
        echo ";User Apache is running as"
        echo "webserver_user=apache"
        echo ""
        echo ";Path all scripts have to be in"
        echo "docroot=/"
        echo ""
        echo "; Security options"
        echo "allow_file_group_writeable=false"
        echo "allow_file_others_writeable=false"
        echo "allow_directory_group_writeable=false"
        echo "allow_directory_others_writeable=false"
        echo ""
        echo ";Check wheter script is within DOCUMENT_ROOT"
        echo "check_vhost_docroot=false"
        echo ""
        echo ";Send minor error messages to browser"
        echo "errors_to_browser=true"
        echo ""
        echo ";PATH environment variable"
        echo "env_path=\"/bin:/usr/bin\""
        echo ""
        echo ";Umask to set, specify in octal notation"
        echo "umask=0022"
        echo ""
        echo ";Minimum UID"
        echo "min_uid=100"
        echo ""
        echo ";Minimum GID"
        echo "min_gid=100"
        echo ""
        echo "[handlers]"
        echo ";Handler for php-scripts"
        if [ "${OPT_PHP1_MODE}" = "suphp" ]; then
          echo "x-httpd-php${OPT_PHP1_VERSION}=\"php:/usr/local/php${OPT_PHP1_VERSION}/bin/php-cgi${OPT_PHP1_VERSION}\""
        fi
        ## Todo: PHP2:
        # if [ "${OPT_PHP2_MODE}" = "suphp" ] && [ "${OPT_PHP2_RELEASE}" != "no" ]; then
        #   echo "x-httpd-php${OPT_PHP2_VERSION}=\"php:/usr/local/php${OPT_PHP2_VERSION}/bin/php-cgi${OPT_PHP2_VERSION}\""
        # fi
        echo ""
        echo ";Handler for CGI-scripts"
        echo "x-suphp-cgi=\"execute:!self\""
      ) > "${SUPHP_CONF_FILE}"

      ## Writing data to ${APACHE_EXTRA_PATH}/httpd-suphp.conf
      echo "Writing data to ${SUPHP_HTTPD}"
      {
        echo "<IfModule mod_suphp.c>"
        echo '<FilesMatch "\.(inc|php|php3|php4|php44|php5|php52|php53|php54|php55|php56|php70|php6|phtml|phps)$">'
        if [ "${OPT_PHP1_MODE}" = "suphp" ]; then
          echo "AddHandler x-httpd-php${OPT_PHP1_VERSION} .inc .php .php3 .php4 .php5 .php${OPT_PHP1_VERSION} .phtml"
        fi
        ## Todo: PHP2:
        # if [ "${OPT_PHP2_MODE}" = "suphp" ] && [ "${OPT_PHP2_RELEASE}" != "no" ]; then
        #   echo "AddHandler x-httpd-php${OPT_PHP2_VERSION} .php${OPT_PHP2_VERSION}" >> ${SUPHP_HTTPD}
        # fi
        echo "</FilesMatch>"
        echo "<Location />"
        echo "suPHP_Engine on"
        if [ -d "/usr/local/php${OPT_PHP1_VERSION}/lib" ]; then
          echo "suPHP_ConfigPath /usr/local/php${OPT_PHP1_VERSION}/lib/"
        elif [ -d "/usr/local/php${OPT_PHP2_VERSION}/lib" ]; then
          echo "suPHP_ConfigPath /usr/local/php${OPT_PHP2_VERSION}/lib/"
        fi
        if [ "${OPT_PHP1_MODE}" = "suphp" ]; then
          echo "suPHP_AddHandler x-httpd-php${OPT_PHP1_VERSION}"
        fi
        ## Todo: PHP2:
        # if [ "${OPT_PHP2_MODE}" = "suphp" ] && [ "${OPT_PHP2_RELEASE}" != "no" ]; then
        #   echo "suPHP_AddHandler x-httpd-php${OPT_PHP2_VERSION}"
        # fi
        echo "</Location>"
        echo "</IfModule>"
      } > "${SUPHP_HTTPD}"

      echo "Done."
    elif [ -e "${SUPHP_HTTPD}" ]; then
      echo -n "" > "${SUPHP_HTTPD}"
    fi
  fi
}

################################################################################################################################

## Todo: Setup Brute-Force Monitor
bfm_setup() {
  ## Update directadmin.conf:
  # brute_force_roundcube_log=${WWW_DIR}/roundcube/logs/errors
  # brute_force_squirrelmail_log=${WWW_DIR}/squirrelmail/data/squirrelmail_access_log
  # brute_force_pma_log=${WWW_DIR}/phpMyAdmin/log/auth.log

  setVal brute_force_roundcube_log "${WWW_DIR}/roundcube/logs/errors" ${DA_CONF_FILE}
  setVal brute_force_pma_log "${WWW_DIR}/phpMyAdmin/log/auth.log" ${DA_CONF_FILE}

  if [ ! -e "${PB_DIR}/patches/pma_auth_logging.patch" ]; then
    ${WGET} -O "${PB_DIR}/patches/pma_auth_logging.patch" "${PB_MIRROR}/patches/pma_auth_logging.patch"
  fi

  #pure_pw=/usr/bin/pure-pw
}

################################################################

## Todo: IPFW Setup
ipfw_setup() {
  return
}

################################################################################################################################

## Validate Options
validate_options() {

  ## Parse Defaults and User Options, then pass computed values to PB

  ## Default SSL Certificates to use
  OPT_PREFER_APACHE_SSL_CERTS="NO"
  OPT_PREFER_EXIM_SSL_CERTS="NO"
  OPT_PREFER_CUSTOM_SSL_CERTS="NO"

  # SERVER_IP=${DA_SERVER_IP}
  # SERVER_IP_MASK=${DA_SERVER_IP_MASK}

  ## Port/Package Options
  case ${PHP1_VERSION} in
    55|56|70) OPT_PHP1_VERSION=${PHP1_VERSION}
      case $(lc ${PHP1_MODE}) in
        "fpm"|"phpfpm"|"php-fpm"|"php_fpm")
          OPT_PHP1_MODE="php-fpm"
          HAVE_FPM_CGI="YES"
          ;;
        "suphp"|"su_php"|"su-php"|"su")
          OPT_PHP1_MODE="suphp"
          HAVE_SUPHP_CGI=YES
          ;;
        "modphp"|"mod_php"|"mod"|"mod-php")
          OPT_PHP1_MODE="mod_php"
          HAVE_CLI="YES"
          ;;
        *) echo "*** Error: Invalid PHP1_MODE value set in options.conf"; exit;;
      esac
      case $(lc ${PHP_INI_TYPE}) in
        "production"|"development") OPT_PHP_INI_TYPE=${PHP_INI_TYPE} ;;
        "custom") OPT_PHP_INI_TYPE="custom" ;;
        "no"|"none") OPT_PHP_INI_TYPE="none" ;;
        *) echo "*** Error: Invalid PHP ini Type set in options.conf"; exit ;;
      esac
      ;;
    "no"|"NO"|"none")
      OPT_PHP1_VERSION="NO"
      OPT_PHP1_MODE="NO"
      HAVE_FPM_CGI="NO"
      HAVE_SUPHP_CGI="NO"
      HAVE_CLI="NO"
      ;;
    *) echo "*** Error: Invalid PHP1_VERSION value set in options.conf"; exit ;;
  esac

  ## PHP2:
  OPT_PHP2_MODE=NO
  OPT_PHP2_VERSION=NO
  OPT_PHP2_RELEASE=NO
  # case ${PHP2_VERSION} in
  #   55|56|70) OPT_PHP1_VERSION=${PHP1_VERSION} ;;
  #   *) echo "*** Error: Invalid PHP2_VERSION value set in options.conf"; exit ;;
  # esac

  # case $(lc ${PHP2_MODE}) in
  #   fpm|phpfpm|php-fpm) OPT_PHP1_MODE="php-fpm" ;;
  #   suphp) OPT_PHP1_MODE="suphp" ;;
  #   modphp|mod_php|mod|mod-php) OPT_PHP1_MODE="modphp" ;;
  #   *) echo "*** Error: Invalid PHP2_MODE value set in options.conf"; exit ;;
  # esac

  ## additional checks for PHP, then:
  ## OPT_PHP_ENABLE="YES"

  case $(lc ${WEBSERVER}) in
    "apache"|"apache24") OPT_WEBSERVER="apache"
    case $(lc ${APACHE_MPM}) in
      "event"|"prefork"|"worker") OPT_APACHE_MPM="${APACHE_MPM}" ;;
      "auto") OPT_APACHE_MPM="event" ;;
      *) echo "*** Error: Invalid APACHE_MPM value set in options.conf"; exit ;;
    esac ;;
    "nginx") OPT_WEBSERVER="nginx" ;;
    "no"|"none") OPT_WEBSERVER="NO" ;;
    *) echo "*** Error: Invalid WEBSERVER value set in options.conf"; exit ;;
  esac

  case $(lc ${SQL_DB}) in
    "mysql55"|"mysql56"|"mysql57"|"mariadb55"|"mariadb100") OPT_SQL_DB="${SQL_DB}" ;;
    "no"|"none") OPT_SQL_DB="NO" ;;
    *) echo "*** Error: Invalid SQL_DB value set in options.conf"; exit ;;
  esac

  case $(lc ${FTPD}) in
    "pureftpd"|"pure-ftpd"|"pureftp") OPT_FTPD="pureftpd" ;;
    "proftpd"|"pro-ftpd"|"proftp") OPT_FTPD="proftpd" ;;
    "no"|"none") OPT_FTPD="NO" ;;
    *) echo "*** Error: Invalid FTPD value set in options.conf"; exit ;;
  esac

  ## Verify: Copied from CB2:
  # if [ "${OPT_FTPD}" = "pureftpd" ]; then
  #   if [ -s "${DA_CONF_FILE}" ]; then
  #     UNIFIED_FTP="$(${DA_BIN} c | grep -m1 unified_ftp_password_file | cut -d= -f2)"
  #     if [ "${UNIFIED_FTP}" != "1" ]; then
  #       echo "unified_ftp_password_file is not set to 1. You must convert before you can use PureFTPD."
  #       echo "Please read this guide: http://www.directadmin.com/features.php?id=1134"
  #       echo ""
  #       echo "Simulation:"
  #       echo "     cd /usr/local/directadmin"
  #       echo "     echo 'action=convert&value=unifiedftp&simulate=yes' >> data/task.queue"
  #       echo "     ./dataskq d1"
  #       echo ""
  #       echo "Conversion:"
  #       echo "     cd /usr/local/directadmin"
  #       echo "     echo 'unified_ftp_password_file=1' >> conf/directadmin.conf"
  #       echo "     echo 'action=convert&value=unifiedftp' >> data/task.queue"
  #       echo "     ./dataskq d1"
  #       exit 1
  #     fi
  #   fi
  # fi

  case "$(uc ${EXIM})" in
    "YES"|"NO") OPT_EXIM="${EXIM}" ;;
    *) echo "*** Error: Invalid EXIM option set in options.conf"; exit ;;
  esac

  ## Alternate method:
  # if [ "$(uc ${EXIM})" = "YES" ]; then
  #   OPT_EXIM="YES"
  # if [ "$(uc ${EXIM})" = "NO" ]; then
  #   OPT_EXIM="NO"
  # fi

  if [ "$(uc ${DOVECOT})" = "YES" ]; then
    OPT_DOVECOT="YES"
  elif [ "$(uc ${DOVECOT})" = "NO" ]; then
    OPT_DOVECOT="NO"
  fi

  if [ "$(uc ${CLAMAV})" = "YES" ]; then
    OPT_CLAMAV="YES"
  elif [ "$(uc ${CLAMAV})" = "NO" ]; then
    OPT_CLAMAV="NO"
  fi

  if [ "$(uc "${CLAMAV_WITH_EXIM}")" = "YES" ]; then
    OPT_CLAMAV_WITH_EXIM="YES"
  else
    OPT_CLAMAV_WITH_EXIM="NO"
  fi

  if [ "$(uc "${WEBAPPS_INBOX_PREFIX}")" = "YES" ]; then
    OPT_WEBAPPS_INBOX_PREFIX="YES"
  else
    OPT_WEBAPPS_INBOX_PREFIX="NO"
  fi

  if [ "$(uc "${SPAM_INBOX_PREFIX}")" = "YES" ]; then
    OPT_SPAM_INBOX_PREFIX="YES"
  else
    OPT_SPAM_INBOX_PREFIX="NO"
  fi

  if [ "$(uc ${SPAMASSASSIN})" = "YES" ]; then
    OPT_SPAMASSASSIN="YES"
    if [ "$(uc "${SPAMASSASSIN_UTILITIES}")" = "YES" ]; then
      OPT_SPAMASSASSIN_UTILITIES="YES"
    else
      OPT_SPAMASSASSIN_UTILITIES="NO"
    fi
  elif [ "$(uc ${SPAMASSASSIN})" = "NO" ]; then
    OPT_SPAMASSASSIN="NO"
    OPT_SPAMASSASSIN_UTILITIES="NO"
  fi

  if [ "$(uc "${BLOCKCRACKING}")" = "YES" ]; then
    OPT_BLOCKCRACKING="YES"
  else
    OPT_BLOCKCRACKING="NO"
  fi

  if [ "$(uc "${EASY_SPAM_FIGHTER}")" = "YES" ]; then
    OPT_EASY_SPAM_FIGHTER="YES"
  else
    OPT_EASY_SPAM_FIGHTER="NO"
  fi

  if [ "${OPT_EASY_SPAM_FIGHTER}" = "YES" ] && [ "${OPT_SPAMASSASSIN}" = "NO" ]; then
    echo "*** Error: Easy Spam Fighter (ESF) requires SpamAssassin to be enabled."
    echo "Set SPAMASSASSIN=YES in options.conf"
    exit 1
  fi

  if [ "$(uc "${PROFTPD_UPLOADSCAN}")" = "YES" ]; then
    OPT_PROFTPD_UPLOADSCAN="YES"
  elif [ "$(uc "${PROFTPD_UPLOADSCAN}")" = "NO" ]; then
    OPT_PROFTPD_UPLOADSCAN="NO"
  fi

  if [ "$(uc "${PUREFTPD_UPLOADSCAN}")" = "YES" ]; then
    OPT_PUREFTPD_UPLOADSCAN="YES"
  else
    OPT_PUREFTPD_UPLOADSCAN="NO"
  fi

  if [ "$(uc "${AWSTATS}")" = "YES" ]; then
    OPT_AWSTATS="YES"
  elif [ "$(uc "${AWSTATS}")" = "NO" ]; then
    OPT_AWSTATS="NO"
  fi

  if [ "$(uc "${WEBALIZER}")" = "YES" ]; then
    OPT_WEBALIZER="YES"
  elif [ "$(uc "${WEBALIZER}")" = "NO" ]; then
    OPT_WEBALIZER="NO"
  fi

  if [ "$(uc "${MAJORDOMO}")" = "YES" ]; then
    OPT_MAJORDOMO="YES"
  else
    OPT_MAJORDOMO="NO"
  fi

  if [ "$(uc "${PHPMYADMIN}")" = "YES" ]; then
    OPT_PHPMYADMIN="YES"
  else
    OPT_PHPMYADMIN="NO"
  fi

  if [ "$(uc "${SUHOSIN}")" = "YES" ]; then
    OPT_SUHOSIN="YES"
  else
    OPT_SUHOSIN="NO"
  fi

  if [ "$(uc "${PHP_SUHOSIN_UPLOADSCAN}")" = "YES" ]; then
    OPT_SUHOSIN_UPLOADSCAN="YES"
  else
    OPT_SUHOSIN_UPLOADSCAN="NO"
  fi

  if [ "$(uc "${MODSECURITY}")" = "YES" ]; then
    OPT_MODSECURITY="YES"
  else
    OPT_MODSECURITY="NO"
  fi

  if [ "$(uc "${ROUNDCUBE}")" = "YES" ]; then
    OPT_ROUNDCUBE="YES"
  elif [ "$(uc "${ROUNDCUBE}")" = "NO" ]; then
    OPT_ROUNDCUBE="NO"
  fi

  if [ "$(uc "${PIGEONHOLE}")" = "YES" ]; then
    OPT_PIGEONHOLE="YES"
  else
    OPT_PIGEONHOLE="NO"
  fi

  ## Optional stuff
  if [ "$(uc ${PB_SYMLINK})" = "YES" ]; then
    OPT_PB_SYMLINK="YES"
  else
    OPT_PB_SYMLINK="NO"
  fi

  if [ "$(uc "${INSTALL_CCACHE}")" = "YES" ]; then
    OPT_INSTALL_CCACHE="YES"
  else
    OPT_INSTALL_CCACHE="NO"
  fi

  if [ "$(uc "${INSTALL_SYNTH}")" = "YES" ]; then
    OPT_INSTALL_SYNTH="YES"
  else
    OPT_INSTALL_SYNTH="NO"
  fi

  ## Following lines are from DA's setup.sh:
  if [ -s /root/.lan ]; then
    DA_LAN=$(cat /root/.lan)
  fi

  if [ -s /root/.insecure_download ]; then
    DA_INSECURE=$(cat /root/.insecure_download)
  fi

  if [ "${DA_INSECURE}" -eq 1 ]; then
    HTTP=http
    EXTRA_VALUE='&insecure=yes'
  fi

  if [ "${DA_LAN}" -eq 1 ]; then
    BIND_ADDRESS=""
  fi

  return
}

################################################################################################################################

## Install Application
## $2 = name of service
## e.g. install_app exim
install_app() {

  case $2 in
    "apache"|"apache24") apache_install ;;
    "awstats") awstats_install ;;
    "bfm") bfm_setup ;;
    "blockcracking"|"bc") blockcracking_install ;;
    "directadmin") directadmin_install ;;
    "dkim") pkgi ${PORT_LIBDKIM} ;;
    "easy_spam_fighter"|"esf") easyspamfighter_install ;;
    "exim") exim_install ;;
    "ioncube") pkgi "${PORT_IONCUBE}" ;;
    "ipfw") ipfw_setup ;;
    "libspf2"|"libspf") pkgi ${PORT_LIBSPF2} ;;
    "mariadb55")
      pkgi ${PORT_MARIADB55} ${PORT_MARIADB55_CLIENT}
      sql_post_install ;;
    "mariadb100")
      pkgi ${PORT_MARIADB100} ${PORT_MARIADB100_CLIENT}
      sql_post_install ;;
    "mysql55")
      pkgi ${PORT_MYSQL55} ${PORT_MYSQL55_CLIENT}
      sql_post_install ;;
    "mysql56")
      pkgi ${PORT_MYSQL56} ${PORT_MYSQL56_CLIENT}
      sql_post_install ;;
    "mysql57")
      pkgi ${PORT_MYSQL57} ${PORT_MYSQL57_CLIENT}
      sql_post_install ;;
    "nginx") nginx_install ;;
    "php"|"php55"|"php56"|"php70") php_install ;;
    "phpmyadmin"|"pma") phpmyadmin_install ;;
    "proftpd") proftpd_install ;;
    "pureftpd") pureftpd_install ;;
    "roundcube") roundcube_install ;;
    "spamassassin") spamassassin_install ;;
    "suhosin") suhosin_install ;;
    "webalizer") webalizer_install ;;
    *) show_install ;;
  esac

  return
}

################################################################

## Uninstall Application
## $1 = name of service
## e.g. uninstall_app exim
uninstall_app() {

  case "$2" in
    *) exit ;;
  esac

  return
}

################################################################################################################################

## Todo: Update PortsBuild Script
update() {
  echo "PortsBuild update script"
  # wget -O portsbuild.sh ${PB_MIRROR}/portsbuild.sh

  ## Backup configuration file
  cp -f "${PB_CONF}" "${PB_CONF}.backup"

  #fetch -o ./${PORTSBUILD_NAME}.tar.gz "${PB_MIRROR}/${PORTSBUILD_NAME}.tar.gz"

  if [ -s "${PORTSBUILD_NAME}.tar.gz" ]; then
    echo "Extracting ${PORTSBUILD_NAME}.tar.gz..."

    tar xvf "${PORTSBUILD_NAME}.tar.gz" --no-same-owner

    chmod 700 portsbuild.sh
  else
    echo "Unable to extract ${PORTSBUILD_NAME}.tar.gz."
  fi

  ## Symlink pb->portsbuild.sh
  if [ "${OPT_PB_SYMLINK}" = "YES" ]; then
    ln -s /usr/local/directadmin/portsbuild/portsbuild.sh /usr/local/bin/pb
  fi

  return
}

################################################################################################################################

## Todo: Upgrade
upgrade() {

  case $2 in
  *) show_menu_upgrade ;;
  esac

  return
}

################################################################

## Upgrade an application or service
upgrade_app() {

  case $2 in
    apache) apache_upgrade ;;
    awstats) awstats_upgrade ;;
    blockcracking) blockcracking_upgrade ;;
    directadmin) directadmin_upgrade ;;
    dovecot) dovecot_upgrade ;;
    easyspamfighter) easyspamfighter_upgrade ;;
    exim) exim_upgrade ;;
    ioncube) ioncube_upgrade ;;
    mariadb) mariadb_upgrade ;;
    modsecurity) modsecurity_upgrade ;;
    mysql) mysql_upgrade ;;
    nginx) nginx_upgrade ;;
    php) php_upgrade ;;
    phpmyadmin) phpmyadmin_upgrade ;;
    pigeonhole) pigeonhole_upgrade ;;
    portsbuild) portsbuild_upgrade ;;
    proftpd) proftpd_upgrade ;;
    pureftpd) pureftpd_upgrade ;;
    roundcube) roundcube_upgrade ;;
    spamassassin) spamassassin_upgrade ;;
    suhosin) suhosin_upgrade ;;
    webalizer) webalizer_upgrade ;;
    *) show_menu_upgrade ;;
  esac

  return
}

################################################################################################################################

## Show Menu for Upgrades
show_menu_upgrade() {

  echo ""
  echo "Listing possible upgrades"
  return
}

################################################################

## Show Setup Menu
show_menu_setup() {

  echo "To setup PortsBuild and DirectAdmin for the first time, run:"
  echo "  ./portsbuild setup <USER_ID> <LICENSE_ID> <SERVER_HOSTNAME> <ETH_DEV> <IP_ADDRESS> <IP_NETMASK>"
  echo ""
  return
}
################################################################################################################################

## Show Configuration Values
show_config() {

  printf "Configured Option Values\n"
  printf "========================\n"
  {
    echo "PHP1 Version: ${OPT_PHP1_VERSION}"
    echo "PHP1 Mode: ${OPT_PHP1_MODE}"
    echo "PHP ini Type: ${OPT_PHP_INI_TYPE}"
    echo "Web Server: ${OPT_WEBSERVER}"
    echo "Apache MPM: ${OPT_APACHE_MPM}"
    echo "SQL Server: ${OPT_SQL_DB}"
    echo "FTP Server: ${OPT_FTPD}"
    echo "Exim: ${OPT_EXIM}"
    echo "Dovecot: ${OPT_DOVECOT}"
    echo "ClamAV: ${OPT_CLAMAV}"
    echo "Exim w/ClamAV: ${OPT_CLAMAV_WITH_EXIM}"
    echo "Webapps Inbox Prefix: ${OPT_WEBAPPS_INBOX_PREFIX}"
    echo "Spam Inbox Prefix: ${OPT_SPAM_INBOX_PREFIX}"
    echo "BlockCracking: ${OPT_BLOCKCRACKING}"
    echo "Easy Spam Fighter: ${OPT_EASY_SPAM_FIGHTER}"
    echo "SpamAssassin: ${OPT_SPAMASSASSIN}"
    echo "SpamAssassin Utilities: ${OPT_SPAMASSASSIN_UTILITIES}"
    echo "ProFTPD Upload Scan: ${OPT_PROFTPD_UPLOADSCAN}"
    echo "PureFTPD Upload Scan: ${OPT_PUREFTPD_UPLOADSCAN}"
    echo "Awstats: ${OPT_AWSTATS}"
    echo "Webalizer: ${OPT_WEBALIZER}"
    echo "Majordomo: ${OPT_MAJORDOMO}"
    echo "phpMyAdmin: ${OPT_PHPMYADMIN}"
    echo "Suhosin: ${OPT_SUHOSIN}"
    echo "Suhosin Upload Scan: ${OPT_SUHOSIN_UPLOADSCAN}"
    echo "ModSecurity: ${OPT_MODSECURITY}"
    echo "RoundCube: ${OPT_ROUNDCUBE}"
    echo "PigeonHole: ${OPT_PIGEONHOLE}"
    echo "PB Symlink: ${OPT_PB_SYMLINK}"
    echo "Install CCache: ${OPT_INSTALL_CCACHE}"
    echo "Install Synth: ${OPT_INSTALL_SYNTH}"
  } | column -t -s:

  return
}

################################################################################################################################

## Show Debugging Information
show_debug() {

  printf "Debugging Information\n\n"
  printf "===[PB]========================\n"
  show_version
  # printf "PortsBuild Version/Build: %s / %s\n" ${PB_VER} ${PB_BUILD_DATE}
  printf "===[OS]========================\n"
  printf "Detected: %s\n" "${OS} ${OS_VER} ${MACHTYPE}"
  printf "Actual: %s\n" "$(uname -v)"
  printf "===[SSL]=======================\n"
  printf "OpenSSL binary path: %s\n" ${OPENSSL_BIN}
  printf "OpenSSL extra options: %s\n" "${OPENSSL_EXTRA}"
  printf "Prefer Apache SSL Certificates: %s\n" ${OPT_PREFER_APACHE_SSL_CERTS}
  printf "Prefer Exim SSL Certificates: %s\n" ${OPT_PREFER_EXIM_SSL_CERTS}
  printf "Prefer Custom SSL Certificates: %s\n" ${OPT_PREFER_CUSTOM_SSL_CERTS}
  printf "===[Misc]======================\n"
  printf "PortsBuild Symlink Enabled: %s\n" ${OPT_PB_SYMLINK}
  printf "\n"

  return
}

################################################################


## Verify: Rewrite Menu
rewrite_app() {

  case $2 in
    "apache"|"apache24") apache_rewrite_confs ;;
    "exim") exim_rewrite_confs ;;
    "dovecot") dovecot_rewrite_confs ;;
    "named"|"bind"|"dns") named_rewrite_confs ;;
    "nginx") rewrite_nginx_confs ;;
    "php") rewrite_php_confs ;;
    "virtual") rewrite_virtual_confs ;;
    *) show_rewrite_menu ;;
  esac

  return
}


################################################################

## Show Rewrite Menu
show_rewrite_menu() {

  printf "Rewrite Configuration Files\n"
  {
    echo "apache: Rewrite Apache configuration files and virtual hosts"
    echo "exim: Rewrite Exim configuration files"
    echo "dovecot: Rewrite Dovecot configuration files"
    echo "named: Rewrite Named (Bind) DNS files"
    echo "nginx: Rewrite Nginx configuration files and virtual hosts"
    echo "php: Rewrite PHP configuration files"
    echo "virtual: Rewrite /etc/virtual directory"
  } | column -t -s:

  return
}

################################################################################################################################

## Todo: Show Installation Menu
show_install() {

#  ( printf "Package Version Origin\n" ; pkg query -i -x "%n %v %o" '(www/apache24|www/nginx|lang/php54|lang/php55|lang/php56|ftp/curl|mail/exim|mail/dovecot2|lang/perl5|mail/roundcube|/www/phpMyAdmin|mail/spamassassin|ftp/wget)' ) | column -t

  printf "Available packages to install:\n"
  {
    echo "apache:Apache 2.4"
    echo "awstats:Awstats"
    echo "bfm:Brute Force Monitor"
    echo "bc:Blockcracking"
    echo "directadmin:DirectAdmin"
    echo "dkim:DKIM"
    echo "esf:Easy Spam Fighter"
    echo "exim:Exim"
    echo "ioncube:Ioncube"
    echo "ipfw:IPFW Firewall setup"
    echo "libspf2:libspf"
    echo "mariadb:MariaDB"
    echo "mysql:MySQL"
    echo "nginx:Nginx"
    echo "php:PHP"
    echo "pma:phpMyAdmin"
    echo "proftpd:ProFTPd"
    echo "pureftpd:PureFTPd"
    echo "roundcube:RoundCube"
    echo "spamassassin:SpamAssassin"
    echo "suhosin:Suhosin"
    echo "webalizer:Webalizer"
  } | column -t -s:


  # echo "Available packages to install:"
  # echo "apache Apache 2.4"
  # echo "awstats Awstats"
  # echo "bfm Brute Force Monitor"
  # echo "bc Blockcracking"
  # echo "directadmin DirectAdmin"
  # echo "dkim DKIM"
  # echo "esf Easy Spam Fighter"
  # echo "exim Exim"
  # echo "ioncube Ioncube"
  # echo "ipfw IPFW Firewall setup"
  # echo "libspf2 libspf"
  # echo "mariadb MariaDB"
  # # echo "mariadb55 MariaDB 5.5"
  # # echo "mariadb100 MariaDB 10.0"
  # echo "mysql MySQL"
  # # echo "mysql55 MySQL 5.5"
  # # echo "mysql56 MySQL 5.6"
  # # echo "mysql57 MySQL 5.7"
  # echo "nginx Nginx"
  # echo "php PHP"
  # echo "pma phpMyAdmin"
  # echo "proftpd ProFTPd"
  # echo "pureftpd PureFTPd"
  # echo "roundcube RoundCube"
  # echo "spamassassin SpamAssassin"
  # echo "suhosin Suhosin"
  # echo "webalizer Webalizer"

  return

}

################################################################################################################################

## Show logo :)
show_logo() {
  echo "                ___\/_ "
  echo "               /  //\  "
  echo "       _______/  /___  "
  echo "      /  __  / ___  /  "
  echo "     /  /_/ / /__/ /   "
  echo "    /  ____/______/    "
  echo "   /  /                "
  echo "  /__/                 "
  echo ""
}

################################################################

## Show version
show_version() {
  printf "  PortsBuild version %s build %s\n" "${PB_VER}" "${PB_BUILD_DATE}"
  return
}

################################################################

## Show versions
show_versions() {
  ## alternative way: awk '{printf("%15s %10s\n", $1, $2)}'
  ( printf "Package Version Origin\n" ; pkg query -i -x "%n %v %o" '(www/apache24|www/nginx|lang/php54|lang/php55|lang/php56|ftp/curl|mail/exim|mail/dovecot2|lang/perl5|mail/roundcube|/www/phpMyAdmin|mail/spamassassin|ftp/wget)' ) | column -t
  return
}

################################################################

## Show outdated versions of (select) packages
show_outdated() {
  printf "List of installed packages that are out of date:\n"
  ( printf "Package Outdated\n" ; pkg version -l '<' -x '(www/apache24|www/nginx|lang/php54|lang/php55|lang/php56|ftp/curl|mail/exim|mail/dovecot2|lang/perl5|mail/roundcube|/www/phpMyAdmin|mail/spamassassin|ftp/wget)' ) | column -t
  return
}

################################################################

## Show Audit
show_audit() {
  ${PKG} audit
}

################################################################

## About PortsBuild
show_about() {
  show_logo
  show_version
  echo "Visit portsbuild.org or github.com/portsbuild/portsbuild"
  return
}

################################################################

## Show the main menu
show_main_menu() {
  show_logo
  show_version
  show_menu
}

################################################################

## Show selection menu
show_menu() {

  echo ""
  echo "  Usage: "
  echo "    $0 command [options] [arguments]"
  echo ""

  # Options:
  #   -h, --help                     Display this help message
  #   -q, --quiet                    Do not output any message
  #   -V, --version                  Display this application version
  #       --ansi                     Force ANSI output
  #       --no-ansi                  Disable ANSI output
  #   -n, --no-interaction           Do not ask any interactive question
  #       --profile                  Display timing and memory usage information
  #   -d, --working-dir=WORKING-DIR  If specified, use the given directory as working directory.
  #   -v|vv|vvv, --verbose           Increase the verbosity of messages: 1 for normal output, 2 for more verbose output and 3 for debug

  # echo "  Options:"
  # echo "    -h, --help"
  # echo "    -q, --quiet"
  # echo "    -v, --verbose"
  # echo ""

  echo "  Available commands:"
  {
    echo "    config: Display the current configuration option values"
    echo "    debug: Displays debugging information"
    echo "    help: Displays help information"
    # echo "  info Displays information about an application or service"
    echo "    install: Install an application or service"
    # echo "  options: Show configured PortsBuild options"
    echo "    outdated: Show outdated applications or services on the system"
    echo "    rewrite: Rewrite (update) a configuration file for an application or service"
    echo "    setup: Setup PortsBuild and DirectAdmin (first-time installations)"
    echo "    update: Updates the portsbuild script"
    echo "    upgrade: Upgrades an application or service"
    #echo "    verify: Verify something"
    # echo "  "
    echo "    versions: Show version information on all applications and services installed"
    echo ""
  } | column -t -s:

# menu_command
# menu_command_desc
# menu_command_option
# menu_command_option_desc

# menu_update_update = "update"
# menu_update_desc = "Update an application or service"

  return
}


################################################################

validate_options

## ./portsbuild selection screen
case "$1" in
  # create_options)  ;;
  # set)  ;;
  # check_options) ;;
  "about") show_about ;;                ## show about
  "audit") show_audit ;;                ## run "pkg audit"
  "c"|"config") show_config ;;          ## show configured option values
  "d"|"debug") show_debug ;;            ## show debugging info
  "i"|"install") install_app "$@" ;;    ## install an application
  # "installed") show_installed ;;        ## show currently installed packages
  "o"|"outdated") show_outdated ;;      ## show installed packages that are out of date
  "r"|"rewrite") rewrite_app "$@" ;;    ## rewrite a configuration file (e.g. apache vhosts)
  "setup") global_setup "$@" ;;         ## first time setup
  "upd"|"update") update ;;             ## update PB script
  "upg"|"upgrade") upgrade "$@" ;;      ## let portsbuild upgrade an app/service (e.g. php via pkg)
  "check"|"verify") verify ;;           ## verify system state
  "version") show_version ;;            ## show portsbuild version
  "v"|"versions"|"installed") show_app_versions ;;  ## show app/service versions via pkg
  *) show_main_menu ;;
esac

################################################################################################################################

## EOF
exit 0
