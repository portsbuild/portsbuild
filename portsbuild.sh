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
#  Installation:
#  - New installs, run: ./portsbuild install <USER_ID> <LICENSE_ID> <SERVER_HOSTNAME> <ETH_DEV> (<IP_ADDRESS>)
#
#  Existing users:
#  - Update: ./portsbuild update
#  - Verify: ./portsbuild verify
#
# Changelog/History: see CHANGELOG for more details
#
# *************************************************************************************************
#

# Script is incomplete. :)
exit;

### If you want to modify PortsBuild settings, please check out 'conf/options.conf'

### PortsBuild ###

if [ "$(id -u)" != "0" ]; then
  echo "Must run this script as the root user.";
  exit 1;
fi

OS=$(uname)
OS_VER=$(uname -r | cut -d- -f1) # 9.3, 10.1, 10.2
OS_B64=$(uname -m | grep -c 64)  # 0, 1
OS_MAJ=$(uname -r | cut -d. -f1) # 9, 10

OS_HOST=$(hostname);
OS_DOMAIN=$(echo "$OS_HOST" | cut -d. -f2,3,4,5,6)

if [ "${OS}" = "FreeBSD" ]; then
  if [ "${OS_B64}" -eq 1 ]; then
    if [ "$OS_VER" = "10.1" ] || [ "$OS_VER" = "10.2" ] || [ "$OS_VER" = "9.3" ]; then
      echo "FreeBSD $OS_VER x64 operating system detected."
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

## Source (include) additional files.
. conf/defaults.conf
. conf/ports.conf
. conf/options.conf
#. conf/discover.conf
#. conf/make.conf

## Verify if /usr/ports exists.
if [ ! -d ${PORTS_BASE}/ ]; then
  if [ "${AUTO_MODE}" -eq 0 ]; then
    echo "Error: FreeBSD Ports system not installed. PortsBuild needs this to continue."
    echo "Please run the following command to install Ports:"
    echo "  portsnap fetch extract"
    echo "or visit: https://www.freebsd.org/doc/en_US.ISO8859-1/books/handbook/ports-using.html"
    exit 1;
  else
    ## Automatically install & update /usr/ports/
    setup_ports
  fi
fi

if [ ! -f conf/defaults.conf ] || [ ! -f conf/ports.conf ] || [ ! -f conf/options.conf ]; then
 echo "Missing files in conf/"
fi

################################################################

## Get DA Options (copied from CB2)
getDA_Opt() {
  #$1 is option name
  #$2 is default value

  if [ ! -s ${DA_CONF_FILE} ]; then
    echo "$2"
    return
  fi

  if ! ${DA_BIN} c | grep -m1 -q -e "^$1="; then
    echo "$2"
    return
  fi

  ${DA_BIN} c | grep -m1 "^$1=" | cut -d= -f2
}

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

## Get Option (copied from CB2)
## Used to retrieve CB/PB options.conf
getOpt() {
  ## $1 = option name
  ## $2 = default value

  # CB2: Added "grep -v" to workaround many lines with empty options
  GET_OPTION="$(grep -v "^$1=$" ${OPTIONS_CONF} | grep -m1 "^$1=" | cut -d= -f2)"
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

  ## Handle email field seperately
  # if [ "$1" = "email" ]; then
  #     OPT_VALUE1="`grep -m1 "^$1=" ${OPTIONS_CONF} | cut -d= -f2 | cut -d\@ -f 1`"
  #     OPT_VALUE2="`grep -m1 "^$1=" ${OPTIONS_CONF} | cut -d= -f2 | cut -d\@ -f 2`"
  #     OPT_NEW_VALUE1="`echo "$2" | cut -d\@ -f 1`"
  #     OPT_NEW_VALUE2="`echo "$2" | cut -d\@ -f 2`"
  #     ${PERL} -pi -e "s#$1=${OPT_VALUE1}\@${OPT_VALUE2}#$1=${OPT_NEW_VALUE1}\@${OPT_NEW_VALUE2}#" ${PB_CONF}
  #     # if [ "${HIDE_CHANGES}" = "0" ]; then
  #     #     echo "Changed ${boldon}$1${boldoff} option from ${boldon}${OPT_VALUE1}@${OPT_VALUE2}${boldoff} to ${boldon}$2${boldoff}"
  #     # fi
  # else
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
    OPT_VALUE="$(grep -m1 "^$1=" ${OPTIONS_CONF} | cut -d= -f2)"
    ${PERL} -pi -e "s#$1=${OPT_VALUE}#$1=$2#" ${PB_CONF}
    # if [ "${HIDE_CHANGES}" = "0" ]; then
    #     echo "Changed ${boldon}$1${boldoff} option from ${boldon}${OPT_VALUE}${boldoff} to ${boldon}$2${boldoff}"
    # fi
  # fi
}


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

################################################################

## Enable a service in /etc/rc.conf
service_on() {
  setVal "${1}_enable" \"YES\" /etc/rc.conf
}

## Disable a service in /etc/rc.conf
service_off() {
  setVal "${1}_enable" \"NO\" /etc/rc.conf
}

################################################################

## pkg bootstrap
setup_pkg() {
  echo "Bootstrapping and updating pkg"
  env ASSUME_ALWAYS_YES=YES pkg bootstrap
  update_pkg
}

## pkg update
update_pkg() {
  ${PKG} update
}

## Install package without prompts
pkgi() {
  ${PKG} install -y "$1"
}

## Setup /usr/ports
setup_ports() {
  ${PORTSNAP} fetch extract
}

## Update /usr/ports
update_ports() {
  ${PORTSNAP} fetch update
}

## Clean stale ports
clean_stale_ports() {
  ${PORTMASTER} -s
}

## Reinstall all ports "in place" (from manual)
reinstall_all_ports() {
  ${PORTMASTER} -a -f -d
}

## Random Password Generator (from CB2)
random_pass() {
  ## $1 = length (default: 12)

  if [ "$1" = "" ]; then
    PASS_LENGTH=12
  else
    PASS_LENGTH=$1
  fi

  ${PERL} -le"print map+(A..Z,a..z,0..9)[rand 62],0..${PASS_LENGTH}"
}

################################################################

## Pre-Install Tasks
pre_install() {
  ## Need to create a blank /etc/auth.conf file for DA compatibility.
  echo "Pre-Install Task: checking for /etc/auth.conf"
  if [ ! -e /etc/auth.conf ]; then
    /usr/bin/touch /etc/auth.conf;
    /bin/chmod 644 /etc/auth.conf;
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

  ## Check for /etc/rc.conf
  if [ ! -e /etc/rc.conf ]; then
    touch /etc/rc.conf
  fi

  ## Check for /etc/make.conf
  if [ ! -e /etc/make.conf ]; then
    touch /etc/make.conf
  fi

  setVal ipv6_ipv4mapping \"YES\" /etc/rc.conf
  setVal net.inet6.ip6.v6only 0 /etc/sysctl.conf

  /sbin/sysctl net.inet6.ip6.v6only=0

  disable_sendmail

  ## Ethernet Device checking here
  ##
}

## Setup
setup() {
  install_deps;
  install_compats;

  if [ "${OPT_INSTALL_CCACHE}" = "YES" ]; then
    install_ccache;
  fi

  pre_install;
  directadmin_pre_install;
  install_directadmin;
  create_cb_options;
  exec_da_permissions;
  post_install;
}


## Install Dependencies
install_deps() {
  if [ "${OS_MAJ}" -eq 10 ]; then
    /usr/sbin/pkg install -y devel/gmake lang/perl5.20 ftp/wget devel/bison textproc/flex graphics/gd security/cyrus-sasl2 devel/cmake lang/python devel/autoconf devel/libtool archivers/libarchive mail/mailx dns/bind910
  elif [ "${OS_MAJ}" -eq 9 ]; then
    /usr/sbin/pkg install -y devel/gmake lang/perl5.20 ftp/wget devel/bison textproc/flex graphics/gd security/cyrus-sasl2 devel/cmake lang/python devel/autoconf devel/libtool archivers/libarchive mail/mailx
  fi
}

## Install Compat Libraries
install_compats() {
  if [ "${OS_MAJ}" -eq 10 ]; then
    /usr/sbin/pkg install -y misc/compat4x misc/compat5x misc/compat6x misc/compat8x misc/compat9x
  elif [ "${OS_MAJ}" -eq 9 ]; then
    /usr/sbin/pkg install -y misc/compat4x misc/compat5x misc/compat6x misc/compat8x
  fi
}

## Install CCache
install_ccache() {
  pkgi devel/ccache

  if [ $? = 0 ]; then
    if [ ! -e /etc/make.conf ]; then
      touch /etc/make.conf
    fi
    setVal WITH_CCACHE_BUILD yes /etc/make.conf
  fi
}

## Post-Install Tasks
post_install() {
  ## cleanup leftover files?
  echo "All done."
  exit 0;
}

## Disable sendmail
disable_sendmail() {
  setVal sendmail_enable \"NONE\" /etc/rc.conf
  setVal sendmail_submit_enable \"NO\" /etc/rc.conf
  setVal sendmail_outbound_enable \"NO\" /etc/rc.conf
  setVal sendmail_msp_queue_enable \"NO\" /etc/rc.conf

  ${SERVICE} sendmail onestop
}

## Enable SSH Daemon
enable_sshd() {
  setVal sshd_enable \"YES\" /etc/rc.conf

  ${SERVICE} sshd start
}

## Update /etc/rc.conf
update_rc() {
  ## Go through installed/enabled services and make sure they're all enabled.
  ## Perhaps rename this function to verify_rc?
  return;
}

## Update /etc/make.conf
update_make() {
  if [ ! -e /etc/make.conf ]; then
    touch /etc/make.conf
  fi

  ## magic goes here
}

## [CATEGORY]_[PORT]_[SET|UNSET]=OPTION1 OPTION2 ...

## Make set options
make_set() {
  # make set
  return;
}

## Make unset options
make_unset() {
  # make unset
  return;
}

## Update /etc/hosts
update_hosts() {
  COUNT=$(grep 127.0.0.1 /etc/hosts | grep -c localhost)
  if [ "$COUNT" -eq 0 ]; then
    #echo -e "127.0.0.1\t\tlocalhost" >> /etc/hosts
    printf "127.0.0.1\t\tlocalhost" >> /etc/hosts
  fi
}

## Setup BIND (named)
setup_bind() {
  ## BIND (named)
  if [ "${OS_MAJ}" -eq 10 ]; then
    if [ ! -e /usr/local/sbin/named ]; then
      echo "*** Error: Cannot find the named binary.";
    fi
    if [ ! -e /usr/local/etc/namedb/named.conf ]; then
      echo "*** Error: Cannot find /usr/local/etc/namedb/named.conf.";
    fi
  elif [ "$OS_MAJ" -eq 9 ]; then
    if [ ! -e /usr/sbin/named ]; then
      echo "*** Error: Cannot find the named binary.";
    fi
    if [ ! -e /var/named/etc/namedb/named.conf ]; then
      echo "*** Error: Cannot find /var/named/etc/namedb/named.conf. Make sure Bind is completely installed.";
    fi
  fi

  ## File target paths:
  ## 10.2: /var/named/etc/namedb/named.conf
  ## 9.3: /etc/namedb/named.conf

  if [ "${OS_MAJ}" -eq 10 ]; then
    ## FreeBSD 10.2 with BIND 9.9.5 from ports
    ${WGET} -O /var/named/etc/namedb/named.conf https://raw.githubusercontent.com/portsbuild/portsbuild/master/conf/named.100.conf
  elif [ "${OS_MAJ}" -eq 9 ]; then
    ## FreeBSD 9.3 with BIND 9.9.5 from base
    ${WGET} -O /etc/namedb/named.conf https://raw.githubusercontent.com/portsbuild/portsbuild/master/conf/named.93.conf
  fi

  ## Generate BIND's rndc.key
  if [ ! -e /usr/local/etc/namedb/rndc.key ] || [ ! -e /etc/namedb/rndc.key ]; then
    rndc-confgen -a -s ${DA_SERVER_IP}
  fi

  setVal named_enable \"YES\" /etc/rc.conf

  ${SERVICE} named start
}

## Create a spoof CustomBuild2 options.conf for DirectAdmin compatibility.
create_cb_options() {
  if [ ! -d ${CB_PATH} ]; then
    mkdir -p ${CB_PATH}
  fi

  ${WGET} -O ${CB_CONF} "${PB_MIRROR}/conf/cb-options.conf"

  if [ -e "${CB_OPTIONS}" ]; then
    chmod 755 "${CB_OPTIONS}"
  fi
}


## Create portsbuild/options.conf
create_pb_options() {
  touch ${DA_PATH}/portsbuild/options.conf
}

### DirectAdmin Installation ###

## DirectAdmin Pre-Installation Tasks (replaces setup.sh)
directadmin_pre_install() {
  ## Update /etc/aliases
  if [ -e /etc/aliases ]; then
      COUNT=$(grep -c diradmin /etc/aliases)
      if [ "$COUNT" -eq 0 ]; then
          echo "diradmin: :blackhole:" >> /etc/aliases
      fi
      /usr/bin/newaliases
  fi

  ## Create the directory
  mkdir ${DA_PATH}

  ## Get DirectAdmin License
  if [ $DA_LAN -eq 0 ]; then
    ${WGET} --no-check-certificate -S -O ${DA_PATH}/update.tar.gz --bind-address=${DA_SERVER_IP} "https://www.directadmin.com/cgi-bin/daupdate?uid=${DA_USER_ID}&lid=${DA_LICENSE_ID}"
  elif [ $DA_LAN -eq 1 ]; then
    ${WGET} --no-check-certificate -S -O ${DA_PATH}/update.tar.gz "https://www.directadmin.com/cgi-bin/daupdate?uid=${DA_USER_ID}&lid=${DA_LICENSE_ID}"
  fi

  if [ ! -e ${DA_PATH}/update.tar.gz ]; then
    echo "Unable to download ${DA_PATH}/update.tar.gz";
    exit 3;
  fi

  COUNT=$(head -n 4 ${DA_PATH}/update.tar.gz | grep -c "* You are not allowed to run this program *");
  if [ "$COUNT" -ne 0 ]; then
    echo "";
    echo "You are not authorized to download the update package with that Client ID and License ID for this IP address. Please email sales@directadmin.com";
    exit 4;
  fi

  ## Extract update.tar.gz into /usr/local/directadmin:
  cd ${DA_PATH} || exit
  tar zxvf update.tar.gz

  ## See if the binary exists:
  if [ ! -e ${DA_PATH}/directadmin ]; then
    echo "Cannot find the DirectAdmin binary. Extraction failed";
    exit 5;
  fi

  ## These were in do_checks()
  ## Check for a separate /home partition (for quota support).
  #HOME_YES=`cat /etc/fstab | grep -c /home`;
  HOME_YES=$(grep -c /home < /etc/fstab)
  if [ "$HOME_YES" -lt "1" ]; then
    echo 'quota_partition=/' >> ${DA_CONF_TEMPLATE};
  fi

  ## Detect the ethernet interfaces that are available on the system (NOTE: can return more than 1 interface, even commented).
  ETH_DEV="$(grep ifconfig < /etc/rc.conf | cut -d= -f1 | cut -d_ -f2)"
  if [ "$ETH_DEV" != "" ]; then
    COUNT=$(grep -c ethernet_dev < $DA_CONF_TEMPLATE);
    if [ "$COUNT" -eq 0 ]; then
      echo ethernet_dev="${ETH_DEV}" >> ${DA_CONF_TEMPLATE};
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
}


## Install DirectAdmin (replaces scripts/install.sh)
## Create necessary users & groups
install_directadmin() {
  ## Add the DirectAdmin user & group:
  pw groupadd diradmin
  pw useradd -g diradmin -n diradmin -d /usr/local/directadmin -s /sbin/nologin

  ## Mail User & Group
  ## NOTE: FreeBSD already comes with a "mail" group (ID: 6)
  pw groupadd mail 2> /dev/null
  pw useradd -g mail -u 12 -n mail -d /var/mail -s /sbin/nologin 2> /dev/null

  ## NOTE: FreeBSD already includes a "ftp" group (ID: 14)
  # pw groupadd ftp 2> /dev/null
  # pw useradd -g ftp -n ftp -s /sbin/nologin 2> /dev/null

  ## Apache user/group creation (changed /var/www to /usr/local/www)
  ## NOTE: Using "apache" user instead of "www" for now
  pw groupadd apache 2> /dev/null
  pw useradd -g apache -n apache -d ${WWW_DIR} -s /sbin/nologin 2> /dev/null

  ## Set DirectAdmin Folder permissions:
  chmod 755 /usr/local/directadmin
  chown diradmin:diradmin /usr/local/directadmin

  ## Create directories and set permissions:
  mkdir -p /var/log/directadmin
  mkdir -p ${DA_PATH}/conf
  chown diradmin:diradmin ${DA_PATH}/*;
  chown diradmin:diradmin /var/log/directadmin;
  chmod 700 ${DA_PATH}/conf;
  chmod 700 /var/log/directadmin;

  #mkdir -p ${DA_PATH}/scripts/packages
  mkdir -p ${DA_PATH}/data/admin

  ## Set permissions
  chown -R diradmin:diradmin ${DA_PATH}/scripts/
  chown -R diradmin:diradmin ${DA_PATH}/data/

  ## No conf files in a fresh install:
  chown diradmin:diradmin ${DA_PATH}/conf/* 2> /dev/null > /dev/null;
  chmod 600 ${DA_PATH}/conf/* 2> /dev/null > /dev/null;

  ## Create User and Reseller Welcome message (need to download/copy these files):
  touch ${DA_PATH}/data/users/admin/u_welcome.txt
  touch ${DA_PATH}/data/admin/r_welcome.txt

  #Verify: Create backup.conf (wasn't created?)
  chown diradmin:diradmin ${DA_PATH}/data/users/admin/backup.conf

  ## Create logs directory:
  mkdir -p /var/log/httpd/domains
  chmod 700 /var/log/httpd

  ## NOTE: /home => /usr/home
  mkdir -p /home/tmp
  chmod 1777 /home/tmp
  chmod 711 /home

  SSHROOT=$(grep -c 'AllowUsers root' < /etc/ssh/sshd_config);
  if [ "${SSHROOT}" = 0 ]; then
    echo "AllowUsers root" >> /etc/ssh/sshd_config
    echo "AllowUsers ${DA_ADMIN_USERNAME}" >> /etc/ssh/sshd_config
    ## echo "AllowUsers YOUR_OTHER_ADMIN_ACCOUNT" >> /etc/ssh/sshd_config
    ## Set SSH folder permissions (is this needed?):
    # chmod 710 /etc/ssh
  fi
}

## DirectAdmin Post-Installation Tasks
directadmin_post_install() {
  mkdir -p ${DA_PATH}/data/users/admin/packages
  chown diradmin:diradmin ${DA_PATH}/data/users/admin/packages
  chmod 700 ${DA_PATH}/data/users/admin/packages
}


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

## Exim Pre-Installation Tasks
exim_pre_install() {
  mkdir -p ${VIRTUAL};
  chown ${EXIM_USER}:${EXIM_GROUP} ${VIRTUAL};
  chmod 755 ${VIRTUAL};

  ## replace $(hostname)
  hostname >> ${VIRTUAL}/domains;

  if [ ! -s ${VIRTUAL}/limit ]; then
    echo "${LIMIT_DEFAULT}" > ${VIRTUAL}/limit
  fi

  if [ ! -s ${VIRTUAL}/limit_unknown ]; then
    echo "${LIMIT_UNKNOWN}" > ${VIRTUAL}/limit_unknown
  fi

  chmod 755 ${VIRTUAL}/*
  mkdir ${VIRTUAL}/usage
  chmod 750 ${VIRTUAL}/usage

  for i in domains domainowners pophosts blacklist_domains whitelist_from use_rbl_domains bad_sender_hosts bad_sender_hosts_ip blacklist_senders whitelist_domains whitelist_hosts whitelist_hosts_ip whitelist_senders skip_av_domains skip_rbl_domains; do
    touch ${VIRTUAL}/$i;
    chmod 600 ${VIRTUAL}/$i;
  done

  chown ${EXIM_USER}:${EXIM_GROUP} ${VIRTUAL}/*;
}

## Exim Post-Installation Tasks
exim_post_install() {
  ## Set permissions
  chown -R ${EXIM_USER}:${EXIM_GROUP} /var/spool/exim

  ## Symlink for compat:
  ln -s ${EXIM_CONF} /etc/exim.conf

  ## Generate Self-Signed SSL Certificates
  ## See: http://help.directadmin.com/item.php?id=245
  /usr/bin/openssl req -x509 -newkey rsa:2048 -keyout /usr/local/etc/exim/exim.key -out /usr/local/etc/exim/exim.cert -days 9000 -nodes

  ln -s /usr/local/etc/exim/exim.key /etc/exim.key
  ln -s /usr/local/etc/exim/exim.cert /etc/exim.cert

  ## Set permissions:
  chown ${EXIM_USER}:${EXIM_GROUP} /usr/local/etc/exim/exim.key
  chmod 644 /usr/local/etc/exim/exim.key
  chmod 644 /usr/local/etc/exim/exim.cert

  ## Reference: Verify Exim config:
  exim -C ${EXIM_CONF} -bV

  setVal exim_enable \"YES\" /etc/rc.conf
  setVal exim_flags \"-bd -q1h\" /etc/rc.conf

  service exim start

  ## Tel DA new path to Exim binary.
  setVal mq_exim_bin "/usr/local/sbin/exim" >> ${DA_CONF}

  ## Replace sendmail programs with Exim binaries.
  ## There's another way to do this via mail/exim and typing "make something"
  if [ ! -e /etc/mail/mailer.conf ]; then
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


## SpamAssassin Pre-Installation Tasks
spamassassin_pre_install() {
  return;
}

## SpamAssassin Post-Installation Tasks
spamassassin_post_install() {
  setVal spamd_enable \"YES\" /etc/rc.conf
  setVal spamd_flags \"-c -m 15\" /etc/rc.conf
}

## Dovecot Pre-Installation Tasks
dovecot_pre_install() {
  return;
}

## Dovecot Post-Installation Tasks
dovecot_post_install() {
  ## Fetch latest config:
  wget -O ${DOVECOT_CONF} http://files.directadmin.com/services/custombuild/dovecot.conf.2.0

  ## Update directadmin.conf:
  echo "add_userdb_quota=1" >> ${DA_CONF}
  echo "dovecot=1" >> ${DA_CONF}

  ## Reference: doRestartDA:
  echo "action=rewrite&value=email_passwd" >> ${DA_TASK_QUEUE}
  #run_dataskq d

  ## Add Dovecot quota support to the directadmin.conf template:
  echo "add_userdb_quota=1" >> ${DA_CONF_TEMPLATE}

  ## Update dovecot.conf for SSL support using existing Apache 2.4 certs:
  # ssl_cert = <${APACHE_DIR}/ssl/server.crt
  # ssl_key = <${APACHE_DIR}/ssl/server.key

  ## or using existing Exim certs:
  # ssl_cert = </usr/local/etc/exim/exim.crt
  # ssl_key = </usr/local/etc/exim/exim.key

  ## or using your own custom certs:
  # ssl_cert = </usr/local/etc/ssl/server.crt
  # ssl_key = </usr/local/etc/ssl/server.key

  ## Prepare Dovecot directories:
  mkdir -p /etc/dovecot/
  mkdir -p ${DOVECOT_PATH}
  mkdir -p /usr/local/etc/dovecot/conf.d

  ## Symlink for compat:
  ln -s ${DOVECOT_CONF} /etc/dovecot/dovecot.conf
  # Skipped: ln -s /etc/dovecot/dovecot.conf /etc/dovecot.conf

  cp -rf ${DA_PATH}/custombuild/configure/dovecot/conf ${DOVECOT_PATH}

  echo "mail_plugins = \$mail_plugins quota" > ${DOVECOT_PATH}/conf/lmtp_mail_plugins.conf

  ## replace `hostname`
  ${PERL} -pi -e "s|HOSTNAME|`hostname`|" ${DOVECOT_PATH}/conf/lmtp.conf

  ## ltmp log files (not done):
  touch /var/log/dovecot-lmtp.log /var/log/dovecot-lmtp-errors.log
  chown root:wheel /var/log/dovecot-lmtp.log /var/log/dovecot-lmtp-errors.log
  chmod 600 /var/log/dovecot-lmtp.log /var/log/dovecot-lmtp-errors.log

  ## Modifications (done):
  ${PERL} -pi -e 's#transport = dovecot_lmtp_udp#transport = virtual_localdelivery#' /usr/local/etc/exim/exim.conf
  ${PERL} -pi -e 's/driver = shadow/driver = passwd/' ${DOVECOT_CONF}
  ${PERL} -pi -e 's/passdb shadow/passdb passwd/' ${DOVECOT_CONF}

  echo "mail_plugins = \$mail_plugins quota"            > ${DOVECOT_PATH}/conf/mail_plugins.conf
  echo "mail_plugins = \$mail_plugins quota imap_quota" > ${DOVECOT_PATH}/conf/imap_mail_plugins.conf

  # # Check for IPV6 compatability (not done):
  # if [ "${IPV6}" = "1" ]; then
  #   perl -pi -e 's|^listen = \*$|#listen = \*|' ${DOVECOT_PATH}/dovecot.conf
  #   perl -pi -e 's|^#listen = \*, ::$|listen = \*, ::|' ${DOVECOT_PATH}/dovecot.conf
  # else
  #   perl -pi -e 's|^#listen = \*$|listen = \*|' ${DOVECOT_PATH}/dovecot.conf
  #   perl -pi -e 's|^listen = \*, ::$|#listen = \*, ::|' ${DOVECOT_PATH}/dovecot.conf
  # fi

  echo "listen = *, ::" > /usr/local/etc/dovecot/conf/ip.conf

  setVal dovecot_enable \"YES\" /etc/rc.conf
}

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
}

## Ensure my.cnf
ensure_my_cnf() {
  #1 = path to cnf
  #2 = user
  #3 = pass
  #4 = optional source file to compare with. update 1 if 4 is newer.
  # host will be on the command line, as that's how DA already does it.

  E_MY_CNF=$1

  W=0
  if [ ! -s ${E_MY_CNF} ]; then
    W=1
  fi

  if [ "${W}" = "0" ] && [ "${4}" != "" ]; then
    if [ ! -s $4 ]; then
      echo "ensure_my_cnf: cannot find $4"
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

## Initialize SQL Parameters (copied from CB2)
get_sql_settings() {
  # MySQL settings
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
    HOSTNAME=$(hostname)
    MYSQL_ACCESS_HOST="$(grep -r -l -m1 '^status=server$' /usr/local/directadmin/data/admin/ips | cut -d/ -f8)"
    if [ "${MYSQL_ACCESS_HOST}" = "" ]; then
      MYSQL_ACCESS_HOST="$(grep -m1 ${HOSTNAME} /etc/hosts | awk '{print $1}')"
      if [ "${MYSQL_ACCESS_HOST}" = "" ]; then
        if [ -s "${WORKDIR}/scripts/setup.txt" ]; then
          MYSQL_ACCESS_HOST=$(grep -m1 -e '^ip=' "${WORKDIR}/scripts/setup.txt" | cut -d= -f2)
        fi
        if [ "${MYSQL_ACCESS_HOST}" = "" ]; then
          echo "Unable to detect your server IP in /etc/hosts. Please enter it: "
          read MYSQL_ACCESS_HOST
        fi
      fi
    fi
  fi

  #ensure_my_cnf ${DA_MYSQL_CNF} "${MYSQL_USER}" "${MYSQL_PASS}" "${DA_MYSQL_CONF}"
  chown diradmin:diradmin "${DA_MYSQL_CNF}"
}

## PHP Post-Installation Tasks
php_post_install() {
  ## Replace default php-fpm.conf with DirectAdmin/CB2 version:
  #cp -f /usr/local/directadmin/custombuild/configure/fpm/conf/php-fpm.conf.56 /usr/local/etc/php-fpm.conf

  PHP_PATH=/usr/local/php56

  ## Create CB2/DA directories for compat:
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

  ## Symlink for compat (replace php56 with your appropriate version):

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

  setVal php_fpm_enable \"YES\" /etc/rc.conf
}

## phpMyAdmin Post-Installation Tasks
phpmyadmin_post_install() {

  ## Reference for virtualhost entry:
  # Alias /phpmyadmin/ "/usr/local/www/phpMyAdmin/"
  # <Directory "/usr/local/www/phpMyAdmin/">
  #   Options None
  #   AllowOverride Limit
  #   Require local
  #   Require host .example.com
  # </Directory>

  ## Custom config from cb2/custom directory (if present):
  CUSTOM_PMA_CONFIG=${CWD}/custom/phpmyadmin/config.inc.php
  CUSTOM_PMA_THEMES=${CWD}/custom/phpmyadmin/themes

  ## Reference: Paths:

  #WWWDIR=/usr/local/www
  ##REALPATH=${WWWDIR}/phpMyAdmin-${PHPMYADMIN_VER}
  #REALPATH=${WWW_DIR}/phpMyAdmin
  ALIASPATH=${WWW_DIR}/phpmyadmin
  REAL_CONFIG_FILE=${PMA_DIR}/config.inc.php

  ## Scripted reference:

  ## If custom config exists
  if [ -e "${CUSTOM_PMA_CONFIG}" ]; then
    echo "Installing custom phpMyAdmin configuration file: ${CUSTOM_PMA_CONFIG}"
    cp -f "${CUSTOM_PMA_CONFIG}" ${PMA_DIR}/config.inc.php
  else
    cp -f ${PMA_DIR}/config.sample.inc.php ${PMA_DIR}/config.inc.php
    ${PERL} -pi -e "s#\['host'\] = 'localhost'#\['host'\] = '${MYSQLHOST}'#" ${PMA_DIR}/config.inc.php
    ${PERL} -pi -e "s#\['host'\] = ''#\['host'\] = '${MYSQLHOST}'#" ${PMA_DIR}/config.inc.php
    ${PERL} -pi -e "s#\['auth_type'\] = 'cookie'#\['auth_type'\] = 'http'#" ${PMA_DIR}/config.inc.php
    ${PERL} -pi -e "s#\['extension'\] = 'mysql'#\['extension'\] = 'mysqli'#" ${PMA_DIR}/config.inc.php
  fi

  ## Copy sample config:
  cp ${PMA_DIR}/config.sample.inc.php ${PMA_DIR}/config.inc.php

  ## Update phpMyAdmin configuration file:
  ${PERL} -pi -e "s#\['host'\] = 'localhost'#\['host'\] = 'localhost'#" ${PMA_DIR}/config.inc.php
  ${PERL} -pi -e "s#\['host'\] = ''#\['host'\] = 'localhost'#" ${PMA_DIR}/config.inc.php
  ${PERL} -pi -e "s#\['auth_type'\] = 'cookie'#\['auth_type'\] = 'http'#" ${PMA_DIR}/config.inc.php
  ${PERL} -pi -e "s#\['extension'\] = 'mysql'#\['extension'\] = 'mysqli'#" ${PMA_DIR}/config.inc.php

  # Copy custom themes:
  if [ -d "${CUSTOM_PMA_THEMES}" ]; then
    echo "Installing custom PhpMyAdmin themes: ${PMA_THEMES}"
    cp -Rf "${CUSTOM_PMA_THEMES}" ${PMA_DIR}
  fi

  ## Update alias path via symlink (not done):
  rm -f ${ALIASPATH} >/dev/null 2>&1
  ln -s ${PMA_DIR} ${ALIASPATH}

  ## Create logs directory:
  if [ ! -d ${PMA_DIR}/log ]; then
    mkdir -p ${PMA_DIR}/log
  fi

  ## Set permissions:
  chown -R ${WEBAPPS_USER}:${WEBAPPS_GROUP} ${PMA_DIR}
  chown -h ${WEBAPPS_USER}:${WEBAPPS_GROUP} ${ALIASPATH}
  chmod 755 ${PMA_DIR}


  ## Set permissions (same as above, remove this):
  chown -R ${WEBAPPS_USER}:${WEBAPPS_GROUP} ${PMA_DIR}
  chown -h ${WEBAPPS_USER}:${WEBAPPS_GROUP} ${PMA_DIR}
  chmod 755 ${PMA_DIR}

  ## Symlink:
  ln -s ${PMA_DIR} ${WWW_DIR}/phpmyadmin
  ln -s ${PMA_DIR} ${WWW_DIR}/pma

  ## verify:

  # Disable scripts directory (path doesn't exist):
  if [ -d ${PMA_DIR}/scripts ]; then
    chmod 000 ${PMA_DIR}/scripts
  fi

  # Disable setup directory (done):
  if [ -d ${PMA_DIR}/setup ]; then
    chmod 000 ${PMA_DIR}/setup
  fi

  ## Auth log patch for BFM compat (not done):
  # Currently outputs to /var/log/auth.log
  #getFile patches/pma_auth_logging.patch pma_auth_logging.patch
  ${WGET} -O "${PB_DIR}/patches/pma_auth_logging.patch" "${PB_MIRROR}/patches/pma_auth_logging.patch"

  if [ -e patches/pma_auth_logging.patch ]; then
    echo "Patching phpMyAdmin to log failed authentications for BFM..."
    cd ${PMA_DIR} || exit
    patch -p0 < "${WORKDIR}/patches/pma_auth_logging.patch"
  fi

  ## Update /etc/groups (verify):
  #access:*:1164:apache,nobody,mail,majordomo,daemon,clamav
}

## Apache Post-Installation Tasks
apache_post_install() {
  ## Symlink for backwards compatability:
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

  ## NOTE: Careful with this, paths are relative
  /usr/bin/openssl req -x509 -newkey rsa:2048 -keyout ${APACHE_DIR}/ssl/server.key -out ${APACHE_DIR}/ssl/server.crt -days 9999 -nodes -config ./custom/ap2/cert_config.txt

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

  ## Rewrite Apache 2.4 configuration files
  ## Perhaps skip this? No need I think -sg

  ##cd /usr/local/directadmin/custombuild
  ##./build rewrite_confs

  ## Update /boot/loader.conf:
  setVal accf_httpd_load \"YES\" /boot/loader.conf
  setVal accf_data_load \"YES\" /boot/loader.conf

  setVal apache24_enable \"YES\" /etc/rc.conf
  setVal apache24_http_accept_enable \"YES\" /etc/rc.conf
}


## Nginx Pre-Installation Tasks
nginx_pre_install() {
  return;
}

## Nginx Post-Installation Tasks
nginx_post_install() {
  ## Update directadmin.conf
  nginxconf=/usr/local/etc/nginx/directadmin-vhosts.conf
  nginxlogdir=/var/log/nginx/domains
  nginxips=/usr/local/etc/nginx/directadmin-ips.conf
  nginx_pid=/var/run/nginx.pid
  nginx_cert=/usr/local/etc/nginx/ssl/server.crt
  nginx_key=/usr/local/etc/nginx/ssl/server.key
  nginx_ca=/usr/local/etc/nginx/ssl/server.ca
}

## ClamAV Post-Installation Tasks
clamav_post_install() {
  setVal clamav_clamd_enable \"YES\" /etc/rc.conf
  setVal clamav_freshclam_enable \"YES\" /etc/rc.conf
}

## RoundCube Pre-Installation Tasks
roundcube_pre_install() {
  return;
}

setup_roundcube() {

  ## Clarifications
  # _CONF = RC's config.inc.php
  # _CNF  = MySQL settings
  # _PATH = path to RC

  #ensure_webapps_logrotate

  ## Fetch MySQL Settings from directadmin/conf/my.cnf
  get_sql_settings

  #REALPATH=/usr/local/www/roundcube
  ALIASPATH=${WWW_DIR}/roundcube

  ROUNDCUBE_PATH=${WWW_DIR}/roundcube

  ## Create & generate credentials for the database:
  ROUNDCUBE_DB=da_roundcube
  ROUNDCUBE_DB_USER=da_roundcube
  ROUNDCUBE_DB_PASS=$(random_pass 12)
  ROUNDCUBE_DES_KEY=$(random_pass 24)
  ROUNDCUBE_MY_CNF=${ROUNDCUBE_PATH}/config/my.cnf

  # if [ -e ${ROUNDCUBE_PATH} ]; then
  #     if [ -d ${ROUNDCUBE_PATH}/logs ]; then
  #         cp -fR ${ROUNDCUBE_PATH}/logs ${ROUNDCUBE_PATH} >/dev/null 2>&1
  #     fi
  #     if [ -d ${ROUNDCUBE_PATH}/temp ]; then
  #         cp -fR ${ROUNDCUBE_PATH}/temp ${ROUNDCUBE_PATH} >/dev/null 2>&1
  #     fi
  # fi

  ##link it from a fake path:
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
        for access_host_ip in `grep '^access_host.*=' ${DA_MYSQL_CONF} | cut -d= -f2`; do {
          ${MYSQL} --defaults-extra-file=${DA_MYSQL_CNF} -e "GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,ALTER,LOCK TABLES,INDEX ON ${ROUNDCUBE_DB}.* TO '${ROUNDCUBE_DB_USER}'@'${access_host_ip}' IDENTIFIED BY '${ROUNDCUBE_DB_PASS}';" --host=${MYSQL_HOST} 2>&1
        }; done
      fi

      ## Needed?
      rm -f ${ROUNDCUBE_MY_CNF}
      #ensure_my_cnf ${ROUNDCUBE_MY_CNF} "${ROUNDCUBE_DB_USER}" "${ROUNDCUBE_DB_PASS}"

      ## Import RoundCube's initial.sql file to create the necessary database tables.
      ${MYSQL} --defaults-extra-file=${ROUNDCUBE_MY_CNF} -e "use ${ROUNDCUBE_DB}; source SQL/mysql.initial.sql;" --host=${MYSQL_HOST} 2>&1

      echo "Database created, ${ROUNDCUBE_DB_USER} password is ${ROUNDCUBE_DB_PASS}"
    else
      echo "Cannot find the SQL directory in ${ROUNDCUBE_PATH}"
      exit 0
    fi
  else
    ## RoundCube database already exists:
    if [ -e "${ROUNDCUBE_CONF}" ]; then
      COUNT_MYSQL=$(grep -m1 -c 'mysql://' ${ROUNDCUBE_CONF})
      if [ "${COUNT_MYSQL}" -gt 0 ]; then
          PART1="$(grep -m1 "\$config\['db_dsnw'\]" ${ROUNDCUBE_CONF} | awk '{print $3}' | cut -d\@ -f1 | cut -d'/' -f3)"
          ROUNDCUBE_DB_USER="$(echo ${PART1} | cut -d\: -f1)"
          ROUNDCUBE_DB_PASS="$(echo ${PART1} | cut -d\: -f2)"
          PART2="$(grep -m1 "\$config\['db_dsnw'\]" ${ROUNDCUBE_CONF} | awk '{print $3}' | cut -d\@ -f2 | cut -d\' -f1)"
          MYSQL_ACCESS_HOST="$(echo ${PART2} | cut -d'/' -f1)"
          ROUNDCUBE_DB="$(echo ${PART2} | cut -d'/' -f2)"
      fi
    fi

    ${MYSQL} --defaults-extra-file=${DA_MYSQL_CNF} -e "GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,ALTER,LOCK TABLES,INDEX ON ${ROUNDCUBE_DB}.* TO '${ROUNDCUBE_DB_USER}'@'${MYSQL_ACCESS_HOST}' IDENTIFIED BY '${ROUNDCUBE_DB_PASS}';" --host=${MYSQL_HOST} 2>&1
    ${MYSQL} --defaults-extra-file=${DA_MYSQL_CNF} -e "SET PASSWORD FOR '${ROUNDCUBE_DB_USER}'@'${MYSQL_ACCESS_HOST}' = PASSWORD('${ROUNDCUBE_DB_PASS}');" --host=${MYSQL_HOST}

    if [ "${MYSQL_HOST}" != "localhost" ]; then
      for access_host_ip in `grep '^access_host.*=' ${DA_MYSQL_CONF} | cut -d= -f2`; do {
        ${MYSQL} --defaults-extra-file=${DA_MYSQL_CNF} -e "GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,ALTER,LOCK TABLES,INDEX ON ${ROUNDCUBE_DB}.* TO '${ROUNDCUBE_DB_USER}'@'${access_host_ip}' IDENTIFIED BY '${ROUNDCUBE_DB_PASS}';" --host=${MYSQL_HOST} 2>&1
        ${MYSQL} --defaults-extra-file=${DA_MYSQL_CNF} -e "SET PASSWORD FOR '${ROUNDCUBE_DB_USER}'@'${access_host_ip}' = PASSWORD('${ROUNDCUBE_DB_PASS}');" --host=${MYSQL_HOST} 2>&1
      }; done
    fi

    #in case anyone uses it for backups
    rm -f ${ROUNDCUBE_MY_CNF}
    #ensure_my_cnf ${ROUNDCUBE_MY_CNF} "${ROUNDCUBE_DB_USER}" "${ROUNDCUBE_DB_PASS}"
  fi

  # Cleanup config
  #rm -f ${ROUNDCUBE_CONF}

  ## Install the proper config:
  if [ -d ../roundcube ]; then
    echo "Editing roundcube configuration..."

    cd ${ROUNDCUBE_PATH}/config || exit

    if [ -e "${ROUNDCUBE_CONFIG}" ]; then
      echo "Installing custom RoundCube Config: ${ROUNDCUBE_CONFIG}"
     cp -f ${ROUNDCUBE_CONFIG} ${ROUNDCUBE_CONF}
    fi

    if [ -e "${ROUNDCUBE_CONFIG_DB}" ]; then
      if [ ! -e ${EDIT_DB} ]; then
        /bin/cp -f "${ROUNDCUBE_CONFIG_DB}" ${EDIT_DB}
      fi
      if [ "${COUNT_MYSQL}" -eq 0 ]; then
        echo "\$config['db_dsnw'] = 'mysql://${ROUNDCUBE_DB_USER}:${ROUNDCUBE_DB_PASS}@${MYSQLHOST}/${ROUNDCUBE_DB}';" >> ${EDIT_DB}
      fi
    else
      if [ ! -e ${EDIT_DB} ]; then
        /bin/cp -f ${DB_DIST} ${EDIT_DB}
        ${PERL} -pi -e "s|mysql://roundcube:pass\@localhost/roundcubemail|mysql://${ROUNDCUBE_DB_USER}:\\Q${ROUNDCUBE_DB_PASS}\\E\@${MYSQL_HOST}/${ROUNDCUBE_DB}|" ${EDIT_DB} > /dev/null
        ${PERL} -pi -e "s/\'mdb2\'/\'db\'/" ${EDIT_DB} > /dev/null
      fi
    fi

    SPAM_INBOX_PREFIX_OPT=$(getDA_Opt spam_inbox_prefix 1)
    SPAM_FOLDER="INBOX.spam"

    if [ "${SPAM_INBOX_PREFIX_OPT}" = "0" ]; then
        SPAM_FOLDER="Junk"
    fi

    ${PERL} -pi -e "s|rcmail-\!24ByteDESkey\*Str|\\Q${ROUNDCUBE_DES_KEY}\\E|" ${ROUNDCUBE_CONF}

    if [ ! -e "${ROUNDCUBE_CONF}" ]; then
      #default_host is set to localhost by default in RC 1.0.0, so we don't echo it to the file

      # These ones are already in config.inc.php.sample file, so we just use perl-regex to change them
      ${PERL} -pi -e "s|\['smtp_port'] = 25|\['smtp_port'] = 587|" ${ROUNDCUBE_CONF} > /dev/null
      ${PERL} -pi -e "s|\['smtp_server'] = ''|\['smtp_server'] = 'localhost'|" ${ROUNDCUBE_CONF} > /dev/null
      ${PERL} -pi -e "s|\['smtp_user'] = ''|\['smtp_user'] = '%u'|" ${ROUNDCUBE_CONF} > /dev/null
      ${PERL} -pi -e "s|\['smtp_pass'] = ''|\['smtp_pass'] = '%p'|" ${ROUNDCUBE_CONF} > /dev/null

      #Changing default options, that are set in defaults.inc.php
      #IMAP folders
      if [ "${WEBAPPS_INBOX_PREFIX_OPT}" = "yes" ]; then
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

      if grep -q '^recipients_max' ${EXIM_CONF}; then
        RECIPIENTS_MAX="$(grep -m1 '^recipients_max' /etc/exim.conf | cut -d= -f2 | tr -d ' ')"
        echo "\$config['max_recipients'] = ${RECIPIENTS_MAX};" >> ${ROUNDCUBE_CONF}
        echo "\$config['max_group_members'] = ${RECIPIENTS_MAX};" >> ${ROUNDCUBE_CONF}
      fi

      if [ ! -s mime.types ]; then
        #if [ "${WEBSERVER_OPT}" = "apache" ] || [ "${WEBSERVER_OPT}" = "litespeed" ] || [ "${WEBSERVER_OPT}" = "nginx_apache" ]; then
          if [ -s ${APACHE_MIME_TYPES} ]; then
            if grep -m1 -q 'application/java-archive' ${APACHE_MIME_TYPES}; then
              cp -f ${APACHE_MIME_TYPES} ./mime.types
            fi
          fi
        #fi
      fi

      if [ ! -s mime.types ]; then
        wget ${WGET_CONNECT_OPTIONS} -O mime.types http://svn.apache.org/repos/asf/httpd/httpd/trunk/docs/conf/mime.types 2> /dev/null
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

        if [ -e /usr/local/directadmin/directadmin ]; then
          DA_PORT=$(/usr/local/directadmin/directadmin c | grep -m1 -e '^port=' | cut -d= -f2)
          ${PERL} -pi -e "s|\['password_directadmin_port'] = 2222|\['password_directadmin_port'] = $DA_PORT|" ${ROUNDCUBE_CONF} > /dev/null

          DA_SSL=$(/usr/local/directadmin/directadmin c | grep -m1 -e '^ssl=' | cut -d= -f2)
          if [ "$DA_SSL" -eq 1 ]; then
            ${PERL} -pi -e "s|\['password_directadmin_host'] = 'tcp://localhost'|\['password_directadmin_host'] = 'ssl://localhost'|" ${ROUNDCUBE_CONF} > /dev/null
          fi
        fi
        cd ${ROUNDCUBE_PATH}/config || exit
      fi

          # Pigeonhole plugin
          if [ "${PIGEONHOLE_OPT}" = "yes" ]; then
              if [ -d ${ROUNDCUBE_PATH}/plugins/managesieve ]; then

                  if [ `grep -m1 -c "'managesieve'" ${ROUNDCUBE_CONF}` -eq 0 ]; then
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

      if [ -d ${ROUNDCUBE_PLUGINS} ]; then
          echo "Copying files from ${ROUNDCUBE_PLUGINS} to ${ROUNDCUBE_PATH}/plugins"
          cp -Rp ${ROUNDCUBE_PLUGINS}/* ${ROUNDCUBE_PATH}/plugins
      fi

      if [ -d ${ROUNDCUBE_SKINS} ]; then
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

      echo "Roundcube ${ROUNDCUBE_VER} has been installed successfully."
  fi

  #systems with "system()" in disable_functions need to use no php.ini:
  if [ "`have_php_system`" = "0" ]; then
      ${PERL} -pi -e 's#^\#\!/usr/bin/env php#\#\!/usr/local/bin/php \-n#' "${ROUNDCUBE_PATH}/bin/update.sh"
  fi

  # Systems with suhosin cannot have PHP memory_limit set to -1, we need not to load suhosin for RoundCube .sh scripts
  if [ "${SUHOSIN_OPT}" = "yes" ]; then
      ${PERL} -pi -e 's#^\#\!/usr/bin/env php#\#\!/usr/local/bin/php \-n#' ${ROUNDCUBE_PATH}/bin/msgimport.sh
      ${PERL} -pi -e 's#^\#\!/usr/bin/env php#\#\!/usr/local/bin/php \-n#' ${ROUNDCUBE_PATH}/bin/indexcontacts.sh
      ${PERL} -pi -e 's#^\#\!/usr/bin/env php#\#\!/usr/local/bin/php \-n#' ${ROUNDCUBE_PATH}/bin/msgexport.sh
  fi

  # Update if needed
  ${ROUNDCUBE_PATH}/bin/update.sh '--version=?'

  # Cleanup
  rm -rf ${ROUNDCUBE_PATH}/installer

  #set the permissions:
  chown -R ${WEBAPPS_USER}:${WEBAPPS_USER} ${ROUNDCUBE_PATH}
  if [ "${WEBAPPS_GROUP}" = "apache" ]; then
      chown -R apache ${ROUNDCUBE_PATH}/temp ${ROUNDCUBE_PATH}/logs
      /bin/chmod -R 770 ${ROUNDCUBE_PATH}/temp
      /bin/chmod -R 770 ${ROUNDCUBE_PATH}/logs
  fi

  # Secure configuration file
  if [ -s ${EDIT_DB} ]; then
      chmod 440 ${EDIT_DB}
      if [ "${WEBAPPS_GROUP}" = "apache" ]; then
          echo "**********************************************************************"
          echo "* "
          echo "* ${boldon}SECURITY: ${ROUNDCUBE_PATH}/config/${EDIT_DB} is readable by apache.${boldoff}"
          echo "* Recommended: use a php type that runs php scripts as the User, then re-install roundcube."
          echo "*"
          echo "**********************************************************************"
      fi

      chown ${WEBAPPS_USER}:${WEBAPPS_GROUP} ${EDIT_DB}

      if [ "${WEBAPPS_GROUP}" = "apache" ]; then
          ls -la ${ROUNDCUBE_PATH}/config/${EDIT_DB}
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

  ensure_webapps_tmp

  #cd ${CWD}
}


## RoundCube Post-Installation Tasks
roundcube_post_install() {
  return;
}

## Webapps Pre-Installation Tasks
webapps_pre_install() {
  ## Create user and group:
  pw groupadd ${WEBAPPS_GROUP}
  pw useradd -g ${WEBAPPS_GROUP} -n ${WEBAPPS_USER} -b ${WWW_DIR} -s /sbin/nologin

  ## Set permissions on temp directory:
  chmod 777 ${WWW_DIR}/tmp

  ## Temp path: /usr/local/www/webmail/tmp
  ## Create webmail/tmp directory:
  mkdir -p ${WWW_DIR}/webmail/tmp
  chmod -R 770 ${WWW_DIR}/webmail/tmp;
  chown -R ${WEBAPPS_USER}:${WEBAPPS_GROUP} ${WWW_DIR}/webmail
  chown -R ${APACHE_USER}:${WEBAPPS_GROUP} ${WWW_DIR}/webmail/tmp;
  echo "Deny from All" >> ${WWW_DIR}/webmail/temp/.htaccess
}

## Webapps Post-Installation Tasks
webapps_post_install() {
  ## Increase the timeout from 10 minutes to 24
  ${PERL} -pi -e 's/idle_timeout = 10/idle_timeout = 24/' "${DEST}/webmail/inc/config.security.php"

  ${PERL} -pi -e 's#\$temporary_directory = "./database/";#\$temporary_directory = "./tmp/";#' "${DEST}/webmail/inc/config.php"
  ${PERL} -pi -e 's/= "ONE-FOR-EACH";/= "ONE-FOR-ALL";/' "${DEST}/webmail/inc/config.php"
  ${PERL} -pi -e 's#\$smtp_server = "SMTP.DOMAIN.COM";#\$smtp_server = "localhost";#' "${DEST}/webmail/inc/config.php"
  # ${PERL} -pi -e 's#\$default_mail_server = "POP3.DOMAIN.COM";#\$default_mail_server = "localhost";#' "${DEST}/webmail/inc/config.php"
  ${PERL} -pi -e 's/POP3.DOMAIN.COM/localhost/' "${DEST}/webmail/inc/config.php"

  rm -rf "${DEST}/webmail/install"

  ## Copy redirect.php (done):
  cp -f ${DA_PATH}/scripts/redirect.php ${WWW_DIR}/redirect.php
}

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


## Ensure Webapps php.ini (copied from CB2)
verify_webapps_php_ini() {
  # ${PHP_INI_WEBAPPS}
  # ${WWW_TMP_DIR}

  # if [ "${PHP1_MODE_OPT}" = "mod_php" ]; then
  #     WEBAPPS_INI=/usr/local/lib/php.conf.d/50-webapps.ini
  #     mkdir -p /usr/local/lib/php.conf.d
  # else
  #     WEBAPPS_INI=/usr/local/php${PHP1_SHORTRELEASE}/lib/php.conf.d/50-webapps.ini
  #     mkdir -p /usr/local/php${PHP1_SHORTRELEASE}/lib/php.conf.d
  # fi

  ## Copy custom/ file
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

## Ensure Webapps tmp (copied from CB2)
verify_webapps_tmp() {
  if [ ! -d "{$WWW_TMP_DIR}" ]; then
    mkdir -p ${WWW_TMP_DIR}
  fi

  chmod 770 ${WWW_TMP_DIR}
  chown ${WEBAPPS_USER}:${WEBAPPS_GROUP} ${WWW_TMP_DIR}

  verify_webapps_php_ini
}

## Apache Host Configuration (copied from CB2)
do_ApacheHostConf() {
  HOSTCONF=${APACHE_DIR}/extra/httpd-hostname.conf

  ## Set this for now since PB only supports 1 instance of PHP.
  PHP1_MODE_OPT="php-fpm"
  PHP1_MODE="FPM"
  PHP1_VERSION="56"

  ## Copy custom/ file
  if [ -e "${WORKDIR}/custom/ap2/conf/extra/httpd-hostname.conf" ]; then
    cp -pf "${WORKDIR}/custom/ap2/conf/extra/httpd-hostname.conf" ${HOSTCONF}
  else
    echo '' > ${HOSTCONF}

    # if [ "${HAVE_FPM_CGI}" = "yes" ]; then
    #   echo 'SetEnvIfNoCase ^Authorization$ "(.+)" HTTP_AUTHORIZATION=$1' >> ${HOSTCONF}
    # fi

    echo "<Directory ${WWW_DIR}>" >> ${HOSTCONF}

    if [ "${PHP1_MODE}" = "FPM" ]; then
      {
        echo '<FilesMatch "\.(inc|php|php3|php4|php44|php5|php52|php53|php54|php55|php56|php70|php6|phtml|phps)$">';
        echo "AddHandler \"proxy:unix:/usr/local/php${PHP1_VERSION}/sockets/webapps.sock|fcgi://localhost\" .inc .php .php5 .php${PHP1_VERSION} .phtml";
        echo "</FilesMatch>";
      } >> ${HOSTCONF}
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
    } >> ${HOSTCONF}
    # echo '    <IfModule mod_ruid2.c>'                 >> ${HOSTCONF}
    # echo '        RUidGid webapps webapps'            >> ${HOSTCONF}
    # echo '    </IfModule>'                            >> ${HOSTCONF}
    # echo '    <IfModule mod_lsapi.c>'                 >> ${HOSTCONF}
    # echo '        lsapi_user_group webapps webapps'   >> ${HOSTCONF}
    # echo '    </IfModule>'                            >> ${HOSTCONF}

    ensure_webapps_tmp

    # WEBAPPS_FCGID_DIR=/var/www/fcgid
    SUEXEC_PER_DIR="0"

    if [ -s /usr/local/sbin/suexec ]; then
      SUEXEC_PER_DIR="$(/usr/local/sbin/suexec -V 2>&1 | grep -c 'AP_PER_DIR')"
    fi

    # if [ "${PHP1_MODE_OPT}" = "fastcgi" ]; then
    #   echo '  <IfModule mod_fcgid.c>' >> ${HOSTCONF}
    #   echo "      FcgidWrapper /usr/local/safe-bin/fcgid${PHP1_VERSION}.sh .php" >> ${HOSTCONF}
    #   if [ "${SUEXEC_PER_DIR}" -gt 0 ]; then
    #       echo '    SuexecUserGroup webapps webapps' >> ${HOSTCONF}
    #   fi
    #   echo '      <FilesMatch "\.(inc|php|php3|php4|php44|php5|php52|php53|php54|php55|php56|php70|php6|phtml|phps)$">' >> ${HOSTCONF}
    #   echo '          Options +ExecCGI' >> ${HOSTCONF}
    #   echo '          AddHandler fcgid-script .php' >> ${HOSTCONF}
    #   echo '      </FilesMatch>' >> ${HOSTCONF}
    #   echo '  </IfModule>' >> ${HOSTCONF}
    # fi

    # if [ "${PHP2_MODE_OPT}" = "fastcgi" ] && [ "${PHP2_RELEASE_OPT}" != "no" ]; then
    #   echo '  <IfModule mod_fcgid.c>' >> ${HOSTCONF}
    #   echo "      FcgidWrapper /usr/local/safe-bin/fcgid${PHP2_SHORTRELEASE}.sh .php${PHP2_SHORTRELEASE}" >> ${HOSTCONF}
    #   if [ "${SUEXEC_PER_DIR}" -gt 0 ]; then
    #   echo '      SuexecUserGroup webapps webapps' >> ${HOSTCONF}
    #   fi
    #   echo "   <FilesMatch \"\.php${PHP2_SHORTRELEASE}\$\">" >> ${HOSTCONF}
    #   echo '          Options +ExecCGI' >> ${HOSTCONF}
    #   echo "          AddHandler fcgid-script .php${PHP2_SHORTRELEASE}" >> ${HOSTCONF}
    #   echo '      </FilesMatch>' >> ${HOSTCONF}
    #   echo '  </IfModule>' >> ${HOSTCONF}
    # fi

    echo "</Directory>" >> ${HOSTCONF}
  fi
}

## Setup Brute-Force Monitor
setup_bfm() {
  ## Defaults:
  # brute_force_roundcube_log=/var/www/html/roundcube/logs/errors
  # brute_force_squirrelmail_log=/var/www/html/squirrelmail/data/squirrelmail_access_log
  # brute_force_pma_log=/var/www/html/phpMyAdmin/log/auth.log
  brute_force_roundcube_log=${WWW_DIR}/roundcube/logs/errors
  brute_force_squirrelmail_log=${WWW_DIR}/squirrelmail/data/squirrelmail_access_log
  brute_force_pma_log=${WWW_DIR}/phpMyAdmin/log/auth.log

  #pure_pw=/usr/bin/pure-pw
}

## DirectAdmin Install
exec_da_install() {
  cd ${DA_PATH} || exit
  ./directadmin i
}

## DirectAdmin Permissions
exec_da_permissions() {
  cd ${DA_PATH} || exit
  ./directadmin p
}

## Install Application
## $1 = name of service
## e.g. install_app exim
install_app() {
  ## add func() to update make.conf, or config via CLI

  case "$1" in
    "directadmin")
      directadmin_pre_install
      directadmin_post_install
      ;;
    "apache")
      portmaster -d ${PORT_APACHE24}
      ;;
    "nginx")
      portmaster -d ${PORT_NGINX}
      ;;
    "php55")
      portmaster -d ${PORT_PHP55}
      ;;
    "php56")
      portmaster -d ${PORT_PHP56}
      ;;
    "ioncube")
      pkgi ${PORT_IONCUBE}
      ;;
    "roundcube")
      roundcube_pre_install
      portmaster -d ${PORT_ROUNDCUBE}
      roundcube_post_install
      ;;
    "spamassassin")
      portmaster -d ${PORT_SPAMASSASSIN}
      spamassassin_post_install
      ;;
    "libspf2") ;;
    "dkim") ;;
    "blockcracking") ;;
    "easy_spam_fighter") ;;
    "exim")
      exim_pre_install
      portmaster -d ${PORT_EXIM}
      exim_post_install
      ;;
    "mariadb55")
      # portmaster -d ${PORT_MARIADB55}
      pkg install -y ${PORT_MARIADB55} databases/mariadb55-client
      ;;
    "mariadb100")
      # portmaster -d ${PORT_MARIADB100}
      pkg install -y ${PORT_MARIADB100} databases/mariadb100-client
      ;;
    "mysql55")
      # portmaster -d ${PORT_MYSQL55}
      pkg install -y ${PORT_MYSQL55} databases/mysql55-client
      ;;
    "mysql56")
      # portmaster -d ${PORT_MYSQL56}
      pkg install -y ${PORT_MYSQL56} databases/mysql56-client
      ;;
    "phpmyadmin")
      phpmyadmin_pre_install
      portmaster -d ${PORT_PHPMYADMIN}
      phpmyadmin_post_install
      ;;
    "pureftpd")
      portmaster -d ${PORT_PUREFTPD}
      ;;
    "proftpd")
      portmaster -d ${PORT_PROFTPD}
      ;;
    "bfm")
      setup_bfm
      ;;
  esac
}

## Uninstall Application
## $1 = name of service
## e.g. uninstall_app exim
uninstall_app() {
  return;
}

## Update PortsBuild
update() {
echo "script update"
# wget
}


## ./portsbuild selection screen
case "$1" in
  "")
  echo "portsbuild 1.0"
  echo "Usage: ./portsbuild.sh <command>"
  echo "where <command> can be:"
  echo " install"
  echo " setup"
  echo " update"
  echo " verify"
  echo " outdated"
  echo " version"
  ;;
  # create_options)  ;;
  # set)  ;;
  # check_options) ;;
  install) install ;; ## install PB+DirectAdmin
  setup) setup ;; ## (alias for 'install'?)
  update) update ;; ## update PB script
  verify) verify ;; ## verify system state
  version) show_version ;;
  all) ;;
esac

################################################################

## EOF
