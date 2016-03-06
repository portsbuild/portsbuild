#!/bin/sh
# *************************************************************************************************
# >>> PortsBuild
#
#  Scripted by -sg/mmx.
#
#  Based on the work of CustomBuild 2.x, written by DirectAdmin and Martynas Bendorius (smtalk).
#
#  CustomBuild2 thread: http://forum.directadmin.com/showthread.php?t=44743
#
#  DirectAdmin Homepage : http://www.directadmin.com
#  DirectAdmin Forums   : http://forums.directadmin.com
#
#  PortsBuild WWW       : http://www.portsbuild.org (coming soon)
#  PortsBuild GitHub    : http://github.com/portsbuild/portsbuild
#
# *************************************************************************************************
#
#  Requirements:
#  - DirectAdmin 1.46 and above (with a valid license).
#  - FreeBSD 10.2-amd64
#  - chmod +x portsbuild.sh
#  - Patience.
#
#  New Installations:
#  - Run: ./portsbuild setup <USER_ID> <LICENSE_ID> <SERVER_HOSTNAME> <ETH_DEV> (<IP_ADDRESS>)
#
#  Existing users:
#  - Update: ./portsbuild update
#  - Verify: ./portsbuild verify
#
# Changelog/History: see CHANGELOG for more details
#
# *************************************************************************************************
#
#
# *** If you want to modify PortsBuild settings, please check out 'conf/options.conf' ***
#
################################################################################################################################

### PortsBuild ###

PB_VER="0.1.0"
PB_BUILD_DATE=20160304

IFS="$(printf '\n\t')"

if [ "$(id -u)" != "0" ]; then
  echo "Must run this script as the root user.";
  exit 1;
fi

OS=$(uname)
OS_VER=$(uname -r | cut -d- -f1) # 9.3, 10.1, 10.2, 10.3
OS_B64=$(uname -m | grep -c 64)  # 0, 1
OS_MAJ=$(uname -r | cut -d. -f1) # 9, 10
OS_HOST=$(hostname);
OS_DOMAIN=$(echo "${OS_HOST}" | cut -d. -f2,3,4,5,6)

if [ "${OS}" = "FreeBSD" ]; then
  if [ "${OS_B64}" -eq 1 ]; then
    if [ "$OS_VER" = "10.1" ] || [ "$OS_VER" = "10.2" ] || [ "$OS_VER" = "10.3" ] ||  [ "$OS_VER" = "9.3" ]; then
      # echo "FreeBSD $OS_VER x64 operating system detected."
      echo ""
    else
      echo "Warning: Unsupported FreeBSD operating system detected."
      echo "PortsBuild is tested to work with FreeBSD versions 9.3, 10.1 and 10.2 amd64 only."
      echo "You can press CTRL+C within 5 seconds to quit the PortsBuild script now, or proceed at your own risk."
      sleep 5;
    fi
  else
    echo "Error: i386 (x86) systems are not supported."
    echo "PortsBuild requires FreeBSD 9.3+ amd64 (x64)."
    exit 1;
  fi
else
  echo "PortsBuild is for FreeBSD systems only. Please use CustomBuild for your Linux needs."
  echo "Visit: http://forum.directadmin.com/showthread.php?t=44743"
  exit 1;
fi

# || [ ! -f options.conf ]

if [ ! -f conf/defaults.conf ] || [ ! -f conf/ports.conf ]; then
 echo "Missing files in conf/"
# recreate them # exit;
fi


## Source (include) additional files into the script:
. conf/defaults.conf
. conf/ports.conf
. options.conf
#. conf/make.conf
#. lang/en.txt ## strings files for multilingual support (planned)

################################################################################################################################

## Get DirectAdmin Option Values (copied from CB2)
getDA_Opt() {
  ## $1 is option name
  ## $2 is default value

  ## Make sure directadmin.conf exists and is greater than zero bytes.
  if [ ! -s "${DA_CONF}" ]; then
    echo "$2"
    return
  fi

  ## Check for value in ./directadmin c
  if ! "${DA_BIN}" c | grep -m1 -q -e "^$1="; then
    echo "$2"
    return
  fi

  ${DA_BIN} c | grep -m1 "^$1=" | cut -d= -f2
}

################################################################################################################################

# ## Emulate ${!variable} (copied from CB2)
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
## Used to retrieve CB/PB options.conf
getOpt() {
  ## $1 = option name
  ## $2 = default value

  # CB2: Added "grep -v" to workaround many lines with empty options
  GET_OPTION=$(grep -v "^$1=$" "${OPTIONS_CONF}" | grep -m1 "^$1=" | cut -d= -f2)
  if [ "${GET_OPTION}" = "" ]; then
    echo "$1=$2" >> "${OPTIONS_CONF}"
  fi

  echo "${GET_OPTION}"
}

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
      VALID="yes"
      break
    fi
  done

  ## Invalid option
  if [ "${VALID}" = "no" ]; then
    echo "${2} is not a valid setting for ${1} option."
    #EXIT_CODE=51
    return
  fi

  OPT_VALUE=$(grep -m1 "^$1=" "${OPTIONS_CONF}" | cut -d= -f2)
  ${PERL} -pi -e "s#$1=${OPT_VALUE}#$1=$2#" ${PB_CONF}
}

################################################################################################################################

## Set Value (copied from CB2)
## Sets the value of $1 to $2 in the file $3
## e.g. setVal mysql_enable yes /etc/rc.conf
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

## Get Value from file
## getVal mysql_enable /etc/rc.conf
getVal() {
  ## $1: option
  ## $2: file to parse

  ## Returns 0 if option is undefined (doesn't exist or blank)

  ## Check if file exists.
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

  return;
}

## Unset Value (opposite of setVal)
# unsetVal() {
#     ## Check if file exists.
#     if [ ! -e $3 ]; then
#         return
#     fi

#     ## Can't put [brackets] around the statement else grep flips out.
#     if ! grep -m1 -q ${1}= ${3} ; then
#         ## It's not there. Great!
#         return
#     else
#         ## The value is already in the file $3, so use perl regex to remove it.
#         ${PERL} -pi -e "s/`grep ${1}= ${3}`//" ${3}
#     fi
# }

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

## Enable a service in /etc/rc.conf
service_on() {
  setVal "${1}_enable" \"YES\" /etc/rc.conf
}

## Disable a service in /etc/rc.conf
service_off() {
  setVal "${1}_enable" \"NO\" /etc/rc.conf
}

################################################################################################################################

## pkg update
pkg_update() {
  echo "Updating FreeBSD packages index"
  ${PKG} update
}

## Install packages without prompts
pkgi() {
  ${PKG} install -y "$1"
}

## Update /usr/ports
ports_update() {
  echo "Updating /usr/ports"
  ${PORTSNAP} fetch update
}

## Rinse & Repeat
make_install_clean() {

  ## Origin: category/portname
  CHOSEN_PORT=$1

  # if [ options_set blank] && [ options_unset blank ]; then
  # # install via pkg
  # pkg install -y ${CHOSEN_PORT}
  # elif
  # # install via ports:

  ## /usr/bin/make
  make -C "${PORTS_BASE}/${CHOSEN_PORT}" rmconfig
  make -C "${PORTS_BASE}/${CHOSEN_PORT}" config OPTIONS_SET="${_MAKE_OPTIONS_SET}" OPTIONS_UNSET="${_MAKE_OPTIONS_UNSET}"
  make -C "${PORTS_BASE}/${CHOSEN_PORT}" reinstall clean

  # fi

}

## Clean stale ports (deprecate soon)
clean_stale_ports() {
  echo "Cleaning stale ports"
  ${PORTMASTER} -s
}

## Reinstall all ports "in place" (deprecate soon)
## Todo: migrate this process to synth
reinstall_all_ports() {
  ## Consider -R
  ${PORTMASTER} -a -f -d

  ## Synth command
  # synth upgrade-system
}

## Update /etc/hosts
update_hosts() {
  COUNT=$(grep 127.0.0.1 /etc/hosts | grep -c localhost)
  if [ "$COUNT" -eq 0 ]; then
    echo "Updating /etc/hosts"
    printf "127.0.0.1\t\tlocalhost" >> /etc/hosts
  fi
}

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

## Add User to Group (copied from CB2)
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
  ## $2 = user_id
  ## $3 = license_id
  ## $4 = server_hostname
  ## $5 = eth_dev
  ## $6 = ip_address
  ## Note to self: 'shift'

  if [ "${DA_ADMIN_EMAIL}" = "" ]; then
    DA_ADMIN_EMAIL="${DA_ADMIN_USERNAME}@${SERVER_DOMAIN}"
  fi

  ## Make sure all inputs are entered (get rid of IP?)
  if [ "${1}" = "" ] || [ "${2}" = "" ] || [ "${3}" = "" ] || [ "${4}" = "" ] || [ "${5}" = "" ] || [ "${6}" = "" ]; then
    show_menu_setup
    return;
  else
    #echo "Arguments:"

    DA_USER_ID=$2
    DA_LICENSE_ID=$3
    DA_SERVER_HOSTNAME=$4
    ETHERNET_DEV=$5
    DA_SERVER_IP=$6
    DA_SERVER_IP_MASK=$7

  fi

  printf "Setup arguments received:\n User ID: %s\n License ID: %s\n Hostname: %s\n Ethernet Device: %s\n Server IP Address: %s\n\n" $2 $3 $4 $5 $6

  echo "Please make sure these values are correct and that they match the records in your DirectAdmin Client License Portal."
  echo "If in doubt, visit: https://www.directadmin.com/clients/"
  echo ""
  echo "About to setup PortsBuild and install DirectAdmin for the first time."
  echo "This will install, setup and configure the following services:"
  ## Todo: Process chosen options
  echo "DirectAdmin, Named, Exim 4.8, Dovecot 2, Apache 2.4, PHP-FPM 5.6, MariaDB 10.0, phpMyAdmin, RoundCube and SpamAssassin"

  ask_user "Do you want to continue?"


  ## Let's go! ##

  if [ $? -eq 1 ]; then

    echo "Bootstrapping and updating pkg"
    /usr/bin/env ASSUME_ALWAYS_YES=YES pkg bootstrap

    pkg_update;

    if [ ${FOUND_PORTS} -eq 0 ]; then
      echo "Setting up /usr/ports for the first time"
      ${PORTSNAP} fetch extract
    fi

    ports_update;

    ## Install Dependencies
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

      pkgi devel/ccache

      if [ $? = 0 ]; then
        setVal WITH_CCACHE_BUILD yes /etc/make.conf
      fi
    fi

    echo "Installing ports-mgmt/portmaster"
    pkgi ports-mgmt/portmaster

    ## Install Synth (https://github.com/jrmarino/synth)
    ## Successor to portmaster
    ## Usage examples:
    ##  synth just-build editors/joe editors/nano editors/libreoffice
    ##  synth just-build /tmp/build.list
    ##  synth upgrade-system
    ##  synth prepare-system

    echo "Installing ports-mgmt/synth"
    /usr/sbin/pkg install -y lang/gcc6-aux devel/ncurses

    ## Eventually replace with binary when it's ready
    if [ ! -e /usr/local/bin/synth ]; then
      cd /usr/ports/ports-mgmt/synth && make install clean
    fi

    ## Todo: Configure synth (copy Live system profile?)
    # synth configure

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
    setVal ipv6_ipv4mapping \"YES\" /etc/rc.conf
    setVal net.inet6.ip6.v6only 0 /etc/sysctl.conf

    /sbin/sysctl net.inet6.ip6.v6only=0

    ## Disable sendmail if Exim is enabled
    if [ "${EXIM_ENABLE}" = "YES" ] || [ "${DISABLE_SENDMAIL}" = "YES" ] ; then
      echo "Disabling sendmail from running (updating /etc/rc.conf)"
      setVal sendmail_enable \"NONE\" /etc/rc.conf
      setVal sendmail_submit_enable \"NO\" /etc/rc.conf
      setVal sendmail_outbound_enable \"NO\" /etc/rc.conf
      setVal sendmail_msp_queue_enable \"NO\" /etc/rc.conf

      ${SERVICE} sendmail onestop
    fi

    ## Ethernet Device checking here
    ## Skipping/avoiding this step as it's not that reliable of a process,
    ## especially if you have multiple interfaces.

    ## Make sure sshd is enabled
    echo "Enabling sshd in /etc/rc.conf"
    setVal sshd_enable \"YES\" /etc/rc.conf

    ${SERVICE} sshd start

    ## Configure named (BIND)
    bind_setup;




    ## Install & configure services and applications




    ## Go for the main attraction
    directadmin_install;

    ## Create a spoof CustomBuild2 options.conf for DirectAdmin compatibility.
    if [ ! -d ${CB_PATH} ]; then
      mkdir -p ${CB_PATH}
    fi

    if [ ! -e "${PB_DIR}/conf/cb-options.conf" ]; then
      ${wget_with_options} -O ${CB_CONF} "${PB_MIRROR}/conf/cb-options.conf"
    else
      cp "${PB_DIR}/conf/cb-options.conf" ${CB_CONF}
    fi

    if [ -e "${CB_CONF}" ]; then
      chown -f diradmin:diradmin ${CB_CONF}
      chmod 755 "${CB_CONF}"
    fi


    ## Skip: DirectAdmin Install
    # cd ${DA_PATH} || exit
    # ./directadmin i

    ## Set DirectAdmin Permissions
    cd ${DA_PATH} || exit
    ./directadmin p

    #${SERVICE} directadmin start

    global_post_install;

  else
    printf "PortsBuild installation canceled\n\n"
    show_main_menu;
  fi

}

## Global Post-Install Tasks
global_post_install() {
  ## cleanup leftover files?
  echo "All done!"
  #exit 0;
}

################################################################################################################################

## Update /etc/rc.conf
update_rc() {
  ## Go through installed/enabled services and make sure they're all enabled.
  ## Perhaps rename this function to verify_rc?

  ## Todo: refactor with "${SERVICE_NAME}_ENABLE"
  ## Todo: check for "${SERVICE_NAME}_INSTALL" as well

  if [ "${NAMED_ENABLE}" = "YES" ]; then
    setVal named_enable \"YES\" /etc/rc.conf
  fi

  ## Todo: write directadmin startup script
  # setVal directadmin_enable \"YES\" /etc/rc.conf

  if [ "${APACHE_ENABLE}" = "YES" ]; then
    setVal apache24_enable \"YES\" /etc/rc.conf
    setVal apache24_http_accept_enable \"YES\" /etc/rc.conf
    setVal accf_http_load \"YES\" /boot/loader.conf
    setVal accf_data_load \"YES\" /boot/loader.conf
  fi

  if [ "${NGINX_ENABLE}" = "YES" ]; then
    setVal nginx_enable \"YES\" /etc/rc.conf
  # else
  #   setVal nginx_enable \"NO\" /etc/rc.conf
  fi

  if [ "${SQL_DB_ENABLE}" = "YES" ]; then
    setVal mysql_enable \"YES\" /etc/rc.conf
    setval mysql_dbdir \"/var/db/mysql\" /etc/rc.conf
    setVal mysql_optfile \"/usr/local/etc/my.cnf\" /etc/rc.conf
  fi

  if [ "${PHP_ENABLE}" = "YES" ]; then
    setVal php_fpm_enable \"YES\" /etc/rc.conf
  fi

  if [ "${EXIM_ENABLE}" = "YES" ]; then
    setVal exim_enable \"YES\" /etc/rc.conf
    setval exim_flags \"-bd -q1h\" /etc/rc.conf
  fi

  if [ "${DOVECOT_ENABLE}" = "YES" ]; then
    setVal dovecot_enable \"YES\" /etc/rc.conf
  fi

  if [ "${PUREFTPD_ENABLE}" = "YES" ]; then
    setVal ftpd_enable \"NO\" /etc/rc.conf
    setVal pureftpd_enable \"YES\" /etc/rc.conf
  fi

  if [ "${PROFTPD_ENABLE}" = "YES" ]; then
    setVal proftpd_enable \"YES\" /etc/rc.conf
    setVal ftpd_enable \"NO\" /etc/rc.conf
  fi

  if [ "${SPAMASSASSIN_ENABLE}" = "YES" ]; then
    setVal spamd_enable \"YES\" /etc/rc.conf
    setVal spamd_flags \"-c -m 15\" /etc/rc.conf
  fi

  if [ "${SAUTILS_ENABLE}" = "YES" ]; then
    # Alternative: /etc/periodic.conf.local
    setVal daily_sa_enable \"YES\" /etc/periodic.conf
    setVal daily_sa_quiet \"NO\" /etc/periodic.conf
    # -D --nogpg
    # daily_sa_update_flags=""
    # daily_sa_compile_flags=""
    setVal daily_sa_compile_nice \"YES\" /etc/periodic.conf
    # daily_sa_compile_nice_flags=""
    setVal daily_sa_restart_spamd \"YES\" /etc/periodic.conf
  fi

  if [ "${CLAMAV_ENABLE}" = "YES" ]; then
    setVal clamav_clamd_enable \"YES\" /etc/rc.conf
    setVal clamav_freshclam_enable \"YES\" /etc/rc.conf
  fi

  if [ "${MEMCACHED_ENABLE}" = "YES" ]; then
    setVal memcached_enable \"YES\" /etc/rc.conf
    setVal memcached_flags \"-m 256 -d\" /etc/rc.conf
  fi

  return;
}

################################################################################################################################

## Update /etc/make.conf
# update_make() {
#   if [ ! -e /etc/make.conf ]; then
#     echo "Creating /etc/make.conf"
#     touch /etc/make.conf
#   fi

#   ## magic goes here
# }

## Set PORT options, either in /etc/make.conf
## or /var/db/ports/$portcode/options
configure_ports() {

  ## Set options in /etc/make.conf
  ## [CATEGORY]_[PORT]_[SET|UNSET]=OPTION1 OPTION2 ...
  ## root@test:/usr/ports/www/apache24 # make config OPTIONS_SET="SUEXEC MPM_EVENT" OPTIONS_UNSET="MPM_PREFORK"

  cd ${PORTS_BASE} || exit
}


################################################################################################################################

## Setup BIND (named)
bind_setup() {

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
        ${WGET} -O /var/named/etc/namedb/named.conf https://raw.githubusercontent.com/portsbuild/portsbuild/master/conf/named.100.conf
      fi
    fi

    if [ ! -e /usr/local/etc/namedb/rndc.key ]; then
      echo "Generating rndc.key for the first time"
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
        ${WGET} -O /etc/namedb/named.conf https://raw.githubusercontent.com/portsbuild/portsbuild/master/conf/named.93.conf
      fi
    fi

    if [ ! -e /etc/namedb/rndc.key ]; then
      echo "Generating rndc.key for the first time"
      /usr/sbin/rndc-confgen -a -s "${DA_SERVER_IP}"
    fi
  fi

  ## File target paths:
  ## 10.2: /var/named/etc/namedb/named.conf
  ## 9.3: /etc/namedb/named.conf

  # if [ "${OS_MAJ}" -eq 10 ]; then
  #   ## FreeBSD 10.2 with BIND 9.9.5 from ports
  #   ${WGET} -O /var/named/etc/namedb/named.conf https://raw.githubusercontent.com/portsbuild/portsbuild/master/conf/named.100.conf
  # elif [ "${OS_MAJ}" -eq 9 ]; then
  #   ## FreeBSD 9.3 with BIND 9.9.5 from base
  #   ${WGET} -O /etc/namedb/named.conf https://raw.githubusercontent.com/portsbuild/portsbuild/master/conf/named.93.conf
  # fi

  ## Generate BIND's rndc.key ("/usr/local/etc/namedb/rndc.key")
  # if [ ! -e /usr/local/etc/namedb/rndc.key ] || [ ! -e /etc/namedb/rndc.key ]; then
  #   echo "Generating rndc.key for the first time"
  #   rndc-confgen -a -s "${DA_SERVER_IP}"
  # fi

  echo "Updating /etc/rc.conf with named_enable=YES"
  setVal named_enable \"YES\" /etc/rc.conf

  echo "Starting named"
  ${SERVICE} named start

  return
}

################################################################################################################################

### DirectAdmin Installation ###

## Install DirectAdmin (replaces scripts/install.sh)
## Create necessary users & groups
directadmin_install() {

  ## Pre-Installation Tasks (replaces setup.sh)

  ## Need to create a blank /etc/auth.conf file for DA compatibility.
  echo "Checking for /etc/auth.conf"
  if [ ! -e /etc/auth.conf ]; then
    /usr/bin/touch /etc/auth.conf;
    /bin/chmod 644 /etc/auth.conf;
  fi

  ## Update /etc/aliases:
  if [ -e /etc/aliases ]; then
    COUNT=$(grep -c diradmin /etc/aliases)
    if [ "$COUNT" -eq 0 ]; then
      echo "diradmin: :blackhole:" >> /etc/aliases
    fi
    ## Update aliases database
    /usr/bin/newaliases
  fi

  mkdir ${DA_PATH}

  DA_LAN=1
  echo "Debugging: ${DA_LAN}"

  if [ ! -e "${DA_PATH}/update.tar.gz" ]; then
    ## Get DirectAdmin binary:
    if [ "${DA_LAN}" -eq 0 ]; then
      ${wget_with_options} --no-check-certificate -S -O ${DA_PATH}/update.tar.gz --bind-address="${DA_SERVER_IP}" "https://www.directadmin.com/cgi-bin/daupdate?uid=${DA_USER_ID}&lid=${DA_LICENSE_ID}"
    elif [ "${DA_LAN}" -eq 1 ]; then
      ${wget_with_options} --no-check-certificate -S -O ${DA_PATH}/update.tar.gz "https://www.directadmin.com/cgi-bin/daupdate?uid=${DA_USER_ID}&lid=${DA_LICENSE_ID}"
    fi
  fi

  if [ ! -e ${DA_PATH}/update.tar.gz ]; then
    echo "*** Error: Unable to download ${DA_PATH}/update.tar.gz";
    exit 3;
  fi

  COUNT=$(head -n 4 ${DA_PATH}/update.tar.gz | grep -c "* You are not allowed to run this program *");
  if [ "$COUNT" -ne 0 ]; then
    echo "";
    echo "*** Error: You are not authorized to download the update package with that Client ID and License ID from this IP address.";
    exit 4;
  fi

  ## Extract update.tar.gz into /usr/local/directadmin:
  cd "${DA_PATH}" || exit
  tar zxvf update.tar.gz

  ## See if the binary exists:
  if [ ! -e "${DA_PATH}/directadmin" ]; then
    echo "*** Error: Cannot find the DirectAdmin binary. Extraction failed.";
    exit 5;
  fi

  ## These were in do_checks()

  ## Check for a separate /home partition (for quota support).
  #HOME_YES=`cat /etc/fstab | grep -c /home`;
  HOME_YES=$(grep -c /home < /etc/fstab)
  if [ "$HOME_YES" -lt "1" ]; then
    echo "quota_partition=/" >> ${DA_CONF_TEMPLATE};
  fi

  ## Detect the ethernet interfaces that are available on the system (or use the one supplied by the user)
  ## NOTE: can return more than 1 interface, even commented, from /etc/rc.conf
  if [ ! -e "${ETHERNET_DEV}" ]; then
    ETH_DEV="$(grep ifconfig < /etc/rc.conf | cut -d= -f1 | cut -d_ -f2)"
    if [ "$ETH_DEV" != "" ]; then
      COUNT=$(grep -c ethernet_dev < $DA_CONF_TEMPLATE);
      if [ "$COUNT" -eq 0 ]; then
        echo ethernet_dev="${ETH_DEV}" >> ${DA_CONF_TEMPLATE};
      fi
    fi
  fi

  ## From setup.sh: generate setup.txt
  {
    echo "hostname=${SERVER_FQDN}";
    echo "email=${DA_ADMIN_USERNAME}@${SERVER_DOMAIN}";
    echo "mysql=${DA_SQL_PASSWORD}";
    echo "mysqluser=${DA_SQLDB_USERNAME}";
    echo "adminname=${DA_ADMIN_USERNAME}";
    echo "adminpass=${DA_ADMIN_PASSWORD}";
    echo "ns1=ns1.${SERVER_DOMAIN}";
    echo "ns2=ns2.${SERVER_DOMAIN}";
    echo "ip=${DA_SERVER_IP}";
    echo "netmask=${DA_SERVER_IP_MASK}";
    echo "uid=${DA_USER_ID}";
    echo "lid=${DA_LICENSE_ID}";
    echo "services=${DA_FREEBSD_SERVICES}";
  } > "${SETUP_TXT}";

  chmod 600 "${SETUP_TXT}";

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
  # touch ${DA_PATH}/data/users/admin/u_welcome.txt
  # touch ${DA_PATH}/data/admin/r_welcome.txt

  ## PB: Create backup.conf (wasn't created? need to verify)
  # chown -f diradmin:diradmin ${DA_PATH}/data/users/admin/backup.conf

  SSHROOT=$(grep -c 'AllowUsers root' < /etc/ssh/sshd_config)
  if [ "${SSHROOT}" = 0 ]; then
    {
      echo "AllowUsers root"
      echo "AllowUsers ${DA_ADMIN_USERNAME}"
      echo "AllowUsers $(logname)"
      ## echo "AllowUsers YOUR_OTHER_ADMIN_ACCOUNT" >> /etc/ssh/sshd_config
    } >> /etc/ssh/sshd_config

    ## Set SSH folder permissions (needed?):
    chmod 710 /etc/ssh
  fi

  ## PB: Change this:
  HTTP="http"

  if [ ! -e "${DA_LICENSE_FILE}" ]; then
    ## Get the DirectAdmin License Key File (untested)
    ${wget_with_options} "${HTTP}://www.directadmin.com/cgi-bin/licenseupdate?lid=${DA_LICENSE_ID}\&uid=${DA_LICENSE_ID}${EXTRA_VALUE}" -O "${DA_LICENSE_FILE}" "${BIND_ADDRESS}"

    if [ $? -ne 0 ]; then
      echo "*** Error: Unable to download the license file."
      da_myip
      echo "Trying license relay server..."

      ${wget_with_options} "${HTTP}://license.directadmin.com/licenseupdate.php?lid=${DA_LICENSE_ID}\&uid=${DA_LICENSE_ID}${EXTRA_VALUE}" -O "${DA_LICENSE_FILE}" "${BIND_ADDRESS}"

      if [ $? -ne 0 ]; then
        echo "*** Error: Unable to download the license file from relay server as well."
        da_myip
        exit 2
      fi
    fi

    COUNT=$(grep -c "* You are not allowed to run this program *" ${DA_LICENSE_FILE})
    if [ "${COUNT}" -ne 0 ]; then
      echo "*** Error: You are not authorized to download the license with that Client ID and License ID (and/or IP address). Please email sales@directadmin.com"
      echo ""
      echo "If you are having connection issues, please see this guide:"
      echo "    http://help.directadmin.com/item.php?id=30"
      echo ""
      da_myip;
      exit 3;
    fi
  fi

  ## Set permissions on license.key:
  chmod 600 $DA_LICENSE_FILE
  chown diradmin:diradmin $DA_LICENSE_FILE

  ## DirectAdmin Post-Installation Tasks
  mkdir -p ${DA_PATH}/data/users/admin/packages
  chown diradmin:diradmin ${DA_PATH}/data/users/admin/packages
  chmod 700 ${DA_PATH}/data/users/admin/packages

}

## Copied from DA/scripts/getLicense.sh
da_myip() {
  IP=$(${wget_with_options} "${BIND_ADDRESS}" -qO - "${HTTP}://myip.directadmin.com")

  if [ "${IP}" = "" ]; then
    echo "*** Error: Cannot determine the server's IP address via myip.directadmin.com"
    return;
  fi

  echo "IP used to connect out: ${IP}"
}

## DirectAdmin Upgrade
directadmin_upgrade() {
  return;
}

directadmin_restart() {
  echo "action=directadmin&value=reload" >> "${DA_TASK_QUEUE}"
  run_dataskq
}


################################################################################################################################

## Install DA cron (from: scripts/install.sh)
install_cron() {
  ## Need to add:
  # * * * * * root /usr/local/directadmin/dataskq
  # 2 0-23/6 * * * root echo 'action=vacation&value=all' >> /usr/local/directadmin/data/task.queue;
  # 5 0 * * * root /usr/sbin/quotaoff -a; /sbin/quotacheck -aug; /usr/sbin/quotaon -a;
  # 30 0 * * * root echo 'action=tally&value=all' >> /usr/local/directadmin/data/task.queue
  # 40 1 1 * * root echo 'action=reset&value=all' >> /usr/local/directadmin/data/task.queue
  # 0 4 * * * root echo 'action=check&value=license' >> /usr/local/directadmin/data/task.queue

  COUNT=$(grep -c dataskq < /etc/crontab)
  if [ "$COUNT" = 0 ]; then
    if [ -s "${DA_CRON}" ]; then
      cat "${DA_CRON}" >> /etc/crontab;
    else
      echo "Error: Could not find ${DA_CRON} or it is empty.";
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


## Verify Webapps Log Rotation (copied from CB2)
verify_webapps_logrotate() {

    # By default it sets each log to webapps:webapps.
    # Swap it to apache:apache if needed
    # else swap it to webapps:webapps from apache:apache... or do nothing

    NSL_VALUE=${WEBAPPS_USER}:${WEBAPPS_GROUP}

    if [ "${PHP1_MODE}" = "mod_php" ]; then
      NSL_VALUE=${APACHE_USER}:${APACHE_GROUP}
    fi

    if [ "${ROUNDCUBE_ENABLE}" = "YES" ]; then
      freebsd_set_newsyslog /usr/local/www/roundcube/logs/errors ${NSL_VALUE}
    fi

    if [ "${SQUIRRELMAIL_ENABLE}" = "YES" ]; then
      freebsd_set_newsyslog /usr/local/www/squirrelmail/data/squirrelmail_access_log ${NSL_VALUE}
    fi

    if [ "${PHPMYADMIN_ENABLE}" = "YES" ]; then
      freebsd_set_newsyslog /usr/local/www/phpMyAdmin/log/auth.log ${NSL_VALUE}
    fi

    return
}

################################################################################################################################

## Exim Installation
exim_install() {

  ### Main Installation
  make -C ${PORT_EXIM} rmconfig
  make -C ${PORT_EXIM} config EXIM_USER="${EXIM_USER}" EXIM_GROUP="${EXIM_GROUP}" mail_exim_SET="${EXIM_MAKE_OPTIONS_SET}" mail_exim_UNSET="${EXIM_MAKE_OPTIONS_UNSET}" OPTIONS_SET="" OPTIONS_UNSET=""
  make -C ${PORT_EXIM} reinstall clean

  ### Pre-Installation Tasks

  ## From: DA/scripts/install.sh
  mkdir -p ${VIRTUAL_PATH}
  chown -f ${EXIM_USER}:${EXIM_GROUP} ${VIRTUAL_PATH}
  chmod 755 ${VIRTUAL_PATH}

  ## replace $(hostname)
  hostname >> ${VIRTUAL_PATH}/domains

  if [ ! -s "${VIRTUAL_PATH}/limit" ]; then
    echo "${LIMIT_DEFAULT}" > "${VIRTUAL_PATH}/limit"
  fi

  if [ ! -s "${VIRTUAL_PATH}/limit_unknown" ]; then
    echo "${LIMIT_UNKNOWN}" > "${VIRTUAL_PATH}/limit_unknown"
  fi

  chmod 755 ${VIRTUAL_PATH}/*
  mkdir ${VIRTUAL_PATH}/usage
  chmod 750 ${VIRTUAL_PATH}/usage

  for i in domains domainowners pophosts blacklist_domains whitelist_from use_rbl_domains bad_sender_hosts bad_sender_hosts_ip blacklist_senders whitelist_domains whitelist_hosts whitelist_hosts_ip whitelist_senders skip_av_domains skip_rbl_domains; do
    touch ${VIRTUAL_PATH}/$i
    chmod 600 ${VIRTUAL_PATH}/$i
  done

  chown -f ${EXIM_USER}:${EXIM_GROUP} ${VIRTUAL_PATH}/*

  ### Post-Install Tasks

  ## Set permissions
  chown -R ${EXIM_USER}:${EXIM_GROUP} /var/spool/exim

  ## Symlink for compat:
  ln -s ${EXIM_CONF} /etc/exim.conf

  ## Generate Self-Signed SSL Certificates
  ## See: http://help.directadmin.com/item.php?id=245
  /usr/bin/openssl req -x509 -newkey rsa:2048 -keyout ${EXIM_SSL_KEY} -out ${EXIM_SSL_CRT} -days 9000 -nodes

  ## Symlink for DA compat
  ln -s ${EXIM_SSL_KEY} /etc/exim.key
  ln -s ${EXIM_SSL_CRT} /etc/exim.cert

  ## Set permissions:
  chown ${EXIM_USER}:${EXIM_GROUP} ${EXIM_SSL_KEY}
  chmod 644 ${EXIM_SSL_KEY}
  chmod 644 ${EXIM_SSL_CRT}

  ## Reference: Verify Exim config:
  /usr/local/sbin/exim -C ${EXIM_CONF} -bV

  ## Update /etc/rc.conf
  echo "Enabling Exim startup (updating /etc/rc.conf)"
  setVal exim_enable \"YES\" /etc/rc.conf
  setVal exim_flags \"-bd -q1h\" /etc/rc.conf

  echo "Starting Exim"
  ${SERVICE} exim start

  ## Tel DA new path to Exim binary.
  setVal mq_exim_bin "/usr/local/sbin/exim" >> ${DA_CONF}

  ## Replace sendmail programs with Exim binaries.
  ## If I recall correctly, there's another way to do this via mail/exim and typing "make something"
  if [ ! -e /etc/mail/mailer.conf ]; then
    echo "Creating /etc/mail/mailer.conf"
    #touch /etc/mail/mailer.conf

    cp ${PB_PATH}/configure/etc/mailer.93.conf /etc/mail/mailer.conf
    cp ${PB_PATH}/configure/etc/mailer.100.conf /etc/mail/mailer.conf

  # else
    ## Update /etc/mail/mailer.conf:
    #sendmail       /usr/libexec/sendmail/sendmail
    #send-mail      /usr/libexec/sendmail/sendmail
    #mailq          /usr/libexec/sendmail/sendmail
    #newaliases     /usr/libexec/sendmail/sendmail
    #hoststat       /usr/libexec/sendmail/sendmail
    #purgestat      /usr/libexec/sendmail/sendmail

    ## Change to:
    # sendmail        /usr/local/sbin/exim
    # send-mail       /usr/local/sbin/exim
    # mailq           /usr/local/sbin/exim -bp
    # newaliases      /usr/bin/true
    # rmail           /usr/local/sbin/exim -i -oee
  fi

  if [ ! -e /etc/periodic.conf ]; then
    touch /etc/periodic.conf
  fi

  setVal daily_status_include_submit_mailq \"NO\" /etc/periodic.conf
  setVal daily_clean_hoststat_enable \"NO\" /etc/periodic.conf
}

################################################################################################################################

## SpamAssassin Installation Tasks
spamassassin_install() {

  ### Main Installation
  make -C ${PORT_SPAMASSASSIN} rmconfig
  make -C ${PORT_SPAMASSASSIN} config mail_spamassassin_SET="${mail_spamassassin_SET}" mail_spamassassin_UNSET="${mail_spamassassin_UNSET}" OPTIONS_SET="" OPTIONS_UNSET=""
  make -C ${PORT_SPAMASSASSIN} reinstall clean

  ## SpamAssassin Post-Installation Tasks
  setVal spamd_enable \"YES\" /etc/rc.conf
  setVal spamd_flags \"-c -m 15\" /etc/rc.conf
}


################################################################################################################################

## Install Exim BlockCracking (BC)
blockcracking_install() {

  ## Check for Exim
  pkg query %n "exim"

  if [ -x ${EXIM_BIN} ]; then

    ${wget_with_options} -O ${PB_MIRROR}/exim/exim.blockcracking.tar.gz

    mkdir -p ${EXIM_PATH}/exim.blockcracking

    ## Extract
    tar xzf exim.blockcracking-${BLOCKCRACKING_VER}.tar.gz -C ${EXIM_PATH}/exim.blockcracking

    BC_DP_SRC=${EXIM_PATH}/exim.blockcracking/script.denied_paths.default.txt

    if [ -e ${EXIM_PATH}/exim.blockcracking/script.denied_paths.custom.txt ]; then
      echo "Using custom BlockCracking script.denied_paths.custom.txt"
      BC_DP_SRC=${EXIM_PATH}/exim.blockcracking/script.denied_paths.custom.txt
    fi

    cp -fp ${BC_DP_SRC} ${EXIM_PATH}/exim.blockcracking/script.denied_paths.txt

    echo "Restarting exim."

    /usr/sbin/service exim restart

    echo "BlockCracking is now enabled."

  else
    echo "*** Error: Exim is not installed. Cannot continue as the binary was not found."
  fi

  return;
}

################################################################################################################################

## Install Easy Spam Figter (ESF)
easyspamfighter_install() {

  ## Check for Exim
  if [ -x ${EXIM_BIN} ]; then
    ## See if SPF and SRS has been enabled (compiled in).
    EXIM_SPF_SUPPORT="$(/usr/local/sbin/exim --version | grep -m1 -c SPF)"
    EXIM_SRS_SUPPORT="$(/usr/local/sbin/exim --version | grep -m1 -c SRS)"

    if [ "${EXIM_SPF_SUPPORT}" = "0" ]; then
      echo "*** Error: Your version of Exim does not support SPF. This is needed for Easy Spam Fighter."
      echo "Please reinstall Exim with SPF support."
      exit 1;
    fi

    if [ "${EXIM_SRS_SUPPORT}" = "0" ]; then
      echo "*** Error: Your version of Exim does not support SRS. This is needed for Easy Spam Fighter."
      echo "Please reinstall Exim with SRS support."
      exit 1;
    fi

    # if [ "${EXIMCONF_RELEASE_OPT}" = "2.1" ] || [ "${EXIMCONF_RELEASE_OPT}" = "4.2" ]; then
    #   echo "${boldon}WARNING:${boldoff} Your exim.conf version might be incompatible with Easy Spam Fighter. Please make sure that your exim.conf release is 4.3 or higher."
    # fi

    # if [ ! -d ${WORKDIR}/easy_spam_fighter ]; then
    #   mkdir -p ${WORKDIR}/easy_spam_fighter
    #   chmod 700 ${WORKDIR}/easy_spam_fighter
    # fi

    # cd ${WORKDIR}
    echo "Enabling Easy Spam Fighter..."

    ## Download ESF files
    # getFile easy_spam_fighter/exim.easy_spam_fighter-${EASY_SPAM_FIGHTER_VER}.tar.gz easy_spam_figther exim.easy_spam_fighter-${EASY_SPAM_FIGHTER_VER}.tar.gz

    #wget_with_options -O esf.tar.gz ${PB_MIRROR}/exim/esf.tar.gz

    mkdir -p ${EXIM_PATH}/exim.easy_spam_fighter

    tar xzf exim.easy_spam_fighter-${EASY_SPAM_FIGHTER_VER}.tar.gz -C ${EXIM_PATH}/exim.easy_spam_fighter

    echo "Restarting Exim."

    /usr/sbin/service exim restart

    echo "Easy Spam Fighter is now enabled."
  else
    echo "*** Error: Exim is not installed. Cannot continue as the binary was not found."
  fi

  return;
}

################################################################################################################################

## Dovecot2 Installation Tasks
dovecot_install() {

  ### Main Installation
  make -C "${PORT_DOVECOT2}" rmconfig
  make -C "${PORT_DOVECOT2}" config mail_dovecot2_SET="${mail_dovecot2_SET}" mail_dovecot2_UNSET="${mail_dovecot2_UNSET}" OPTIONS_SET="" OPTIONS_UNSET=""
  make -C "${PORT_DOVECOT2}" reinstall clean

  ### Post-Installation Tasks

  ## Update directadmin.conf:
  COUNT=0
  if [ -e ${DA_CONF} ]; then
    COUNT="$(grep -m1 -c -e '^add_userdb_quota=1' ${DA_CONF})"

    if [ "${COUNT}" = "0" ]; then
      # echo "Adding add_userdb_quota=1 to the ${DA_CONF} file to enable Dovecot quota support"
      echo "add_userdb_quota=1" >> ${DA_CONF}
      directadmin_restart
      echo "action=rewrite&value=email_passwd" >> ${DA_TASK_QUEUE}
      run_dataskq d
    fi
  fi

  ## Update directadmin.conf (template):
  COUNT_TEMPLATE="$(grep -m1 -c -e '^add_userdb_quota=1' ${DA_CONF_TEMPLATE})"
  if [ "${COUNT_TEMPLATE}" = "0" ] && [ -e ${DA_CONF_TEMPLATE} ]; then
    # echo "Adding add_userdb_quota=1 to the ${DA_CONF_TEMPLATE} (template) file"
    echo "add_userdb_quota=1" >> ${DA_CONF_TEMPLATE}
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
  cp -rf ${PB_PATH}/configure/dovecot/conf ${DOVECOT_PATH}/conf
  cp -rf ${PB_PATH}/configure/dovecot/conf.d ${DOVECOT_PATH}/conf.d

  ## Setup config:
  if [ -e "${PB_PATH}/configure/dovecot/dovecot.conf" ]; then
    cp "${PB_PATH}/configure/dovecot/dovecot.conf" ${DOVECOT_CONF}
  # else
   # ${WGET} -O ${DOVECOT_CONF} http://files.directadmin.com/services/custombuild/dovecot.conf.2.0
  fi

  ## Symlink for compat:
  mkdir -p /etc/dovecot/
  ln -s ${DOVECOT_CONF} ${DOVECOT_PATH}/dovecot.conf
  ## Skipped: ln -s /etc/dovecot/dovecot.conf /etc/dovecot.conf

  #cp -f ${PB_PATH}/configure/dovecot/conf.d/90-quote.conf ${DOVECOT_PATH}/conf.d/90-quota.conf

  ## PigeonHole (not done yet):
  if [ "${PIGEONHOLE_OPT}" = "YES" ]; then

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

  ## verify_dovecot_logrotate
  freebsd_set_newsyslog /var/log/dovecot-lmtp-errors.log root:wheel
  freebsd_set_newsyslog /var/log/dovecot-lmtp.log root:wheel

  echo "Enabling Dovecot startup (upating /etc/rc.conf)"
  setVal dovecot_enable \"YES\" /etc/rc.conf

  ${SERVICE} dovecot restart
}

## Dovecot Configuration
dovecot_config() {
  return;
}
## Dovecot Upgrade
dovecot_upgrade() {

  return;
}

## Dovecot Uninstall
dovecot_uninstall() {
  return;
}

################################################################################################################################

## Webalizer Installation (incomplete)
webalizer_install() {
  if [ "${AWSTATS_OPT}" = "no" ]; then
    setVal awstats 0 ${DA_CONF_TEMPLATE}
    setVal awstats 0 ${DA_CONF}
  else
    setVal awstats 1 ${DA_CONF_TEMPLATE}
    setVal awstats 1 ${DA_CONF}
  fi

  doRestartDA

  if [ -e /etc/webalizer.conf ]; then
    mv -f /etc/webalizer.conf /etc/webalizer.conf.moved 2> /dev/null > /dev/null
  fi
}

## AwStats Installation (incomplete)
awstats_install() {

  #setup the directadmin.conf
  setVal awstats 1 ${DA_CONF_TEMPLATE}
  setVal awstats 1 ${DA_CONF}
  if [ "${WEBALIZER_OPT}" = "no" ]; then
    setVal webalizer 0 ${DA_CONF_TEMPLATE}
    setVal webalizer 0 ${DA_CONF}
  else
    setVal webalizer 1 ${DA_CONF_TEMPLATE}
    setVal webalizer 1 ${DA_CONF}
  fi

  doRestartDA
}

################################################################################################################################

## Verify my.cnf (copied from CB2)
verify_my_cnf() {
  # $1 = path to cnf
  # $2 = user
  # $3 = pass
  # $4 = optional source file to compare with. update 1 if 4 is newer.
  # host will be on the command line, as that's how DA already does it.

  E_MY_CNF=$1

  W=0
  if [ ! -s ${E_MY_CNF} ]; then
    W=1
  fi

  if [ "${W}" = "0" ] && [ "${4}" != "" ]; then
    if [ ! -s $4 ]; then
      echo "verify_my_cnf: cannot find $4"
      W=1
    else
      MY_CNF_T=$(${file_mtime} ${E_MY_CNF})
      SRC_CNF_T=$(${file_mtime} ${4})

      if [ "${MY_CNF_T}" -lt "${SRC_CNF_T}" ]; then
        echo "Found outdated ${E_MY_CNF}. Rewriting from ${4}"
        W=1
      fi
    fi
  fi

  if [ "${W}" = "1" ]; then
    echo '[client]' > ${E_MY_CNF}
    chmod 600 "${E_MY_CNF}"
    echo "user=${2}" >> "${E_MY_CNF}"
    echo "password=${3}" >> "${E_MY_CNF}"
  fi
}

################################################################################################################################

## Initialize SQL Parameters (copied from CB2)
get_sql_settings() {
  ## DA_MYSQL=/usr/local/directadmin/conf/mysql.conf
  ## Use: ${DA_MYSQL_CONF}

  if [ -s ${DA_MYSQL_CONF} ]; then
    MYSQL_USER=$(grep -m1 "^user=" ${DA_MYSQL_CONF} | cut -d= -f2)
    MYSQL_PASS=$(grep -m1 "^passwd=" ${DA_MYSQL_CONF} | cut -d= -f2)
  else
    MYSQL_USER='da_admin'
    MYSQL_PASS='nothing'
  fi

  if [ -s ${DA_MYSQL_CONF} ] && [ "$(grep -m1 -c -e "^host=" ${DA_MYSQL_CONF})" -gt "0" ]; then
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
        if [ -s "${WORKDIR}/scripts/setup.txt" ]; then
          MYSQL_ACCESS_HOST=$(grep -m1 -e '^ip=' "${WORKDIR}/scripts/setup.txt" | cut -d= -f2)
        fi
        if [ "${MYSQL_ACCESS_HOST}" = "" ]; then
          echo "Unable to detect your server IP in /etc/hosts. Please enter it: "
          read -r MYSQL_ACCESS_HOST
        fi
      fi
    fi
  fi

  #verify_my_cnf ${DA_MYSQL_CNF} "${MYSQL_USER}" "${MYSQL_PASS}" "${DA_MYSQL_CONF}"
  chown diradmin:diradmin "${DA_MYSQL_CNF}"
}

################################################################################################################################

## SQL Post-Installation Tasks
sql_post_install() {

  ## Remove /etc/my.cnf if it exists (not compliant with hier)
  if [ -e /etc/my.cnf ]; then
    # if [ ! -e ${MYSQL_CNF} ]
    #   mv /etc/my.cnf ${MYSQL_CNF}
    # else
      mv /etc/my.cnf /etc/my.cnf.disabled
    # fi
  fi

  ## Secure Installation (replace it with scripted method below)
  ## /usr/local/bin/mysql_secure_installation
  echo "Securing SQL installation"
  ${MYSQLSECURE_BIN}

  if [ -e "${MYSQLUPGRADE_BIN}" ]; then
    ${MYSQLUPGRADE_BIN} --defaults-extra-file=${DA_MYSQL_CNF}
  elif [ -e "${MYSQLFIX_BIN}" ]; then
    ${MYSQLFIX_BIN} --defaults-extra-file=${DA_MYSQL_CNF}
  fi

  ## From CB2 (skipped, 5.1 is outdated):
  # if [ -e /usr/local/mysql/bin/mysqlcheck ] && [ "${MYSQL_OPT}" = "5.1" ] && [ "${MYSQL_INST_OPT}" != "mariadb" ]; then
  #   /usr/local/mysql/bin/mysqlcheck --defaults-extra-file=${DA_MY_CNF} --fix-db-names --fix-table-names -A
  # fi

  ## Use this:
  # /usr/local/bin/mysqladmin --user=root password YOURSQLPASSWORD 1> /dev/null 2> /dev/null
  # echo "UPDATE mysql.user SET password=PASSWORD('YOURSQLPASSWORD') WHERE user='root';"> mysql.temp;
  # echo "UPDATE mysql.user SET password=PASSWORD('YOURSQLPASSWORD') WHERE password='';">> mysql.temp;
  # echo "DROP DATABASE IF EXISTS test;" >> mysql.temp
  # echo "FLUSH PRIVILEGES;" >> mysql.temp;
  # /usr/local/bin/mysql mysql --user=root --password=YOURSQLPASSWORD < mysql.temp;
  # rm -f mysql.temp;

  ## Note: there are two (2) users (with different passwords): root and da_admin
  ## Add the `da_admin` user to MySQL (replace the variables!):
  # echo "GRANT CREATE, DROP ON *.* TO da_admin@localhost IDENTIFIED BY 'YOURSQLPASSWORD' WITH GRANT OPTION;" > mysql.temp;
  # echo "GRANT ALL PRIVILEGES ON *.* TO da_admin@localhost IDENTIFIED BY 'YOURSQLPASSWORD' WITH GRANT OPTION;" >> mysql.temp;
  # /usr/local/bin/mysql --user=root --password=YOURSQLPASSWORD < mysql.temp;
  # rm -f mysql.temp;


  ## CLI method (incomplete):
  #   /usr/local/bin/mysql --user=root --password=ROOT_SQL_PASSWORD "GRANT CREATE, DROP ON *.* TO da_admin@localhost IDENTIFIED BY 'DA_ADMIN_SQL_PASSWORD' WITH GRANT OPTION;"

  ## Add DirectAdmin `da_admin` SQL database credentials to `mysql.conf`:
  echo "user=da_admin" > ${DA_MYSQL_CONF}
  echo "passwd=${DA_ADMIN_SQL_PASSWORD}" >> ${DA_MYSQL_CONF}
  chown diradmin:diradmin ${DA_MYSQL_CONF}
  chmod 400 ${DA_MYSQL_CONF}

  ## Defaults: /usr/local/share/mysql/*.cnf
  if [ ! -e "${MYSQL_CNF}" ]; then
    case ${DEFAULT_MY_CNF} in
      my-huge.cnf|my-medium.cnf|my-innodb-heavy-4G.cnf|my-small.cnf|my-large.cnf) cp /usr/local/share/mysql/${DEFAULT_MY_CNF} "${MYSQL_CNF}" ;;
      my-huge|my-medium|my-innodb-heavy-4G|my-small|my-large) cp /usr/local/share/mysql/${DEFAULT_MY_CNF}.cnf "${MYSQL_CNF}" ;;
      custom) cp -f ${CUSTOM_MYSQL_CNF} "${MYSQL_CNF}" ;;
      *)
        touch ${MYSQL_CNF}
        echo "[mysqld]" > ${MYSQL_CNF}
        echo "local-infile=0" >> ${MYSQL_CNF}
        echo "innodb_file_per_table" >> ${MYSQL_CNF}
        ;;
    esac
    chown root:wheel ${MYSQL_CNF}
  fi

  ## Symlink the MySQL/MariaDB binaries for compat:
  DA_MYSQL_PATH=/usr/local/mysql/bin
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
}


################################################################################################################################

## PHP Installation Tasks
php_install() {

  case ${PHP1_VERSION} in
    55) PORT_PHP="${PORT_PHP55}"
        PORT_PHP_EXT="${PORT_PHP55_EXT}"
        PHP_MAKE_OPTIONS_SET="${PHP55_MAKE_OPTIONS_SET}"
        PHP_MAKE_OPTIONS_UNSET="${PHP55_MAKE_OPTIONS_UNSET}"
        PHP_EXT_MAKE_OPTIONS_SET="${PHP55_EXT_MAKE_OPTIONS_SET}"
        PHP_EXT_MAKE_OPTIONS_UNSET="${PHP55_EXT_MAKE_OPTIONS_UNSET}"
        ;;
    56) PORT_PHP="${PORT_PHP55}"
        PORT_PHP_EXT="${PORT_PHP56_EXT}"
        PHP_MAKE_OPTIONS_SET="${PHP56_MAKE_OPTIONS_SET}"
        PHP_MAKE_OPTIONS_UNSET="${PHP56_MAKE_OPTIONS_SET}"
        PHP_EXT_MAKE_OPTIONS_SET="${PHP56_EXT_MAKE_OPTIONS_SET}"
        PHP_EXT_MAKE_OPTIONS_UNSET="${PHP56_EXT_MAKE_OPTIONS_UNSET}"
        ;;
    70) PORT_PHP="${PORT_PHP55}"
        PORT_PHP_EXT="${PORT_PHP70_EXT}"
        PHP_MAKE_OPTIONS_SET="${PHP70_MAKE_OPTIONS_SET}"
        PHP_MAKE_OPTIONS_UNSET="${PHP70_MAKE_OPTIONS_SET}"
        PHP_EXT_MAKE_OPTIONS_SET="${PHP70_EXT_MAKE_OPTIONS_SET}"
        PHP_EXT_MAKE_OPTIONS_UNSET="${PHP70_EXT_MAKE_OPTIONS_UNSET}"
        ;;
    *) ;;
  esac

  make -C "${PORT_PHP}" rmconfig
  make -C "${PORT_PHP}" config OPTIONS_SET="${PHP_MAKE_OPTIONS_SET} ${GLOBAL_MAKE_OPTIONS_SET}" OPTIONS_UNSET="${PHP_MAKE_OPTIONS_UNSET} ${GLOBAL_MAKE_OPTIONS_UNSET}"
  make -C "${PORT_PHP_EXT}" config OPTIONS_SET="${PHP_EXT_MAKE_OPTIONS_SET} ${GLOBAL_MAKE_OPTIONS_SET}" OPTIONS_UNSET="${PHP_EXT_MAKE_OPTIONS_UNSET} ${GLOBAL_MAKE_OPTIONS_UNSET}"
  make -C "${PORT_PHP}" reinstall clean
  # make -C "${PORT_PHP_EXT}" reinstall clean

  ## Replace default php-fpm.conf with DirectAdmin/CB2 version:
  cp -f "${PB_PATH}/configure/fpm/conf/php-fpm.conf.${PHP1_VERSION}" /usr/local/etc/php-fpm.conf

  if [ "${PHP_INI_TYPE}" = "production" ]; then
    cp -f /usr/local/etc/php.ini-production /usr/local/etc/php.ini
  elif [ "${PHP_INI_TYPE}" = "development" ]; then
    cp -f /usr/local/etc/php.ini-development /usr/local/etc/php.ini
  fi

  ## e.g. PHP1_VER="56"
  PHP1_PATH="/usr/local/php${PHP1_VERSION}"

  ## Create directories for DA compat:
  mkdir -p ${PHP1_PATH}
  mkdir -p ${PHP1_PATH}/bin
  mkdir -p ${PHP1_PATH}/etc
  mkdir -p ${PHP1_PATH}/include
  mkdir -p ${PHP1_PATH}/lib
  mkdir -p ${PHP1_PATH}/php
  mkdir -p ${PHP1_PATH}/sbin
  mkdir -p ${PHP1_PATH}/sockets
  mkdir -p ${PHP1_PATH}/var/log/
  mkdir -p ${PHP1_PATH}/var/run
  # mkdir -p ${PHP_PATH}/lib/php.conf.d/
  mkdir -p ${PHP1_PATH}/lib/php/

  ## Symlink for compat
  ln -s /usr/local/bin/php ${PHP1_PATH}/bin/php
  ln -s /usr/local/bin/php-cgi ${PHP1_PATH}/bin/php-cgi
  ln -s /usr/local/bin/php-config ${PHP1_PATH}/bin/php-config
  ln -s /usr/local/bin/phpize ${PHP1_PATH}/bin/phpize
  ln -s /usr/local/sbin/php-fpm ${PHP1_PATH}/sbin/php-fpm
  ln -s /var/log/php-fpm.log ${PHP1_PATH}/var/log/php-fpm.log
  ln -s /usr/local/include/php ${PHP1_PATH}/include

  ## php.conf.d: directory for additional PHP ini files loaded by FPM:
  ln -s /usr/local/etc/php ${PHP1_PATH}/lib/php.conf.d
  ln -s /usr/local/etc/php.ini ${PHP1_PATH}/lib/php.ini
  ln -s /usr/local/etc/php-fpm.conf ${PHP1_PATH}/etc/php-fpm.conf
  ln -s /usr/local/lib/php/build ${PHP1_PATH}/lib/php/build
  ## Note: extensions dir "20131226" might be different across PHP versions
  ln -s /usr/local/lib/php/20131226 ${PHP1_PATH}/lib/php/extensions

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
  setVal php_fpm_enable \"YES\" /etc/rc.conf
}

## Upgrade PHP and related components
php_upgrade() {
  pkg upgrade "$(pkg query %o | grep php${PHP1_VERSION})"

  #pkg query -i -x "%o %v" '(php)'
}


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

  ### Main Installation
  make -C "${PORT_PHPMYADMIN}" rmconfig
  make -C "${PORT_PHPMYADMIN}" config OPTIONS_SET="${PMA_MAKE_OPTIONS_SET} ${GLOBAL_MAKE_OPTIONS_SET}" OPTIONS_UNSET="${PMA_MAKE_OPTIONS_UNSET} ${GLOBAL_MAKE_OPTIONS_UNSET}"
  make -C "${PORT_PHPMYADMIN}" reinstall clean

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
    ${wget_with_options} -O "${PB_DIR}/patches/pma_auth_logging.patch" "${PB_MIRROR}/patches/pma_auth_logging.patch"
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
  return;
}

################################################################################################################################

## Apache Installation
apache_install() {

  ### Main Installation
  make -C "${PORT_APACHE24}" rmconfig
  make -C "${PORT_APACHE24}" config OPTIONS_SET="${APACHE24_MAKE_OPTIONS_SET} ${GLOBAL_MAKE_OPTIONS_SET} " OPTIONS_UNSET="${APACHE24_MAKE_OPTIONS_UNSET} ${GLOBAL_MAKE_OPTIONS_UNSET}"
  make -C "${PORT_APACHE24}" reinstall clean
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

  if [ -x /usr/local/bin/openssl ]; then
    /usr/local/bin/openssl req -x509 -newkey rsa:2048 -keyout ${APACHE_SSL_KEY} -out ${APACHE_SSL_CRT} -days 9999 -nodes -config ${PB_PATH}/custom/ap2/cert_config.txt
  else
    /usr/bin/openssl req -x509 -newkey rsa:2048 -keyout ${APACHE_SSL_KEY} -out ${APACHE_SSL_CRT} -days 9999 -nodes -config ${PB_PATH}/custom/ap2/cert_config.txt
  fi

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

  ## Copy over modified (custom) CB2 conf files to conf/:
  cp -rf ${PB_PATH}/custom/ap2/conf/ ${APACHE_PATH}/
  cp -f ${PB_PATH}/custom/ap2/conf/httpd.conf ${APACHE_PATH}/
  cp -f ${PB_PATH}/custom/ap2/conf/extra/httpd-mpm.conf ${APACHE_EXTRA_PATH}/httpd-mpm.conf

  ## Already done (default):
  ${PERL} -pi -e 's/^DefaultType/#DefaultType/' ${APACHE_PATH}/httpd.conf

  chmod 710 ${APACHE_PATH}

  ## Update directadmin.conf with new paths:
  setVal apacheconf ${APACHE_PATH}/httpd.conf ${DA_CONF}
  setVal apacheips ${APACHE_PATH}/ips.conf ${DA_CONF}
  setVal apachemimetypes ${APACHE_PATH}/mime.types ${DA_CONF}
  setVal apachecert ${APACHE_SSL_CRT} ${DA_CONF}
  setVal apachekey ${APACHE_SSL_KEY} ${DA_CONF}
  setVal apacheca ${APACHE_SSL_CA} ${DA_CONF}

  ## Rewrite Apache 2.4 configuration files
  ## cd /usr/local/directadmin/custombuild
  ## ./build rewrite_confs

  apache_rewrite_confs

  ## Update /boot/loader.conf:
  setVal accf_http_load \"YES\" /boot/loader.conf
  setVal accf_data_load \"YES\" /boot/loader.conf

  ## Update /etc/rc.conf
  setVal apache24_enable \"YES\" /etc/rc.conf
  setVal apache24_http_accept_enable \"YES\" /etc/rc.conf
}

################################################################################################################################

## Nginx Installation
nginx_install() {

  ## Main Installation
  make -C "${PORT_NGINX}" rmconfig
  make -C "${PORT_NGINX}" config OPTIONS_SET="${NGINX_MAKE_OPTIONS_SET}" OPTIONS_UNSET="${NGINX_MAKE_OPTIONS_UNSET}"
  make -C "${PORT_NGINX}" reinstall clean

  ## Nginx Pre-Installation Tasks

  ## Update directadmin.conf
  # nginxconf=/usr/local/etc/nginx/directadmin-vhosts.conf
  # nginxlogdir=/var/log/nginx/domains
  # nginxips=/usr/local/etc/nginx/directadmin-ips.conf
  # nginx_pid=/var/run/nginx.pid
  # nginx_cert=/usr/local/etc/nginx/ssl/server.crt
  # nginx_key=/usr/local/etc/nginx/ssl/server.key
  # nginx_ca=/usr/local/etc/nginx/ssl/server.ca

  setVal nginx_enable \"YES\" /etc/rc.conf

  return;
}

## Copied from CB2
addNginxToAccess() {
  # Check for nginx user in access group
  if grep -m1 -q "^access" /etc/group; then
    if ! grep -m1 "^access" /etc/group | grep -q nginx; then
      usermod -G access nginx
    fi
  fi
}

## Uninstall nginx
nginx_uninstall() {
  return;
}

################################################################################################################################

## ClamAV Installation Tasks
clamav_install() {

  ### Main Installation
  make -C "${PORT_CLAMAV}" rmconfig
  make -C "${PORT_CLAMAV}" config OPTIONS_SET="${CLAMAV_MAKE_OPTIONS_SET} ${GLOBAL_MAKE_OPTIONS_SET}" OPTIONS_UNSET="${CLAMAV_MAKE_OPTIONS_UNSET} ${GLOBAL_MAKE_OPTIONS_UNSET}"
  make -C "${PORT_CLAMAV}" reinstall clean

  ## Verify:
  if [ "${CLAMAV_EXIM_ENABLE}" = "YES" ]; then
    wget ${WGET_CONNECT_OPTIONS} -O /usr/local/etc/exim.clamav.load.conf ${PB_MIRROR}/exim/exim.clamav.load.conf
    wget ${WGET_CONNECT_OPTIONS} -O /usr/local/etc/exim.clamav.conf ${PB_MIRROR}/exim/exim.clamav.conf
  fi

  if [ "${CLAMD_CONF}" -eq 0 ]; then
    if [ ! -s "${CLAMD_CONF}" ] && [ -s /usr/local/etc/clamd.conf.sample ]; then
      cp -f /usr/local/etc/clamd.conf.sample "${CLAMD_CONF}"
    fi

    perl -pi -e 's|Example|#Example|' "${CLAMD_CONF}"
    perl -pi -e 's|#PidFile /var/run/clamd.pid|PidFile /var/run/clamd/clamd.pid|' "${CLAMD_CONF}"
    perl -pi -e 's|#TCPSocket 3310|TCPSocket 3310|' "${CLAMD_CONF}"
    perl -pi -e 's|#TCPAddr 127.0.0.1|TCPAddr 127.0.0.1|' "${CLAMD_CONF}"
    perl -pi -e 's|^LocalSocket|#LocalSocket|' "${CLAMD_CONF}"
  fi

  if [ "${FRESHCLAM_CONF}" -eq 0 ]; then
    if [ ! -s "${FRESHCLAM_CONF}" ] && [ -s /usr/local/etc/freshclam.conf.sample ]; then
      cp -f /usr/local/etc/freshclam.conf.sample "${FRESHCLAM_CONF}"
    fi

    perl -pi -e 's|Example|#Example|' "${FRESHCLAM_CONF}"
    perl -pi -e 's|#LogSyslog yes|LogSyslog yes|' "${FRESHCLAM_CONF}"
    perl -pi -e 's|#PidFile /var/run/freshclam.pid|PidFile /var/run/clamd/freshclam.pid|' "${FRESHCLAM_CONF}"
    perl -pi -e 's|#Checks 24|#Checks 24|' "${FRESHCLAM_CONF}"
    perl -pi -e 's|#NotifyClamd /path/to/clamd.conf|#NotifyClamd /etc/clamd.conf|' "${FRESHCLAM_CONF}"
  fi

  ## Verify:
  if [ "${CLAMAV_EXIM_ENABLE}" = "YES" ]; then
    perl -pi -e 's|#.include_if_exists /usr/local/etc/exim.clamav.load.conf|.include_if_exists /etc/exim.clamav.load.conf|' "${EXIM_CONF}"
    perl -pi -e 's|#.include_if_exists /usr/local/etc/exim.clamav.conf|.include_if_exists /etc/exim.clamav.conf|' "${EXIM_CONF}"
  fi

  setVal clamav_clamd_enable \"YES\" /etc/rc.conf
  setVal clamav_freshclam_enable \"YES\" /etc/rc.conf

  ${SERVICE} clamav-clamd start
  ${SERVICE} clamav-freshclam start

  if [ "${CLAMAV_EXIM_ENABLE}" = "YES" ]; then
    echo "Restarting Exim"
    ${SERVICE} exim restart
  fi

  return;
}

################################################################################################################################

## RoundCube Installation
roundcube_install() {

  ### Main Installation
  make -C "${PORT_ROUNDCUBE}" rmconfig
  make -C "${PORT_ROUNDCUBE}" config OPTIONS_SET="${ROUNDCUBE_MAKE_OPTIONS_SET} ${GLOBAL_MAKE_OPTIONS_SET}" OPTIONS_UNSET="${ROUNDCUBE_MAKE_OPTIONS_UNSET} ${GLOBAL_MAKE_OPTIONS_UNSET}"
  make -C "${PORT_ROUNDCUBE}" reinstall clean

  ### Post-Installation Tasks

  ## Clarifications
  # _CONF = RC's config.inc.php
  # _CNF  = MySQL settings
  # _PATH = path to RC

  ## CB2: verify_webapps_logrotate

  ## Fetch MySQL Settings from directadmin/conf/my.cnf
  get_sql_settings

  ## ROUNDCUBE_ALIAS_PATH=${WWW_DIR}/roundcube
  ## ROUNDCUBE_CONFIG_DB= custom config from CB2
  #ROUNDCUBE_PATH=${WWW_DIR}/roundcube

  ## Create & generate credentials for the database:
  ROUNDCUBE_DB=da_roundcube
  ROUNDCUBE_DB_USER=da_roundcube
  ROUNDCUBE_DB_PASS=$(random_pass 12)
  ROUNDCUBE_DES_KEY=$(random_pass 24)
  ROUNDCUBE_MY_CNF=${ROUNDCUBE_PATH}/config/my.cnf
  ROUNDCUBE_CONF_SAMPLE=${ROUNDCUBE_PATH}/config/config.inc.php.sample

  # if [ -e ${ROUNDCUBE_PATH} ]; then
  #     if [ -d ${ROUNDCUBE_PATH}/logs ]; then
  #         cp -fR ${ROUNDCUBE_PATH}/logs ${ROUNDCUBE_PATH} >/dev/null 2>&1
  #     fi
  #     if [ -d ${ROUNDCUBE_PATH}/temp ]; then
  #         cp -fR ${ROUNDCUBE_PATH}/temp ${ROUNDCUBE_PATH} >/dev/null 2>&1
  #     fi
  # fi

  ## Link it from a fake path:
  #/bin/rm -f ${ALIASPATH}
  #/bin/ln -sf roundcubemail-${ROUNDCUBE_VER} ${ALIASPATH}

  ## Set permissions:
  chown -h ${WEBAPPS_USER}:${WEBAPPS_USER} ${ROUNDCUBE_PATH}

  cd ${ROUNDCUBE_PATH} || exit

  #EDIT_CONFIG=config.inc.php
  # Use: ${ROUNDCUBE_CONF}
  #CONFIG_DIST=config.inc.php.sample
  # EDIT_DB=${EDIT_CONFIG}
  # DB_DIST=${CONFIG_DIST}

  ## Insert data to SQL DB and create database/user for RoundCube:
  if ! ${MYSQLSHOW} --defaults-extra-file=${DA_MYSQL_CNF} --host=${MYSQL_HOST} | grep -m1 -q ' da_roundcube '; then
    if [ -d "${ROUNDCUBE_PATH}/SQL" ]; then
      echo "Creating RoundCube SQL user and database."
      ${MYSQL} --defaults-extra-file=${DA_MYSQL_CNF} -e "CREATE DATABASE ${ROUNDCUBE_DB};" --host=${MYSQL_HOST} 2>&1
      ${MYSQL} --defaults-extra-file=${DA_MYSQL_CNF} -e "GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,ALTER,LOCK TABLES,INDEX ON ${ROUNDCUBE_DB}.* TO '${ROUNDCUBE_DB_USER}'@'${MYSQL_ACCESS_HOST}' IDENTIFIED BY '${ROUNDCUBE_DB_PASS}';" --host=${MYSQL_HOST} 2>&1

      if [ "${MYSQL_HOST}" != "localhost" ]; then
        grep '^access_host.*=' ${DA_MYSQL_CONF} | cut -d= -f2 | while IFS= read -r access_host_ip
        do
          ${MYSQL} --defaults-extra-file=${DA_MYSQL_CNF} -e "GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,ALTER,LOCK TABLES,INDEX ON ${ROUNDCUBE_DB}.* TO '${ROUNDCUBE_DB_USER}'@'${access_host_ip}' IDENTIFIED BY '${ROUNDCUBE_DB_PASS}';" --host=${MYSQL_HOST} 2>&1
        done

        # for access_host_ip in $(grep '^access_host.*=' ${DA_MYSQL_CONF} | cut -d= -f2); do {
        #   ${MYSQL} --defaults-extra-file=${DA_MYSQL_CNF} -e "GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,ALTER,LOCK TABLES,INDEX ON ${ROUNDCUBE_DB}.* TO '${ROUNDCUBE_DB_USER}'@'${access_host_ip}' IDENTIFIED BY '${ROUNDCUBE_DB_PASS}';" --host=${MYSQL_HOST} 2>&1
        # }; done
      fi

      ## Needed?
      rm -f ${ROUNDCUBE_MY_CNF}
      #verify_my_cnf ${ROUNDCUBE_MY_CNF} "${ROUNDCUBE_DB_USER}" "${ROUNDCUBE_DB_PASS}"

      ## Import RoundCube's initial.sql file to create the necessary database tables.
      ${MYSQL} --defaults-extra-file=${ROUNDCUBE_MY_CNF} -e "use ${ROUNDCUBE_DB}; source SQL/mysql.initial.sql;" --host=${MYSQL_HOST} 2>&1

      echo "Database created, ${ROUNDCUBE_DB_USER} password is ${ROUNDCUBE_DB_PASS}"
    else
      echo "Cannot find the SQL directory in ${ROUNDCUBE_PATH}"
      exit 0
    fi
  else
    ## RoundCube config & database already exists, so fetch existing values:
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

    #in case anyone uses it for backups
    rm -f ${ROUNDCUBE_MY_CNF}
    #verify_my_cnf ${ROUNDCUBE_MY_CNF} "${ROUNDCUBE_DB_USER}" "${ROUNDCUBE_DB_PASS}"
  fi

  # Cleanup config
  #rm -f ${ROUNDCUBE_CONF}

  ## Install the proper config (e.g. custom):
  if [ -d ../roundcube ]; then
    echo "Editing roundcube configuration..."

    cd ${ROUNDCUBE_PATH}/config || exit

    ## (not implemented) RoundCube Custom Configuration
    # if [ -e "${ROUNDCUBE_CONF_CUSTOM}" ]; then
    #   echo "Installing custom RoundCube Config: ${ROUNDCUBE_CONF_CUSTOM}"
    #  cp -f "${ROUNDCUBE_CONF_CUSTOM}" ${ROUNDCUBE_CONF}
    # fi

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
      if [ "${WEBAPPS_INBOX_PREFIX}" = "YES" ]; then
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
        #if [ "${WEBSERVER}" = "apache" ] || [ "${WEBSERVER}" = "litespeed" ] || [ "${WEBSERVER}" = "nginx_apache" ]; then
          if [ -s ${APACHE_MIME_TYPES} ]; then
            if grep -m1 -q 'application/java-archive' ${APACHE_MIME_TYPES}; then
              cp -f ${APACHE_MIME_TYPES} ${ROUNDCUBE_PATH}/config/mime.types
            fi
          fi
        #fi
      fi

      if [ ! -s "${ROUNDCUBE_PATH}/config/mime.types" ]; then
        ${WGET} "${WGET_CONNECT_OPTIONS}" -O mime.types http://svn.apache.org/repos/asf/httpd/httpd/trunk/docs/conf/mime.types 2> /dev/null
      fi

      echo "\$config['mime_types'] = '${ROUNDCUBE_PATH}/config/mime.types';" >> ${ROUNDCUBE_CONF}

      ## Password plugin
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
      if [ "${PIGEONHOLE_ENABLE}" = "YES" ]; then
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
      cp -Rp ${ROUNDCUBE_PLUGINS}/* ${ROUNDCUBE_PATH}/plugins
    fi

    if [ -d "${ROUNDCUBE_SKINS}" ]; then
      echo "Copying files from ${ROUNDCUBE_SKINS} to ${ROUNDCUBE_PATH}/skins"
      cp -Rp ${ROUNDCUBE_SKINS}/* ${ROUNDCUBE_PATH}/skins
    fi

    if [ -d ${ROUNDCUBE_PROGRAM} ]; then
      echo "Copying files from ${ROUNDCUBE_PROGRAM} to ${ROUNDCUBE_PATH}/program"
      cp -Rp ${ROUNDCUBE_PROGRAM}/* ${ROUNDCUBE_PATH}/program
    fi

    if [ -e ${ROUNDCUBE_HTACCESS} ]; then
      echo "Copying .htaccess file from ${ROUNDCUBE_HTACCESS} to ${ROUNDCUBE_PATH}/.htaccess"
      cp -pf ${ROUNDCUBE_HTACCESS} ${ROUNDCUBE_PATH}/.htaccess
    fi

    #echo "Roundcube ${ROUNDCUBE_VER} has been installed successfully."
  fi

  #systems with "system()" in disable_functions need to use no php.ini:
  if [ "$(have_php_system)" = "0" ]; then
    ${PERL} -pi -e 's#^\#\!/usr/bin/env php#\#\!/usr/local/bin/php \-n#' "${ROUNDCUBE_PATH}/bin/update.sh"
  fi

  ## Systems with suhosin cannot have PHP memory_limit set to -1. Must prevent suhosin from loading for RoundCube's .sh scripts
  if [ "${SUHOSIN_ENABLE}" = "YES" ]; then
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

  ## Verify this (770 compatible with FPM?):
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
  if [ ${PHP1_MODE} = "FPM" ]; then
    chmod 755 ${WWW_DIR}/tmp
  else
    chmod 777 ${WWW_DIR}/tmp
  fi

  ## Temp path: /usr/local/www/webmail/tmp
  ## Create webmail/tmp directory:
  ## Verify whether 770 will work or not (750 for FPM?)
  mkdir -p ${WWW_DIR}/webmail/tmp
  chmod -R 770 ${WWW_DIR}/webmail/tmp;
  chown -R ${WEBAPPS_USER}:${WEBAPPS_GROUP} ${WWW_DIR}/webmail
  chown -R ${APACHE_USER}:${WEBAPPS_GROUP} ${WWW_DIR}/webmail/tmp;
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

  # if [ "${PHP1_MODE_OPT}" = "mod_php" ]; then
  #     WEBAPPS_INI=/usr/local/lib/php.conf.d/50-webapps.ini
  #     mkdir -p /usr/local/lib/php.conf.d
  # else
  #     WEBAPPS_INI=/usr/local/php${PHP1_SHORTRELEASE}/lib/php.conf.d/50-webapps.ini
  #     mkdir -p /usr/local/php${PHP1_SHORTRELEASE}/lib/php.conf.d
  # fi

  ## Copy custom/ file (not implemented)
  if [ -e "${PHP_CUSTOM_PHP_CONF_D_INI_PATH}/50-webapps.ini" ]; then
    echo "Using custom ${PHP_CUSTOM_PHP_CONF_D_INI_PATH}/50-webapps.ini for ${PHP_INI_WEBAPPS}"
    cp -f "${PHP_CUSTOM_PHP_CONF_D_INI_PATH}/50-webapps.ini" ${PHP_INI_WEBAPPS}
  else
    {
      echo "[PATH=${WWW_DIR}]";
      echo "session.save_path=${WWW_TMP_DIR}";
      echo "upload_tmp_dir=${WWW_TMP_DIR}";
      echo "disable_functions=exec,system,passthru,shell_exec,escapeshellarg,escapeshellcmd,proc_close,proc_open,dl,popen,show_source,posix_kill,posix_mkfifo,posix_getpwuid,posix_setpgid,posix_setsid,posix_setuid,posix_setgid,posix_seteuid,posix_setegid,posix_uname";
    } >> ${PHP_INI_WEBAPPS}
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

  if [ "${WEBSERVER}" = "apache" ]; then

    APACHE_HOST_CONF=${APACHE_EXTRA_PATH}/httpd-hostname.conf

    ## Set this for now since PB only supports 1 instance of PHP.
    #PHP1_MODE_OPT="php-fpm"
    #PHP1_MODE="FPM"
    #PHP1_VERSION="56"

    ## Copy custom/ file
    ## APACHE_HOST_CONF_CUSTOM
    if [ -e "${PB_PATH}/custom/ap2/conf/extra/httpd-hostname.conf" ]; then
      cp -pf "${PB_PATH}/custom/ap2/conf/extra/httpd-hostname.conf" ${APACHE_HOST_CONF}
    else
      echo '' > ${APACHE_HOST_CONF}

      # if [ "${HAVE_FPM_CGI}" = "yes" ]; then
      #   echo 'SetEnvIfNoCase ^Authorization$ "(.+)" HTTP_AUTHORIZATION=$1' >> ${APACHE_HOST_CONF}
      # fi

      echo "<Directory ${WWW_DIR}>" >> ${APACHE_HOST_CONF}

      if [ "${PHP1_MODE}" = "FPM" ]; then
        {
          echo '<FilesMatch "\.(inc|php|php3|php4|php44|php5|php52|php53|php54|php55|php56|php70|php6|phtml|phps)$">';
          echo "AddHandler \"proxy:unix:/usr/local/php${PHP1_VERSION}/sockets/webapps.sock|fcgi://localhost\" .inc .php .php5 .php${PHP1_VERSION} .phtml";
          echo "</FilesMatch>";
        } >> ${APACHE_HOST_CONF}
      fi

      {
        echo "  Options +SymLinksIfOwnerMatch +IncludesNoExec";
        echo "  AllowOverride AuthConfig FileInfo Indexes Limit Options=Includes,IncludesNOEXEC,Indexes,ExecCGI,MultiViews,SymLinksIfOwnerMatch,None";
        echo "";
        echo "  Order Allow,Deny";
        echo "  Allow from all";
        echo "  <IfModule mod_suphp.c>";
        echo "      suPHP_Engine On";
        echo "      suPHP_UserGroup ${WEBAPPS_USER} ${WEBAPPS_GROUP}";
        echo "  </IfModule>";
      } >> ${APACHE_HOST_CONF}

      ## Unsupported:
      # echo '    <IfModule mod_ruid2.c>'                 >> ${APACHE_HOST_CONF}
      # echo '        RUidGid webapps webapps'            >> ${APACHE_HOST_CONF}
      # echo '    </IfModule>'                            >> ${APACHE_HOST_CONF}
      # echo '    <IfModule mod_lsapi.c>'                 >> ${APACHE_HOST_CONF}
      # echo '        lsapi_user_group webapps webapps'   >> ${APACHE_HOST_CONF}
      # echo '    </IfModule>'                            >> ${APACHE_HOST_CONF}

      verify_webapps_tmp

      # WEBAPPS_FCGID_DIR=/var/www/fcgid
      SUEXEC_PER_DIR="0"

      if [ -s /usr/local/sbin/suexec ]; then
        SUEXEC_PER_DIR=$(/usr/local/sbin/suexec -V 2>&1 | grep -c 'AP_PER_DIR')
      fi

      # if [ "${PHP1_MODE}" = "fastcgi" ]; then
      #   echo '  <IfModule mod_fcgid.c>' >> ${APACHE_HOST_CONF}
      #   echo "      FcgidWrapper /usr/local/safe-bin/fcgid${PHP1_VERSION}.sh .php" >> ${APACHE_HOST_CONF}
      #   if [ "${SUEXEC_PER_DIR}" -gt 0 ]; then
      #     echo '    SuexecUserGroup webapps webapps' >> ${APACHE_HOST_CONF}
      #   fi
      #   echo '      <FilesMatch "\.(inc|php|php3|php4|php44|php5|php52|php53|php54|php55|php56|php70|php6|phtml|phps)$">' >> ${APACHE_HOST_CONF}
      #   echo '          Options +ExecCGI' >> ${APACHE_HOST_CONF}
      #   echo '          AddHandler fcgid-script .php' >> ${APACHE_HOST_CONF}
      #   echo '      </FilesMatch>' >> ${APACHE_HOST_CONF}
      #   echo '  </IfModule>' >> ${APACHE_HOST_CONF}
      # fi

      # if [ "${PHP2_MODE}" = "fastcgi" ] && [ "${PHP2_RELEASE}" != "no" ]; then
      #   echo '  <IfModule mod_fcgid.c>' >> ${APACHE_HOST_CONF}
      #   echo "      FcgidWrapper /usr/local/safe-bin/fcgid${PHP2_SHORTRELEASE}.sh .php${PHP2_SHORTRELEASE}" >> ${APACHE_HOST_CONF}
      #   if [ "${SUEXEC_PER_DIR}" -gt 0 ]; then
      #   echo '      SuexecUserGroup webapps webapps' >> ${APACHE_HOST_CONF}
      #   fi
      #   echo "   <FilesMatch \"\.php${PHP2_SHORTRELEASE}\$\">" >> ${APACHE_HOST_CONF}
      #   echo '          Options +ExecCGI' >> ${APACHE_HOST_CONF}
      #   echo "          AddHandler fcgid-script .php${PHP2_SHORTRELEASE}" >> ${APACHE_HOST_CONF}
      #   echo '      </FilesMatch>' >> ${APACHE_HOST_CONF}
      #   echo '  </IfModule>' >> ${APACHE_HOST_CONF}
      # fi

      echo "</Directory>" >> ${APACHE_HOST_CONF}
    fi
  fi
}

################################################################################################################################

## Rewrite Confs (copied from CB2)
rewrite_confs() {

  if [ "${WEBSERVER}" = "apache" ] || [ "${WEBSERVER}" = "nginx_apache" ]; then

    # Copy the new configs
    cp -rf "${PB_PATH}/configure/ap2/" "${APACHE_PATH}"
    cp -f "${PB_PATH}/configure/ap2/httpd.conf" "${APACHE_CONF}"
    cp -f "${PB_PATH}/configure/ap2/extra/httpd-mpm.conf" "${APACHE_EXTRA_PATH}/httpd-mpm.conf"

    ${PERL} -pi -e 's/^DefaultType/#DefaultType/' "${APACHE_CONF}"

    HDC=${APACHE_EXTRA_PATH}/httpd-directories-old.conf

    ln -sf $HDC "${APACHE_EXTRA_PATH}/httpd-directories.conf"

    apache_rewrite_confs

    ## Custom configurations
    if [ "${APCUSTOMCONFDIR}" != "0" ]; then
      cp -rf "${APCUSTOMCONFDIR}" "${APACHE_PATH}"
    fi

    chmod 710 "${APACHE_EXTRA_PATH}"

    ## Swap the |WEBAPPS_PHP_RELEASE| token.
    if [ "${PHP1_MODE}" = "FPM" ] || [ "${PHP2_MODE}" = "FPM" ]; then
      PHPV=""

      if [ "${PHP1_MODE}" = "FPM" ]; then
        PHPV=$(${PERL} -e "print ${PHP1_VERSION}")
      elif [ "${PHP2_VERSION}" != "" ]; then
        PHPV=$(${PERL} -e "print ${PHP2_VERSION}")
      fi

      if [ "${PHPV}" != "" ]; then
        ${PERL} -pi -e "s/\|WEBAPPS_PHP_RELEASE\|/${PHPV}/" "${APACHE_EXTRA_PATH}/${HDC}"
      fi
    fi

    ## Todo:
    verify_server_ca

    # Verify we have the correct apache_ver
    if [ "$(grep -m1 -c apache_ver=2.0 ${DA_CONF_TEMPLATE})" -eq "0" ]; then
      echo "apache_ver=2.0" >> ${DA_CONF_TEMPLATE}
    elif [ "$(grep -m1 -c apache_ver= ${DA_CONF_TEMPLATE})" -ne "0" ]; then
      ${PERL} -pi -e 's/`grep apache_ver= ${DA_CONF_TEMPLATE}`/apache_ver=2.0/' ${DA_CONF_TEMPLATE}
    fi

    if [ "$(grep -m1 -c apache_ver=2.0 ${DA_CONF})" -eq "0" ]; then
      echo "apache_ver=2.0" >> ${DA_CONF}
      echo "action=rewrite&value=httpd" >> "${DA_TASK_QUEUE}"
    elif [ "$(grep -m1 -c apache_ver= ${DA_CONF})" -ne "0" ]; then
      ${PERL} -pi -e 's/`grep apache_ver= ${DA_CONF}`/apache_ver=2.0/' ${DA_CONF}
      echo "action=rewrite&value=httpd" >> "${DA_TASK_QUEUE}"
    fi

    ## Todo:
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
      cd "${CWD}/httpd-${APACHE2_VER}" || exit
    fi


    if [ ! -e "${APACHE_SSL_KEY}" ] || [ ! -e "${APACHE_SSL_CRT}" ]; then
      ## Generate the SSL certificate and key:
      if [ -x /usr/local/bin/openssl ]; then
        /usr/local/bin/openssl req -x509 -newkey rsa:2048 -keyout ${APACHE_SSL_KEY} -out ${APACHE_SSL_CRT} -days 9999 -nodes -config ${PB_PATH}/configure/ap2/cert_config.txt
      else
        /usr/bin/openssl req -x509 -newkey rsa:2048 -keyout ${APACHE_SSL_KEY} -out ${APACHE_SSL_CRT} -days 9999 -nodes -config ${PB_PATH}/configure/ap2/cert_config.txt
      fi

      ## /usr/bin/openssl req -x509 -newkey rsa:2048 -keyout "${APACHE_SSL_KEY}" -out "${APACHE_SSL_CRT}" -days 9999 -nodes -config ./${APCERTCONF}

      chmod 600 "${APACHE_SSL_CRT}"
      chmod 600 "${APACHE_SSL_KEY}"
    fi

    ## Todo:
    doApacheCheck

    PHPMODULES=${APACHE_EXTRA_PATH}/httpd-phpmodules.conf

    echo -n "" > "${APACHE_EXTRA_PATH}/httpd-nginx.conf"

    echo -n "" > "${PHPMODULES}"

    if [ "${HAVE_SUPHP_CGI}" = "yes" ]; then
      ${PERL} -pi -e 's|^LoadModule suphp_module|#LoadModule suphp_module|' "${APACHE_CONF}"
      echo "LoadModule  suphp_module    ${APACHE_LIB_PATH}/mod_suphp.so" >> "${PHPMODULES}"
    fi

    ## mod_security (not done):
    if [ "${MODSECURITY_ENABLE}" = "yes" ] && [ "${WEBSERVER}" = "apache" ]; then
      ${PERL} -pi -e 's|^LoadModule security2_module|#LoadModule security2_module|' "${APACHE_CONF}"
      echo "Include ${APACHE_EXTRA_PATH}/httpd-modsecurity.conf" >> "${PHPMODULES}"
      cp -pf "${MODSECURITY_APACHE_INCLUDE}" ${APACHE_EXTRA_PATH}/httpd-modsecurity.conf
      doModSecurityRules norestart
    fi

    ## HTScanner (not done):
    if [ "${HTSCANNER_OPT}" = "yes" ]; then
      if [ "${HAVE_FCGID}" = "yes" ] || [ "${HAVE_FPM_CGI}" = "yes" ] || [ "${HAVE_SUPHP_CGI}" = "yes" ]; then
        ${PERL} -pi -e 's|^LoadModule htscanner_module|#LoadModule htscanner_module|' "${APACHE_CONF}"
        echo "LoadModule  htscanner_module    ${APACHE_LIB_PATH}/mod_htscanner2.so" >> "${PHPMODULES}"
      fi
    fi

    ## Example: /usr/local/libexec/apache24/mod_mpm_event.so

    ## Verfiy:
    if ! grep -m1 -q "${APACHE_LIB_PATH}/mod_mpm_" "${PHPMODULES}"; then
      # Use event MPM for php-fpm and prefork for mod_php
      if [ "${APACHE_MPM}" = "AUTO" ]; then
        if [ "${HAVE_CLI}" = "no" ]; then
          # Add to httpd-phpmodules.conf
          echo "LoadModule mpm_event_module ${APACHE_LIB_PATH}/mod_mpm_event.so" >> "${PHPMODULES}"
        else
          # Add to httpd-phpmodules.conf
          echo "LoadModule mpm_prefork_module ${APACHE_LIB_PATH}/mod_mpm_prefork.so" >> "${PHPMODULES}"
        fi
      elif [ "${APACHE_MPM}" = "EVENT" ]; then
        echo "LoadModule mpm_event_module ${APACHE_LIB_PATH}/mod_mpm_event.so" >> "${PHPMODULES}"
      elif [ "${APACHE_MPM}" = "WORKER" ]; then
        echo "LoadModule mpm_worker_module ${APACHE_LIB_PATH}/mod_mpm_worker.so" >> "${PHPMODULES}"
      else
        echo "LoadModule mpm_prefork_module ${APACHE_LIB_PATH}/mod_mpm_prefork.so" >> "${PHPMODULES}"
      fi
    fi

    # ${PERL} -pi -e 's/^LoadModule php4/\#LoadModule php4/' "${APACHE_CONF}"
    ${PERL} -pi -e 's/^LoadModule php5/\#LoadModule php5/' "${APACHE_CONF}"
    ${PERL} -pi -e 's/^LoadModule php7/\#LoadModule php7/' "${APACHE_CONF}"

    # Add correct php module to httpd-phpmodules.conf
    if [ "${PHP1_MODE}" = "MODPHP" ]; then
      if [ "${PHP1_VERSION}" = "70" ]; then
        echo "LoadModule  php7_module   ${APACHE_LIB_PATH}/libphp7.so" >> "${PHPMODULES}"
      else
        echo "LoadModule  php5_module   ${APACHE_LIB_PATH}/libphp5.so" >> "${PHPMODULES}"
      fi
    fi
    if [ "${PHP2_MODE}" = "mod_php" ] && [ "${PHP2_VERSION}" != "" ]; then
      if [ "${PHP2_VERSION}" = "70" ]; then
        echo "LoadModule    php7_module             ${APACHE_LIB_PATH}/libphp7.so" >> "${PHPMODULES}"
      else
        echo "LoadModule    php5_module             ${APACHE_LIB_PATH}/libphp5.so" >> "${PHPMODULES}"
      fi
    fi

    # if [ "${HAVE_FCGID}" = "yes" ]; then
    #   if [ -e ${PHPMODULES} ]; then
    #     if ! grep -m1 -c 'fcgid_module' ${PHPMODULES}; then
    #       ${PERL} -pi -e 's|^LoadModule  fcgid_module|#LoadModule  fcgid_module|' /etc/httpd/conf/httpd.conf
    #       echo "LoadModule fcgid_module ${APACHE_LIB_PATH}/mod_fcgid.so" >> ${PHPMODULES}
    #     fi
    #     if ! grep -m1 -c 'httpd-fcgid.conf' ${PHPMODULES}; then
    #       echo "Include ${APACHE_EXTRA_PATH}/httpd-fcgid.conf" >> ${PHPMODULES}
    #     fi
    #   fi

    #   if [ ! -d /usr/local/safe-bin ]; then
    #     mkdir -p /usr/local/safe-bin
    #     chmod 511 /usr/local/safe-bin
    #     chown apache:apache /usr/local/safe-bin
    #   fi

    #   for php_shortrelease in `echo ${PHP1_SHORTRELEASE_SET}`; do
    #     EVAL_CHECK_VAR=HAVE_FCGID${php_shortrelease}
    #     if [ "$(eval_var ${EVAL_CHECK_VAR})" = "yes" ]; then
    #       cp -f ${CWD}/configure/fastcgi/fcgid${php_shortrelease}.sh /usr/local/safe-bin/fcgid${php_shortrelease}.sh
    #       if [ -e ${CWD}/custom/fastcgi/fcgid${php_shortrelease}.sh ]; then
    #         cp -f ${CWD}/custom/fastcgi/fcgid${php_shortrelease}.sh /usr/local/safe-bin/fcgid${php_shortrelease}.sh
    #       fi
    #       chown apache:apache /usr/local/safe-bin/fcgid${php_shortrelease}.sh
    #       chmod 555 /usr/local/safe-bin/fcgid${php_shortrelease}.sh
    #     fi
    #   done
    # fi

    if [ "${HAVE_SUPHP_CGI}" = "yes" ]; then
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
    # if [ "${CLOUDLINUX_OPT}" = "no" ] || [ "${PHP1_MODE_OPT}" != "lsphp" ]; then
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

    if [ "${WEBSERVER}" = "apache" ] || [ "${WEBSERVER}" = "nginx_apache" ]; then
      echo "Restarting Apache"
      ${SERVICE} apachectl restart
    fi
  fi

  ## Nginx:

  if [ "${WEBSERVER}" = "nginx" ] || [ "${WEBSERVER}" = "nginx_apache" ]; then
    #copy the new configs
    cp -rf ${NGINXCONFDIR}/* "${NGINX_CONF}"

    for php_shortrelease in $(echo ${PHP1_SHORTRELEASE_SET}); do
      ${PERL} -pi -e "s|/usr/local/php${php_shortrelease}/sockets/webapps.sock|/usr/local/php${PHP1_SHORTRELEASE}/sockets/webapps.sock|" ${NGINXCONF}/nginx.conf
    done

    do_rewrite_nginx_webapps
    verify _server_ca
    ensure_dhparam "${NGINX_CONF}/ssl.crt/dhparams.pem"

    if [ "${MODSECURITY_OPT}" = "yes" ]; then
      doModSecurityRules norestart
    fi

    #rewrite ips.conf
    echo "action=rewrite&value=nginx" >> "${TASK_QUEUE}"
    echo "action=rewrite&value=ips" >> "${TASK_QUEUE}"

    run_dataskq

    #add all the Include lines if they do not exist
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
      cp -rf ${NGINXCUSTOMCONFDIR}/* "${NGINXCONF}/"
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
    if [ "${USERDIR_ACCESS_OPT}" = "no" ]; then
      ${PERL} -pi -e 's| include /etc/nginx/nginx-userdir.conf;| #include /etc/nginx/nginx-userdir.conf;|' /etc/nginx/nginx-vhosts.conf
    else
      ${PERL} -pi -e 's| #include /etc/nginx/nginx-userdir.conf;| include /etc/nginx/nginx-userdir.conf;|' /etc/nginx/nginx-vhosts.conf
    fi

    doPhpConf

    echo "Restarting nginx."
    # /usr/sbin/nginx -s stop >/dev/null 2>&1
    # control_service nginx start
    service nginx restart
  fi

  if [ "${WEBSERVER}" = "nginx_apache" ]; then
    setVal nginx 0 ${DACONF_TEMPLATE_FILE}
    setVal nginx 0 ${DACONF_FILE}
    setVal nginx_proxy 1 ${DACONF_TEMPLATE_FILE}
    setVal nginx_proxy 1 ${DACONF_FILE}
  fi

  verify_webapps_tmp

  directadmin_restart


}
################################################################################################################################

## Run DirectAdmin Task Query (copied from CB2)
run_dataskq() {
  ## $1 = argument (e.g. "d" for debug)

  DATASKQ_OPT=$1
  if [ -s "${DA_CONF}" ]; then
    /usr/local/directadmin/dataskq "${DATASKQ_OPT}" --custombuild
  fi
}

################################################################################################################################

## Rewrite directadmin-vhosts.conf (copied from CB2: doVhosts)
rewrite_vhosts() {
  PATHNAME=${APACHE_EXTRA_PATH}

  if [ "${WEBSERVER}" = "nginx" ]; then
    PATHNAME="${NGINXCONF}"
  fi

  if [ ! -d "${PATHNAME}" ]; then
    mkdir -p "${PATHNAME}"
  fi

  echo -n '' > ${APACHE_EXTRA_PATH}/directadmin-vhosts.conf

  if [ "${WEBSERVER}" = "nginx" ]; then
    for i in $(ls /usr/local/directadmin/data/users/*/nginx.conf); do
      echo "include $i;" >> ${APACHE_EXTRA_PATH}/directadmin-vhosts.conf
    done
  elif [ "${WEBSERVER}" = "apache" ]; then
    for i in $(ls /usr/local/directadmin/data/users/*/httpd.conf); do
      echo "Include $i" >> ${APACHE_EXTRA_PATH}/directadmin-vhosts.conf
    done
  elif [ "${WEBSERVER}" = "nginx_apache" ]; then
    echo -n '' > ${NGINXCONF}/directadmin-vhosts.conf
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
  pkgi "${PORT_SUHOSIN}"

  if [ ${PHP_SUHOSIN_UPLOADSCAN} = "YES" ] && [ ! -e /usr/local/bin/clamdscan ]; then
    if [ "${CLAMAV_OPT}" = "no" ]; then
      echo "Cannot install suhosin with PHP upload scan using ClamAV, because /usr/local/bin/clamdscan does not exist on the system and clamav=no is set in the options.conf file."
      exit
    fi

    clamav_install
  fi
}

################################################################################################################################

## Tokenize the IP (copied from CB2)
tokenize_IP() {
  TOKENFILE_APACHE=${APACHE_EXTRA_PATH}/httpd-vhosts.conf

  TOKENFILE_NGINX=${NGINXCONF}/nginx.conf
  if [ -e ${TOKENFILE_NGINX} ]; then
    if grep -q -m1 'nginx-vhosts\.conf' ${TOKENFILE_NGINX}; then
      TOKENFILE_NGINX=${NGINXCONF}/nginx-vhosts.conf
    fi
  fi

  TOKENFILE_NGINX_USERDIR=${NGINXCONF}/nginx-userdir.conf

  HOSTNAME=$(hostname)
  IP="$(grep -r -l -m1 '^status=server$' /usr/local/directadmin/data/admin/ips | cut -d/ -f8)"
  if [ "${IP}" = "" ]; then
    IP="$(grep -m1 ${HOSTNAME} /etc/hosts | awk '{print $1}')"
    if [ "${IP}" = "" ]; then
      echo "Unable to detect your server IP in /etc/hosts. Please enter it: "
      read IP
    fi
  fi
  if [ "${IP}" = "" ]; then
    echo "Unable to detect your server IP. Exiting..."
    do_exit 0
  fi

  if [ "$(echo ${IP} | grep -m1 -c ':')" -gt 0 ]; then
    IP="[${IP}]"
  fi

  echo "Using $IP for your server IP"

  LAN_IP=$(getDA_Opt lan_ip "")

  if [ "${WEBSERVER}" = "apache" ] || [ "${WEBSERVER}" = "litespeed" ] || [ "${WEBSERVER}" = "nginx_apache" ]; then
    if [ -e ${TOKENFILE_APACHE} ]; then
      if [ "$(grep -m1 -c '|IP|' ${TOKENFILE_APACHE})" -gt "0" ]; then
        STR="perl -pi -e 's/\|IP\|/$IP/' ${TOKENFILE_APACHE}"
        eval "${STR}"
      fi
    fi
  fi

  if [ "${WEBSERVER}" = "nginx" ] || [ "${WEBSERVER}" = "nginx_apache" ]; then
    if [ -e "${TOKENFILE_NGINX}" ]; then
      if [ "$(grep -m1 -c '|IP|' ${TOKENFILE_NGINX})" -gt "0" ]; then
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
      if [ "$(grep -m1 -c '|IP|' ${TOKENFILE_NGINX_USERDIR})" -gt "0" ]; then
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

  if [ "${WEBSERVER}" = "apache" ] || [ "${WEBSERVER}" = "litespeed" ]; then
    if [ -e ${TOKENFILE_APACHE} ]; then
      if [ "$(grep -m1 -c '|PORT_80|' ${TOKENFILE_APACHE})" -gt "0" ]; then
        STR="perl -pi -e \"s/\|PORT_80\|/${PORT_80}/\" ${TOKENFILE_APACHE}"
        eval "${STR}"
      else
        perl -pi -e "s/:${PORT_8080}\>/:${PORT_80}\>/" ${TOKENFILE_APACHE}
        perl -pi -e "s/^Listen ${PORT_8080}$/Listen ${PORT_80}/" ${TOKENFILE_APACHE}
      fi
      if [ "$(grep -m1 -c '|PORT_443|' ${TOKENFILE_APACHE})" -gt "0" ]; then
        STR="perl -pi -e \"s/\|PORT_443\|/${PORT_443}/\" ${TOKENFILE_APACHE}"
        eval "${STR}"
      else
        perl -pi -e "s/:${PORT_8081}\>/:${PORT_443}\>/" ${TOKENFILE_APACHE}
        perl -pi -e "s/^Listen ${PORT_8081}$/Listen ${PORT_443}/" ${TOKENFILE_APACHE}
      fi

      SSLFILE=${APACHE_EXTRA_PATH}/httpd-ssl.conf
      STR="perl -pi -e \"s/\|PORT_443\|/${PORT_443}/\" ${SSLFILE}"
      eval "${STR}"
      perl -pi -e "s/:${PORT_8081}\>/:${PORT_443}\>/" ${SSLFILE}
      perl -pi -e "s/^Listen ${PORT_8081}$/Listen ${PORT_443}/" ${SSLFILE}

      perl -pi -e "s/:${PORT_8080}\>/:${PORT_80}\>/" ${HTTPD_CONF}
      perl -pi -e "s/^Listen ${PORT_8080}$/Listen ${PORT_80}/" ${HTTPD_CONF}
    fi
  fi

  if [ "${WEBSERVER}" = "nginx" ]; then
    if [ -e "${TOKENFILE_NGINX}" ]; then
      if [ "$(grep -m1 -c '|PORT_80|' ${TOKENFILE_NGINX})" -gt "0" ]; then
        STR="perl -pi -e \"s/\|PORT_80\|/${PORT_80}/\" ${TOKENFILE_NGINX}"
        eval "${STR}"
      fi
      if [ "$(grep -m1 -c '|PORT_443|' ${TOKENFILE_NGINX})" -gt "0" ]; then
        STR="perl -pi -e \"s/\|PORT_443\|/${PORT_443}/\" ${TOKENFILE_NGINX}"
        eval "${STR}"
      fi
    fi

    if [ -e "${TOKENFILE_NGINX_USERDIR}" ]; then
      if [ "$(grep -m1 -c '|PORT_80|' ${TOKENFILE_NGINX_USERDIR})" -gt "0" ]; then
        STR="perl -pi -e \"s/\|PORT_80\|/${PORT_80}/\" ${TOKENFILE_NGINX_USERDIR}"
        eval "${STR}"
      fi
      if [ "$(grep -m1 -c '|PORT_443|' ${TOKENFILE_NGINX_USERDIR})" -gt "0" ]; then
        STR="perl -pi -e \"s/\|PORT_443\|/${PORT_443}/\" ${TOKENFILE_NGINX_USERDIR}"
        eval "${STR}"
      fi
    fi
  fi

  if [ "${WEBSERVER}" = "nginx_apache" ]; then
    if [ -e "${TOKENFILE_NGINX}" ]; then
      if [ "$(grep -m1 -c '|PORT_80|' ${TOKENFILE_NGINX})" -gt "0" ]; then
        STR="perl -pi -e \"s/\|PORT_80\|/${PORT_80}/\" ${TOKENFILE_NGINX}"
        eval "${STR}"
      fi

      if [ "$(grep -m1 -c '|PORT_443|' ${TOKENFILE_NGINX})" -gt "0" ]; then
        STR="perl -pi -e \"s/\|PORT_443\|/${PORT_443}/\" ${TOKENFILE_NGINX}"
        eval "${STR}"
      fi

      if [ "`grep -m1 -c '|PORT_8080|' ${TOKENFILE_NGINX}`" -gt "0" ]; then
        STR="perl -pi -e \"s/\|PORT_8080\|/${PORT_8080}/\" ${TOKENFILE_NGINX}"
        eval "${STR}"
      fi

      if [ "`grep -m1 -c '|PORT_8081|' ${TOKENFILE_NGINX}`" -gt "0" ]; then
        STR="perl -pi -e \"s/\|PORT_8081\|/${PORT_8081}/\" ${TOKENFILE_NGINX}"
        eval "${STR}"
      fi
    fi

    if [ -e ${TOKENFILE_NGINX_USERDIR} ]; then
      if [ "`grep -m1 -c '|PORT_80|' ${TOKENFILE_NGINX_USERDIR}`" -gt "0" ]; then
        STR="perl -pi -e \"s/\|PORT_80\|/${PORT_80}/\" ${TOKENFILE_NGINX_USERDIR}"
        eval "${STR}"
      fi

      if [ "`grep -m1 -c '|PORT_443|' ${TOKENFILE_NGINX_USERDIR}`" -gt "0" ]; then
        STR="perl -pi -e \"s/\|PORT_443\|/${PORT_443}/\" ${TOKENFILE_NGINX_USERDIR}"
        eval "${STR}"
      fi

      if [ "`grep -m1 -c '|PORT_8080|' ${TOKENFILE_NGINX_USERDIR}`" -gt "0" ]; then
        STR="perl -pi -e \"s/\|PORT_8080\|/${PORT_8080}/\" ${TOKENFILE_NGINX_USERDIR}"
        eval "${STR}"
      fi

      if [ "`grep -m1 -c '|PORT_8081|' ${TOKENFILE_NGINX_USERDIR}`" -gt "0" ]; then
        STR="perl -pi -e \"s/\|PORT_8081\|/${PORT_8081}/\" ${TOKENFILE_NGINX_USERDIR}"
        eval "${STR}"
      fi
    fi

    if [ -e ${TOKENFILE_APACHE} ]; then
      if [ "`grep -m1 -c '|PORT_80|' ${TOKENFILE_APACHE}`" -gt "0" ]; then
        STR="perl -pi -e \"s/\|PORT_80\|/${PORT_8080}/\" ${TOKENFILE_APACHE}"
        eval "${STR}"
      else
        perl -pi -e "s/:${PORT_80}\>/:${PORT_8080}\>/" ${TOKENFILE_APACHE}
      fi

      if [ "`grep -m1 -c '|PORT_443|' ${TOKENFILE_APACHE}`" -gt "0" ]; then
        STR="perl -pi -e \"s/\|PORT_443\|/${PORT_8081}/\" ${TOKENFILE_APACHE}"
        eval "${STR}"
      else
        perl -pi -e "s/:${PORT_443}\>/:${PORT_8081}\>/" ${TOKENFILE_APACHE}
      fi

      if [ "`grep -m1 -c "^Listen ${PORT_80}$" ${HTTPD_CONF}`" -gt 0 ]; then
        STR="perl -pi -e \"s/^Listen ${PORT_80}$/Listen ${PORT_8080}/\" ${HTTPD_CONF}"
        eval "${STR}"
      else
        perl -pi -e "s/:${PORT_80}\>/:${PORT_8080}\>/" ${HTTPD_CONF}
      fi

      SSLFILE=${APACHE_EXTRA_PATH}/httpd-ssl.conf
      STR="perl -pi -e \"s/\|PORT_443\|/${PORT_8081}/\" ${SSLFILE}"
      eval "${STR}"
      perl -pi -e "s/:${PORT_443}\>/:${PORT_8081}\>/" ${SSLFILE}
      perl -pi -e "s/^Listen ${PORT_443}$/Listen ${PORT_8081}/" ${SSLFILE}
    fi
  fi
}

################################################################################################################################

## Rewrite PHP Configuration (copied from CB2: doPhpConf)
rewrite_php_confs() {

  if [ "${HAVE_FPM_CGI}" = "yes" ]; then
    for php_shortrelease in $(echo ${PHP1_SHORTRELEASE_SET}); do
      set_service "php-fpm${php_shortrelease}" OFF
    done
  else
    for php_shortrelease in $(echo ${PHP1_SHORTRELEASE_SET}); do
      set_service "php-fpm${php_shortrelease}" delete
    done
  fi

  fpmChecks

  if [ "${WEBSERVER}" = "apache" ] || [ "${WEBSERVER}" = "nginx_apache" ]; then

    doApacheHostConf

    # Writing data to httpd-php-handlers.conf
    echo -n "" > "${PHP_HANDLERS_HTTPD}"

    echo '<FilesMatch "\.(inc|php|php3|php4|php44|php5|php52|php53|php54|php55|php56|php70|php6|phtml|phps)$">' >> "${PHP_HANDLERS_HTTPD}"


    if [ "${PHP1_MODE_OPT}" = "mod_php" ]; then
      echo "AddHandler application/x-httpd-php .inc .php .php5 .php${PHP1_SHORTRELEASE} .phtml" >> "${PHP_HANDLERS_HTTPD}"
    fi

    # if [ "${PHP2_MODE_OPT}" = "mod_php" ] && [ "${PHP2_RELEASE_OPT}" != "no" ]; then
    #   echo "AddHandler application/x-httpd-php .php${PHP2_SHORTRELEASE}" >> "${PHP_HANDLERS_HTTPD}"
    # fi

    if [ "${PHP1_MODE_OPT}" = "mod_php" ] || [ "${PHP2_MODE_OPT}" = "mod_php" ]; then
      echo "AddHandler application/x-httpd-php-source .phps" >> "${PHP_HANDLERS_HTTPD}"
    fi

    echo '</FilesMatch>' >> ${PHP_HANDLERS_HTTPD}

    echo "AddType text/html .php" >> ${PHP_HANDLERS_HTTPD}
  fi

  for php_shortrelease in `echo ${PHP1_SHORTRELEASE_SET}`; do
    eval $(echo "HAVE_FPM${php_shortrelease}=no")
  done

  if [ "${PHP1_MODE_OPT}" = "php-fpm" ]; then

      "${INITDDIR}/php-fpm${PHP1_SHORTRELEASE}" restart

    set_service php-fpm${PHP1_SHORTRELEASE} ON
    eval `echo "HAVE_FPM${PHP1_SHORTRELEASE}=yes"`
  fi

  if [ "${PHP2_MODE_OPT}" = "php-fpm" ] && [ "${PHP2_RELEASE_OPT}" != "no" ]; then
        ${INITDDIR}/php-fpm${PHP2_SHORTRELEASE} restart
     # set_service php-fpm${PHP2_SHORTRELEASE} ON
    # eval `echo "HAVE_FPM${PHP2_SHORTRELEASE}=yes"`
  fi

  for php_shortrelease in $(echo ${PHP1_SHORTRELEASE_SET}); do
    EVAL_FPM_VAR=HAVE_FPM${php_shortrelease}
    HAVE_SHORTRELEASE="$(eval_var ${EVAL_FPM_VAR})"

    if [ "${HAVE_SHORTRELEASE}" = "no" ]; then
        if [ -e "${INITDDIR}/php-fpm${php_shortrelease}" ]; then
          "${INITDDIR}/php-fpm${php_shortrelease}" stop
        else
          ${SERVICE} php-fpm stop
        fi
        # set_service php-fpm${php_shortrelease} delete
        # boot/init script: rm -f ${INITDDIR}/php-fpm${php_shortrelease}
    fi
  done

  if [ "${WEBSERVER}" = "apache" ] || [ "${WEBSERVER}" = "nginx_apache" ]; then
    if [ "${HAVE_SUPHP_CGI}" = "yes" ]; then
      ## Writing data to suphp.conf:
      (
        echo -n ""
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
      ) > "${SUPHP_CONF_FILE}"

      if [ "${PHP1_MODE_OPT}" = "suphp" ]; then
        echo "x-httpd-php${PHP1_SHORTRELEASE}=\"php:/usr/local/php${PHP1_SHORTRELEASE}/bin/php-cgi${PHP1_SHORTRELEASE}\"" >> "${SUPHP_CONF_FILE}"
      fi

      if [ "${PHP2_MODE_OPT}" = "suphp" ] && [ "${PHP2_RELEASE_OPT}" != "no" ]; then
        echo "x-httpd-php${PHP2_SHORTRELEASE}=\"php:/usr/local/php${PHP2_SHORTRELEASE}/bin/php-cgi${PHP2_SHORTRELEASE}\"" >> "${SUPHP_CONF_FILE}"
      fi

      echo "" >> "${SUPHP_CONF_FILE}"
      echo ";Handler for CGI-scripts" >> "${SUPHP_CONF_FILE}"
      echo "x-suphp-cgi=\"execute:!self\"" >> "${SUPHP_CONF_FILE}"

      # Writing data to ${APACHE_EXTRA_PATH}/httpd-suphp.conf
      echo "Writing data to ${SUPHP_HTTPD}"
      echo -n "" > "${SUPHP_HTTPD}"

      echo "<IfModule mod_suphp.c>" >> "${SUPHP_HTTPD}"
      echo '<FilesMatch "\.(inc|php|php3|php4|php44|php5|php52|php53|php54|php55|php56|php70|php6|phtml|phps)$">' >> "${SUPHP_HTTPD}"

      if [ "${PHP1_MODE_OPT}" = "suphp" ]; then
        echo "AddHandler x-httpd-php${PHP1_SHORTRELEASE} .inc .php .php3 .php4 .php5 .php${PHP1_SHORTRELEASE} .phtml" >> "${SUPHP_HTTPD}"
      fi

      # if [ "${PHP2_MODE_OPT}" = "suphp" ] && [ "${PHP2_RELEASE_OPT}" != "no" ]; then
      #   echo "AddHandler x-httpd-php${PHP2_SHORTRELEASE} .php${PHP2_SHORTRELEASE}" >> ${SUPHP_HTTPD}
      # fi

      echo '</FilesMatch>' >> "${SUPHP_HTTPD}"

      echo "<Location />" >> "${SUPHP_HTTPD}"
      echo "suPHP_Engine on" >> "${SUPHP_HTTPD}"

      if [ -d "/usr/local/php${PHP1_SHORTRELEASE}/lib" ]; then
        echo "suPHP_ConfigPath /usr/local/php${PHP1_SHORTRELEASE}/lib/" >> "${SUPHP_HTTPD}"
      elif [ -d "/usr/local/php${PHP2_SHORTRELEASE}/lib" ]; then
        echo "suPHP_ConfigPath /usr/local/php${PHP2_SHORTRELEASE}/lib/" >> "${SUPHP_HTTPD}"
      fi

      if [ "${PHP1_MODE_OPT}" = "suphp" ]; then
        echo "suPHP_AddHandler x-httpd-php${PHP1_SHORTRELEASE}" >> ${SUPHP_HTTPD}
      fi

      # if [ "${PHP2_MODE_OPT}" = "suphp" ] && [ "${PHP2_RELEASE_OPT}" != "no" ]; then
      #   echo "suPHP_AddHandler x-httpd-php${PHP2_SHORTRELEASE}" >> ${SUPHP_HTTPD}
      # fi

      echo "</Location>" >> "${SUPHP_HTTPD}"
      echo "</IfModule>" >> "${SUPHP_HTTPD}"
      echo "Done."
    elif [ -e "${SUPHP_HTTPD}" ]; then
      echo -n "" > "${SUPHP_HTTPD}"
    fi
  fi
}

################################################################################################################################

## Setup Brute-Force Monitor
bfm_setup() {
  ## Update directadmin.conf:
  # brute_force_roundcube_log=${WWW_DIR}/roundcube/logs/errors
  # brute_force_squirrelmail_log=${WWW_DIR}/squirrelmail/data/squirrelmail_access_log
  # brute_force_pma_log=${WWW_DIR}/phpMyAdmin/log/auth.log

  setVal brute_force_roundcube_log "${WWW_DIR}/roundcube/logs/errors" ${DA_CONF}
  setVal brute_force_pma_log "${WWW_DIR}/phpMyAdmin/log/auth.log" ${DA_CONF}

  if [ ! -e "${PB_DIR}/patches/pma_auth_logging.patch" ]; then
    ${wget_with_options} -O "${PB_DIR}/patches/pma_auth_logging.patch" "${PB_MIRROR}/patches/pma_auth_logging.patch"
  fi

  #pure_pw=/usr/bin/pure-pw
}

## IPFW Setup (not done)
ipfw_setup() {
  return;
}

################################################################################################################################

## Validate Options
validate_options() {

  ## Verify if PortsBuild directory exists.
  # if [ ! -d "/usr/local/directadmin/portsbuild" ]; then
  #   FOUND_PORTSBUILD=0
  # else
  #   FOUND_PORTSBUILD=1
  # fi

  ## Parse Defaults and User Options, then pass computed values to PB

  ## Default SSL Certificates to use
  OPT_PREFER_APACHE_SSL_CERTS="NO"
  OPT_PREFER_EXIM_SSL_CERTS="NO"
  OPT_PREFER_CUSTOM_SSL_CERTS="NO"

  # SERVER_IP=${DA_SERVER_IP}
  # SERVER_IP_MASK=${DA_SERVER_IP_MASK}

  case ${PHP1_VERSION} in
    55|56|70) PHP_ENABLE="YES" ;;
    *) echo "*** Error: Invalid PHP version set in options.conf"; exit ;;
  esac

  case $(uc ${PHP1_MODE}) in
    FPM|SUPHP|MODPHP|MOD_PHP) PHP_ENABLE="YES" ;;
    *) echo "*** Error: Invalid PHP mode set in options.conf"; exit ;;
  esac

  case $(uc ${WEBSERVER}) in
    APACHE|APACHE24) APACHE_ENABLE="YES" ;;
    NGINX) NGINX_ENABLE="YES" ;;
    *) echo "*** Error: Invalid WEBSERVER set in options.conf"; exit ;;
  esac

  case $(uc ${APACHE_MPM}) in
    EVENT|PREFORK|WORKER) APACHE_ENABLE="YES" ;;
    *) echo "*** Error: Invalid APACHE_MPM set in options.conf"; exit ;;
  esac

  case $(uc ${SQL_DB_SERVER}) in
    MYSQL55|MYSQL56|MYSQL57|MARIADB55|MARIADB100) SQL_DB_ENABLE="YES" ;;
    *) echo "*** Error: Invalid SQL_DB_Server set in options.conf"; exit ;;
  esac

  case $(lc ${PHP_INI_TYPE}) in
    production|development) ;;
    custom) ;;
    *) echo "*** Error: Invalid PHP.ini type set in options.conf"; exit ;;
  esac

  if [ "${PB_SYMLINK}" = "" ]; then
    OPT_PB_SYMLINK="NO"
  fi

  if [ "${INSTALL_CCACHE}" = "" ]; then
    OPT_INSTALL_CCACHE="YES"
  fi

  DA_LAN=0
  if [ -s /root/.lan ]; then
    DA_LAN=$(cat /root/.lan)
  fi

  INSECURE=0
  if [ -s /root/.insecure_download ]; then
    INSECURE=$(cat /root/.insecure_download)
  fi

  # BIND_ADDRESS=--bind-address=$IP
  # if [ "${DA_LAN}" -eq 1 ]; then
  #   BIND_ADDRESS="";
  # fi

  return;
}

################################################################################################################################

## Install Application
## $2 = name of service
## e.g. install_app exim
install_app() {

  case $2 in
    apache) apache_install ;;
    bfm) bfm_setup ;;
    blockcracking) blockcracking_install ;;
    directadmin) directadmin_install ;;
    dkim) pkgi ${PORT_LIBDKIM} ;;
    easy_spam_fighter) easyspamfighter_install ;;
    exim) exim_install ;;
    ioncube) pkgi "${PORT_IONCUBE}" ;;
    ipfw) ipfw_setup ;;
    libspf2) pkgi ${PORT_LIBSPF2} ;;
    mariadb55)
      /usr/sbin/pkg -y ${PORT_MARIADB55} ${PORT_MARIADB55_CLIENT}
      sql_post_install ;;
    mariadb100)
      /usr/sbin/pkg -y ${PORT_MARIADB100} ${PORT_MARIADB100_CLIENT}
      sql_post_install ;;
    mysql55)
      /usr/sbin/pkg -y ${PORT_MYSQL55} ${PORT_MYSQL55_CLIENT}
      sql_post_install ;;
    mysql56)
      /usr/sbin/pkg -y ${PORT_MYSQL56} ${PORT_MYSQL56_CLIENT}
      sql_post_install ;;
    mysql57)
      /usr/sbin/pkg -y ${PORT_MYSQL57} ${PORT_MYSQL57_CLIENT}
      sql_post_install ;;
    nginx) nginx_install ;;
    php55|php56|php70) php_install ;;
    phpmyadmin) phpmyadmin_install ;;
    proftpd) proftpd_install ;;
    pureftpd) pureftpd_install ;;
    roundcube) roundcube_install ;;
    spamassassin) spamassassin_install ;;
    suhosin) suhosin_install ;;
    *) echo "Script error"; return;
  esac
}

## Uninstall Application
## $1 = name of service
## e.g. uninstall_app exim
uninstall_app() {

  case "$1" in
    *) exit;
  esac

  return;
}

################################################################################################################################

## Update PortsBuild Script
update() {
  echo "PortsBuild script update"
  # wget -O portsbuild.sh ${PB_MIRROR}/portsbuild.sh

  ## Backup configuration file
  cp -f options.conf ../portsbuild.conf.backup

  #fetch -o ./${PORTSBUILD_NAME}.tar.gz "${PB_MIRROR}/${PORTSBUILD_NAME}.tar.gz"

  if [ -s "${PORTSBUILD_NAME}.tar.gz" ]; then
    echo "Extracting ${NAME}.tar.gz..."

    tar xvzf "${PORTSBUILD_NAME}.tar.gz" --no-same-owner

    chmod 700 portsbuild.sh
  else
    echo "Unable to extract ${PORTSBUILD_NAME}.tar.gz."
  fi

  ## Symlink pb->portsbuild.sh
  if [ "${OPT_PB_SYMLINK}" = "YES" ]; then
    ln -s /usr/local/directadmin/portsbuild/portsbuild.sh /usr/local/bin/pb
  fi
}

################################################################################################################################

## Upgrade
upgrade() {
    case $2 in
    "") show_menu_upgrade ;;
    esac
}

## Upgrade an application or service
upgrade_app() {
  case $2 in
    "") show_menu_upgrade ;;
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
}

################################################################################################################################

## Show Menu for Upgrades
show_menu_upgrade() {
  echo ""
  echo "Listing possible upgrades"

  return;
}

## Show Setup Menu
show_menu_setup() {
  echo "To setup PortsBuild and DirectAdmin for the first time, run:"
  echo "  ./portsbuild setup <USER_ID> <LICENSE_ID> <SERVER_HOSTNAME> <ETH_DEV> <IP_ADDRESS>"
  echo ""
  return;
}

################################################################################################################################

## Show logo :)
show_logo() {
  echo "               ___\/_ "
  echo "              /  //\  "
  echo "      _______/  /___  "
  echo "     /  __  / ___  /  "
  echo "    /  /_/ / /__/ /   "
  echo "   /  ____/______/    "
  echo "  /  /                "
  echo " /__/                 "
  echo ""
}

## Show version
show_version() {
  echo "portsbuild version ${PB_VER} build ${PB_BUILD_DATE}"
}

## Show versions
show_versions() {
  ## alternative way: awk '{printf("%15s %10s\n", $1, $2)}'
  ( printf "Package Version Origin\n" ; pkg query -i -x "%n %v %o" '(www/apache24|www/nginx|lang/php54|lang/php55|lang/php56|ftp/curl|mail/exim|mail/dovecot2|lang/perl5|mail/roundcube|/www/phpMyAdmin|mail/spamassassin|ftp/wget)' ) | column -t
}

## Show outdated versions of packages
show_outdated() {
  echo "List of packages that are out of date"
  ( printf "Package Outdated\n" ; pkg version -l '<' -x '(www/apache24|www/nginx|lang/php54|lang/php55|lang/php56|ftp/curl|mail/exim|mail/dovecot2|lang/perl5|mail/roundcube|/www/phpMyAdmin|mail/spamassassin|ftp/wget)' ) | column -t
}

## About PortsBuild
about() {
  show_version;
  echo "visit portsbuild.org"
}

## Show selection menu
show_menu() {
  echo ""
  echo "Usage: "
  echo "  pb command [options] [arguments]"
  echo ""
  # echo "Options:"
  # echo "  -h, --help"
  # echo "  -q, --quiet"
  # echo "  -v, --verbose"
  # echo ""
  echo "Available commands"
  echo "  config      Display the current configuration option values"
  echo "  help        Displays help information"
  # echo "  info      Displays information about an application or service"
  echo "  install     Install an application or service"
  echo "  options     Show configured PortsBuild options"
  echo "  outdated    Show outdated applications or services on the system"
  echo "  rewrite     Rewrite (update) a configuration file for an application or service"
  echo "  setup       Setup PortsBuild and DirectAdmin (first-time installations)"
  echo "  update      Updates the portsbuild script"
  echo "  upgrade     Upgrades an application or service"
  #echo "  verify      Verify something"
  # echo "  "
  echo "  version     Show version information on all applications and services installed"
  echo ""

# menu_command
# menu_command_desc
# menu_command_option
# menu_command_option_desc

# menu_update_update = "update"
# menu_update_desc = "Update an application or service"

  return;
}

## Show the main menu
show_main_menu() {
  show_logo;
  show_version;
  show_menu;
}


validate_options;

## ./portsbuild selection screen
case "$1" in
  #"") show_logo; show_version; show_menu; ;;
  # create_options)  ;;
  # set)  ;;
  # check_options) ;;
  "install") install ;;            ## install an application

  "outdated") show_outdated ;;

  "setup")
   #echo "${2}";
   global_setup "$@"
   ;;                ## first time setup

  "update") update ;;              ## update PB script
  "upgrade") upgrade "$@" ;;            ## let portsbuild upgrade an app/service (e.g. php via pkg)
  "verify") verify ;;              ## verify system state
  "version") show_version ;;       ## show portsbuild version
  "versions") show_app_versions ;; ## app/service versions via pkg

  *) show_main_menu ;;
esac

################################################################################################################################

## EOF
