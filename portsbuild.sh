#!/bin/sh
# ******************************************************************************
# >>> PortsBuild
#
#  Alternative to DirectAdmin's CustomBuild for FreeBSD systems using ports and packages
#
#  Scripted by mmx aka -sg aka sarog aka Saro.
#
#  Based on the work of CustomBuild 2.x, written by DirectAdmin and Martynas Bendorius (smtalk).
#
#  CustomBuild2 thread: http://forum.directadmin.com/showthread.php?t=44743
#
#  DirectAdmin Homepage : https://www.directadmin.com
#  DirectAdmin Forums   : https://forums.directadmin.com
#
#  PortsBuild WWW       : https://www.portsbuild.org (coming soon)
#  PortsBuild GitHub    : https://github.com/portsbuild/portsbuild
#
# ******************************************************************************
#
#  Requirements:
#  - DirectAdmin license
#  - FreeBSD 12/13.1+ (amd64 only)
#  - chmod 700 portsbuild.sh
#  - Patience.
#
#  New Installations:
#  - Modify: options.conf
#  - Setup : ./portsbuild.sh setup <USER_ID> <LICENSE_ID> <SERVER_FQDN> <ETH_DEV> <IP_ADDRESS> <IP_NETMASK>
#
#  Existing users:
#  - Update : ./portsbuild.sh update
#  - Upgrade: ./portsbuild.sh upgrade <package|port|service>
#  - Rewrite: ./portsbuild.sh rewrite <configuration>
#  - Verify : ./portsbuild.sh verify
#
#  TODO: Changelog/History: see CHANGELOG for more details
#
# ******************************************************************************
#
#  ** Need help? Visit the DirectAdmin Forums and look for the PB thread *URL here*
#
#  ** Found a bug? Please submit an issue: https://github.com/portsbuild/portsbuild/issues
#
#  ** Want to contribute or improve PortsBuild? Please fork and submit a pull request. :)
#
################################################################################

## Fun fact #1: root's shell is actually /bin/tcsh

PB_VER="0.1.2"
PB_BUILD_DATE=20170520
IFS="$(printf '\n\t')"
LANG=C

if [ "$(/usr/bin/id -u)" != "0" ]; then
  printf "*** Error: Must run this script as the root user.\n"
  exit 1
fi

readonly OS=$(uname)
readonly OS_VER=$(uname -r | cut -d- -f1) # 12.1, 13.0, 13.1
readonly OS_B64=$(uname -m | grep -c 64)  # 0, 1
readonly OS_MAJ=$(uname -r | cut -d. -f1) # 12, 13, 14
readonly OS_HOST=$(hostname)

if [ "${OS}" = "FreeBSD" ]; then
  if [ "${OS_B64}" -eq 1 ]; then
  if [ "${OS_MAJ}" != "13" ] && [ "${OS_MAJ}" != "12" ]; then
      printf "Warning: Unsupported FreeBSD operating system detected.\n"
      printf "PortsBuild has been tested to work with FreeBSD versions 12.2, 13.1 amd64 (x64) only.\n"
      printf "You can press CTRL+C within 5 seconds to quit the PortsBuild script now,\n"
      printf "or proceed at your own risk.\n"
      sleep 5
    fi
  else
    printf "Error: i386 (x86) systems are not supported.\n"
    printf "PortsBuild requires the 64-bit version (amd64) of FreeBSD.\n"
    exit 1
  fi
else
  printf "PortsBuild is for FreeBSD systems only.\n"
  printf "Please use CustomBuild for your Linux needs.\n"
  printf "Visit: http://forum.directadmin.com/showthread.php?t=44743\n"
  exit 1
fi

################################################################################
## PortsBuild Paths & Files
################################################################################

PB_PATH=/usr/local/portsbuild
if [ ! -e "${PB_PATH}" ] || [ "$(pwd)" != "${PB_PATH}" ]; then
  PB_PATH=$(pwd)
else
  PB_PATH=/usr/local/portsbuild
fi

readonly PB_PATH
readonly PB_DEBUG="NO"
readonly PB_CONF="${PB_PATH}/options.conf"
readonly PB_CONFIG="${PB_PATH}/configure"
readonly PB_CUSTOM="${PB_PATH}/custom"
readonly PB_PATCHES="${PB_PATH}/patches"
readonly PB_SETUP=/root/portsbuild.txt

## PortsBuild Remote File Repository
readonly PB_GITHUB="https://github.com/portsbuild/portsbuild"
readonly PB_GITRAW="https://raw.githubusercontent.com/portsbuild/portsbuild/master"
readonly PB_MIRROR="http://s3.amazonaws.com/portsbuild/files"

################################################################################
### File: constants.conf
################################################################################

## System Accounts
readonly DA_ADMIN_USER='admin'
readonly DA_SQLDB_USER='da_admin'
readonly APACHE_USER='apache'     ## www
readonly APACHE_GROUP='apache'    ## www
readonly NGINX_USER='nginx'       ## www
readonly NGINX_GROUP='nginx'      ## www
readonly WEBAPPS_USER='webapps'
readonly WEBAPPS_GROUP='webapps'
readonly EXIM_USER='mail'         ## mailnull
readonly EXIM_GROUP='mail'        ## mail
# readonly DA_SRV_USER=diradmin
# readonly DA_SRV_GROUP=diradmin

## System Binary/Application paths and variables
# readonly BIN=/bin
# readonly UB=/usr/bin
# readonly US=/usr/sbin
# readonly ULB=/usr/local/bin
# readonly ULS=/usr/local/sbin
# readonly ULE=/usr/local/etc
readonly LOGS=/var/log
readonly ENV=/usr/bin/env
readonly CHOWN=/usr/sbin/chown
readonly CHGRP=/usr/bin/chgrp
readonly CHMOD=/bin/chmod
readonly CP=/bin/cp
readonly COLUMN=/usr/bin/column
readonly FETCH=/usr/bin/fetch
readonly GREP=/usr/bin/grep
readonly KILLALL=/usr/bin/killall
readonly MAKE=/usr/bin/make
readonly MKDIR=/bin/mkdir
readonly PATCH=/usr/bin/patch
readonly PERL=/usr/local/bin/perl
readonly PKG=/usr/sbin/pkg
readonly PW=/usr/sbin/pw
readonly PORTSNAP=/usr/sbin/portsnap
readonly PORTMASTER=/usr/local/sbin/portmaster
readonly PRINTF=/usr/bin/printf
readonly RCD=/usr/local/etc/rc.d
readonly SERVICE=/usr/sbin/service
readonly STAT=/usr/bin/stat
readonly SYNTH=/usr/local/bin/synth
readonly SYSRC=/usr/sbin/sysrc
readonly SYSCTL=/sbin/sysctl
readonly TOUCH=/usr/bin/touch
readonly WGET=/usr/local/bin/wget
readonly WGET_CONNECT_OPTIONS='--connect-timeout=10 --read-timeout=10 --tries=3'
readonly TAR=/usr/bin/tar

## Runtime Discovery
readonly CPU_CORES="$("${SYSCTL}" -n hw.ncpu)"
readonly SERVER_DOMAIN=$(echo "${OS_HOST}" | cut -d. -f2,3,4,5,6)
readonly NEWSYSLOG_FILE=/usr/local/etc/newsyslog.conf.d/directadmin.conf
readonly SSHD_CONFIG=/etc/ssh/sshd_config

## DirectAdmin Paths & Files
readonly DA_PATH=/usr/local/directadmin
readonly DA_BIN="${DA_PATH}/directadmin"
readonly DA_SCRIPTS_PATH="${DA_PATH}/scripts"
readonly DA_CRON_FILE="${DA_SCRIPTS}/directadmin_cron"
readonly DA_CONF="${DA_PATH}/conf/directadmin.conf"
readonly DA_CONF_TEMPLATE="${DA_PATH}/data/templates/directadmin.conf"
readonly DA_MYSQL_CONF="${DA_PATH}/conf/mysql.conf"
readonly DA_MYSQL_CNF="${DA_PATH}/conf/my.cnf"
readonly DA_LICENSE="${DA_PATH}/conf/license.key"
readonly DA_SETUP_TXT="${DA_SCRIPTS_PATH}/setup.txt"
readonly DA_TASK_QUEUE="${DA_PATH}/data/task.queue.cb"
readonly DA_SERVICES="${DA_PATH}/data/admin/services.status"
readonly DA_SSL_KEY="${DA_PATH}/conf/cakey.pem"
readonly DA_SSL_CRT="${DA_PATH}/conf/cacert.pem"
readonly DA_SSL_CA="${DA_PATH}/conf/carootcert.pem"

## CustomBuild Paths & Files
readonly CB_PATH="${DA_PATH}/custombuild"
readonly CB_CONF="${CB_PATH}/options.conf"

## Apache 2.4
readonly APACHE_PATH=/usr/local/etc/apache24
readonly APACHE_LIBS="/usr/local/libexec/apache24"
readonly APACHE_EXTRAS="${APACHE_PATH}/extra"
readonly APACHE_CONF="${APACHE_PATH}/httpd.conf"
readonly APACHE_HOSTNAME_CONF="${APACHE_EXTRAS}/httpd-hostname.conf"
readonly APACHE_MIME_TYPES="${APACHE_PATH}/mime.types"
readonly APACHE_HTPASSWD=/usr/local/bin/htpasswd
readonly APACHE_HTTPD=/usr/local/sbin/httpd
readonly APACHE_SSL_KEY="${APACHE_PATH}/ssl/server.key"
readonly APACHE_SSL_CRT="${APACHE_PATH}/ssl/server.crt"
readonly APACHE_SSL_CA="${APACHE_PATH}/ssl/server.ca"
readonly APACHE_SUEXEC=/usr/local/sbin/suexec
readonly APXS=/usr/local/sbin/apxs
readonly PHP_HANDLERS_CONF="${APACHE_EXTRAS}/httpd-php-handlers.conf"
# readonly APACHE_PID=/var/run/httpd.pid

## Nginx
readonly NGINX_PATH=/usr/local/etc/nginx
readonly NGINX_CONF="${NGINX_PATH}/nginx.conf"
readonly NGINX_SSL_KEY="${NGINX_PATH}/ssl/server.key"
readonly NGINX_SSL_CRT="${NGINX_PATH}/ssl/server.crt"
readonly NGINX_SSL_CA="${NGINX_PATH}/ssl/server.ca"
# readonly NGINX_PID=/var/run/nginx.pid

## Needed?
# readonly NGINX_VHOSTS=${NGINX_PATH}/vhosts
# NGINX_VHOSTS_CONF=${NGINX_PATH}/directadmin-vhosts.conf
# NGINX_LOGS=${LOGS}/nginx/domains
# NGINX_IPS_CONF=${NGINX_PATH}/directadmin-ips.conf

readonly WWW_DIR=/usr/local/www         ## Ports uses "${WWW_DIR}"
readonly WWW_TMP_DIR="${WWW_DIR}/tmp"   ## Temporary files directory

readonly WEBMAIL_PATH="${WWW_DIR}/webmail"
readonly WEBMAIL_TMP_DIR="${WEBMAIL_PATH}/tmp"

## RoundCube
readonly ROUNDCUBE_PATH="${WWW_DIR}/roundcube"
readonly ROUNDCUBE_CONF="${ROUNDCUBE_PATH}/config/config.inc.php"

## PHP
readonly PHP_ETC=/usr/local/etc/php
readonly PHP_INI=/usr/local/etc/php.ini
readonly PHP_INI_WEBAPPS="${PHP_ETC}/50-webapps.ini"
# readonly PHP_INI_EXTENSIONS="${PHP_ETC}/extensions.ini"
readonly PHP_INI_OPCACHE="${PHP_ETC}/opcache.ini"
readonly PHP_INI_DIRECTADMIN="${PHP_ETC}/10-directadmin.ini"
readonly PHP_FPM_CONF="/usr/local/etc/php-fpm.conf"
readonly PHP_SOCKETS_PATH=/var/run/php/sockets
readonly PHP_RELEASE_SET="7.4 8.0 8.1 8.2"
readonly PHP_SHORTRELEASE_SET="$(echo "${PHP_RELEASE_SET}" | tr -d '.')"
readonly PHP_FPM_BIN=/usr/local/sbin/php-fpm
readonly SUPHP_CONF_FILE=/usr/local/etc/suphp.conf
readonly SUPHP_AP2_CONF="${APACHE_EXTRAS}/httpd-suphp.conf"
# readonly SUPHP_PATH=/usr/local/suphp
# readonly SUPHP_SO=/usr/lib/apache/mod_suphp.so

## Virtual Mail Directory
readonly VIRTUAL_PATH=/etc/virtual

## Exim
readonly EXIM_BIN=/usr/local/sbin/exim
readonly EXIM_PATH=/usr/local/etc/exim
readonly EXIM_CONF="${EXIM_PATH}/configure" ## required_files in rc.d/exim
readonly EXIM_BC_PATH="${EXIM_PATH}/bc"
readonly EXIM_ESF_PATH="${EXIM_PATH}/esf"
readonly EXIM_SSL_KEY="${EXIM_PATH}/ssl/exim.key"
readonly EXIM_SSL_CRT="${EXIM_PATH}/ssl/exim.crt"
readonly EXIM_SSL_CA="${EXIM_PATH}/ssl/exim.ca"

## Dovecot
readonly DOVECOT_BIN=/usr/local/sbin/dovecot
readonly DOVECOT_PATH=/usr/local/etc/dovecot
readonly DOVECOT_CONF="${DOVECOT_PATH}/dovecot.conf"
readonly DOVECOT_SSL_KEY="${DOVECOT_PATH}/ssl/dovecot.key"
readonly DOVECOT_SSL_CRT="${DOVECOT_PATH}/ssl/dovecot.crt"
readonly DOVECOT_SSL_CA="${DOVECOT_PATH}/ssl/dovecot.ca"

## phpMyAdmin
readonly PMA_PATH="${WWW_DIR}/phpMyAdmin"
readonly PMA_CONFIG="${PMA_PATH}/config.inc.php"

## MySQL/MariaDB
# readonly MYSQL_RELEASE_SET="5.5 5.6 5.7"
# readonly MARIADB_RELEASE_SET="5.5 10.0 10.1"
readonly MYSQL_CNF=/usr/local/etc/my.cnf
readonly MYSQL=/usr/local/bin/mysql
readonly MYSQLADMIN=/usr/local/bin/mysqladmin
readonly MYSQLCHECK=/usr/local/bin/mysqlcheck
readonly MYSQLD=/usr/local/libexec/mysqld
readonly MYSQLD_SAFE=/usr/local/bin/mysqld_safe
readonly MYSQLDUMP=/usr/local/bin/mysqldump
readonly MYSQLIMPORT=/usr/local/bin/mysqlimport
readonly MYSQLSECURE=/usr/local/bin/mysql_secure_installation
readonly MYSQLSHOW=/usr/local/bin/mysqlshow
readonly MYSQLUPGRADE=/usr/local/bin/mysql_upgrade

## ClamAV
readonly CLAMDSCAN=/usr/local/bin/clamdscan
readonly CLAMD_CONF=/usr/local/etc/clamd.conf
readonly FRESHCLAM_CONF=/usr/local/etc/freshclam.conf

## ModSecurity
readonly MODSECURITY_PATH=/usr/local/etc/modsecurity
readonly MODSECURITY_CONF="${MODSECURITY_PATH}/modsecurity.conf"

## ProFTPD
readonly PROFTPD_CONF=/usr/local/etc/proftpd.conf
readonly PROFTPD_ETC=/usr/local/etc/proftpd
readonly PROFTPD_DHPARAMS="${PROFTPD_ETC}/dhparams.pem"
readonly PROFTPD_CLAMAV_CONF=/usr/local/etc/proftpd.clamav.conf
readonly PROFTPD_PASSWD=/usr/local/etc/proftpd.passwd
# readonly PROFTPD_PASSWD=/usr/local/etc/proftpd.db

## PureFTPD
readonly PUREFTPD_UPLOADSCAN_BIN=/usr/local/bin/pureftpd_uploadscan.sh

################################################################################
### File: defaults.conf (default values)
################################################################################

DA_ADMIN_EMAIL="${DA_ADMIN_USER}@${SERVER_DOMAIN}"

## todo: retrieve commit hash via dig
case "${OS_MAJ}" in
  # 9|10) DA_SERVICES_PKG="services_freebsd91_64.tar.gz" ;;
  # 11) DA_SERVICES_PKG="services_freebsd110_64.tar.gz" ;;
  12) ;;
  13) ;;
  14) ;;
esac

: "${MIN_PASS_LENGTH:=12}"          ## Min Random Password Length
: "${MAX_PASS_LENGTH:=16}"          ## Max Random Password Length
: "${NEWSYSLOG_DAYS:=10}"           ## Number of days to keep logs before rotating
: "${DA_LAN:=0}"                    ## DA LAN Mode
: "${DA_INSECURE:=0}"               ## DA Insecure Mode
: "${LAN_IP=""}"                    ## Server's LAN IP

: "${PHP_VERSION:="8.2"}"          ## PHP #1 Version
: "${PHP_MODE:="php-fpm"}"         ## PHP #1 Mode

: "${EXIM_RECIPIENTS_MAX:=150}"       ## Exim Max Recipients

: "${SQL_DATA_PATH:=/var/db/mysql}"   ## SQL DB files path (DA default: /home/mysql)
: "${MYSQL_HOST:=localhost}"          ## SQL default hostname
: "${DEFAULT_MY_CNF:="my-huge.cnf"}"  ## Default my.cnf file to use

## Custom SSL Certificates
CUSTOM_SSL_KEY='/usr/local/etc/ssl/server.key'
CUSTOM_SSL_CRT='/usr/local/etc/ssl/server.crt'
CUSTOM_SSL_CA='/usr/local/etc/ssl/server.ca'

# ROUNDCUBE_CONFIG_CUSTOM="${ROUNDCUBE_CONF}"
## Already defined in roundcube_install()
# ROUNDCUBE_PLUGINS="${PB_CUSTOM}/roundcube/plugins"
# ROUNDCUBE_SKINS="${PB_CUSTOM}/roundcube/skins"
# ROUNDCUBE_PROGRAM="${PB_CUSTOM}/roundcube/program"
# ROUNDCUBE_HTACCESS="${PB_CUSTOM}/roundcube/.htaccess"

################################################################################
### Alternatives Discovery
################################################################################

## OPT_WITH_OPENSSL_PORT=$(sysrc -e -f /etc/make.conf WITH_OPENSSL_PORT)
WITH_OPENSSL_PORT="$(${SYSRC} -q -e -f /etc/make.conf WITH_OPENSSL_PORT)"
## Use either BASE or PORT OpenSSL libraries.
## The latter only if make.conf contains WITH_OPENSSL_PORT=YES
if [ -x /usr/local/bin/openssl ] && [ "${WITH_OPENSSL_PORT}" ]; then
  OPENSSL=/usr/local/bin/openssl
  # GLOBAL_MAKE_VARIABLES="${GLOBAL_MAKE_VARIABLES} WITH_OPENSSL_PORT=YES"
elif [ -x /usr/bin/openssl ]; then
  OPENSSL=/usr/bin/openssl
  # GLOBAL_MAKE_VARIABLES="${GLOBAL_MAKE_VARIABLES} WITH_OPENSSL_BASE=YES"
else
  printf "*** Error: OpenSSL binary not found. Does /usr/bin/openssl exist?\n"
  exit 0
fi

readonly OPENSSL

## Check for this file and append to OpenSSL calls using -config:
# OPENSSL_EXTRA="-config ${PB_CUSTOM}/ssl/openssl_req.conf"
# -config ${PB_CUSTOM}/ssl/openssl_req.conf
OPENSSL_EXTRA=""

################################################################################

## See if IPV6 is enabled in DirectAdmin:
if [ -e "${DA_BIN}" ]; then
  IPV6=$(${DA_BIN} c | grep -m1 '^ipv6=' | cut -d= -f2)
else
  IPV6=0
fi

readonly IPV6

################################################################################
## PortsBuild Compatibility Switches
################################################################################
readonly COMPAT_APACHE24_SYMLINKS="NO"
readonly COMPAT_DOVECOT_SYMLINKS="YES"
readonly COMPAT_EXIM_SYMLINKS="YES"
readonly COMPAT_NAMED_SYMLINKS="YES"
readonly COMPAT_PHP_SYMLINKS="YES"
readonly COMPAT_SQL_SYMLINKS="YES"

################################################################################

################################################################################
### File: ports.conf
################################################################################

## FreeBSD Ports path
readonly PORTS_BASE=/usr/ports
# readonly PORTS_VAR_DB=/var/db/ports
# readonly PKG_VAR_DB=/var/db/pkgs

## Ports: Dependencies
readonly PORT_PORTMASTER='ports-mgmt/portmaster'
readonly PORT_SYNTH='ports-mgmt/synth'
readonly PORT_PERL='lang/perl5.32'
readonly PORT_AUTOCONF='devel/autoconf'
readonly PORT_AUTOMAKE='devel/automake'
readonly PORT_BISON='devel/bison'
readonly PORT_CA_ROOT_NSS='security/ca_root_nss'
readonly PORT_CURL='ftp/curl'
readonly PORT_LIBTOOL='devel/libtool'
readonly PORT_LIBXML2='textproc/libxml2'
readonly PORT_LIBXSLT='textproc/libxslt'
readonly PORT_LIBARCHIVE='archivers/libarchive'
readonly PORT_FREETYPE2='print/freetype2'
readonly PORT_CYRUSSASL2='security/cyrus-sasl2'
readonly PORT_PYTHON='lang/python'
readonly PORT_CCACHE='devel/ccache'
readonly PORT_CMAKE='devel/cmake'
readonly PORT_GMAKE='devel/gmake'
readonly PORT_WGET='ftp/wget'
readonly PORT_FLEX='textproc/flex'
readonly PORT_GD='graphics/gd'
readonly PORT_SASL2='security/cyrus-sasl2'
readonly PORT_MAILX='mail/mailx'
readonly PORT_BIND='dns/bind99'
readonly PORT_GCC6='lang/gcc6-aux'
readonly PORT_NCURSES='devel/ncurses'

readonly PORT_COMPATS="misc/compat4x misc/compat5x misc/compat6x misc/compat7x misc/compat8x"
readonly PORT_DEPS="${PORT_GMAKE} ${PORT_PERL} ${PORT_WGET} ${PORT_BISON} \
${PORT_FLEX} ${PORT_GD} ${PORT_SASL2} ${PORT_CMAKE} ${PORT_PYTHON} \
${PORT_AUTOCONF} ${PORT_LIBTOOL} ${PORT_LIBARCHIVE} ${PORT_MAILX} ${PORT_CA_ROOT_NSS} \
${PORT_COMPATS}"
readonly PORT_DEPS_100="${PORT_DEPS} ${PORT_BIND} misc/compat9x"
readonly PORT_DEPS_110="${PORT_DEPS_100} misc/compat10x"
readonly PORT_DEPS_120="${PORT_DEPS_110} misc/compat11x"
readonly PORT_DEPS_130="${PORT_DEPS_120} misc/compat12x"
readonly PORT_DEPS_140="${PORT_DEPS_130} misc/compat13x"

readonly LINUX_COMPAT_C7='emulators/linux_base-c7'

## Ports: Web Servers
readonly PORT_APACHE24='www/apache24'
readonly PORT_NGINX='www/nginx'
readonly PORT_NGHTTP2='www/nghttp2'

readonly PORT_FASTCGI='www/mod_fastcgi'
readonly PORT_FCGID='www/mod_fcgid'

## Ports: PHP
readonly PORT_SUPHP='www/suphp'
readonly PORT_PHPMYADMIN='databases/phpmyadmin'
readonly PORT_IONCUBE='devel/ioncube'
readonly PORT_SUHOSIN='security/suhosin'
readonly PORT_HTSCANNER='devel/pecl-htscanner'
readonly PORT_MOD_SECURITY='www/mod_security'

## Ports: Mail & Related Services
readonly PORT_EXIM='mail/exim'
readonly PORT_SPAMASSASSIN='mail/spamassassin'
readonly PORT_SPAMASSASSIN_UTILITIES='mail/sa-utils'
readonly PORT_DOVECOT2='mail/dovecot2'
readonly PORT_PIGEONHOLE='mail/dovecot2-pigeonhole'
readonly PORT_CLAMAV='security/clamav'
readonly PORT_ROUNDCUBE='mail/roundcube'
readonly PORT_LIBSPF2='mail/libspf2'
readonly PORT_LIBDKIM='mail/libdkim'
readonly PORT_MAILMAN='mail/mailman'

## Ports: FTPd
readonly PORT_PUREFTPD='ftp/pure-ftpd'
readonly PORT_PROFTPD='ftp/proftpd'
readonly PORT_PROFTPD_CLAMAV='security/proftpd-mod_clamav'

## Ports: Database Servers
### MariaDB
readonly PORT_MARIADB103='databases/mariadb103-server'
readonly PORT_MARIADB104='databases/mariadb104-server'
readonly PORT_MARIADB105='databases/mariadb105-server'
readonly PORT_MARIADB106='databases/mariadb106-server'
readonly PORT_MARIADB103_CLIENT='databases/mariadb103-client'
readonly PORT_MARIADB104_CLIENT='databases/mariadb104-client'
readonly PORT_MARIADB105_CLIENT='databases/mariadb105-client'
readonly PORT_MARIADB106_CLIENT='databases/mariadb106-client'

### MySQL
readonly PORT_MYSQL55='databases/mysql55-server'
readonly PORT_MYSQL56='databases/mysql56-server'
readonly PORT_MYSQL57='databases/mysql57-server'
readonly PORT_MYSQL80='databases/mysql80-server'
readonly PORT_MYSQL55_CLIENT='databases/mysql55-client'
readonly PORT_MYSQL56_CLIENT='databases/mysql56-client'
readonly PORT_MYSQL57_CLIENT='databases/mysql57-client'
readonly PORT_MYSQL80_CLIENT='databases/mysql80-client'

## Ports: Web Stats
readonly PORT_AWSTATS='www/awstats'
readonly PORT_WEBALIZER='www/webalizer'

# readonly PORT_PCRE='devel/pcre'
# to remove: readonly PORT_LETSENCRYPT='security/letsencrypt.sh'

################################################################################
### File: make.conf
################################################################################

### Global (default) make options

## These variables are included every time 'make' is called.
## Default is to source /etc/make.conf
: "${GLOBAL_MAKE_VARS=""}" # e.g. WITH_OPENSSL_PORT=YES BATCH=YES WITH_CCACHE_BUILD=YES

## These options are included every time a Port is built via 'make'.
: "${GLOBAL_MAKE_SET=""}"
: "${GLOBAL_MAKE_UNSET=""}" # EXAMPLES X11 HTMLDOCS CUPS TESTS DOCS NLS

APACHE24_MAKE_SET="SUEXEC" # MPM_EVENT
APACHE24_MAKE_UNSET="" # MPM_PREFORK
# APACHE24_EXTRA_PATCHES=""

NGINX_MAKE_SET=""
NGINX_MAKE_UNSET=""

## Prefixes for multi-PHP installations:
# readonly PHP56_PREFIX='/usr/local/php56'
# readonly PHP70_PREFIX='/usr/local/php70'
# readonly PHP71_PREFIX='/usr/local/php71'

DEFAULT_PHP_MAKE_SET=""
DEFAULT_PHP_MAKE_UNSET=""
DEFAULT_PHP_EXT_MAKE_SET="BCMATH BZ2 CALENDAR CTYPE CURL DOM EXIF FILEINFO FILTER FTP \
GD GETTEXT HASH ICONV IMAP JSON MBSTRING MCRYPT MYSQL MYSQLI OPCACHE OPENSSL PDF \
PDO PDO_MYSQL PDO_SQLITE PHAR POSIX PSPELL READLINE RECODE SESSION SIMPLEXML SOAP \
SOCKETS SQLITE3 TOKENIZER WDDX XML XMLREADER XMLRPC XMLWRITER XSL ZIP ZLIB"
DEFAULT_PHP_EXT_MAKE_UNSET=""

#PHP56_MAKE_SET="${DEFAULT_PHP_MAKE_SET}" # MAILHEAD
#PHP56_MAKE_UNSET="${DEFAULT_PHP_MAKE_UNSET}"
#PHP56_EXT_MAKE_SET="${DEFAULT_PHP_EXT_MAKE_SET}"
#PHP56_EXT_MAKE_UNSET="${DEFAULT_PHP_EXT_MAKE_UNSET}"

#PHP70_MAKE_SET="${DEFAULT_PHP_MAKE_SET}"
#PHP70_MAKE_UNSET="${DEFAULT_PHP_MAKE_UNSET}"
#PHP70_EXT_MAKE_SET="${DEFAULT_PHP_EXT_MAKE_SET}"
#PHP70_EXT_MAKE_UNSET="${DEFAULT_PHP_EXT_MAKE_UNSET}"

#PHP71_MAKE_SET="${DEFAULT_PHP_MAKE_SET}"
#PHP71_MAKE_UNSET="${DEFAULT_PHP_MAKE_UNSET}"
#PHP71_EXT_MAKE_SET="${DEFAULT_PHP_EXT_MAKE_SET}"
#PHP71_EXT_MAKE_UNSET="${DEFAULT_PHP_EXT_MAKE_UNSET}"

PHP74_MAKE_SET="${DEFAULT_PHP_MAKE_SET}"
PHP74_MAKE_UNSET="${DEFAULT_PHP_MAKE_UNSET}"
PHP74_EXT_MAKE_SET="${DEFAULT_PHP_EXT_MAKE_SET}"
PHP74_EXT_MAKE_UNSET="${DEFAULT_PHP_EXT_MAKE_UNSET}"

PHP56_MOD_MAKE_SET="" # MAILHEAD
PHP56_MOD_MAKE_UNSET=""
PHP70_MOD_MAKE_SET=""
PHP70_MOD_MAKE_UNSET=""
PHP71_MOD_MAKE_SET=""
PHP71_MOD_MAKE_UNSET=""

ROUNDCUBE_MAKE_SET="" # SSL
ROUNDCUBE_MAKE_UNSET=""

PMA_MAKE_SET=""
PMA_MAKE_UNSET=""

EXIM_MAKE_SET="SPF SA_EXIM SRS" # DMARC DCC MILTER
EXIM_MAKE_UNSET=""

SPAMASSASSIN_MAKE_SET="DKIM SPF_QUERY" # DCC PYZOR RAZOR RELAY_COUNTRY
SPAMASSASSIN_MAKE_UNSET=""

SPAMASSASSIN_UTILITIES_MAKE_SET="SACOMPILE"
SPAMASSASSIN_UTILITIES_MAKE_UNSET=""

DOVECOT2_MAKE_SET="" #
DOVECOT2_MAKE_UNSET=""

PIGEONHOLE_MAKE_SET="" # MANAGESIEVE
PIGEONHOLE_MAKE_UNSET=""

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
# MARIADB101_MAKE_SET="TOKUDB"
# MARIADB101_MAKE_UNSET=""
# MYSQL55_MAKE_SET=""
# MYSQL55_MAKE_UNSET=""
# MYSQL56_MAKE_SET=""
# MYSQL56_MAKE_UNSET=""
# MYSQL57_MAKE_SET=""
# MYSQL57_MAKE_UNSET=""


################################################################################
### Custom Configurations
################################################################################

## SSL Certificate Generation Parameters
SSL_REQ_CONF="${PB_CONFIG}/ssl/openssl_req.conf"
if [ -e "${PB_CUSTOM}/ssl/openssl_req.conf" ]; then
  SSL_REQ_CONF="${PB_CUSTOM}/ssl/openssl_req.conf"
fi

## Mod Security for Apache
MODSECURITY_APACHE_INCLUDE="${PB_CONFIG}/ap2/conf/extra/httpd-modsecurity.conf"
if [ -e "${PB_CUSTOM}/ap2/conf/extra/httpd-modsecurity.conf" ]; then
  MODSECURITY_APACHE_INCLUDE="${PB_CUSTOM}/ap2/conf/extra/httpd-modsecurity.conf"
fi

## Mod Security for Nginx
MODSECURITY_NGINX_INCLUDE="${PB_CONFIG}/nginx/conf/nginx-modsecurity.conf"
if [ -e "${PB_CUSTOM}/nginx/conf/nginx-modsecurity.conf" ]; then
  MODSECURITY_NGINX_INCLUDE="${PB_CUSTOM}/nginx/conf/nginx-modsecurity.conf"
fi

## Mod Security for Apache+Nginx Reverse Proxy
MODSECURITY_NGINX_REVERSE_INCLUDE="${PB_CONFIG}/nginx_reverse/conf/nginx-modsecurity.conf"
if [ -e "${PB_CUSTOM}/nginx_reverse/conf/nginx-modsecurity.conf" ]; then
  MODSECURITY_NGINX_REVERSE_INCLUDE="${PB_CUSTOM}/nginx_reverse/conf/nginx-modsecurity.conf"
fi

MODSECURITY_CUSTOM_RULES="${PB_CUSTOM}/modsecurity/conf"

################################################################################

## Verify: From CB2:
if [ "${OPT_WEBSERVER}" = "apache" ] || [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
  ## CB2: Do we have httpd-phpmodules.conf line?
  NEWCONFIGS=1
  if [ -e "${APACHE_CONF}" ]; then
    if [ "$(grep -m1 -c -e "${APACHE_EXTRAS}/httpd-phpmodules.conf" "${APACHE_CONF}")" = "0" ]; then
      NEWCONFIGS=0
    fi
  fi
fi

readonly NEWCONFIGS

################################################################################

## Get DirectAdmin Option Values (from CB2)
## Retrieves values from directadmin/conf/options.conf
getDA_Opt() {

  local OPTION_NAME="$1"
  local OPTION_DEFAULT="$2"

  ## Make sure directadmin.conf exists and contains values.
  if [ ! -s "${DA_CONF}" ]; then
    printf "%s\n" "${OPTION_DEFAULT}"
    return
  fi

  ## Check for value in ./directadmin c
  if ! "${DA_BIN}" c | grep -m1 -q -e "^${OPTION_NAME}="; then
    printf "%s\n" "${OPTION_DEFAULT}"
    return
  fi

  ## Retrieve DirectAdmin's default value:
  ${DA_BIN} c | grep -m1 "^${OPTION_NAME}=" | cut -d= -f2
}

################################################################################
## Emulate ${!variable} (from CB2)
################################################################################

eval_var() {

  local var="$1"

  if [ -z "${var}" ]; then
    printf "\n"
  else
    eval newval="\$${var}"
    echo "${newval}"
  fi
}

################################################################################
## Get Option (from CB2)
## Used to retrieve CB options.conf
################################################################################

getOpt() {

  local OPTION_NAME="$1"
  local OPTION_DEFAULT="$2"
  local GET_OPTION

  ## CB2: Added "grep -v" to workaround many lines with empty options
  GET_OPTION="$(grep -v "^${OPTION_NAME}=$" "${CB_CONF}" | grep -m1 "^${OPTION_NAME}=" | cut -d= -f2)"
  if [ -z "${GET_OPTION}" ]; then
    echo "${OPTION_NAME}=${OPTION_DEFAULT}" >> "${CB_CONF}"
  fi

  echo "${GET_OPTION}"
}

################################################################################
## Set Option (from CB2)
## Used to manipulate CB options.conf
################################################################################

setOpt() {

  local OPTION_NAME="$1"
  local OPTION_VALUE="$2"
  local OPTION_DEFAULT="$3"
  local OPT_VALUE

  OPT_VALUE="$(grep -m1 "^${OPTION_NAME}=" "${CB_CONF}" | cut -d= -f2)"
  ${PERL} -pi -e "s#${OPTION_NAME}=${OPT_VALUE}#${OPTION_NAME}=${OPTION_VALUE}#" "${CB_CONF}"
}

################################################################################
## Set Value ($1) to ($2) in file ($3) (from CB2)
################################################################################

setVal() {

  local OPTION_NAME="$1"
  local OPTION_VALUE="$2"
  local OPTION_FILE="$3"
  local FILE_DESC

  if [ "${OPTION_FILE}" = "${DA_CONF}" ] && [ ! -e "${DA_CONF}" ]; then
    return
  fi

  if [ "${OPTION_FILE}" = "${DA_CONF}" ]; then
    FILE_DESC='directadmin.conf'
  elif [ "${OPTION_FILE}" = "${DA_CONF_TEMPLATE}" ]; then
    FILE_DESC='directadmin.conf (template)'
  else
    FILE_DESC="${OPTIONS_FILE}"
  fi

  printf "Setting %s to %s in %s\n" "${OPTION_NAME}" "${OPTION_VALUE}" "${FILE_DESC}"

  ## Check if file exists.
  if [ ! -e "${OPTION_FILE}" ]; then
    printf "setVal(): File not found: %s\n" "${OPTION_FILE}"
    return
  fi

  ## Can't put [brackets] around the statement else grep flips out.
  if ! grep -m1 -q "${OPTION_NAME}=" "${OPTION_FILE}"; then
    ## It's not there, so add it.
    echo "${OPTION_NAME}=${OPTION_VALUE}" >> "${OPTION_FILE}"
    return
  else
    FIND_OPTION="$(grep "${1}=" "${OPTION_FILE}")"
    NEW_OPT_VALUE="${OPTION_NAME}=${OPTION_VALUE}"
    ## The value is already in the file $3, so use Perl regex to replace it.
    ${PERL} -pi -e "s|${FIND_OPTION}|${NEW_OPT_VALUE}|" "${OPTION_FILE}"
    # ${PERL} -pi -e "s/`grep ${1}= ${3}`/${1}=${2}/" ${3}
  fi
}

################################################################################
## Get Value ($1) from file ($2)
## Returns 0 if option is undefined (doesn't exist or is blank).
################################################################################

getVal() {

  local OPTION_NAME="$1"
  local OPTION_FILE="$2"
  local GET_VALUE

  ## Check if file exists:
  if [ ! -e "${OPTION_FILE}" ]; then
    return
  fi

  GET_VALUE="$(grep -v "^${OPTION_NAME}=$" "${OPTION_FILE}" | grep -m1 "^${OPTION_NAME}=" | cut -d= -f2 | tr -d '"')"
  if [ -z "${GET_VALUE}" ]; then
    echo "0"
    # GET_VALUE=0
  else
    echo "${GET_VALUE}"
  fi

  return
}

################################################################################
## Used to set values ON/OFF in the services.status (from CB2)
## Usage: set_service name ON|OFF|delete
################################################################################

set_service() {

  local SERVICE_NAME="$1"
  local SERVICE_STATUS="$2"
  local SERVICE_COUNT

  if [ ! -e "${DA_SERVICES}" ]; then
    return
  fi

  SERVICE_COUNT="$(grep -m1 -c "^$SERVICE_NAME=" ${DA_SERVICES})"

  if [ "${SERVICE_STATUS}" = "delete" ]; then
    if [ "${SERVICE_COUNT}" -eq 0 ]; then
      return
    else
      ${PERL} -pi -e "s/^${SERVICE_NAME}=.*\n//" "${DA_SERVICES}"
    fi
    return
  fi

  if [ "${SERVICE_STATUS}" = "ON" ] || [ "${SERVICE_STATUS}" = "OFF" ]; then
    if [ "${SERVICE_COUNT}" -eq 0 ]; then
      echo "${SERVICE_NAME}=${SERVICE_STATUS}" >> "${DA_SERVICES}"
    else
      ${PERL} -pi -e "s/^${SERVICE_NAME}=.*/${SERVICE_NAME}=${SERVICE_STATUS}/" "${DA_SERVICES}"
    fi
    return
  fi

  printf "set_service(): %s: unknown option: %s\n" "${SERVICE_NAME}" "${SERVICE_STATUS}"

  return
}

################################################################################
## Get File from PB Mirror
## $1 = source and $2 = target
## Usage: getFile configure/proftpd/proftpd.conf ${PROFTPD_CONF}
################################################################################

getFile() {

  local SOURCE_FILE="$1" ## $1 = source (input, from PB mirror)
  local TARGET_FILE="$2" ## $2 = target (output)
  local IFS=' '

  printf "*** Notice: Downloading %s to %s\n" "${SOURCE_FILE}" "${TARGET_FILE}"

  ${WGET} ${WGET_CONNECT_OPTIONS} -O ${TARGET_FILE} "${PB_MIRROR}/${SOURCE_FILE}"

  return
}

################################################################################
## Convert string to lowercase
################################################################################

lc() {
  local char="$*"
  local out
  out="$(echo "$char" | tr "[:upper:]" "[:lower:]")"
  local retval=$?
  echo "$out"
  unset out
  unset char
  return $retval
}

################################################################################
## Convert string to uppercase
################################################################################

uc() {
  local char="$*"
  local out
  out="$(echo "$char" | tr "[:lower:]" "[:upper:]")"
  local retval=$?
  echo "$out"
  unset out char
  return $retval
}

################################################################################
## Ask User a Question
## Usage: ask_user "Question"
################################################################################

ask_user() {

  ## not done: $2 = expected answer: "yn", "custom", etc. (optional)
  ## not done: $3 = execute command (optional)

  local ASK_QUESTION="${1:="Do you want to continue?"}"
  local RESPONSE=""

  while true; do
    read -p "${ASK_QUESTION} (y/n): " -r RESPONSE
    case $RESPONSE in
      [Yy]* ) return 1; break ;;
      [Nn]* ) return 0; break ;;
      * ) printf "Please answer with Yes or No.\n" ;;
    esac
  done
}

################################################################################
## Update /usr/ports via portsnap
################################################################################

ports_update() {

  if [ ! -d "${PORTS_BASE}" ]; then
    printf "Setting up %s for the first time.\n" ${PORTS_BASE}
    ${PORTSNAP} fetch extract
  fi

  printf "Updating /usr/ports\n"
  ${PORTSNAP} fetch update

  return
}

################################################################################
## pkg shortcuts
################################################################################

pkgi() { ${PKG} -d install -f -y "$@"; }
pkgu() { ${PKG} upgrade -f -y "$@"; }
pkgd() { ${PKG} delete -f "$@"; }
pkgq() { ${PKG} query "$@"; }

pkg_clean() { ${PKG} clean -y; }
pkg_update() { ${PKG} update; }
pkg_update_force() { ${PKG} update -f; }

################################################################################
## Setup latest pkg repo
################################################################################

pkg_repo_setup() {

  local PKG_REPO_DIR=/usr/local/etc/pkg/repos

  if [ "${OPT_LATEST_PKG_REPO}" = "YES" ]; then
    if [ ! -e "${PKG_REPO_DIR}/FreeBSD.conf" ]; then
      ${MKDIR} -p "${PKG_REPO_DIR}"
      ${TOUCH} "${PKG_REPO_DIR}/FreeBSD.conf"
      printf "FreeBSD: {\n  url: \"pkg+http://pkg.FreeBSD.org/\${ABI}/latest\"\n}" > "${PKG_REPO_DIR}/FreeBSD.conf"
    fi
  fi

  return
}

################################################################################
## synth shortcuts
################################################################################

synth_prepare() { ${SYNTH} prepare-system; }
synth_upgrade() { ${SYNTH} upgrade-system; }
synth_status() { ${SYNTH} status; }

################################################################################
## portmaster shortcuts
################################################################################

## Clean stale ports (deprecate soon)
clean_stale_ports() { printf "Cleaning stale ports\n"; ${PORTMASTER} -s; }

## Reinstall all ports "in place" (deprecate soon)
## Consider -R flag
## Todo: migrate this process to synth
reinstall_all_ports() { ${PORTMASTER} -a -f -d; }

################################################################################
## apache shortcuts
################################################################################

apxs_enable() { ${APXS} -e -a -n "$1" "$2"; }
apxs_disable() { ${APXS} -e -A -n "$1" "$2"; }

################################################################################
## Todo: Rinse & Repeat
## (Need to work with eval)
################################################################################

make_install_clean() {

  # local CATEGORY=$1
  # local PORT=$2

  ## Origin: category/portname
  local CHOSEN_PORT="$1"

  # if [ options_set blank] && [ options_unset blank ]; then
  # # install via pkg
  # pkg install -y ${CHOSEN_PORT}
  # elif
  # # install via ports:

  ## /usr/bin/make
  ${MAKE} -DNO_DIALOG -C "${PORTS_BASE}/${CHOSEN_PORT}" rmconfig
  ${MAKE} -DNO_DIALOG -C "${PORTS_BASE}/${CHOSEN_PORT}" \
  OPTIONS_SET="${_MAKE_SET}" \
  OPTIONS_UNSET="${_MAKE_UNSET}" \
  reinstall clean
  # fi

  return
}

################################################################################
## Update /etc/hosts
################################################################################

update_hosts() {

  local HOSTS_COUNT

  HOSTS_COUNT="$(grep 127.0.0.1 /etc/hosts | grep -c localhost)"
  if [ "${HOSTS_COUNT}" -eq 0 ]; then
    printf "Updating /etc/hosts\n"
    printf "127.0.0.1\t\tlocalhost" >> /etc/hosts
  fi

  return
}

################################################################################
## Get System Timezone (from CB2)
################################################################################

getTimezone() {

  local DATETIMEZONE MD5_LOCALTIME

  if [ -d /usr/share/zoneinfo ] && [ -e /etc/localtime ]; then
    MD5_LOCALTIME="$(md5 /etc/localtime | awk '{print $4}')"
    ## CB2: We don't use 'grep -m1' here to fix: "xargs: md5: terminated with signal 13; aborting"
    DATETIMEZONE="$(find /usr/share/zoneinfo -type f -print0 | xargs -0 md5 \
      | grep "${MD5_LOCALTIME}" | awk '{print $2}' | cut -d\( -f2 | cut -d\) -f1 \
      | ${PERL} -p0 -e 's#/usr/share/zoneinfo/##')"
  fi

  DATETIMEZONE=${DATETIMEZONE:="America/Toronto"}

  printf "%s\n" "${DATETIMEZONE}"

  return
}

################################################################################
## Add (new) User to (new) Group (from CB2)
################################################################################

addUserGroup() {

  local USER="$1"
  local GROUP="$2"

  if ! /usr/bin/grep -q "^${GROUP}:" < /etc/group; then
    ${PW} groupadd "${GROUP}"
  fi

  if ! /usr/bin/id "${USER}" > /dev/null; then
    ${PW} useradd -g "${GROUP}" -n "${USER}" -s /sbin/nologin
  fi

  return
}

################################################################################
## Random Password Generator (from CB2)
################################################################################

random_pass() {

  local min="$1"

  MIN_PASS_LENGTH="${min:=12}"

  ${PERL} -le "print map+(A..Z,a..z,0..9)[rand 62],0..${MIN_PASS_LENGTH}"

  return
}

################################################################################
## Setup PortsBuild and DirectAdmin
## Possible arguments: <USER_ID> <LICENSE_ID> <SERVER_FQDN> <ETH_DEV> (<IP_ADDRESS>)"
################################################################################

global_setup() {

  ## $1 = "setup"
  local DA_USER_ID="$2"
  local DA_LICENSE_ID="$3"
  local SERVER_FQDN="$4"
  local ETHERNET_DEV="$5"
  local DA_SERVER_IP="$6"
  local DA_SERVER_IP_MASK="$7"
  local LAN_IP="$8"
  local DA_INSECURE="$9"
  local VERIFY_HOSTS ADMIN_GROUP_COUNT

  ## Make sure all inputs are entered
  if [ -z "$1" ] ||
    [ -z "${DA_USER_ID}"   ] || [ -z "${DA_LICENSE_ID}"     ] ||
    [ -z "${SERVER_FQDN}"  ] || [ -z "${ETHERNET_DEV}"      ] ||
    [ -z "${DA_SERVER_IP}" ] || [ -z "${DA_SERVER_IP_MASK}" ]; then
    show_menu_setup
    return
  fi

  printf "\n"
  printf "  Global System Setup Initiated\n\n"
  printf "  About to setup PortsBuild and install DirectAdmin for the first time.\n\n"
  printf "  Setup arguments received:\n"
  {
    printf "\tUser ID: %s\n" "${DA_USER_ID}"
    printf "\tLicense ID: %s\n" "${DA_LICENSE_ID}"
    printf "\tServer FQDN: %s\n" "${SERVER_FQDN}"
    printf "\tEthernet Device: %s\n" "${ETHERNET_DEV}"
    printf "\tServer IP Address: %s\n" "${DA_SERVER_IP}"
    printf "\tServer IP Netmask: %s\n" "${DA_SERVER_IP_MASK}"

    if [ -n "${LAN_IP}" ]; then
      printf "\tLAN IP: %s\n" "${LAN_IP}"
      printf "\tLAN Mode: Enabled\n"
    fi

    if [ "${DA_INSECURE}" = 1 ]; then
      printf "\tInsecure Mode: Enabled\n"
    fi
  } | column -t -s:

  printf "\n"
  printf "  Please make sure these values are correct\n"
  printf "  and that they match the records in your DirectAdmin Client License Portal.\n"
  printf "  If in doubt, visit: https://www.directadmin.com/clients/\n\n"
  printf "  PortsBuild will install, setup and configure the following services:\n"
  printf "\tDirectAdmin"
  if [ "${OPT_NAMED}" = "YES" ]; then ( printf ", Named" ); fi
  if [ "${OPT_EXIM}" = "YES" ]; then ( printf ", Exim" ); fi
  if [ "${OPT_DOVECOT}" = "YES" ]; then ( printf ", Dovecot" ); fi
  if [ "${OPT_MAJORDOMO}" = "YES" ]; then ( printf ", Majordomo" ); fi
  if [ "${OPT_WEBSERVER}" = "apache" ]; then ( printf ", Apache" ); else ( printf ", Nginx"); fi
  if [ "${OPT_PHP_RELEASE}" != "NO" ]; then ( printf ", %s %s" "${OPT_PHP_MODE}" "${OPT_PHP_VERSION}" ); fi
  if [ "${OPT_SQL_DB}" != "NO" ]; then ( printf ", %s" "${OPT_SQL_DB}" ); fi
  if [ "${OPT_PHPMYADMIN}" = "YES" ]; then ( printf ", phpMyAdmin" ); fi
  if [ "${OPT_ROUNDCUBE}" = "YES" ]; then ( printf ", RoundCube" ); fi
  if [ "${OPT_SPAMASSASSIN}" = "YES" ]; then ( printf ", SpamAssassin" ); fi
  if [ "${OPT_CLAMAV}" = "YES" ]; then ( printf ", ClamAV" ); fi
  if [ "${OPT_FTPD}" != "NO" ]; then ( printf ", %s" "${OPT_FTPD}" ); fi
  printf "\n\n"

  printf "  The following features will be enabled: \n\t"
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
  if [ "${OPT_HTSCANNER}" = "YES" ]; then ( printf ", HTScanner" ); fi
  if [ "${OPT_LETSENCRYPT}" = "YES" ]; then ( printf ", Let's Encrypt" ); fi
  printf "\n\n"

  # echo "PHP ini Type: ${OPT_PHP_INI_TYPE}"
  # echo "Webapps Inbox Prefix: ${OPT_WEBAPPS_INBOX_PREFIX}"
  # echo "Spam Inbox Prefix: ${OPT_SPAM_INBOX_PREFIX}"
  # echo "Install CCache: ${OPT_INSTALL_CCACHE}"
  # echo "Install Synth: ${OPT_INSTALL_SYNTH}"

  ask_user "Do you want to continue?"

  ## Let's go! ##

  if [ "$?" -eq 1 ]; then
    printf "Bootstrapping and updating pkg\n"
    /usr/bin/env ASSUME_ALWAYS_YES=YES pkg bootstrap

    pkg_repo_setup

    pkg_update

    ports_update

    pkgi "${LINUX_COMPAT_C7}"

    ## Install Dependencies
    printf "Installing initial required dependencies and compatibility libraries (misc/compats)\n"
    case "${OS_MAJ}" in
      12) pkgi "${PORT_DEPS_110}" ;;
      13) pkgi "${PORT_DEPS_120}" ;;
      14) pkgi "${PORT_DEPS_130}" ;;
    esac

    ## Check for /etc/rc.conf
    if [ ! -e /etc/rc.conf ]; then
      printf "Creating /etc/rc.conf\n"
      ${TOUCH} /etc/rc.conf
    fi

    ## Check for /etc/make.conf
    if [ ! -e /etc/make.conf ]; then
      printf "Creating /etc/make.conf\n"
      ${TOUCH} /etc/make.conf
    fi

    if [ "${OPT_INSTALL_CCACHE}" = "YES" ]; then
      printf "Installing: %s\n" "${PORT_CCACHE}"
      pkgi "${PORT_CCACHE}"

      if [ "$?" = 0 ]; then
        ${SYSRC} -f /etc/make.conf WITH_CCACHE_BUILD=yes ## Still needed?
        ${SYSRC} -f /etc/make.conf CCACHE_DIR="/var/db/ccache"
      fi
    fi

    printf "Installing: %s\n" "${PORT_PORTMASTER}"
    pkgi "${PORT_PORTMASTER}"

    if [ "${OPT_INSTALL_SYNTH}" = "YES" ] && [ ! -e "${SYNTH}" ]; then
      printf "Installing: %s\n" "${PORT_SYNTH}"
      pkgi "${PORT_SYNTH}"

      ## Todo: Configure synth (copy a default/stock Live system profile?)
      # synth configure
    fi

    ## Symlink Perl for DA compat
    printf "Checking for the /usr/bin/perl => /usr/local/bin/perl symlink\n"

    if [ ! -e /usr/bin/perl ]; then
      if [ -e "${PERL}" ]; then
        ln -s "${PERL}" /usr/bin/perl
      else
        pkgi "${PORT_PERL}"
        if [ $? -eq 0 ]; then
          ln -s "${PERL}" /usr/bin/perl
        fi
      fi
    fi

    ## IPV6 settings suggested by DA
    printf "Setting ipv6_ipv4mapping=YES in /etc/rc.conf\n"
    ${SYSRC} ipv6_ipv4mapping="YES"
    ${SYSRC} -f /etc/sysctl.conf net.inet6.ip6.v6only=0
    ${SYSCTL} net.inet6.ip6.v6only=0

    ## update_hosts

    ## Verify if /etc/hosts has the localhost entry
    VERIFY_HOSTS=$(grep 127.0.0.1 /etc/hosts | grep -c localhost)
    if [ "${VERIFY_HOSTS}" -eq 0 ]; then
      printf "127.0.0.1\t\tlocalhost\n" >> /etc/hosts
    fi

    ## Disable sendmail if Exim is enabled
    if [ "${OPT_EXIM}" = "YES" ] || [ "${OPT_DISABLE_SENDMAIL}" = "YES" ]; then
      printf "Disabling sendmail from running (updating /etc/rc.conf)\n"
      ${SERVICE} sendmail stop
      ${SYSRC} sendmail_enable="NONE"
      ${SYSRC} sendmail_submit_enable="NO"
      ${SYSRC} sendmail_outbound_enable="NO"
      ${SYSRC} sendmail_msp_queue_enable="NO"
    fi

    ## Ethernet Device checking goes here.
    ## Skipping/avoiding this step as it's not that reliable of a process,
    ## especially if you have multiple interfaces configured in /etc/rc.conf.

    ## Make sure sshd is enabled
    printf "Enabling sshd in /etc/rc.conf\n"
    ${SYSRC} sshd_enable="YES"

    printf "Starting sshd (if not already done so)\n"
    ${SERVICE} sshd start

    ## Go for the main attraction (need setup.txt)
    printf "Installing DirectAdmin\n"
    directadmin_install

    ## Install and configure services & applications
    if [ "${OPT_NAMED}" = "YES" ]; then ( bind_setup ); fi
    if [ "${OPT_EXIM}" = "YES" ]; then ( exim_install); fi
    if [ "${OPT_MAJORDOMO}" = "YES" ]; then ( majordomo_install); fi
    if [ "${OPT_DOVECOT}" = "YES" ]; then ( dovecot_install ); fi
    if [ "${OPT_WEBSERVER}" = "apache" ]; then ( apache_install ); fi
    if [ "${OPT_PHP_MODE}" != "NO" ]; then ( php_install ); fi
    if [ "${OPT_SQL_DB}" != "NO" ]; then ( sql_install ); fi
    if [ "${OPT_PHPMYADMIN}" = "YES" ]; then ( phpmyadmin_install ); fi
    if [ "${OPT_ROUNDCUBE}" = "YES" ]; then ( roundcube_install ); fi
    if [ "${OPT_SPAMASSASSIN}" = "YES" ]; then ( spamassassin_install ); fi
    if [ "${OPT_CLAMAV}" = "YES" ]; then ( clamav_install ); fi
    if [ "${OPT_FTPD}" != "NO" ]; then ( install_app "${OPT_FTPD}" ); fi
    if [ "${OPT_BLOCKCRACKING}" = "YES" ]; then ( blockcracking_install ); fi
    if [ "${OPT_EASY_SPAM_FIGHTER}" = "YES" ]; then ( easyspamfighter_install ); fi
    if [ "${OPT_MODSECURITY}" = "YES" ]; then ( modsecurity_install ); fi
    if [ "${OPT_HTSCANNER}" = "YES" ]; then ( install_mod_htscanner ); fi
    if [ "${OPT_LETSENCRYPT}" = "YES" ]; then ( letsencrypt_install ); fi

    ## Create a spoof CustomBuild2 options.conf for DirectAdmin compatibility
    if [ ! -d "${CB_PATH}" ]; then
      ${MKDIR} -p "${CB_PATH}"
    fi

    if [ ! -e "${CB_CONF}" ]; then
      if [ ! -e "${PB_CUSTOM}/build/options.conf" ]; then
        ${WGET} -O "${CB_CONF}" "${PB_MIRROR}/custombuild/options.conf"
      else
        printf "Copying custombuild/options.conf.sample file.\n"
        cp "${PB_CUSTOM}/build/options.conf" "${CB_CONF}"
      fi
    fi

    ## Create newsyslog entries
    newsyslog_setup

    ## Replace templates/proftpd.conf with corrected version
    ## 2016-05-10: DA seems to create/override /etc/proftpd.conf regardless of what's set in the configuration file.
    cp -f "${PB_PATH}/directadmin/data/templates/custom/proftpd.conf" "${DA_PATH}/data/templates/proftpd.conf"
    cp -f "${PB_PATH}/directadmin/data/templates/custom/proftpd.conf" "${DA_PATH}/data/templates/custom/proftpd.conf"

    ${CHOWN} -f diradmin:diradmin "${CB_CONF}"
    ${CHMOD} 755 "${CB_CONF}"

    ## Copy DA startup file to /usr/local/etc/rc.d/
    cp -f "${PB_PATH}/etc/rc.d/directadmin" "${RCD}/directadmin"
    ${CHMOD} 755 "${RCD}/directadmin"

    ## Update /etc/rc.conf:
    ${SYSRC} directadmin_enable="YES"

    ## DirectAdmin Install
    ## This is where directadmin.conf gets created for the first time (copy of the template)
    printf "Running ./directadmin i\n"
    ${DA_BIN} i

    ## Set DirectAdmin Permissions
    printf "Running ./directadmin p\n"
    ${DA_BIN} p

    ## PB: On first time startup, DirectAdmin creates /etc/proftpd.conf
    ##     and backs up the original to /etc/proftpd.conf.back
    ## "Install of /usr/local/directadmin/data/templates/proftpd.conf to /etc/proftpd.conf successfull"
    if [ -e /etc/proftpd.conf ]; then
      rm /etc/proftpd.conf
      rm /etc/proftpd.conf.back
      ln -s ${PROFTPD_CONF} /etc/proftpd.conf
    fi

    ## From DA's scripts/install.sh
    ADMIN_GROUP_COUNT=$(grep -c -e '^admin:' /etc/group)
    if [ "${ADMIN_GROUP_COUNT}" -eq 0 ]; then
      ADMIN_PASS_COUNT=$(grep -c -e '^admin:' /etc/passwd)
      if [ "${ADMIN_PASS_COUNT}" -eq 1 ]; then
        ## DA: We have a user, but no admin group.
        ${PW} groupadd ${DA_ADMIN_USER}
      fi
    fi

    if [ -z ${LAN_IP} ]; then
      setVal lan_ip "${LAN_IP}" "${DA_CONF}"
      setVal lan_ip "${LAN_IP}" "${DA_CONF_TEMPLATE}"
    fi

    printf "Starting DirectAdmin\n"
    ${SERVICE} directadmin start


    install_cron

    deny_cron

    bfm_setup

    ## Todo:
    # ipfw_enable

    basic_system_security

    printf "PortsBuild installation completed.\n\n"

    exit 0

  else
    printf "PortsBuild installation canceled.\n\n"
    # show_main_menu
  fi

  return
}

################################################################################
## Update System Startup Scripts
## Modifies /etc/rc.conf, /boot/loader.conf, /etc/periodic.conf, etc.
################################################################################

update_rcd() {

  ## Todo: refactor with eval "${SERVICE_NAME}_enable"
  ## Todo: implement case()

  if [ -e "${RCD}/directadmin" ]; then
    ${SYSRC} directadmin_enable="YES"
  else
    ${SYSRC} -q -x directadmin_enable
  fi

  if [ "${OPT_NAMED}" = "YES" ]; then
    ${SYSRC} named_enable="YES"
  else
    ${SYSRC} -q -x named_enable
  fi

  if [ "${OPT_WEBSERVER}" = "apache" ]; then
    ${SYSRC} apache24_enable="YES"
    ${SYSRC} apache24_http_accept_enable="YES"
    ${SYSRC} -f /boot/loader.conf accf_http_load="YES"
    ${SYSRC} -f /boot/loader.conf accf_data_load="YES"
    ${SYSRC} -q -x nginx_enable
  else
    ${SYSRC} -q -x apache24_enable
    ${SYSRC} -q -x apache24_http_accept_enable
    ${SYSRC} -q -f /boot/loader.conf -x accf_http_load
    ${SYSRC} -q -f /boot/loader.conf -x accf_data_load
  fi

  if [ "${OPT_WEBSERVER}" = "nginx" ]; then
    ${SYSRC} nginx_enable="YES"
    ${SYSRC} -q -x apache24_enable
    ${SYSRC} -q -x apache24_http_accept_enable
    ${SYSRC} -q -f /boot/loader.conf -x accf_http_load ## Verify:
    ${SYSRC} -q -f /boot/loader.conf -x accf_data_load ## Verify:
  else
    ${SYSRC} -q -x nginx_enable
  fi

  if [ "${OPT_SQL_DB}" != "NO" ]; then
    ${SYSRC} mysql_enable="YES"
    ${SYSRC} mysql_dbdir="${SQL_DATA_PATH}"
    ${SYSRC} mysql_optfile="/usr/local/etc/my.cnf"
  fi

  if [ "${OPT_PHP_MODE}" = "php-fpm" ] && [ "${OPT_PHP_RELEASE}" != "NO" ]; then
    ${SYSRC} php_fpm_enable="YES"
  else
    ${SYSRC} -q -x php_fpm_enable
  fi

  if [ "${OPT_EXIM}" = "YES" ]; then
    ${SYSRC} exim_enable="YES"
    ${SYSRC} exim_flags="-bd -q1h"
    ${SYSRC} -f /etc/periodic.conf daily_status_include_submit_mailq="NO"
    ${SYSRC} -f /etc/periodic.conf daily_clean_hoststat_enable="NO"
  else
    ${SYSRC} -q -x exim_enable
    ${SYSRC} -q -x exim_flags
    ${SYSRC} -q -f /etc/periodic.conf -x daily_status_include_submit_mailq
    ${SYSRC} -q -f /etc/periodic.conf -x daily_clean_hoststat_enable
  fi

  if [ "${OPT_DOVECOT}" = "YES" ]; then
    ${SYSRC} dovecot_enable="YES"
  else
    ${SYSRC} -q -x dovecot_enable
  fi

  if [ "${OPT_FTPD}" = "pureftpd" ]; then
    ${SYSRC} ftpd_enable="NO"
    ${SYSRC} pureftpd_enable="YES"
    # ${SYSRC} pureftpd_flags=""
    ${SYSRC} pureftpd_config=""
    ${SYSRC} -q -x proftpd_enable
  else
    ${SYSRC} -q -x pureftpd_enable
  fi

  if [ "${OPT_FTPD}" = "proftpd" ]; then
    ${SYSRC} ftpd_enable="NO"
    ${SYSRC} proftpd_enable="YES"
    ${SYSRC} -q -x pureftpd_enable
    ${SYSRC} -q -x pureftpd_config
    ${SYSRC} -q -x pureftpd_flags
    ${SYSRC} -q -x pureftpd_uploadscript
  else
    ${SYSRC} -q -x proftpd_enable
  fi

  if [ "${OPT_SPAMASSASSIN}" = "YES" ]; then
    ${SYSRC} spamd_enable="YES"
    ${SYSRC} spamd_flags="-c -m 15"
  else
    ${SYSRC} -q -x spamd_enable
    ${SYSRC} -q -x spamd_flags
  fi

  if [ "${OPT_SPAMASSASSIN_UTILITIES}" = "YES" ] && [ "${OPT_SPAMASSASSIN}" = "YES" ]; then
    ${SYSRC} -f /etc/periodic.conf daily_sa_enable="YES"
    ${SYSRC} -f /etc/periodic.conf daily_sa_quiet="NO"
    ${SYSRC} -f /etc/periodic.conf daily_sa_compile_nice="YES"
    ${SYSRC} -f /etc/periodic.conf daily_sa_restart_spamd="YES"
    # daily_sa_update_flags="" ## -D --nogpg
    # daily_sa_compile_flags=""
    # daily_sa_compile_nice_flags=""
  else
    ${SYSRC} -q -f /etc/periodic.conf -x daily_sa_enable
    ${SYSRC} -q -f /etc/periodic.conf -x daily_sa_quiet
    ${SYSRC} -q -f /etc/periodic.conf -x daily_sa_compile_nice
    ${SYSRC} -q -f /etc/periodic.conf -x daily_sa_restart_spamd
  fi

  if [ "${OPT_CLAMAV}" = "YES" ]; then
    ${SYSRC} clamav_clamd_enable="YES"
    ${SYSRC} clamav_freshclam_enable="YES"
  else
    ${SYSRC} -q -x clamav_clamd_enable
    ${SYSRC} -q -x clamav_freshclam_enable
  fi

  ## PB: Misc.
  # rc_debug="NO"          # Set to YES to enable debugging output from rc.d
  # rc_info="NO"            # Enables display of informational messages at boot.
  # rc_startmsgs="YES"      # Show "Starting foo:" messages at boot
  # fsck_y_enable="NO"      # Set to YES to do fsck -y if the initial preen fails.
  # background_fsck="YES"   # Attempt to run fsck in the background where possible.
  # background_fsck_delay="60" # Time to wait (seconds) before starting the fsck.

  return
}

################################################################################
## PB: Verify: Control Service
################################################################################

control_service() {

  local SERVICE_NAME="$1"
  local SERVICE_ACTION="$2" ## start, restart, stop, reload

  if [ -z "${SERVICE_NAME}" ] || [ -z "${SERVICE_ACTION}" ]; then
    printf "*** Error: Missing arguments for control_service().\n"
    return
  fi

  if [ ! -e "${RCD}/${SERVICE_NAME}" ] || [ ! -e "/etc/rc.d/${SERVICE_NAME}" ]; then
    printf "*** Error: Service %s not found." "${SERVICE_NAME}"
    return
  fi

  SERVICE_STATUS=$(${SERVICE} "${SERVICE_NAME}" status)

  if [ "${SERVICE_NAME}" = "directadmin" ]; then
    if [ "${SERVICE_ACTION}" = "restart" ]; then
      echo "action=directadmin&value=reload" >> "${DA_TASK_QUEUE}"
      run_dataskq
    else
      ## Handover to rc.d/directadmin
      ${SERVICE} directadmin "${SERVICE_ACTION}"
    fi
    return
  fi

  ## Test certain service config files before restarting to prevent downtime
  case ${SERVICE_NAME} in
    "php-fpm"|"fpm"|"php"|"php_fpm") CONFIG_STATUS=$(${SERVICE} php-fpm configtest) ;;
    "apache"|"apache24"|"httpd") CONFIG_STATUS=$(${SERVICE} apache24 configtest) ;;
    "nginx") CONFIG_STATUS=$(${SERVICE} nginx configtest) ;;
    "exim") CONFIG_STATUS=$(${EXIM_BIN} -C "${EXIM_CONF}" -bV) ;;
    "dovecot") CONFIG_STATUS=$(${DOVECOT_BIN} -c ${DOVECOT_CONF}) ;;
    "sshd") CONFIG_STATUS=$(${SERVICE} sshd configtest) ;;
  esac

  ## Perform the necessary action
  case ${SERVICE_ACTION} in
    "start"|"restart")
      if [ "${CONFIG_STATUS}" = 0 ]; then
        if [ "${SERVICE_STATUS}" = 0 ]; then
          printf "Restarting %s\n" "${SERVICE_NAME}"
          ${SERVICE} "${SERVICE_NAME}" restart
        else
          printf "Starting %s\n" "${SERVICE_NAME}"
          ${SERVICE} "${SERVICE_NAME}" start
        fi
      else
        printf "*** Error: Cannot %s %s due to configuration file error.\n" "${SERVICE_ACTION}" "${SERVICE_NAME}"
      fi
    ;;
    "reload")
      if [ "${CONFIG_STATUS}" = 0 ]; then
        printf "Reloading %s\n" "${SERVICE_NAME}"
        ${SERVICE} "${SERVICE_NAME}" reload
      fi
    ;;
    "stop") ${SERVICE} "${SERVICE_NAME}" stop ;;
    "status") printf "%s\n" "${SERVICE_STATUS}" ;;
    *) printf "*** Error: Action %s not found\n" "${SERVICE_ACTION}" ;;
  esac

  return
}

################################################################################
## Setup BIND (named) for DNS services
################################################################################

bind_setup() {

  local NAMED_BIN NAMEDB_PATH RNDC_BIN NAMED_CONF RNDC_KEY NAMED_STATUS

  if [ "${OPT_NAMED}" != "YES" ]; then
    printf "*** Notice: Skipping named (BIND) DNS setup as it's disabled in options.conf\n"
    return
  fi

  printf "Setting up named (BIND)\n"

  case "${OS_MAJ}" in
    9) ## FreeBSD 9.3: /etc/namedb/
      NAMED_BIN=/usr/sbin/named
      NAMEDB_PATH=/etc/namedb
      RNDC_BIN=/sbin/rndc-confgen
      NAMED_CONF="${NAMEDB_PATH}/named.conf"
      RNDC_KEY="${NAMEDB_PATH}/rndc.key"
      ;;
    10|11) ## FreeBSD 10/11+: /usr/local/etc/namedb/
      NAMED_BIN=/usr/local/sbin/named
      NAMEDB_PATH=/usr/local/etc/namedb
      RNDC_BIN=/usr/local/sbin/rndc-confgen
      NAMED_CONF="${NAMEDB_PATH}/named.conf"
      RNDC_KEY="${NAMEDB_PATH}/rndc.key"

      if [ "${COMPAT_NAMED_SYMLINKS}" = "YES" ]; then
        ## PB: Needed as of 2016-05-10 or else DA complains:
        ln -s /usr/local/sbin/named-checkzone /usr/sbin/named-checkzone
      fi
      ;;
    *) ## Script problem
      err 1 "*** Error: Script error at bind_setup()"
      ;;
  esac

  if [ ! -e "${NAMED_BIN}" ]; then
    printf "*** Error: Cannot find the named binary at %s\n" "${NAMED_BIN}"
    exit 1
  fi

  if [ ! -d "${NAMEDB_PATH}" ]; then
    printf "Creating %s\n" "${NAMEDB_PATH}"
    ${MKDIR} -p "${NAMEDB_PATH}"
  fi

  if [ ! -e "${NAMED_CONF}" ]; then
    printf "*** Warning: Cannot find %s\n" ${NAMED_CONF}

    if [ -e "${PB_PATH}/configure/named/named.${OS_MAJ}.conf" ]; then
      cp "${PB_PATH}/configure/named/named.${OS_MAJ}.conf" "${NAMED_CONF}"
    else
      ${WGET} -O ${NAMED_CONF} "${PB_MIRROR}/configure/named/named.${OS_MAJ}.conf"
    fi
  fi

  if [ ! -e "${RNDC_KEY}" ]; then
    printf "*** Notice: Generating the rndc.key for the first time\n"
    ${RNDC_BIN} -a -s "${DA_SERVER_IP}"
  fi

  setVal namedconfig "${NAMED_CONF}" "${DA_CONF_TEMPLATE}"
  setVal nameddir "${NAMEDB_PATH}" "${DA_CONF_TEMPLATE}"

  if [ -e "${DA_CONF}" ]; then
    setVal namedconfig "${NAMED_CONF}" "${DA_CONF}"
    setVal nameddir "${NAMEDB_PATH}" "${DA_CONF}"
  fi

  printf "Updating /etc/rc.conf with named_enable=YES\n"
  ${SYSRC} named_enable="YES"

  ## PB: Todo: Replace with control_service()
  NAMED_STATUS=$(${SERVICE} named status)

  if [ "${NAMED_STATUS}" = 0 ]; then
    printf "Restarting named\n"
    ${SERVICE} named restart
  else
    printf "Starting named\n"
    ${SERVICE} named start
  fi

  return
}

################################################################################
## DirectAdmin Installation
## Replaces scripts/install.sh
################################################################################

directadmin_install() {

  local BIND_ADDRESS HTTP DA_EXTRA_VALUE HOME_FOUND PROCFS_NUM AUTH_COUNT
  local RC_ETH_DEV ETH_COUNT SSHROOT ALIASES_COUNT LICENSE_COUNT LICENSE_CHECK
  local DA_SQLDB_PASSWORD DA_ADMIN_PASSWORD

  BIND_ADDRESS="--bind-address=${DA_SERVER_IP}"

  if [ "${DA_INSECURE}" -eq 1 ]; then
    HTTP=http
    DA_EXTRA_VALUE='&insecure=yes'
  fi

  if [ "${DA_LAN}" -eq 1 ]; then
    BIND_ADDRESS=""
  fi

  ## Determin IP address using DA servers (from DA/scripts/getLicense.sh)
  da_myip() {
    local DISCOVERED_IP
    DISCOVERED_IP=$(${WGET} "${BIND_ADDRESS}" -qO - "${HTTP}://myip.directadmin.com")
    if [ -z "${DISCOVERED_IP}" ]; then
      printf "*** Error: Cannot determine the server's IP address via myip.directadmin.com\n"
      return
    fi
    printf "Server's IP address used to connect out: %s\n" "${DISCOVERED_IP}"
    return
  }

  ## From DA's setup.sh:
  if [ -e "${DA_CONF}" ]; then
    printf "\n\n"
    printf "*** DirectAdmin already exists ***\n"
    printf "    Press Ctrl-C within the next 10 seconds to cancel the installation\n"
    printf "    Else, wait, and the install will continue, but will destroy existing data\n"
    printf "\n\n"
    sleep 10
  fi

  ## From DA's setup.sh:
  if [ -e /usr/local/cpanel ]; then
    printf "\n\n"
    printf "*** CPanel exists on this system ***\n"
    printf "    Press Ctrl-C within the next 10 seconds to cancel the install\n"
    printf "    Else, wait, and the install will continue overtop (as best it can)\n"
    printf "\n\n"
    sleep 10
  fi

  ## 2016-03-07: Need to create a blank /etc/auth.conf file for DA compatibility
  printf "Checking for /etc/auth.conf\n"
  if [ ! -e /etc/auth.conf ]; then
    ${TOUCH} /etc/auth.conf
    ${CHMOD} 644 /etc/auth.conf
  fi

  ## Update /etc/aliases:
  if [ -e /etc/aliases ]; then
    ALIASES_COUNT=$(grep -c diradmin /etc/aliases)
    if [ "${ALIASES_COUNT}" -eq 0 ]; then
      printf "diradmin: :blackhole:\n" >> /etc/aliases
    fi
    ## Update aliases database
    printf "Updating /etc/aliases\n"
    /usr/bin/newaliases
  fi

  ## Packages directory (not really needed?)
  ${MKDIR} -p "${DA_PATH}"
  ${MKDIR} -p "${DA_PATH}/packages"

  if [ ! -s "${DA_PATH}/update.tar.gz" ]; then
    rm "${DA_PATH}/update.tar.gz"
  fi

  ## Get DirectAdmin binary
  if [ ! -e "${DA_PATH}/update.tar.gz" ]; then
    if [ "${DA_LAN}" -eq 0 ]; then
      ${WGET} --no-check-certificate -S -O "${DA_PATH}/update.tar.gz" "--bind-address=${DA_SERVER_IP}" \
      "${HTTP}://www.directadmin.com/cgi-bin/daupdate?uid=${DA_USER_ID}&lid=${DA_LICENSE_ID}"
    elif [ "${DA_LAN}" -eq 1 ]; then
      ${WGET} --no-check-certificate -S -O "${DA_PATH}/update.tar.gz" \
      "${HTTP}://www.directadmin.com/cgi-bin/daupdate?uid=${DA_USER_ID}&lid=${DA_LICENSE_ID}"
    fi
  fi

  if [ ! -e "${DA_PATH}/update.tar.gz" ]; then
    printf "\n*** Error: Unable to download %s\n" "${DA_PATH}/update.tar.gz"
    exit 3
  fi

  AUTH_COUNT=$(head -n 4 "${DA_PATH}/update.tar.gz" | grep -c '\* You are not allowed to run this program \*');
  if [ "${AUTH_COUNT}" -ne 0 ]; then
    printf "*** \nError: You are not authorized to download the update package \n \
    with that Client ID and License ID from this IP address.\n"
    exit 4
  fi

  ## Extract update.tar.gz into /usr/local/directadmin
  ${TAR} xvf "${DA_PATH}/update.tar.gz" -C "${DA_PATH}"

  ## See if the binary exists:
  if [ ! -e "${DA_PATH}/directadmin" ]; then
    printf "\n*** Error: Cannot find the DirectAdmin binary. Extraction failed.\n"
    exit 5
  fi

  ## PB: Todo: Update addip and startips scripts with improved versions
  # if [ ! -e "${DA_PATH}/scripts/custom/addip" ]; then
  #   if [ -e "${PB_PATH}/directadmin/scripts/custom/addip" ]; then
  #     mkdir -p "${DA_PATH}/scripts/custom"
  #     cp -f "${PB_PATH}/directadmin/scripts/custom/addip" "${DA_PATH}/scripts/custom/addip"
  #   else
  #     echo "Downloading missing file"
  #     ## download file
  #   fi
  # fi
  #
  # echo "Setting custom addip= in DirectAdmin's Configuration Template File "
  # setVal addip "${DA_PATH}/scripts/custom/addip" "${DA_CONF_TEMPLATE}"
  # # setVal addip "${DA_PATH}/scripts/custom/addip" "${DA_CONF}"

  ## The following lines were in DA's install/setup do_checks():
  ## Check for a separate /home partition (for quota support)
  HOME_FOUND=$(grep -c /home /etc/fstab)
  if [ "${HOME_FOUND}" -lt "1" ]; then
    printf "Setting quota_partition=/ in DirectAdmin's Configuration Template File\n"
    setVal quota_partition "/" "${DA_CONF_TEMPLATE}"
  fi

  ## 2016-05-13: From scripts/fstab.sh (/proc is needed)
  ## PB: Verify: Add quota support to fstab
  ${PERL} -pi -e 's/[\ \t]+\/home[\ \t]+ufs[\ \t]+rw[\ \t]+/\t\t\/home\t\t\tufs\trw,userquota,groupquota\t/' /etc/fstab
  ${PERL} -pi -e 's/[\ \t]+\/[\ \t]+ufs[\ \t]+rw[\ \t]+/\t\/\tufs\trw,userquota,groupquota\t/' /etc/fstab

  PROCFS_NUM=$(grep -c procfs /etc/fstab)
  if [ "${PROCFS_NUM}" -eq 0 ]; then
    printf "Adding /proc to /etc/fstab\n"
    printf "proc\t\t/proc\t\tprocfs\trw\t0\t0\n" >> /etc/fstab
    /sbin/mount procfs /proc
  fi

  ## Detect the ethernet interfaces that are available on the system, or use the one supplied by the user from first time setup
  ## PB: NOTE: Ethernet device discovery can return more than 1 interface (even ones commented out) from /etc/rc.conf
  if [ -z "${ETHERNET_DEV}" ]; then
    RC_ETH_DEV="$(grep ifconfig /etc/rc.conf | cut -d= -f1 | cut -d_ -f2)"
    if [ -n "${RC_ETH_DEV}" ]; then
      ETH_COUNT=$(grep -c ethernet_dev ${DA_CONF_TEMPLATE})
      if [ "${ETH_COUNT}" -eq 0 ]; then
        printf "Setting ethernet_dev=%s in DirectAdmin's Configuration Template File\n" "${RC_ETH_DEV}"
        setVal ethernet_dev "${ETH_DEV}" "${DA_CONF_TEMPLATE}"
      fi
    fi
  else
    printf "Setting ethernet_dev=%s in DirectAdmin's Configuration Template File\n" "${ETHERNET_DEV}"
    setVal ethernet_dev "${ETHERNET_DEV}" "${DA_CONF_TEMPLATE}"
  fi

  DA_ADMIN_EMAIL=${DA_ADMIN_EMAIL:=${DA_ADMIN_USER}@${SERVER_DOMAIN}}

  printf "Generating random passwords for SQL DB and DirectAdmin admin user\n"
  DA_SQLDB_PASSWORD=$(random_pass) ## Used as 'root' SQL password
  DA_ADMIN_PASSWORD=$(random_pass) ## Also used as 'da_admin' SQL password

  ## From DA/setup.sh: generate scripts/setup.txt
  {
    printf "hostname=%s\n" "${SERVER_FQDN}"
    printf "email=%s\n" "${DA_ADMIN_EMAIL}"
    printf "mysql=%s\n" "${DA_SQLDB_PASSWORD}"
    printf "mysqluser=%s\n" "${DA_SQLDB_USER}"
    printf "adminname=%s\n" "${DA_ADMIN_USER}"
    printf "adminpass=%s\n" "${DA_ADMIN_PASSWORD}"
    printf "ns1=ns1.%s\n" "${SERVER_DOMAIN}"
    printf "ns2=ns2.%s\n" "${SERVER_DOMAIN}"
    printf "ip=%s\n" "${DA_SERVER_IP}"
    printf "netmask=%s\n" "${DA_SERVER_IP_MASK}"
    printf "uid=%s\n" "${DA_USER_ID}"
    printf "lid=%s\n" "${DA_LICENSE_ID}"
    printf "services=%s\n" "${DA_SERVICES_PKG}"
  } > "${DA_SETUP_TXT}"

  ${CHMOD} 600 "${DA_SETUP_TXT}"

  ## Add the DirectAdmin user & group:
  ${PW} groupadd diradmin 2>&1
  ${PW} useradd -g diradmin -n diradmin -d ${DA_PATH} -s /sbin/nologin 2>&1

  ## Mail User & Group creation
  ## PB: NOTE: FreeBSD already comes with a "mail" group (ID: 6) and a "mailnull" user (ID: 26)
  ##           so this step is somewhat pointless.
  ${PW} groupadd mail 2> /dev/null
  ${PW} useradd -g mail -u 12 -n mail -d /var/mail -s /sbin/nologin 2> /dev/null

  ## PB: FreeBSD already includes a "ftp" group (ID: 14)
  # ${PW} groupadd ftp 2> /dev/null
  # ${PW} useradd -g ftp -n ftp -s /sbin/nologin 2> /dev/null

  ## Apache user/group creation (changed /var/www to /usr/local/www)
  ## PB: NOTE: Using "apache" user instead of "www" for now
  ${PW} groupadd ${APACHE_GROUP} 2> /dev/null
  ${PW} useradd -g ${APACHE_GROUP} -n ${APACHE_USER} -d ${WWW_DIR} -s /sbin/nologin 2> /dev/null

  ## Webapps user/group creation
  if [ "$(grep -c -m1 -e "^${WEBAPPS_USER}:" /etc/passwd)" = "0" ]; then
    ${PW} groupadd ${WEBAPPS_GROUP} 2> /dev/null
    ${PW} useradd -g ${WEBAPPS_GROUP} -n ${WEBAPPS_USER} -b ${WWW_DIR} -s /sbin/nologin 2> /dev/null
  fi

  ## Set DirectAdmin Folder permissions:
  ${CHMOD} -f 755 ${DA_PATH}
  ${CHOWN} -f diradmin:diradmin ${DA_PATH}

  ## Create directories (logs and conf) and set permissions:
  ${MKDIR} -p "${LOGS}/directadmin"
  ${MKDIR} -p "${DA_PATH}/conf"

  ${CHOWN} -f diradmin:diradmin ${DA_PATH}/*
  ${CHOWN} -f diradmin:diradmin "${LOGS}/directadmin"
  ${CHMOD} -f 700 "${DA_PATH}/conf"
  ${CHMOD} -f 700 "${LOGS}/directadmin"

  #${MKDIR} -p ${DA_PATH}/scripts/packages
  ${MKDIR} -p "${DA_PATH}/data/admin"

  ## Set permissions
  ${CHOWN} -R diradmin:diradmin "${DA_PATH}/scripts/"
  ${CHOWN} -R diradmin:diradmin "${DA_PATH}/data/"

  ## No conf files in a fresh install:
  ${CHOWN} -f diradmin:diradmin ${DA_PATH}/conf/* 2> /dev/null > /dev/null
  ${CHMOD} -f 600 ${DA_PATH}/conf/* 2> /dev/null > /dev/null

  ## Create logs directory:
  ${MKDIR} -p "${LOGS}/httpd/domains"
  ${CHMOD} 700 "${LOGS}/httpd"

  ## NOTE: /home => /usr/home
  ${MKDIR} -p /home/tmp
  ${CHMOD} -f 1777 /home/tmp
  ${CHMOD} 711 /home

  ## PB: Create User and Reseller Welcome message (need to download/copy these files):
  ## 2016-03-22: Needed?
  # touch ${DA_PATH}/data/users/admin/u_welcome.txt
  # touch ${DA_PATH}/data/admin/r_welcome.txt

  ## PB: Verify: Create backup.conf (wasn't created?)
  # ${CHOWN} -f diradmin:diradmin ${DA_PATH}/data/users/admin/backup.conf

  ## 2016-06-24: Necessary? Don't we need PermitRootLogin yes added?
  SSHROOT=$(grep -c 'AllowUsers root' ${SSHD_CONFIG})
  if [ "${SSHROOT}" = 0 ]; then
    printf "*** Notice: Adding the 'root' user to the sshd configuration's AllowUsers list.\n"
    {
      printf "AllowUsers root\n"
      printf "AllowUsers %s\n" "${DA_ADMIN_USER}"
      printf "AllowUsers %s\n" "$(logname)"
      ## printf "AllowUsers %s\n" "${YOUR_OTHER_ADMIN_ACCOUNT}""
    } >> ${SSHD_CONFIG}

    ## Set SSH folder permissions (needed?):
    ${CHMOD} 710 /etc/ssh
  fi

  LICENSE_COUNT="$(grep -c '\* You are not allowed to run this program \*' ${DA_LICENSE})"
  if [ "${LICENSE_COUNT}" -ne 0 ]; then
    rm "${DA_LICENSE}"
  fi

  ## Download DirectAdmin License file
  if [ ! -e "${DA_LICENSE}" ]; then
    ${WGET} "${HTTP}://www.directadmin.com/cgi-bin/licenseupdate?lid=${DA_LICENSE_ID}&uid=${DA_USER_ID}${DA_EXTRA_VALUE}" -O "${DA_LICENSE}" "${BIND_ADDRESS}"

    if [ "$?" -ne 0 ]; then
      printf "*** Warning: Unable to download the DirectAdmin license file.\n"
      da_myip

      printf "Trying the license relay server...\n"
      ${WGET} "${HTTP}://license.directadmin.com/licenseupdate.php?lid=${DA_LICENSE_ID}&uid=${DA_USER_ID}${DA_EXTRA_VALUE}" -O "${DA_LICENSE}" "${BIND_ADDRESS}"

      if [ "$?" -ne 0 ]; then
        printf "*** Error: Unable to download the DirectAdmin license file from relay server as well.\n"
        da_myip
        exit 2
      fi
    fi

    LICENSE_CHECK="$(grep -c '\* You are not allowed to run this program \*' ${DA_LICENSE})"
    if [ "${LICENSE_CHECK}" -ne 0 ]; then
      printf "*** Error: You are not authorized to download the DirectAdmin license\n"
      printf "\t\t\twith that Client ID and License ID (and/or IP address).\n"
      printf "\t\t\tPlease email sales@directadmin.com\n\n"
      printf "\t\t\tIf you are having connection issues, please see this guide:\n"
      printf "\t\t\thttp://help.directadmin.com/item.php?id=30\n\n"
      da_myip
      exit 3
    fi
  fi

  ## Set permissions on license.key:
  ${CHMOD} 600 ${DA_LICENSE}
  ${CHOWN} diradmin:diradmin ${DA_LICENSE}

  ${MKDIR} -p "${DA_PATH}/data/users/admin/packages"
  ${CHOWN} diradmin:diradmin "${DA_PATH}/data/users/admin/packages"
  ${CHMOD} 700 "${DA_PATH}/data/users/admin/packages"

  if [ ! -d "${DA_PATH}/data/templates/custom" ]; then
    printf "*** Notice: Copying custom PB DirectAdmin templates.\n"
    cp -Rf "${PB_PATH}/directadmin/data/templates/custom/" "${DA_PATH}/data/templates/custom/"
    ${CHOWN} -R diradmin:diradmin "${DA_PATH}/data/templates/custom/"
  fi

  ${MKDIR} -p /home/admin/domains/sharedip
  ${CHOWN} -R "${DA_ADMIN_USER}:${DA_ADMIN_USER}" /home/admin/domains/sharedip

  return
}

################################################################################
## DirectAdmin Update via CLI (from CB2: daUpdateDA())
################################################################################

directadmin_update() {
  printf "Updating DirectAdmin\n"
  echo "action=update&value=program" >> "${DA_TASK_QUEUE}"
  run_dataskq
  return
}

################################################################################
## DirectAdmin Restart
################################################################################

directadmin_restart() {
  printf "Restarting DirectAdmin\n"
  echo "action=directadmin&value=reload" >> "${DA_TASK_QUEUE}"
  run_dataskq
  return
}

################################################################################
## Basic System Security Tasks
################################################################################

basic_system_security() {

  printf "Running Basic System Security Tasks\n"

  printf "Setting security.bsd.see_other_uids to 0\n"
  ${SYSRC} -f /etc/sysctl.conf security.bsd.see_other_uids=0

  printf "Setting security.bsd.see_other_gids to 0\n"
  ${SYSRC} -f /etc/sysctl.conf security.bsd.see_other_gids=0

# setVal enforce_difficult_passwords 1 ${DA_CONF_TEMPLATE}
# setVal enforce_difficult_passwords 1 ${DA_CONF}

  printf "\n *** Heads up! *** \n"
  printf "Please note that 'AllowUsers root' was added to %s as a precautionary step (in case you get locked out).\n" "${SSHD_CONFIG}"
  printf "This means the root user can remotely login to this machine via SSH.\n"
  printf "You may want to modify this value/file later on when setting up this machine for production use.\n\n"

  return
}

################################################################################
## Install DA cron (from: scripts/install.sh)
################################################################################

install_cron() {

  local COUNT

  COUNT=$(grep -c dataskq < /etc/crontab)

  if [ "$COUNT" = 0 ]; then
    # if [ -s "${DA_CRON_FILE}" ]; then
      printf "Updating /etc/crontab with required DirectAdmin schedules\n"
      # cat "${DA_CRON_FILE}" >> /etc/crontab
      {
        printf "\n"
        printf "*\t*\t*\t*\t*\troot\t/usr/local/directadmin/dataskq\n"
        printf "2\t0-23/6\t*\t*\t*\troot\techo 'action=vacation&value=all' >> /usr/local/directadmin/data/task.queue;\n"
        printf "5\t0\t*\t*\t*\troot\t/usr/sbin/quotaoff -a; /sbin/quotacheck -aug; /usr/sbin/quotaon -a;\n"
        printf "30\t0\t*\t*\t*\troot\techo 'action=tally&value=all' >> /usr/local/directadmin/data/task.queue\n"
        printf "40\t1\t1\t*\t*\troot\techo 'action=reset&value=all' >> /usr/local/directadmin/data/task.queue\n"
        printf "0\t4\t*\t*\t*\troot\techo 'action=check&value=license' >> /usr/local/directadmin/data/task.queue\n"
      } >> /etc/crontab
    # else
    #   printf "*** Error: Could not find %s or the file is empty.\n" "${DA_CRON_FILE}"
    # fi
  fi

  return
}

################################################################################
## Deny Specific Users from Cron (from install.sh)
################################################################################

deny_cron() {

  local DENY_FILE

  DENY_FILE=/var/cron/deny

  deny() {
    if [ -e "${DENY_FILE}" ]; then
      DENY_COUNT=$(grep -c -e "^$1\$" "${DENY_FILE}")
      if [ "${DENY_COUNT}" -ne 0 ]; then
        return
      fi
    fi
    printf "%s\n" "${1}" >> "${DENY_FILE}"
    ${CHMOD} 600 "${DENY_FILE}"
  }

  deny "${APACHE_USER}"
  deny "${WEBAPPS_USER}"

  return
}

################################################################################
## Newsyslog Setup (from install.sh)
## PB: Todo: Use/Merge with freebsd_set_newsyslog?
################################################################################

newsyslog_setup() {

  if [ ! -d /usr/local/etc/newsyslog.conf.d ]; then
    ${MKDIR} -p /usr/local/etc/newsyslog.conf.d
  fi

  if [ ! -e "${NEWSYSLOG_FILE}" ]; then
    printf "Creating newsyslog configuration file for DirectAdmin.\n"
    printf "File: %s\n" "${NEWSYSLOG_FILE}"
    ${TOUCH} "${NEWSYSLOG_FILE}"
  fi

  ## addLog /file user:group flag pid
  addLog() {
    local COUNT
    COUNT=$(grep -c "$1" "${NEWSYSLOG_FILE}")
    if [ "${COUNT}" -ne 0 ]; then
      return
    fi
    # logfilename          [owner:group]    mode count size when  flags [/pid_file] [sig_num]
    printf "%s\t%s\t600\t%s\t*\t@T00\t%s\t%s\n" "$1" "$2" "${NEWSYSLOG_DAYS}" "$3" "$4" >> "${NEWSYSLOG_FILE}"
  }

  ## DirectAdmin
  addLog "${LOGS}/directadmin/error.log" diradmin:diradmin -
  addLog "${LOGS}/directadmin/errortaskq.log" diradmin:diradmin -
  addLog "${LOGS}/directadmin/security.log" diradmin:diradmin -
  addLog "${LOGS}/directadmin/system.log" diradmin:diradmin -
  addLog "${LOGS}/directadmin/login.log" diradmin:diradmin -

  ## Apache
  if [ "${OPT_WEBSERVER}" = "apache" ]; then
    addLog "${LOGS}/httpd/access_log" ${APACHE_USER}:${APACHE_GROUP} -
    addLog "${LOGS}/httpd/fpexe_log" ${APACHE_USER}:${APACHE_GROUP} -
    addLog "${LOGS}/httpd/suexec_log" ${APACHE_USER}:${APACHE_GROUP} -
    addLog "${LOGS}/suphp.log" '' -
    addLog "${LOGS}/httpd/error_log" ${APACHE_USER}:${APACHE_GROUP} - /var/run/httpd.pid
  fi

  ## Todo: Nginx
  if [ "${OPT_WEBSERVER}" = "nginx" ]; then
    addLog "${LOGS}/httpd/access_log" ${APACHE_USER}:${APACHE_GROUP} -
    addLog "${LOGS}/httpd/fpexe_log" ${APACHE_USER}:${APACHE_GROUP} -
    addLog "${LOGS}/httpd/suexec_log" ${APACHE_USER}:${APACHE_GROUP} -
    addLog "${LOGS}/suphp.log" '' -
    addLog "${LOGS}/httpd/error_log" ${APACHE_USER}:${APACHE_GROUP} - /var/run/httpd.pid
  fi

  ## Exim
  if [ "${OPT_EXIM}" = "YES" ]; then
    addLog "${LOGS}/exim/paniclog" ${EXIM_USER}:${EXIM_GROUP} -
    addLog "${LOGS}/exim/exim_paniclog" ${EXIM_USER}:${EXIM_GROUP} -
    addLog "${LOGS}/exim/rejectlog" ${EXIM_USER}:${EXIM_GROUP} -
    addLog "${LOGS}/exim/exim_rejectlog" ${EXIM_USER}:${EXIM_GROUP} -
    addLog "${LOGS}/exim/processlog" ${EXIM_USER}:${EXIM_GROUP} -
    addLog "${LOGS}/exim/exim_processlog" ${EXIM_USER}:${EXIM_GROUP} -
    addLog "${LOGS}/exim/mainlog" ${EXIM_USER}:${EXIM_GROUP} - /var/run/exim.pid
    addLog "${LOGS}/exim/exim_mainlog" ${EXIM_USER}:${EXIM_GROUP} - /var/run/exim.pid
  fi

  ## ProFTPD
  if [ "${OPT_FTPD}" = "proftpd" ]; then
    addLog "${LOGS}/proftpd/auth.log" '' -
    addLog "${LOGS}/proftpd/xferlog.legacy" '' -
    addLog "${LOGS}/proftpd/access.log" '' - /var/run/proftpd/proftpd.pid
  fi

  ## PureFTPD
  if [ "${OPT_FTPD}" = "pureftpd" ]; then
    addLog "${LOGS}/pureftp.log" '' - /var/run/pure-ftpd.pid
  fi

  ## PHP-FPM
  if [ "${OPT_PHP_MODE}" = "php-fpm" ]; then
    if [ -x "${RCD}/php-fpm" ]; then
      addLog "${LOGS}/php-fpm.log" '' - "/var/run/php-fpm.pid\t30"
    fi
  fi

  ## RoundCube
  if [ "${OPT_ROUNDCUBE}" = "YES" ]; then
    addLog "${WWW_DIR}/roundcube/logs/errors" ${WEBAPPS_USER}:${WEBAPPS_GROUP} -
  fi

  ## phpMyAdmin
  if [ "${OPT_PHPMYADMIN}" = "YES" ]; then
    addLog "${WWW_DIR}/phpMyAdmin/log/auth.log" ${WEBAPPS_USER}:${WEBAPPS_GROUP} -
  fi

  ## SquirrelMail
  if [ "${OPT_SQUIRRELMAIL}" = "YES" ]; then
    addLog "${WWW_DIR}/squirrelmail/data/squirrelmail_access_log" ${WEBAPPS_USER}:${WEBAPPS_GROUP} -
  fi

  # addLog "${LOGS}/chrootshell.log" '' -

  return
}

################################################################################
## FreeBSD Set NewSyslog (from CB2)
################################################################################

freebsd_set_newsyslog() {

  local NSL_FILE="$1"
  local NSL_ACCOUNT="$2"

  if [ ! -e "${NEWSYSLOG_FILE}" ]; then
    ${MKDIR} -p /usr/local/etc/newsyslog.conf.d/
    ${TOUCH} "${NEWSYSLOG_FILE}"
  fi

  ## Todo: Remove:
  # if [ ! "${NEWSYSLOG_DAYS}" -gt 0 ]; then
  #   NEWSYSLOG_DAYS=10
  # fi

  if ! grep -q "${NSL_FILE}" "${NEWSYSLOG_FILE}"; then
    printf "%s\t%s\t600\t%d\t*\t@T00\t-\n" "${NSL_FILE}" "${NSL_ACCOUNT}" "${NEWSYSLOG_DAYS}" >> "${NEWSYSLOG_FILE}"
  fi

  ## CB2: Replace whatever we may have with whatever we need, eg:
  #/var/www/html/roundcube/logs/errors  webapps:webapps 600     4       *       @T00    -
  #/var/www/html/roundcube/logs/errors  apache:apache 600     4       *       @T00    -
  #/var/www/html/roundcube/logs/errors      600     4       *       @T00    -

  ${PERL} -pi -e "s|^${NSL_FILE}\s+${WEBAPPS_USER}:${WEBAPPS_GROUP}\s+|${NSL_FILE}\t${NSL_ACCOUNT}\t|" "${NEWSYSLOG_FILE}"
  ${PERL} -pi -e "s|^${NSL_FILE}\s+${APACHE_USER}:${APACHE_GROUP}\s+|${NSL_FILE}\t${NSL_ACCOUNT}\t|" "${NEWSYSLOG_FILE}"
  ${PERL} -pi -e "s|^${NSL_FILE}\s+600\s+|${NSL_FILE}\t${NSL_ACCOUNT}\t600\t|" "${NEWSYSLOG_FILE}"
}

################################################################################
## Verify Webapps Log Rotation (from CB2: ensure_webapps_lograte())
################################################################################

verify_webapps_logrotate() {

  ## CB2:
  # By default it sets each log file's permissions to webapps:webapps
  # Swap it to apache:apache if needed,
  # else swap it to webapps:webapps from apache:apache... or do nothing

  local NSL_VALUE="${WEBAPPS_USER}:${WEBAPPS_GROUP}"

  if [ "${OPT_PHP_MODE}" = "mod_php" ]; then
    NSL_VALUE="${APACHE_USER}:${APACHE_GROUP}"
  fi

  if [ "${OPT_ROUNDCUBE}" = "YES" ]; then
    freebsd_set_newsyslog "${WWW_DIR}/roundcube/logs/errors" ${NSL_VALUE}
  fi

  if [ "${OPT_PHPMYADMIN}" = "YES" ]; then
    freebsd_set_newsyslog "${WWW_DIR}/phpMyAdmin/log/auth.log" ${NSL_VALUE}
  fi

  if [ "${OPT_SQUIRRELMAIL}" = "YES" ]; then
    freebsd_set_newsyslog "${WWW_DIR}/squirrelmail/data/squirrelmail_access_log" ${NSL_VALUE}
  fi

  return
}

################################################################################
## Exim Installation
################################################################################

exim_install() {

  local IFS=' '
  local virtual_files

  if [ "${OPT_EXIM}" != "YES" ]; then
    printf "*** Notice: EXIM is disabled in options.conf\n"
    return
  fi

  printf "Starting Exim installation\n"

  ### Main Installation
  if [ -z "${EXIM_MAKE_SET}" ] && [ -z "${EXIM_MAKE_UNSET}" ]; then
    pkgi ${PORT_EXIM}
  else
    ${MAKE} -DNO_DIALOG -C "${PORTS_BASE}/${PORT_EXIM}" rmconfig
    ${MAKE} -DNO_DIALOG -C "${PORTS_BASE}/${PORT_EXIM}" \
    mail_exim_SET="${EXIM_MAKE_SET}" \
    mail_exim_UNSET="${EXIM_MAKE_UNSET}" \
    OPTIONS_SET="${GLOBAL_MAKE_SET}" \
    OPTIONS_UNSET="${GLOBAL_MAKE_UNSET}" \
    reinstall clean
  fi
  # EXIM_USER="${EXIM_USER}" EXIM_GROUP="${EXIM_GROUP}"

  ## From: DA's scripts/install.sh
  ${MKDIR} -p "${VIRTUAL_PATH}"
  ${CHOWN} -f "${EXIM_USER}:${EXIM_GROUP}" "${VIRTUAL_PATH}"
  ${CHMOD} 755 "${VIRTUAL_PATH}"

  if [ ! -s "${VIRTUAL_PATH}/limit" ]; then
    printf "%s\n" "${LIMIT_DEFAULT}" > "${VIRTUAL_PATH}/limit"
  fi

  if [ ! -s "${VIRTUAL_PATH}/limit_unknown" ]; then
    printf "%s\n" "${LIMIT_UNKNOWN}" > "${VIRTUAL_PATH}/limit_unknown"
  fi

  ${CHMOD} 755 ${VIRTUAL_PATH}/*

  if [ ! -d "${VIRTUAL_PATH}/usage" ]; then
    ${MKDIR} "${VIRTUAL_PATH}/usage"
  fi

  ${CHMOD} 750 ${VIRTUAL_PATH}/usage

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
    blacklist_smtp_usernames \
    blacklist_script_usernames"

  for file in ${virtual_files}; do
    if [ ! -e "${VIRTUAL_PATH}/${file}" ]; then
      ${TOUCH} "${VIRTUAL_PATH}/${file}"
    fi
    ${CHOWN} "${EXIM_USER}:${EXIM_GROUP}" "${VIRTUAL_PATH}/${file}"
    ${CHMOD} 600 "${VIRTUAL_PATH}/${file}"
  done

  ## Todo: add check first before adding 'hostname'
  ## Verify: replace with: $(hostname)
  hostname >> "${VIRTUAL_PATH}/domains"

  ${CHOWN} -f ${EXIM_USER}:${EXIM_GROUP} ${VIRTUAL_PATH}/*
  ${CHOWN} -R ${EXIM_USER}:${EXIM_GROUP} /var/spool/exim

  if [ ! -d "${EXIM_PATH}/ssl" ]; then
    ${MKDIR} -p "${EXIM_PATH}/ssl"
    ${CHOWN} "${EXIM_USER}:${EXIM_GROUP}" "${EXIM_PATH}/ssl"
    ${CHMOD} 755 "${EXIM_PATH}/ssl"
  fi

  if [ ! -e "${EXIM_SSL_KEY}" ]; then
    ## Generate Self-Signed SSL Certificates
    ## See: http://help.directadmin.com/item.php?id=245
    ${OPENSSL} req -x509 -newkey rsa:2048 -keyout ${EXIM_SSL_KEY} \
    -out ${EXIM_SSL_CRT} -days 9000 -nodes -config "${SSL_REQ_CONF}" # "${OPENSSL_EXTRA}"
  fi

  ${CHOWN} "${EXIM_USER}:${EXIM_GROUP}" ${EXIM_SSL_KEY}
  ${CHMOD} 600 ${EXIM_SSL_KEY}

  ${CHOWN} "${EXIM_USER}:${EXIM_GROUP}" ${EXIM_SSL_CRT}
  ${CHMOD} 644 ${EXIM_SSL_CRT}

  ## Symlink for DA compat:
  if [ "${COMPAT_EXIM_SYMLINKS}" = "YES" ]; then
    if [ -e ${EXIM_CONF} ]; then
      ln -sf ${EXIM_CONF} /etc/exim.conf
      ${CHOWN} -h "${EXIM_USER}:${EXIM_GROUP}" /etc/exim.conf
      ${CHMOD} -h 644 /etc/exim.conf
    fi
    if [ -e "${EXIM_SSL_CRT}" ]; then
      ln -sf ${EXIM_SSL_CRT} /etc/exim.cert
      ${CHOWN} -h "${EXIM_USER}:${EXIM_GROUP}" /etc/exim.cert
      ${CHMOD} -h 644 /etc/exim.cert
    fi
    if [ -e "${EXIM_SSL_KEY}" ]; then
      ln -sf ${EXIM_SSL_KEY} /etc/exim.key
      ${CHOWN} -h "${EXIM_USER}:${EXIM_GROUP}" /etc/exim.key
      ${CHMOD} -h 600 /etc/exim.key
    fi
  fi

  ## Set Exim user/group in configuration
  ${PERL} -pi -e "s#exim_user = mailnull#exim_user = ${EXIM_USER}#" ${EXIM_CONF}
  ${PERL} -pi -e "s#exim_group = mail#exim_group = ${EXIM_GROUP}#" ${EXIM_CONF}

  ## Symlink configuration file (exim.conf -> configure)
  # ln -s ${EXIM_CONF} "${EXIM_PATH}/exim.conf"

  ## Verify Exim config:
  ${EXIM_BIN} -C "${EXIM_CONF}" -bV

  ## Update /etc/rc.conf
  printf "Enabling Exim startup (updating /etc/rc.conf)\n"
  ${SYSRC} exim_enable="YES"
  ${SYSRC} exim_flags="-bd -q1h"

  if [ ! -e /etc/periodic.conf ]; then
    printf "Creating /etc/periodic.conf\n"
    ${TOUCH} /etc/periodic.conf
  fi

  printf "Updating /etc/periodic.conf\n"
  ${SYSRC} -f /etc/periodic.conf daily_status_include_submit_mailq="NO"
  ${SYSRC} -f /etc/periodic.conf daily_clean_hoststat_enable="NO"

  ## ${SERVICE} exim start
  exim_restart

  # printf "Updating mq_exim_bin paths in DirectAdmin template + configuration files\n"
  setVal mq_exim_bin ${EXIM_BIN} ${DA_CONF_TEMPLATE}

  if [ -e "${DA_CONF}" ]; then
    setVal mq_exim_bin ${EXIM_BIN} ${DA_CONF}
  fi

  ## Todo: Cleaner version
  ## Replace sendmail programs with Exim binaries (see: mailwrapper)
  ## Verify: Modify /usr/local/etc/mailer.conf instead?
  if [ ! -e /etc/mail/mailer.conf ]; then
    printf "Creating /etc/mail/mailer.conf\n"
    ${TOUCH} /etc/mail/mailer.conf

    # cp "${PB_PATH}/configure/etc/mail/mailer.93.conf" /etc/mail/mailer.conf
    # cp "${PB_PATH}/configure/etc/mail/mailer.100.conf" /etc/mail/mailer.conf
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
    printf "%s\t%s\n" "sendmail" "${EXIM_BIN}"
    printf "%s\t%s\n" "send-mail" "${EXIM_BIN}"
    printf "%s\t\t%s\n" "mailq" "${EXIM_BIN} -bp"
    printf "%s\t%s\n" "newaliases" "/usr/bin/true"
    printf "%s\t\t%s\n" "rmail" "${EXIM_BIN} -i -oee"
  } > /etc/mail/mailer.conf

  return
}

################################################################################
## Rewrite named (DNS) database records for all domains
################################################################################

rewrite_namedb() {

  if [ -e ${PB_PATH}/directadmin/scripts/fix_namedb.sh ]; then
    ${CHMOD} 755 ${PB_PATH}/directadmin/scripts/fix_namedb.sh
    ${PB_PATH}/directadmin/scripts/fix_namedb.sh
  else
    printf "*** Error: cannot find scripts/fix_namedb.sh to rewrite DNS records.\n"
    exit 1
  fi

  ${SERVICE} named restart

  return
}

################################################################################
## Exim Restart with configuration file verification
################################################################################

exim_restart() {

  ${EXIM_BIN} -C "${EXIM_CONF}" -bV

  if [ "$?" = "0" ]; then
    printf "Restarting Exim\n"
    ${SERVICE} exim restart
  else
    printf "*** Warning: Aborting automatic Exim restart due to configuration verification failure.\n"
    printf "Please verify the Exim configuration file at: %s\n" ${EXIM_CONF}
    printf "You can verify the file by typing:\n"
    printf "  %s -C %s -bV\n\n" ${EXIM_BIN} ${EXIM_CONF}
    printf "You can restart Exim manually by typing:\n"
    printf "  service exim restart\n"
  fi

  return
}

################################################################################
## Todo: Exim Upgrade
################################################################################

exim_upgrade() {
  printf "*** Notice: Upgrading Exim\n"
  pkgu "${PORT_EXIM}"
  exim_restart
  return
}

################################################################################
## Uninstall Exim
################################################################################

exim_uninstall() {

  printf "*** Notice: Uninstalling Exim\n"

  ${SERVICE} exim stop

  ${SYSRC} -q -x exim_enable
  ${SYSRC} -q -x exim_flags
  ${SYSRC} -q -f /etc/periodic.conf daily_status_include_submit_mailq
  ${SYSRC} -q -f /etc/periodic.conf daily_clean_hoststat_enable

  pkgd "${PORT_EXIM}"

  ## Todo: Restore /etc/mail/mailer.conf:
  #sendmail       /usr/libexec/sendmail/sendmail
  #send-mail      /usr/libexec/sendmail/sendmail
  #mailq          /usr/libexec/sendmail/sendmail
  #newaliases     /usr/libexec/sendmail/sendmail
  #hoststat       /usr/libexec/sendmail/sendmail
  #purgestat      /usr/libexec/sendmail/sendmail

  return
}

################################################################################
## Exim Version (from CB2)
################################################################################

exim_version() {
  ${EXIM_BIN} -bV | grep -m1 'built' | head -n1 | awk '{ print $3 }'
  return
}

################################################################################
## Verify Exim Keep Environment (from CB2)
################################################################################

verify_exim_keep_env(){

  local EXIMV FOR_EXIM_CONF_VER

  EXIMV="$(exim_version)"

  ## CB2:
  ## This might be the current exim.conf, or the exim.conf being installed.
  ## Set by whichever is calling the function.
  FOR_EXIM_CONF_VER=$1

  if [ "${FOR_EXIM_CONF_VER}" != "2.1" ] && [ "${FOR_EXIM_CONF_VER}" != "4.2" ]; then
    ## CB2: for newer exim.conf files with exim.variables.conf:
    ## CB2: remove variables from the default that don't work with older versions of exim.
    if [ "$(version_cmp ${EXIMV} 4.86.2 'exim ver for keep_environment')" -lt 0 ]; then
      echo "Exim ${EXIMV} is older than 4.86.2. Removing variable keep_environment."
      ${PERL} -pi -e 's/^keep_environment=.*$\n//' "${EXIM_PATH}/exim.variables.conf.default"
      ${PERL} -pi -e 's/^keep_environment=.*$\n//' "${EXIM_PATH}/exim.variables.conf"
    fi
  else
    ## CB2:
    ## older exim.conf files without extra files.
    ## remove variables from the exim.conf that don't work with older versions of exim.
    if [ "$(version_cmp ${EXIMV} 4.86.2 'exim ver for keep_environment')" -lt 0 ]; then
      echo "Exim ${EXIMV} is older than 4.86.2. Removing variable keep_environment from ${EXIM_CONF}.";
      ${PERL} -pi -e 's/^keep_environment=/#keep_environment=/' ${EXIM_CONF}
    else
      ## CB2: else enable the feature, if available.
      echo "Exim ${EXIMV} is at least 4.86.2.";
      COUNT_KEEP_ENV=$(grep -c 'keep_environment' ${EXIM_CONF})
      if [ "${COUNT_KEEP_ENV}" -gt 0 ]; then
        printf "Uncommenting variable keep_environment in %s.\n" ${EXIM_CONF}
        ${PERL} -pi -e 's/^#keep_environment=/keep_environment=/' ${EXIM_CONF}
      else
        printf "Adding variable keep_environment to %s.\n" ${EXIM_CONF}
        ${PERL} -pi -e 's/^perl_startup/keep_environment=PWD\nperl_startup/' ${EXIM_CONF}
      fi
    fi
  fi

  return
}

################################################################################
## Exim.conf Version (from CB2)
################################################################################

exim_conf_version() {

  local COUNT=0
  local T_EXIMCONFV=0

  if [ -e "${EXIM_CONF}" ]; then
    COUNT="$(head -n1 ${EXIM_CONF} | grep -c 'Version')"
    if [ "${COUNT}" -gt 0 ]; then
      T_EXIMCONFV="$(head -n1 ${EXIM_CONF} | awk '{ print $6 }')"
    fi

    if [ "${T_EXIMCONFV}" = "0" ]; then
      COUNT=$(head -n2 ${EXIM_CONF} | grep -c release)
      if [ "${COUNT}" -gt 0 ]; then
        T_EXIMCONFV="$(head -n2 ${EXIM_CONF} | grep release | awk '{ print $2 }' | cut -d. -f4,5,6 | cut -d- -f1)"
      fi
    fi
  fi

  if [ "${T_EXIMCONFV}" = "0" ]; then
    printf "exim_conf_version: Cannot determine version of %s\n" ${EXIM_CONF}
  fi

  printf "%s\n" "${T_EXIMCONFV}"

  return
}

################################################################################
## Verify: Generate Exim.conf (from CB2: doEximConf())
################################################################################

exim_conf() {

  local EXIMV EXIM_CONF_MERGED EXIM_CONF_DEFAULT EXIM_CONF_CUSTOM

  if [ "${OPT_EXIM_CONF_UPDATE}" != "YES" ]; then
    printf "*** Error: You cannot update Exim configuration files because you do not have EXIM_CONF_UPDATE set in options.conf.\n"
    exit 1
  fi

  ${WGET} ${WGET_CONNECT_OPTIONS} -O "${EXIM_PATH}/exim.conf.cb20" http://${PB_MIRROR}/services/SpamBlocker/${EXIM_CONF_VER}/exim.conf-SpamBlockerTechnology-v${EXIM_CONF_VER}.txt

  ## CB2: Don't overwrite exim.conf if wget failed (empty exim.conf file)
  if [ -s "${EXIM_PATH}/exim.conf.cb20" ]; then
    mv -f "${EXIM_PATH}/exim.conf.cb20" ${EXIM_CONF}
  else
    rm -f "${EXIM_PATH}/exim.conf.cb20"
    printf "Download of exim.conf failed.\n"
  fi

  ## CB2: Used to determine if we need to remove some variables from the exim.conf or exim.variables.conf.
  EXIMV="$(exim_version)"

  ## CB2: Download additional files for exim.conf
  if [ "${OPT_EXIMCONF_RELEASE}" != "2.1" ] && [ "${OPT_EXIMCONF_RELEASE}" != "4.2" ]; then
    ${WGET} ${WGET_CONNECT_OPTIONS} -O ${EXIM_PATH}/exim.strings.conf.cb20 http://${PB_MIRROR}/services/SpamBlocker/${EXIM_CONF_VER}/exim.strings.conf
    ${WGET} ${WGET_CONNECT_OPTIONS} -O ${EXIM_PATH}/exim.variables.conf.cb20 http://${PB_MIRROR}/services/SpamBlocker/${EXIM_CONF_VER}/exim.variables.conf.default

    EXIM_CONF_MERGED="${EXIM_PATH}/exim.variables.conf.merged"
    EXIM_CONF_DEFAULT="${EXIM_PATH}/exim.variables.conf.default"
    EXIM_CONF_CUSTOM="${EXIM_PATH}/exim.variables.conf.custom"

    if [ -s "${EXIM_PATH}/exim.strings.conf.cb20" ]; then
      mv -f "${EXIM_PATH}/exim.strings.conf.cb20" "${EXIM_PATH}/exim.strings.conf"
    else
      rm -f "${EXIM_PATH}/exim.strings.conf.cb20"
      printf "*** Error: Download of exim.strings.conf failed\n"
    fi

    if [ -s "${EXIM_PATH}/exim.variables.conf.cb20" ]; then
      mv -f "${EXIM_PATH}/exim.variables.conf.cb20" ${EXIM_CONF_DEFAULT}
    else
      rm -f "${EXIM_PATH}/exim.variables.conf.cb20"
      printf "*** Error: Download of ${EXIM_CONF_DEFAULT} failed\n"
    fi

    if [ -s "${EXIM_CONF_DEFAULT}" ]; then
      if [ "${IPV6}" = "0" ]; then
        ${PERL} -pi -e 's|disable_ipv6=false|disable_ipv6=true|' ${EXIM_CONF_DEFAULT}
      else
        ${PERL} -pi -e 's|disable_ipv6=true|disable_ipv6=false|' ${EXIM_CONF_DEFAULT}
      fi
    else
      printf "\n*** Error: %s does not exist or is empty.\n\n" ${EXIM_CONF_DEFAULT}
    fi

    if [ ! -s "${EXIM_PATH}/exim.variables.conf" ] && [ -s "${EXIM_CONF_DEFAULT}" ]; then
      cp -f ${EXIM_CONF_DEFAULT} "${EXIM_PATH}/exim.variables.conf"
    fi

    ########################################

    ## CB2: need to do a merge here with exim.variables.conf.default
    ##      and exim.variables.conf.custom, and save to exim.variables.conf

    printf "# Do not edit this file directly\n" > ${EXIM_CONF_MERGED}
    printf "# Edit %s\n" "${EXIM_CONF_CUSTOM}" >> ${EXIM_CONF_MERGED}

    ## CB2: Because anything from custom, including extras (not in default), will always go in.
    if [ -s ${EXIM_CONF_CUSTOM} ]; then
      cat ${EXIM_CONF_CUSTOM} >> ${EXIM_CONF_MERGED}
    fi

    for i in $(cat ${EXIM_CONF_DEFAULT} | cut -d= -f1); do
      if [ -e ${EXIM_CONF_CUSTOM} ]; then
        if [ "$(grep -m1 -c ^${i}= ${EXIM_CONF_CUSTOM})" = "1" ]; then
          continue
        fi
      fi

      VALUE="$(grep -m1 ^${i} ${EXIM_CONF_DEFAULT} | cut -d= -f2)"
      echo "${i}=${VALUE}" >> ${EXIM_CONF_MERGED}
    done

    mv -f ${EXIM_CONF_MERGED} "${EXIM_PATH}/exim.variables.conf"

    EXIM_SRS_CONF="${EXIM_PATH}/exim.srs.conf"
    EXIM_SRS_FORWARD_CONF="${EXIM_PATH}/exim.srs.forward.conf"

    if [ "${OPT_EXIM_SRS}" = "YES" ]; then
      if [ ! -s ${EXIM_SRS_CONF} ]; then
        printf "hide srs_config = " > ${EXIM_SRS_CONF}
        ${OPENSSL} rand -base64 48 >> ${EXIM_SRS_CONF}
      fi

      if [ ! -e ${EXIM_SRS_FORWARD_CONF} ]; then
        printf "srs = forward\n" > ${EXIM_SRS_FORWARD_CONF}
      fi
    fi
  else
    ## Older exim.conf file changes:
    if [ -s ${EXIM_CONF} ];  then
      if [ "${IPV6}" = "0" ]; then
        ${PERL} -pi -e 's|disable_ipv6=false|disable_ipv6=true|' ${EXIM_CONF}
      else
        ${PERL} -pi -e 's|disable_ipv6=true|disable_ipv6=false|' ${EXIM_CONF}
      fi
    fi
  fi

  verify_exim_keep_env "${OPT_EXIMCONF_RELEASE}"

  ## Todo:
  ${WGET} ${WGET_CONNECT_OPTIONS} -O "${EXIM_PATH}/exim.pl.cb20" "http://${DOWNLOADSERVER_OPT}/services/exim.pl.${EXIM_PL_VER}"

  if [ -s "${EXIM_PATH}/exim.pl.cb20" ]; then
    mv -f "${EXIM_PATH}/exim.pl.cb20" "${EXIM_PATH}/exim.pl"
  else
    rm -f ${EXIM_PATH}/exim.pl.cb20
    printf "*** Error: Download of exim.pl failed\n"
  fi

  ${CHMOD} 755 "${EXIM_PATH}/exim.pl"

  if [ ! -e /etc/virtual/limit ]; then
    printf "/etc/virtual/limit not found. Creating it with a value of 0.\n"
    printf "0\n" > /etc/virtual/limit
    ${CHOWN} "${EXIM_USER}:${EXIM_GROUP}" /etc/virtual/limit
  fi

  if [ ! -d /etc/virtual/usage ]; then
    printf "/etc/virtual/usage not found. Creating...\n"
    ${MKDIR} -p /etc/virtual/usage
    ${CHOWN} "${EXIM_USER}:${EXIM_GROUP}" /etc/virtual/usage
  fi

  ## Verify Exim File (from CB2: doEnsureEximFile())
  exim_verify_file() {
    if [ "$1" != "" ]; then
      if [ ! -e "${1}" ]; then
        printf "Creating file: %s\n" "${1}"
        ${TOUCH} "${1}"
        ${CHOWN} "${EXIM_USER}:${EXIM_GROUP}" "${1}"
        ${CHMOD} 600 "${1}"
      fi
    fi
  }

  exim_verify_file /etc/virtual/bad_sender_hosts
  exim_verify_file /etc/virtual/bad_sender_hosts_ip
  exim_verify_file /etc/virtual/blacklist_domains
  exim_verify_file /etc/virtual/blacklist_senders
  exim_verify_file /etc/virtual/whitelist_domains
  exim_verify_file /etc/virtual/whitelist_hosts
  exim_verify_file /etc/virtual/whitelist_hosts_ip
  exim_verify_file /etc/virtual/whitelist_senders
  exim_verify_file /etc/virtual/use_rbl_domains
  exim_verify_file /etc/virtual/skip_av_domains
  exim_verify_file /etc/virtual/skip_rbl_domains
  exim_verify_file /etc/virtual/blacklist_smtp_usernames
  exim_verify_file /etc/virtual/blacklist_script_usernames

  ## PB: Old version of exim.conf
  # if [ "${OPT_DOVECOT}" = "YES" ] && [ "${OPT_EXIMCONF_RELEASE}" = "2.1" ]; then
  #   cd ${PB_PATH} || exit
  #   if [ -e exim.conf.dovecot.patch ]; then
  #     ${PATCH} -d/ -p0 < exim.conf.dovecot.patch
  #   fi
  # fi

  if [ "${OPT_PIGEONHOLE}" = "YES" ]; then
    cd ${PB_PATH} || exit
    if [ "${OPT_EXIMCONF_RELEASE}" = "2.1" ]; then
      ## Todo: getFile patches/exim.conf.pigeonhole.patch eximpigeonholepatch
      cd ${EXIM_PATH} || exit
      ${PATCH} -p0 < ${PB_PATCHES}/exim.conf.pigeonhole.patch
      cd ${PB_PATH} || exit
    else
      ${PERL} -pi -e 's#transport = virtual_localdelivery#transport = dovecot_lmtp_udp#' ${EXIM_CONF}
    fi
  else
    #we have LMTP enabled by default for 4.3+
    if [ "${OPT_EXIMCONF_RELEASE}" = "2.1" ] || [ "${OPT_EXIMCONF_RELEASE}" = "4.2" ]; then
      ${PERL} -pi -e 's#transport = dovecot_lmtp_udp#transport = virtual_localdelivery#' ${EXIM_CONF}
    fi
  fi

  if [ "${OPT_BLOCKCRACKING}" = "YES" ]; then
    blockcracking_install norestart
  else
    rm -rf "${EXIM_PATH}/bc"
  fi

  if [ "${OPT_EASY_SPAM_FIGHTER}" = "YES" ]; then
    easyspamfighter_install norestart
  else
    rm -rf "${EXIM_PATH}/esf"
  fi

  if [ "${OPT_SPAMASSASSIN}" = "YES" ]; then
    ${PERL} -pi -e 's|#.include_if_exists ${EXIM_PATH}/exim.spamassassin.conf|.include_if_exists ${EXIM_PATH}/exim.spamassassin.conf|' ${EXIM_CONF}
    if [ ! -s "${EXIM_PATH}/exim.spamassassin.conf" ]; then
      ${WGET} ${WGET_CONNECT_OPTIONS} -O "${EXIM_PATH}/exim.spamassassin.conf" "http://${PB_MIRROR}/services/exim.spamassassin.conf"
    fi
  else
    rm -f "${EXIM_PATH}/exim.spamassassin.conf"
  fi

  ## ClamAV+Exim
  if [ "${OPT_CLAMAV_EXIM}" = "YES" ] && [ "${OPT_CLAMAV}" = "YES" ]; then
    ${PERL} -pi -e 's|#.include_if_exists ${EXIM_PATH}/exim.clamav.load.conf|.include_if_exists ${EXIM_PATH}/exim.clamav.load.conf|' ${EXIM_CONF}
    ${PERL} -pi -e 's|#.include_if_exists ${EXIM_PATH}/exim.clamav.conf|.include_if_exists ${EXIM_PATH}/exim.clamav.conf|' ${EXIM_CONF}
    if [ "${OPT_CLAMAV_EXIM}" = "YES" ]; then
      if [ ! -s "${EXIM_PATH}/exim.clamav.load.conf" ]; then
        ${WGET} ${WGET_CONNECT_OPTIONS} -O "${EXIM_PATH}/exim.clamav.load.conf" http://${PB_MIRROR}/services/exim.clamav.load.conf
      fi
      if [ ! -s "${EXIM_PATH}/exim.clamav.conf" ]; then
        ${WGET} ${WGET_CONNECT_OPTIONS} -O "${EXIM_PATH}/exim.clamav.conf" http://${PB_MIRROR}/services/exim.clamav.conf
      fi
    fi
  else
    rm -f "${EXIM_PATH}/exim.clamav.load.conf"
    rm -f "${EXIM_PATH}/exim.clamav.conf"
  fi

  exim_restart

  COUNT_LMTP=0
  if [ -e ${EXIM_CONF} ]; then
    COUNT_LMTP=$(grep -c 'transport = dovecot_lmtp_udp' ${EXIM_CONF})
  fi

  if [ ! -e "${DOVECOT_PATH}/conf/lmtp.conf" ] && [ "${COUNT_LMTP}" = "1" ] && [ -e ${DOVECOT_CONF} ]; then
    if ! grep -q 'protocol lmtp' ${DOVECOT_CONF}; then
      printf "WARNING: make sure you have LMTP enabled in dovecot.conf, './build dovecot_conf' should fix it.\n"
    fi
  fi

  return
}

################################################################################
## SpamAssassin Installation Tasks
################################################################################

spamassassin_install() {

  if [ "${OPT_SPAMASSASSIN}" != "YES" ]; then
    printf "*** Notice: SpamAssassin not enabled in options.conf\n"
    return
  fi

  printf "Installing SpamAssassin optional and required Perl modules first\n"

  pkgi security/p5-Digest-SHA1 net/p5-Geo-IP net/p5-Net-CIDR-Lite \
  mail/razor-agents net/p5-IO-Socket-INET6 \
  www/p5-LWP-UserAgent-WithCache net/p5-Net-Patricia \
  mail/p5-Mail-DKIM mail/p5-Mail-SPF
  # pkgi www/p5-LWP-UserAgent-Determined

  printf "Starting SpamAssassin installation\n"

  ### Main Installation
  if [ -z "${SPAMASSASSIN_MAKE_SET}" ] && [ -z "${SPAMASSASSIN_MAKE_UNSET}" ]; then
    pkgi ${PORT_SPAMASSASSIN}
  else
    ${MAKE} -DNO_DIALOG -C "${PORTS_BASE}/${PORT_SPAMASSASSIN}" rmconfig
    ${MAKE} -DNO_DIALOG -C "${PORTS_BASE}/${PORT_SPAMASSASSIN}" \
    mail_spamassassin_SET="${SPAMASSASSIN_MAKE_SET}" \
    mail_spamassassin_UNSET="${SPAMASSASSIN_MAKE_UNSET}" \
    OPTIONS_SET="${GLOBAL_MAKE_SET}" \
    OPTIONS_UNSET="${GLOBAL_MAKE_UNSET}" \
    reinstall clean
  fi

  ${SYSRC} spamd_enable="YES"
  ${SYSRC} spamd_flags="-c -m 15"

  ${SERVICE} sa-spamd start

  ## Update rules via 'sa-update' (or using sa-utils):
  # sa-update

  return
}

################################################################################
## Todo: SpamAssassin Upgrade
################################################################################

spamassassin_upgrade() {

  printf "Upgrading SpamAssassin\n"

  if [ -z "${SPAMASSASSIN_MAKE_SET}" ] && [ -z "${SPAMASSASSIN_MAKE_UNSET}" ]; then
    pkgu "${PORT_SPAMASSASSIN}"
  else
    ${MAKE} -DNO_DIALOG -C "${PORTS_BASE}/${PORT_SPAMASSASSIN}" rmconfig
    ${MAKE} -DNO_DIALOG -C "${PORTS_BASE}/${PORT_SPAMASSASSIN}" \
    mail_spamassassin_SET="${SPAMASSASSIN_MAKE_SET}" \
    mail_spamassassin_UNSET="${SPAMASSASSIN_MAKE_UNSET}" \
    OPTIONS_SET="${GLOBAL_MAKE_SET}" \
    OPTIONS_UNSET="${GLOBAL_MAKE_UNSET}" \
    reinstall clean
  fi

  ${SERVICE} sa-spamd restart

  return
}

################################################################################
## Uninstall SpamAssassin
################################################################################

spamassassin_uninstall() {

  printf "Uninstalling SpamAssassin\n"

  ${SERVICE} sa-spamd stop

  ${SYSRC} -q -x spamd_enable
  ${SYSRC} -q -x spamd_flags

  pkgd ${PORT_SPAMASSASSIN}

  spamassassin_utilities_uninstall

  return
}

################################################################################
## SpamAssassin Utilities Installation Tasks
################################################################################

spamassassin_utilities_install() {

  if [ "${OPT_SPAMASSASSIN}" != "YES" ]; then
    printf "*** Notice: SpamAssassin not enabled in options.conf\n"
    return
  fi

  printf "Starting SpamAssassin Utilities installation\n"

  ### Main Installation
  if [ -z "${SPAMASSASSIN_UTILITIES_MAKE_SET}" ] && [ -z "${SPAMASSASSIN_UTILITIES_MAKE_UNSET}" ]; then
    pkgi "${PORT_SPAMASSASSIN_UTILITIES}"
  else
    ${MAKE} -DNO_DIALOG -C "${PORTS_BASE}/${PORT_SPAMASSASSIN_UTILITIES}" rmconfig
    ${MAKE} -DNO_DIALOG -C "${PORTS_BASE}/${PORT_SPAMASSASSIN_UTILITIES}" \
    mail_sa-utils_SET="${SPAMASSASSIN_UTILITIES_MAKE_SET}" \
    mail_sa-utils_UNSET="${SPAMASSASSIN_UTILITIES_MAKE_UNSET}" \
    OPTIONS_SET="${GLOBAL_MAKE_SET}" \
    OPTIONS_UNSET="${GLOBAL_MAKE_UNSET}" \
    reinstall clean
  fi

  printf "Updating /etc/periodic.conf\n"
  ${SYSRC} -f /etc/periodic.conf daily_sa_enable="YES"
  ${SYSRC} -f /etc/periodic.conf daily_sa_quiet="NO"
  ${SYSRC} -f /etc/periodic.conf daily_sa_compile_nice="YES"
  ${SYSRC} -f /etc/periodic.conf daily_sa_restart_spamd="YES"
  # daily_sa_update_flags="" ## -D --nogpg
  # daily_sa_compile_flags=""
  # daily_sa_compile_nice_flags=""

  return
}

################################################################################
## Uninstall SpamAssassin Utilities
################################################################################

spamassassin_utilities_uninstall() {

  printf "Uninstalling SpamAssassin Utilities\n"

  ${SYSRC} -q -f /etc/periodic.conf -x daily_sa_enable
  ${SYSRC} -q -f /etc/periodic.conf -x daily_sa_quiet
  ${SYSRC} -q -f /etc/periodic.conf -x daily_sa_compile_nice
  ${SYSRC} -q -f /etc/periodic.conf -x daily_sa_restart_spamd
  ${SYSRC} -q -f /etc/periodic.conf -x daily_sa_update_flags
  ${SYSRC} -q -f /etc/periodic.conf -x daily_sa_compile_flags
  ${SYSRC} -q -f /etc/periodic.conf -x daily_sa_compile_nice_flags

  pkgd "${PORT_SPAMASSASSIN_UTILITIES}"

  return
}

################################################################################
## Todo: Install Exim BlockCracking (BC)
################################################################################

blockcracking_install() {

  if [ -x "${EXIM_BIN}" ]; then

    printf "Setting up BlockCracking for Exim\n"

    cp -fp "${PB_CONFIG}/exim/bc/*" "${EXIM_BC_PATH}/"

    ## used to include: -${BLOCKCRACKING_VER}

    ### Downloaded version:
    ## used to include: -${BLOCKCRACKING_VER}
    # ${WGET} -O "${PB_PATH}/files/exim.blockcracking.tar.gz" "${PB_MIRROR}/files/exim.blockcracking.tar.gz"

    # if [ -e "${PB_PATH}/files/exim.blockcracking.tar.gz" ]; then
    #   mkdir -p ${EXIM_BC_PATH}

    #   printf "Extracting exim.blockcracking.tar.gz\n"
    #   ${TAR} xvf "${PB_PATH}/files/exim.blockcracking.tar.gz" -C ${EXIM_BC_PATH}

    #   BC_DP_SRC=${EXIM_BC_PATH}/script.denied_paths.default.txt

    #   if [ -e "${EXIM_BC_PATH}/script.denied_paths.custom.txt" ]; then
    #     printf "Using custom BlockCracking script.denied_paths.custom.txt\n"
    #     BC_DP_SRC="${EXIM_BC_PATH}/script.denied_paths.custom.txt"
    #   fi

    #   cp -fp ${BC_DP_SRC} ${EXIM_BC_PATH}/script.denied_paths.txt

    #   exim_restart

    #   printf "BlockCracking is now enabled.\n"
    # else
    #   printf "*** Error: Unable to find exim.blockcracking.tar.gz for extraction. Aborting.\n"
    #   exit 1
    # fi
  else
    printf "*** Error: Exim is not installed. Cannot continue as the binary was not found.\n"
  fi

  return
}

################################################################################
## Todo: Install Easy Spam Figter (ESF)
################################################################################

easyspamfighter_install() {

  local EXIM_SPF_SUPPORT EXIM_SRS_SUPPORT

  if [ -x ${EXIM_BIN} ]; then
    ## See if SPF and SRS has been compiled in:
    EXIM_SPF_SUPPORT="$(${EXIM_BIN} --version | grep -m1 -c SPF)"
    EXIM_SRS_SUPPORT="$(${EXIM_BIN} --version | grep -m1 -c SRS)"

    if [ "${EXIM_SPF_SUPPORT}" = "0" ]; then
      printf "*** Error: Your version of Exim does not support SPF. This is needed for Easy Spam Fighter.\n"
      printf "Please reinstall Exim with SPF support.\n"
      exit 1
    fi

    if [ "${EXIM_SRS_SUPPORT}" = "0" ]; then
      printf "*** Error: Your version of Exim does not support SRS. This is needed for Easy Spam Fighter.\n"
      printf "Please reinstall Exim with SRS support.\n"
      exit 1
    fi

    ## Check exim.conf version
    # if [ "${OPT_EXIMCONF_RELEASE}" = "2.1" ] || [ "${OPT_EXIMCONF_RELEASE}" = "4.2" ]; then
    #   echo "WARNING: Your exim.conf version might be incompatible with Easy Spam Fighter.""
    #   echo "Please make sure that your exim.conf release is 4.3 or higher."
    # fi

    ## ESF work directry under portsbuild/
    # if [ ! -d ${PB_CONFIG}/exim/esf ]; then
    #   mkdir -p ${PB_CONFIG}/exim/esf
    #   chmod 700 ${PB_CONFIG}/exim/esf
    # fi

    # cd ${PB_PATH} || exit

    ## Download ESF files
    # getFile easy_spam_fighter/exim.easy_spam_fighter-${EASY_SPAM_FIGHTER_VER}.tar.gz \
    # easy_spam_figther exim.easy_spam_fighter-${EASY_SPAM_FIGHTER_VER}.tar.gz

    ## Todo: grab latest version
    ${WGET} -O "${PB_PATH}/files/esf.tar.gz" "${PB_MIRROR}/files/esf.tar.gz"

    if [ -e "${PB_PATH}/files/esf.tar.gz" ]; then

      ## path was: ${EXIM_PATH}/exim.easy_spam_fighter
      mkdir -p "${EXIM_ESF_PATH}"

      printf "Extracting Easy Spam Fighter\n"
      ${TAR} xvf "${PB_PATH}/files/esf.tar.gz" -C "${EXIM_ESF_PATH}"

      exim_restart

      printf "Easy Spam Fighter is now enabled.\n"
    else
      printf "*** Error: Unable to find esf.tar.gz for extraction. Aborting.\n"
      # exit 1
    fi
  else
    printf "*** Error: Exim is not installed. Cannot continue as the binary was not found.\n"
    exit 1
  fi

  return
}

################################################################################
## Dovecot2 Installation
################################################################################

dovecot_install() {

  local DOVECOT_CHECK QUOTA_COUNT COUNT_TEMPLATE

  if [ "${OPT_DOVECOT}" != "YES" ]; then
    printf "*** Notice: DOVECOT is not enabled in options.conf\n"
    return
  fi

  ## Todo:
  ## 2016-03-26: Check to see if we need to convert instead of a fresh install

  DOVECOT_CHECK=0
  if [ -e "${DA_CONF}" ]; then
    DOVECOT_CHECK="$(grep -m1 -c -e '^dovecot=1' ${DA_CONF})"
  fi

  if [ "${DOVECOT_CHECK}" -eq 0 ] || [ ! -e "${DA_CONF}" ]; then
    setVal dovecot 1 ${DA_CONF_TEMPLATE}
  fi

  if [ "${DOVECOT_CHECK}" -eq 0 ] || [ ! -e "${DA_CONF}" ]; then
     printf "Converting to Dovecot\n"

    #   ## PB: Verify: moved contents of function below
    #   # convertToDovecot
    #
    #   ## CB2: Patch exim.conf
    #   if [ -e "${EXIM_CONF}" ] && [ "$(grep -m1 -c maildir_format ${EXIM_CONF})" -eq 0 ]; then
    #     echo "To Dovecot: Patching /etc/exim.conf to maildir"
    #     ## Verify: patch -d/ -p0 < ${PB_PATH}/patches/exim.conf.dovecot.patch
    #   fi

    ## Existing installs
    if [ -e "${DA_CONF}" ]; then
      if ! grep -m1 -q -e '^dovecot=1' ${DA_CONF}; then
        # printf "Adding dovecot=1 to %s" "${DA_CONF}"
        setVal dovecot 1 ${DA_CONF}
        set_service dovecot ON
        directadmin_restart
      fi
    fi

    ## Existing + New installs
    if [ -e "${DA_CONF_TEMPLATE}" ]; then
      if ! grep -m1 -q -e '^dovecot=1' ${DA_CONF_TEMPLATE}; then
        # printf "Adding dovecot=1 to template %s" "${DA_CONF_TEMPLATE}"
        setVal dovecot 1 ${DA_CONF_TEMPLATE}
        set_service dovecot ON
      fi
    fi

    # ${SERVICE} directadmin restart
    # ${SERVICE} exim restart
    # ${PERL} -pi -e 's/^imap/#imap/' /etc/inetd.conf
    # killall -HUP inetd
    # /usr/local/etc/rc.dv/m-pop3d stop

    # grep -v vm-pop3d /usr/local/etc/rc.d/boot.sh > /usr/local/etc/rc.d/boot.sh.new
    # mv -f /usr/local/etc/rc.d/boot.sh /usr/local/etc/rc.d/boot.sh.old
    # mv -f /usr/local/etc/rc.d/boot.sh.new /usr/local/etc/rc.d/boot.sh
    # chmod 755 /usr/local/etc/rc.d/boot.sh

    # printf "Adding conversion command to the Task Queue\n"
    # echo "action=convert&value=todovecot" >> ${DA_TASK_QUEUE}
    # printf "Executing the Task Queue contents now, please wait...\n"
    # run_dataskq d

    # printf "Restarting Dovecot\n"
    # dovecot_restart

    # printf "Restarting Exim\n"
    # exim_restart

    # printf "Dovecot conversion completed.\n"
  fi

  printf "Starting Dovecot installation\n"

  ### Main Installation
  if [ -z "${DOVECOT2_MAKE_SET}" ] && [ -z "${DOVECOT2_MAKE_UNSET}" ]; then
    pkgi ${PORT_DOVECOT2}
  else
    ${MAKE} -DNO_DIALOG -C "${PORTS_BASE}/${PORT_DOVECOT2}" rmconfig
    ${MAKE} -DNO_DIALOG -C "${PORTS_BASE}/${PORT_DOVECOT2}" \
    mail_dovecot2_SET="${DOVECOT2_MAKE_SET}" \
    mail_dovecot2_UNSET="${DOVECOT2_MAKE_UNSET}" \
    OPTIONS_SET="${GLOBAL_MAKE_SET}" \
    OPTIONS_UNSET="${GLOBAL_MAKE_UNSET}" \
    reinstall clean
  fi

  ## Update directadmin.conf:
  QUOTA_COUNT=0
  if [ -e "${DA_CONF}" ]; then
    QUOTA_COUNT="$(grep -m1 -c -e '^add_userdb_quota=1' ${DA_CONF})"
    if [ "${QUOTA_COUNT}" = "0" ]; then
      # printf "Adding add_userdb_quota=1 to the %s file to enable Dovecot quota support\n" ${DA_CONF}
      setVal add_userdb_quota 1 ${DA_CONF}
      directadmin_restart
      echo "action=rewrite&value=email_passwd" >> ${DA_TASK_QUEUE}
      run_dataskq d
    fi
  fi

  ## Update directadmin.conf (template):
  COUNT_TEMPLATE="$(grep -m1 -c -e '^add_userdb_quota=1' ${DA_CONF_TEMPLATE})"
  if [ "${COUNT_TEMPLATE}" = "0" ] && [ -e "${DA_CONF_TEMPLATE}" ]; then
    # echo "Adding add_userdb_quota=1 to the ${DA_CONF_TEMPLATE} (template) file"
    setVal add_userdb_quota 1 ${DA_CONF_TEMPLATE}
  fi

  ## Prepare Dovecot directories:
  if [ ! -d "${DOVECOT_PATH}" ]; then
    ${MKDIR} -p ${DOVECOT_PATH}
  fi

  if [ ! -d "${DOVECOT_PATH}/conf" ]; then
    ${MKDIR} -p "${DOVECOT_PATH}/conf"
  fi

  if [ ! -d "${DOVECOT_PATH}/conf.d" ]; then
    ${MKDIR} -p "${DOVECOT_PATH}/conf.d"
  fi

  ## Copy default configuration files:
  cp -rf "${PB_CONFIG}/dovecot/conf" "${DOVECOT_PATH}/conf"
  cp -rf "${PB_CONFIG}/dovecot/conf.d" "${DOVECOT_PATH}/conf.d"

  ## Setup config:
  if [ -e "${PB_CONFIG}/dovecot/dovecot.conf" ]; then
    cp -f "${PB_CONFIG}/dovecot/dovecot.conf" ${DOVECOT_CONF}
  # else
   # ${WGET} -O ${DOVECOT_CONF} http://files.directadmin.com/services/custombuild/dovecot.conf.2.0
  fi

  if [ "${COMPAT_DOVECOT_SYMLINKS}" = "YES" ]; then
    ## Symlink for compat:
    ${MKDIR} -p /etc/dovecot
    ln -s ${DOVECOT_CONF} "/etc/dovecot/dovecot.conf"
    ## Skipped: ln -s /etc/dovecot/dovecot.conf /etc/dovecot.conf
  fi

  #cp -f ${PB_CONFIG}/dovecot/conf.d/90-quote.conf ${DOVECOT_PATH}/conf.d/90-quota.conf

  ## Todo: PigeonHole:
  if [ "${OPT_PIGEONHOLE}" = "YES" ]; then
    ## Todo: Install PigeonHole:
    pigeonhole_install

    ${PERL} -pi -e 's#transport = virtual_localdelivery#transport = dovecot_lmtp_udp#' ${EXIM_CONF}

    cp -f "${PB_CONFIG}/dovecot/conf.d/90-sieve.conf" "${DOVECOT_PATH}/conf.d/90-sieve.conf"
    printf "protocols = imap pop3 lmtp sieve\n" > ${DOVECOT_PATH}/conf/protocols.conf
    printf "mail_plugins = \$mail_plugins quota sieve\n" > ${DOVECOT_PATH}/conf/lmtp_mail_plugins.conf
  else
    rm -f "${DOVECOT_PATH}/conf.d/90-sieve.conf"
    printf "mail_plugins = \$mail_plugins quota\n" > ${DOVECOT_PATH}/conf/lmtp_mail_plugins.conf
  fi

  if [ -e "${DOVECOT_PATH}/conf/lmtp.conf" ]; then
    ${PERL} -pi -e "s|HOSTNAME|$(hostname)|" ${DOVECOT_PATH}/conf/lmtp.conf
  fi

  ${TOUCH} /var/log/dovecot-lmtp.log /var/log/dovecot-lmtp-errors.log
  ${CHOWN} root:wheel /var/log/dovecot-lmtp.log /var/log/dovecot-lmtp-errors.log
  ${CHMOD} 600 /var/log/dovecot-lmtp.log /var/log/dovecot-lmtp-errors.log

  ${PERL} -pi -e 's/driver = shadow/driver = passwd/' ${DOVECOT_CONF}
  ${PERL} -pi -e 's/passdb shadow/passdb passwd/' ${DOVECOT_CONF}

  printf "mail_plugins = \$mail_plugins quota\n"            > ${DOVECOT_PATH}/conf/mail_plugins.conf
  printf "mail_plugins = \$mail_plugins quota imap_quota\n" > ${DOVECOT_PATH}/conf/imap_mail_plugins.conf

  ## Check for IPV6 compatibility:
  if [ "${IPV6}" = "1" ]; then
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
    echo "ssl_cert = <${CUSTOM_SSL_CRT}" > "${DOVECOT_PATH}/conf/ssl.conf"
    echo "ssl_key = <${CUSTOM_SSL_KEY}" >> "${DOVECOT_PATH}/conf/ssl.conf"
  else
    ## (not done) Create self-signed certs just for Dovecot:
    echo "ssl_cert = <${DOVECOT_SSL_CRT}" > "${DOVECOT_PATH}/conf/ssl.conf"
    echo "ssl_key = <${DOVECOT_SSL_KEY}" >> "${DOVECOT_PATH}/conf/ssl.conf"
  fi

  printf "ssl_protocols = !SSLv2 !SSLv3\n" >> "${DOVECOT_PATH}/conf/ssl.conf"
  printf "ssl_cipher_list = ALL:!ADH:RC4+RSA:+HIGH:+MEDIUM:-LOW:-SSLv2:-EXP\n" >> "${DOVECOT_PATH}/conf/ssl.conf"

  freebsd_set_newsyslog "${LOGS}/dovecot-lmtp-errors.log" root:wheel
  freebsd_set_newsyslog "${LOGS}/dovecot-lmtp.log" root:wheel

  ## PB: vm-pop3d is no longer needed (part of CB2's convertToDovecot())
  set_service vm-pop3d delete

  ## Disable da-popb4smtp
  set_service da-popb4smtp OFF

  printf "Enabling Dovecot startup (upating /etc/rc.conf)\n"
  ${SYSRC} dovecot_enable="YES"

  dovecot_restart

  return
}

################################################################################
## Dovecot Configuration (from CB: doDovecotConf())
################################################################################

dovecot_config() {

  local COUNT COUNT_TEMPLATE

  if [ "${OPT_DOVECOT_CONF}" != "yes" ]; then
    printf "*** NOtice: You cannot update Dovecot configuration files, because you do not have it set in options.conf.\n"
  fi

  printf "Updating Dovecot configuration files...\n"

  ## CB2: Enable dovecot quota by default
  COUNT=0
  if [ -e "${DA_CONF}" ]; then
    COUNT="$(grep -m1 -c -e '^add_userdb_quota=1' ${DA_CONF})"
  fi

  if [ "${COUNT}" = "0" ] && [ -e ${DA_CONF} ]; then
    #echo "Adding add_userdb_quota=1 to the ${DA_CONF} file to enable dovecot quota..."
    printf "add_userdb_quota=1\n" >> ${DA_CONF}
    directadmin_restart
    echo "action=rewrite&value=email_passwd" >> ${DA_TASK_QUEUE}
    run_dataskq d
  fi

  COUNT_TEMPLATE="$(grep -m1 -c -e '^add_userdb_quota=1' ${DA_CONF_TEMPLATE})"
  if [ "${COUNT_TEMPLATE}" = "0" ] && [ -e "${DA_CONF_TEMPLATE}" ]; then
    #echo "Adding add_userdb_quota=1 to the ${DACONF_TEMPLATE_FILE} (template) file ..."
    printf "add_userdb_quota=1\n" >> "${DA_CONF_TEMPLATE}"
  fi

  if [ ! -d "${DOVECOT_PATH}/conf" ]; then
    ${MKDIR} -p "${DOVECOT_PATH}/conf"
  fi

  if [ ! -d "${DOVECOT_PATH}/conf.d" ]; then
    ${MKDIR} -p "${DOVECOT_PATH}/conf.d"
  fi

  cp -rf ${DOVECOTCONFDIR} ${DOVECOT_PATH}

  if [ "${IPV6}" = "1" ]; then
    printf "listen = *, ::\n" > "${DOVECOT_PATH}/conf/ip.conf"
  fi

  ## Verify:
  if [ "${DOVECOTCUSTOMCONFDIR}" != "0" ]; then
    cp -rf ${DOVECOTCUSTOMCONFDIR} ${DOVECOT_PATH}/
  fi

  cp -f ${DOVECTCONFFILE} ${DOVECOT_CONF}
  cp -f ${DOVECTCONFQUOTA} "${DOVECOT_PATH}/conf.d/90-quota.conf"

  if [ "${OPT_PIGEONHOLE}" = "YES" ]; then
    cp -f ${DOVECTCONFSIEVE} "${DOVECOT_PATH}/conf.d/90-sieve.conf"
    printf "protocols = imap pop3 lmtp sieve\n" > "${DOVECOT_PATH}/conf/protocols.conf"
    printf "mail_plugins = \$mail_plugins quota sieve\n" > "${DOVECOT_PATH}/conf/lmtp_mail_plugins.conf"
  else
    rm -f "${DOVECOT_PATH}/conf.d/90-sieve.conf"
    printf "mail_plugins = \$mail_plugins quota\n" > "${DOVECOT_PATH}/conf/lmtp_mail_plugins.conf"
  fi
  if [ -e "${DOVECOT_PATH}/conf/lmtp.conf" ]; then
    ${PERL} -pi -e "s|HOSTNAME|$(hostname)|" "${DOVECOT_PATH}/conf/lmtp.conf"
  fi

  # if [ ! -L /usr/local/etc/dovecot.conf ]; then
  #   mv -f /usr/local/etc/dovecot.conf /usr/local/etc/dovecot.conf.old
  #   ln -s /etc/dovecot/dovecot.conf /usr/local/etc/dovecot.conf
  # fi

  # DC="${DOVECOT_PATH}/dovecot.conf"
  # if [ -L ${DOVECOT_PATH}/dovecot.conf ]; then
  #   DC=${DOVECOT_PATH}/dovecot.conf
  # fi

  ${PERL} -pi -e 's/driver = shadow/driver = passwd/' ${DOVECOT_CONF}
  ${PERL} -pi -e 's/passdb shadow/passdb passwd/' ${DOVECOT_CONF}

  printf "mail_plugins = \$mail_plugins quota\n" > "${DOVECOT_PATH}/conf/mail_plugins.conf"
  printf "mail_plugins = \$mail_plugins quota imap_quota\n" > "${DOVECOT_PATH}/conf/imap_mail_plugins.conf"

  #If customized configs - overwrite existing ones, which we modified above
  if [ "${DOVECOTCUSTOMCONFDIR}" != "0" ]; then
    if [ -e ${DOVECOTCUSTOMCONFDIR}/protocols.conf ]; then
      cp -f ${DOVECOTCUSTOMCONFDIR}/protocols.conf "${DOVECOT_PATH}/conf/protocols.conf"
    fi
    if [ -e ${DOVECOTCUSTOMCONFDIR}/lmtp_mail_plugins.conf ]; then
      cp -f ${DOVECOTCUSTOMCONFDIR}/lmtp_mail_plugins.conf "${DOVECOT_PATH}/conf/lmtp_mail_plugins.conf"
    fi
    if [ -e ${DOVECOTCUSTOMCONFDIR}/mail_plugins.conf ]; then
      cp -f ${DOVECOTCUSTOMCONFDIR}/mail_plugins.conf "${DOVECOT_PATH}/conf/mail_plugins.conf"
    fi
    if [ -e ${DOVECOTCUSTOMCONFDIR}/imap_mail_plugins.conf ]; then
      cp -f ${DOVECOTCUSTOMCONFDIR}/imap_mail_plugins.conf "${DOVECOT_PATH}/conf/imap_mail_plugins.conf"
    fi
    if [ -e ${DOVECOTCUSTOMCONFDIR}/lmtp.conf ]; then
      cp -f ${DOVECOTCUSTOMCONFDIR}/lmtp.conf "${DOVECOT_PATH}/conf/lmtp.conf"
    fi
  fi

  if [ "$1" != "norestart" ]; then
    # echo "Restarting dovecot."
    control_service dovecot restart
  fi

  printf "Dovecot configuration files have been updated successfully.\n"

  return
}

################################################################################
## Dovecot Restart with configuration file verification
################################################################################

dovecot_restart() {

  ${DOVECOT_BIN} -c ${DOVECOT_CONF}

  if [ $? = "0" ]; then
    printf "Restarting Dovecot\n"
    ${SERVICE} dovecot restart
  else
    printf "*** Warning: Aborting automatic Dovecot restart due to configuration verification failure.\n"
    printf "Please verify the Dovecot configuration file at: %s\n" ${DOVECOT_CONF}
    printf "You can verify the file by typing:\n"
    printf "  %s -c %s\n\n" ${DOVECOT_BIN} ${DOVECOT_CONF}
    printf "You can restart Dovecot manually by typing:\n"
    printf "  service dovecot restart\n"
  fi

  return

}

################################################################################
## Dovecot Uninstall
################################################################################

dovecot_uninstall() {

  printf "Uninstalling Dovecot\n"

  ${SERVICE} dovecot stop

  ${SYSRC} -q -x dovecot_enable

  pkgd "${PORT_DOVECOT2}"

  return
}

################################################################################
## Todo: Pigeonhole Installation
################################################################################

pigeonhole_install() {

  if [ "${OPT_PIGEONHOLE}" != "YES" ]; then
    printf "*** Notice: Pigeonhole not enabled in options.conf\n"
    return
  fi

  printf "Starting Pigeonhole installation\n"

  ### Main Installation
  if [ -z "${PIGEONHOLE_MAKE_SET}" ] && [ -z "${PIGEONHOLE_MAKE_UNSET}" ]; then
    pkgi ${PORT_WEBALIZER}
  else
    ${MAKE} -DNO_DIALOG -C "${PORTS_BASE}/${PORT_PIGEONHOLE}" rmconfig
    ${MAKE} -DNO_DIALOG -C "${PORTS_BASE}/${PORT_PIGEONHOLE}" \
    mail_dovecot2_pigeonhole_SET="${PIGEONHOLE_MAKE_SET}" \
    mail_dovecot2_pigeonhole_UNSET="${PIGEONHOLE_MAKE_UNSET}" \
    OPTIONS_SET="${GLOBAL_MAKE_SET}" \
    OPTIONS_UNSET="${GLOBAL_MAKE_UNSET}" \
    reinstall clean
  fi

  return
}

################################################################################
## Todo: Webalizer Installation
################################################################################

webalizer_install() {

  if [ "${OPT_WEBALIZER}" != "YES" ]; then
    printf "*** Notice: Webalizer not enabled in options.conf\n"
    return
  fi

  printf "Starting Webalizer installation\n"

  ### Main Installation
  if [ -z "${WEBALIZER_MAKE_SET}" ] && [ -z "${WEBALIZER_MAKE_UNSET}" ]; then
    pkgi ${PORT_WEBALIZER}
  else
    ${MAKE} -DNO_DIALOG -C "${PORTS_BASE}/${PORT_WEBALIZER}" rmconfig
    ${MAKE} -DNO_DIALOG -C "${PORTS_BASE}/${PORT_WEBALIZER}" \
    www_webalizer_SET="${WEBALIZER_MAKE_SET}" \
    www_webalizer_UNSET="${WEBALIZER_MAKE_UNSET}" \
    OPTIONS_SET="${GLOBAL_MAKE_SET}" \
    OPTIONS_UNSET="${GLOBAL_MAKE_UNSET}" \
    reinstall clean
  fi

  if [ "${OPT_AWSTATS}" = "NO" ]; then
    setVal awstats 0 ${DA_CONF_TEMPLATE}
    setVal awstats 0 ${DA_CONF}
  else
    setVal awstats 1 ${DA_CONF_TEMPLATE}
    setVal awstats 1 ${DA_CONF}
  fi

  directadmin_restart

  if [ -e /etc/webalizer.conf ]; then
    mv -f /etc/webalizer.conf /etc/webalizer.conf.moved 2> /dev/null > /dev/null
  fi

  return
}

################################################################################
## Todo: AwStats Installation
################################################################################

awstats_install() {

  if [ "${OPT_AWSTATS}" != "YES" ]; then
    printf "*** Notice: Awstats not enabled in options.conf\n"
    return
  fi

  printf "Starting AwStats installation\n"

  ### Main Installation
  if [ -z "${AWSTATS_MAKE_SET}" ] && [ -z "${AWSTATS_MAKE_UNSET}" ]; then
    pkgi ${PORT_AWSTATS}
  else
    ${MAKE} -DNO_DIALOG -C "${PORTS_BASE}/${PORT_AWSTATS}" rmconfig
    ${MAKE} -DNO_DIALOG -C "${PORTS_BASE}/${PORT_AWSTATS}" \
    www_awstats_SET="${AWSTATS_MAKE_SET}" \
    www_awstats_UNSET="${AWSTATS_MAKE_UNSET}" \
    OPTIONS_SET="${GLOBAL_MAKE_SET}" \
    OPTIONS_UNSET="${GLOBAL_MAKE_UNSET}" \
    reinstall clean
  fi
  ### Post-Installation Tasks

  ## Setup directadmin.conf
  setVal awstats 1 ${DA_CONF_TEMPLATE}
  setVal awstats 1 ${DA_CONF}

  if [ "${OPT_WEBALIZER}" = "NO" ]; then
    setVal webalizer 0 ${DA_CONF_TEMPLATE}
    setVal webalizer 0 ${DA_CONF}
  else
    setVal webalizer 1 ${DA_CONF_TEMPLATE}
    setVal webalizer 1 ${DA_CONF}
  fi

  directadmin_restart

  return
}

################################################################################
## Verify my.cnf (from CB2: verify_my_cnf())
################################################################################

verify_my_cnf() {

  local MY_CNF="$1"
  local SQL_USER="$2"
  local SQL_PASS="$3"
  local SRC_CNF="$4"
  local WRITE_NEW MY_CNF_TS SRC_CNF_TS STAT

  readonly STAT="/usr/bin/stat -f %m"

  ## CB2 Note: SQL server hostname will be on the command line (that's how DA does it).
  ## Update $1 if $4 is newer.

  ## See if file exists and is not zero bytes, else we'll create a new one.
  WRITE_NEW=0
  if [ ! -s "${MY_CNF}" ]; then
    WRITE_NEW=1
  fi

  ## Compare timestamps
  if [ "${WRITE_NEW}" = "0" ] && [ -n "${SRC_CNF}" ]; then
    if [ ! -s "${SRC_CNF}" ]; then
      printf "*** Notice: verify_my_cnf(): Cannot find %s\n" "${SRC_CNF}"
      WRITE_NEW=1
    else
      ## Compare timestamps
      printf "Comparing files %s and %s\n" "${MY_CNF}" "${SRC_CNF}"
      MY_CNF_TS="$(${STAT} ${MY_CNF})"
      SRC_CNF_TS="$(${STAT} ${SRC_CNF})"

      # debug: echo "${MY_CNF_TS} and ${SRC_CNF_TS}"

      if [ "${MY_CNF_TS}" -lt "${SRC_CNF_TS}" ]; then
        printf "*** Notice: Found outdated file: %s\n" "${MY_CNF}"
        printf "*** Notice: Rewriting from file: %s\n" "${SRC_CNF}."
        WRITE_NEW=1
      fi
    fi
  fi

  ## Create new .cnf file
  if [ "${WRITE_NEW}" = "1" ]; then
    {
      printf "[client]\n"
      printf "user=%s\n" "${SQL_USER}"
      printf "password=%s\n" "${SQL_PASS}"
    } > "${MY_CNF}"
    ${CHMOD} 600 "${MY_CNF}"
  fi

  return
}

################################################################################
## Initialize SQL Parameters (from CB2: initMySQL())
################################################################################

get_sql_settings() {

  ## DA_MYSQL=/usr/local/directadmin/conf/mysql.conf
  ## Use: ${DA_MYSQL_CONF}

  sql_prepare

  ## Grab credentials from mysql.conf
  if [ -s "${DA_MYSQL_CONF}" ]; then
    MYSQL_USER=$(grep -m1 "^user=" ${DA_MYSQL_CONF} | cut -d= -f2)
    MYSQL_PASS=$(grep -m1 "^passwd=" ${DA_MYSQL_CONF} | cut -d= -f2)
  ## PB: 2016-05-22: No longer necessary due to sql_prepare()
  # else
  #   MYSQL_USER='da_admin'
  #   MYSQL_PASS='nothing'
  fi

  ## Grab SQL server IP from mysql.conf
  if [ -s "${DA_MYSQL_CONF}" ] && [ "$(grep -m1 -c -e "^host=" ${DA_MYSQL_CONF})" -gt "0" ]; then
    MYSQL_HOST="$(grep -m1 "^host=" ${DA_MYSQL_CONF} | cut -d= -f2)"
  else
    MYSQL_HOST=localhost
  fi

  ## Where connections to MySQL are coming from. Usualy the server IP, unless on a LAN.
  MYSQL_ACCESS_HOST=localhost
  if [ "${MYSQL_HOST}" != "localhost" ]; then
    SERVER_HOSTNAME="$(hostname)"
    MYSQL_ACCESS_HOST="$(grep -r -l -m1 '^status=server$' "${DA_PATH}/data/admin/ips" | cut -d/ -f8)"
    if [ -z "${MYSQL_ACCESS_HOST}" ]; then
      MYSQL_ACCESS_HOST="$(grep -m1 "${SERVER_HOSTNAME}" /etc/hosts | awk '{print $1}')"
      if [ -z "${MYSQL_ACCESS_HOST}" ]; then
        if [ -s "${DA_PATH}/scripts/setup.txt" ]; then
          MYSQL_ACCESS_HOST="$(grep -m1 -e '^ip=' "${DA_PATH}/scripts/setup.txt" | cut -d= -f2)"
        fi
        if [ -z "${MYSQL_ACCESS_HOST}" ]; then
          printf "Unable to detect your server IP in /etc/hosts. Please enter it: "
          read -r MYSQL_ACCESS_HOST
        fi
      fi
    fi
  fi

  verify_my_cnf "${DA_MYSQL_CNF}" "${MYSQL_USER}" "${MYSQL_PASS}" "${DA_MYSQL_CONF}"

  ${CHOWN} diradmin:diradmin "${DA_MYSQL_CNF}"

  return
}

################################################################################
## Prepare SQL DB Settings (first-time installations)
################################################################################

sql_prepare() {

  local SQL_TEMP_FILE NEW_MYSQL_PASS

  ## Note: there are two (2) super SQL users with (potentially different) passwords:
  ## 1) 'root'     + adminpass=  (from: setup.txt)
  ## 2) 'da_admin' + passwd=     (from: mysql.conf/my.cnf)

  ## If first-time installation, create mysql.conf
  if [ ! -s "${DA_MYSQL_CONF}" ]; then
    printf "*** Notice: mysql.conf doesn't exist. Generating a new file.\n"

    ${TOUCH} ${DA_MYSQL_CONF}
    NEW_MYSQL_PASS=$(random_pass)

    ## Add DirectAdmin 'da_admin' SQL database credentials to 'mysql.conf':
    {
      printf "user=%s\n" "${DA_MYSQL_USER}"
      printf "password=%s\n" "${NEW_MYSQL_PASS}"
    } > "${DA_MYSQL_CONF}"

    ${CHOWN} diradmin:diradmin ${DA_MYSQL_CONF}
    ${CHMOD} 400 ${DA_MYSQL_CONF}

    ## Prepare a temporary SQL file with our credentials for import.
    SQL_TEMP_FILE="${PB_PATH}/temp.sql"
    ${TOUCH} "${SQL_TEMP_FILE}"
    ${CHMOD} 600 "${SQL_TEMP_FILE}"
    {
      ## root user password:
      printf "UPDATE mysql.user SET password=PASSWORD('%s') WHERE user='root';\n" "${MYSQL_PASS}"
      printf "UPDATE mysql.user SET password=PASSWORD('%s') WHERE password='';\n" "${MYSQL_PASS}"
      printf "DROP DATABASE IF EXISTS test;\nFLUSH PRIVILEGES;\n"
      ## Add the `da_admin` user to MySQL:
      printf "GRANT CREATE, DROP ON *.* TO %s@%s IDENTIFIED BY '%s' WITH GRANT OPTION;\n" \
      "${MYSQL_USER}" "${MYSQL_ACCESS_HOST}" "${MYSQL_PASS}"
      printf "GRANT ALL PRIVILEGES ON *.* TO %s@%s IDENTIFIED BY '%s' WITH GRANT OPTION;\n" \
      "${MYSQL_USER}" "${MYSQL_ACCESS_HOST}" "${MYSQL_PASS}"
      ## Remove remote root access: (need to add server's current hostname)
      # printf "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');\n"
      ## Drop anonymous users:
      printf "DELETE FROM mysql.user WHERE User='';\n"
      ## Flush and reload privileges:
      printf "FLUSH PRIVILEGES;\n"
    } > "${SQL_TEMP_FILE}"

    ${MYSQL} --user=root < "${SQL_TEMP_FILE}"

    rm -f "${SQL_TEMP_FILE}"
  fi

  return
}

################################################################################
## MariaDB or MySQL Database Installation
################################################################################

sql_install() {

  local DA_MYSQL_PATH

  if [ "${OPT_SQL_DB}" = "NO" ]; then
    printf "*** Notice: OPT_SQL_DB not set in options.conf\n"
    return
  fi

  printf "Starting SQL database installation: %s\n" "${OPT_SQL_DB}"

  set_service "mysql-server" OFF

  case "${OPT_SQL_DB}" in
    "mariadb103") pkgi ${PORT_MARIADB103} ${PORT_MARIADB103_CLIENT} ;;
    "mariadb104") pkgi ${PORT_MARIADB104} ${PORT_MARIADB104_CLIENT} ;;
    "mariadb105") pkgi ${PORT_MARIADB105} ${PORT_MARIADB105_CLIENT} ;;
    "mariadb106") pkgi ${PORT_MARIADB106} ${PORT_MARIADB106_CLIENT} ;;
    "mysql55")    pkgi ${PORT_MYSQL55}    ${PORT_MYSQL55_CLIENT}    ;;
    "mysql56")    pkgi ${PORT_MYSQL56}    ${PORT_MYSQL56_CLIENT}    ;;
    "mysql57")    pkgi ${PORT_MYSQL57}    ${PORT_MYSQL57_CLIENT}    ;;
    "mysql80")    pkgi ${PORT_MYSQL80}    ${PORT_MYSQL80_CLIENT}    ;;
    *) printf "*** Error: Script error at sql_install()\n"; exit    ;;
  esac

  if [ ! -e "${MYSQL}" ]; then
    printf "*** Error: MySQL binary not found at %s\nAborting post-installation tasks." "${MYSQL}"
    err 1 "The MySQL binary was not found."
  fi

  printf "Starting SQL database post-installation tasks\n"

  ## Remove /etc/my.cnf if it exists (not compliant with FreeBSD's hier(7)):
  if [ -e /etc/my.cnf ]; then
    printf "*** Notice: Found an existing my.cnf file in /etc, however this is not recommended.\n"
    printf "*** Notice: Moving /etc/my.cnf to /etc/my.cnf.disabled\n"
    mv /etc/my.cnf /etc/my.cnf.disabled
  fi

  printf "Updating /etc/rc.conf:\n"
  ${SYSRC} mysql_enable="YES"
  ${SYSRC} mysql_dbdir="${SQL_DATA_PATH}"
  ${SYSRC} mysql_optfile="/usr/local/etc/my.cnf"

  printf "Starting %s\n" "${OPT_SQL_DB}"
  ${SERVICE} "mysql-server" start

  ## Retrieve: $MYSQL_USER, $MYSQL_PASS, $MYSQL_HOST, $MYSQL_ACCESS_HOST
  get_sql_settings
  # sql_prepare

  if [ -e "${MYSQLUPGRADE}" ]; then
    ${MYSQLUPGRADE} "--defaults-extra-file=${DA_MYSQL_CNF}"
  else
    printf "*** Warning: The mysqlupgrade binary was not found on this system.\n"
  fi

  ## Reference CNF files: /usr/local/share/mysql/*.cnf
  if [ ! -e "${MYSQL_CNF}" ]; then
    case ${DEFAULT_MY_CNF} in
      "my-huge.cnf" \
      |"my-medium.cnf" \
      |"my-innodb-heavy-4G.cnf" \
      |"my-small.cnf" \
      |"my-large.cnf")
        cp "/usr/local/share/mysql/${DEFAULT_MY_CNF}" "${MYSQL_CNF}"
      ;;
      "my-huge" \
      |"my-medium" \
      |"my-innodb-heavy-4G" \
      |"my-small" \
      |"my-large")
        cp "/usr/local/share/mysql/${DEFAULT_MY_CNF}.cnf" "${MYSQL_CNF}"
      ;;
      "custom") cp -f "${CUSTOM_MYSQL_CNF}" "${MYSQL_CNF}"
      ;;
      *)
        ${TOUCH} "${MYSQL_CNF}"
        printf "[mysqld]\nlocal-infile=0\ninnodb_file_per_table\n" > ${MYSQL_CNF}
        ;;
    esac
    ${CHOWN} root:wheel ${MYSQL_CNF}
  fi

  ## Todo: comment out thread_concurrency in my.cnf to prevent deprecation warnings
  ## e.g. thread_concurrency = 8

  if [ "${COMPAT_SQL_SYMLINKS}" = "YES" ]; then
    readonly DA_MYSQL_PATH=/usr/local/mysql/bin
    if [ ! -e "${DA_MYSQL_PATH}/mysql" ]; then
      printf "Symlinking the MySQL/MariaDB binaries for DirectAdmin compatibility\n"
      ${MKDIR} -p /usr/local/mysql/bin
      ln -s ${MYSQL} "${DA_MYSQL_PATH}/mysql"
      ln -s ${MYSQLDUMP} "${DA_MYSQL_PATH}/mysqldump"
      ln -s ${MYSQLD} "${DA_MYSQL_PATH}/mysqld"
      ln -s ${MYSQLD_SAFE} "${DA_MYSQL_PATH}/mysqld_safe"
      ln -s ${MYSQLADMIN} "${DA_MYSQL_PATH}/mysqladmin"
      ln -s ${MYSQLIMPORT} "${DA_MYSQL_PATH}/mysqlimport"
      ln -s ${MYSQLSHOW} "${DA_MYSQL_PATH}/mysqlshow"
      ln -s ${MYSQLUPGRADE} "${DA_MYSQL_PATH}/mysql_upgrade"
      ln -s ${MYSQLCHECK} "${DA_MYSQL_PATH}/mysqlcheck"
      ln -s ${MYSQLSECURE} "${DA_MYSQL_PATH}/mysql_secure_installation"
    else
      printf "*** Notice: MySQL/MariaDB binaries already symlinked in %s\n" ${DA_MYSQL_PATH}
    fi
  fi

  set_service "mysql-server" ON

  printf "Restarting %s\n" "${OPT_SQL_DB}"
  ${SERVICE} "mysql-server" restart

  return
}

################################################################################
## Verify: FPM Check (from CB2: fpmCheck())
## Checks to see if any changes were done (e.g. converting between web server softwares)
################################################################################

fpmCheck() {

  # local ARG="$1"
  local WEB_SERVER_CHANGED FPM_COUNT FPM_SOCK_CHMOD

  FPM_SOCK_CHMOD=700

  WEB_SERVER_CHANGED=0

  FPM_COUNT="$(grep -m1 -c nginx "${PHP_FPM_CONF}")"

  ## PB: Select appropriate web user depending on chosen web server
  if [ "${OPT_WEBSERVER}" = "apache" ] ||  [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
    CHOWN_USER="${APACHE_USER}"
  elif [ "${OPT_WEBSERVER}" = "nginx" ]; then
    CHOWN_USER="${NGINX_USER}"
  else ## Verify: Better to exit with error?
    CHOWN_USER="${OPT_WEBSERVER}"
  fi

  ## Socket directory permissions
  ${CHOWN} "${CHOWN_USER}:${CHOWN_USER}" "${PHP_SOCKETS_PATH}"

  ## Socket directory permissions
  ${CHMOD} "${FPM_SOCK_CHMOD}" "${PHP_SOCKETS_PATH}"

  ## Nginx
  if [ "${OPT_WEBSERVER}" = "nginx" ] && [ "${FPM_COUNT}" -eq 0 ]; then
    ${PERL} -pi -e 's/apache/nginx/' "${PHP_FPM_CONF}"
    WEB_SERVER_CHANGED=1
  elif [ "${OPT_WEBSERVER}" = "apache" ] || [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
    if [ "${FPM_COUNT}" -gt 0 ]; then
      ${PERL} -pi -e 's/nginx/apache/' "${PHP_FPM_CONF}"
      WEB_SERVER_CHANGED=1
    fi
  fi

  ## Socket directory permissions
  if [ -d "${PHP_SOCKETS_PATH}" ]; then
    if [ "${OPT_WEBSERVER}" = "nginx" ]; then
      # ${CHOWN} -R "${NGINX_USER}:${NGINX_GROUP}" "${PHP_SOCKETS_PATH}"
      ${CHGRP} -R "${NGINX_GROUP}" "${PHP_SOCKETS_PATH}"
    elif [ "${OPT_WEBSERVER}" = "apache" ] || [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
      # ${CHOWN} -R "${APACHE_USER}:${APACHE_GROUP}" "${PHP_SOCKETS_PATH}"
      ${CHGRP} -R "${APACHE_GROUP}" "${PHP_SOCKETS_PATH}"
    fi
  fi

  ## Restart PHP-FPM if webserver changed
  if [ "${WEB_SERVER_CHANGED}" -eq 1 ]; then
    php_fpm_restart
  fi

  return
}

################################################################################
## Todo: Verify: FPM Checks (from CB2: fpmChecks())
################################################################################

fpmChecks() {

  local IFS=' '
  local PHP_REPLACE_STRING
  # local php_shortrelease

  if [ "${PB_DEBUG}" = "YES" ]; then
    echo "*** Debug: Function: fpmChecks()"
    echo "OPT_PHP_MODE: ${OPT_PHP_MODE}"
    echo "OPT_PHP_VER: ${OPT_PHP_VER}"
    echo "PHP_SOCKETS_PATH: ${PHP_SOCKETS_PATH}"
    echo "PHP_FPM_CONF: ${PHP_FPM_CONF}"
  fi

  # EVAL_CHECK_VAR="HAVE_FPM${OPT_PHP_VER}_CGI"
  # $(eval_var "${EVAL_CHECK_VAR}") = "YES"

  # if [ "${OPT_PHP_MODE}" = "php-fpm" ] && [ -d "${PHP_SOCKETS_PATH}" ]; then
  cp -f "${PB_CONFIG}/fpm/conf/php-fpm.conf.${OPT_PHP_VER}" "${PHP_FPM_CONF}"
  fpmCheck "${OPT_PHP_VER}"
  # fi

  if [ "${HAVE_FPM_CGI}" = "YES" ]; then
    if [ "${OPT_WEBSERVER}" = "nginx" ]; then
      ${PERL} -pi -e 's/apache/nginx/' "${DA_PATH}/data/templates/php-fpm.conf"
    elif [ "${OPT_WEBSERVER}" = "apache" ] || [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
      ${PERL} -pi -e 's/nginx/apache/' "${DA_PATH}/data/templates/php-fpm.conf"
    fi

    ## CB2: update the webapps_settings.conf (via regex)
    ## CB2: swap "fastcgi_pass unix:/usr/local/php54/sockets/webapps.sock;" if needed
    ## CB2: might be a better way to do this, other checks. Close enough for now.
    ## PB: Todo: Remove?
    if [ -e "${NGINX_PATH}/webapps_settings.conf" ]; then
      PHP_REPLACE_STRING="$(grep -m1 '^fastcgi_pass unix:/var/run/php/sockets/webapps.sock;' "${NGINX_PATH}/webapps_settings.conf" | cut -d/ -f4)"
      if [ -z "${PHP_REPLACE_STRING}" ]; then
        PHP_REPLACE_STRING=php54
      fi
      if [ "${OPT_PHP_MODE}" = "php-fpm" ]; then
        ${PERL} -pi -e "s#${PHP_REPLACE_STRING}#php${OPT_PHP_VER}#" "${NGINX_PATH}/webapps_settings.conf"
      fi
    fi

    ## Update PHP-FPM version in Nginx configuration files
    ## PB: Todo: Remove?
    if [ -e "${NGINX_PATH}/nginx-vhosts.conf" ]; then
      PHP_REPLACE_STRING="$(grep -m1 '^fastcgi_pass unix:/var/run/php/sockets/webapps.sock;' "${NGINX_PATH}/nginx-vhosts.conf" | cut -d/ -f4)"
      if [ -z "${PHP_REPLACE_STRING}" ]; then
        PHP_REPLACE_STRING=php54
      fi
      if [ "${OPT_PHP_MODE}" = "php-fpm" ]; then
        ${PERL} -pi -e "s#${PHP_REPLACE_STRING}#php${OPT_PHP_VER}#" "${NGINX_PATH}/nginx-vhosts.conf"
      fi
    fi
  fi

  return
}

################################################################################
## Dovecot Checks (from CB2: dovecotChecks())
## Used when switching between webservers: Apache/Nginx/Nginx_Apache
################################################################################

dovecot_checks() {

  local DOVECOT_COUNT

  if [ -e "${DOVECOT_CONF}" ]; then
    DOVECOT_COUNT="$(grep -m1 -c "${APACHE_PATH}/" ${DOVECOT_CONF})"
    if [ "${OPT_WEBSERVER}" = "nginx" ] && [ "${DOVECOT_COUNT}" -gt 0 ]; then
      ${PERL} -pi -e "s#${APACHE_PATH}/#${NGINX_PATH}/#" ${DOVECOT_CONF}
      if grep -m1 -q "${NGINX_PATH}/" ${DOVECOT_CONF}; then
        ${SERVICE} dovecot restart
      fi
    elif [ "${OPT_WEBSERVER}" = "apache" ] || [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
      if [ "${DOVECOT_COUNT}" -eq 0 ]; then
        ${PERL} -pi -e "s#${NGINX_PATH}/#${APACHE_PATH}/#" ${DOVECOT_CONF}
        if grep -m1 -q "${APACHE_PATH}/" ${DOVECOT_CONF}; then
          ${SERVICE} dovecot restart
        fi
      fi
    fi
  fi

  return
}

################################################################################
## PHP Installation Tasks
################################################################################

php_install() {

  local IFS=' '
  local PHPMODULES COUNT_SUPHP COUNT_MODSEC COUNT_HTSCANNER
  local PHP_EXT_LIST PORT_PHP PORT_PHP_EXT PORT_MOD_PHP
  local PHP_MAKE_SET PHP_MAKE_UNSET PHP_EXT_MAKE_SET PHP_EXT_MAKE_UNSET
  local PHP_MOD_MAKE_SET PHP_MOD_MAKE_UNSET PHP_EXT_DIR

  ## Install Web Server(s) first

  ## Apache / Nginx+Apache:
  if [ "${OPT_WEBSERVER}" = "apache" ] || [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
    if [ ! -x "${APACHE_HTTPD}" ]; then
      apache_install
    fi
  fi

  ## Nginx / Nginx+Apache:
  if [ "${OPT_WEBSERVER}" = "nginx" ] || [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
    if [ ! -d "${NGINX_PATH}" ]; then
      nginx_install
    fi
  fi

  if [ "${OPT_WEBSERVER}" = "apache" ] || [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
    doApacheCheck
  fi

  ## CB2 code:
  PHPMODULES="${APACHE_EXTRAS}/httpd-phpmodules.conf"
  if [ "${HAVE_CLI}" = "YES" ] && [ -e "${PHPMODULES}" ]; then
    if [ "${OPT_WEBSERVER}" = "apache" ] || [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
      if grep -m1 -q "LoadModule mpm_event_module ${APACHE_LIBS}/mod_mpm_event.so" ${PHPMODULES}; then
        printf "*** Notice: Switching Apache Event MPM to Prefork (mod_php requirement).\n"
        ${PERL} -pi -e "s#LoadModule mpm_event_module ${APACHE_LIBS}/mod_mpm_event.so#LoadModule mpm_prefork_module ${APACHE_LIBS}/mod_mpm_prefork.so#" ${PHPMODULES}
        ${SERVICE} apache24 restart
      fi
      if grep -m1 -q "LoadModule mpm_worker_module ${APACHE_LIBS}/mod_mpm_worker.so" ${PHPMODULES}; then
        printf "*** Notice: Switching Apache Worker MPM to Prefork (mod_php requirement).\n"
        ${PERL} -pi -e "s#LoadModule mpm_worker_module ${APACHE_LIBS}/mod_mpm_worker.so#LoadModule mpm_prefork_module ${APACHE_LIBS}/mod_mpm_prefork.so#" ${PHPMODULES}
        ${SERVICE} apache24 restart
      fi
    fi
  fi

  printf "*** Notice: Starting PHP installation\n"

  if [ -z "${PHP_MAKE_SET}" ] && [ -z "${PHP_MAKE_UNSET}" ]; then
    ## Base PHP Installation (includes FPM, CGI, CLI modes)
    case ${OPT_PHP_MODE} in
      "php-fpm") pkgi ${PORT_PHP} ${PHP_EXT_LIST} ;;
      "mod_php") pkgi ${PORT_MOD_PHP} ${PHP_EXT_LIST} ;;
      "suphp") pkgi ${PORT_SUPHP} ${PHP_EXT_LIST} ;;
      # fastcgi) pkgi "${PORT_PHP}" "${PHP_EXT_LIST}" ;;
      # fcgid) pkgi "${PORT_PHP}" "${PHP_EXT_LIST}" ;;
    esac
  else
    case ${OPT_PHP_VER} in
    "56")
      PHP_MAKE_SET="${PHP56_MAKE_SET}"
      PHP_MAKE_UNSET="${PHP56_MAKE_UNSET}"
      PHP_EXT_MAKE_SET="${PHP56_EXT_MAKE_SET}"
      PHP_EXT_MAKE_UNSET="${PHP56_EXT_MAKE_UNSET}"
      PHP_MOD_MAKE_SET="${PHP56_MOD_MAKE_SET}"
      PHP_MOD_MAKE_UNSET="${PHP56_MOD_MAKE_UNSET}"
      ;;
    "70")
      PHP_MAKE_SET="${PHP70_MAKE_SET}"
      PHP_MAKE_UNSET="${PHP70_MAKE_UNSET}"
      PHP_EXT_MAKE_SET="${PHP70_EXT_MAKE_SET}"
      PHP_EXT_MAKE_UNSET="${PHP70_EXT_MAKE_UNSET}"
      PHP_MOD_MAKE_SET="${PHP70_MOD_MAKE_SET}"
      PHP_MOD_MAKE_UNSET="${PHP70_MOD_MAKE_UNSET}"
      ;;
    "71")
      PHP_MAKE_SET="${PHP71_MAKE_SET}"
      PHP_MAKE_UNSET="${PHP71_MAKE_UNSET}"
      PHP_EXT_MAKE_SET="${PHP71_EXT_MAKE_SET}"
      PHP_EXT_MAKE_UNSET="${PHP71_EXT_MAKE_UNSET}"
      PHP_MOD_MAKE_SET="${PHP71_MOD_MAKE_SET}"
      PHP_MOD_MAKE_UNSET="${PHP71_MOD_MAKE_UNSET}"
      ;;
    esac

    case ${OPT_PHP_MODE} in
      "php-fpm")
          ## Base PHP Installation (includes FPM, CGI, CLI modes)
          ${MAKE} -DNO_DIALOG -C "${PORTS_BASE}/${PORT_PHP}" rmconfig
          ${MAKE} -DNO_DIALOG -C "${PORTS_BASE}/${PORT_PHP}" \
          OPTIONS_SET="${PHP_MAKE_SET} ${GLOBAL_MAKE_SET}" \
          OPTIONS_UNSET="${PHP_MAKE_UNSET} ${GLOBAL_MAKE_UNSET}" \
          reinstall

          ## PHP Extensions:
          ${MAKE} -DNO_DIALOG -C "${PORTS_BASE}/${PORT_PHP_EXT}" rmconfig
          ${MAKE} -DNO_DIALOG -C "${PORTS_BASE}/${PORT_PHP_EXT}" \
          OPTIONS_SET="${PHP_EXT_MAKE_SET} ${GLOBAL_MAKE_SET}" \
          OPTIONS_UNSET="${PHP_EXT_MAKE_UNSET} ${GLOBAL_MAKE_UNSET}" \
          reinstall

          ## Cleanup
          ${MAKE} -DNO_DIALOG -C "${PORTS_BASE}/${PORT_PHP}" clean
          ${MAKE} -DNO_DIALOG -C "${PORTS_BASE}/${PORT_PHP_EXT}" clean
          ;;
      "mod_php")
          ${MAKE} -DNO_DIALOG -C "${PORTS_BASE}/${PORT_MOD_PHP}" rmconfig
          ${MAKE} -DNO_DIALOG -C "${PORTS_BASE}/${PORT_MOD_PHP}" \
          OPTIONS_SET="${PHP_MOD_MAKE_SET} ${GLOBAL_MAKE_SET}" \
          OPTIONS_UNSET="${PHP_MOD_MAKE_UNSET} ${GLOBAL_MAKE_UNSET}" \
          reinstall

          ## PHP Extensions:
          ${MAKE} -DNO_DIALOG -C "${PORTS_BASE}/${PORT_PHP_EXT}" \
          OPTIONS_SET="${PHP_EXT_MAKE_SET} ${GLOBAL_MAKE_SET}" \
          OPTIONS_UNSET="${PHP_EXT_MAKE_UNSET} ${GLOBAL_MAKE_UNSET}" \
          reinstall

          ## Cleanup
          ${MAKE} -DNO_DIALOG -C "${PORTS_BASE}/${PORT_MOD_PHP}" clean
          ${MAKE} -DNO_DIALOG -C "${PORTS_BASE}/${PORT_PHP_EXT}" clean
          ;;
      "suphp")
          pkgi ${PORT_SUPHP} ${PORT_PHP_EXT}
          ;;
      "fastcgi") echo "not done" ;;
      # "fcgid") echo "not done" ;;
      *) printf "*** Error: php_install(): Wrong PHP mode selected. (Script error)\n"; exit ;;
    esac
  fi

  if [ "${OPT_PHP_MODE}" = "php-fpm" ] && [ ! -d "${PHP_SOCKETS_PATH}" ]; then
    printf "*** Notice: Creating directory: %s\n" "${PHP_SOCKETS_PATH}"
    ${MKDIR} -p "${PHP_SOCKETS_PATH}"
  fi

  # ${MAKE} -DNO_DIALOG -C "${PORT_PHP_EXT}" reinstall clean

  if [ -e /usr/local/etc/php.conf ]; then
    PHP_EXT_DIR="$(grep PHP_EXT_DIR= /usr/local/etc/php.conf | grep -m1 PHP_EXT_DIR | cut -d= -f2 | tr -d '"')"
  else
    printf "*** Error: cannot continue due to missing file: /usr/local/etc/php.conf\n"
    exit 1
  fi

  if [ "${COMPAT_PHP_SYMLINKS}" == "YES" ]; then
    printf "*** Notice: DirectAdmin + PHP Compatibility mode enabled.\n"

    ## Create CB2/DA directories for compat:
    # ${MKDIR} -p /usr/local/php$OPT_PHP_VER/{bin,etc,include,lib/php,php,sbin,var/log,var/run}
    ${MKDIR} -p "/usr/local/php${OPT_PHP_VER}"
    ${MKDIR} -p "/usr/local/php${OPT_PHP_VER}/bin"
    ${MKDIR} -p "/usr/local/php${OPT_PHP_VER}/etc"
    ${MKDIR} -p "/usr/local/php${OPT_PHP_VER}/include"
    ${MKDIR} -p "/usr/local/php${OPT_PHP_VER}/lib"
    ${MKDIR} -p "/usr/local/php${OPT_PHP_VER}/php"
    ${MKDIR} -p "/usr/local/php${OPT_PHP_VER}/sbin"
    ${MKDIR} -p "/usr/local/php${OPT_PHP_VER}/var/log/"
    ${MKDIR} -p "/usr/local/php${OPT_PHP_VER}/var/run"
    ${MKDIR} -p "/usr/local/php${OPT_PHP_VER}/lib/php/"

    ## ${MKDIR} -p "/usr/local/php${OPT_PHP_VER}/lib/php.conf.d/"
    ## ${MKDIR} -p "/usr/local/php${OPT_PHP_VER}/sockets"

    ## Symlinks
    ln -fsv /usr/local/bin/php "/usr/local/php${OPT_PHP_VER}/bin/php"
    ln -fsv /usr/local/bin/php-cgi "/usr/local/php${OPT_PHP_VER}/bin/php-cgi"
    ln -fsv /usr/local/bin/php-config "/usr/local/php${OPT_PHP_VER}/bin/php-config"
    ln -fsv /usr/local/bin/phpize "/usr/local/php${OPT_PHP_VER}/bin/phpize"
    ln -fsv /usr/local/sbin/php-fpm "/usr/local/php${OPT_PHP_VER}/sbin/php-fpm"

    ln -fsv /var/log/php-fpm.log "/usr/local/php${OPT_PHP_VER}/var/log/php-fpm.log"

    ln -Ffsv /usr/local/etc/php/ "/usr/local/php${OPT_PHP_VER}/lib/php.conf.d"
    ln -fsv /usr/local/etc/php.ini "/usr/local/php${OPT_PHP_VER}/lib/php.ini"
    ln -fsv /usr/local/etc/php-fpm.conf "/usr/local/php${OPT_PHP_VER}/etc/php-fpm.conf"
    ln -Ffsv /usr/local/include/php/ "/usr/local/php${OPT_PHP_VER}/include/php"
    ln -Ffsv /var/run/php/sockets/ "/usr/local/php${OPT_PHP_VER}/sockets"

    ## Fetch build date value from: /usr/local/etc/php.conf $PHP_EXT_DIR
    ln -Ffsv "/usr/local/lib/php/${PHP_EXT_DIR}/" "/usr/local/php${OPT_PHP_VER}/lib/php/extensions"
    ln -Ffsv /usr/local/lib/php/build/ "/usr/local/php${OPT_PHP_VER}/lib/php/build"
  fi


  if [ "${OPT_PHP_IONCUBE}" = "YES" ]; then
    printf "*** Notice: Installing IonCube loaders.\n"
    pkgi ${PORT_IONCUBE}
  fi

  ### CB2 code:
  if [ "${OPT_WEBSERVER}" = "apache" ] || [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
    printf "" > "${PHPMODULES}"

    if [ -e "${PHPMODULES}" ]; then
      COUNT_SUPHP="$(grep -m1 -c 'suphp_module' ${PHPMODULES})"
      if [ "${HAVE_SUPHP_CGI}" = "YES" ] && [ "${COUNT_SUPHP}" -eq 0 ]; then
        ${PERL} -pi -e 's|^LoadModule suphp_module|#LoadModule suphp_module|' ${APACHE_CONF}
        printf "LoadModule suphp_module %s/mod_suphp.so" "${APACHE_LIBS}" >> ${PHPMODULES}
      fi

      ## Mod Security
      COUNT_MODSEC="$(grep -m1 -c 'httpd-modsecurity' ${PHPMODULES})"
      if [ "${OPT_MODSECURITY}" = "YES" ] && [ ! -e "${APACHE_LIBS}/mod_security2.so" ]; then
        modsecurity_install
      fi

      if [ "${OPT_MODSECURITY}" = "YES" ]  && [ "${COUNT_MODSEC}" -eq 0 ] && [ "${OPT_WEBSERVER}" = "apache" ]; then
        ${PERL} -pi -e 's|^LoadModule security2_module|#LoadModule security2_module|' ${APACHE_CONF}
        printf "Include %s/httpd-modsecurity.conf" "${APACHE_EXTRAS}" >> ${PHPMODULES}
        cp -pf "${MODSECURITY_APACHE_INCLUDE}" "${APACHE_EXTRAS}/httpd-modsecurity.conf"
      fi

      ## HTScanner
      if [ "${HAVE_CLI}" = "NO" ]; then
        COUNT_HTSCANNER="$(grep -m1 -c 'htscanner_module' ${PHPMODULES})"
        if [ "${OPT_HTSCANNER}" = "YES" ] && [ "${COUNT_HTSCANNER}" -eq 0 ]; then
          ${PERL} -pi -e 's|^LoadModule htscanner_module|#LoadModule htscanner_module|' ${APACHE_CONF}
          printf "LoadModule htscanner_module %s/mod_htscanner2.so" "${APACHE_LIBS}" >> ${PHPMODULES}
        fi
      elif [ "${HAVE_CLI}" = "YES" ]; then
        COUNT_HTSCANNER="$(grep -m1 -c 'htscanner_module' ${PHPMODULES})"
        if [ "${OPT_HTSCANNER}" = "YES" ] && [ "${COUNT_HTSCANNER}" -gt 0 ]; then
          ${PERL} -pi -e 's|^LoadModule htscanner_module|#LoadModule htscanner_module|' ${APACHE_CONF}
          ${PERL} -pi -e 's|^LoadModule htscanner_module|^#LoadModule htscanner_module' ${PHPMODULES}
        fi
      fi
    fi

    ## Determine Apache MPM + Generate httpd-phpmodules.conf
    if ! grep -m1 -q "${APACHE_LIBS}/mod_mpm_" "${PHPMODULES}"; then
      {
        if [ "${OPT_APACHE_MPM}" = "auto" ]; then
          ## CB2: Use Event MPM for CGI (FPM) and Prefork for CLI (mod_php)
          if [ "${HAVE_CLI}" = "NO" ]; then
            printf "LoadModule mpm_event_module %s/mod_mpm_event.so\n" "${APACHE_LIBS}"
          else
            printf "LoadModule mpm_prefork_module %s/mod_mpm_prefork.so\n" "${APACHE_LIBS}"
          fi
        elif [ "${OPT_APACHE_MPM}" = "event" ]; then
          printf "LoadModule mpm_event_module %s/mod_mpm_event.so\n" "${APACHE_LIBS}"
        elif [ "${OPT_APACHE_MPM}" = "worker" ]; then
          printf "LoadModule mpm_worker_module %s/mod_mpm_worker.so\n" "${APACHE_LIBS}"
        else
          printf "LoadModule mpm_prefork_module %s/mod_mpm_prefork.so\n" ${APACHE_LIBS}
        fi
      } >> ${PHPMODULES}
    fi
  fi

  ${PERL} -pi -e 's/^LoadModule php4/\#LoadModule php4/' ${APACHE_CONF}
  ${PERL} -pi -e 's/^LoadModule php5/\#LoadModule php5/' ${APACHE_CONF}
  ${PERL} -pi -e 's/^LoadModule php7/\#LoadModule php7/' ${APACHE_CONF}

  ## CB2: Add correct PHP module to httpd-phpmodules.conf

  ## PHP: mod_php:
  if [ "${OPT_PHP_MODE}" = "mod_php" ]; then
    if [ "${OPT_PHP_RELEASE}" = "7.0" ]; then
      printf "LoadModule php7_module %s/libphp7.so\n" ${APACHE_LIBS} >> ${PHPMODULES}
    else
      printf "LoadModule php5_module %s/libphp5.so\n" ${APACHE_LIBS} >> ${PHPMODULES}
    fi
  fi

  ## FCGID
  if [ "${HAVE_FCGID}" = "YES" ]; then
    if [ -e "${PHPMODULES}" ]; then
      if [ ! -s "${APACHE_LIBS}/mod_fcgid.so" ]; then
        install_mod_fcgid
      fi
      if ! grep -m1 -q 'fcgid_module' ${PHPMODULES}; then
        ${PERL} -pi -e 's|^LoadModule mod_fcgid|#LoadModule mod_fcgid|' ${APACHE_CONF}
        printf "LoadModule fcgid_module %s/mod_fcgid.so\n" ${APACHE_LIBS} >> ${PHPMODULES}
      fi
      if ! grep -m1 -c 'httpd-fcgid.conf' ${PHPMODULES}; then
        printf "Include %s/httpd-fcgid.conf\n" ${APACHE_EXTRAS} >> ${PHPMODULES}
      fi
    fi
  fi

  ## HTScanner
  if [ "${OPT_WEBSERVER}" = "apache" ] || [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
    if [ "${HAVE_FCGID}" = "YES" ] || [ "${HAVE_FPM_CGI}" = "YES" ] || [ "${HAVE_SUPHP_CGI}" = "YES" ]; then
      if [ "${OPT_HTSCANNER}" = "YES" ] && [ ! -e "${APACHE_LIBS}/mod_htscanner2.so" ]; then
        install_mod_htscanner
      fi
    fi
    if [ "${NEWCONFIGS}" = "1" ]; then
      ${PERL} -pi -e 's/^LoadModule mod_php/\#LoadModule mod_php/' ${APACHE_CONF}
      ${PERL} -pi -e 's/^LoadModule php/\#LoadModule php/' ${APACHE_CONF}
    fi
  fi

  php_conf

  fpmChecks

  # cp -f "${PB_PATH}/directadmin/data/templates/custom/php-fpm.conf" "${DA_PATH}/data/templates/custom/php-fpm.conf"

  if [ "${OPT_WEBSERVER}" = "apache" ]  || [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
    printf "Rewriting all users httpd.conf files, please wait...\n"
    echo "action=rewrite&value=httpd" >> ${DA_TASK_QUEUE}
  elif [ "${OPT_WEBSERVER}" = "nginx" ]; then
    printf "Rewriting all users nginx.conf files, please wait...\n"
    echo "action=rewrite&value=nginx" >> ${DA_TASK_QUEUE}
  fi

  run_dataskq d

  if [ "${OPT_PHP_MODE}" = "php-fpm" ]; then
    php_fpm_restart
  fi

  if [ "${OPT_WEBSERVER}" = "apache" ] || [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
    printf "Restarting Apache\n"
    ${SERVICE} apache24 restart
  fi

  if [ "${OPT_WEBSERVER}" = "nginx" ] || [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
    printf "Restarting Nginx\n"
    ## Verify: /usr/sbin/nginx -s stop >/dev/null 2>&1
    ${SERVICE} nginx restart
  fi

  return
}

################################################################################
## Todo: Move to control_service()
## PHP-FPM Restart and configuration file verification
################################################################################

php_fpm_restart() {

  ## local PHP_ARG = $1 ## ${OPT_PHP_VERSION}

  ## Check for graceful restarts?

  if [ -x "${PHP_FPM_BIN}" ]; then
    ${PHP_FPM_BIN} --test
  fi

  if [ "$?" = "0" ]; then
    ${SERVICE} "php-fpm" reload
  else
    printf "*** Warning: Aborting automatic PHP-FPM restart due to configuration verification failure.\n"
    printf "The current PHP-FPM configuration file: %s\n" "${PHP_FPM_CONF}"
    printf "You can verify the file by typing:\n"
    printf "  %s --test\n\n" "${PHP_FPM_BIN}"
    printf "You can restart PHP-FPM manually by typing:\n"
    printf "  service php-fpm restart\n"
  fi

  return
}

################################################################################
## Upgrade PHP and related components
################################################################################

php_upgrade() {

  printf "Upgrading PHP and related extensions.\n"

  pkgu "$(pkg query %o | grep "php${OPT_PHP_VER}")"

  # pkgq -i -x "%o %v" '(php)'

  php_fpm_restart
}

################################################################################
## Have PHP System (from CB2)
## Needed?
################################################################################

have_php_system() {

  local COUNT_FUNCTIONS

  ## Checks to see if we can use system() based on the disable_functions
  if [ ! -s "${PHP_INI}" ]; then
    echo 1
    return
  fi

  COUNT_FUNCTIONS="$(grep -m1 -c ^disable_functions "${PHP_INI}")"
  if [ "${COUNT_FUNCTIONS}" -eq 0 ]; then
    echo 1
    return
  fi

  COUNT_FUNCTIONS="$(grep -m1 ^disable_functions "${PHP_INI}" | grep -m1 -c system)"
  if [ "${COUNT_FUNCTIONS}" -eq 1 ]; then
    echo 0
    return
  fi

  echo 1
  return
}

################################################################################
## phpMyAdmin Installation
################################################################################

phpmyadmin_install() {

  if [ "${OPT_PHPMYADMIN}" != "YES" ]; then
    printf "*** Notice: PHPMYADMIN is not enabled in options.conf\n"
    return
  fi

  printf "Starting phpMyAdmin installation\n"

  ### Main Installation
  if [ -z "${PMA_MAKE_SET}" ] && [ -z "${PMA_MAKE_UNSET}" ]; then
    pkgi ${PORT_PHPMYADMIN}
  else
    ${MAKE} -DNO_DIALOG -C "${PORTS_BASE}/${PORT_PHPMYADMIN}" rmconfig
    ${MAKE} -DNO_DIALOG -C "${PORTS_BASE}/${PORT_PHPMYADMIN}" \
    databases_phpmyadmin_SET="${PMA_MAKE_SET}" \
    databases_phpmyadmin_UNSET"${PMA_MAKE_UNSET}" \
    OPTIONS_SET="${GLOBAL_MAKE_SET}" \
    OPTIONS_UNSET="${GLOBAL_MAKE_UNSET}" \
    reinstall clean
  fi

  ## Reference for virtualhost entry:
  # Alias /phpmyadmin/ "/usr/local/www/phpMyAdmin/"
  # <Directory "/usr/local/www/phpMyAdmin/">
  #   Options None
  #   AllowOverride Limit
  #   Require local
  #   Require host .example.com
  # </Directory>

  ## Custom config from cb2/custom directory (if present):
  CUSTOM_PMA_CONFIG="${PB_CUSTOM}/phpmyadmin/config.inc.php"
  CUSTOM_PMA_THEMES="${PB_CUSTOM}/phpmyadmin/themes"

  ##REALPATH=${WWW_DIR}/phpMyAdmin-${PHPMYADMIN_VER}
  #REALPATH=${WWW_DIR}/phpMyAdmin
  PMA_ALIAS_PATH="${WWW_DIR}/phpmyadmin"

  ## Scripted reference:

  ## If custom config exists:
  if [ -e "${CUSTOM_PMA_CONFIG}" ]; then
    printf "Installing custom phpMyAdmin configuration file: %s\n" "${CUSTOM_PMA_CONFIG}"
    cp -f "${CUSTOM_PMA_CONFIG}" ${PMA_CONFIG}
  else
    cp -f ${PMA_PATH}/config.sample.inc.php ${PMA_CONFIG}
    ${PERL} -pi -e "s#\['host'\] = 'localhost'#\['host'\] = '${MYSQL_HOST}'#" ${PMA_CONFIG}
    ${PERL} -pi -e "s#\['host'\] = ''#\['host'\] = '${MYSQL_HOST}'#" ${PMA_CONFIG}
    ${PERL} -pi -e "s#\['auth_type'\] = 'cookie'#\['auth_type'\] = 'http'#" ${PMA_CONFIG}
    ${PERL} -pi -e "s#\['extension'\] = 'mysql'#\['extension'\] = 'mysqli'#" ${PMA_CONFIG}
  fi

  ## Copy sample config:
  cp "${PMA_PATH}/config.sample.inc.php" ${PMA_CONFIG}

  ## Update phpMyAdmin configuration file:
  ${PERL} -pi -e "s#\['host'\] = 'localhost'#\['host'\] = 'localhost'#" ${PMA_CONFIG}
  ${PERL} -pi -e "s#\['host'\] = ''#\['host'\] = 'localhost'#" ${PMA_CONFIG}
  ${PERL} -pi -e "s#\['auth_type'\] = 'cookie'#\['auth_type'\] = 'http'#" ${PMA_CONFIG}
  ${PERL} -pi -e "s#\['extension'\] = 'mysql'#\['extension'\] = 'mysqli'#" ${PMA_CONFIG}

  # Copy custom themes (not implemented):
  if [ -d "${CUSTOM_PMA_THEMES}" ]; then
    printf "Installing custom phpMyAdmin themes: %s\n" "${PMA_THEMES}"
    cp -Rf "${CUSTOM_PMA_THEMES}" ${PMA_PATH}
  fi

  ## Update alias path via symlink (not done):
  rm -f ${PMA_ALIAS_PATH} >/dev/null 2>&1
  ln -s ${PMA_PATH} ${PMA_ALIAS_PATH}

  ## Symlink:
  #ln -s ${PMA_PATH} "${WWW_DIR}/phpmyadmin"
  ln -s ${PMA_PATH} "${WWW_DIR}/pma"

  ## Create logs directory:
  if [ ! -d ${PMA_PATH}/log ]; then
    ${MKDIR} -p "${PMA_PATH}/log"
  fi

  ## Set permissions:
  ${CHOWN} -R "${WEBAPPS_USER}:${WEBAPPS_GROUP}" ${PMA_PATH}
  ${CHOWN} -h "${WEBAPPS_USER}:${WEBAPPS_GROUP}" ${PMA_ALIAS_PATH}
  ${CHMOD} 755 ${PMA_PATH}

  ## Disable/lockdown scripts directory (might not even exist):
  if [ -d "${PMA_PATH}/scripts" ]; then
    ${CHMOD} 000 "${PMA_PATH}/scripts"
  fi

  ## Disable/lockdown setup directory (done):
  if [ -d "${PMA_PATH}/setup" ]; then
    ${CHMOD} 000 "${PMA_PATH}/setup"
  fi

  ## Auth log patch for BFM compat (not done):
  ## Currently outputs to /var/log/auth.log
  if [ ! -e "${PB_PATH}/patches/pma_auth_logging.patch" ]; then
    ${WGET} -O "${PB_PATH}/patches/pma_auth_logging.patch" "${PB_MIRROR}/patches/pma_auth_logging.patch"
  fi

  if [ -e "${PB_PATH}/patches/pma_auth_logging.patch" ]; then
    printf "Patching phpMyAdmin for BFM to log failed authentications\n"
    cd ${PMA_PATH} || exit
    ${PATCH} -p0 < "${PB_PATH}/patches/pma_auth_logging.patch"
  fi

  ## Verify: Update /etc/groups:
  #access:*:1164:apache,nobody,mail,majordomo,daemon,clamav
}

################################################################################
## Upgrade phpMyAdmin
################################################################################

phpmyadmin_upgrade() {

  printf "Upgrading phpMyAdmin\n"

  pkgu "${PORT_PHPMYADMIN}"

  return
}

################################################################################
## Apache 2.4 Installation (references doApache2 from CB2)
################################################################################

apache_install() {

  local PHPMODULES ADMIN_HTTP HAVE_DACONF HDC
  local WWW_APACHE24_PATCHDIR WWW_APACHE24_WRKSRC
  local FIRST_TIME_INSTALL

  if [ "${OPT_WEBSERVER}" != "apache" ]; then
    printf "***\n Error: Can't install Apache %s because it hasn't been enabled in options.conf\n" "${OPT_APACHE_VER}"
    return
  fi

  printf "Starting Apache installation\n"

  ## PB: Verify: Needed?
  if [ ! -x "${APACHE_HTTPD}" ]; then
    FIRST_TIME_INSTALL="YES"
  else
    FIRST_TIME_INSTALL="NO"
  fi

  ### Main Installation
  if [ -z "${APACHE24_MAKE_SET}" ] && [ -z "${APACHE24_MAKE_UNSET}" ] &&
    [ "${OPT_HARDEN_SYMLINKS_PATCH}" = "NO" ] && [ "${OPT_SUEXEC}" = "NO" ]; then
    pkgi "${PORT_APACHE24}"
  else
    readonly WWW_APACHE24_PATCHDIR=$(${MAKE} -C ${PORTS_BASE}/${PORT_APACHE24} make -V PATCHDIR)
    readonly WWW_APACHE24_WRKSRC=$(${MAKE} -C ${PORTS_BASE}/${PORT_APACHE24} make -V WRKSRC)

    ## Start with a clean working directory
    ${MAKE} -DNO_DIALOG -C "${PORTS_BASE}/${PORT_APACHE24}" distclean clean

    if [ "${OPT_APACHE_VER}" = "2.4" ]; then
      if [ "${OPT_HARDEN_SYMLINKS_PATCH}" = "YES" ]; then
          printf "Copying Apache 2.4 Harden Symlink patches to %s\n" "${WWW_APACHE24_PATCHDIR}"
          cp -f "${PB_PATCHES}/${PORT_APACHE24}/patch-include_http__core.h" "${WWW_APACHE24_PATCHDIR}"
          cp -f "${PB_PATCHES}/${PORT_APACHE24}/patch-server_core.c" "${WWW_APACHE24_PATCHDIR}"
      fi

      printf "Copying Apache 2.4 suexec patches to %s\n" "${WWW_APACHE24_PATCHDIR}"
      cp -f "${PB_PATCHES}/${PORT_APACHE24}/patch-modules_generators_mod__suexec.c" "${WWW_APACHE24_PATCHDIR}"
      cp -f "${PB_PATCHES}/${PORT_APACHE24}/patch-support_suexec.c" "${WWW_APACHE24_PATCHDIR}"
      cp -f "${PB_PATCHES}/${PORT_APACHE24}/patch-configure.in" "${WWW_APACHE24_PATCHDIR}"

      ## Todo: Missing configure.in parameters?
      # printf "Patching Apache 2.4 to allow SuexecUserGroup in a Directory context.\n"
      # cp -f "${PB_PATCHES}/${PORT_APACHE24}/patch-mod_suexec_directory" "${WWW_APACHE24_PATCHDIR}"

      ## Todo: For ModSecurity
      ## PB: Is it actually found here? /usr/src/contrib/apr-util/dbm/sdbm/sdbm_private.h
      # if [ -d "${WWW_APACHE24_WRKSRC}/srclib/apr-util" ]; then
      #   printf "Patching srclib/apr-util/dbm/sdbm/sdbm_private.h..."
      #   #cd srclib/apr-util
      #   #patch -p0 < ${PB_PATH}/patches/sdbm_private.patch
      #   #cd ../../
      # fi
    fi

    ## Research: patch for users override
    # USERS=${APACHE_USER} GROUPS=${APACHE_GROUP}

    ## Option hints from /usr/ports/Mk/bsd.apache.mk
    ${MAKE} -DNO_DIALOG -C "${PORTS_BASE}/${PORT_APACHE24}" rmconfig
    ${MAKE} -DNO_DIALOG -C "${PORTS_BASE}/${PORT_APACHE24}" \
    www_apache24_SET="${APACHE24_MAKE_SET}" \
    www_apache24_UNSET="${APACHE24_MAKE_UNSET}" \
    OPTIONS_SET="${GLOBAL_MAKE_SET}" \
    OPTIONS_UNSET="${GLOBAL_MAKE_UNSET}" \
    SUEXEC_CALLER="${APACHE_USER}" \
    SUEXEC_UIDMIN=100 \
    SUEXEC_GIDMIN=100 \
    SUEXEC_SAFEPATH="/usr/local/bin:/usr/bin:/bin" \
    SUEXEC_SAFEDIR="/usr/local/safe-bin" \
    SUEXEC_DOCROOT="/" \
    SUEXEC_LOGFILE="${LOGS}/httpd/suexec.log" \
    SUEXEC_USERDIR="public_html" \
    reinstall clean
  fi
    # CONFIGURE_ARGS+="--with-suexec-safedir=/usr/local/safe-bin" \

  ## Update /boot/loader.conf
  ${SYSRC} -f /boot/loader.conf accf_http_load="YES"
  ${SYSRC} -f /boot/loader.conf accf_data_load="YES"

  ## Load the modules now to avoid restarting
  /sbin/kldload -q accf_http
  /sbin/kldload -q accf_data

  ## Update /etc/rc.conf
  ${SYSRC} apache24_enable="YES"
  ${SYSRC} apache24_http_accept_enable="YES"

  ## Todo: Implement HTCacheClean
  # ${SYSRC} htcacheclean_enable="YES"
  # htcacheclean_enable="${htcacheclean_enable:-"NO"}"
  # htcacheclean_cache="${htcacheclean_cache:-"/usr/local/www/proxy"}"
  # htcacheclean_cachelimit="${htcacheclean_cachelimit:-"512M"}"
  # htcacheclean_interval="${htcacheclean_interval:-"60"}"
  # htcacheclean_args="${htcacheclean_args:-"-t -n -i"}"

  ## PB: Verify:
  ## Copy over base configuration files to etc/apache24/:
  if [ -d "${PB_CONFIG}/ap2/conf/" ]; then
    cp -rf "${PB_CONFIG}/ap2/conf/" "${APACHE_PATH}/"
    # cp -f "${PB_CONFIG}/ap2/conf/httpd.conf" "${APACHE_CONF}"
    # cp -f "${PB_CONFIG}/ap2/conf/extra/httpd-mpm.conf" ${APACHE_EXTRAS}/httpd-mpm.conf
  fi

  ## Copy over modified (custom) configuration files to etc/apache24/:
  if [ -d "${PB_CUSTOM}/ap2/conf/" ]; then
    cp -rf "${PB_CUSTOM}/ap2/conf/" "${APACHE_PATH}/"
    # cp -f "${PB_CUSTOM}/ap2/conf/httpd.conf" "${APACHE_CONF}"
    # cp -f "${PB_CUSTOM}/ap2/conf/extra/httpd-mpm.conf" ${APACHE_EXTRAS}/httpd-mpm.conf
  fi

  ## This is already done (Apache 2.4 default)
  ${PERL} -pi -e 's/^DefaultType/#DefaultType/' ${APACHE_CONF}

  ${CHMOD} 710 "${APACHE_PATH}"

  ## Update directadmin.conf (template) with new paths:
  setVal apache_ver 2.0 "${DA_CONF_TEMPLATE}"
  setVal apacheconf "${APACHE_EXTRAS}/directadmin-vhosts.conf" "${DA_CONF_TEMPLATE}"
  setVal apacheips "${APACHE_PATH}/ips.conf" "${DA_CONF_TEMPLATE}"
  setVal apachemimetypes "${APACHE_MIME_TYPES}" "${DA_CONF_TEMPLATE}"
  setVal apachecert "${APACHE_SSL_CRT}" "${DA_CONF_TEMPLATE}"
  setVal apachekey "${APACHE_SSL_KEY}" "${DA_CONF_TEMPLATE}"
  setVal apacheca "${APACHE_SSL_CA}" "${DA_CONF_TEMPLATE}"
  setVal apache_pid /var/run/httpd.pid "${DA_CONF_TEMPLATE}"
  setVal htpasswd "${APACHE_HTPASSWD}" "${DA_CONF_TEMPLATE}"
  setVal cloud_cache 0 "${DA_CONF_TEMPLATE}"
  setVal nginx 0 "${DA_CONF_TEMPLATE}"

  ## Update existing directadmin.conf file if present
  if [ -s "${DA_CONF}" ]; then
    setVal apache_ver 2.0 "${DA_CONF}"
    setVal apacheconf "${APACHE_EXTRAS}/directadmin-vhosts.conf" "${DA_CONF}"
    setVal apacheips ${APACHE_PATH}/ips.conf "${DA_CONF}"
    setVal apachemimetypes "${APACHE_MIME_TYPES}" "${DA_CONF}"
    setVal apachecert "${APACHE_SSL_CRT}" "${DA_CONF}"
    setVal apachekey "${APACHE_SSL_KEY}" "${DA_CONF}"
    setVal apacheca "${APACHE_SSL_CA}" "${DA_CONF}"
    setVal apache_pid /var/run/httpd.pid "${DA_CONF}"
    setVal htpasswd "${APACHE_HTPASSWD}" "${DA_CONF}"
    setVal cloud_cache 0 "${DA_CONF}"
    setVal nginx 0 "${DA_CONF}"
  fi

  ## Setup initial httpd.conf file for user 'admin'
  ADMIN_HTTP="${DA_PATH}/data/users/admin/httpd.conf"
  if [ ! -e "${ADMIN_HTTP}" ] && [ -d "${DA_PATH}/data/users/admin" ]; then
    printf "" > "${ADMIN_HTTP}"
    ${CHOWN} "diradmin:${DA_ADMIN_USER}" "${ADMIN_HTTP}"
    ${CHMOD} 640 "${ADMIN_HTTP}"
  fi

  ## Create httpd log directories
  if [ ! -d "${LOGS}/httpd/domains" ]; then
    ${MKDIR} -p "${LOGS}/httpd/domains"
    ${CHMOD} 711 "${LOGS}/httpd"
  fi

  addUserGroup "${APACHE_USER}" "${APACHE_GROUP}"

  ## Backup SSL Certificates and httpd.conf
  backup_http

  if [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
    setVal nginx_proxy 1 "${DA_CONF_TEMPLATE}"
    setVal nginx_proxy 1 "${DA_CONF}"
    setVal litespeed 0 "${DA_CONF_TEMPLATE}"
    setVal litespeed 0 "${DA_CONF}"
    set_service litespeed delete
    ${KILLALL} litespeed >/dev/null 2>&1
    ${KILLALL} -9 litespeed >/dev/null 2>&1
    directadmin_restart
  elif [ "${OPT_WEBSERVER}" = "apache" ]; then
    setVal nginx_proxy 0 "${DA_CONF_TEMPLATE}"
    setVal nginx_proxy 0 "${DA_CONF}"
    setVal litespeed 0 "${DA_CONF_TEMPLATE}"
    setVal litespeed 0 "${DA_CONF}"
    ${KILLALL} nginx >/dev/null 2>&1
    ${KILLALL} litespeed >/dev/null 2>&1
    directadmin_restart
    set_service nginx delete
    set_service litespeed delete
    ${KILLALL} -9 nginx >/dev/null 2>&1
    ${KILLALL} -9 litespeed >/dev/null 2>&1
    ${SYSRC} -q -x nginx_enable
  fi

  ## Verify:
  # if [ "${OPT_WEBSERVER}" = "apache" ] || [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then ## || [ ! -e "${APACHE_HTTPD}" ]
  #   set_service apache24 ON
  # fi

  ${CHOWN} "${WEBAPPS_USER}:${APACHE_GROUP}" "${WWW_DIR}"
  ${CHMOD} 551 "${WWW_DIR}"

  restore_http

  ## PB: Verify: Needed?
  # if [ "${FIRST_TIME_INSTALL}" = "NO" ]; then
  #   ## Start Apache
  #   ${SERVICE} apache24 start
  # fi

  HAVE_DACONF=0
  if [ -s "${DA_CONF}" ]; then
    HAVE_DACONF=1
  fi

  ## PB: Verify: Still need to reference httpd-directories-old.conf?
  ## CB2: Copy the new configs if needed
  if [ "$(grep -m1 -c 'Include' "${APACHE_EXTRAS}/directadmin-vhosts.conf")" = "0" ] || [ ! -e "${APACHE_EXTRAS}/directadmin-vhosts.conf" ]; then

    cp -rf "${PB_CONFIG}/ap2/conf/" "${APACHE_PATH}/"

    HDC="${APACHE_EXTRAS}/httpd-directories-old.conf"

    ln -sf "${HDC}" "${APACHE_EXTRAS}/httpd-directories.conf"

    apache_host_conf

    ## Verify: Custom Configurations
    if [ "${APCUSTOMCONFDIR}" != "0" ]; then
      cp -rf "${APCUSTOMCONFDIR}" "${APACHE_PATH}"
    fi
  fi

  create_httpd_nginx

  ## Hide frontpage (from CB2: hideFrontpage())
  # if [ -e "${DA_CONF_TEMPLATE}" ] && [ "$(grep -m1 -c frontpage_on "${DA_CONF_TEMPLATE}")" = "0" ]; then
  setVal frontpage_on 0 "${DA_CONF_TEMPLATE}"
  # fi

  ## Existing DirectAdmin installation
  if [ -e "${DA_CONF}" ] && [ "$(grep -m1 -c frontpage_on "${DA_CONF}")" = "0" ]; then
    setVal frontpage_on 0 "${DA_CONF}"
    if [ -e "${DA_PATH}/data" ]; then
      echo "action=directadmin&value=reload" >> "${DA_TASK_QUEUE}"
    fi
  fi

  ## CB2: Make sure the correct apache_ver is set in directadmin.conf
  ## PB: Needed? Default is 2.0 for new installs
  if [ "$(grep -m1 -c apache_ver=2.0 "${DA_CONF_TEMPLATE}")" -eq "0" ]; then
    setVal apache_ver 2.0 "${DA_CONF_TEMPLATE}"
    echo "action=rewrite&value=httpd" >> "${DA_TASK_QUEUE}"
    directadmin_restart
  elif [ "$(grep -m1 -c apache_ver=2.0 "${DA_CONF_TEMPLATE}")" -ne "0" ]; then
    ${PERL} -pi -e "s/$(grep -m1 apache_ver= ${DA_CONF_TEMPLATE})/apache_ver=2.0/" "${DA_CONF_TEMPLATE}"
  fi

  ## Existing DirectAdmin installation
  ## PB: Needed? Default is 2.0 for new installs
  if [ "${HAVE_DACONF}" = "1" ]; then
    if [ "$(grep -m1 -c apache_ver=2.0 "${DA_CONF}")" -eq "0" ]; then
      setVal apache_ver 2.0 "${DA_CONF}"
      directadmin_restart
      echo "action=rewrite&value=httpd" >> "${DA_TASK_QUEUE}"
    elif [ "$(grep -m1 -c apache_ver=2.0 "${DA_CONF}")" -ne "0" ]; then
      ${PERL} -pi -e "s/$(grep -m1 apache_ver= ${DA_CONF})/apache_ver=2.0/" "${DA_CONF}"
      directadmin_restart
      echo "action=rewrite&value=httpd" >> "${DA_TASK_QUEUE}"
    fi
  fi

  fpmChecks

  dovecot_checks

  if [ "${HAVE_FPM_CGI}" = "YES" ]; then
    ${PERL} -pi -e 's/nginx/apache/' "${DA_PATH}/data/templates/php-fpm.conf"
  fi

  verify_server_ca

  do_rewrite_httpd_alias

  ## CB2: Rewrite ips.conf if needed
  echo "action=rewrite&value=ips" >> "${DA_TASK_QUEUE}"
  echo "action=rewrite&value=httpd" >> "${DA_TASK_QUEUE}"

  run_dataskq

  ## CB2: Tokenize the IP and ports if needed
  tokenize_IP
  tokenize_ports

  ## CB2: Add all the Include lines if they do not exist (or if directadmin-vhosts.conf doesn't exist)
  if [ "$(grep -m1 -c 'Include' "${APACHE_EXTRAS}/directadmin-vhosts.conf")" = "0" ] ||
    [ ! -e "${APACHE_EXTRAS}/directadmin-vhosts.conf" ]; then
    rewrite_vhosts
  fi

  ## Generate self-signed SSL Key and Certificate for Apache if they don't exist
  if [ ! -s "${APACHE_SSL_KEY}" ] || [ ! -s "${APACHE_SSL_CRT}" ]; then
    printf "*** Notice: Generating a self-signed SSL certificate and key for Apache.\n"

    ${MKDIR} -p "${APACHE_PATH}/ssl"

    ${OPENSSL} req -x509 -newkey rsa:2048 -keyout "${APACHE_SSL_KEY}" \
    -out "${APACHE_SSL_CRT}" -days 9999 -nodes -config "${SSL_REQ_CONF}"

    ${CHMOD} 600 "${APACHE_SSL_CRT}"
    ${CHMOD} 600 "${APACHE_SSL_KEY}"
  fi

  doApacheCheck

  if [ ! -d "${WWW_DIR}" ]; then
    printf "*** Notice: Creating directory: %s\n" "${WWW_DIR}"
    ${MKDIR} -p "${WWW_DIR}"
  fi

  ## Create default "blank" page
  if [ ! -e "${WWW_DIR}/index.html" ]; then
    if [ -e "${WWW_DIR}/index.html.en" ]; then
      cp -f "${WWW_DIR}/index.html.en" "${WWW_DIR}/index.html"
    else
      printf "*** Notice: Creating default index.html under %s\n" "${WWW_DIR}"
      printf "<html>\n<head>\n<title>Default Page</title>\n</head>\n<body>\n \
      <p>Apache is functioning normally</p>\n</body>\n</html>\n" > "${WWW_DIR}/index.html"
    fi
  fi

  ## If we were switching from Nginx to Apache:
  ${PERL} -pi -e 's/Nginx/Apache/' "${WWW_DIR}/index.html"

  ## Safe-bin directory
  if [ ! -d /usr/local/safe-bin ]; then
    printf "*** Notice: Creating directory: /usr/local/safe-bin\n"
    ${MKDIR} -p /usr/local/safe-bin
    ${CHMOD} 511 /usr/local/safe-bin
    ${CHOWN} "${APACHE_USER}:${APACHE_GROUP}" /usr/local/safe-bin
  fi

  ## CB2: Make sure apr is linked correctly
  ## PB: FreeBSD: /usr/local/bin/apr-1-config
  ## PB: Needed?
  # if [ -e /usr/bin/apr-1-config ]; then
  #   ln -sf /usr/bin/apr-1-config /usr/bin/apr-config
  # fi

  PHPMODULES="${APACHE_EXTRAS}/httpd-phpmodules.conf"

  if [ -e "${PHPMODULES}" ]; then
    if [ "${OPT_MODSECURITY}" = "YES" ] && [ ! -e "${APACHE_LIBS}/mod_security2.so" ] && [ "${OPT_WEBSERVER}" = "apache" ]; then
      modsecurity_install
    fi

    COUNT="$(grep -m1 -c 'httpd-modsecurity' ${PHPMODULES})"
    if [ "${OPT_MODSECURITY}" = "YES" ] && [ "${OPT_WEBSERVER}" = "apache" ] && [ "${COUNT}" -eq 0 ]; then
      ${PERL} -pi -e 's|^LoadModule security2_module|#LoadModule security2_module|' "${APACHE_CONF}"
      printf "Include %s/httpd-modsecurity.conf\n" "${APACHE_EXTRAS}" >> "${PHPMODULES}"
      cp -pf "${MODSECURITY_APACHE_INCLUDE}" "${APACHE_EXTRAS}/httpd-modsecurity.conf"
    fi

    ## Figure out which Apache MPM module we need to load
    if ! grep -m1 -q "${APACHE_LIBS}/mod_mpm_" "${PHPMODULES}"; then
      ## CB2: Use event MPM for php-fpm and prefork for mod_php
      if [ "${OPT_APACHE_MPM}" = "auto" ]; then
        if [ "${HAVE_CLI}" = "NO" ]; then
          printf "LoadModule mpm_event_module %s/mod_mpm_event.so\n" "${APACHE_LIBS}" >> "${PHPMODULES}"
        else
          printf "LoadModule mpm_prefork_module %s/mod_mpm_prefork.so\n" "${APACHE_LIBS}" >> "${PHPMODULES}"
        fi
      elif [ "${OPT_APACHE_MPM}" = "event" ]; then
        printf "LoadModule mpm_event_module %s/mod_mpm_event.so\n" "${APACHE_LIBS}" >> "${PHPMODULES}"
      elif [ "${OPT_APACHE_MPM}" = "worker" ]; then
        printf "LoadModule mpm_worker_module %s/mod_mpm_worker.so\n" "${APACHE_LIBS}" >> "${PHPMODULES}"
      else
        printf "LoadModule mpm_prefork_module %s/mod_mpm_prefork.so\n" "${APACHE_LIBS}" >> "${PHPMODULES}"
      fi
    fi

    ## Todo: HTScanner
    if [ "${OPT_HTSCANNER}" = "YES" ]; then
      if [ "${OPT_WEBSERVER}" = "apache" ]  || [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
        if [ "${HAVE_FCGID}" = "YES" ] || [ "${HAVE_FPM_CGI}" = "YES" ] || [ "${HAVE_SUPHP_CGI}" = "YES" ]; then
          if ! grep -m1 -c 'htscanner_module' ${PHPMODULES}; then
            ${PERL} -pi -e 's|^LoadModule htscanner_module|#LoadModule htscanner_module|' ${APACHE_CONF}
            printf "LoadModule htscanner_module %s/mod_htscanner2.so\n" "${APACHE_LIBS}" >> "${PHPMODULES}"
          else
            ${PERL} -pi -e 's|^LoadModule htscanner_module|#LoadModule htscanner_module|' "${APACHE_CONF}"
            ${PERL} -pi -e 's|^LoadModule  htscanner_module|^#LoadModule htscanner_module' "${PHPMODULES}"
          fi
          install_mod_htscanner
        fi
      fi
    fi

    ## suPHP:
    if [ "${HAVE_SUPHP_CGI}" = "YES" ]; then
      if ! grep -m1 -q 'suphp_module' "${PHPMODULES}"; then
        ${PERL} -pi -e 's|^LoadModule suphp_module|#LoadModule suphp_module|' "${APACHE_CONF}"
        printf "LoadModule suphp_module %s/mod_suphp.so\n" "${APACHE_LIBS}" >> "${PHPMODULES}"
      fi
    fi

    ## FCGID:
    if [ "${HAVE_FCGID}" = "YES" ]; then
      if [ ! -s "${APACHE_LIBS}/mod_fcgid.so" ]; then
        install_mod_fcgid
      fi
      if ! grep -m1 -q 'fcgid_module' "${PHPMODULES}"; then
        ${PERL} -pi -e 's|^LoadModule  mod_fcgid|#LoadModule mod_fcgid|' "${APACHE_CONF}"
        printf "LoadModule fcgid_module %s/mod_fcgid.so\n " "${APACHE_LIBS}" >> "${PHPMODULES}"
      fi
      if ! grep -m1 -q 'httpd-fcgid.conf' "${PHPMODULES}"; then
        printf "Include %s/httpd-fcgid.conf\n" "${APACHE_EXTRAS}" >> "${PHPMODULES}"
      fi
    fi

    ## HTScanner
    if [ "${HAVE_FCGID}" = "YES" ] || [ "${HAVE_FPM_CGI}" = "YES" ] || [ "${HAVE_SUPHP_CGI}" = "YES" ]; then
      if [ "${OPT_WEBSERVER}" = "apache" ] || [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
        if [ "${OPT_HTSCANNER}" = "YES" ] && [ ! -e "${APACHE_LIBS}/mod_htscanner2.so" ]; then
          install_mod_htscanner
        fi
      fi
    fi
  fi

  ## CB2: Make sure there is no SSLMutex in /usr/local/etc/apache24/extra/httpd-ssl.conf
  ## CB2: Make sure there is no LockFile in /usr/local/etc/apache24/extra/httpd-mpm.conf
  if [ "${OPT_APACHE_VER}" = "2.4" ]; then
    ${PERL} -pi -e 's/^SSLMutex/#SSLMutex/' "${APACHE_EXTRAS}/httpd-ssl.conf"
    ${PERL} -pi -e 's/^LockFile/#LockFile/' "${APACHE_EXTRAS}/httpd-mpm.conf"
  fi

  ## Disable UserDir access if userdir_access=no is set in the options.conf file
  if [ "${OPT_USERDIR_ACCESS}" = "NO" ]; then
    ${PERL} -pi -e 's#UserDir public_html#UserDir disabled#' "${APACHE_EXTRAS}/httpd-vhosts.conf"
  else
    ${PERL} -pi -e 's#UserDir disabled#UserDir public_html#' "${APACHE_EXTRAS}/httpd-vhosts.conf"
  fi

  ## CB2: doModHostingLimits 0
  ## CB2: doModLsapi 0
  ## CB2: ldconfig

  ## PB: Moved this out of COMPAT
  if [ -e "${APACHE_HTTPD}" ]; then
    ln -sf "${APACHE_HTTPD}" /usr/sbin/httpd
  fi

  if [ "${COMPAT_APACHE24_SYMLINKS}" = "YES" ]; then
    printf "PortsBuild+DirectAdmin Compatibility mode: Creating symlinks for Apache\n"

    ## 2016-03-05: no longer needed?
    ${MKDIR} -p /etc/httpd
    ln -sf "${APACHE_PATH}" /etc/httpd/conf

    ## PB: Not needed?
    # ln -sf /var/www/build /etc/httpd/build

    ## CustomBuild2 looking for Apache modules in ?*
    ## Symlink for backcomp (done):
    ## 2016-03-05: no longer needed?
    # mkdir -p ${APACHE_LIBS}
    # ln -s ${APACHE_LIBS} xyz/usr/.../../

    ## Since DirectAdmin/CB2 reference /var/www/html often, we'll symlink for compat:
    ${MKDIR} -p /var/www
    ln -s "${WWW_DIR}" /var/www/html
    ${CHOWN} -h "${WEBAPPS_USER}:${WEBAPPS_GROUP}" /var/www/html

    # touch /etc/httpd/conf/ssl.crt/server.crt
    # touch /etc/httpd/conf/ssl.key/server.key
    # touch ${APACHE_PATH}/ssl/server.crt
    # touch ${APACHE_PATH}/ssl/server.key

    ## 2016-03-05: no longer needed?
    ${MKDIR} -p /etc/httpd/conf/ssl.crt
    ${MKDIR} -p /etc/httpd/conf/ssl.key

    ln -s "${APACHE_SSL_CRT}" /etc/httpd/conf/ssl.crt/server.crt
    ln -s "${APACHE_SSL_KEY}" /etc/httpd/conf/ssl.key/server.key
    ln -s "${APACHE_SSL_CA}" /etc/httpd/conf/ssl.crt/server.ca

    ln -s "${APACHE_SSL_CRT}" "${APACHE_PATH}/ssl.crt/server.crt"
    ln -s "${APACHE_SSL_KEY}" "${APACHE_PATH}/ssl.key/server.key"
    ln -s "${APACHE_SSL_CA}" "${APACHE_PATH}/ssl.crt/server.ca"
  fi

  if [ "${OPT_WEBSERVER}" = "apache" ] || [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
    printf "Restarting Apache\n"
    ${SERVICE} apache24 restart
  fi

  printf "Apache %s installation has been completed.\n" "${OPT_APACHE_VER}"

  return
}

################################################################################
## Apache Uninstall
################################################################################

apache_uninstall() {

  printf "Uninstalling Apache\n"

  ${SERVICE} apache24 stop

  pkgd apache24

  ${SYSRC} -q -x apache24_enable
  ${SYSRC} -q -x apache24_http_accept_enable

  rm /usr/sbin/httpd

  return
}

################################################################################
## Install mod_htscanner (from CB2: doModHtscanner())
################################################################################

install_mod_htscanner() {

  local PHPMODULES

  if [ "${OPT_HTSCANNER}" = "NO" ]; then
    printf "*** Notice: HTSCANNER is not enabled in options.conf.\n"
    return
  fi

  pkgi "${PORT_HTSCANNER}"

  ## PB: Verify:
  # ${APXS} -a -i -c mod_htscanner2.c

  PHPMODULES="${APACHE_EXTRAS}/httpd-phpmodules.conf"

  if [ -e "${PHPMODULES}" ]; then
    ${PERL} -pi -e 's|^LoadModule htscanner_module|#LoadModule htscanner_module|' "${APACHE_CONF}"
    if ! grep -m1 -q 'htscanner_module' ${PHPMODULES}; then
      printf "LoadModule htscanner_module %s/mod_htscanner2.so\n" "${APACHE_LIBS}" >> "${PHPMODULES}"
    fi
  fi

  echo "action=rewrite&value=httpd" >> "${DA_TASK_QUEUE}"

  run_dataskq

  printf "mod_htscanner has been installed successfully.\n"

  return
}

################################################################################
## Verify: Install Let's Encrypt
################################################################################

letsencrypt_install() {

  if [ "${OPT_LETSENCRYPT}" = "NO" ]; then
    printf "*** Notice: LETSENCRYPT is not enabled in options.conf.\n"
    return
  fi

  ## DirectAdmin Version of Let's Encrypt
  ${WGET} -O "${DA_SCRIPTS}/letsencrypt.sh" http://files.directadmin.com/services/all/letsencrypt.sh

  ${CHOWN} diradmin:diradmin "${DA_SCRIPTS}/letsencrypt.sh"
  ${CHMOD} 700 "${DA_SCRIPTS}/letsencrypt.sh"

  ## Enable in DA's options.conf
  setVal letsencrypt 1 "${DA_CONF}"
  setVal letsencrypt 1 "${DA_CONF_TEMPLATE}"

  return
}

################################################################################
## Uninstall Let's Encrypt
################################################################################

letsencrypt_uninstall() {

  return
}

################################################################################
## Verify: Install mod_fcgid (from CB2: doModFCGID())
################################################################################

install_mod_fcgid() {

  local PHPMODULES

  if [ "${OPT_WEBSERVER}" = "nginx" ]; then
    printf "*** Error: Cannot install mod_fcgid, because WEBSERVER is set to nginx in options.conf.\n"
    exit 1
  fi

  ## Todo: getFile fcgid.sh fcgid_sh
  # cp

  PHPMODULES="${APACHE_EXTRAS}/httpd-phpmodules.conf"

  if [ -e "${PHPMODULES}" ]; then
    if ! grep -m1 -q 'fcgid_module' "${PHPMODULES}"; then
      ${PERL} -pi -e 's|^LoadModule  fcgid_module|#LoadModule  fcgid_module|' "${APACHE_CONF}"
      printf "LoadModule fcgid_module %s/mod_fcgid.so" "${APACHE_LIBS}" >> "${PHPMODULES}"
    fi

    if ! grep -m1 -q 'httpd-fcgid.conf' "${PHPMODULES}"; then
      printf "Include %s/httpd-fcgid.conf" "${APACHE_EXTRAS}" >> "${PHPMODULES}"
    fi
  fi

  ## Copy configuration
  if [ ! -e "${APACHE_EXTRAS}/httpd-fcgid.conf" ] && [ -e "${PB_CONFIG}/ap2/conf/extra/httpd-fcgid.conf" ]; then
    cp "${PB_CONFIG}/ap2/conf/extra/httpd-fcgid.conf" "${APACHE_PATH}/extra/httpd-fcgid.conf"
  fi

  echo "action=rewrite&value=httpd" >> "${DA_TASK_QUEUE}"
  run_dataskq

  printf "mod_fcgid has been installed successfully.\n"

  return
}

################################################################################
## Todo: NGINX Installation
################################################################################

nginx_install() {

  if [ "${OPT_WEBSERVER}" != "nginx" ] || [ "${OPT_WEBSERVER}" != "nginx_apache" ]; then
    printf "*** Notice: WEBSERVER not set to NGINX or NGINX_APACHE in options.conf\n"
    return
  fi

  printf "Starting Nginx installation\n"

  ### Main Installation
  if [ -z "${NGINX_MAKE_SET}" ] && [ -z "${NGINX_MAKE_UNSET}" ]; then
    pkgi "${PORT_NGINX}"
  else
    ${MAKE} -DNO_DIALOG -C "${PORTS_BASE}/${PORT_NGINX}" rmconfig
    ${MAKE} -DNO_DIALOG -C "${PORTS_BASE}/${PORT_NGINX}" \
    www_nginx_SET="${NGINX_MAKE_SET}" \
    www_nginx_UNSET="${NGINX_MAKE_UNSET}" \
    OPTIONS_SET="${GLOBAL_MAKE_SET}" \
    OPTIONS_UNSET="${GLOBAL_MAKE_UNSET}" \
    reinstall clean
  fi

  # setVal nginx 1 ${DA_CONF}
  # setVal apache 0 ${DA_CONF}

  ## Update directadmin.conf (template)
  setVal nginxconf "${NGINX_PATH}/directadmin-vhosts.conf" "${DA_CONF_TEMPLATE}"
  setVal nginxips "${NGINX_PATH}/directadmin-ips.conf" "${DA_CONF_TEMPLATE}"
  setVal nginxlogdir "${LOGS}/nginx/domains" "${DA_CONF_TEMPLATE}"
  setVal nginx_pid /var/run/nginx.pid "${DA_CONF_TEMPLATE}"
  setVal nginx_cert "${NGINX_SSL_CRT}" "${DA_CONF_TEMPLATE}"
  setVal nginx_key "${NGINX_SSL_KEY}" "${DA_CONF_TEMPLATE}"
  setVal nginx_ca "${NGINX_SSL_CA}" "${DA_CONF_TEMPLATE}"

  ## Update directadmin.conf with new paths
  if [ -e "${DA_CONF}" ]; then
    setVal nginxconf "${NGINX_PATH}/directadmin-vhosts.conf" "${DA_CONF}"
    setVal nginxips "${NGINX_PATH}/directadmin-ips.conf" "${DA_CONF}"
    setVal nginxlogdir "${LOGS}/nginx/domains" "${DA_CONF}"
    setVal nginx_pid /var/run/nginx.pid "${DA_CONF}"
    setVal nginx_cert "${NGINX_SSL_CRT}" "${DA_CONF}"
    setVal nginx_key "${NGINX_SSL_KEY}" "${DA_CONF}"
    setVal nginx_ca "${NGINX_SSL_CA}" "${DA_CONF}"
  fi

  ## Update /etc/rc.conf
  ${SYSRC} nginx_enable="YES"

  ## Add 'nginx' user into 'access' group:
  addUserGroup "${NGINX_USER}" access

  # ${PW} groupadd ${WEBAPPS_USER} 2> /dev/null
  # ${PW} useradd -g ${WEBAPPS_USER} -n ${WEBAPPS_USER} -b ${WWW_DIR} -s /sbin/nologin 2> /dev/null

  ## Nginx+Apache:
  if [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
    ${SYSRC} apache24_enable="YES"
    ${SYSRC} apache24_http_accept_enable="YES"
  else
    ${SYSRC} -q -x apache24_enable
    ${SYSRC} -q -x apache24_http_accept_enable
  fi

  ## Start nginx
  ${SERVICE} nginx start

  return
}

################################################################################
## Uninstall nginx
################################################################################

nginx_uninstall() {

  printf "Uninstalling Nginx\n"

  ${SERVICE} nginx stop

  pkgd "${PORT_NGINX}"

  ${SYSRC} -q -x nginx_enable

  return
}

################################################################################
## Majordomo Install
################################################################################

majordomo_install() {

  if [ "${OPT_MAJORDOMO}" = "NO" ]; then
    printf "*** Notice: Majordomo not enabled in options.conf\n"
    return
  fi

  if [ -e "${PB_PATH}/directadmin/scripts/custom/majordomo.sh" ]; then
    printf "Starting Majordomo installation\n"
    ${CHMOD} +x "${PB_PATH}/directadmin/scripts/custom/majordomo.sh"
    "${PB_PATH}/directadmin/scripts/custom/majordomo.sh"
  else
    printf "*** Error: Majordomo installation script not found.\n"
  fi

  return
}

################################################################################
## Majordomo Uninstall
################################################################################

majordomo_uninstall() {

  printf "Majordomo uninstall not implemented.\n"

  return
}

################################################################################
## Todo: Fix FTP Accounts
## From: https://help.directadmin.com/item.php?id=205
################################################################################

fix_ftp_accounts() {

  local FTP_SHADOW UUID UGID FTP_COUNT PF
  local IFS=' '

  shift

  PF="${1}"

  printf "*** Notice: Fixing FTP Accounts (argument: %s)\n" "${PF}"

  if [ ! -e "${DA_PATH}/data/users" ]; then
    printf "*** Error: DirectAdmin users directory not found.\n"
    exit 1
  fi

  for u in ${DA_PATH}/data/users ; do {
    if [ ! -d "${u}" ]; then
      continue
    fi

    FTP_SHADOW="/home/${u}/.shadow"
    if [ ! -e "${FTP_SHADOW}" ]; then
      continue
    fi

    ## DA: Make sure it doesn't already exist
    FTP_COUNT=$(grep -c -e "^${u}:" "${PF}")
    if [ "${FTP_COUNT}" -ne 0 ]; then
      continue
    fi

    UUID=$(id -u "${u}")
    UGID=$(id -g "${u}")

    echo "${u}:$(cat "/home/${u}/.shadow"):${UUID}:${UGID}:system:/home/${u}:/bin/false"
  }
  done
}

################################################################################
## PureFTPD Installation
################################################################################

pureftpd_install() {

  local PUREFTPD_PEM PUREFTPD_LOG PUREFTPD_DB PUREFTPD_PASSWD
  local PUREFTPD_DHPARAMS_PEM PUREPW

  ## From pureftpd's README.Virtual-Users
  ## https://download.pureftpd.org/pub/pure-ftpd/doc/README.Virtual-Users
  # If defined, a PURE_PASSWDFILE environment variable can set the default path
  # to the pureftpd.passwd file. Without this variable, it defaults to
  # /etc/pureftpd.passwd
  # If defined, a PURE_DBFILE environment variable can set the default path
  # to the pureftpd.pdb file. Without this variable, it defaults to
  # /etc/pureftpd.pdb

  PUREPW=/usr/local/bin/pure-pw
  PURECONF=/usr/local/etc/pure-ftpd.conf
  PUREFTPD_PEM=/etc/ssl/private/pure-ftpd.pem
  PUREFTPD_DHPARAMS_PEM=/usr/local/etc/pure-ftpd-dhparams.pem
  PUREFTPD_LOG="${LOGS}/pureftpd.log"
  PUREFTPD_DB=/etc/pureftpd.pdb
  PUREFTPD_PASSWD=/etc/pureftpd.passwd

  if [ "${OPT_FTPD}" != "pureftpd" ]; then
    printf "*** Notice: FTPD not set to PUREFTPD in options.conf\n"
    return
  fi

  printf "Starting PureFTPD installation\n"

  ### Main Installation
  if [ -z "${PUREFTPD_MAKE_SET}" ] && [ -z "${PUREFTPD_MAKE_UNSET}" ]; then
    pkgi "${PORT_PUREFTPD}"
  else
    ${MAKE} -DNO_DIALOG -C "${PORTS_BASE}/${PORT_PUREFTPD}" rmconfig
    ${MAKE} -DNO_DIALOG -C "${PORTS_BASE}/${PORT_PUREFTPD}" \
    ftp_pure_ftpd_SET="${PUREFTPD_MAKE_SET}" \
    ftp_pure_ftpd_UNSET="${PUREFTPD_MAKE_UNSET}" \
    OPTIONS_SET="${GLOBAL_MAKE_SET}" \
    OPTIONS_UNSET="${GLOBAL_MAKE_UNSET}" \
    reinstall clean
  fi

  ## Todo:
  ## Setup SSL Certificates

  if [ ! -e /etc/ssl/private ]; then
    ${MKDIR} -p /etc/ssl/private
  fi

  if [ ! -e "${PUREFTPD_PEM}" ] && [ "${OPT_WEBSERVER}" = "nginx" ]; then
    if [ -e "${NGINX_SSL_CRT}" ] && [ -e "${NGINX_SSL_KEY}" ]; then
      cat "${NGINX_SSL_CRT}" > "${PUREFTPD_PEM}"
      cat "${NGINX_SSL_KEY}" >> "${PUREFTPD_PEM}"
    fi
  fi

  if [ ! -e "${PUREFTPD_PEM}" ]; then
    if [ -e "${APACHE_SSL_CRT}" ] && [ -e "${APACHE_SSL_KEY}" ]; then
      cat "${APACHE_SSL_CRT}" > "${PUREFTPD_PEM}"
      cat "${APACHE_SSL_KEY}" >> "${PUREFTPD_PEM}"
    fi
  fi

  if [ ! -e "${PUREFTPD_PEM}" ]; then
    if [ -e "${EXIM_SSL_CRT}" ] && [ -e "${EXIM_SSL_KEY}" ]; then
      cat "${EXIM_SSL_CRT}" > "${PUREFTPD_PEM}"
      cat "${EXIM_SSL_KEY}" >> "${PUREFTPD_PEM}"
    fi
  fi

  if [ ! -e "${PUREFTPD_DHPARAMS_PEM}" ]; then
    ${OPENSSL} dhparam -out ${PUREFTPD_DHPARAMS_PEM} 2048
  fi

  ${CHMOD} 600 "${PUREFTPD_DHPARAMS_PEM}"
  ${CHMOD} 600 "${PUREFTPD_PEM}"

  if [ "${OPT_PUREFTPD_UPLOADSCAN}" = "YES" ] && [ "${OPT_CLAMAV}" = "YES" ]; then
    if [ ! -e "${CLAMDSCAN}" ]; then
      clamav_install
    fi

    if [ ! -e "${CLAMDSCAN}" ]; then
      printf "*** Error: Cannot enable upload scanning in Pure-FTPD because there is no ClamAV (%s) on the system.\n" "${CLAMDSCAN}"
      exit 1
    fi

    printf "Enabling Pure-FTPD upload scanning script\n"
    cp -f "${PB_CONFIG}/pureftpd/pureftpd_uploadscan.sh" "${PUREFTPD_UPLOADSCAN_BIN}"
    ${CHMOD} 711 "${PUREFTPD_UPLOADSCAN_BIN}"

    ${SYSRC} pureftpd_upload_enable="YES"
    ${SYSRC} pureftpd_uploadscript="${PUREFTPD_UPLOADSCAN_BIN}"
  else
    rm -f ${PUREFTPD_UPLOADSCAN_BIN}
    ${SYSRC} -q -x pureftpd_upload_enable
    ${SYSRC} -q -x pureftpd_uploadscript
  fi

  if [ -x "${RCD}/proftpd" ]; then
    ${SERVICE} proftpd stop
    ${SYSRC} -q -x proftpd_enable
    ${SYSRC} -q -x proftpd_flags
  fi

  ${SYSRC} ftpd_enable="NO"

  ${SYSRC} pureftpd_enable="YES"
  ${SYSRC} pureftpd_flags="-B -A -C 15 -E -H -k 99 -L 10000:8 -O stats:${PUREFTPD_LOG} -l puredb:${PUREFTPD_DB} -p 35000:35999 -u 100 -U 133:022 -w -Z -Y 1 -J -S:HIGH:MEDIUM:+TLSv1:!SSLv2:+SSLv3"
  ${SYSRC} pureftpd_config=""

  ## Update directadmin.conf
  setVal pureftp 1 "${DA_CONF_TEMPLATE}"
  setVal pureftp 1 "${DA_CONF}"

  setVal pure_pw ${PUREPW} "${DA_CONF_TEMPLATE}"
  setVal pure_pw ${PUREPW} "${DA_CONF}"

  setVal ftpconfig ${PURECONF} "${DA_CONF_TEMPLATE}"
  setVal ftpconfig ${PURECONF} "${DA_CONF}"

  setVal ftppasswd_db ${PUREFTPD_DB} "${DA_CONF_TEMPLATE}"
  setVal ftppasswd_db ${PUREFTPD_DB} "${DA_CONF}"

  setVal ftppasswd ${PUREFTPD_PASSWD} "${DA_CONF_TEMPLATE}"
  setVal ftppasswd ${PUREFTPD_PASSWD} "${DA_CONF}"

  # setVal ftppasswd ${PROFTPD_PASSWD} "${DA_CONF_TEMPLATE}"
  # setVal ftppasswd ${PROFTPD_PASSWD} "${DA_CONF}"

  setVal pureftp_log ${PUREFTPD_LOG} "${DA_CONF_TEMPLATE}"
  setVal pureftp_log ${PUREFTPD_LOG} "${DA_CONF}"

  ## Create a blank file so the startup precmd routine does not complain.
  if [ ! -e ${PURECONF} ]; then
    ## cp "${PURECONF}.sample" ${PURECONF}
    ${TOUCH} ${PURECONF}
  fi

  directadmin_restart

  ## Update services.status
  set_service proftpd delete
  set_service pure-ftpd ON

  if [ ! -e ${PUREFTPD_PASSWD} ]; then
    ## fix_ftp_accounts "${PUREFTPD_PASSWD}" >> "${PUREFTPD_PASSWD}"
    ${CHMOD} 755 ${PB_PATH}/directdamin/scripts/custom/fix_ftp.sh
    ${TOUCH} ${PUREFTPD_PASSWD}
    ${PB_PATH}/directdamin/scripts/fix_ftp.sh >> ${PUREFTPD_PASSWD}
  fi

  ${CHOWN} root:ftp ${PUREFTPD_PASSWD}
  ${CHMOD} 640 ${PUREFTPD_PASSWD}

  ${PUREPW} mkdb ${PUREFTPD_DB} -f ${PUREFTPD_PASSWD}

  printf "Restarting PureFTPD\n"
  ${SERVICE} "pure-ftpd" restart

  return
}

################################################################################
## PureFTPD Uninstall
################################################################################

pureftpd_uninstall() {

  printf "Uninstalling PureFTPD\n"

  set_service pure-ftpd delete

  setVal pureftp 0 ${DA_CONF}
  setVal pureftp 0 ${DA_CONF_TEMPLATE}

  ${SERVICE} pureftpd stop

  ${SYSRC} -q -x pureftpd_enable
  ${SYSRC} -q -x pureftpd_config
  ${SYSRC} -q -x pureftpd_flags
  ${SYSRC} -q -x pureftpd_upload_enable
  ${SYSRC} -q -x pureftpd_uploadscript

  pkgd -y "${PORT_PUREFTPD}"

  rm -f ${PUREFTPD_UPLOADSCAN_BIN}

  return
}

################################################################################
## ProFTPD Installation
################################################################################

proftpd_install() {

  local PRXS

  readonly PRXS=/usr/local/bin/prxs

  if [ "${OPT_FTPD}" != "proftpd" ]; then
    printf "*** Notice: FTPD not set to PROFTPD in options.conf\n"
    return
  fi

  printf "Starting ProFTPD installation\n"

  ### Main Installation
  if [ -z "${PROFTPD_MAKE_SET}" ] && [ -z "${PROFTPD_MAKE_UNSET}" ]; then
    pkgi "${PORT_PROFTPD}"
  else
    ${MAKE} -DNO_DIALOG -C "${PORTS_BASE}/${PORT_PROFTPD}" rmconfig
    ${MAKE} -DNO_DIALOG -C "${PORTS_BASE}/${PORT_PROFTPD}" \
    ftp_proftpd_SET="${PROFTPD_MAKE_SET}" \
    ftp_proftpd_UNSET="${PROFTPD_MAKE_UNSET}" \
    OPTIONS_SET="${GLOBAL_MAKE_SET}" \
    OPTIONS_UNSET="${GLOBAL_MAKE_UNSET}" \
    reinstall clean
  fi

  ## Stop PureFTPD if it's running
  if [ -x "${RCD}/pure-ftpd" ]; then
    ${SERVICE} "pure-ftpd" onestop
  fi

  ${SYSRC} -q -x pureftpd_enable
  ${SYSRC} -q -x pureftpd_config
  ${SYSRC} -q -x pureftpd_flags
  ${SYSRC} -q -x pureftpd_upload_enable
  ${SYSRC} -q -x pureftpd_uploadscript

  ## Update directadmin.conf + template
  setVal pureftp 0 "${DA_CONF_TEMPLATE}"
  setVal ftpconfig "${PROFTPD_CONF}" "${DA_CONF_TEMPLATE}"
  setVal ftppasswd "${PROFTPD_PASSWD}" "${DA_CONF_TEMPLATE}"
  setVal ftpvhosts /usr/local/etc/proftpd.vhosts.conf "${DA_CONF_TEMPLATE}"
  # setVal ftppasswd_db /usr/local/etc/pureftpd.pdb "${DA_CONF_TEMPLATE}"

  if [ -e "${DA_CONF}" ]; then
    setVal pureftp 0 "${DA_CONF}"
    setVal ftpconfig "${PROFTPD_CONF}" "${DA_CONF}"
    setVal ftppasswd "${PROFTPD_PASSWD}" "${DA_CONF}"
    setVal ftpvhosts /usr/local/etc/proftpd.vhosts.conf "${DA_CONF}"
    # setVal ftppasswd_db /usr/local/etc/pureftpd.pdb "${DA_CONF}"
  fi

  ## Update services.status
  set_service pure-ftpd delete
  set_service proftpd ON

  if [ "${OPT_PROFTPD_UPLOADSCAN}" = "YES" ] && [ "${OPT_CLAMAV}" = "YES" ]; then
    if [ ! -e "${CLAMDSCAN}" ]; then
      clamav_install
    fi

    if [ ! -e "${CLAMDSCAN}" ]; then
      printf "*** Error: Cannot enable upload scanning in ProFTPD because there is no ClamAV (%s) on the system.\n" ${CLAMDSCAN}
      exit 1
    fi

    pkgi "${PORT_PROFTPD_CLAMAV}"

    ## Verify:
    if ! grep -m1 -q "^Include ${PROFTPD_CLAMAV_CONF}" "${PROFTPD_CONF}"; then
      ${PERL} -pi -e "s#</Global>#</Global>\n\nInclude ${PROFTPD_CLAMAV_CONF}#" "${PROFTPD_CONF}"
    fi

    ${PRXS} -c -i -d mod_clamav.c

    {
      printf "<IfModule mod_dso.c>\n"
      printf "  LoadModule mod_clamav.c\n"
      printf "</IfModule>\n"
      printf "<IfModule mod_clamav.c>\n"
      printf "  ClamAV on\n"
      printf "  ClamServer 127.0.0.1\n"
      printf "  ClamPort 3310\n"
      printf "  ClamMaxSize 5 Mb\n"
      printf "</IfModule>\n"
    } > "${PROFTPD_CLAMAV_CONF}"

    # <IfModule mod_clamav.c>
    #   ClamAV on
    #   ClamServer localhost
    #   ClamPort 3310
    # </IfModule>

  else
    ## Truncate the configuration file
    printf "" > "${PROFTPD_CLAMAV_CONF}"
  fi

  # /usr/local/libexec/proftpd --configtest

  printf "Starting ProFTPD\n"
  ${SERVICE} proftpd restart

  return
}

################################################################################
## ProFTPD Uninstall
################################################################################

proftpd_uninstall() {

  printf "Uninstalling ProFTPD\n"

  set_service proftpd delete

  ${SERVICE} proftpd stop

  pkgd -y "${PORT_PROFTPD}"
  pkgd -y "${PORT_PROFTPD_CLAMAV}"

  ${SYSRC} -q -x proftpd_enable
  ${SYSRC} -q -x proftpd_flags

  return
}

################################################################################
## ClamAV Installation Tasks
################################################################################

clamav_install() {

  if [ "${OPT_CLAMAV}" = "NO" ]; then
    printf "*** Error: CLAMAV not enabled in options.conf\n"
    return
  fi

  printf "Starting ClamAV installation\n"

  ### Main Installation
  if [ -z "${CLAMAV_MAKE_SET}" ] && [ -z "${CLAMAV_MAKE_UNSET}" ]; then
    pkgi "${PORT_CLAMAV}"
  else
    ${MAKE} -DNO_DIALOG -C "${PORTS_BASE}/${PORT_CLAMAV}" rmconfig
    ${MAKE} -DNO_DIALOG -C "${PORTS_BASE}/${PORT_CLAMAV}" \
    security_clamav_SET="${CLAMAV_MAKE_SET}" \
    security_clamav_UNSET="${CLAMAV_MAKE_UNSET}" \
    OPTIONS_SET="${GLOBAL_MAKE_SET}" \
    OPTIONS_UNSET="${GLOBAL_MAKE_UNSET}" \
    reinstall clean
  fi

  ## Todo:
  if [ "${OPT_CLAMAV_WITH_EXIM}" = "YES" ]; then
    ${WGET} -O "${EXIM_PATH}/exim.clamav.load.conf" "${PB_MIRROR}/exim/exim.clamav.load.conf"
    ${WGET} -O "${EXIM_PATH}/exim.clamav.conf" "${PB_MIRROR}/exim/exim.clamav.conf"
  fi

  ## Todo:
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

  if [ "${OPT_CLAMAV_WITH_EXIM}" = "YES" ]; then
    ${PERL} -pi -e "s|#.include_if_exists ${EXIM_PATH}/exim.clamav.load.conf|.include_if_exists ${EXIM_PATH}/exim.clamav.load.conf|" "${EXIM_CONF}"
    ${PERL} -pi -e "s|#.include_if_exists ${EXIM_PATH}/exim.clamav.conf|.include_if_exists ${EXIM_PATH}/exim.clamav.conf|" "${EXIM_CONF}"
  fi

  ## Add 'clamav' user to 'access' group
  addUserGroup clamav access

  ${SYSRC} clamav_clamd_enable="YES"
  ${SYSRC} clamav_freshclam_enable="YES"

  ${SERVICE} clamav-clamd start
  ${SERVICE} clamav-freshclam start

  if [ "${OPT_CLAMAV_WITH_EXIM}" = "YES" ]; then
    printf "Restarting Exim\n"
    ${SERVICE} exim restart
  fi

  return
}

################################################################################
## ClamAV Uninstall
################################################################################

clamav_uninstall() {

  printf "Uninstalling ClamAV\n"

  ${SERVICE} clamav-clamd stop
  ${SERVICE} clamav-freshclam stop

  pkgd "${PORT_CLAMAV}"

  ${SYSRC} -q -x clamav_clamd_enable
  ${SYSRC} -q -x clamav_freshclam_enable

  return
}

################################################################################
## Install RoundCube (from CB2: doroundcube())
################################################################################

roundcube_install() {

  local EDIT_CONFIG CONFIG_DIST PART1 PART2 SPAM_FOLDER DAPORT DASSL
  local ROUNDCUBE_PLUGINS ROUNDCUBE_SKINS ROUNDCUBE_PROGRAM ROUNDCUBE_HTACCESS

  if [ "${OPT_ROUNDCUBE}" = "NO" ]; then
    printf "*** Notice: ROUNDCUBE not enabled in options.conf\n"
    return
  fi

  printf "Starting RoundCube installation\n"

  ### Main Installation
  if [ -z "${ROUNDCUBE_MAKE_SET}" ] && [ -z "${ROUNDCUBE_MAKE_UNSET}" ]; then
    pkgi "${PORT_ROUNDCUBE}"
  else
    ${MAKE} -DNO_DIALOG -C "${PORTS_BASE}/${PORT_ROUNDCUBE}" rmconfig
    ${MAKE} -DNO_DIALOG -C "${PORTS_BASE}/${PORT_ROUNDCUBE}" \
    mail_roundcube_SET="${ROUNDCUBE_MAKE_SET}" \
    mail_roundcube_UNSET="${ROUNDCUBE_MAKE_UNSET}" \
    OPTIONS_SET="${GLOBAL_MAKE_SET}" \
    OPTIONS_UNSET="${GLOBAL_MAKE_UNSET}" \
    reinstall clean
  fi

  verify_webapps_logrotate

  get_sql_settings

  ## PB: Todo: Move to top:
  ## Defaults:
  ROUNDCUBE_CONFIG="${PB_CUSTOM}/roundcube/config.inc.php"

  ## Custom configuration overrides:
  ROUNDCUBE_PLUGINS="${PB_CUSTOM}/roundcube/plugins"
  ROUNDCUBE_SKINS="${PB_CUSTOM}/roundcube/skins"
  ROUNDCUBE_PROGRAM="${PB_CUSTOM}/roundcube/program"
  ROUNDCUBE_HTACCESS="${PB_CUSTOM}/roundcube/.htaccess"
  ## End PB: Todo: Move to top:

  ROUNDCUBE_PATH="${WWW_DIR}/roundcube"

  ## CB2: Variables for the database:
  ROUNDCUBE_DB=da_roundcube
  ROUNDCUBE_DB_USER=da_roundcube
  ROUNDCUBE_DB_PASS=$(random_pass)
  ROUNDCUBE_DES_KEY=$(random_pass 24)
  ROUNDCUBE_MY_CNF="${ROUNDCUBE_PATH}/config/my.cnf"

  ## PB: NOTE: All paths are relative!
  EDIT_CONFIG=config.inc.php
  CONFIG_DIST=config.inc.php.sample
  # EDIT_CONFIG=${ROUNDCUBE_PATH}/config/config.inc.php
  # CONFIG_DIST=${ROUNDCUBE_PATH}/config/config.inc.php.sample

  ## PB: NOTE: Directory change:
  cd "${ROUNDCUBE_PATH}" || exit

  ##### Database Configuration #####

  ## CB2: Insert data into MySQL and create the  database and user account for RoundCube:
  if ! ${MYSQLSHOW} "--defaults-extra-file=${DA_PATH}/conf/my.cnf" "--host=${MYSQL_HOST}" | grep -m1 -q ' da_roundcube '; then
    ## PB: New RoundCube installation
    if [ -d "${ROUNDCUBE_PATH}/SQL" ]; then
      printf "Creating the database and user account for RoundCube + inserting data.\n"

      ${MYSQL} "--defaults-extra-file=${DA_MYSQL_CNF}" "--host=${MYSQL_HOST}" -e "CREATE DATABASE ${ROUNDCUBE_DB};" 2>&1
      ${MYSQL} "--defaults-extra-file=${DA_MYSQL_CNF}" "--host=${MYSQL_HOST}" -e "GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,ALTER,LOCK TABLES,INDEX ON ${ROUNDCUBE_DB}.* TO '${ROUNDCUBE_DB_USER}'@'${MYSQL_ACCESS_HOST}' IDENTIFIED BY '${ROUNDCUBE_DB_PASS}';" 2>&1

      if [ "${MYSQL_HOST}" != "localhost" ]; then
        for access_host_ip in $(grep '^access_host.*=' "${DA_MYSQL_CONF}" | cut -d= -f2); do {
          ${MYSQL} "--defaults-extra-file=${DA_MYSQL_CNF}" "--host=${MYSQL_HOST}" \
          -e "GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,ALTER,LOCK TABLES,INDEX ON ${ROUNDCUBE_DB}.* \
          TO '${ROUNDCUBE_DB_USER}'@'${access_host_ip}' IDENTIFIED BY '${ROUNDCUBE_DB_PASS}';" 2>&1
        }; done
      fi

      rm -f "${ROUNDCUBE_MY_CNF}"

      verify_my_cnf "${ROUNDCUBE_MY_CNF}" "${ROUNDCUBE_DB_USER}" "${ROUNDCUBE_DB_PASS}"

      ${MYSQL} --defaults-extra-file=${ROUNDCUBE_MY_CNF} --host=${MYSQL_HOST} -e "USE ${ROUNDCUBE_DB}; source SQL/mysql.initial.sql;" 2>&1

      printf "Database created: %s password: %s\n" "${ROUNDCUBE_DB_USER}" "${ROUNDCUBE_DB_PASS}"
    else
      printf "*** Error: Cannot find the 'SQL' directory in %s\n" "${ROUNDCUBE_PATH}"
      exit 0
    fi
  else
    ## PB: Existing RoundCube installation
    if [ -e "${ROUNDCUBE_CONFIG}" ]; then
      COUNT_MYSQL=$(grep -m1 -c 'mysql://' "${ROUNDCUBE_CONFIG}")
      if [ "${COUNT_MYSQL}" -gt 0 ]; then
        PART1="$(grep -m1 "\$config\['db_dsnw'\]" ${ROUNDCUBE_CONFIG} | awk '{print $3}' | cut -d\@ -f1 | cut -d'/' -f3)"
        ROUNDCUBE_DB_USER="$(echo "${PART1}" | cut -d\: -f1)"
        ROUNDCUBE_DB_PASS="$(echo "${PART1}" | cut -d\: -f2)"
        PART2="$(grep -m1 "\$config\['db_dsnw'\]" ${ROUNDCUBE_CONFIG} | awk '{print $3}' | cut -d\@ -f2 | cut -d\' -f1)"
        MYSQL_ACCESS_HOST="$(echo "${PART2}" | cut -d'/' -f1)"
        ROUNDCUBE_DB="$(echo "${PART2}" | cut -d'/' -f2)"
      fi
    fi

    ${MYSQL} "--defaults-extra-file=${DA_MYSQL_CNF}" "--host=${MYSQL_HOST}" \
    -e "GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,ALTER,LOCK TABLES,INDEX ON ${ROUNDCUBE_DB}.* \
    TO '${ROUNDCUBE_DB_USER}'@'${MYSQL_ACCESS_HOST}' IDENTIFIED BY '${ROUNDCUBE_DB_PASS}';" 2>&1
    ${MYSQL} "--defaults-extra-file=${DA_MYSQL_CNF}" "--host=${MYSQL_HOST}" \
    -e "SET PASSWORD FOR '${ROUNDCUBE_DB_USER}'@'${MYSQL_ACCESS_HOST}' = PASSWORD('${ROUNDCUBE_DB_PASS}');" 2>&1

    if [ "${MYSQL_HOST}" != "localhost" ]; then
      for access_host_ip in $(grep '^access_host.*=' ${DA_MYSQL_CONF} | cut -d= -f2); do {
        ${MYSQL} "--defaults-extra-file=${DA_MYSQL_CNF}" "--host=${MYSQL_HOST}" \
        -e "GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,ALTER,LOCK TABLES,INDEX ON ${ROUNDCUBE_DB}.* \
        TO '${ROUNDCUBE_DB_USER}'@'${access_host_ip}' IDENTIFIED BY '${ROUNDCUBE_DB_PASS}';" 2>&1
        ${MYSQL} "--defaults-extra-file=${DA_MYSQL_CNF}" "--host=${MYSQL_HOST}" \
        -e "SET PASSWORD FOR '${ROUNDCUBE_DB_USER}'@'${access_host_ip}' = PASSWORD('${ROUNDCUBE_DB_PASS}');" 2>&1
      }; done
    fi

    ## CB2: in case anyone uses it for backups
    rm -f "${ROUNDCUBE_MY_CNF}"
    verify_my_cnf "${ROUNDCUBE_MY_CNF}" "${ROUNDCUBE_DB_USER}" "${ROUNDCUBE_DB_PASS}"
  fi

  ##### RoundCube Configuration #####

  ## CB2: Cleanup config
  rm -f "${EDIT_CONFIG}"

  ## PB: Todo: Verify:
  ## CB2: install the proper configuration file:
  if [ -d ../roundcube ]; then
    printf "Editing RoundCube configuration\n"

    ## PB: NOTE: Directory change:
    cd "${ROUNDCUBE_PATH}/config" || exit

    if [ -e "${ROUNDCUBE_CONFIG}" ]; then
      printf "Installing custom RoundCube Config: %s\n" "${ROUNDCUBE_CONFIG}"
      cp -f "${ROUNDCUBE_CONFIG}" "${EDIT_CONFIG}"
    fi

    if [ -e "${ROUNDCUBE_CONFIG}" ]; then
      if [ ! -e "${EDIT_CONFIG}" ]; then
        cp -f "${ROUNDCUBE_CONFIG}" "${EDIT_CONFIG}"
      fi
      if [ "${COUNT_MYSQL}" -eq 0 ]; then
        echo "\$config['db_dsnw'] = 'mysql://${ROUNDCUBE_DB_USER}:${ROUNDCUBE_DB_PASS}@${MYSQL_HOST}/${ROUNDCUBE_DB}';" >> "${EDIT_CONFIG}"
      fi
    else
      if [ ! -e "${EDIT_CONFIG}" ]; then
        cp -f "${CONFIG_DIST}" "${EDIT_CONFIG}"
        ${PERL} -pi -e "s|mysql://roundcube:pass\@localhost/roundcubemail|mysql://${ROUNDCUBE_DB_USER}:\\Q${ROUNDCUBE_DB_PASS}\\E\@${MYSQL_HOST}/${ROUNDCUBE_DB}|" "${EDIT_CONFIG}" > /dev/null
        ${PERL} -pi -e "s/\'mdb2\'/\'db\'/" "${EDIT_CONFIG}" > /dev/null
      fi
    fi

    OPT_SPAM_INBOX_PREFIX=$(getDA_Opt spam_inbox_prefix 1)

    SPAM_FOLDER="INBOX.spam"
    if [ "${OPT_SPAM_INBOX_PREFIX}" = "0" ]; then
      SPAM_FOLDER="Junk"
    fi

    ${PERL} -pi -e "s|rcmail-\!24ByteDESkey\*Str|\\Q${ROUNDCUBE_DES_KEY}\\E|" "${EDIT_CONFIG}"

    ## PB: New Installation:
    if [ ! -e "${ROUNDCUBE_CONFIG}" ]; then
      ## PB: Newer version of RoundCube (1.x+)
      ## CB2: default_host is set to localhost by default in RC 1.0.0, so we don't echo it to the file
      ## CB2: These ones are already in config.inc.php.sample file, so we just use perl-regex to change them
      ${PERL} -pi -e "s|\['smtp_port'] = 25|\['smtp_port'] = 587|" "${EDIT_CONFIG}" > /dev/null
      ${PERL} -pi -e "s|\['smtp_server'] = ''|\['smtp_server'] = 'localhost'|" "${EDIT_CONFIG}" > /dev/null
      ${PERL} -pi -e "s|\['smtp_user'] = ''|\['smtp_user'] = '%u'|" "${EDIT_CONFIG}" > /dev/null
      ${PERL} -pi -e "s|\['smtp_pass'] = ''|\['smtp_pass'] = '%p'|" "${EDIT_CONFIG}" > /dev/null

      ## CB2: Changing default options, override the ones set in defaults.inc.php

      ## CB2: IMAP folders
      if [ "${OPT_WEBAPPS_INBOX_PREFIX}" = "YES" ]; then
        {
          echo "\$config['drafts_mbox'] = 'INBOX.Drafts';"
          echo "\$config['junk_mbox'] = '${SPAM_FOLDER}';"
          echo "\$config['sent_mbox'] = 'INBOX.Sent';"
          echo "\$config['trash_mbox'] = 'INBOX.Trash';"
          echo "\$config['default_folders'] = array('INBOX', 'INBOX.Drafts', 'INBOX.Sent', '${SPAM_FOLDER}', 'INBOX.Trash');"
        } >> "${EDIT_CONFIG}"
      else
        {
          echo "\$config['junk_mbox'] = '${SPAM_FOLDER}';"
          echo "\$config['default_folders'] = array('INBOX', 'Drafts', 'Sent', '${SPAM_FOLDER}', 'Trash');"
        } >> "${EDIT_CONFIG}"
      fi

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
      } >> "${EDIT_CONFIG}"

      ## CB2: Grab settings from exim.conf
      if grep -q '^recipients_max' "${EXIM_CONF}"; then
        RECIPIENTS_MAX="$(grep -m1 '^recipients_max' "${EXIM_CONF}" | cut -d= -f2 | tr -d ' ')"
        echo "\$config['max_recipients'] = ${RECIPIENTS_MAX};" >> "${EDIT_CONFIG}"
        echo "\$config['max_group_members'] = ${RECIPIENTS_MAX};" >> "${EDIT_CONFIG}"
      fi

      if [ ! -s mime.types ]; then
        if [ "${OPT_WEBSERVER}" = "apache" ] || [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
          if [ -s "${APACHE_MIME_TYPES}" ]; then
            if grep -m1 -q 'application/java-archive' "${APACHE_MIME_TYPES}"; then
              cp -f "${APACHE_MIME_TYPES}" "${ROUNDCUBE_PATH}/mime.types"
            fi
          fi
        fi
      fi

      # if [ ! -s mime.types ]; then
      #   ${WGET} ${WGET_CONNECT_OPTIONS} -O mime.types http://svn.apache.org/repos/asf/httpd/httpd/trunk/docs/conf/mime.types 2> /dev/null
      # fi

      echo "\$config['mime_types'] = '${ROUNDCUBE_PATH}/config/mime.types';" >> "${EDIT_CONFIG}"

      ##### Password Plugin Configuration #####

      ## CB2: Password plugin
      if [ -e "${ROUNDCUBE_PATH}/plugins/password" ]; then
        ${PERL} -pi -e "s|\['plugins'] = array\(\n|\['plugins'] = array\(\n    'password',\n|" "${EDIT_CONFIG}" > /dev/null

        ## PB: NOTE: Directory change:
        cd "${ROUNDCUBE_PATH}/plugins/password" || exit

        if [ ! -e config.inc.php ]; then
          cp config.inc.php.dist config.inc.php
        fi

        ${PERL} -pi -e "s|\['password_driver'] = 'sql'|\['password_driver'] = 'directadmin'|" config.inc.php > /dev/null

        if [ -e "${DA_PATH}/directadmin" ]; then
          DAPORT=$(/usr/local/directadmin/directadmin c | grep -m1 -e '^port=' | cut -d= -f2)
          ${PERL} -pi -e "s|\['password_directadmin_port'] = 2222|\['password_directadmin_port'] = ${DAPORT}|" config.inc.php > /dev/null

          DASSL=$(${DA_PATH}/directadmin c | grep -m1 -e '^ssl=' | cut -d= -f2)
          if [ "${DASSL}" -eq 1 ]; then
            ${PERL} -pi -e "s|\['password_directadmin_host'] = 'tcp://localhost'|\['password_directadmin_host'] = 'ssl://localhost'|" config.inc.php > /dev/null
          fi
        fi

        ## PB: NOTE: Directory change:
        cd "${ROUNDCUBE_PATH}/config" || exit
      fi

      ##### PigeonHole Configuration #####

      ## PB: Todo:
      ## CB2: Pigeonhole plugin
      if [ "${OPT_PIGEONHOLE}" = "YES" ]; then
        if [ -d "${ROUNDCUBE_PATH}/plugins/managesieve" ]; then
          if [ $(grep -m1 -c "'managesieve'" "${EDIT_CONFIG}") -eq 0 ]; then
            ${PERL} -pi -e "s|\['plugins'] = array\(\n|\['plugins'] = array\(\n    'managesieve',\n|" "${EDIT_CONFIG}" > /dev/null
          fi

          ## PB: NOTE: Directory change:
          cd "${ROUNDCUBE_PATH}/plugins/managesieve" || exit

          if [ ! -e config.inc.php ]; then
            cp config.inc.php.dist config.inc.php
          fi
          ${PERL} -pi -e "s|\['managesieve_port'] = null|\['managesieve_port'] = 4190|" config.inc.php > /dev/null

          ## PB: NOTE:
          cd "${ROUNDCUBE_PATH}/config" || exit
        fi
      fi
    fi

    ##### Custom Configuration Files #####

    ## Custom Configurations
    if [ -d "${ROUNDCUBE_PLUGINS}" ]; then
      printf "Copying files from %s to %s\n" "${ROUNDCUBE_PLUGINS}" "${ROUNDCUBE_PATH}/plugins"
      cp -Rp "${ROUNDCUBE_PLUGINS}/*" "${ROUNDCUBE_PATH}/plugins"
    fi

    if [ -d "${ROUNDCUBE_SKINS}" ]; then
      printf "Copying files from %s to %s\n" "${ROUNDCUBE_SKINS}" "${ROUNDCUBE_PATH}/skins"
      cp -Rp "${ROUNDCUBE_SKINS}/*" "${ROUNDCUBE_PATH}/skins"
    fi

    if [ -d "${ROUNDCUBE_PROGRAM}" ]; then
      printf "Copying files from %s to %s\n" "${ROUNDCUBE_PROGRAM}" "${ROUNDCUBE_PATH}/program"
      cp -Rp "${ROUNDCUBE_PROGRAM}/*" "${ROUNDCUBE_PATH}/program"
    fi

    if [ -e "${ROUNDCUBE_HTACCESS}" ]; then
      printf "Copying .htaccess file from %s to %s\n" "${ROUNDCUBE_HTACCESS}" "${ROUNDCUBE_PATH}/.htaccess"
      cp -pf "${ROUNDCUBE_HTACCESS}" "${ROUNDCUBE_PATH}/.htaccess"
    fi

    printf "RoundCube has been configured successfully.\n"
  fi

  ## CB2: Systems with "system()" in disable_functions need to use no php.ini:
  if [ "$(have_php_system)" = "0" ]; then
    ${PERL} -pi -e 's#^\#\!/usr/bin/env php#\#\!/usr/local/bin/php \-n#' "${ROUNDCUBE_PATH}/bin/update.sh"
  fi

  ## CB2: Systems with Suhosin cannot have PHP memory_limit set to -1
  ##      We need to not load Suhosin for RoundCube .sh scripts
  if [ "${OPT_SUHOSIN}" = "YES" ]; then
    ${PERL} -pi -e 's#^\#\!/usr/bin/env php#\#\!/usr/local/bin/php \-n#' "${ROUNDCUBE_PATH}/bin/msgimport.sh"
    ${PERL} -pi -e 's#^\#\!/usr/bin/env php#\#\!/usr/local/bin/php \-n#' "${ROUNDCUBE_PATH}/bin/indexcontacts.sh"
    ${PERL} -pi -e 's#^\#\!/usr/bin/env php#\#\!/usr/local/bin/php \-n#' "${ROUNDCUBE_PATH}/bin/msgexport.sh"
  fi

  ## CB2: Update if needed:
  "${ROUNDCUBE_PATH}/bin/update.sh" '--version=?'

  ## CB2: Cleanup:
  rm -rf "${ROUNDCUBE_PATH}/installer"

  ## CB2: Set the permissions:
  ${CHOWN} -R "${WEBAPPS_USER}:${WEBAPPS_GROUP}" "${ROUNDCUBE_PATH}"

  if [ "${WEBAPPS_GROUP}" = "apache" ]; then
    ${CHOWN} -R apache "${ROUNDCUBE_PATH}/temp" "${ROUNDCUBE_PATH}/logs"
    ${CHMOD} -R 770 "${ROUNDCUBE_PATH}/temp"
    ${CHMOD} -R 770 "${ROUNDCUBE_PATH}/logs"
  fi

  ## CB2: Secure the configuration file
  if [ -s "${EDIT_CONFIG}" ]; then
    ${CHMOD} 440 "${EDIT_CONFIG}"
    if [ "${WEBAPPS_GROUP}" = "apache" ]; then
      printf "**********************************************************************\n"
      printf "*\n"
      printf "* SECURITY: %s is readable by Apache.\n" ${EDIT_CONFIG}
      printf "* Recommendation: Use a PHP type that runs PHP scripts as the User, then re-install RoundCube.\n"
      printf "*\n"
      printf "**********************************************************************\n"
    fi

    ${CHOWN} "${WEBAPPS_USER}:${WEBAPPS_GROUP}" "${EDIT_CONFIG}"

    if [ "${WEBAPPS_GROUP}" = "apache" ]; then
      ls -la "${EDIT_CONFIG}"
      sleep 5
    fi
  fi

  RC_HTACCESS="${ROUNDCUBE_PATH}/.htaccess"
  if [ -s "${RC_HTACCESS}" ]; then
    if grep -m1 -q upload_max_filesize "${RC_HTACCESS}"; then
      ${PERL} -pi -e 's/^php_value   upload_max_filesize/#php_value   upload_max_filesize/' "${RC_HTACCESS}"
      ${PERL} -pi -e 's/^php_value   post_max_size/#php_value   post_max_size/' "${RC_HTACCESS}"
      ${PERL} -pi -e 's/^php_value   memory_limit/#php_value   memory_limit/' "${RC_HTACCESS}"
    fi

    ${PERL} -pi -e 's/FollowSymLinks/SymLinksIfOwnerMatch/' "${RC_HTACCESS}"
  fi

  verify_webapps_tmp

  return
}

################################################################################
## Webapps Installation
################################################################################

webapps_install() {

  ## Create user and group:
  # ${PW} groupadd ${WEBAPPS_GROUP}
  # ${PW} useradd -g ${WEBAPPS_GROUP} -n ${WEBAPPS_USER} -b ${WWW_DIR} -s /sbin/nologin

  ## Set permissions on temp directory:
  if [ "${OPT_PHP_MODE}" = "php-fpm" ]; then
    ${CHMOD} 755 "${WWW_DIR}/tmp"
  else
    ${CHMOD} 777 "${WWW_DIR}/tmp"
  fi

  ## Temp path: /usr/local/www/webmail/tmp
  ## Create webmail/tmp directory:
  ## Verify whether 770 will work or not (750 for FPM?)
  ${MKDIR} -p "${WWW_DIR}/webmail/tmp"
  ${CHMOD} -R 770 "${WWW_DIR}/webmail/tmp"
  ${CHOWN} -R "${WEBAPPS_USER}:${WEBAPPS_GROUP}" "${WWW_DIR}/webmail"
  ${CHOWN} -R "${APACHE_USER}:${WEBAPPS_GROUP}" "${WWW_DIR}/webmail/tmp"
  printf "Deny from All\n" >> ${WWW_DIR}/webmail/tmp/.htaccess


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
  cp -f "${DA_PATH}/scripts/redirect.php" "${WWW_DIR}/redirect.php"

  return
}

################################################################################
## Secure php.ini (from CB2)
################################################################################

secure_php_ini() {

  ## $1 = php.ini file to update
  local PHPINI_FILE="$1"
  local CURRENT_DISABLE_FUNCT NEW_DISABLE_FUNCT

  if [ "${PB_DEBUG}" = "YES" ]; then
    echo "*** Debug: Function: secure_php_ini()"
  fi

  if [ -e "${PHPINI_FILE}" ]; then
    if grep -m1 -q -e disable_functions "${PHPINI_FILE}"; then
      CURRENT_DISABLE_FUNCT="$(grep -m1 'disable_functions' "${PHPINI_FILE}")"
      NEW_DISABLE_FUNCT="exec,system,passthru,shell_exec,escapeshellarg,escapeshellcmd,proc_close,proc_open,dl,popen,show_source,posix_kill,posix_mkfifo,posix_getpwuid,posix_setpgid,posix_setsid,posix_setuid,posix_setgid,posix_seteuid,posix_setegid,posix_uname"
      ${PERL} -pi -e "s#${CURRENT_DISABLE_FUNCT}#disable_functions \= ${NEW_DISABLE_FUNCT}#" "${PHPINI_FILE}"
    else
      printf "disable_functions = %s\n" "${NEW_DISABLE_FUNCT}" >> "${PHPINI_FILE}"
    fi

    ${PERL} -pi -e 's/^register_globals = On/register_globals = Off/' "${PHPINI_FILE}"
    ${PERL} -pi -e 's/^mysql.allow_local_infile = On/mysql.allow_local_infile = Off/' "${PHPINI_FILE}"
    ${PERL} -pi -e 's/^mysqli.allow_local_infile = On/mysqli.allow_local_infile = Off/' "${PHPINI_FILE}"
    ${PERL} -pi -e 's/^;mysqli.allow_local_infile = On/mysqli.allow_local_infile = Off/' "${PHPINI_FILE}"
    ${PERL} -pi -e 's/^expose_php = On/expose_php = Off/' "${PHPINI_FILE}"
  fi

  return
}

################################################################################
## Configure php.ini (from CB2: doPhpIni())
################################################################################

configure_php_ini() {

  local COUNT COUNT2 PHP_INI_VAR

  if [ "${PB_DEBUG}" = "YES" ]; then
    echo "*** Debug: Debug mode enabled."
    echo "*** Function: configure_php_ini()"
  fi

  if [ "${PHP_INI_OPT}" = "NO" ]; then
    printf "Cannot install php.ini because it is not set in options.conf.\n"
    return
  fi

  ## PHP:
  COUNT=$(grep -m1 -c '^date.timezone' "php.ini-${OPT_PHP_INI_TYPE}")
  COUNT2=$(grep -m1 -c ';date.timezone' "php.ini-${OPT_PHP_INI_TYPE}")
  if [ "$COUNT" -eq 0 ] && [ "$COUNT2" -eq 0 ]; then
    ## echo "Adding date.timezone = \"${OPT_PHP_TIMEZONE}\" to php.ini, please change it by yourself to fit your own needs."
    printf "date.timezone = \"%s\"\n" "${OPT_PHP_TIMEZONE}" >> "php.ini-${OPT_PHP_INI_TYPE}"
  elif [ "$COUNT" -eq 0 ]; then
    ## echo "Adding date.timezone = \"${OPT_PHP_TIMEZONE}\" to php.ini, please change it by yourself to fit your own needs."
    ${PERL} -pi -e "s#;date.timezone.*#date.timezone = \"${OPT_PHP_TIMEZONE}\"#" "php.ini-${OPT_PHP_INI_TYPE}"
  fi

  ${PERL} -pi -e 's/upload_max_filesize = 2M/upload_max_filesize = 64M/' "php.ini-${OPT_PHP_INI_TYPE}"
  ${PERL} -pi -e 's/post_max_size = 8M/post_max_size = 64M/' "php.ini-${OPT_PHP_INI_TYPE}"

  ## short_open_tag: http://help.directadmin.com/item.php?id=438
  ${PERL} -pi -e 's/^short_open_tag = Off/short_open_tag = On/' "php.ini-${OPT_PHP_INI_TYPE}"

  if [ "${OPT_PHP_INI_XMAILHEADER}" = "YES" ]; then
    printf "Enabling mail.add_x_header option in php.ini\n"
    ${PERL} -pi -e 's/mail.add_x_header = Off/mail.add_x_header = On/' "php.ini-${OPT_PHP_INI_TYPE}"
    ${PERL} -pi -e 's/mail.add_x_header = 0/mail.add_x_header = On/' "php.ini-${OPT_PHP_INI_TYPE}"
    if ! grep -m1 -q '^mail.add_x_header' "php.ini-${OPT_PHP_INI_TYPE}"; then
      printf "mail.add_x_header = On\n" >> "php.ini-${OPT_PHP_INI_TYPE}"
    fi
  else
    printf "Disabling mail.add_x_header option in php.ini\n"
    ${PERL} -pi -e 's/^mail.add_x_header =/;mail.add_x_header =/' "php.ini-${OPT_PHP_INI_TYPE}"
  fi

  if [ "${OPT_PHP_MODE}" = "mod_php" ]; then
    cp -f "php.ini-${OPT_PHP_INI_TYPE}" ${PHP_INI}
    ## CB2: writeLog "${PHP_INI} installed"
  elif [ "${OPT_PHP_MODE}" = "php-fpm" ] || [ "${OPT_PHP_MODE}" = "fastcgi" ] || [ "${OPT_PHP_MODE}" = "suphp" ]; then
    PHP_INI_VAR=PHP_INI_FPM${PHP_SHORTRELEASE}
    cp -f "php.ini-${OPT_PHP_INI_TYPE}" $(eval_var ${PHP_INI_VAR})
    ## CB2: writeLog "$(eval_var ${PHP_INI_VAR}) installed"
  fi

  printf "Done for PHP release #1.\n"

  cd "${PB_PATH}" || exit

  return
}

################################################################################
## ModSecurity Installation
################################################################################

modsecurity_install() {

  local PHPMODULES

  ## ap24-mod_security
  pkgi "${PORT_MOD_SECURITY}"

  ## CB2: For nginx we need to rebuild it, because ModSecurity is added as a static module
  if [ "${OPT_WEBSERVER}" = "nginx" ] || [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
    printf '' > "${NGINX_PATH}/nginx-modsecurity-enable.conf"
    printf "ModSecurityEnabled on;\n" >> "${NGINX_PATH}/nginx-modsecurity-enable.conf"
    printf "ModSecurityConfig %s/nginx-modsecurity.conf;\n" "${NGINX_PATH}" >> "${NGINX_PATH}/nginx-modsecurity-enable.conf"

    ## Verify:
    # if [ "$1" = "1" ]; then
    #   # Build nginx to enable the module statically (./configure --add-module=../mod_security/nginx/modsecurity)
    #   echo "Building Nginx to enable ModSecurity module statically."
    #   ./build nginx
    #   return
    # fi
  else
    if [ -d "${NGINX_PATH}" ]; then
      printf '' > "${NGINX_PATH}/nginx-modsecurity-enable.conf"
    fi
  fi

  # getFile patches/modsec-712.patch modsec-712.patch

  # if [ "${OPT_WEBSERVER}" = "apache" ]; then
  #   MODSECURITY_CONFIGURE_FLAGS=""
  # else
  #   MODSECURITY_CONFIGURE_FLAGS="--enable-standalone-module --disable-mlogc"
  # fi

  if [ "${OPT_WEBSERVER}" = "nginx" ]; then
    cp -pf "${MODSECURITY_NGINX_INCLUDE}" "${NGINX_PATH}/nginx-modsecurity.conf"
  elif [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
    cp -pf "${MODSECURITY_NGINX_REVERSE_INCLUDE}" "${NGINX_PATH}/nginx-modsecurity.conf"
  fi

  if [ "${OPT_WEBSERVER}" = "apache" ]; then
    ## Add mod_security include in apache
    PHPMODULES="${APACHE_EXTRAS}/httpd-phpmodules.conf"

    if [ -e "${PHPMODULES}" ]; then
      ${PERL} -pi -e 's|^LoadModule security2_module|#LoadModule security2_module|' "${APACHE_CONF}"
      if ! grep -m1 -q 'httpd-modsecurity' "${PHPMODULES}"; then
        printf "Include %s/httpd-modsecurity.conf\n" "${APACHE_EXTRAS}" >> "${PHPMODULES}"
      fi
      cp -pf "${MODSECURITY_APACHE_INCLUDE}" "${APACHE_EXTRAS}/httpd-modsecurity.conf"
    fi
  fi

  echo "action=rewrite&value=httpd" >> "${DA_TASK_QUEUE}"
  run_dataskq

  printf "ModSecurity has been installed successfully.\n"

  ## CB2: For initial Comodo ruleset installation, we need to restart webserver
  ##      so that it detects installation of modsecurity
  if [ "${OPT_MODSECURITY_RULESET}" = "comodo" ]; then
    if [ "${OPT_WEBSERVER}" = "apache" ]; then
      ${SERVICE} apache24 restart
    elif [ "${OPT_WEBSERVER}" = "nginx" ] || [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
      ${SERVICE} nginx restart
    fi
  fi

  update_modsecurity_rules norestart

  if [ "${OPT_WEBSERVER}" = "apache" ]; then
    ${SERVICE} apache24 restart
  elif [ "${OPT_WEBSERVER}" = "nginx" ] || [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
    ${SERVICE} nginx restart
  fi

  return
}

################################################################################
## ModSecurity Upgrade
################################################################################

modsecurity_upgrade() {

  pkgu "${PORT_MOD_SECURITY}"

  return
}

################################################################################
## Todo: Update ModSecurity Rules (from CB2: doModSecurityRules())
################################################################################

update_modsecurity_rules() {

  printf "*** Error: update_modsecurity_rules(): Incomplete\n"
  exit

  local MODSECURITY_CONF_FILE CWAF_PLATFORM

  if [ ! -d "${MODSECURITY_PATH}" ]; then
    ${MKDIR} -p ${MODSECURITY_PATH}
  fi

  rm -f "${MODSECURITY_PATH}/*"

  ## Verify: Comodo Rules
  if [ "${OPT_MODSECURITY_RULESET}" = "comodo" ]; then
    printf "Installing the Comodo Ruleset for ModSecurity\n"

    if [ "${OPT_WEBSERVER}" = "nginx" ] || [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
      # getFileCWAF cwaf_rules_nginx-${CWAF_RULES_NGINX_VER}.tgz cwaf_rules_nginx
      CWAF_PLATFORM=Nginx
    else
      # getFileCWAF cwaf_rules-${CWAF_RULES_VER}.tgz cwaf_rules
      CWAF_PLATFORM=Apache
    fi

    if [ ! -e /usr/local/cwaf/scripts/updater.pl ]; then
      ${WGET} -O ${PB_PATH}/cwaf_client_install.sh https://waf.comodo.com/cpanel/cwaf_client_install.sh
      ${CHMOD} 700 cwaf_client_install.sh
      HOME=/root TERM=xterm ./cwaf_client_install.sh -- --batch --login=nologin --password=nopassword --platform=${CWAF_PLATFORM}

      #### plugin was not installed exit ###
      if [ $? -ne 0 ]; then
        rm -f cwaf_client_install.sh
        printf "Installation of Comodo WAF plugin failed\n"
        exit 1
      fi

      rm -f cwaf_client_install.sh
    else
      printf "Updating to the latest CWAF client version\n"
      /usr/local/cwaf/scripts/update-client.pl
    fi

    echo "IncludeOptional /usr/local/etc/cwaf/cwaf.conf" > "${MODSECURITY_PATH}/comodo_rules.conf.main"

    if [ "${OPT_WEBSERVER}" = "nginx" ] || [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
      ${PERL} -pi -e 's/cwaf_platform="Apache"/cwaf_platform="Nginx"/' /usr/local/etc/cwaf/main.conf
      ${PERL} -pi -e 's/cwaf_platform="LiteSpeed"/cwaf_platform="Nginx"/' /usr/local/etc/cwaf/main.conf
      /usr/local/cwaf/scripts/updater.pl -p "${DA_PATH}/custombuild/cwaf_rules_nginx-${CWAF_RULES_NGINX_VER}.tgz"

      rm -f "cwaf_rules-${CWAF_RULES_NGINX_VER}.tgz"
    else
      ${PERL} -pi -e 's/cwaf_platform="Nginx"/cwaf_platform="Apache"/' /usr/local/etc/cwaf/main.conf
      ${PERL} -pi -e 's/cwaf_platform="LiteSpeed"/cwaf_platform="Apache"/' /usr/local/etc/cwaf/main.conf
      /usr/local/cwaf/scripts/updater.pl -p "${DA_PATH}/custombuild/cwaf_rules-${CWAF_RULES_VER}.tgz"

      rm -f "cwaf_rules-${CWAF_RULES_VER}.tgz"
    fi
  fi

  ## OWASP Rules
  if [ "${OPT_MODSECURITY_RULESET}" = "owasp" ]; then
    printf "Installing the OWASP Core Ruleset for ModSecurity\n"
    ## Todo: getFile SpiderLabs-owasp-modsecurity-crs-${OWASP_RULES_VER}.tar.gz owasp_rules
    ${TAR} xzf "SpiderLabs-owasp-modsecurity-crs-${OWASP_RULES_VER}.tar.gz" -C "${MODSECURITY_PATH}/" */modsecurity_crs_10_setup.conf.example --strip-components=1 --no-same-owner
    ${TAR} xzf "SpiderLabs-owasp-modsecurity-crs-${OWASP_RULES_VER}.tar.gz" -C "${MODSECURITY_PATH}/" */base_rules --strip-components=2 --no-same-owner

    printf "%s" "${OWASP_RULES_VER}" > "${MODSECURITY_PATH}/owasp_rules_version"

    if [ -e "${MODSECURITY_PATH}/modsecurity_crs_10_setup.conf.example" ]; then
      mv -f "${MODSECURITY_PATH}/modsecurity_crs_10_setup.conf.example" "${MODSECURITY_PATH}/modsecurity_crs_10_setup.conf.main"
    fi
    ${PERL} -pi -e 's|^SecDefaultAction|#SecDefaultAction|' "${MODSECURITY_PATH}/modsecurity_crs_10_setup.conf.main"
  fi

  ## Web Server Configuration
  if [ "${OPT_WEBSERVER}" = "apache" ]; then
    MODSECURITY_CONF_FILE="${APACHE_EXTRAS}/httpd-modsecurity.conf"
  else
    MODSECURITY_CONF_FILE="${NGINX_PATH}/nginx-modsecurity.conf"
  fi

  ## UploadScan via ClamAV
  if [ "${OPT_MODSECURITY_UPLOADSCAN}" = "YES" ] && [ "${OPT_CLAMAV}" = "YES" ]; then
    if [ ! -e "${CLAMDSCAN}" ]; then
      #removeLockfile
      clamav_install
    fi

    if [ ! -e "${CLAMDSCAN}" ]; then
      printf "*** Error: Cannot enable upload scan in ProFTPd because there is no ClamAV (%s) on the system.\n" "${CLAMDSCAN}"
      exit 1
    fi

    cp -pf "${RUNAV_PL}" /usr/local/bin/runav.pl
    ${CHMOD} 755 /usr/local/bin/runav.pl
    cp -pf "${RUNAV_CONF}" "${MODSECURITY_PATH}/runav.conf"
    ${PERL} -pi -e 's#SecRequestBodyAccess Off#SecRequestBodyAccess On#' "${MODSECURITY_CONF_FILE}"
  else
    rm -f /usr/local/bin/runav.pl
    rm -f "${MODSECURITY_PATH}/runav.conf"
    ${PERL} -pi -e 's#SecRequestBodyAccess On#SecRequestBodyAccess Off#' "${MODSECURITY_CONF_FILE}"
  fi

  ## Custom Rules
  if [ -d "${MODSECURITY_CUSTOM_RULES}" ]; then
    printf "Copying custom ModSecurity rules to %s/\n" "${MODSECURITY_PATH}"
    cp -Rpf "${MODSECURITY_CUSTOM_RULES}/*" "${MODSECURITY_PATH}/"
  fi

  printf "Installation of the ModSecurity Ruleset has finished.\n"

  ## Restart Web Server
  if [ "$1" != "norestart" ]; then
    if [ "${OPT_WEBSERVER}" = "apache" ] || [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
      ${SERVICE} apache24 restart
    fi
    if [ "${OPT_WEBSERVER}" = "nginx_apache" ] || [ "${OPT_WEBSERVER}" = "nginx" ]; then
      ${SERVICE} nginx restart
    fi
  fi

  return
}

################################################################################
## Verify Webapps php.ini (from CB2)
################################################################################

verify_webapps_php_ini() {

  if [ "${PB_DEBUG}" = "YES" ]; then
    echo "*** Debug: Function: verify_webapps_php_ini()"
    echo "PHP_CUSTOM_PHP_CONF_D_INI_PATH: ${PHP_CUSTOM_PHP_CONF_D_INI_PATH}"
    echo "PHP_INI_WEBAPPS: ${PHP_INI_WEBAPPS}"
  fi

  # ${PHP_INI_WEBAPPS = /usr/local/etc/php/50-webapps.ini
  # ${WWW_TMP_DIR} = /usr/local/www/tmp

  ## PB: 2016-06-01: No longer needed.
  # if [ "${OPT_PHP_MODE}" = "mod_php" ]; then
  #   PHP_INI_WEBAPPS=/usr/local/lib/php.conf.d/50-webapps.ini
  #   mkdir -p /usr/local/lib/php.conf.d
  # else
  #   PHP_INI_WEBAPPS=/usr/local/php${OPT_PHP_VER}/lib/php.conf.d/50-webapps.ini
  #   mkdir -p "/usr/local/php${OPT_PHP_VER}/lib/php.conf.d"
  # fi

  ## Copy custom/ file (not implemented)
  if [ -e "${PHP_CUSTOM_PHP_CONF_D_INI_PATH}/50-webapps.ini" ]; then
    printf "Using custom %s/50-webapps.ini for %s\n" "${PHP_CUSTOM_PHP_CONF_D_INI_PATH}" "${PHP_INI_WEBAPPS}"
    cp -f "${PHP_CUSTOM_PHP_CONF_D_INI_PATH}/50-webapps.ini" "${PHP_INI_WEBAPPS}"
  else
    {
      printf "[PATH=%s]\n" "${WWW_DIR}"
      printf "session.save_path=%s\n" "${WWW_TMP_DIR}"
      printf "upload_tmp_dir=%s\n" "${WWW_TMP_DIR}"
      printf "disable_functions=exec,system,passthru,shell_exec,escapeshellarg,escapeshellcmd,proc_close,proc_open,dl,popen,show_source,posix_kill,posix_mkfifo,posix_getpwuid,posix_setpgid,posix_setsid,posix_setuid,posix_setgid,posix_seteuid,posix_setegid,posix_uname\n"
    } > "${PHP_INI_WEBAPPS}"
  fi

  return
}

################################################################################
## Verify Webapps Temp Directory (from CB2)
################################################################################

verify_webapps_tmp() {

  if [ ! -d "{$WWW_TMP_DIR}" ]; then
    ${MKDIR} -p "${WWW_TMP_DIR}"
  fi

  ## Verify: 770 compatible with FPM?
  ${CHMOD} 770 "${WWW_TMP_DIR}"
  ${CHOWN} "${WEBAPPS_USER}:${WEBAPPS_GROUP}" "${WWW_TMP_DIR}"

  verify_webapps_php_ini

  return
}

################################################################################
## Get Webmail Link (from CB2)
################################################################################

get_webmail_link() {

  local WEBMAIL_LINK

  WEBMAIL_LINK=roundcube
  if [ "${OPT_ROUNDCUBE}" = "NO" ]; then
    WEBMAIL_LINK=squirrelmail
  fi

  if [ -s "${DA_CONF}" ] && [ -s "${DA_BIN}" ]; then
    WEBMAIL_LINK=$("${DA_BIN}" c | grep -m1 '^webmail_link' | cut -d= -f2)
  fi

  echo "${WEBMAIL_LINK}"

  return
}

################################################################################
## Apache Host Configuration (from CB2: doApacheHostConf())
## Generates extra/httpd-hostname.conf
################################################################################

apache_host_conf() {

  local SUEXEC_PER_DIR WEBAPPS_FCGID_DIR

  ## Already defined: APACHE_HOSTNAME_CONF="${APACHE_EXTRAS}/httpd-hostname.conf"
  ## PB: Not used? WEBAPPS_FCGID_DIR=/usr/local/www/fcgid

  if [ "${PB_DEBUG}" = "YES" ]; then
    echo "*** Debug: Function: apache_host_conf()"
  fi

  ## Custom Configurations
  ## Target: APACHE_HOSTNAME_CONF_CUSTOM
  if [ -e "${PB_CUSTOM}/ap2/conf/extra/httpd-hostname.conf" ]; then
    cp -pf "${PB_CUSTOM}/ap2/conf/extra/httpd-hostname.conf" "${APACHE_HOSTNAME_CONF}"
  else
    {
      if [ "${HAVE_FPM_CGI}" = "YES" ]; then
        printf "SetEnvIfNoCase ^Authorization\$ \"(.+)\" HTTP_AUTHORIZATION=\$1\n"
      fi
      printf "<Directory %s>\n" "${WWW_DIR}"

      ## PHP: FPM:
      if [ "${OPT_PHP_MODE}" = "php-fpm" ]; then
        printf "  <FilesMatch \"\.(inc|php|php3|php4|php44|php5|php52|php53|php54|php55|php56|php70|php71|php6|phtml|phps)\$\">\n"
        ## PB: Single PHP installation for now:
        ## echo "    AddHandler \"proxy:unix:/usr/local/php${OPT_PHP_VER}/sockets/webapps.sock|fcgi://localhost\" .inc .php .php5 .php${OPT_PHP_VER} .phtml"
        printf "    AddHandler \"proxy:unix:/var/run/php/sockets/webapps.sock|fcgi://localhost\" .inc .php .php5 .php%s .phtml\n" "${OPT_PHP_VER}"
        printf "  </FilesMatch>"
      fi
      printf "  Options +SymLinksIfOwnerMatch +IncludesNoExec\n"
      printf "  AllowOverride AuthConfig FileInfo Indexes Limit Options=Includes,IncludesNOEXEC,Indexes,ExecCGI,MultiViews,SymLinksIfOwnerMatch,None\n\n"
      printf "  Order Allow,Deny\n"
      printf "  Allow from all\n"
      printf "  <IfModule mod_suphp.c>\n"
      printf "    suPHP_Engine On\n"
      printf "    suPHP_UserGroup %s %s\n" "${WEBAPPS_USER}" "${WEBAPPS_GROUP}"
      printf "  </IfModule>\n"

      if [ "${OPT_PHP_MODE}" = "mod_php" ]; then
        printf "  <IfModule mod_php5.c>\n"
        printf "    php_admin_value session.save_path %s\n" "${WWW_TMP_DIR}"
        printf "    php_admin_value upload_tmp_dir %s\n" "${WWW_TMP_DIR}"
        printf "  </IfModule>\n"
        printf "  <IfModule mod_php7.c>\n"
        printf "    php_admin_value session.save_path %s\n" "${WWW_TMP_DIR}"
        printf "    php_admin_value upload_tmp_dir %s\n" "${WWW_TMP_DIR}"
        printf "  </IfModule>\n"
      fi
    } > "${APACHE_HOSTNAME_CONF}"

    verify_webapps_tmp

    SUEXEC_PER_DIR=0

    ## PB: Note: Need CB2 Apache 2.4 patches or else this doesn't work.
    if [ -s "${APACHE_SUEXEC}" ]; then
      SUEXEC_PER_DIR="$(${APACHE_SUEXEC} -V 2>&1 | grep -c 'AP_PER_DIR')"
    fi

    if [ "${PB_DEBUG}" = "YES" ]; then
      echo "SUEXEC_PER_DIR: ${SUEXEC_PER_DIR}"
    fi

    ## PHP: FastCGI: (technically fcgid)
    if [ "${OPT_PHP_MODE}" = "fastcgi" ]; then
      {
        printf "  <IfModule mod_fcgid.c>\n"
        printf "    FcgidWrapper /usr/local/safe-bin/fcgid%s.sh .php\n" ${OPT_PHP_VER}
        if [ "${SUEXEC_PER_DIR}" -gt 0 ]; then
          printf "  SuexecUserGroup %s %s\n" "${WEBAPPS_USER}" "${WEBAPPS_GROUP}"
        fi
        printf "    <FilesMatch \"\.(inc|php|php3|php4|php44|php5|php52|php53|php54|php55|php56|php70|php71|php6|phtml|phps)\$\">\n" "${OPT_PHP_VER}"
        printf "      Options +ExecCGI\n"
        printf "      AddHandler fcgid-script .php\n"
        printf "    </FilesMatch>\n"
        printf "  </IfModule>\n"
      } >> "${APACHE_HOSTNAME_CONF}"
    fi
    printf "</Directory>\n" >> "${APACHE_HOSTNAME_CONF}"
  fi

  return
}

################################################################################
## Add Alias Redirect (from CB2: add_alias_redirect())
################################################################################

add_alias_redirect() {

  local AF=$1
  local A=$2
  local P=$3
  local HTTP HOST_ALIAS IS_WELL_KNOWN LETSENCRYPT

  HTTP=http://
  HOST_ALIAS=NO
  IS_WELL_KNOWN=NO

  if [ "${OPT_REDIRECT_HOST_HTTPS}" = "YES" ]; then
    HTTP='https://'
  fi

  if [ "${OPT_USE_HOSTNAME_FOR_ALIAS}" = "YES" ]; then
    HOST_ALIAS="YES"
  fi

  if [ "${P}" = ".well-known" ]; then
    IS_WELL_KNOWN="YES"
  fi

  if [ "${HOST_ALIAS}" = "YES" ] && [ "${IS_WELL_KNOWN}" = "NO" ]; then
    {
      echo "RewriteCond %{HTTP_HOST} !^${OPT_REDIRECT_HOST}\$"
      echo "RewriteCond %{REQUEST_URI} ^/${A}/ [OR]"
      echo "RewriteCond %{REQUEST_URI} ^/${A}\$ [OR]"
      echo "RewriteRule ^/${A}(.*) ${HTTP}${OPT_REDIRECT_HOST}/${P}\$1"
      printf "\n"
    } >> "${AF}"
  fi

  ## CB2: For Let's Encrypt challenges
  if [ "${IS_WELL_KNOWN}" = "YES" ]; then
    LETSENCRYPT=$(getDA_Opt letsencrypt 0)
    if [ "${LETSENCRYPT}" = "1" ]; then
      echo "Alias /${A} ${WWW_DIR}/${P}" >> "${AF}"
    fi
    return
  fi

  ## CB2: "! -e /usr/local/www/${A}" is used to add Alias'es for the RewriteRules that don't have /usr/local/www/ALIAS
  if [ "${HOST_ALIAS}" = "NO" ] || [ ! -e "${WWW_DIR}/${A}" ]; then
    echo "Alias /${A} ${WWW_DIR}/${P}" >> "${AF}"
  fi

  return
}

################################################################################
## Rewrite httpd Alias (from CB2: do_rewrite_httpd_alias())
################################################################################

do_rewrite_httpd_alias() {

  local HA LETSENCRYPT app app_path

  if [ "${PB_DEBUG}" = "YES" ]; then
    echo "*** Debug: Function: do_rewrite_httpd_alias()"
    echo "APACHE_EXTRAS: ${APACHE_EXTRAS}"
    echo "OPT_USE_HOSTNAME_FOR_ALIAS: ${OPT_USE_HOSTNAME_FOR_ALIAS}"
    echo "PB_CONFIG: ${PB_CONFIG}"
    echo "PB_CUSTOM: ${PB_CUSTOM}"
  fi

  ## Custom Configuration
  if [ -e "${PB_CUSTOM}/ap2/conf/extra/httpd-alias.conf" ]; then
    cp -pf "${PB_CUSTOM}/ap2/conf/extra/httpd-alias.conf" "${APACHE_EXTRAS}/httpd-alias.conf"
  else
    HA="${APACHE_EXTRAS}/httpd-alias.conf"

    ## Truncate file
    printf "" > "${HA}"

    if [ "${OPT_USE_HOSTNAME_FOR_ALIAS}" = "YES" ]; then
      printf "RewriteEngine On\n" >> "${HA}"
    fi

    add_alias_redirect "${HA}" config redirect.php

    if [ "${OPT_SQUIRRELMAIL}" = "YES" ]; then
      add_alias_redirect ${HA} squirrelmail squirrelmail
    fi

    if [ "${OPT_ROUNDCUBE}" = "YES" ]; then
      add_alias_redirect ${HA} roundcube roundcube
    fi

    WEBMAIL_LINK=$(get_webmail_link)
    if [ -e "${WWW_DIR}/${WEBMAIL_LINK}" ]; then
      add_alias_redirect ${HA} webmail "${WEBMAIL_LINK}"
    fi

    if [ "${OPT_PHPMYADMIN}" = "YES" ]; then
      add_alias_redirect "${HA}" phpMyAdmin phpMyAdmin
      add_alias_redirect "${HA}" phpmyadmin phpMyAdmin
      add_alias_redirect "${HA}" pma phpMyAdmin
    fi

    ## For Let's Encrypt challenges
    LETSENCRYPT=$(getDA_Opt letsencrypt 0)
    if [ "${LETSENCRYPT}" = "1" ]; then
      add_alias_redirect "${HA}" .well-known .well-known
    fi

    if [ -s "${WEBAPPS_LIST}" ]; then
      ## CB2: http://forum.directadmin.com/showthread.php?t=48203&p=247343#post247343
      printf "Adding custom webapps from %s\n" "${WEBAPPS_LIST}"

      ## Verify:
      while read l < "${WEBAPPS_LIST}"; do
        app=$(echo "$l" | cut -d= -f1)
        app_path=$(echo "$l" | cut -d= -f2)

        if [ -z "${app}" ] || [ -z "${app_path}" ]; then
          printf "Check your %s. A name or path is blank.\n" "${WEBAPPS_LIST}"
          printf "name=%s\n" "$app"
          printf "path=%s\n" "$app_path"
          continue
        fi

        if [ ! -e "${WWW_DIR}/${app_path}" ]; then
          printf "Cannot find path %s for alias %s\n" "${WWW_DIR}/${app_path}" "${app}"
          continue
        fi

        add_alias_redirect "${HA}" "${app}" "${app_path}"
        printf "Added %s pointing to %s\n" "${app}" "${app_path}"
      done
    fi
  fi

  return
}

################################################################################
## Add Nginx Alias Redirect (from CB2: add_nginx_alias_redirect())
################################################################################

add_nginx_alias_redirect() {

  local FILE=$1
  local ALIAS=$2
  local PATH=$3

  {
    printf "\tlocation /%s {\n" "${ALIAS}"
    printf "\t\trewrite ^/* /%s last;\n" "${PATH}"
    printf "\t}\n"
  } >> "${FILE}"
}

################################################################################
## Verify: Todo: Add Nginx Alias (from CB2: add_nginx_alias())
################################################################################

add_nginx_alias() {

  local FILE="$1"
  local ALIAS="$2"

  if [ "${OPT_WEBSERVER}" = "nginx" ]; then
    {
      printf "\tlocation /%s {\n" "${ALIAS}"
      printf "\t\troot %s;\n" "${WWW_DIR}"
      printf "\t\tindex index.php index.html index.htm;\n"
      printf "\t\tlocation ~ ^/%s/(.+\\.php)\$ {\n" "${ALIAS}"
      printf "\t\t\tinclude %s/webapps_settings.conf;\n" "${NGINX_PATH}"
      printf "\t\t}\n"
      printf "\t\tlocation ~* ^/%s/(.+\\.(jpg|jpeg|gif|css|png|js|ico|html|xml|txt))\$ {\n" "${ALIAS}"
      printf "\t\t\troot %s;\n" "${WWW_DIR}/"
      printf "\t\t}\n"
      printf "\t}\n"
    } >> "${FILE}"
  elif [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
    {
      printf "\tlocation /%s {\n" "${ALIAS}"
      printf "\t\troot %s/;\n" "${WWW_DIR}"
      printf "\t\tindex index.php index.html index.htm;\n"
      printf "\t\tlocation ~ ^/%s/ {\n" "${ALIAS}"
      printf "\t\t\taccess_log off;\n"
      printf "\t\tset \$my_server_addr \$server_addr;\n"
      printf "\t\tif (\$server_addr ~ ^[0-9a-fA-F:]+\$) { set \$my_server_addr [\$server_addr]; }\n"
      printf "\t\t\tproxy_pass http://\$my_server_addr:%s;\n" "${PORT_8080}"
      printf "\t\t\tproxy_set_header X-Client-IP      \$remote_addr;\n"
      printf "\t\t\tproxy_set_header X-Accel-Internal /%s/nginx_static_files;\n" "${ALIAS}"
      printf "\t\t\tproxy_set_header Host\t     \$host;\n"
      printf "\t\t\tproxy_set_header X-Forwarded-For  \$proxy_add_x_forwarded_for;\n"
      printf "\t\t}\n"
      printf "\t\tlocation ~ ^/%s/nginx_static_files/ {\n" "${ALIAS}"
      printf "\t\t\taccess_log  %s/nginx/access_log_proxy;\n" ${LOGS}
      printf "\t\t\talias       %s/;\n" "${WWW_DIR}"
      printf "\t\t\tinternal;\n"
      printf "\t\t}\n"
      printf "\t}\n"
    } >> "${FILE}"
  fi
}

################################################################################
## Verify: Todo: Rewrite Nginx Webapps (from CB2: do_rewrite_nginx_webapps())
################################################################################

do_rewrite_nginx_webapps() {

  local NW LETSENCRYPT WEBMAIL_LINK NW_HOSTNAME PHP_REPLACE_STRING

  NW="${NGINX_PATH}/webapps.conf"
  NW_HOSTNAME="${NGINX_PATH}/webapps.hostname.conf"

  if [ -e "${PB_CUSTOM}/nginx/conf/webapps.conf" ] && [ "${OPT_WEBSERVER}" = "nginx" ]; then
    cp -pf "${PB_CUSTOM}/nginx/conf/webapps.conf" "${NW}"
  elif [ -e "${PB_CUSTOM}/nginx_reverse/conf/webapps.conf" ] && [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
    cp -pf "${PB_CUSTOM}/nginx_reverse/conf/webapps.conf" "${NW}"
  else
    : > ${NW}

    ## For Let's Encrypt challenges
    LETSENCRYPT="$(getDA_Opt letsencrypt 0)"
    if [ "${LETSENCRYPT}" = "1" ]; then
      add_nginx_alias "${NW}" .well-known
    fi

    if [ "${OPT_SQUIRRELMAIL}" = "YES" ]; then
      add_nginx_alias "${NW}" squirrelmail
    fi

    if [ "${OPT_ROUNDCUBE}" = "YES" ]; then
      add_nginx_alias "${NW}" roundcube
    fi

    if [ "${OPT_PHPMYADMIN}" = "YES" ]; then
      add_nginx_alias "${NW}" phpMyAdmin
      add_nginx_alias_redirect "${NW}" phpmyadmin phpMyAdmin
      add_nginx_alias_redirect "${NW}" pma phpMyAdmin
    fi

    WEBMAIL_LINK=$(get_webmail_link)
    if [ -e "${WWW_DIR}/${WEBMAIL_LINK}" ]; then
      add_nginx_alias_redirect "${NW}" webmail "${WEBMAIL_LINK}"
    fi

    {
      printf "\tif (\$request_method !~ ^(GET|HEAD|POST)\$ ) {\n"
      printf "\t\treturn 444;\n"
      printf "\t}\n"
      ## CB2: block .htaccess and .user.ini
      printf "\tlocation ~ /(\\.htaccess|\\.htpasswd|\\.user\\.ini) {\n"
      printf "\t\tdeny all;\n"
      printf "\t}\n"
    } >> "${NW}"
  fi

  ## Custom Configuration
  if [ -e "${PB_CUSTOM}/nginx/conf/webapps.hostname.conf" ] && [ "${OPT_WEBSERVER}" = "nginx" ]; then
    cp -pf "${PB_CUSTOM}/nginx/conf/webapps.hostname.conf" "${NW_HOSTNAME}"
  elif [ -e "${PB_CUSTOM}/nginx_reverse/conf/webapps.conf" ] && [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
    cp -pf "${PB_CUSTOM}/nginx_reverse/conf/webapps.hostname.conf" "${NW_HOSTNAME}"
  else
    ## CB2: In nginx-vhosts.conf we don't need to have "real" alias specified, because they already exist when acessing http://IP or http://hostname
    : > ${NW_HOSTNAME}

    if [ "${OPT_PHPMYADMIN}" = "YES" ]; then
      add_nginx_alias_redirect "${NW_HOSTNAME}" phpmyadmin phpMyAdmin
      add_nginx_alias_redirect "${NW_HOSTNAME}" pma phpMyAdmin
    fi

    WEBMAIL_LINK=$(get_webmail_link)
    if [ -e "${WWW_DIR}/${WEBMAIL_LINK}" ]; then
      add_nginx_alias_redirect "${NW_HOSTNAME}" webmail "${WEBMAIL_LINK}"
    fi

    {
      printf "\tif (\$request_method !~ ^(GET|HEAD|POST)\$ ) {\n"
      printf "\t\treturn 444;\n"
      printf "\t}\n"
      ## CB2: block .htaccess and .user.ini
      printf "\tlocation ~ /(\\.htaccess|\\.htpasswd|\\.user\\.ini) {\n"
      printf "\t\tdeny all;\n"
      printf "\t}\n"
    } >> "${NW_HOSTNAME}"
  fi

  cp -pf "${NGINX_PATH}/webapps.conf" "${NGINX_PATH}/webapps.ssl.conf"
  ${PERL} -pi -e "s|:${PORT_8080}|:${PORT_8081}|" "${NGINX_PATH}/webapps.ssl.conf"
  ${PERL} -pi -e 's|http:|https:|' "${NGINX_PATH}/webapps.ssl.conf"

  if [ "${HAVE_FPM_CGI}" = "YES" ]; then
    ## CB2: update the webapps_settings.conf
    ##      swap "fastcgi_pass unix:/usr/local/php54/sockets/webapps.sock;" if needed
    ##      might be a better way to do this, other checks. Close enough for now.

    PHP_REPLACE_STRING="$(grep -m1 '^fastcgi_pass unix:/usr/local/php../sockets/webapps.sock;' "${NGINX_PATH}/webapps_settings.conf" | cut -d/ -f4)"
    if [ -z "${PHP_REPLACE_STRING}" ]; then
      PHP_REPLACE_STRING=php54
    fi
    if [ "${OPT_PHP_MODE}" = "php-fpm" ]; then
      ${PERL} -pi -e "s#${PHP_REPLACE_STRING}#php${OPT_PHP_VER}#" "${NGINX_PATH}/webapps_settings.conf"
    fi
  fi
}

################################################################################
## Create httpd Nginx (from CB2: create_httpd_nginx())
################################################################################

create_httpd_nginx() {

  local APACHE_NGINX_CONF

  APACHE_NGINX_CONF="${APACHE_EXTRAS}/httpd-nginx.conf"

  ${TOUCH} "${APACHE_NGINX_CONF}"

  if [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
    {
      printf "AccelRedirectSet On\n"
      printf "AccelRedirectSize 1k\n"
      printf "RemoteIPHeader X-Client-IP\n"
      printf "RemoteIPInternalProxy 127.0.0.1\n"
      if [ "${IPV6}" = "1" ]; then
        printf "RemoteIPInternalProxy ::1\n"
      fi
      printf "RemoteIPInternalProxyList %s/data/admin/ip.list\n" "${DA_PATH}"
    } > "${APACHE_NGINX_CONF}"
  fi

  return
}

################################################################################
## Do Apache Check (from CB2: doApacheCheck())
################################################################################

doApacheCheck() {

  if [ "${PB_DEBUG}" = "YES" ]; then
    echo "*** Debug: Function: doApacheCheck()"
  fi

  if [ ! -e "${APACHE_EXTRAS}/httpd-includes.conf" ]; then
    printf "" > "${APACHE_EXTRAS}/httpd-includes.conf"
  fi

  if [ ! -e "${SUPHP_AP2_CONF}" ]; then
    printf "" > "${SUPHP_AP2_CONF}"
  fi

  if [ ! -e "${APACHE_EXTRAS}/httpd-php-handlers.conf" ]; then
    printf "" > "${APACHE_EXTRAS}/httpd-php-handlers.conf"
  fi

  if [ ! -e "${APACHE_EXTRAS}/httpd-phpmodules.conf" ]; then
    printf "" > "${APACHE_EXTRAS}/httpd-phpmodules.conf"
  fi

  return
}

################################################################################
## Rewrite Confs (from CB2: doRewriteConfs())
################################################################################

rewrite_confs() {

  local IFS=' '
  local HDC PHPV PHPMODULES WEBMAIL_LINK

  if [ ${PB_DEBUG} = "YES" ]; then
    printf "*** Debug: Function: rewrite_confs()\n"
    printf "OPT_WEBSERVER: %s\t" "${OPT_WEBSERVER}"
    printf "OPT_PHP_MODE: %s\t" "${OPT_PHP_MODE}"
    printf "OPT_PHP_VER: %s\t" "${OPT_PHP_VER}"
    printf "PB_CONFIG: %s\t" "${PB_CONFIG}"
    printf "PB_CONFIG: %s\t" "${PB_CUSTOM}"
    printf "***\n"
    printf "APACHE_PATH: %s\n" "${APACHE_PATH}"
    printf "APACHE_CONF: %s\n" "${APACHE_CONF}"
    printf "APACHE_LIBS: %s\n" "${APACHE_LIBS}"
    printf "APACHE_EXTRAS: %s\n" "${APACHE_EXTRAS}"
    printf "APACHE_SSL_CRT: %s\n" "${APACHE_SSL_CRT}"
    printf "APACHE_SSL_KEY: %s\n" "${APACHE_SSL_KEY}"
    printf "APCUSTOMCONFDIR: %s\n" "${APCUSTOMCONFDIR}"
    printf "***\n"
    printf "PERL: %s\n" "${PERL}"
    printf "DA_CONF: %s\n" "${DA_CONF}"
    printf "DA_CONF_TEMPLATE: %s\n" "${DA_CONF_TEMPLATE}"
    printf "DA_TASK_QUEUE: %s\n" "${DA_TASK_QUEUE}"
    printf "OPENSSL: %s\n" "${OPENSSL}"
    printf "NEWCONFIGS: %s\n" "${NEWCONFIGS}"
    printf "***\n"
    printf "HAVE_FPM_CGI: %s\t" "${HAVE_FPM_CGI}"
    printf "HAVE_CLI: %s\t" "${HAVE_CLI}"
    printf "HAVE_FCGID: %s\t" "${HAVE_FCGID}"
    printf "HAVE_SUPHP_CGI: %s\t" "${HAVE_SUPHP_CGI}"
    # printf "***\n"
    # printf "HAVE_PHP1_FPM: %s\t" "${HAVE_PHP1_FPM}"
    # printf "HAVE_PHP1_CLI: %s\t" "${HAVE_PHP1_CLI}"
    # printf "HAVE_PHP1_FCGID: %s\t" "${HAVE_PHP1_FCGID}"
    # printf "HAVE_PHP1_SUPHP: %s\t" "${HAVE_PHP1_SUPHP}"
    printf "***\n"
    printf "HAVE_FPM56_CGI: %s\t" "${HAVE_FPM56_CGI}"
    printf "HAVE_SUPHP56_CGI: %s\t" "${HAVE_SUPHP56_CGI}"
    printf "HAVE_FCGID56: %s\t" "${HAVE_FCGID56}"
    printf "HAVE_CLI56: %s\t" "${HAVE_CLI56}"
    printf "***\n"
    printf "HAVE_FPM70_CGI: %s\t" "${HAVE_FPM70_CGI}"
    printf "HAVE_SUPHP70_CGI: %s\t" "${HAVE_SUPHP70_CGI}"
    printf "HAVE_FCGID70: %s\t" "${HAVE_FCGID70}"
    printf "HAVE_CLI70: %s\t\n" "${HAVE_CLI70}"
    printf "***\n"
    printf "HAVE_FPM71_CGI: %s\t" "${HAVE_FPM71_CGI}"
    printf "HAVE_SUPHP71_CGI: %s\t" "${HAVE_SUPHP71_CGI}"
    printf "HAVE_FCGID71: %s\t" "${HAVE_FCGID71}"
    printf "HAVE_CLI71: %s\t\n" "${HAVE_CLI71}"
    printf "***\n"

    # echo "PHPMODULES: ${PHPMODULES}"
  fi

  cp ${PB_PATH}/directadmin/data/templates/custom/* "${DA_PATH}/data/templates/custom/"

  ## **************************************************
  ## Apache / Nginx+Apache
  ## **************************************************
  if [ "${OPT_WEBSERVER}" = "apache" ] || [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
    ## Copy the new configuration files
    cp -rf "${PB_CONFIG}/ap2/conf/" "${APACHE_PATH}/"
    cp -f "${PB_CONFIG}/ap2/conf/httpd.conf" "${APACHE_CONF}"
    cp -f "${PB_CONFIG}/ap2/conf/extra/httpd-mpm.conf" "${APACHE_EXTRAS}/httpd-mpm.conf"

    ${PERL} -pi -e 's/^DefaultType/#DefaultType/' "${APACHE_CONF}"

    HDC="${APACHE_EXTRAS}/httpd-directories-old.conf"

    ln -sf "${HDC}" "${APACHE_EXTRAS}/httpd-directories.conf"

    apache_host_conf

    ## Todo:
    APCUSTOMCONFDIR=0
    ## Todo: Custom Apache configurations
    if [ "${APCUSTOMCONFDIR}" != "0" ]; then
      cp -rf "${APCUSTOMCONFDIR}" "${APACHE_PATH}"
    fi

    ${CHMOD} 710 "${APACHE_PATH}"

    ## Swap the |WEBAPPS_PHP_RELEASE| token
    if [ "${OPT_PHP_MODE}" = "php-fpm" ]; then
      PHPV=""
      if [ "${OPT_PHP_MODE}" = "php-fpm" ]; then
        PHPV="${OPT_PHP_VER}"
      fi
      if [ -n "${PHPV}" ]; then
        ${PERL} -pi -e "s/\|WEBAPPS_PHP_RELEASE\|/${PHPV}/" "${HDC}"
      fi
    fi

    verify_server_ca

    ## CB2: Verify we have the correct apache_ver
    if [ "$(grep -m1 -c apache_ver=2.0 "${DA_CONF_TEMPLATE}")" -eq "0" ]; then
      setVal apache_ver 2.0 "${DA_CONF_TEMPLATE}"
    elif [ "$(grep -m1 -c apache_ver= ${DA_CONF_TEMPLATE})" -ne "0" ]; then
      ${PERL} -pi -e "s/$(grep apache_ver= ${DA_CONF_TEMPLATE})/apache_ver=2.0/" "${DA_CONF_TEMPLATE}"
    fi

    if [ "$(grep -m1 -c apache_ver=2.0 "${DA_CONF}")" -eq "0" ]; then
      setVal apache_ver 2.0 "${DA_CONF}"
      echo "action=rewrite&value=httpd" >> "${DA_TASK_QUEUE}"
    elif [ "$(grep -m1 -c apache_ver= "${DA_CONF}")" -ne "0" ]; then
      ${PERL} -pi -e "s/$(grep apache_ver= "${DA_CONF}")/apache_ver=2.0/" "${DA_CONF}"
      echo "action=rewrite&value=httpd" >> "${DA_TASK_QUEUE}"
    fi

    do_rewrite_httpd_alias

    ## Rewrite ips.conf
    echo "action=rewrite&value=ips" >> "${DA_TASK_QUEUE}"

    run_dataskq

    ## CB2: Tokenize the IP and ports
    tokenize_IP
    tokenize_ports

    ## Add all the Include lines if they do not exist
    if [ "$(grep -m1 -c 'Include' "${APACHE_EXTRAS}/directadmin-vhosts.conf")" = "0" ] ||
      [ ! -e "${APACHE_EXTRAS}/directadmin-vhosts.conf" ]; then
      rewrite_vhosts
    fi

    ## Verify SSL directory exists
    if [ ! -d "${APACHE_PATH}/ssl" ]; then
      ${MKDIR} -p "${APACHE_PATH}/ssl"
    fi

    ## Generate SSL Key & Certificate if they don't exist
    if [ ! -e "${APACHE_SSL_KEY}" ] || [ ! -e "${APACHE_SSL_CRT}" ]; then
      ${OPENSSL} req -x509 -newkey rsa:2048 -keyout "${APACHE_SSL_KEY}" \
      -out "${APACHE_SSL_CRT}" -days 9999 -nodes -config "${SSL_REQ_CONF}" # "${OPENSSL_EXTRA}"
      ${CHMOD} 600 "${APACHE_SSL_CRT}"
      ${CHMOD} 600 "${APACHE_SSL_KEY}"
    fi

    doApacheCheck

    PHPMODULES="${APACHE_EXTRAS}/httpd-phpmodules.conf"

    printf "" > "${APACHE_EXTRAS}/httpd-nginx.conf"
    printf "" > "${PHPMODULES}"

    if [ "${HAVE_SUPHP_CGI}" = "YES" ]; then
      ${PERL} -pi -e 's|^LoadModule suphp_module|#LoadModule suphp_module|' "${APACHE_CONF}"
      printf "LoadModule suphp_module %s/mod_suphp.so\n" "${APACHE_LIBS}" >> "${PHPMODULES}"
    fi

    ## mod_security:
    if [ "${OPT_MODSECURITY}" = "YES" ] && [ "${OPT_WEBSERVER}" = "apache" ]; then
      ${PERL} -pi -e 's|^LoadModule security2_module|#LoadModule security2_module|' "${APACHE_CONF}"
      printf "Include %s/httpd-modsecurity.conf\n" "${APACHE_EXTRAS}" >> "${PHPMODULES}"
      cp -pf "${MODSECURITY_APACHE_INCLUDE}" "${APACHE_EXTRAS}/httpd-modsecurity.conf"
      update_modsecurity_rules norestart
    fi

    ## HTScanner:
    if [ "${OPT_HTSCANNER}" = "YES" ]; then
      if [ "${HAVE_FCGID}" = "YES" ] || [ "${HAVE_FPM_CGI}" = "YES" ] || [ "${HAVE_SUPHP_CGI}" = "YES" ]; then
        ${PERL} -pi -e 's|^LoadModule htscanner_module|#LoadModule htscanner_module|' "${APACHE_CONF}"
        printf "LoadModule htscanner_module %s/mod_htscanner2.so\n" "${APACHE_LIBS}" >> "${PHPMODULES}"
      fi
    fi

    ## Example: ${APACHE_LIBS}/mod_mpm_event.so

    if ! grep -m1 -q "${APACHE_LIBS}/mod_mpm_" "${PHPMODULES}"; then
      ## Use event MPM for php-fpm and prefork for mod_php
      if [ "${OPT_APACHE_MPM}" = "auto" ]; then
          ## Add to httpd-phpmodules.conf
        if [ "${HAVE_CLI}" = "NO" ]; then
          printf "LoadModule mpm_event_module %s/mod_mpm_event.so\n" "${APACHE_LIBS}" >> "${PHPMODULES}"
        else
          printf "LoadModule mpm_prefork_module %s/mod_mpm_prefork.so\n" "${APACHE_LIBS}" >> "${PHPMODULES}"
        fi
      elif [ "${OPT_APACHE_MPM}" = "event" ]; then
        printf "LoadModule mpm_event_module %s/mod_mpm_event.so\n" "${APACHE_LIBS}" >> "${PHPMODULES}"
      elif [ "${OPT_APACHE_MPM}" = "worker" ]; then
        printf "LoadModule mpm_worker_module %s/mod_mpm_worker.so\n" "${APACHE_LIBS}" >> "${PHPMODULES}"
      else
        printf "LoadModule mpm_prefork_module %s/mod_mpm_prefork.so\n" "${APACHE_LIBS}" >> "${PHPMODULES}"
      fi
    fi

    ${PERL} -pi -e 's/^LoadModule php4/\#LoadModule php4/' "${APACHE_CONF}"
    ${PERL} -pi -e 's/^LoadModule php5/\#LoadModule php5/' "${APACHE_CONF}"
    ${PERL} -pi -e 's/^LoadModule php7/\#LoadModule php7/' "${APACHE_CONF}"

    ## Add correct PHP module to httpd-phpmodules.conf

    ## PHP: mod_php:
    if [ "${OPT_PHP_MODE}" = "mod_php" ]; then
      if [ "${OPT_PHP_VER}" = "70" ]; then
        printf "LoadModule php7_module %s/libphp7.so\n" "${APACHE_LIBS}" >> "${PHPMODULES}"
      else
        printf "LoadModule php5_module %s/libphp5.so\n" "${APACHE_LIBS}" >> "${PHPMODULES}"
      fi
    fi

    ## FCGID:
    if [ "${HAVE_FCGID}" = "YES" ]; then
      if [ -e "${PHPMODULES}" ]; then
        if ! grep -m1 -c 'fcgid_module' "${PHPMODULES}"; then
          ${PERL} -pi -e 's|^LoadModule  fcgid_module|#LoadModule  fcgid_module|' "${APACHE_CONF}"
          printf "LoadModule fcgid_module %s/mod_fcgid.so\n" "${APACHE_LIBS}" >> "${PHPMODULES}"
        fi
        if ! grep -m1 -c 'httpd-fcgid.conf' "${PHPMODULES}"; then
          printf "Include %s/httpd-fcgid.conf\n" "${APACHE_EXTRAS}" >> "${PHPMODULES}"
        fi
      fi

      if [ ! -d /usr/local/safe-bin ]; then
        ${MKDIR} -p /usr/local/safe-bin
        ${CHMOD} 511 /usr/local/safe-bin
        ${CHOWN} "${APACHE_USER}:${APACHE_GROUP}" /usr/local/safe-bin
      fi

      cp -f "${PB_CONFIG}/fastcgi/fcgid${OPT_PHP_VER}.sh" "/usr/local/safe-bin/fcgid${OPT_PHP_VER}.sh"

      ## Custom configuration
      if [ -e "${PB_CUSTOM}/fastcgi/fcgid${OPT_PHP_VER}.sh" ]; then
        cp -f "${PB_CUSTOM}/fastcgi/fcgid${OPT_PHP_VER}.sh" "/usr/local/safe-bin/fcgid${OPT_PHP_VER}.sh"
      fi
      ${CHOWN} "${APACHE_USER}:${APACHE_GROUP}" "/usr/local/safe-bin/fcgid${OPT_PHP_VER}.sh"
      ${CHMOD} 555 "/usr/local/safe-bin/fcgid${OPT_PHP_VER}.sh"
    fi

    ## SuPHP:
    if [ "${HAVE_SUPHP_CGI}" = "YES" ]; then
      if [ -e "${PHPMODULES}" ]; then
        if ! grep -m1 -q 'suphp_module' "${PHPMODULES}"; then
          printf "LoadModule suphp_module %s/mod_suphp.so\n" "${APACHE_LIBS}" >> "${PHPMODULES}"
        fi
      fi
    fi

    if [ "${NEWCONFIGS}" = "1" ]; then
      ${PERL} -pi -e 's/^LoadModule mod_php/\#LoadModule mod_php/' "${APACHE_CONF}"
      ${PERL} -pi -e 's/^LoadModule php/\#LoadModule php/' "${APACHE_CONF}"
      ${PERL} -pi -e 's/^LoadModule suphp/\#LoadModule suphp/' "${APACHE_CONF}"
    fi

    WEBMAIL_LINK=$(get_webmail_link)
    ${PERL} -pi -e "s#Alias /webmail \"${WWW_DIR}/roundcube/\"#Alias /webmail \"${WWW_DIR}/${WEBMAIL_LINK}/\"#" "${APACHE_EXTRAS}/httpd-alias.conf"

    ## test:
    # SUEXEC_PER_DIR=1
    # echo "$(eval_var ${SUEXEC_PER_DIR})"

    php_conf
    # doModLsapi 0

    ## Disable UserDir access if userdir_access=no is set in the options.conf file
    if [ "${OPT_USERDIR_ACCESS}" = "NO" ]; then
      ${PERL} -pi -e 's#UserDir public_html#UserDir disabled#' "${APACHE_EXTRAS}/httpd-vhosts.conf"
    else
      ${PERL} -pi -e 's#UserDir disabled#UserDir public_html#' "${APACHE_EXTRAS}/httpd-vhosts.conf"
    fi

    create_httpd_nginx

    if [ "${OPT_WEBSERVER}" = "apache" ] || [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
      printf "Restarting Apache\n"
      ${SERVICE} apache24 restart
    fi
  fi

  ## **************************************************
  ## Nginx:
  ## **************************************************
  if [ "${OPT_WEBSERVER}" = "nginx" ] || [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
    # Copy the new configs
    cp -rf "${NGINXCONFDIR}/*" "${NGINX_PATH}"

    do_rewrite_nginx_webapps
    verify_server_ca

    ## Todo:
    verify_dhparam "${NGINX_PATH}/ssl/dhparams.pem"

    if [ "${OPT_MODSECURITY}" = "YES" ]; then
      update_modsecurity_rules norestart
    fi

    ## Rewrite ips.conf
    echo "action=rewrite&value=nginx" >> "${TASK_QUEUE}"
    echo "action=rewrite&value=ips" >> "${TASK_QUEUE}"

    run_dataskq

    # Add all the Include lines if they do not exist
    if [ "$(grep -m1 -c 'Include' "${NGINX_PATH}/directadmin-vhosts.conf")" = "0" ] ||
      [ ! -e "${NGINX_PATH}/directadmin-vhosts.conf" ]; then
      rewrite_vhosts
    fi

    if [ ! -e "${NGINX_PATH}/directadmin-settings.conf" ]; then
      ${TOUCH} "${NGINX_PATH}/directadmin-settings.conf"
    fi

    if [ ! -e "${NGINX_PATH}/directadmin-ips.conf" ]; then
      ${TOUCH} "${NGINX_PATH}/directadmin-ips.conf"
    fi

    if [ ! -e "${NGINX_PATH}/nginx-includes.conf" ]; then
      ${TOUCH} "${NGINX_PATH}/nginx-includes.conf"
    fi

    if [ ! -e "${NGINX_PATH}/nginx-modsecurity-enable.conf" ]; then
      ${TOUCH} "${NGINX_PATH}/nginx-modsecurity-enable.conf"
    elif [ "${OPT_MODSECURITY}" = "NO" ]; then
      printf '' > "${NGINX_PATH}/nginx-modsecurity-enable.conf"
    fi

    if [ "${NGINXCUSTOMCONFDIR}" != "0" ]; then
      cp -rf "${NGINXCUSTOMCONFDIR}/*" "${NGINX_PATH}/"
    fi

    ${CHMOD} 710 "${NGINX_PATH}"

    if [ "${IPV6}" = "1" ]; then
      ${PERL} -pi -e 's| #listen       \[::1\]:| listen       \[::1\]:|' "${NGINX_PATH}/nginx-vhosts.conf"
      ${PERL} -pi -e 's| #listen       \[::1\]:| listen       \[::1\]:|' "${NGINX_PATH}/nginx.conf"
    else
      ${PERL} -pi -e 's| listen       \[::1\]:| #listen       \[::1\]:|' "${NGINX_PATH}/nginx-vhosts.conf"
      ${PERL} -pi -e 's| listen       \[::1\]:| #listen       \[::1\]:|' "${NGINX_PATH}/nginx.conf"
    fi

    ${PERL} -pi -e "s#worker_processes  1;#worker_processes  ${CPU_CORES};#" "${NGINX_PATH}/nginx.conf"

    tokenize_IP
    tokenize_ports

    ## Disable UserDir access if userdir_access=no is set in the options.conf file
    if [ "${OPT_USERDIR_ACCESS}" = "NO" ]; then
      ${PERL} -pi -e "s| include ${NGINX_PATH}/nginx-userdir.conf;| #include ${NGINX_PATH}/nginx-userdir.conf;|" "${NGINX_PATH}/nginx-vhosts.conf"
    else
      ${PERL} -pi -e "s| #include ${NGINX_PATH}/nginx-userdir.conf;| include ${NGINX_PATH}/nginx-userdir.conf;|" "${NGINX_PATH}/nginx-vhosts.conf"
    fi

    php_conf

    printf "Restarting nginx.\n"
    # /usr/sbin/nginx -s stop >/dev/null 2>&1
    ${SERVICE} nginx restart
  fi

  ## **************************************************
  ## Nginx+Apache:
  ## **************************************************
  if [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
    setVal nginx 0 "${DA_CONF_TEMPLATE}"
    setVal nginx 0 "${DA_CONF}"
    setVal nginx_proxy 1 "${DA_CONF_TEMPLATE}"
    setVal nginx_proxy 1 "${DA_CONF}"
  fi

  verify_webapps_tmp

  directadmin_restart

  return
}

################################################################################
## Run DirectAdmin Task Query (from CB2)
################################################################################

run_dataskq() {

  local DATASKQ_OPT="$1"

  if [ -s "${DA_CONF}" ]; then
    "${DA_PATH}/dataskq" "${DATASKQ_OPT}" --custombuild
  fi

  return
}

################################################################################
## Rewrite directadmin-vhosts.conf (from CB2: doVhosts())
################################################################################

rewrite_vhosts() {

  local IFS=' '
  local PATHNAME="${APACHE_EXTRAS}"

  printf "*** Notice: Starting: Rewriting Virtual Hosts via rewrite_vhosts()\n"

  if [ "${OPT_WEBSERVER}" = "nginx" ]; then
    PATHNAME="${NGINX_PATH}"
  fi

  if [ ! -d "${PATHNAME}" ]; then
    ${MKDIR} -p "${PATHNAME}"
  fi

  printf '' > "${APACHE_EXTRAS}/directadmin-vhosts.conf"

  if [ "${OPT_WEBSERVER}" = "nginx" ]; then
    for i in ${DA_PATH}/data/users/*/nginx.conf ; do
      echo "include $i;" >> "${APACHE_EXTRAS}/directadmin-vhosts.conf"
    done
  elif [ "${OPT_WEBSERVER}" = "apache" ]; then
    for i in ${DA_PATH}/data/users/*/httpd.conf ; do
      echo "Include $i" >> "${APACHE_EXTRAS}/directadmin-vhosts.conf"
    done
  elif [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
    printf '' > "${NGINX_PATH}/directadmin-vhosts.conf"
    for i in ${DA_PATH}/data/users/*/nginx.conf ; do
      echo "include $i;" >> "${NGINX_PATH}/directadmin-vhosts.conf"
    done
    for i in ${DA_PATH}/data/users/*/httpd.conf ; do
      echo "Include $i" >> "${APACHE_EXTRAS}/directadmin-vhosts.conf"
    done
  else
    printf "*** Error: rewrite_hosts(): No suitable webserver selected.\n"
  fi

  printf "*** Notice: Completed: Rewriting Virtual Hosts via rewrite_vhosts()\n"

  return
}

################################################################################
## Verify Server CA Certificate (from CB2: ensure_server_ca())
################################################################################

verify_server_ca() {

  local SSL_CA SSL_CRT SSL_KEY NG_CA NG_CRT NG_KEY

  if [ "${PB_DEBUG}" = "YES" ]; then
    echo "*** Debug: Function: verify_server_ca()"
    echo "APACHE_SSL_CRT: ${APACHE_SSL_CRT}"
    echo "APACHE_SSL_KEY: ${APACHE_SSL_KEY}"
    echo "APACHE_SSL_CA: ${APACHE_SSL_CA}"
  fi

  if [ "${OPT_WEBSERVER}" = "apache" ] || [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
    SSL_CA="${APACHE_SSL_CA}"
    SSL_CRT="${APACHE_SSL_CRT}"
    SSL_KEY="${APACHE_SSL_KEY}"
    ## PB: ${MKDIR} -p ${APACHE_PATH}/ssl.crt
  elif [ "${OPT_WEBSERVER}" = "nginx" ]; then
    SSL_CA="${NGINX_SSL_CA}"
    SSL_CRT="${NGINX_SSL_CRT}"
    ## PB: ${MKDIR} -p ${NGINX_PATH}/ssl.crt
  else
    printf "*** Script Error: verify_server_ca(): Unknown value for WEBSERVER=%s\n" "${OPT_WEBSERVER}"
    return
  fi

  if [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
    ${MKDIR} -p ${NGINX_PATH}/ssl
  fi

  printf "Making sure %s exists.\n" "${SSL_CA}"

  ## Copy root CA cert from PORT_CA_ROOT_NSS package (or install it)
  if [ ! -s "${SSL_CA}" ]; then
    if [ -s /usr/local/share/certs/ca-root-nss.crt ]; then
      printf "Copying ca-root-nss.crt to %s\n" "${SSL_CA}"
      cp -f /usr/local/share/certs/ca-root-nss.crt "${SSL_CA}"
    else
      pkgi "${PORT_CA_ROOT_NSS}"
      if [ "$?" = 0 ]; then
        printf "Copying ca-root-nss.crt to %s\n" "${SSL_CA}"
        cp -f /usr/local/share/certs/ca-root-nss.crt "${SSL_CA}"
      fi
    fi
  fi

  ## PB: Todo: Download CA cert
  # if [ ! -s ${SSL_CA} ]; then
  #   printf "Downloading a generic server SSL Certificate Authority...\n"
  #   ${WGET} ${WGET_CONNECT_OPTIONS} -O ${SSL_CA} ${WEBPATH_SERVICES}/configure/ssl/server.ca
  # fi

  ## Nginx+Apache
  if [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
    if [ -s "${SSL_CRT}" ] && [ -s "${SSL_CA}" ]; then
      cat "${SSL_CRT}" > "${SSL_CRT}.combined"
      ## CB2: Sometimes we don't have a new line in SSL_CRT, so we add one to separate SSL_CRT and SSL_CA
      printf "\n" >> "${SSL_CRT}.combined"
      cat "${SSL_CA}" >> "${SSL_CRT}.combined"
    fi

    NG_CA="${NGINX_SSL_CA}"
    NG_CRT="${NGINX_SSL_CRT}"
    NG_KEY="${NGINX_SSL_KEY}"

    cp -f "${SSL_CA}" "${NG_CA}"
    cp -f "${SSL_CRT}" "${NG_CRT}"
    cp -f "${SSL_KEY}" "${NG_KEY}"
  fi

  ## Nginx / Nginx+Apache
  if [ "${OPT_WEBSERVER}" = "nginx" ] || [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
    NG_CA="${NGINX_SSL_CA}"
    NG_CRT="${NGINX_SSL_CRT}"

    if [ -s "${NG_CRT}" ] && [ -s "${NG_CA}" ]; then
      cat "${NG_CRT}" > "${NG_CRT}.combined"
      ## CB2: Sometimes we don't have a new line in SSL_CRT,
      ##      so we add one to separate SSL_CRT and SSL_CA
      printf "\n" >> "${SSL_CRT}.combined"
      cat "${NG_CA}" >> "${NG_CRT}.combined"
    fi

    ${CHMOD} 600 "${NGINX_SSL_CA}"
    ${CHMOD} 600 "${NGINX_SSL_CRT}"
    ${CHMOD} 600 "${NG_CRT}.combined"
  fi

  return
}

################################################################################
## Backup HTTP (from CB2: backupHttp())
################################################################################

backup_http() {

  printf "Backing up Apache's SSL certificate and key, and tur/usr/local/directadmin/data/users/ning off DirectAdmin's httpd status check.\n"

  if [ -e "${APACHE_SSL_CRT}" ]; then
    cp -fp "${APACHE_SSL_CRT}" "${APACHE_SSL_CRT}.backup"
  fi

  if [ -e "${APACHE_SSL_KEY}" ]; then
    cp -fp "${APACHE_SSL_KEY}" "${APACHE_SSL_KEY}.backup"
  fi

  if [ -e "${APACHE_CONF}" ]; then
    cp -fp "${APACHE_CONF}" "${APACHE_CONF}.backup"
  fi

  ## Verify: Turn off httpd service checking
  # set_service apache24 OFF

  return
}

################################################################################
## Restore HTTP (from CB2: restoreHttp())
################################################################################

restore_http() {

  printf "Restoring Apache's SSL certificate and key, and turning on DirectAdmin's httpd status check.\n"

  if [ -e "${APACHE_SSL_CRT}.backup" ]; then
    cp -fp "${APACHE_SSL_CRT}.backup" "${APACHE_SSL_CRT}"
    ${CHMOD} 600 "${APACHE_SSL_CRT}"
  fi

  if [ -e "${APACHE_SSL_KEY}.backup" ]; then
    cp -fp "${APACHE_SSL_KEY}.backup" "${APACHE_SSL_KEY}"
    ${CHMOD} 600 ${APACHE_SSL_KEY}
  fi

  if [ -e "${APACHE_CONF}.backup" ]; then
    cp -fp "${APACHE_CONF}.backup" "${APACHE_CONF}"
  fi

  verify_server_ca

  ## Verify: Turn on httpd service checking
  # set_service apache24 ON

  return
}

################################################################################
## Suhosin Installation
################################################################################

suhosin_install() {

  if [ "${OPT_SUHOSIN}" != "YES" ]; then
    printf "*** Error: Suhosin is not enabled in options.conf\n"
    return
  fi

  printf "Starting Suhosin installation\n"

  ## Main Installation
  pkgi "${PORT_SUHOSIN}"

  ## Add support for scanning uploads using ClamAV
  if [ "${OPT_SUHOSIN_UPLOADSCAN}" = "YES" ] && [ ! -e "${CLAMDSCAN}" ]; then
    printf "*** Error: Cannot install Suhosin with PHP upload scan using ClamAV,\n\
      because %s does not exist on the system" "${CLAMDSCAN}"
    if [ "${OPT_CLAMAV}" = "NO" ]; then
      printf " and CLAMAV=NO is set in the options.conf file.\n"
      return #exit
    fi
    printf ".\n"

    clamav_install
  fi

  return
}

################################################################################
## Tokenize the IP (from CB2: tokenizeIP())
################################################################################

tokenize_IP() {

  local TOKENFILE_APACHE TOKENFILE_NGINX TOKENFILE_NGINX_USERDIR HOSTNAME
  local LAN_IP IP STR

  TOKENFILE_APACHE="${APACHE_EXTRAS}/httpd-vhosts.conf"
  TOKENFILE_NGINX="${NGINX_PATH}/nginx.conf"

  if [ -e "${TOKENFILE_NGINX}" ]; then
    if grep -q -m1 'nginx-vhosts\.conf' "${TOKENFILE_NGINX}"; then
      TOKENFILE_NGINX="${NGINX_PATH}/nginx-vhosts.conf"
    fi
  fi

  TOKENFILE_NGINX_USERDIR="${NGINX_PATH}/nginx-userdir.conf"

  HOSTNAME=$(hostname)

  IP="$(grep -r -l -m1 '^status=server$' /usr/local/directadmin/data/admin/ips | cut -d/ -f8)"
  if [ -z "${IP}" ]; then
    IP="$(grep -m1 "${HOSTNAME}" /etc/hosts | awk '{print $1}')"
    if [ -z "${IP}" ]; then
      printf "Unable to detect your server's IP in /etc/hosts. \nPlease enter it: "
      read IP
    fi
  fi

  if [ -z "${IP}" ]; then
    printf "Unable to detect your server IP. Exiting.\n"
    exit 0 # was: do_exit 0
  fi

  if [ "$(echo "${IP}" | grep -m1 -c ':')" -gt 0 ]; then
    IP="[${IP}]"
  fi

  printf "Using %s as your server's IP address.\n" "${IP}"

  LAN_IP=$(getDA_Opt lan_ip "")

  ## Apache or Nginx+Apache
  if [ "${OPT_WEBSERVER}" = "apache" ] || [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
    if [ -e "${TOKENFILE_APACHE}" ]; then
      if [ "$(grep -m1 -c '|IP|' ${TOKENFILE_APACHE})" -gt "0" ]; then
        STR="${PERL} -pi -e 's/\|IP\|/$IP/' ${TOKENFILE_APACHE}"
        eval "${STR}"
      fi
    fi
  fi

  ## Nginx or Nginx+Apache
  if [ "${OPT_WEBSERVER}" = "nginx" ] || [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
    if [ -e "${TOKENFILE_NGINX}" ]; then
      if [ "$(grep -m1 -c '|IP|' "${TOKENFILE_NGINX}")" -gt "0" ]; then
        if [ -n "${LAN_IP}" ]; then
          printf "Using lan_ip=%s as a secondary server IP address.\n" "${LAN_IP}"
          STR="${PERL} -pi -e 's/\|IP\|:\|PORT_80\|;/\|IP\|:\|PORT_80\|;\n\tlisten\t\t$LAN_IP:\|PORT_80\|;/' ${TOKENFILE_NGINX}"
          eval "${STR}"
          STR="${PERL} -pi -e 's/\|IP\|:\|PORT_443\| ssl;/\|IP\|:\|PORT_443\| ssl;\n\tlisten\t\t$LAN_IP:\|PORT_443\| ssl;/' ${TOKENFILE_NGINX}"
          eval "${STR}"
        fi
        printf "Using %s for your server's IP address.\n" "$IP"
        STR="${PERL} -pi -e 's/\|IP\|/$IP/' ${TOKENFILE_NGINX}"
        eval "${STR}"
      fi
    fi

    ## Nginx UserDir
    if [ -e "${TOKENFILE_NGINX_USERDIR}" ]; then
      if [ "$(grep -m1 -c '|IP|' "${TOKENFILE_NGINX_USERDIR}")" -gt "0" ]; then
        if [ -n "${LAN_IP}" ]; then
          STR="${PERL} -pi -e 's/\|IP\|:\|PORT_80\|;/\|IP\|:\|PORT_80\|;\n\tlisten\t\t$LAN_IP:\|PORT_80\|;/' ${TOKENFILE_NGINX_USERDIR}"
          eval "${STR}"
          STR="${PERL} -pi -e 's/\|IP\|:\|PORT_443\| ssl;/\|IP\|:\|PORT_443\| ssl;\n\tlisten\t\t$LAN_IP:\|PORT_443\| ssl;/' ${TOKENFILE_NGINX_USERDIR}"
          eval "${STR}"
        fi
        STR="${PERL} -pi -e 's/\|IP\|/$IP/' ${TOKENFILE_NGINX_USERDIR}"
        eval "${STR}"
      fi
    fi
  fi
}

################################################################################
## Tokenize Ports (from CB2: tokenize_ports())
################################################################################

tokenize_ports() {

  local TOKENFILE_APACHE TOKENFILE_NGINX TOKENFILE_NGINX_USERDIR
  local SSLFILE STR

  TOKENFILE_APACHE="${APACHE_PATH}/extra/httpd-vhosts.conf"
  TOKENFILE_NGINX="${NGINX_PATH}/nginx.conf"

  if [ -e "${TOKENFILE_NGINX}" ]; then
    if grep -q -m1 'nginx-vhosts\.conf' "${TOKENFILE_NGINX}"; then
      TOKENFILE_NGINX="${NGINX_PATH}/nginx-vhosts.conf"
    fi
  fi

  TOKENFILE_NGINX_USERDIR="${NGINX_PATH}/nginx-userdir.conf"

  if [ "${OPT_WEBSERVER}" = "apache" ]; then
    if [ -e "${TOKENFILE_APACHE}" ]; then
      if [ "$(grep -m1 -c '|PORT_80|' "${TOKENFILE_APACHE}")" -gt "0" ]; then
        STR="${PERL} -pi -e \"s/\|PORT_80\|/${PORT_80}/\" ${TOKENFILE_APACHE}"
        eval "${STR}"
      else
        ${PERL} -pi -e "s/:${PORT_8080}\>/:${PORT_80}\>/" "${TOKENFILE_APACHE}"
        ${PERL} -pi -e "s/^Listen ${PORT_8080}$/Listen ${PORT_80}/" "${TOKENFILE_APACHE}"
      fi
      if [ "$(grep -m1 -c '|PORT_443|' "${TOKENFILE_APACHE}")" -gt "0" ]; then
        STR="${PERL} -pi -e \"s/\|PORT_443\|/${PORT_443}/\" ${TOKENFILE_APACHE}"
        eval "${STR}"
      else
        ${PERL} -pi -e "s/:${PORT_8081}\>/:${PORT_443}\>/" "${TOKENFILE_APACHE}"
        ${PERL} -pi -e "s/^Listen ${PORT_8081}$/Listen ${PORT_443}/" "${TOKENFILE_APACHE}"
      fi

      SSLFILE="${APACHE_EXTRAS}/httpd-ssl.conf"

      STR="${PERL} -pi -e \"s/\|PORT_443\|/${PORT_443}/\" ${SSLFILE}"
      eval "${STR}"
      ${PERL} -pi -e "s/:${PORT_8081}\>/:${PORT_443}\>/" "${SSLFILE}"
      ${PERL} -pi -e "s/^Listen ${PORT_8081}$/Listen ${PORT_443}/" "${SSLFILE}"

      STR="${PERL} -pi -e \"s/\|PORT_80\|/${PORT_80}/\" ${APACHE_CONF}"
      eval "${STR}"
      ${PERL} -pi -e "s/:${PORT_8080}\>/:${PORT_80}\>/" "${APACHE_CONF}"
      ${PERL} -pi -e "s/^Listen ${PORT_8080}$/Listen ${PORT_80}/" "${APACHE_CONF}"
    fi
  fi

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

    if [ -e "${TOKENFILE_APACHE}" ]; then
      if [ "$(grep -m1 -c '|PORT_80|' "${TOKENFILE_APACHE}")" -gt "0" ]; then
        STR="${PERL} -pi -e \"s/\|PORT_80\|/${PORT_8080}/\" ${TOKENFILE_APACHE}"
        eval "${STR}"
      else
        ${PERL} -pi -e "s/:${PORT_80}\>/:${PORT_8080}\>/" "${TOKENFILE_APACHE}"
      fi

      if [ "$(grep -m1 -c '|PORT_443|' "${TOKENFILE_APACHE}")" -gt "0" ]; then
        STR="${PERL} -pi -e \"s/\|PORT_443\|/${PORT_8081}/\" ${TOKENFILE_APACHE}"
        eval "${STR}"
      else
        ${PERL} -pi -e "s/:${PORT_443}\>/:${PORT_8081}\>/" "${TOKENFILE_APACHE}"
      fi

      if [ "$(grep -m1 -c "^Listen ${PORT_80}$" "${APACHE_CONF}")" -gt 0 ]; then
        STR="${PERL} -pi -e \"s/^Listen ${PORT_80}$/Listen ${PORT_8080}/\" ${APACHE_CONF}"
        eval "${STR}"
      else
        ${PERL} -pi -e "s/:${PORT_80}\>/:${PORT_8080}\>/" "${APACHE_CONF}"
      fi

      STR="${PERL} -pi -e \"s/\|PORT_80\|/${PORT_8080}/\" ${APACHE_CONF}"
      eval "${STR}"
      ${PERL} -pi -e "s/:${PORT_80}\>/:${PORT_8080}\>/" "${APACHE_CONF}"
      ${PERL} -pi -e "s/^Listen ${PORT_80}$/Listen ${PORT_8080}/" "${APACHE_CONF}"

      SSLFILE="${APACHE_EXTRAS}/httpd-ssl.conf"

      STR="${PERL} -pi -e \"s/\|PORT_443\|/${PORT_8081}/\" ${SSLFILE}"
      eval "${STR}"
      ${PERL} -pi -e "s/:${PORT_443}\>/:${PORT_8081}\>/" "${SSLFILE}"
      ${PERL} -pi -e "s/^Listen ${PORT_443}$/Listen ${PORT_8081}/" "${SSLFILE}"
    fi
  fi

  return
}

################################################################################
## Verify: Todo: PHP Configuration (from CB2: doPhpConf())
################################################################################

php_conf() {

  local IFS=' '

   if [ "${PB_DEBUG}" = "YES" ]; then
    echo "*** Debug: Function: php_conf()"
    echo "PHP_HANDLERS_CONF: ${PHP_HANDLERS_CONF}"
    echo "SUPHP_AP2_CONF: ${SUPHP_AP2_CONF}"
    echo "HAVE_SUPHP_CGI: ${HAVE_SUPHP_CGI}"
  fi

  if [ "${HAVE_FPM_CGI}" = "YES" ]; then
    set_service "php-fpm" OFF
  else
    set_service "php-fpm" delete
  fi

  fpmChecks

  if [ "${OPT_WEBSERVER}" = "apache" ] || [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
    apache_host_conf

    ## Custom Configuration
    if [ -e "${PB_CUSTOM}/ap2/conf/extra/httpd-php-handlers.conf" ]; then
      cp -f "${PB_CUSTOM}/ap2/conf/extra/httpd-php-handlers.conf" "${PHP_HANDLERS_CONF}"
    else
      ## Generate httpd-php-handlers.conf
      printf "" > "${PHP_HANDLERS_CONF}"
      {
        printf "<FilesMatch \"\.(inc|php|php3|php4|php44|php5|php52|php53|php54|php55|php56|php70|php71|php6|phtml|phps)\$\">\n"
        if [ "${OPT_PHP_MODE}" = "mod_php" ]; then
          printf "AddHandler application/x-httpd-php .inc .php .php5 .php%s .phtml\n" "${OPT_PHP_VER}"
        fi
        if [ "${OPT_PHP_MODE}" = "mod_php" ]; then
          printf "AddHandler application/x-httpd-php-source .phps\n"
        fi
        printf "</FilesMatch>\n"
        printf "AddType text/html .php\n"
      } > "${PHP_HANDLERS_CONF}"
    fi
  fi

  eval "$(echo "HAVE_FPM${OPT_PHP_VER}=YES")"

  if [ "${OPT_PHP_MODE}" = "php-fpm" ]; then
    php_fpm_restart
    set_service "php-fpm" ON
    eval "$(echo "HAVE_FPM${OPT_PHP_VER}=YES")"
  fi

  ## Cleanup:
  EVAL_FPM_VAR=HAVE_FPM${OPT_PHP_VER}
  HAVE_SHORTRELEASE="$(eval_var ${EVAL_FPM_VAR})"

  if [ "${HAVE_SHORTRELEASE}" = "NO" ]; then
    if [ -x "${RCD}/php-fpm" ]; then
      ${SERVICE} "php-fpm" stop
    fi
    set_service "php-fpm" delete
    ## Verify: delete instead? (-x)
    ${SYSRC} -q php_fpm_enable="NO"
  fi

  ## Generate suphp.conf:
  if [ "${OPT_WEBSERVER}" = "apache" ] || [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
    if [ "${HAVE_SUPHP_CGI}" = "YES" ]; then
      {
        printf "[global]\n"
        printf ";Path to logfile\n"
        printf "logfile=%s/suphp.log\n\n" "${LOGS}"
        printf ";Loglevel\n"
        printf "loglevel=warn\n\n"
        printf ";User Apache is running as\n"
        printf "webserver_user=%s\n\n" "${APACHE_USER}"
        printf ";Path all scripts have to be in\n"
        printf "docroot=/\n\n"
        printf ";Security options\n"
        printf "allow_file_group_writeable=false\n"
        printf "allow_file_others_writeable=false\n"
        printf "allow_directory_group_writeable=false\n"
        printf "allow_directory_others_writeable=false\n\n"
        printf ";Check wheter script is within DOCUMENT_ROOT\n"
        printf "check_vhost_docroot=false\n\n"
        printf ";Send minor error messages to browser\n"
        printf "errors_to_browser=true\n\n"
        printf ";PATH environment variable\n"
        printf "env_path=\"/bin:/usr/bin\"\n\n"
        printf ";Umask to set, specify in octal notation\n"
        printf "umask=0022\n\n"
        printf ";Minimum UID\n"
        printf "min_uid=100\n\n"
        printf ";Minimum GID\n"
        printf "min_gid=100\n\n"
        printf "[handlers]\n"
        printf ";Handler for php-scripts\n"
        if [ "${OPT_PHP_MODE}" = "suphp" ]; then
          printf "x-httpd-php%s=\"php:/usr/local/bin/php-cgi\"\n" "${OPT_PHP_VER}"
        fi
        printf "\n;Handler for CGI-scripts\n"
        printf "x-suphp-cgi=\"execute:!self\"\n"
      } > "${SUPHP_CONF_FILE}"

      ## Generate ${APACHE_EXTRAS}/httpd-suphp.conf
      printf "Writing data to %s\n" "${SUPHP_AP2_CONF}"
      {
        printf "<IfModule mod_suphp.c>\n"
        printf "  <FilesMatch \"\.(inc|php|php3|php4|php44|php5|php52|php53|php54|php55|php56|php70|php71|php6|phtml|phps)\$\">\n"
        if [ "${OPT_PHP_MODE}" = "suphp" ]; then
          printf "    AddHandler x-httpd-php%s .inc .php .php3 .php4 .php5 .php%s .phtml\n" "${OPT_PHP_VER}" "${OPT_PHP_VER}"
        fi
        printf "  </FilesMatch>\n"
        printf "<Location />\n"
        printf "suPHP_Engine on\n"
        ## Verify: need build or ext_date_dir?
        ## Get it from /usr/local/etc/php.conf
        if [ -d "/usr/local/lib/php" ]; then
          printf "suPHP_ConfigPath /usr/local/lib/php\n"
        fi
        if [ "${OPT_PHP_MODE}" = "suphp" ]; then
          printf "suPHP_AddHandler x-httpd-php%s\n" "${OPT_PHP_VER}"
        fi
        printf "</Location>\n"
        printf "</IfModule>\n"
      } > "${SUPHP_AP2_CONF}"
      printf "Done.\n"
    elif [ -e "${SUPHP_AP2_CONF}" ]; then
      printf "" > "${SUPHP_AP2_CONF}"
    fi
  fi

  return
}

################################################################################
## Todo: Setup Brute-Force Monitor
################################################################################

bfm_setup() {

  setVal brute_force_pma_log "${WWW_DIR}/phpMyAdmin/log/auth.log" "${DA_CONF_TEMPLATE}"
  setVal brute_force_roundcube_log "${WWW_DIR}/roundcube/logs/errors" "${DA_CONF_TEMPLATE}"
  setVal brute_force_squirrelmail_log "${WWW_DIR}/squirrelmail/data/squirrelmail_access_log" "${DA_CONF_TEMPLATE}"

  if [ -e "${DA_CONF}" ]; then
    setVal brute_force_pma_log "${WWW_DIR}/phpMyAdmin/log/auth.log" "${DA_CONF}"
    setVal brute_force_roundcube_log "${WWW_DIR}/roundcube/logs/errors" "${DA_CONF}"
    setVal brute_force_squirrelmail_log "${WWW_DIR}/squirrelmail/data/squirrelmail_access_log" "${DA_CONF}"
  fi

  ## Todo:
  if [ -e "${PB_PATH}/patches/${PORT_PHPMYADMIN}/pma_auth_logging.patch" ]; then
    ## ${WGET} "${WGET_CONNECT_OPTIONS}" -O "${PB_PATH}/patches/pma_auth_logging.patch" "${PB_MIRROR}/patches/pma_auth_logging.patch"
    # cp -f "${PB_PATH}/patches/${PORT_PHPMYADMIN}/pma_auth_logging.patch"
    echo "todo"
  fi

  return
}

################################################################################
## Verify: Test: IPFW Enable
################################################################################

ipfw_enable() {

  ## From: http://help.directadmin.com/item.php?id=380
  ##  and: http://forum.directadmin.com/showthread.php?t=42202

  ## Update /etc/rc.conf:
  ${SYSRC} firewall_enable="YES"
  ${SYSRC} firewall_type="simple"
  ${SYSRC} firewall_script="/etc/ipfw.rules"
  ${SYSRC} firewall_logging="YES"

  ## Update /etc/sysctl.conf with IPFW enhancements:
  ${SYSRC} -f /etc/sysctl.conf net.inet.ip.fw.verbose=1
  ${SYSRC} -f /etc/sysctl.conf net.inet.ip.fw.verbose_limit=5
  ${SYSRC} -f /etc/sysctl.conf net.inet.ip.fw.dyn_max=65536
  ${SYSRC} -f /etc/sysctl.conf net.inet.ip.fw.dyn_keepalive=1

  ## Recycle finwait2 connections faster:
  ${SYSRC} -f /etc/sysctl.conf net.inet.tcp.fast_finwait2_recycle=1

  ## Faster finwait2 timeouts:
  ${SYSRC} -f /etc/sysctl.conf net.inet.tcp.finwait2_timeout=15000

  ## Verify:
  ${SYSRC} -f /etc/ipfw.rules pif="${ETH_DEV}"

  ${TOUCH} /root/blocked_ips.txt
  ${TOUCH} /root/exempt_ips.txt

  cp -f "${PB_PATH}/directadmin/scripts/custom/block_ip.sh" ${DA_PATH}/scripts/custom/
  cp -f "${PB_PATH}/directadmin/scripts/custom/unblock_ip.sh" ${DA_PATH}/scripts/custom/
  cp -f "${PB_PATH}/directadmin/scripts/custom/show_blocked_ips.sh" ${DA_PATH}/scripts/custom/
  cp -f "${PB_PATH}/directadmin/scripts/custom/brute_force_notice_ip.sh" ${DA_PATH}/scripts/custom/

  ${CHMOD} 700 "${DA_PATH}/scripts/custom/block_ip.sh"
  ${CHMOD} 700 "${DA_PATH}/scripts/custom/unblock_ip.sh"
  ${CHMOD} 700 "${DA_PATH}/scripts/custom/show_blocked_ips.sh"
  ${CHMOD} 700 "${DA_PATH}/scripts/custom/brute_force_notice_ip.sh"

  return
}

################################################################################
## Disable IPFW
################################################################################

ipfw_disable() {

  printf "Disabling ipfw\n"

  ${SYSRC} firewall_enable="NO"
  ${SYSRC} firewall_logging="NO"

  return
}

################################################################################
## Remove IPFW Settings
################################################################################

ipfw_remove() {

  printf "Removing ipfw\n"

  ## /etc/rc.conf
  ${SYSRC} -q -x firewall_enable
  ${SYSRC} -q -x firewall_type
  ${SYSRC} -q -x firewall_script
  ${SYSRC} -q -x firewall_logging

  ## /etc/sysctl.conf
  ${SYSRC} -q -f /etc/sysctl.conf -x net.inet.ip.fw.verbose
  ${SYSRC} -q -f /etc/sysctl.conf -x net.inet.ip.fw.verbose_limit
  ${SYSRC} -q -f /etc/sysctl.conf -x net.inet.ip.fw.dyn_max
  ${SYSRC} -q -f /etc/sysctl.conf -x net.inet.ip.fw.dyn_keepalive
  ${SYSRC} -q -f /etc/sysctl.conf -x net.inet.tcp.fast_finwait2_recycle
  ${SYSRC} -q -f /etc/sysctl.conf -x net.inet.tcp.finwait2_timeout

  ## da/scripts/custom:
  rm -f "${DA_PATH}/scripts/custom/block_ip.sh"
  rm -f "${DA_PATH}/scripts/custom/unblock_ip.sh"
  rm -f "${DA_PATH}/scripts/custom/brute_force_notice_ip.sh"
  rm -f "${DA_PATH}/scripts/custom/show_blocked_ips.sh"

  return
}

################################################################################

## Error exitval message (from /etc/rc.subr)
## Display message to stderr and log to the syslog, and exit with exitval.
err() {
  local exitval="$1"
  shift
  if [ -x /usr/bin/logger ]; then
    logger "$0: ERROR: $*"
  fi
  echo 1>&2 "$0: ERROR: $*"
  exit "$exitval"
}

################################################################################
## info message (from /etc/rc.subr)
## Display informational message to stdout and log to syslog.
################################################################################

info() {
  case "${rc_info}" in
  [Yy][Ee][Ss]|[Tt][Rr][Uu][Ee]|[Oo][Nn]|1)
    if [ -x /usr/bin/logger ]; then
      logger "$0: INFO: $*"
    fi
    echo "$0: INFO: $*"
    ;;
  esac
}

################################################################################
## Debug message (from /etc/rc.subr)
## If debugging is enabled output message to stderr.
## BEWARE that you don't call any subroutine that itself calls this function.
################################################################################

debug() {
  case ${rc_debug} in
    [Yy][Ee][Ss]|[Tt][Rr][Uu][Ee]|[Oo][Nn]|1)
      if [ -x /usr/bin/logger ]; then
        logger "$0: DEBUG: $*"
      fi
      echo 1>&2 "$0: DEBUG: $*"
    ;;
  esac
}

################################################################################
## Warning message (from /etc/rc.subr)
## Display message to stderr and log to the syslog.
################################################################################

warn() {
  if [ -x /usr/bin/logger ]; then
    logger "$0: WARNING: $*"
  fi
  echo 1>&2 "$0: WARNING: $*"
}

################################################################################
## checkyesno var (from /etc/rc.subr)
## Test $1 variable, and warn if not set to YES or NO.
## Return 0 if it's "yes" (et al), nonzero otherwise.
## NOTE: Modified to return 0 for yes or no, 1 for incorrect values
################################################################################

checkyesno_opt() {
  eval _value=\$${1}
  # debug "checkyesno: $1 is set to $_value."
  case $_value in
    [Yy][Ee][Ss]|[Tt][Rr][Uu][Ee]|[Oo][Nn]|1) return 0 ;; # "yes", "true", "on", or "1"
    [Nn][Oo]|[Ff][Aa][Ll][Ss][Ee]|[Oo][Ff][Ff]|0) return 0 ;; # "no", "false", "off", or "0"
    *) err 1 "${1} is not set properly in options.conf (value must be YES or NO)."
    return 1
    ;;
  esac
}

################################################################################
## checkyesno var (from /etc/rc.subr)
## Test $1 variable, and warn if not set to YES or NO.
## Return 0 if it's "yes" (et al), nonzero otherwise.
################################################################################

checkyesno() {
  eval _value=\$${1}
  # debug "checkyesno: $1 is set to $_value."
  case $_value in
    # "yes", "true", "on", or "1"
  [Yy][Ee][Ss]|[Tt][Rr][Uu][Ee]|[Oo][Nn]|1)
    return 0
    ;;
    # "no", "false", "off", or "0"
  [Nn][Oo]|[Ff][Aa][Ll][Ss][Ee]|[Oo][Ff][Ff]|0)
    return 1
    ;;
  *)
    warn "${1} is not set properly in options.conf (value must be YES or NO)."
    return 1
    ;;
  esac
}

################################################################################
## Check options.conf file
################################################################################

check_options_file() {

  # cp options.conf.sample options.conf

  if [ ! -f ${PB_CONF} ]; then
    printf "*** Notice: PortsBuild's options.conf file is missing. Downloading a fresh copy now.\n"
    getFile options.conf "${PB_CONF}"

    if [ ! -f "${PB_CONF}" ]; then
      printf "*** Error: options.conf is still missing. Can't continue.\n"
      exit 1
    fi
  fi

  return
}

################################################################################
## OS-specific validations
################################################################################

validate_os() {

  case "${OS_MAJ}" in
    9) pkgi "${PORT_DEPS}" ;;
    10) pkgi "${PORT_DEPS_100}" ;;
    11) pkgi "${PORT_DEPS_110}" ;;
  esac

  return
}

################################################################################
## Validate Options
## Parse Defaults and User Options, then pass computed values to PB
################################################################################

validate_options() {

  local IFS=' '
  local UNIFIED_FTP

  # if [ -n "${ETHERNET_DEV}" ]; then
  #   OPT_ETHERNET_DEV=${ETHERNET_DEV}
  # fi

  # SERVER_IP=${DA_SERVER_IP}
  # SERVER_IP_MASK=${DA_SERVER_IP_MASK}

  ## Default SSL Certificates to use
  OPT_PREFER_APACHE_SSL_CERTS="NO"
  OPT_PREFER_EXIM_SSL_CERTS="NO"
  OPT_PREFER_CUSTOM_SSL_CERTS="NO"

  ## PHP Modes (single PHP installation):
  HAVE_FPM="NO"
  HAVE_FPM_CGI="NO"
  HAVE_SUPHP_CGI="NO"
  HAVE_CLI="NO"
  HAVE_FCGID="NO"

  for php_shortrelease in $(echo "${PHP_SHORTRELEASE_SET}"); do
    eval $(echo "PHP_EXT_FPM${php_shortrelease}=/usr/local/etc/php/10-directadmin.ini")
    EVAL_PHP_EXT_SUPHP_VAR=PHP_EXT_FPM${php_shortrelease}
    eval $(echo "PHP_EXT_SUPHP${php_shortrelease}=$(eval_var "${EVAL_PHP_EXT_SUPHP_VAR}")")
  done

  ## Additional ini files
  PHP_CUSTOM_PHP_CONF_D_INI_PATH="${PB_CUSTOM}/php.conf.d"

  ## PB: Used for rewriting configurations
  for php_shortrelease in $(echo "${PHP_SHORTRELEASE_SET}"); do
    eval "$(echo "HAVE_FPM${php_shortrelease}_CGI=NO")"
    eval "$(echo "HAVE_FCGID${php_shortrelease}=NO")"
    eval "$(echo "HAVE_SUPHP${php_shortrelease}_CGI=NO")"
    eval "$(echo "HAVE_CLI${php_shortrelease}=NO")"
  done

  $(eval_var "${HAVE_CLI}")

  ## Standard 443 and 80 ports
  readonly PORT_80=$(getDA_Opt port_80 80)
  readonly PORT_443=$(getDA_Opt port_443 443)

  ## Reverse proxy ports
  readonly PORT_8080=$(getDA_Opt port_8080 8080)
  readonly PORT_8081=$(getDA_Opt port_8081 8081)

  setOpt squirrelmail no

  ## Verify and update CB/options.conf via setOpt()
  if checkyesno_opt AWSTATS; then
    readonly OPT_AWSTATS="$(uc ${AWSTATS})"
    setOpt awstats "${OPT_AWSTATS}"
  fi
  if checkyesno_opt BLOCKCRACKING; then
    readonly OPT_BLOCKCRACKING="$(uc ${BLOCKCRACKING})"
    setOpt blockcracking "${OPT_BLOCKCRACKING}"
  fi
  if checkyesno_opt CLAMAV; then
    readonly OPT_CLAMAV="$(uc ${CLAMAV})"
    setOpt clamav "${OPT_CLAMAV}"
  fi
  if checkyesno_opt CLAMAV_WITH_EXIM; then
    readonly OPT_CLAMAV_WITH_EXIM="$(uc ${CLAMAV_WITH_EXIM})"
    setOpt clamav_exim "${OPT_CLAMAV_WITH_EXIM}"
  fi
  if checkyesno_opt DOVECOT; then
    readonly OPT_DOVECOT="$(uc ${DOVECOT})"
    setOpt dovecot "${OPT_DOVECOT}"
  fi
  if checkyesno_opt EASY_SPAM_FIGHTER; then
    readonly OPT_EASY_SPAM_FIGHTER="$(uc ${EASY_SPAM_FIGHTER})"
    setOpt easy_spam_fighter "${OPT_EASY_SPAM_FIGHTER}"
  fi
  if checkyesno_opt EXIM; then
    readonly OPT_EXIM="$(uc ${EXIM})"
    setOpt exim "${OPT_EXIM}"
  fi
  if checkyesno_opt EXIM_CONF_UPDATE; then
    readonly OPT_EXIM_CONF_UPDATE="$(uc ${EXIM_CONF_UPDATE})"
    setOpt exim_conf "${OPT_EXIM_CONF_UPDATE}"
  fi
  if checkyesno_opt HTSCANNER; then
    readonly OPT_HTSCANNER="$(uc ${HTSCANNER})"
    setOpt htscanner "${OPT_HTSCANNER}"
  fi
  if checkyesno_opt INSTALL_PORTMASTER; then
    readonly OPT_INSTALL_PORTMASTER="$(uc ${INSTALL_PORTMASTER})"
  fi
  if checkyesno_opt INSTALL_CCACHE; then
    readonly OPT_INSTALL_CCACHE="$(uc ${INSTALL_CCACHE})"
  fi
  if checkyesno_opt INSTALL_SYNTH; then
    readonly OPT_INSTALL_SYNTH="$(uc ${INSTALL_SYNTH})"
  fi
  if checkyesno_opt LATEST_PKG_REPO; then
    readonly OPT_LATEST_PKG_REPO="$(uc ${LATEST_PKG_REPO})"
    pkg_repo_setup
  fi
  if checkyesno_opt LETSENCRYPT; then
    readonly OPT_LETSENCRYPT="$(uc "${LETSENCRYPT}")"
    setOpt letsencrypt "${OPT_LETSENCRYPT}"
  fi
  if checkyesno_opt MAJORDOMO; then
    readonly OPT_MAJORDOMO="$(uc ${MAJORDOMO})"
    setOpt majordomo "${OPT_MAJORDOMO}"
  fi
  if checkyesno_opt MODSECURITY; then
    readonly OPT_MODSECURITY="$(uc ${MODSECURITY})"
    setOpt modsecurity "${OPT_MODSECURITY}"
  fi
  if checkyesno_opt NAMED; then
    readonly OPT_NAMED="$(uc ${NAMED})"
  fi
  if checkyesno_opt PB_SYMLINK; then
    readonly OPT_PB_SYMLINK="$(uc ${PB_SYMLINK})"
  fi
  if checkyesno_opt PHP_INI_XMAILHEADER; then
    readonly OPT_PHP_INI_XMAILHEADER="$(uc ${PHP_INI_XMAILHEADER})"
    setOpt x_mail_header "${OPT_PHP_INI_XMAILHEADER}"
  fi
  if checkyesno_opt PHP_IONCUBE; then
    readonly OPT_PHP_IONCUBE="$(uc ${PHP_IONCUBE})"
    setOpt ioncube "${OPT_PHP_IONCUBE}"
  fi
  if checkyesno_opt PHP_OPCACHE; then
    readonly OPT_OPCACHE="$(uc ${PHP_OPCACHE})"
    setOpt opcache "${OPT_OPCACHE}"
  fi
  if checkyesno_opt PHPMYADMIN; then
    readonly OPT_PHPMYADMIN="$(uc ${PHPMYADMIN})"
    setOpt phpmyadmin "${OPT_PHPMYADMIN}"
  fi
  if checkyesno_opt PIGEONHOLE; then
    readonly OPT_PIGEONHOLE="$(uc ${PIGEONHOLE})"
    setOpt pigeonhole "${OPT_PIGEONHOLE}"
  fi
  if checkyesno_opt PROFTPD_UPLOADSCAN; then
    readonly OPT_PROFTPD_UPLOADSCAN="$(uc ${PROFTPD_UPLOADSCAN})"
    setOpt proftpd_uploadscan "${OPT_PROFTPD_UPLOADSCAN}"
  fi
  if checkyesno_opt PUREFTPD_UPLOADSCAN; then
    readonly OPT_PUREFTPD_UPLOADSCAN="$(uc ${PUREFTPD_UPLOADSCAN})"
    setOpt pureftpd_uploadscan "${OPT_PUREFTPD_UPLOADSCAN}"
  fi
  if checkyesno_opt REDIRECT_HOST_HTTPS; then
    readonly OPT_REDIRECT_HOST_HTTPS="$(uc ${REDIRECT_HOST_HTTPS})"
    setOpt redirect_host_https "${OPT_REDIRECT_HOST_HTTPS}"
  fi
  if checkyesno_opt ROUNDCUBE; then
    readonly OPT_ROUNDCUBE="$(uc ${ROUNDCUBE})"
    setOpt roundcube "${OPT_ROUNDCUBE}"
  fi
  if checkyesno_opt SPAM_INBOX_PREFIX; then
    readonly OPT_SPAM_INBOX_PREFIX="$(uc ${SPAM_INBOX_PREFIX})"
    setOpt spam_inbox_prefix "${OPT_SPAM_INBOX_PREFIX}"
  fi
  if checkyesno_opt SPAMASSASSIN; then
    readonly OPT_SPAMASSASSIN="$(uc ${SPAMASSASSIN})"
    setOpt spamassassin "${OPT_SPAMASSASSIN}"
  fi
  if checkyesno_opt SPAMASSASSIN_UTILITIES; then
    readonly OPT_SPAMASSASSIN_UTILITIES="$(uc ${SPAMASSASSIN_UTILITIES})"
    # setOpt x yes
  fi
  if checkyesno_opt SUHOSIN; then
    readonly OPT_SUHOSIN="$(uc ${SUHOSIN})"
    setOpt suhosin "${OPT_SUHOSIN}" no
  fi
  if checkyesno_opt SUHOSIN_UPLOADSCAN; then
    readonly OPT_SUHOSIN_UPLOADSCAN="$(uc ${SUHOSIN_UPLOADSCAN})"
    setOpt suhosin_php_uploadscan "${OPT_SUHOSIN_UPLOADSCAN}" no
  fi
  if checkyesno_opt USE_HOSTNAME_FOR_ALIAS; then
    readonly OPT_USE_HOSTNAME_FOR_ALIAS="$(uc ${USE_HOSTNAME_FOR_ALIAS})"
    setOpt use_hostname_for_alias "${OPT_USE_HOSTNAME_FOR_ALIAS}"
  fi
  if checkyesno_opt USERDIR_ACCESS; then
    readonly OPT_USERDIR_ACCESS="$(uc ${USERDIR_ACCESS})"
    setOpt userdir_access "${OPT_USERDIR_ACCESS}" no
  fi
  if checkyesno_opt WEBALIZER; then
    readonly OPT_WEBALIZER="$(uc ${WEBALIZER})"
    setOpt webalizer "${OPT_WEBALIZER}" no
  fi
  if checkyesno_opt WEBAPPS_INBOX_PREFIX; then
    readonly OPT_WEBAPPS_INBOX_PREFIX="$(uc ${WEBAPPS_INBOX_PREFIX})"
    setOpt webapps_inbox_prefix "${OPT_WEBAPPS_INBOX_PREFIX}"
  fi

  ## Port/Package Options
  case ${PHP_VERSION} in
    "5.6"|"7.0"|"7.1")
      OPT_PHP_VERSION="${PHP_VERSION}"
      OPT_PHP_VER=$(echo ${PHP_VERSION} | tr -d '.')
      setOpt php1_release "${PHP_VERSION}"
      setOpt php2_release "no"
      setOpt php2_mode "php-fpm"

      eval "$(echo "PHP_VER=${OPT_PHP_VER}")"

      readonly PORT_PHP="lang/php${OPT_PHP_VER}"
      readonly PORT_PHP_EXT="lang/php${OPT_PHP_VER}-extensions"
      readonly PORT_MOD_PHP="www/mod_php${OPT_PHP_VER}"

      readonly PORT_ARCHIVERS_PHP_BZ2="archivers/php${OPT_PHP_VER}-bz2"
      readonly PORT_ARCHIVERS_PHP_PHAR="archivers/php${OPT_PHP_VER}-phar"
      readonly PORT_ARCHIVERS_PHP_ZIP="archivers/php${OPT_PHP_VER}-zip"
      readonly PORT_ARCHIVERS_PHP_ZLIB="archivers/php${OPT_PHP_VER}-zlib"
      readonly PORT_CONVERTERS_PHP_ICONV="converters/php${OPT_PHP_VER}-iconv"
      readonly PORT_CONVERTERS_PHP_MBSTRING="converters/php${OPT_PHP_VER}-mbstring"
      readonly PORT_CONVERTERS_PHP_RECODE="converters/php${OPT_PHP_VER}-recode"
      readonly PORT_DATABASES_PHP_MYSQL="databases/php${OPT_PHP_VER}-mysql"
      readonly PORT_DATABASES_PHP_MYSQLI="databases/php${OPT_PHP_VER}-mysqli"
      readonly PORT_DATABASES_PHP_ODBC="databases/php${OPT_PHP_VER}-odbc"
      readonly PORT_DATABASES_PHP_PDO="databases/php${OPT_PHP_VER}-pdo"
      readonly PORT_DATABASES_PHP_PDO_MYSQL="databases/php${OPT_PHP_VER}-pdo_mysql"
      readonly PORT_DATABASES_PHP_PDO_SQLITE="databases/php${OPT_PHP_VER}-pdo_sqlite"
      readonly PORT_DATABASES_PHP_SQLITE3="databases/php${OPT_PHP_VER}-sqlite3"
      readonly PORT_DEVEL_PHP_GETTEXT="devel/php${OPT_PHP_VER}-gettext"
      readonly PORT_DEVEL_PHP_JSON="devel/php${OPT_PHP_VER}-json"
      readonly PORT_DEVEL_PHP_READLINE="devel/php${OPT_PHP_VER}-readline"
      readonly PORT_DEVEL_PHP_TOKENIZER="devel/php${OPT_PHP_VER}-tokenizer"
      readonly PORT_FTP_PHP_CURL="ftp/php${OPT_PHP_VER}-curl"
      readonly PORT_FTP_PHP_FTP="ftp/php${OPT_PHP_VER}-ftp"
      readonly PORT_GRAPHICS_PHP_EXIF="graphics/php${OPT_PHP_VER}-exif"
      readonly PORT_GRAPHICS_PHP_GD="graphics/php${OPT_PHP_VER}-gd"
      readonly PORT_MAIL_PHP_IMAP="mail/php${OPT_PHP_VER}-imap"
      readonly PORT_MATH_PHP_BCMATH="math/php${OPT_PHP_VER}-bcmath"
      readonly PORT_MISC_PHP_CALENDAR="misc/php${OPT_PHP_VER}-calendar"
      readonly PORT_NET_MGMT_PHP_SNMP="net-mgmt/php${OPT_PHP_VER}-snmp"
      readonly PORT_NET_PHP_SOAP="net/php${OPT_PHP_VER}-soap"
      readonly PORT_NET_PHP_SOCKETS="net/php${OPT_PHP_VER}-sockets"
      readonly PORT_NET_PHP_XMLRPC="net/php${OPT_PHP_VER}-xmlrpc"
      readonly PORT_SECURITY_PHP_FILTER="security/php${OPT_PHP_VER}-filter"
      readonly PORT_SECURITY_PHP_HASH="security/php${OPT_PHP_VER}-hash"
      readonly PORT_SECURITY_PHP_MCRYPT="security/php${OPT_PHP_VER}-mcrypt"
      readonly PORT_SECURITY_PHP_OPENSSL="security/php${OPT_PHP_VER}-openssl"
      readonly PORT_SYSUTILS_PHP_FILEINFO="sysutils/php${OPT_PHP_VER}-fileinfo"
      readonly PORT_SYSUTILS_PHP_POSIX="sysutils/php${OPT_PHP_VER}-posix"
      readonly PORT_TEXTPROC_PHP_CTYPE="textproc/php${OPT_PHP_VER}-ctype"
      readonly PORT_TEXTPROC_PHP_DOM="textproc/php${OPT_PHP_VER}-dom"
      readonly PORT_TEXTPROC_PHP_PSPELL="textproc/php${OPT_PHP_VER}-pspell"
      readonly PORT_TEXTPROC_PHP_SIMPLEXML="textproc/php${OPT_PHP_VER}-simplexml"
      readonly PORT_TEXTPROC_PHP_WDDX="textproc/php${OPT_PHP_VER}-wddx"
      readonly PORT_TEXTPROC_PHP_XML="textproc/php${OPT_PHP_VER}-xml"
      readonly PORT_TEXTPROC_PHP_XMLREADER="textproc/php${OPT_PHP_VER}-xmlreader"
      readonly PORT_TEXTPROC_PHP_XMLWRITER="textproc/php${OPT_PHP_VER}-xmlwriter"
      readonly PORT_TEXTPROC_PHP_XSL="textproc/php${OPT_PHP_VER}-xsl"
      readonly PORT_WWW_PHP_OPCACHE="www/php${OPT_PHP_VER}-opcache"
      readonly PORT_WWW_PHP_SESSION="www/php${OPT_PHP_VER}-session"
      readonly PORT_WWW_PHP_TIDY="www/php${OPT_PHP_VER}-tidy"

      ## PHP Extensions
      readonly PHP_EXT_LIST="${PORT_ARCHIVERS_PHP_BZ2} ${PORT_ARCHIVERS_PHP_PHAR} \
      ${PORT_ARCHIVERS_PHP_ZIP} ${PORT_ARCHIVERS_PHP_ZLIB} ${PORT_CONVERTERS_PHP_ICONV} \
      ${PORT_CONVERTERS_PHP_MBSTRING} ${PORT_CONVERTERS_PHP_RECODE} ${PORT_DATABASES_PHP_MYSQL} \
      ${PORT_DATABASES_PHP_MYSQLI} ${PORT_DATABASES_PHP_ODBC} ${PORT_DATABASES_PHP_PDO} \
      ${PORT_DATABASES_PHP_PDO_MYSQL} ${PORT_DATABASES_PHP_PDO_SQLITE} \
      ${PORT_DATABASES_PHP_SQLITE3} ${PORT_DEVEL_PHP_GETTEXT} ${PORT_DEVEL_PHP_JSON} \
      ${PORT_DEVEL_PHP_READLINE} ${PORT_DEVEL_PHP_TOKENIZER} ${PORT_FTP_PHP_CURL} \
      ${PORT_FTP_PHP_FTP} ${PORT_GRAPHICS_PHP_EXIF} ${PORT_GRAPHICS_PHP_GD} ${PORT_MAIL_PHP_IMAP} \
      ${PORT_MATH_PHP_BCMATH} ${PORT_MISC_PHP_CALENDAR} ${PORT_NET_MGMT_PHP_SNMP} \
      ${PORT_NET_PHP_SOAP} ${PORT_NET_PHP_SOCKETS} ${PORT_NET_PHP_XMLRPC} \
      ${PORT_SECURITY_PHP_FILTER} ${PORT_SECURITY_PHP_HASH} ${PORT_SECURITY_PHP_MCRYPT} \
      ${PORT_SECURITY_PHP_OPENSSL} ${PORT_SYSUTILS_PHP_FILEINFO} ${PORT_SYSUTILS_PHP_POSIX} \
      ${PORT_TEXTPROC_PHP_CTYPE} ${PORT_TEXTPROC_PHP_DOM} ${PORT_TEXTPROC_PHP_PSPELL} \
      ${PORT_TEXTPROC_PHP_SIMPLEXML} ${PORT_TEXTPROC_PHP_WDDX} ${PORT_TEXTPROC_PHP_XML} \
      ${PORT_TEXTPROC_PHP_XMLREADER} ${PORT_TEXTPROC_PHP_XMLWRITER} ${PORT_TEXTPROC_PHP_XSL} \
      ${PORT_WWW_PHP_OPCACHE} ${PORT_WWW_PHP_SESSION} ${PORT_WWW_PHP_TIDY}"

      readonly PHP_PREFIX="/usr/local/php${OPT_PHP_VER}"

      case $(lc ${PHP_MODE}) in
        "fpm"|"phpfpm"|"php-fpm"|"php_fpm")
          readonly OPT_PHP_MODE="php-fpm"
          readonly OPT_PHP_RELEASE="YES"
          readonly HAVE_FPM_CGI="YES"
          readonly HAVE_FPM="YES"
          # eval $(echo "HAVE_FPM${OPT_PHP_VER}_CGI=YES")
          # eval $(echo "HAVE_FPM${OPT_PHP_VER}=YES")
          setOpt php1_mode php-fpm
          ;;
        "suphp"|"su_php"|"su-php"|"su")
          readonly OPT_PHP_MODE="suphp"
          readonly OPT_PHP_RELEASE="YES"
          readonly HAVE_SUPHP_CGI="YES"
          eval "$(echo "HAVE_SUPHP${OPT_PHP_VER}_CGI=YES")"
          setOpt php1_mode suphp
          ;;
        "modphp"|"mod_php"|"mod"|"mod-php")
          readonly OPT_PHP_MODE="mod_php"
          readonly OPT_PHP_RELEASE="YES"
          readonly HAVE_CLI="YES"
          eval "$(echo "HAVE_CLI${OPT_PHP_VER}=YES")"
          setOpt php1_mode mod_php
          ;;
        "fastcgi"|"fcgi")
          readonly OPT_PHP_MODE="fastcgi"
          readonly OPT_PHP_RELEASE="YES"
          readonly HAVE_FCGID="YES"
          eval "$(echo "HAVE_FCGID${OPT_PHP_VER}=YES")"
          setOpt php1_mode fastcgi
          ;;
        *) printf "*** Error: Invalid PHP_MODE value set in options.conf\n"; exit;;
      esac
      case $(lc ${PHP_INI_TYPE}) in
        "production"|"development")
          readonly OPT_PHP_INI_TYPE="${PHP_INI_TYPE}"
          setOpt php_ini "${PHP_INI_TYPE}"
          ;;
        "custom")
          readonly OPT_PHP_INI_TYPE="custom"
          setOpt php_ini "no"
          ;;
        "no"|"none")
          readonly OPT_PHP_INI_TYPE="none"
          setOpt php_ini "no"
          ;;
        *) printf "*** Error: Invalid PHP ini Type set in options.conf\n"; exit ;;
      esac
      ;;
    "no"|"NO"|"none")
      readonly OPT_PHP_MODE="NO"
      readonly OPT_PHP_RELEASE="NO"
      readonly OPT_PHP_VER="NO"
      readonly OPT_PHP_VERSION="NO"
      readonly HAVE_FPM="NO"
      readonly HAVE_FPM_CGI="NO"
      readonly HAVE_SUPHP_CGI="NO"
      readonly HAVE_CLI="NO"
      readonly HAVE_FCGID="NO"
      ;;
    *) printf "*** Error: Invalid PHP_VERSION value set in options.conf\n"; exit ;;
  esac

  HAS_CLI=NO
  if [ "${OPT_PHP_MODE}" = "mod_php" ]; then
    HAS_CLI=YES
  fi

  HAS_CGI=NO
  if [ "${OPT_PHP_MODE}" = "php-fpm" ]; then
    HAS_CGI=YES
  fi

  if [ "${OPT_PHP_MODE}" = "suphp" ]; then
    HAS_CGI=YES
  fi

  if [ "${OPT_PHP_MODE}" = "fastcgi" ]; then
    HAS_CGI=YES
  fi

  #### From CB2:
  for php_shortrelease in $(echo ${PHP_SHORTRELEASE_SET}); do
    # Variables for php-fpm
    eval `echo "PHP${php_shortrelease}_CONFIGURE_FPM=${PB_CONFIG}/fpm/configure.php${php_shortrelease}"`
    if [ -e custom/fpm/configure.php${php_shortrelease} ]; then
      eval `echo "PHP${php_shortrelease}_CONFIGURE_FPM=${PB_CUSTOM}/fpm/configure.php${php_shortrelease}"`
    fi
    eval `echo "PHP${php_shortrelease}_FPM_CONF=${PB_PATH}/configure/fpm/conf/php-fpm.conf.${php_shortrelease}"`
    if [ -e ${PB_CUSTOM}/fpm/conf/php-fpm.conf.${php_shortrelease} ]; then
      eval `echo "PHP${php_shortrelease}_FPM_CONF=${PB_CUSTOM}/fpm/conf/php-fpm.conf.${php_shortrelease}"`
    fi
    eval `echo "PHP_INI_FPM${php_shortrelease}=${PHP_INI}"`
    eval `echo "PHP_SBIN_FPM${php_shortrelease}=${PHP_FPM_BIN}"`

    # Variables for PHP as suPHP
    EVAL_PHP_INI_SUPHP_VAR=PHP_SBIN_FPM${php_shortrelease}
    eval `echo "PHP_INI_SUPHP${php_shortrelease}=$(eval_var ${EVAL_PHP_INI_SUPHP_VAR})"`
    eval `echo "PHP_BIN_SUPHP${php_shortrelease}=/usr/local/bin/php-cgi"`
    eval `echo "PHP_BIN_PHP${php_shortrelease}=/usr/local/bin/php"`
    eval `echo "PHP${php_shortrelease}_CONFIGURE_SUPHP=${PB_CONFIG}/suphp/configure.php${php_shortrelease}"`
    if [ -e ${PB_CUSTOM}/suphp/configure.php${php_shortrelease} ]; then
      eval `echo "PHP${php_shortrelease}_CONFIGURE_SUPHP=${PB_CUSTOM}/suphp/configure.php${php_shortrelease}"`
    fi

    # Variables for php-fastcgi
    eval `echo "PHP${php_shortrelease}_CONFIGURE_FCGI=${PB_CONFIG}/fastcgi/configure.php${php_shortrelease}"`
    if [ -e ${PB_CUSTOM}/fastcgi/configure.php${php_shortrelease} ]; then
      eval `echo "PHP${php_shortrelease}_CONFIGURE_FCGI=${PB_CUSTOM}/fastcgi/configure.php${php_shortrelease}"`
    fi

    eval `echo "PHP_EXT_FPM${php_shortrelease}=/usr/local/etc/php/10-directadmin.ini"`
    EVAL_PHP_EXT_SUPHP_VAR=PHP_EXT_FPM${php_shortrelease}
    eval `echo "PHP_EXT_SUPHP${php_shortrelease}=$(eval_var ${EVAL_PHP_EXT_SUPHP_VAR})"`
  done



  PHP_CUSTOM_PHP_CONF_D_INI_PATH="${PB_PATH}/custom/php.conf.d"

  ## PHP extensions file rewritten by DirectAdmin
  PHP_EXT=/usr/local/etc/php/10-directadmin.ini
  ## PHP_INI=/usr/local/etc/php.ini
  PHP_BIN=/usr/local/bin/php

  PHP_INI_FILE=${PHP_INI}
  PHP_INI_EXT_FILE=${PHP_EXT}
  if [ "${OPT_PHP_MODE}" != "mod_php" ]; then
    PHP_RELEASE_INI_EVAL="PHP_INI_FPM${OPT_PHP_VER}"
    PHP_INI_FILE="$(eval_var ${PHP_RELEASE_INI_EVAL})"
    PHP_RELEASE_INI_EXT_EVAL="PHP_EXT_FPM${OPT_PHP_VER}"
    PHP_INI_EXT_FILE="$(eval_var ${PHP_RELEASE_INI_EXT_EVAL})"
  fi

  PHP_INI_EXT_FILE_OLD="$(echo ${PHP_INI_EXT_FILE} | ${PERL} -p0 -e 's|10-directadmin.ini|directadmin.ini|')"
  if [ -e "${PHP_INI_EXT_FILE_OLD}" ] && [ ! -e "${PHP_INI_EXT_FILE}" ]; then
    mv -f "${PHP_INI_EXT_FILE_OLD}" "${PHP_INI_EXT_FILE}"
  fi
  #### End: From CB2


  ## additional checks for PHP, then:
  ## OPT_PHP_ENABLE="YES"

  case $(lc ${WEBSERVER}) in
    "apache"|"apache24")
      readonly OPT_WEBSERVER="apache"
      readonly OPT_APACHE_VER="2.4"
      setOpt webserver apache
      setOpt apache_ver 2.4
      case $(lc ${APACHE_MPM}) in
        "event"|"prefork"|"worker")
          readonly OPT_APACHE_MPM="${APACHE_MPM}"
          setOpt apache_mpm "${APACHE_MPM}"
          ;;
        "auto")
          readonly OPT_APACHE_MPM="event"
          setOpt apache_mpm auto
          ;;
        *) printf "*** Error: Invalid APACHE_MPM value set in options.conf\n"; exit ;;
      esac
      ;;
    "nginx")
      readonly OPT_WEBSERVER="nginx"
      setOpt webserver nginx
      ;;
    "nginx_apache")
      readonly OPT_WEBSERVER="nginx_apache"
      setOpt webserver nginx_apache
      ;;
    "no"|"none")
      readonly OPT_WEBSERVER="NO"
      setOpt webserver apache
      ;;
    *) printf "*** Error: Invalid WEBSERVER value set in options.conf\n"; exit ;;
  esac

  case $(lc ${SQL_DB}) in
    "mariadb55"|"mariadb100"|"mariadb101"|"mariadb")
      readonly OPT_SQL_DB="${SQL_DB}"
      setOpt mysql_inst mariadb
      ;;
    "mariadb")
      readonly OPT_SQL_DB="mariadb101"
      setOpt mysql_inst mariadb
      ;;
    "mysql55"|"mysql56"|"mysql57")
      readonly OPT_SQL_DB="${SQL_DB}"
      setOpt mysql_inst mysql
      ;;
    "mysql")
      readonly OPT_SQL_DB="mysql56"
      setOpt mysql_inst mysql
      ;;
    "no"|"none")
      readonly OPT_SQL_DB="NO"
      setOpt mysql_inst no
      ;;
    *) printf "*** Error: Invalid SQL_DB value set in options.conf\n"; exit ;;
  esac

  case $(lc ${FTPD}) in
    "pureftpd"|"pure-ftpd"|"pureftp") readonly OPT_FTPD="pureftpd";  setOpt ftpd pureftpd ;;
    "proftpd"|"pro-ftpd"|"proftp")    readonly OPT_FTPD="proftpd";   setOpt ftpd proftpd ;;
    "no"|"none")                      readonly OPT_FTPD="NO";        setOpt ftpd no ;;
    *) printf "*** Error: Invalid FTPD value set in options.conf\n"; exit ;;
  esac

  ## Verify:
  if [ "${OPT_FTPD}" = "pureftpd" ]; then
    if [ -s "${DA_CONF}" ]; then
      UNIFIED_FTP="$(${DA_BIN} c | grep -m1 unified_ftp_password_file | cut -d= -f2)"
      if [ "${UNIFIED_FTP}" != "1" ]; then
        echo "  unified_ftp_password_file is not set to 1. You must convert before you can use PureFTPD."
        echo "  Please read this guide: http://www.directadmin.com/features.php?id=1134"
        echo ""
        echo "  Simulation:"
        echo "     cd /usr/local/directadmin"
        echo "     echo 'action=convert&value=unifiedftp&simulate=yes' >> data/task.queue"
        echo "     ./dataskq d1"
        echo ""
        echo "  Conversion:"
        echo "     cd /usr/local/directadmin"
        echo "     echo 'unified_ftp_password_file=1' >> conf/directadmin.conf"
        echo "     echo 'action=convert&value=unifiedftp' >> data/task.queue"
        echo "     ./dataskq d1"
        exit 1
      fi
    # else
    #   setVal unified_ftp_password_file 1 ${DA_CONF_TEMPLATE}
    #   setVal unified_ftp_password_file 1 ${DA_CONF}
    fi
  fi

  if [ "${OPT_EASY_SPAM_FIGHTER}" = "YES" ] && [ "${OPT_SPAMASSASSIN}" = "NO" ]; then
    printf "*** Error: Easy Spam Fighter (ESF) requires SpamAssassin to be enabled.\n"
    printf "Set SPAMASSASSIN=YES in options.conf\n"
    exit 1
  fi

  ## Following lines are from DA's setup.sh:
  if [ -s /root/.lan ]; then
    DA_LAN=$(cat /root/.lan)
  fi

  if [ -s /root/.insecure_download ]; then
    DA_INSECURE=$(cat /root/.insecure_download)
  fi

  return
}

################################################################################
## Todo: Get Versions (from CB2: doVersions())
################################################################################

get_versions() {

  local VERSIONS ## 0 = auto-update, 1 == show info only
  local DIRECTADMIN_VER DIRECTADMINV APACHE_VER APACHE2_VER DOVECOT_CONF_VER DOVECOT_CONFV DOVECTCONFFILE
  local EXIT_CODE

  ## DirectAdmin
  if [ -e "${DA_BIN}" ] && [ "${DIRECTADMIN_VER}" != "0" ]; then
    DIRECTADMINV="$(${DA_BIN} v | grep -m1 '^Version:' | grep -oE '[^ ]+$' | cut -d. -f2,3,4)"
    if [ "${VERSIONS}" = "1" ]; then
      printf "Latest version of DirectAdmin: %s\n" "${DIRECTADMIN_VER}"
      printf "Installed version of DirectAdmin: %s\n\n" "${DIRECTADMINV}"
    fi
    if [ "${DIRECTADMIN_VER}" != "${DIRECTADMINV}" ]; then
      if [ "${VERSIONS}" = "0" ] || [ "${VERSIONS}" = "3" ]; then
        directadmin_update
      elif [ "${VERSIONS}" = "1" ]; then
        printf "DirectAdmin %s to %s update is available.\n" "${DIRECTADMINV}" "${DIRECTADMIN_VER}"
      fi
      EXIT_CODE=$((EXIT_CODE+1))
    fi
  else
    printf "DirectAdmin is not installed.\n"
  fi

  ## Apache
  if [ "${APACHE2_VER}" != "0" ]; then
    if [ "${OPT_WEBSERVER}" = "apache" ] || [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
      if [ -e "${APACHE_HTTPD}" ]; then
        APACHEV="$(${APACHE_HTTPD} -v | grep -m1 'Server version:' | awk '{ print $3 }' | cut -d/ -f2)"
        if [ "${VERSIONS}" = "1" ]; then
          printf "Latest version of Apache: %s\n" "${APACHE2_VER}"
          printf "Installed version of Apache: %s\n\n" "${APACHEV}"
        fi
        if [ "${APACHE2_VER}" != "${APACHEV}" ]; then
          if [ "${VERSIONS}" = "0" ]; then
            printf "Updating Apache.\n"
            apache_install
          elif [ "${VERSIONS}" = "1" ]; then
            printf "Apache %s to %s update is available.\n" "${APACHEV}" "${APACHE2_VER}"
          fi
          EXIT_CODE=$((EXIT_CODE+1))
        fi
      fi
    fi
  fi

  ## dovecot.conf
  if [ "${OPT_DOVECOT_CONF}" = "YES" ]; then
    COUNT=0
    if [ -e "${DOVECOT_CONF}" ]; then
      COUNT=$(head -n1 "${DOVECOT_CONF}" | grep -c '^#')
    fi
    if [ "${COUNT}" -gt 0 ]; then
      DOVECOT_CONFV="$(head -n1 "${DOVECOT_CONF}" | cut -d'#' -f2)"
    else
      DOVECOT_CONFV=0
    fi

    if [ "${DOVECOT_CONFV}" = "" ]; then
      DOVECOT_CONFV=0
    fi

    COUNT=0
    if [ -e ${DOVECTCONFFILE} ]; then
      COUNT=$(head -n1 ${DOVECTCONFFILE} | grep -c '^#')
    fi
    if [ "${COUNT}" -gt 0 ]; then
      DOVECOT_CONF_VER="$(head -n1 ${DOVECTCONFFILE} | cut -d'#' -f2)"
    else
      DOVECOT_CONF_VER=0
    fi

    if [ "${DOVECOT_CONF_VER}" != "0" ]; then
      if [ "${VERSIONS}" = "1" ]; then
        printf "Latest version of dovecot.conf: %s\n" "${DOVECOT_CONF_VER}"
        printf "Installed version of dovecot.conf: %s\n" "${DOVECOT_CONFV}"
      fi
      if [ "${DOVECOT_CONF_VER}" != "${DOVECOT_CONFV}" ]; then
        if [ "${VERSIONS}" = "0" ]; then
          printf "Updating dovecot.conf\n"
          dovecot_config
        elif [ "${VERSIONS}" = "1" ]; then
          printf "dovecot.conf %s to %s update is available.\n\n" "${DOVECOT_CONFV}" "${DOVECOT_CONF_VER}"
        fi
        EXIT_CODE=$((EXIT_CODE+1))
      fi
    fi
  fi

  ## Exim.conf
  if [ "${OPT_EXIM_CONF_UPDATE}" = "YES" ] && [ "${EXIM_CONF_VER}" != "0" ]; then
    EXIMCONFV=$(exim_conf_version)
    if [ "${VERSIONS}" = "1" ]; then
      printf "Latest version of exim.conf: %s\n" "${EXIM_CONF_VER}"
      printf "Installed version of exim.conf: %s\n" "${EXIMCONFV}"
    fi
    if [ "${EXIM_CONF_VER}" != "${EXIMCONFV}" ]; then
      if [ "${VERSIONS}" = "0" ]; then
        printf "Updating exim.conf\n"
        exim_conf
      elif [ "${VERSIONS}" = "1" ]; then
        printf "exim.conf %s to %s update is available.\n\n" "${EXIMCONFV}" "${EXIM_CONF_VER}"
      fi
      EXIT_CODE=$((EXIT_CODE+1))
    fi
  fi

  ## BlockCracking
  if [ "${OPT_BLOCKCRACKING}" = "YES" ] && [ "${BLOCKCRACKING_VER}" != "0" ]; then
    COUNT=0
    if [ -e "${EXIM_BC_PATH}/README.txt" ]; then
      COUNT=$(head -n1 "${EXIM_BC_PATH}/README.txt" | grep -c '^#')
    fi
    if [ "${COUNT}" -gt 0 ]; then
      BLOCKCRACKINGV="$(head -n1 "${EXIM_BC_PATH}/README.txt" | cut -d'#' -f2)"
    else
      BLOCKCRACKINGV=0
    fi
    if [ "${VERSIONS}" = "1" ]; then
      printf "Latest version of BlockCracking: %s\n" "${BLOCKCRACKING_VER}"
      printf "Installed version of BlockCracking: %s\n" "${BLOCKCRACKINGV}"
    fi
    if [ "${BLOCKCRACKING_VER}" != "${BLOCKCRACKINGV}" ]; then
      if [ "${VERSIONS}" = "0" ]; then
        printf "Updating BlockCracking\n"
        blockcracking_install
      elif [ "${VERSIONS}" = "1" ]; then
        printf "BlockCracking %s to %s update is available.\n\n" "${BLOCKCRACKINGV}" "${BLOCKCRACKING_VER}"
      fi
      EXIT_CODE=$((EXIT_CODE+1))
    fi
  fi

  ## Easy Spam Fighter
  if [ "${OPT_EASY_SPAM_FIGHTER}" = "YES" ] && [ "${EASY_SPAM_FIGHTER_VER}" != "0" ]; then
    COUNT=0
    if [ -e "${EXIM_ESF_PATH}/README.txt" ]; then
      COUNT=$(head -n1 "${EXIM_ESF_PATH}/README.txt" | grep -c '^#')
    fi
    if [ "${COUNT}" -gt 0 ]; then
      EASY_SPAM_FIGHTERV="$(head -n1 "${EXIM_PATH}/esf/README.txt" | cut -d'#' -f2)"
    else
      EASY_SPAM_FIGHTERV=0
    fi
    if [ "${VERSIONS}" = "1" ]; then
      printf "Latest version of Easy Spam Fighter: %s\n" "${EASY_SPAM_FIGHTER_VER}"
      printf "Installed version of Easy Spam Fighter: %s\n" "${EASY_SPAM_FIGHTERV}"
    fi
    if [ "${EASY_SPAM_FIGHTER_VER}" != "${EASY_SPAM_FIGHTERV}" ]; then
      if [ "${VERSIONS}" = "0" ]; then
        printf "Updating Easy Spam Fighter\n"
        easyspamfighter_install
      elif [ "${VERSIONS}" = "1" ]; then
        printf "Easy Spam Fighter %s to %s update is available.\n\n" "${EASY_SPAM_FIGHTERV}" "${EASY_SPAM_FIGHTER_VER}"
      fi
      EXIT_CODE=$((EXIT_CODE+1))
    fi
  fi

}

################################################################################
## Todo: Update directadmin.conf (and the template) with corrected paths
################################################################################

update_da_conf() {

  printf "*** Notice: Updating directadmin.conf (and template) with recommended values.\n"

  # if [ -e "${DA_CONF}" ]; then
  # fi

  setVal openssl ${OPENSSL} ${DA_CONF_TEMPLATE}
  setVal openssl ${OPENSSL} ${DA_CONF}

  setVal php_version_selector 0 ${DA_CONF_TEMPLATE}
  setVal php_version_selector 0 ${DA_CONF}

  # setVal pureftp 0 "${DA_CONF_TEMPLATE}"
  # setVal pureftp 0 "${DA_CONF}"

  setVal ftpconfig "${PROFTPD_CONF}" "${DA_CONF_TEMPLATE}"
  setVal ftpconfig "${PROFTPD_CONF}" "${DA_CONF}"

  setVal ftppasswd "${PROFTPD_PASSWD}" "${DA_CONF_TEMPLATE}"
  setVal ftppasswd "${PROFTPD_PASSWD}" "${DA_CONF}"

  setVal ftppasswd_db /usr/local/etc/pureftpd.pdb "${DA_CONF_TEMPLATE}"
  setVal ftppasswd_db /usr/local/etc/pureftpd.pdb "${DA_CONF}"

  setVal ftpvhosts /usr/local/etc/proftpd.vhosts.conf "${DA_CONF_TEMPLATE}"
  setVal ftpvhosts /usr/local/etc/proftpd.vhosts.conf "${DA_CONF}"

  setVal mq_exim_bin "${EXIM_BIN}" "${DA_CONF_TEMPLATE}"
  setVal mq_exim_bin "${EXIM_BIN}" "${DA_CONF}"

  setVal brute_force_pma_log "${WWW_DIR}/phpMyAdmin/log/auth.log" "${DA_CONF_TEMPLATE}"
  setVal brute_force_pma_log "${WWW_DIR}/phpMyAdmin/log/auth.log" "${DA_CONF}"

  setVal brute_force_roundcube_log "${WWW_DIR}/roundcube/logs/errors" "${DA_CONF_TEMPLATE}"
  setVal brute_force_roundcube_log "${WWW_DIR}/roundcube/logs/errors" "${DA_CONF}"

  setVal brute_force_squirrelmail_log "${WWW_DIR}/squirrelmail/data/squirrelmail_access_log" "${DA_CONF_TEMPLATE}"
  setVal brute_force_squirrelmail_log "${WWW_DIR}/squirrelmail/data/squirrelmail_access_log" "${DA_CONF}"

  if [ "${OS_MAJ}" -eq 10 ] || [ "${OS_MAJ}" -eq 11 ]; then
    ## FreeBSD 10/11: /usr/local/etc/namedb/
    NAMED_BIN=/usr/local/sbin/named
    NAMEDB_PATH=/usr/local/etc/namedb
    RNDC_BIN=/usr/local/sbin/rndc-confgen
    NAMED_CONF="${NAMEDB_PATH}/named.conf"
    RNDC_KEY="${NAMEDB_PATH}/rndc.key"
  elif [ "${OS_MAJ}" -eq 9 ]; then
    ## FreeBSD 9.3: /etc/namedb/
    NAMED_BIN=/usr/sbin/named
    NAMEDB_PATH=/etc/namedb
    RNDC_BIN=/sbin/rndc-confgen
    NAMED_CONF="${NAMEDB_PATH}/named.conf"
    RNDC_KEY="${NAMEDB_PATH}/rndc.key"
  else
    printf "*** Warning: update_da_conf(): Unable to detect operating system version. (script error)\n"
  fi

  setVal namedconfig "${NAMED_CONF}" "${DA_CONF_TEMPLATE}"
  setVal nameddir "${NAMEDB_PATH}" "${DA_CONF_TEMPLATE}"

  setVal namedconfig "${NAMED_CONF}" "${DA_CONF}"
  setVal nameddir "${NAMEDB_PATH}" "${DA_CONF}"

  setVal frontpage_on 0 "${DA_CONF_TEMPLATE}"
  setVal frontpage_on 0 "${DA_CONF}"

  if [ "${OPT_WEBSERVER}" = "apache" ]; then
    setVal apache_pid /var/run/httpd.pid "${DA_CONF_TEMPLATE}"
    setVal apache_pid /var/run/httpd.pid "${DA_CONF}"
    setVal apache_ver 2.0 "${DA_CONF_TEMPLATE}"
    setVal apache_ver 2.0 "${DA_CONF}"
    setVal apacheca "${APACHE_SSL_CA}" "${DA_CONF_TEMPLATE}"
    setVal apacheca "${APACHE_SSL_CA}" "${DA_CONF}"
    setVal apachecert "${APACHE_SSL_CRT}" "${DA_CONF_TEMPLATE}"
    setVal apachecert "${APACHE_SSL_CRT}" "${DA_CONF}"
    setVal apacheconf "${APACHE_EXTRAS}/directadmin-vhosts.conf" "${DA_CONF_TEMPLATE}"
    setVal apacheconf "${APACHE_EXTRAS}/directadmin-vhosts.conf" "${DA_CONF}"
    setVal apacheips "${APACHE_PATH}/ips.conf" "${DA_CONF_TEMPLATE}"
    setVal apacheips "${APACHE_PATH}/ips.conf" "${DA_CONF}"
    setVal apachekey "${APACHE_SSL_KEY}" "${DA_CONF_TEMPLATE}"
    setVal apachekey "${APACHE_SSL_KEY}" "${DA_CONF}"
    setVal apachemimetypes "${APACHE_MIME_TYPES}" "${DA_CONF_TEMPLATE}"
    setVal apachemimetypes "${APACHE_MIME_TYPES}" "${DA_CONF}"
    setVal cloud_cache 0 "${DA_CONF_TEMPLATE}"
    setVal cloud_cache 0 "${DA_CONF}"
    setVal htpasswd "${APACHE_HTPASSWD}" "${DA_CONF_TEMPLATE}"
    setVal htpasswd "${APACHE_HTPASSWD}" "${DA_CONF}"
    setVal nginx 0 "${DA_CONF_TEMPLATE}"
    setVal nginx 0 "${DA_CONF}"
  fi

  if [ "${OPT_WEBSERVER}" = "nginx" ]; then
    setVal nginx_ca "${NGINX_SSL_CA}" "${DA_CONF_TEMPLATE}"
    setVal nginx_ca "${NGINX_SSL_CA}" "${DA_CONF}"
    setVal nginx_cert "${NGINX_SSL_CRT}" "${DA_CONF_TEMPLATE}"
    setVal nginx_cert "${NGINX_SSL_CRT}" "${DA_CONF}"
    setVal nginx_key "${NGINX_SSL_KEY}" "${DA_CONF_TEMPLATE}"
    setVal nginx_key "${NGINX_SSL_KEY}" "${DA_CONF}"
    setVal nginx_pid /var/run/nginx.pid "${DA_CONF_TEMPLATE}"
    setVal nginx_pid /var/run/nginx.pid "${DA_CONF}"
    setVal nginxconf "${NGINX_PATH}/directadmin-vhosts.conf" "${DA_CONF_TEMPLATE}"
    setVal nginxconf "${NGINX_PATH}/directadmin-vhosts.conf" "${DA_CONF}"
    setVal nginxips "${NGINX_PATH}/directadmin-ips.conf" "${DA_CONF_TEMPLATE}"
    setVal nginxips "${NGINX_PATH}/directadmin-ips.conf" "${DA_CONF}"
    setVal nginxlogdir "${LOGS}/nginx/domains" "${DA_CONF_TEMPLATE}"
    setVal nginxlogdir "${LOGS}/nginx/domains" "${DA_CONF}"
  fi

  if [ "${OPT_WEBSERVER}" = "nginx_apache" ]; then
    setVal nginx_proxy 1 "${DA_CONF_TEMPLATE}"
    setVal nginx_proxy 1 "${DA_CONF}"
  elif [ "${OPT_WEBSERVER}" = "apache" ]; then
    setVal nginx_proxy 0 "${DA_CONF_TEMPLATE}"
    setVal nginx_proxy 0 "${DA_CONF}"
  fi

  setVal litespeed 0 "${DA_CONF_TEMPLATE}"
  setVal litespeed 0 "${DA_CONF}"

  printf "*** Notice: Completed directadmin.conf updates.\n"

  return
}

################################################################################
## Install Application
## $2 = name of service
## e.g. install_app exim
################################################################################

install_app() {

  local APP="$1"

  if [ "${APP}" = "install" ]; then
    APP="$2" # shift?
  fi

  case ${APP} in
    "apache"|"apache24") apache_install ;;
    "awstats") awstats_install ;;
    "bfm") bfm_setup ;;
    "bind"|"named"|"dns") bind_setup ;;
    "blockcracking"|"bc") blockcracking_install ;;
    "directadmin"|"da") directadmin_install ;;
    "dkim") pkgi ${PORT_LIBDKIM} ;;
    "dovecot") dovecot_install ;;
    "easy_spam_fighter"|"easyspamfighter"|"esf") easyspamfighter_install ;;
    "exim") exim_install ;;
    "ioncube"|"ic") pkgi "${PORT_IONCUBE}" ;;
    "ipfw") ipfw_enable ;;
    "libspf2"|"libspf"|"spf") pkgi ${PORT_LIBSPF2} ;;
    "mariadb"|"mysql") sql_install ;;
    "modsecurity"|"modsec"|"mod_security") modsecurity_install ;;
    "nginx") nginx_install ;;
    "php"|"ftm"|"php56"|"php70"|"php71") php_install ;;
    "phpmyadmin"|"pma") phpmyadmin_install ;;
    "proftpd"|"proftp") proftpd_install ;;
    "pureftpd"|"pureftp") pureftpd_install ;;
    "roundcube"|"rc") roundcube_install ;;
    "spamassassin"|"sa") spamassassin_install ;;
    "suhosin") suhosin_install ;;
    "webalizer") webalizer_install ;;
    *) show_install_menu ;;
  esac

  return
}

################################################################################
##
## Uninstall Application
## $1 = name of service
## e.g. uninstall_app exim
##
################################################################################

uninstall_app() {

  printf "*** Error: uninstall_app() not implemented yet.\n"

  case "$2" in
    *) exit ;;
  esac

  return
}

################################################################################
##
## Todo: Update PortsBuild Script
##
################################################################################

pb_update() {

  printf "PortsBuild update script\n"
  # wget -O portsbuild.sh ${PB_MIRROR}/portsbuild.sh

  ## Backup configuration file
  cp -f "${PB_CONF}" "${PB_CONF}.backup"

  # fetch -o ./${PORTSBUILD_NAME}.tar.gz "${PB_MIRROR}/${PORTSBUILD_NAME}.tar.gz"

  if [ -s "${PORTSBUILD_NAME}.tar.gz" ]; then
    printf "Extracting %s.tar.gz...\n" "${PORTSBUILD_NAME}"

    ${TAR} xvf "${PORTSBUILD_NAME}.tar.gz" --no-same-owner

    ${CHMOD} 700 portsbuild.sh
  else
    printf "Unable to extract %s.tar.gz\n" "${PORTSBUILD_NAME}"
  fi

  ## Symlink pb->portsbuild.sh
  if [ "${OPT_PB_SYMLINK}" = "YES" ]; then
    ln -s /usr/local/portsbuild/portsbuild.sh /usr/local/bin/pb
  fi

  return
}

################################################################################
##
## Upgrade an application or service
##
################################################################################

upgrade_app() {

  case $1 in
    "apache"|"httpd") apache_upgrade ;;
    "awstats") awstats_upgrade ;;
    "blockcracking"|"bc") blockcracking_upgrade ;;
    "directadmin"|"da") directadmin_update ;;
    "dovecot"|"dc") dovecot_upgrade ;;
    "easyspamfighter"|"esf") easyspamfighter_upgrade ;;
    "exim") exim_upgrade ;;
    "ioncube") ioncube_upgrade ;;
    "mariadb"|"maria") mariadb_upgrade ;;
    "modsecurity"|"modsec"|"mod_security") modsecurity_upgrade ;;
    "mysql"|"sql") mysql_upgrade ;;
    "nginx") nginx_upgrade ;;
    "php"|"fpm"|"php-fpm"|"php_fpm") php_upgrade ;;
    "phpmyadmin"|"pma") phpmyadmin_upgrade ;;
    "pigeonhole"|"ph") pigeonhole_upgrade ;;
    "portsbuild"|"pb") portsbuild_upgrade ;;
    "proftpd"|"proftp") proftpd_upgrade ;;
    "pureftpd"|"pureftp") pureftpd_upgrade ;;
    "roundcube"|"rc") roundcube_upgrade ;;
    "spamassassin"|"sa") spamassassin_upgrade ;;
    "suhosin") suhosin_upgrade ;;
    "webalizer") webalizer_upgrade ;;
    "") show_menu_upgrade ;;
  esac

  return
}

################################################################################
##
## Todo:Show Menu for Upgrades
##
################################################################################

show_menu_upgrade() {

  printf "\n  Listing possible upgrades:\n"

  return
}

################################################################################
##
## Show Setup Menu
##
################################################################################

show_menu_setup() {

  printf "\n"
  printf "  To setup PortsBuild and DirectAdmin for the first time, run:\n"
  printf "\t%s setup <USER_ID> <LICENSE_ID> <SERVER_FQDN> <ETH_DEV> <IP_ADDRESS> <IP_NETMASK>\n\n" "$0"

  return
}

################################################################################
## Show Configuration Values
################################################################################

show_config_values() {

  printf "\n"
  printf "\tConfigured Option Values (options.conf)\n"
  printf "\t=======================================\n"
  {
    printf "\tPHP Version: %s\n" "${OPT_PHP_VERSION}"
    printf "\tPHP Mode: %s\n" "${OPT_PHP_MODE}"
    printf "\tPHP ini Type: %s\n" "${OPT_PHP_INI_TYPE}"
    printf "\tWeb Server: %s\n" "${OPT_WEBSERVER}"
    printf "\tApache MPM: %s\n" "${OPT_APACHE_MPM}"
    printf "\tSQL Server: %s\n" "${OPT_SQL_DB}"
    printf "\tFTP Server: %s\n" "${OPT_FTPD}"
    printf "\tExim: %s\n" "${OPT_EXIM}"
    printf "\tDovecot: %s\n" "${OPT_DOVECOT}"
    printf "\tClamAV: %s\n" "${OPT_CLAMAV}"
    printf "\tExim w/ClamAV: %s\n" "${OPT_CLAMAV_WITH_EXIM}"
    printf "\tWebapps Inbox Prefix: %s\n" "${OPT_WEBAPPS_INBOX_PREFIX}"
    printf "\tSpam Inbox Prefix: %s\n" "${OPT_SPAM_INBOX_PREFIX}"
    printf "\tBlockCracking: %s\n" "${OPT_BLOCKCRACKING}"
    printf "\tEasy Spam Fighter: %s\n" "${OPT_EASY_SPAM_FIGHTER}"
    printf "\tSpamAssassin: %s\n" "${OPT_SPAMASSASSIN}"
    printf "\tSpamAssassin Utilities: %s\n" "${OPT_SPAMASSASSIN_UTILITIES}"
    printf "\tProFTPD Upload Scan: %s\n" "${OPT_PROFTPD_UPLOADSCAN}"
    printf "\tPureFTPD Upload Scan: %s\n" "${OPT_PUREFTPD_UPLOADSCAN}"
    printf "\tAwstats: %s\n" "${OPT_AWSTATS}"
    printf "\tWebalizer: %s\n" "${OPT_WEBALIZER}"
    printf "\tMajordomo: %s\n" "${OPT_MAJORDOMO}"
    printf "\tphpMyAdmin: %s\n" "${OPT_PHPMYADMIN}"
    printf "\tSuhosin: %s\n" "${OPT_SUHOSIN}"
    printf "\tSuhosin Upload Scan: %s\n" "${OPT_SUHOSIN_UPLOADSCAN}"
    printf "\tModSecurity: %s\n" "${OPT_MODSECURITY}"
    printf "\tRoundCube: %s\n" "${OPT_ROUNDCUBE}"
    printf "\tPigeonHole: %s\n" "${OPT_PIGEONHOLE}"
    printf "\tPB Symlink: %s\n" "${OPT_PB_SYMLINK}"
    printf "\tInstall Portmaster: %s\n" "${OPT_INSTALL_PORTMASTER}"
    printf "\tInstall CCache: %s\n" "${OPT_INSTALL_CCACHE}"
    printf "\tInstall Synth: %s\n" "${OPT_INSTALL_SYNTH}"
  } | column -t -s:

  printf "\n"

  return
}

################################################################################
## Show Configuration Menu
################################################################################

# show_config_menu() {

#   case $2 in
#     "daconf"|"da_conf") update_da_conf ;;
#     "") ;;
#   esac

# }

################################################################################
## Show Configuration
################################################################################

show_config() {

  case $2 in
    "daconf"|"da_conf") update_da_conf ;;
    "") show_config_values ;;
  esac

  return
}

################################################################################
## Show Debugging Information
################################################################################

show_debug() {

  printf "  Debugging Information\n\n"
  printf "===[PB]========================\n"
  show_version
  printf "Path: %s\n" "${PB_PATH}"
  # printf "PortsBuild Version/Build: %s / %s\n" ${PB_VER} ${PB_BUILD_DATE}
  printf "===[OS]========================\n"
  printf "Detected: %s\n" "${OS} ${OS_VER} ${MACHTYPE}"
  printf "Actual: %s\n" "$(uname -v)"
  printf "===[SSL]=======================\n"
  printf "OpenSSL binary path: %s\n" "${OPENSSL}"
  printf "OpenSSL extra options: %s\n" "${OPENSSL_EXTRA}"
  printf "Prefer Apache SSL Certificates: %s\n" "${OPT_PREFER_APACHE_SSL_CERTS}"
  printf "Prefer Exim SSL Certificates: %s\n" "${OPT_PREFER_EXIM_SSL_CERTS}"
  printf "Prefer Custom SSL Certificates: %s\n" "${OPT_PREFER_CUSTOM_SSL_CERTS}"
  printf "===[Misc]======================\n"
  printf "PortsBuild Symlink Enabled: %s\n" "${OPT_PB_SYMLINK}"
  printf "\n"

  return
}

################################################################################
## Verify: Rewrite Menu
################################################################################

rewrite_app() {

  local APP="$2"

  case "${APP}" in
    "apache"|"apache24") apache_host_conf ;;
    "exim") exim_rewrite_confs ;;
    "dovecot") dovecot_rewrite_confs ;;
    "named"|"bind"|"dns") named_rewrite_confs ;;
    "nginx") nginx_rewrite_confs ;;
    "php") php_rewrite_confs ;;
    "vhosts") rewrite_vhosts ;;
    "virtual") rewrite_virtual_confs ;;
    "") show_rewrite_menu ;;
  esac

  return
}

################################################################################
## Show Rewrite Menu
################################################################################

show_rewrite_menu() {

  printf "\n"
  printf "  Rewrite Configuration Files\n\n"
  printf "  Usage:\n"
  printf "\t%s rewrite [options] [arguments]\n\n" "$0"
  printf "  Available rewrite options:\n"
  {
    printf "\tapache: Rewrite Apache configuration files and virtual hosts\n"
    printf "\tdovecot: Rewrite Dovecot configuration files\n"
    printf "\texim: Rewrite Exim configuration files\n"
    printf "\tnamed: Rewrite Named (Bind) DNS files\n"
    printf "\tnginx: Rewrite Nginx configuration files and virtual hosts\n"
    printf "\tphp: Rewrite PHP configuration files\n"
    printf "\tvhosts: Rewrite Virtual Hosts\n"
    printf "\tvirtual: Rewrite Mail (/etc/virtual) directory\n"
  } | column -t -s:

  printf "\n"

  return
}

################################################################################
## Show Installation Menu
################################################################################

show_install_menu() {

  printf "\n"
  printf "  Install a Package (Application or Service)\n\n"
  printf "  Usage:\n"
  printf "\t%s install [package] [arguments]\n\n" "$0"
  printf "  Available packages to install:\n"
  {
    printf "\tapache:Apache 2.4\n"
    printf "\tawstats:Awstats\n"
    printf "\tbfm:Brute Force Monitor\n"
    printf "\tbc:Blockcracking\n"
    printf "\tdirectadmin:DirectAdmin\n"
    printf "\tdkim:DKIM\n"
    printf "\tesf:Easy Spam Fighter\n"
    printf "\texim:Exim\n"
    printf "\tioncube:Ioncube\n"
    printf "\tipfw:IPFW Firewall setup\n"
    printf "\tlibspf2:libspf\n"
    printf "\tmariadb:MariaDB\n"
    printf "\tmysql:MySQL\n"
    printf "\tnginx:Nginx\n"
    printf "\tphp:PHP\n"
    printf "\tpma:phpMyAdmin\n"
    printf "\tproftpd:ProFTPd\n"
    printf "\tpureftpd:PureFTPd\n"
    printf "\troundcube:RoundCube\n"
    printf "\tspamassassin:SpamAssassin\n"
    printf "\tsuhosin:Suhosin\n"
    printf "\twebalizer:Webalizer\n"
  } | column -t -s:

  printf "\n"

  return
}

################################################################################
## Show logo :)
################################################################################

show_logo() {
  printf "\n"
  printf "                ___\\\/_\n"
  printf "               /  /\/\\\  \n"
  printf "       _______/  /___  \n"
  printf "      /  __  / ___  /  \n"
  printf "     /  /_/ / /__/ /   \n"
  printf "    /  ____/______/    \n"
  printf "   /  /                \n"
  printf "  /__/                 \n\n"
}

################################################################################
## Show version
################################################################################

show_version() {
  printf "  PortsBuild version %s build %s\n" "${PB_VER}" "${PB_BUILD_DATE}"
  return
}

################################################################################
## Show Application Versions
################################################################################

show_versions() {
  printf "\n"
  printf "List of installed packages and their versions:\n\n"
  ## alternative way: awk '{printf("%15s %10s\n", $1, $2)}'
  ( printf "Package Version Origin\n" ; \
   pkgq -i -x "%n %v %o" '(www/apache24|www/nginx|security/clamav
   |lang/php56|lang/php70|lang/php71|ftp/curl|mail/exim
   |mail/dovecot2|lang/perl5|mail/roundcube|mail/spamassassin
   |ftp/wget|security/suhosin|www/suphp|databases/phpmyadmin
   |databases/mariadb55-server|databases/mariadb55-client
   |databases/mariadb100-server|databases/mariadb100-client
   |databases/mariadb101-server|databases/mariadb101-client
   |databases/mysql55-server|databases/mysql55-client
   |databases/mysql56-server|databases/mysql56-client
   |databases/mysql57-server|databases/mysql57-client)' ) | column -t
  printf "\n"

  return
}

################################################################################
## Show versions of (select) packages
################################################################################

show_outdated() {
  printf "\n"
  printf "List of installed packages that are out of date:\n\n"
  ( printf "Package Outdated\n" ; \
   ${PKG} version -l '<' -x '(www/apache24|www/nginx|security/clamav
   |lang/php56|lang/php70|lang/php71|ftp/curl|mail/exim
   |mail/dovecot2|lang/perl5|mail/roundcube|mail/spamassassin
   |ftp/wget|security/suhosin|www/suphp|databases/phpmyadmin
   |databases/mariadb55-server|databases/mariadb55-client
   |databases/mariadb100-server|databases/mariadb100-client
   |databases/mariadb101-server|databases/mariadb101-client
   |databases/mysql55-server|databases/mysql55-client
   |databases/mysql56-server|databases/mysql56-client
   |databases/mysql57-server|databases/mysql57-client)' ) | column -t
  printf "\n"

  return
}

################################################################################
## Show Audit
################################################################################

show_audit() {
  printf "\n"
  printf "List of installed packages that are vulnerable:\n\n"
  ${PKG} audit
  printf "\n"

  return
}

################################################################################
## About PortsBuild
################################################################################

show_about() {
  show_logo
  show_version
  printf "\n  Visit portsbuild.org or github.com/portsbuild/portsbuild\n\n"

  return
}

################################################################################
## Show the main menu
################################################################################

show_main_menu() { show_logo; show_version; show_menu; }

################################################################################
## Show selection menu
################################################################################

show_menu() {
  printf "\n"
  printf "  Usage:\n"
  printf "\t%s command [options] [arguments]\n\n" "$0"

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

  printf "  Available commands:\n"
  {
    printf "\tconfig: Display the current configuration option values\n"
    printf "\tdebug: Displays debugging information\n"
    printf "\thelp: Displays help information\n"
    # printf "\tinfo Displays information about an application or service\n"
    printf "\tinstall: Install an application or service\n"
    # printf "\toptions: Show configured PortsBuild options\n"
    printf "\toutdated: Show outdated applications or services on the system\n"
    printf "\trewrite: Rewrite (update) a configuration file\n"
    printf "\tsetup: Setup PortsBuild and DirectAdmin (first-time installations)\n"
    # printf "\tshow: Show something\n"
    printf "\tupdate: Updates the portsbuild script\n"
    printf "\tupgrade: Upgrades an application or service\n"
    # printf "\tverify: Verify something\n"
    printf "\tversions: Show version information on installed services\n"
  } | column -t -s:

  printf "\n"

  return
}

################################################################################

check_options_file

. options.conf

validate_options

################################################################################

## ./portsbuild selection screen

case "$1" in
  "about") show_about ;;                        ## show about
  "audit") show_audit ;;                        ## run "pkg audit"
  "c"|"config") show_config "$@" ;;             ## show configured option values
  "d"|"debug") show_debug ;;                    ## show debugging info
  "i"|"install"|"build") install_app "$@" ;;    ## install an application
  "o"|"outdated") show_outdated ;;              ## show installed packages that are out of date
  "r"|"rewrite") rewrite_app "$@" ;;            ## rewrite a configuration file (e.g. apache vhosts)
  "s"|"setup") global_setup "$@" ;;             ## first time setup
  # "show") show_show "$@" ;;                   ## show something
  "upd"|"update") pb_update ;;                  ## update PB script
  "upg"|"upgrade") upgrade "$@" ;;              ## let portsbuild upgrade an app/service (e.g. php via pkg)
  "check"|"verify") verify ;;                   ## verify system state
  "version") show_version ;;                    ## show portsbuild version
  "v"|"versions"|"installed") show_versions ;;  ## show app/service versions via pkg
  "func") "$2" ;;                               ## direct function call
  # "create_options") create_options ;;         ## create options.conf
  # "set") set_option "$@" ;;                   ## set value in options.conf
  # check_options) check_options ;;             ## validate options.conf
  "fix_ftp_accounts") fix_ftp_accounts "$@" ;;  ## Fix FTP Accounts
  "fix_startup") update_rcd ;;
  "rewrite_confs") rewrite_confs ;;             ## Rewrite web server configuration files
  "rewrite_namedb"|"rewrite_dns") rewrite_namedb ;; ## Fix named (DNS) database
  "exim_conf"|"eximconf") exim_conf ;;          ## Generate exim.conf
  *) show_main_menu ;;
esac

################################################################################
## EOF
################################################################################

exit 0
