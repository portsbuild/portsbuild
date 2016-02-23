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
PB_BUILD_DATE=20160222

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

if [ ! -f conf/defaults.conf ] || [ ! -f conf/ports.conf ] || [ ! -f conf/options.conf ]; then
 echo "Missing files in conf/"
 exit;
fi

## Source (include) additional files into the script:
. conf/defaults.conf
. conf/ports.conf
. conf/options.conf
. conf/validate.sh
#. conf/make.conf
#. lang/en.txt ## strings files for multilingual support (planned)

# Script is incomplete. :)
if [ "$(hostname)" != "pb.fallout.local" ]; then
  echo "PortsBuild is incomplete. If you want to play with it anyway, comment out line 97's exit;"
  exit;

  DA_LAN=1
fi

################################################################################################################################

## Get DirectAdmin Option Values (copied from CB2)
getDA_Opt() {
  ## $1 is option name
  ## $2 is default value

  ## Make sure directadmin.conf exists and is greater than zero bytes.
  if [ ! -s ${DA_CONF} ]; then
    echo "$2"
    return
  fi

  ## Check for value in ./directadmin c
  if ! ${DA_BIN} c | grep -m1 -q -e "^$1="; then
    echo "$2"
    return
  fi

  ${DA_BIN} c | grep -m1 "^$1=" | cut -d= -f2
}

################################################################################################################################

# ## Emulate ${!variable} (copied from CB2)
# eval_var() {
#   var=${1}
#   if [ -z "${var}" ]; then
#     echo ""
#   else
#     eval newval="\$${var}"
#     echo "${newval}"
#   fi
# }

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
## Used to manipulate CB/PB options.conf
setOpt() {
  ## $1 = option name
  ## $2 = value

    VAR=$(echo "$1" | tr "'a-z'" "'A-Z'")
    if [ -z "$(eval_var ${VAR}_DEF)" ]; then
      echo "${1} is not a valid option."
      #EXIT_CODE=50
      return
    fi

    VALID="no"
    for i in $(eval_var "${VAR}_SET"); do
      if [ "${i}" = "${2}" ] || [ "${i}" = "userinput" ]; then
        VALID="yes"
        break
      fi
    done

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
      * ) echo "Please answer with yes or no." ;;
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

}

## Update /etc/hosts
update_hosts() {
  COUNT=$(grep 127.0.0.1 /etc/hosts | grep -c localhost)
  if [ "$COUNT" -eq 0 ]; then
    echo "Updating /etc/hosts"
    printf "127.0.0.1\t\tlocalhost" >> /etc/hosts
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
  echo "About to setup PortsBuild+Directadmin for the first time."
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
    pkgi lang/gcc6-aux devel/ncurses

    ## Eventually replace with binary when it's ready
    if [ ! -e /usr/local/bin/synth ]; then
      cd /usr/ports/ports-mgmt/synth && make install
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
      cp
    fi

    if [ -e "${CB_CONF}" ]; then
      chmod 755 "${CB_CONF}"
    fi


    ## Skip: DirectAdmin Install
    # cd ${DA_PATH} || exit
    # ./directadmin i

    ## Set DirectAdmin Permissions
    cd ${DA_PATH} || exit
    ./directadmin p

    #${SERVICE} directadmin start

    #global_post_install;

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

  if [ "${NAMED_ENABLE}" = "YES" ]; then
    setVal named_enable \"YES\" /etc/rc.conf
  fi

  ## Todo: write directadmin startup script
  # setVal directadmin_enable \"YES\" /etc/rc.conf

  if [ "${APACHE_ENABLE}" = "YES" ]; then
    setVal apache24_enable \"YES\" /etc/rc.conf
    setVal apache24_http_accept_enable \"YES\" /etc/rc.conf
  fi

  if [ "${MYSQL_ENABLE}" = "YES" ] || [ "${MARIADB_ENABLE}" = "YES" ]; then
    setVal mysql_enable \"YES\" /etc/rc.conf
    setval mysql_dbdir \"/var/db/mysql\" /etc/rc.conf
    setVal mysql_optfile \"/usr/local/etc/my.cnf\" /etc/rc.conf
  fi

  if [ "${NGINX_ENABLE}" = "YES" ]; then
    setVal nginx_enable \"YES\" /etc/rc.conf
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
    setVal pureftpd_enable \"YES\" /etc/rc.conf
    setVal ftpd_enable \"NO\" /etc/rc.conf
  fi

  if [ "${PROFTPD_ENABLE}" = "YES" ]; then
    setVal proftpd_enable \"YES\" /etc/rc.conf
    setVal ftpd_enable \"NO\" /etc/rc.conf
  fi

  if [ "${SPAMASSASSIN_ENABLE}" = "YES" ]; then
    setVal spamd_enable \"YES\" /etc/rc.conf
    setVal spamd_flags \"-c -m 15\" /etc/rc.conf
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
update_make() {
  if [ ! -e /etc/make.conf ]; then
    echo "Creating /etc/make.conf"
    touch /etc/make.conf
  fi

  ## magic goes here
}

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
      return;
    fi

    if [ ! -e /usr/local/etc/namedb/named.conf ]; then
      echo "*** Warning: Cannot find /usr/local/etc/namedb/named.conf.";
      ${WGET} -O /var/named/etc/namedb/named.conf https://raw.githubusercontent.com/portsbuild/portsbuild/master/conf/named.100.conf
    fi

    if [ ! -e /usr/local/etc/namedb/rndc.key ]; then
      echo "Generating rndc.key for the first time"
     rndc-confgen -a -s "${DA_SERVER_IP}"
    fi
  elif [ "$OS_MAJ" -eq 9 ]; then
    if [ ! -e /usr/sbin/named ]; then
      echo "*** Error: Cannot find the named binary.";
      return;

    fi
    if [ ! -e /var/named/etc/namedb/named.conf ]; then
      echo "*** Warning: Cannot find /var/named/etc/namedb/named.conf.";
      ${WGET} -O /etc/namedb/named.conf https://raw.githubusercontent.com/portsbuild/portsbuild/master/conf/named.93.conf
    fi

    if [ ! -e /etc/namedb/rndc.key ]; then
      echo "Generating rndc.key for the first time"
      rndc-confgen -a -s "${DA_SERVER_IP}"
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

  return;
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
  cd ${DA_PATH} || exit
  tar zxvf update.tar.gz

  ## See if the binary exists:
  if [ ! -e ${DA_PATH}/directadmin ]; then
    echo "*** Error: Cannot find the DirectAdmin binary. Extraction failed.";
    exit 5;
  fi

  ## These were in do_checks()

  ## Check for a separate /home partition (for quota support).
  #HOME_YES=`cat /etc/fstab | grep -c /home`;
  HOME_YES=$(grep -c /home < /etc/fstab)
  if [ "$HOME_YES" -lt "1" ]; then
    echo 'quota_partition=/' >> ${DA_CONF_TEMPLATE};
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
  } > ${SETUP_TXT};

  chmod 600 ${SETUP_TXT};

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
  chown -f diradmin:diradmin ${DA_PATH}/*;
  chown -f diradmin:diradmin /var/log/directadmin;
  chmod -f 700 ${DA_PATH}/conf;
  chmod -f 700 /var/log/directadmin;

  #mkdir -p ${DA_PATH}/scripts/packages
  mkdir -p ${DA_PATH}/data/admin

  ## Set permissions
  chown -R diradmin:diradmin ${DA_PATH}/scripts/
  chown -R diradmin:diradmin ${DA_PATH}/data/

  ## No conf files in a fresh install:
  chown -f diradmin:diradmin ${DA_PATH}/conf/* 2> /dev/null > /dev/null;
  chmod -f 600 ${DA_PATH}/conf/* 2> /dev/null > /dev/null;

  ## Create logs directory:
  mkdir -p /var/log/httpd/domains
  chmod 700 /var/log/httpd

  ## NOTE: /home => /usr/home
  mkdir -p /home/tmp
  chmod -f 1777 /home/tmp
  chmod 711 /home

  ## PB: Create User and Reseller Welcome message (need to download/copy these files):
  touch ${DA_PATH}/data/users/admin/u_welcome.txt
  touch ${DA_PATH}/data/admin/r_welcome.txt

  ## PB: Create backup.conf (wasn't created? need to verify)
  chown -f diradmin:diradmin ${DA_PATH}/data/users/admin/backup.conf

  SSHROOT=$(grep -c 'AllowUsers root' < /etc/ssh/sshd_config);
  if [ "${SSHROOT}" = 0 ]; then
    {
      echo "AllowUsers root";
      echo "AllowUsers ${DA_ADMIN_USERNAME}";
      echo "AllowUsers $(logname)";
      ## echo "AllowUsers YOUR_OTHER_ADMIN_ACCOUNT" >> /etc/ssh/sshd_config
    } >> /etc/ssh/sshd_config

    ## Set SSH folder permissions (needed?):
    chmod 710 /etc/ssh
  fi

  ## Change this:
  HTTP="http"

  ## Get the DirectAdmin License Key File (untested)
  ${wget_with_options} ${HTTP}://www.directadmin.com/cgi-bin/licenseupdate?lid=${DA_LICENSE_ID}\&uid=${DA_LICENSE_ID}${EXTRA_VALUE} -O ${DA_LICENSE_FILE} ${BIND_ADDRESS}

  if [ $? -ne 0 ]; then
    echo "*** Error: Unable to download the license file.";
    da_myip;
    echo "Trying license relay server...";

    ${wget_with_options} ${HTTP}://license.directadmin.com/licenseupdate.php?lid=${2}\&uid=${1}${EXTRA_VALUE} -O $DA_LICENSE_FILE ${BIND_ADDRESS}

    if [ $? -ne 0 ]; then
      echo "*** Error: Unable to download the license file from relay server as well.";
      myip;
      exit 2;
    fi
  fi


  COUNT=$(grep -c "* You are not allowed to run this program *" ${DA_LICENSE_FILE});
  if [ "${COUNT}" -ne 0 ]; then
    echo "*** Error: You are not authorized to download the license with that Client ID and License ID (and/or IP address). Please email sales@directadmin.com";
    echo "";
    echo "If you are having connection issues, please see this guide:";
    echo "    http://help.directadmin.com/item.php?id=30";
    echo "";
    da_myip;
    exit 3;
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
  IP=$($WGET_PATH $WGET_OPTION ${BIND_ADDRESS} -qO - ${HTTP}://myip.directadmin.com)

  if [ "${IP}" = "" ]; then
    echo "*** Error: Cannot determine the server's IP address via myip.directadmin.com";
    return;
  fi

  echo "IP used to connect out: ${IP}";
}

## DirectAdmin Upgrade
directadmin_upgrade() {
  return;
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
    if [ -s ${DA_CRON} ]; then
      cat ${DA_CRON} >> /etc/crontab;
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
  NSL=/usr/local/etc/newsyslog.d/directadmin.conf

  if ! grep -q ${NSL_L} $NSL; then
    echo "${NSL_L}\t${NSL_V}\t600\t4\t*\t@T00\t-" >> $NSL
  fi

  #replace whatever we may have with whatever we need, eg:
  #/var/www/html/roundcube/logs/errors  webapps:webapps 600     4       *       @T00    -
  #/var/www/html/roundcube/logs/errors  apache:apache 600     4       *       @T00    -
  #/var/www/html/roundcube/logs/errors      600     4       *       @T00    -

  ${PERL} -pi -e "s|^${NSL_L}\s+webapps:webapps\s+|${NSL_L}\t${NSL_V}\t|" ${NSL}
  ${PERL} -pi -e "s|^${NSL_L}\s+apache:apache\s+|${NSL_L}\t${NSL_V}\t|" ${NSL}
  ${PERL} -pi -e "s|^${NSL_L}\s+600\s+|${NSL_L}\t${NSL_V}\t600\t|" ${NSL}
}


## Verify Webapps Log Rotation (copied from CB2)
verify_webapps_logrotate() {

    # By default it sets each log to webapps:webapps.
    # Swap it to apache:apache if needed
    # else swap it to webapps:webapps from apache:apache... or do nothing

    NSL_VALUE=webapps:webapps

    # if [ "${PHP1_MODE_OPT}" = "mod_php" ] && [ "${MOD_RUID2_OPT}" = "no" ]; then
    #   NSL_VALUE=apache:apache
    # fi

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

  ### Pre-Installation Tasks

  ## From: DA/scripts/install.sh
  mkdir -p ${VIRTUAL_PATH};
  chown -f ${EXIM_USER}:${EXIM_GROUP} ${VIRTUAL_PATH};
  chmod 755 ${VIRTUAL_PATH};

  ## replace $(hostname)
  hostname >> ${VIRTUAL_PATH}/domains;

  if [ ! -s ${VIRTUAL_PATH}/limit ]; then
    echo "${LIMIT_DEFAULT}" > ${VIRTUAL_PATH}/limit
  fi

  if [ ! -s ${VIRTUAL_PATH}/limit_unknown ]; then
    echo "${LIMIT_UNKNOWN}" > ${VIRTUAL_PATH}/limit_unknown
  fi

  chmod 755 ${VIRTUAL_PATH}/*
  mkdir ${VIRTUAL_PATH}/usage
  chmod 750 ${VIRTUAL_PATH}/usage

  for i in domains domainowners pophosts blacklist_domains whitelist_from use_rbl_domains bad_sender_hosts bad_sender_hosts_ip blacklist_senders whitelist_domains whitelist_hosts whitelist_hosts_ip whitelist_senders skip_av_domains skip_rbl_domains; do
    touch ${VIRTUAL_PATH}/$i;
    chmod 600 ${VIRTUAL_PATH}/$i;
  done

  chown -f ${EXIM_USER}:${EXIM_GROUP} ${VIRTUAL_PATH}/*;


  ### Main Installation

  # Alternative: make -C /usr/ports/mail/exim config
  cd /usr/ports/mail/exim || exit
  make config EXIM_USER=mail EXIM_GROUP=mail
  make install clean


  ### Post-Install Tasks

  ## Set permissions
  chown -R ${EXIM_USER}:${EXIM_GROUP} /var/spool/exim

  ## Symlink for compat:
  ln -s ${EXIM_CONF} /etc/exim.conf

  ## Generate Self-Signed SSL Certificates
  ## See: http://help.directadmin.com/item.php?id=245
  /usr/bin/openssl req -x509 -newkey rsa:2048 -keyout /usr/local/etc/exim/exim.key -out /usr/local/etc/exim/exim.cert -days 9000 -nodes

  ## Symlink for DA compat
  ln -s /usr/local/etc/exim/exim.key /etc/exim.key
  ln -s /usr/local/etc/exim/exim.cert /etc/exim.cert

  ## Set permissions:
  chown ${EXIM_USER}:${EXIM_GROUP} /usr/local/etc/exim/exim.key
  chmod 644 /usr/local/etc/exim/exim.key
  chmod 644 /usr/local/etc/exim/exim.cert

  ## Reference: Verify Exim config:
  exim -C ${EXIM_CONF} -bV

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
    touch /etc/mail/mailer.conf
  fi

  ## Update /etc/mail/mailer.conf:
  ## Change to:
  # sendmail /usr/local/sbin/exim
  # send-mail /usr/local/sbin/exim
  # mailq /usr/local/sbin/exim -bp
  # newaliases /usr/bin/true
  # #hoststat /usr/libexec/sendmail/sendmail
  # #purgestat /usr/libexec/sendmail/sendmail
  # rmail /usr/local/sbin/exim -i -oee

  if [ ! -e /etc/periodic.conf ]; then
    touch /etc/periodic.conf
  fi

  ## Replace with setVal
  # echo "daily_status_include_submit_mailq=\"NO\"" >> /etc/periodic.conf
  # echo "daily_clean_hoststat_enable=\"NO\"" >> /etc/periodic.conf

  setVal daily_status_include_submit_mailq \"NO\" /etc/periodic.conf
  setVal daily_clean_hoststat_enable \"NO\" /etc/periodic.conf
}

################################################################################################################################

## SpamAssassin Pre-Installation Tasks
spamassassin_pre_install() {
  return;
}

## SpamAssassin Post-Installation Tasks
spamassassin_post_install() {
  setVal spamd_enable \"YES\" /etc/rc.conf
  setVal spamd_flags \"-c -m 15\" /etc/rc.conf
}


################################################################################################################################

## Install Exim BlockCracking (BC)
blockcracking_install() {

  ## Check for Exim
  pkg query %n "exim"

  if [ -x ${EXIM_BIN} ]; then

    wget_with_options -O ${PB_MIRROR}/exim/exim.blockcracking.tar.gz

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
      echo "Your version of Exim does not support SPF. This is needed for Easy Spam Fighter."
      echo "Please rebuild Exim with SPF support."
      exit 1;
    fi

    if [ "${EXIM_SRS_SUPPORT}" = "0" ]; then
      echo "Your version of Exim does not support SRS. This is needed for Easy Spam Fighter."
      echo "Please rebuild Exim with SRS support."
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

## Dovecot Installation Tasks
dovecot_install() {

  # make -C /usr/ports/mail/dovecot2 config

  cd /usr/ports/mail/dovecot2 || exit
  make config
  make install clean


  ## Dovecot Post-Installation Tasks

  ## Fetch latest config:
  ${WGET} -O ${DOVECOT_CONF} http://files.directadmin.com/services/custombuild/dovecot.conf.2.0

  ## Update directadmin.conf:
  echo "add_userdb_quota=1" >> ${DA_CONF}
  echo "dovecot=1" >> ${DA_CONF}

  ## Reference: doRestartDA:
  echo "action=rewrite&value=email_passwd" >> ${DA_TASK_QUEUE}
  #run_dataskq d

  ## Add Dovecot quota support to the directadmin.conf template:
  echo "add_userdb_quota=1" >> ${DA_CONF_TEMPLATE}

  ## Todo/verify:
  ## Update dovecot.conf (and conf/ssl.conf?) for SSL support
  if [ "${OPT_PREFER_APACHE_SSL_CERTS}" = "YES" ]; then
    ## using existing Apache certs:
    ssl_cert = <${APACHE_DIR}/ssl/server.crt
    ssl_key = <${APACHE_DIR}/ssl/server.key
  elif [ "${OPT_PREFER_EXIM_SSL_CERTS}" = "YES" ]; then
    ## or using existing Exim certs:
    ssl_cert = <${EXIM_PATH}/exim.crt
    ssl_key = <${EXIM_PATH}/exim.key
  elif [ "${OPT_PREFER_CUSTOM_SSL_CERTS}" = "YES" ]; then
    ## or using your own custom certs:
    ssl_cert = </usr/local/etc/ssl/server.crt
    ssl_key = </usr/local/etc/ssl/server.key
  fi

  ## Prepare Dovecot directories:
  mkdir -p /etc/dovecot/
  mkdir -p ${DOVECOT_PATH}
  mkdir -p /usr/local/etc/dovecot/conf.d

  ## Symlink for compat:
  ln -s ${DOVECOT_CONF} /etc/dovecot/dovecot.conf
  # Skipped: ln -s /etc/dovecot/dovecot.conf /etc/dovecot.conf


  ## Verify: use conf/ or conf.d/?

  ## Verify
  cp -rf ${DA_PATH}/custombuild/configure/dovecot/conf ${DOVECOT_PATH}

  echo "mail_plugins = \$mail_plugins quota" > ${DOVECOT_PATH}/conf/lmtp_mail_plugins.conf

  ## Todo: Replace `hostname` with $(hostname)
  ${PERL} -pi -e "s|HOSTNAME|`hostname`|" ${DOVECOT_PATH}/conf/lmtp.conf

  ## ltmp log files (not done):
  touch /var/log/dovecot-lmtp.log /var/log/dovecot-lmtp-errors.log
  chown root:wheel /var/log/dovecot-lmtp.log /var/log/dovecot-lmtp-errors.log
  chmod 600 /var/log/dovecot-lmtp.log /var/log/dovecot-lmtp-errors.log

  ## Modifications (done):
  ${PERL} -pi -e 's#transport = dovecot_lmtp_udp#transport = virtual_localdelivery#' ${EXIM_CONF}
  ${PERL} -pi -e 's/driver = shadow/driver = passwd/' ${DOVECOT_CONF}
  ${PERL} -pi -e 's/passdb shadow/passdb passwd/' ${DOVECOT_CONF}

  echo "mail_plugins = \$mail_plugins quota"            > ${DOVECOT_PATH}/conf/mail_plugins.conf
  echo "mail_plugins = \$mail_plugins quota imap_quota" > ${DOVECOT_PATH}/conf/imap_mail_plugins.conf

  ## Check for IPV6 compatibility:
  if [ "${IPV6_ENABLED}" = "1" ]; then
    ${PERL} -pi -e 's|^listen = \*$|#listen = \*|' ${DOVECOT_PATH}/dovecot.conf
    ${PERL} -pi -e 's|^#listen = \*, ::$|listen = \*, ::|' ${DOVECOT_PATH}/dovecot.conf
  else
    ${PERL} -pi -e 's|^#listen = \*$|listen = \*|' ${DOVECOT_PATH}/dovecot.conf
    ${PERL} -pi -e 's|^listen = \*, ::$|#listen = \*, ::|' ${DOVECOT_PATH}/dovecot.conf
  fi

  echo "listen = *, ::" > /usr/local/etc/dovecot/conf/ip.conf

  echo "Enabling Dovecot startup (upating /etc/rc.conf)"
  setVal dovecot_enable \"YES\" /etc/rc.conf
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
  ## Secure Installation (replace it with scripted method below)
  /usr/local/bin/mysql_secure_installation

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
  # echo "user=da_admin" > /usr/local/directadmin/conf/mysql.conf
  # echo "passwd=DA_ADMIN_SQL_PASSWORD" >> /usr/local/directadmin/conf/mysql.conf
  # chown diradmin:diradmin /usr/local/directadmin/conf/mysql.conf;
  # chmod 400 /usr/local/directadmin/conf/mysql.conf;

  ## Create and update `/usr/local/etc/my.cnf`:

  # touch /usr/local/etc/my.cnf
  # echo "[mysqld]" > /usr/local/etc/my.cnf;
  # echo "local-infile=0" >> /usr/local/etc/my.cnf;
  # echo "innodb_file_per_table" >> /usr/local/etc/my.cnf;

  ## Symlink the `mysqldump` binary for compat. This is used by DirectAdmin during SQL backup functions (may not be needed since we can set the binary path in directadmin.conf):
  mkdir -p /usr/local/mysql/bin
  ln -s /usr/local/bin/mysqldump /usr/local/mysql/bin/mysqldump
  ln -s /usr/local/bin/mysql /usr/local/mysql/bin/mysql

}

################################################################################################################################

## PHP Post-Installation Tasks
php_post_install() {

  # make -C /usr/ports/lang/php${PHP1_VERSION} config
  cd "/usr/ports/lang/php${PHP1_VERSION}" || exit
  make config
  make install clean

  ## Replace default php-fpm.conf with DirectAdmin/CB2 version:
  #cp -f /usr/local/directadmin/custombuild/configure/fpm/conf/php-fpm.conf.56 /usr/local/etc/php-fpm.conf

  if [ "${PHP_INI_TYPE}" = "production" ]; then
    cp -f /usr/local/etc/php.ini-production /usr/local/etc/php.ini
  elif [ "${PHP_INI_TYPE}" = "development" ]; then
    cp -f /usr/local/etc/php.ini-development /usr/local/etc/php.ini
  fi

  ## PHP1_VERSION="56"
  PHP_PATH="/usr/local/php${PHP1_VERSION}"

  ## Create directories for DA compat:
  mkdir -p ${PHP_PATH}
  mkdir -p ${PHP_PATH}/bin
  mkdir -p ${PHP_PATH}/etc
  mkdir -p ${PHP_PATH}/include
  mkdir -p ${PHP_PATH}/lib
  mkdir -p ${PHP_PATH}/php
  mkdir -p ${PHP_PATH}/sbin
  mkdir -p ${PHP_PATH}/sockets
  mkdir -p ${PHP_PATH}/var/log/
  mkdir -p ${PHP_PATH}/var/run
  #mkdir -p ${PHP_PATH}/lib/php.conf.d/
  mkdir -p ${PHP_PATH}/lib/php/

  ## Symlink for compat
  ln -s /usr/local/bin/php ${PHP_PATH}/bin/php
  ln -s /usr/local/bin/php-cgi ${PHP_PATH}/bin/php-cgi
  ln -s /usr/local/bin/php-config ${PHP_PATH}/bin/php-config
  ln -s /usr/local/bin/phpize ${PHP_PATH}/bin/phpize
  ln -s /usr/local/sbin/php-fpm ${PHP_PATH}/sbin/php-fpm
  ln -s /var/log/php-fpm.log ${PHP_PATH}/var/log/php-fpm.log
  ln -s /usr/local/include/php ${PHP_PATH}/include

  ## Scan directory for PHP ini files:
  ln -s /usr/local/etc/php ${PHP_PATH}/lib/php.conf.d
  ln -s /usr/local/etc/php.ini ${PHP_PATH}/lib/php.ini
  ln -s /usr/local/etc/php-fpm.conf ${PHP_PATH}/etc/php-fpm.conf
  ln -s /usr/local/lib/php/build ${PHP_PATH}/lib/php/build
  ln -s /usr/local/lib/php/20131226 ${PHP_PATH}/lib/php/extensions

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

################################################################################################################################

## phpMyAdmin Installation
phpmyadmin_install() {

  ### Main Installation

  cd /usr/ports/databases/phpMyAdmin || exit
  make config
  make install clean

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
  CUSTOM_PMA_CONFIG="${CB_PATH}/custom/phpmyadmin/config.inc.php"
  CUSTOM_PMA_THEMES="${CB_PATH}/custom/phpmyadmin/themes"

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
    ${WGET} "${WGET_CONNECT_OPTIONS}" -O "${PB_DIR}/patches/pma_auth_logging.patch" "${PB_MIRROR}/patches/pma_auth_logging.patch"
  fi

  if [ -e "${PB_DIR}/patches/pma_auth_logging.patch" ]; then
    echo "Patching phpMyAdmin to log failed authentications for BFM"
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
  cd /usr/ports/www/apache24 || exit
  make config
  make install clean

  ### Post-Installation Tasks

  ## Symlink for backwards compatibility:
  mkdir -p /etc/httpd/conf
  ln -s ${APACHE_DIR} /etc/httpd/conf

  ## CustomBuild2 looking for Apache modules in /usr/lib/apache*
  ## Symlink for backcomp (done):

  mkdir -p /usr/lib/apache
  ln -s /usr/local/libexec/apache24 /usr/lib/apache

  ## Since DirectAdmin/CB2 reference /var/www/html often, we'll symlink for compat:
  mkdir -p /var/www
  ln -s ${WWW_DIR} /var/www/html
  chown -h ${WEBAPPS_USER}:${WEBAPPS_GROUP} /var/www/html

  ## CustomBuild2 reference /etc/httpd/conf/ssl
  ## Create empty files for CB2 to generate

  ## Symlink SSL directories for compat:
  mkdir -p /etc/httpd/conf/ssl.crt
  mkdir -p /etc/httpd/conf/ssl.key
  mkdir -p ${APACHE_DIR}/ssl

  #touch /etc/httpd/conf/ssl.crt/server.crt
  #touch /etc/httpd/conf/ssl.key/server.key

  touch ${APACHE_DIR}/ssl/server.crt
  touch ${APACHE_DIR}/ssl/server.key

  ln -s ${APACHE_DIR}/ssl/server.crt /etc/httpd/conf/ssl.crt/server.crt
  ln -s ${APACHE_DIR}/ssl/server.ca /etc/httpd/conf/ssl.crt/server.ca
  ln -s ${APACHE_DIR}/ssl/server.key /etc/httpd/conf/ssl.key/server.key

  ln -s ${APACHE_DIR}/ssl/server.crt ${APACHE_DIR}/ssl.crt/server.crt
  ln -s ${APACHE_DIR}/ssl/server.ca ${APACHE_DIR}/ssl.crt/server.ca
  ln -s ${APACHE_DIR}/ssl/server.key ${APACHE_DIR}/ssl.key/server.key

  ## Also check for /usr/local/bin/openssl (security/openssl port):
  /usr/bin/openssl req -x509 -newkey rsa:2048 -keyout ${APACHE_DIR}/ssl/server.key -out ${APACHE_DIR}/ssl/server.crt -days 9999 -nodes -config ${CB_PATH}/custom/ap2/cert_config.txt

  ## Set permissions:
  chmod 600 ${APACHE_DIR}/ssl/server.crt
  chmod 600 ${APACHE_DIR}/ssl/server.key

  ## Symlink for DA compat:
  ln -s /usr/local/sbin/httpd /usr/sbin/httpd

  ## Copy over modified (custom) CB2 conf files to conf/:
  cp -rf ${DA_PATH}/custombuild/custom/ap2/conf/ ${APACHE_DIR}/
  cp -f ${DA_PATH}/custombuild/custom/ap2/conf/httpd.conf ${APACHE_DIR}/
  cp -f ${DA_PATH}/custombuild/custom/ap2/conf/extra/httpd-mpm.conf ${APACHE_DIR}/extra/httpd-mpm.conf

  ## Already done (default):
  ${PERL} -pi -e 's/^DefaultType/#DefaultType/' ${APACHE_DIR}/httpd.conf
  chmod 710 ${APACHE_DIR}

  ## Update directadmin.conf with new SSL paths
  # setVal apacheconf /usr/local/etc/apache24/httpd.conf
  # setVal apacheips /usr/local/etc/apache24/ips.conf
  # setVal apachemimetypes /usr/local/etc/apache24/mime.types
  # setVal apachecert /usr/local/etc/apache24/ssl/server.crt
  # setVal apachekey /usr/local/etc/apache24/ssl/server.key
  # setVal apacheca /usr/local/etc/apache24/ssl/server.ca

  ## Rewrite Apache 2.4 configuration files
  ## Perhaps skip this? No need I think -sg

  ##cd /usr/local/directadmin/custombuild
  ##./build rewrite_confs

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

## ClamAV Post-Installation Tasks
clamav_install() {
  setVal clamav_clamd_enable \"YES\" /etc/rc.conf
  setVal clamav_freshclam_enable \"YES\" /etc/rc.conf

  return;
}

################################################################################################################################

## RoundCube Installation
roundcube_install() {



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
        #if [ "${WEBSERVER_OPT}" = "apache" ] || [ "${WEBSERVER_OPT}" = "litespeed" ] || [ "${WEBSERVER_OPT}" = "nginx_apache" ]; then
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
  if [ "`have_php_system`" = "0" ]; then
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
rewrite_apache_conf() {

  APACHE_HOST_CONF=${APACHE_PATH}/extra/httpd-hostname.conf

  ## Set this for now since PB only supports 1 instance of PHP.
  #PHP1_MODE_OPT="php-fpm"
  #PHP1_MODE="FPM"
  PHP1_VERSION="56"

  ## Copy custom/ file
  ## APACHE_HOST_CONF_CUSTOM
  if [ -e "${WORKDIR}/custom/ap2/conf/extra/httpd-hostname.conf" ]; then
    cp -pf "${WORKDIR}/custom/ap2/conf/extra/httpd-hostname.conf" ${APACHE_HOST_CONF}
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

    # if [ "${PHP1_MODE_OPT}" = "fastcgi" ]; then
    #   echo '  <IfModule mod_fcgid.c>' >> ${APACHE_HOST_CONF}
    #   echo "      FcgidWrapper /usr/local/safe-bin/fcgid${PHP1_VERSION}.sh .php" >> ${APACHE_HOST_CONF}
    #   if [ "${SUEXEC_PER_DIR}" -gt 0 ]; then
    #       echo '    SuexecUserGroup webapps webapps' >> ${APACHE_HOST_CONF}
    #   fi
    #   echo '      <FilesMatch "\.(inc|php|php3|php4|php44|php5|php52|php53|php54|php55|php56|php70|php6|phtml|phps)$">' >> ${APACHE_HOST_CONF}
    #   echo '          Options +ExecCGI' >> ${APACHE_HOST_CONF}
    #   echo '          AddHandler fcgid-script .php' >> ${APACHE_HOST_CONF}
    #   echo '      </FilesMatch>' >> ${APACHE_HOST_CONF}
    #   echo '  </IfModule>' >> ${APACHE_HOST_CONF}
    # fi

    # if [ "${PHP2_MODE_OPT}" = "fastcgi" ] && [ "${PHP2_RELEASE_OPT}" != "no" ]; then
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
}

################################################################################################################################

## Setup Brute-Force Monitor
bfm_setup() {
  ## Update directadmin.conf:
  # brute_force_roundcube_log=${WWW_DIR}/roundcube/logs/errors
  # brute_force_squirrelmail_log=${WWW_DIR}/squirrelmail/data/squirrelmail_access_log
  # brute_force_pma_log=${WWW_DIR}/phpMyAdmin/log/auth.log

  setVal brute_force_roundcube_log ${WWW_DIR}/roundcube/logs/errors ${DA_CONF}
  setVal brute_force_pma_log ${WWW_DIR}/phpMyAdmin/log/auth.log ${DA_CONF}



  if [ ! -e "${PB_DIR}/patches/pma_auth_logging.patch" ]; then
    wget_with_options -O "${PB_DIR}/patches/pma_auth_logging.patch" "${PB_MIRROR}/patches/pma_auth_logging.patch"
  fi

  #pure_pw=/usr/bin/pure-pw
}

## IPFW Setup
ipfw_setup() {
  return;
}



################################################################################################################################

## Install Application
## $1 = name of service
## e.g. install_app exim
install_app() {
  ## add func() to update make.conf, or config via CLI

  case "$1" in
    "directadmin")
      directadmin_install
      ;;
    "apache")
      apache_install
      # portmaster -d ${PORT_APACHE24}
      ;;
    "nginx")
      nginx_install
      #portmaster -d ${PORT_NGINX}
      ;;
    "php55")
      cd /usr/ports/lang/php55 && make config && make install
      # portmaster -d ${PORT_PHP55}
      ;;
    "php56")
      cd /usr/ports/lang/php56 && make config && make install
      # portmaster -d ${PORT_PHP56}
      ;;
    "php70")
      cd /usr/ports/lang/php70 && make config && make install
      ;;
    "ioncube")
      pkgi ${PORT_IONCUBE}
      ;;
    "roundcube")
      roundcube_install
      portmaster -d ${PORT_ROUNDCUBE}
      ;;
    "spamassassin")
      cd /usr/ports/mail/spamassassin && make config && make install
      # portmaster -d ${PORT_SPAMASSASSIN}
      spamassassin_install
      ;;
    "libspf2") pkgi ${PORT_LIBSPF2} ;;
    "dkim") pkgi ${PORT_LIBDKIM} ;;
    "blockcracking") blockcracking_install ;;
    "easy_spam_fighter") easyspamfighter_install ;;
    "exim")
      exim_install
      ;;
    "mariadb55")
      # portmaster -d ${PORT_MARIADB55}
      pkgi ${PORT_MARIADB55} ${PORT_MARIADB55_CLIENT}
      sql_post_install
      ;;
    "mariadb100")
      # portmaster -d ${PORT_MARIADB100}
      pkgi ${PORT_MARIADB100} ${PORT_MARIADB100_CLIENT}
      sql_post_install
      ;;
    "mysql55")
      # portmaster -d ${PORT_MYSQL55}
      pkgi ${PORT_MYSQL55} ${PORT_MYSQL55_CLIENT}
      sql_post_install
      ;;
    "mysql56")
      # portmaster -d ${PORT_MYSQL56}
      pkgi ${PORT_MYSQL56} ${PORT_MYSQL56_CLIENT}
      sql_post_install
      ;;
    "mysql57")
      # portmaster -d ${PORT_MYSQL56}
      pkgi ${PORT_MYSQL57} ${PORT_MYSQL57_CLIENT}
      sql_post_install
      ;;
    "phpmyadmin")
      #cd /usr/ports/databases/phpMyAdmin && make config && make install
      # portmaster -d ${PORT_PHPMYADMIN}
      phpmyadmin_install
      ;;
    "pureftpd")
      #cd /usr/ports/ftp/pureftpd && make config && make install
      portmaster -d ${PORT_PUREFTPD}
      ;;
    "proftpd")
      portmaster -d ${PORT_PROFTPD}
      ;;
    "bfm")
      bfm_setup
      ;;
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

  if [ "${OPT_PB_SYMLINK}" = "YES" ]; then
    ln -s /usr/local/directadmin/portsbuild/portsbuild.sh /usr/local/bin/pb
  fi
}

################################################################################################################################

## Upgrade
upgrade() {
    case "$2" in
    "") show_menu_upgrade ;;
    esac
}

## Upgrade an application or service
upgrade_app() {
  case "$2" in
    "") show_menu_upgrade ;;
    "php") php_upgrade ;;
    "suhosin") suhosin_upgrade ;;
    "ioncube") ioncube_upgrade ;;
    "modsecurity") modsecurity_upgrade ;;
    "awstats") awstats_upgrade ;;
    "webalizer") webalizer_upgrade ;;

    "apache") apache_upgrade ;;
    "nginx") nginx_upgrade ;;

    "mysql") mysql_upgrade ;;
    "mariadb") mariadb_upgrade ;;

    "phpmyadmin") phpmyadmin_upgrade ;;

    "exim") exim_upgrade ;;
    "dovecot") dovecot_upgrade ;;
    "roundcube") roundcube_upgrade ;;
    "pigeonhole") pigeonhole_upgrade ;;

    "spamassassin") spamassassin_upgrade ;;
    "blockcracking") blockcracking_upgrade ;;
    "easyspamfighter") easyspamfighter_upgrade ;;

    "pureftpd") pureftpd_upgrade ;;
    "proftpd") proftpd_upgrade ;;

    "directadmin") directadmin_upgrade ;;
    "portsbuild") portsbuild_upgrade ;;

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
