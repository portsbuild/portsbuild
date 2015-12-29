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

OS=`uname`
OS_VER=`uname -r | cut -d- -f1` # 9.3, 10.1, 10.2
OS_B64=`uname -m | grep -c 64`  # 0, 1
OS_MAJ=`uname -r | cut -d. -f1` # 9, 10

OS_HOST=`hostname`;
OS_DOMAIN=`echo $OS_HOST | cut -d. -f2,3,4,5,6`

if [ ${OS} = "FreeBSD" ]; then
    if [ ${OS_B64} -eq 1 ]; then
        if [ "$OS_VER" = "10.1" ] || [ "$OS_VER" = "10.2" ] || [ "$OS_VER" = "9.3" ]; then
            echo "FreeBSD $OS_VER x64 operating system detected.";
        else
            echo "Warning: Unsupported FreeBSD operating system detected."
            echo "PortsBuild is tested to work with FreeBSD versions 9.3, 10.1 and 10.2 amd64 only.";
            echo "You can press CTRL+C within 5 seconds to quit the PortsBuild script now, or proceed at your own risk.";
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

## Source (include) additional files.
. conf/defaults.conf
. conf/ports.conf
. conf/options.conf
#. conf/discover.conf
#. conf/make.conf

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
        setup_ports
    fi
fi

################################################################

## Get DA Options (copied from CB2)
getDA_Opt() {
    #$1 is option name
    #$2 is default value

    if [ ! -s ${DA_CONF_FILE} ]; then
        echo $2
        return
    fi

    if ! ${DA_BIN} c | grep -m1 -q -e "^$1="; then
        echo $2
        return
    fi

    ${DA_BIN} c | grep -m1 "^$1=" | cut -d= -f2
}

## Get Option (copied from CB2)
## Used to retrieve CB/PB options.conf
getOpt() {
    ## $1 = option name
    ## $2 = default value

    # CB2: Added "grep -v" to workaround many lines with empty options
    GET_OPTION="`grep -v "^$1=$" ${OPTIONS_CONF} | grep -m1 "^$1=" | cut -d= -f2`"
    if [ "${GET_OPTION}" = "" ]; then
        echo "$1=$2" >> ${OPTIONS_CONF}
    fi

    echo ${GET_OPTION}
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
        VAR=`echo $1 | tr "[a-z]" "[A-Z]"`
        if [ -z "$(eval_var ${VAR}_DEF)" ]; then
            echo "${1} is not a valid option."
            #EXIT_CODE=50
            return
        fi
        VALID="no"
        for i in $(eval_var ${VAR}_SET); do
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
        OPT_VALUE="`grep -m1 "^$1=" ${OPTIONS_CONF} | cut -d= -f2`"
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
    if [ ! -e $3 ]; then
        return
    fi

    ## Can't put [brackets] around the statement else grep flips out.
    if ! grep -m1 -q ${1}= ${3} ; then
        ## It's not there, so add it.
        echo "$1=$2" >> $3
        return
    else
        ## The value is already in the file $3, so use perl regex to replace it.
        ${PERL} -pi -e "s/`grep ${1}= ${3}`/${1}=${2}/" ${3}
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
    setVal ${1}_enable \"YES\" /etc/rc.conf
}

## Disable a service in /etc/rc.conf
service_off() {
    setVal ${1}_enable \"NO\" /etc/rc.conf
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
    ${PKG} install -y $1
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
    tr -cd 'a-zA-Z0-9' < /dev/urandom 2>/dev/null | head -c${1:-`perl -le 'print int rand(7) + 10'`}
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
            if [ $? eq 0 ]; then
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

    if [ OPT_INSTALL_CCACHE = "YES" ]; then
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
    if [ ${OS_MAJ} -eq 10 ]; then
        /usr/sbin/pkg install -y devel/gmake lang/perl5.20 ftp/wget devel/bison textproc/flex graphics/gd security/cyrus-sasl2 devel/cmake lang/python devel/autoconf devel/libtool archivers/libarchive mail/mailx dns/bind910
    elif [ ${OS_MAJ} -eq 9 ]; then
        /usr/sbin/pkg install -y devel/gmake lang/perl5.20 ftp/wget devel/bison textproc/flex graphics/gd security/cyrus-sasl2 devel/cmake lang/python devel/autoconf devel/libtool archivers/libarchive mail/mailx
    fi
}

## Install Compat Libraries
install_compats() {
    if [ ${OS_MAJ} -eq 10 ]; then
        /usr/sbin/pkg install -y misc/compat4x misc/compat5x misc/compat6x misc/compat8x misc/compat9x
    elif [ ${OS_MAJ} -eq 9 ]; then
        /usr/sbin/pkg install -y misc/compat4x misc/compat5x misc/compat6x misc/compat8x
    fi
}

## Install CCache
install_ccache() {
    pkgi devel/ccache

    if [ $? == 0 ]; then
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
}

## Update /etc/sysctl.conf
update_sysctl() {
   #
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
}

## Make unset options
make_unset() {
    # make unset
}


## Update /etc/hosts
update_hosts() {

    COUNT=`grep 127.0.0.1 /etc/hosts | grep -c localhost`
    if [ "$COUNT" -eq 0 ]; then
        echo -e "127.0.0.1\t\tlocalhost" >> /etc/hosts
    fi
}

## Setup BIND (named)
setup_bind() {

    ## BIND (named)
    if [ ${OS_MAJ} -eq 10 ]; then
        if [ ! -e /usr/local/sbin/named ]; then
            echo "*** Error: Cannot find the named binary.";
        fi
        if [ ! -e /usr/local/etc/namedb/named.conf ]; then
            echo "*** Error: Cannot find /usr/local/etc/namedb/named.conf.";
        fi
    elif [ $OS_MAJ -eq 9 ]; then
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

    if [ ${OS_MAJ} -eq 10 ]; then
        ## FreeBSD 10.2 with BIND 9.9.5 from ports
        ${WGET} -O /var/named/etc/namedb/named.conf https://raw.githubusercontent.com/portsbuild/portsbuild/master/conf/named.100.conf
    elif [ ${OS_MAJ} -eq 9 ]; then
        ## FreeBSD 9.3 with BIND 9.9.5 from base
        ${WGET} -O /etc/namedb/named.conf https://raw.githubusercontent.com/portsbuild/portsbuild/master/conf/named.93.conf
    fi

    setVal named_enable \"YES\" /etc/rc.conf

    ${SERVICE} named start
}

## Create a spoof CustomBuild2 options.conf for DirectAdmin compatibility.
create_cb_options() {

    if [ !-d ${CB_PATH} ]; then
        mkdir -p ${CB_PATH}
    fi

    ${WGET} -O ${CB_CONF} ${PB_MIRROR}/conf/cb-options.conf

    if [ -e ${CB_OPTIONS} ]; then
        chmod 755 ${CB_OPTIONS}
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
        COUNT=`grep -c diradmin /etc/aliases`
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

    COUNT=`head -n 4 ${DA_PATH}/update.tar.gz | grep -c "* You are not allowed to run this program *"`;
    if [ $COUNT -ne 0 ]; then
        echo "";
        echo "You are not authorized to download the update package with that Client ID and License ID for this IP address. Please email sales@directadmin.com";
        exit 4;
    fi

    ## Extract update.tar.gz into /usr/local/directadmin:
    cd ${DA_PATH}
    tar zxvf update.tar.gz

    ## See if the binary exists:
    if [ ! -e ${DA_PATH}/directadmin ]; then
        echo "Cannot find the DirectAdmin binary. Extraction failed";
        exit 5;
    fi


    ## These were in do_checks()
    ## Check for a separate /home partition (for quota support).
    HOME_YES=`cat /etc/fstab | grep -c /home`;
    if [ $HOME_YES -lt "1" ]; then
        echo 'quota_partition=/' >> ${DA_CONF_TEMPLATE};
    fi

    ## Detect the ethernet interfaces that are available on the system (NOTE: can return more than 1 interface, even commented).
    ETH_DEV="`cat /etc/rc.conf | grep ifconfig | cut -d= -f1 | cut -d_ -f2`"
    if [ "$ETH_DEV" != "" ]; then
        COUNT=`cat $DA_CONF_TEMPLATE | grep -c ethernet_dev`;
        if [ $COUNT -eq 0 ]; then
            echo ethernet_dev=${ETH_DEV} >> ${DA_CONF_TEMPLATE};
        fi
    fi



## From setup.sh: generate setup.txt
    echo "hostname=${SERVER_FQDN}"                      >  ${SETUP_TXT};
    echo "email=${DA_ADMIN_USERNAME}@${SERVER_DOMAIN}"  >> ${SETUP_TXT};
    echo "mysql=${DA_SQL_PASSWORD}"                     >> ${SETUP_TXT};
    echo "mysqluser=${DA_SQLDB_USERNAME}"               >> ${SETUP_TXT};
    echo "adminname=${DA_ADMIN_USERNAME}"               >> ${SETUP_TXT};
    echo "adminpass=${DA_ADMIN_PASSWORD}"               >> ${SETUP_TXT};
    echo "ns1=ns1.${SERVER_DOMAIN}"                     >> ${SETUP_TXT};
    echo "ns2=ns2.${SERVER_DOMAIN}"                     >> ${SETUP_TXT};
    echo "ip=${DA_SERVER_IP}"                           >> ${SETUP_TXT};
    echo "netmask=${DA_SERVER_IP_MASK}"                 >> ${SETUP_TXT};
    echo "uid=${DA_USER_ID}"                            >> ${SETUP_TXT};
    echo "lid=${DA_LICENSE_ID}"                         >> ${SETUP_TXT};
    echo "services=${DA_FREEBSD_SERVICES}"              >> ${SETUP_TXT};

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

    SSHROOT=`cat /etc/ssh/sshd_config | grep -c 'AllowUsers root'`;
    if [ ${SSHROOT} = 0 ]; then
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

    COUNT=`cat /etc/crontab | grep -c dataskq`
    if [ $COUNT = 0 ]; then
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

    echo "`hostname`" >> ${VIRTUAL}/domains;

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
    echo "daily_status_include_submit_mailq=\"NO\"" >> /etc/periodic.conf
    echo "daily_clean_hoststat_enable=\"NO\"" >> /etc/periodic.conf

}


## SpamAssassin Pre-Installation Tasks
spamassassin_pre_install() {
    #
}

## SpamAssassin Post-Installation Tasks
spamassassin_post_install() {
    
    setVal spamd_enable \"YES\" /etc/rc.conf
    setVal spamd_flags \"-c -m 15\" /etc/rc.conf
}

## Dovecot Pre-Installation Tasks
dovecot_pre_install() {
    #
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
    mkdir -p /usr/local/etc/dovecot/conf
    mkdir -p /usr/local/etc/dovecot/conf.d

    ## Symlink for compat:
    ln -s ${DOVECOT_CONF} /etc/dovecot/dovecot.conf
    # Skipped: ln -s /etc/dovecot/dovecot.conf /etc/dovecot.conf

    cp -rf ${DA_PATH}/custombuild/configure/dovecot/conf /usr/local/etc/dovecot/

    echo 'mail_plugins = $mail_plugins quota' > /usr/local/etc/dovecot/conf/lmtp_mail_plugins.conf

    ${PERL} -pi -e "s|HOSTNAME|`hostname`|" /usr/local/etc/dovecot/conf/lmtp.conf

    ## ltmp log files (not done):
    touch /var/log/dovecot-lmtp.log /var/log/dovecot-lmtp-errors.log
    chown root:wheel /var/log/dovecot-lmtp.log /var/log/dovecot-lmtp-errors.log
    chmod 600 /var/log/dovecot-lmtp.log /var/log/dovecot-lmtp-errors.log

    ## Modifications (done):
    ${PERL} -pi -e 's#transport = dovecot_lmtp_udp#transport = virtual_localdelivery#' /usr/local/etc/exim/exim.conf
    ${PERL} -pi -e 's/driver = shadow/driver = passwd/' /usr/local/etc/dovecot/dovecot.conf
    ${PERL} -pi -e 's/passdb shadow/passdb passwd/' /usr/local/etc/dovecot/dovecot.conf

    echo 'mail_plugins = $mail_plugins quota' > /usr/local/etc/dovecot/conf/mail_plugins.conf
    echo 'mail_plugins = $mail_plugins quota imap_quota' > /usr/local/etc/dovecot/conf/imap_mail_plugins.conf

# # Check for IPV6 compatability (not done):
# if [ "${IPV6}" = "1" ]; then
#   perl -pi -e 's|^listen = \*$|#listen = \*|' /usr/local/etc/dovecot/dovecot.conf
#   perl -pi -e 's|^#listen = \*, ::$|listen = \*, ::|' /usr/local/etc/dovecot/dovecot.conf
# else
#   perl -pi -e 's|^#listen = \*$|listen = \*|' /usr/local/etc/dovecot/dovecot.conf
#   perl -pi -e 's|^listen = \*, ::$|#listen = \*, ::|' /usr/local/etc/dovecot/dovecot.conf
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

## PHP Post-Installation Tasks
php_post_install() {

    ## Replace default php-fpm.conf with DirectAdmin/CB2 version:
    #cp -f /usr/local/directadmin/custombuild/configure/fpm/conf/php-fpm.conf.56 /usr/local/etc/php-fpm.conf

    ## Create CB2/DA directories for compat (replace php56 with your appropriate version):

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

    ## Symlink for compat (replace php56 with your appropriate version):

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

    # secure_php_ini

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
    PMA_CONFIG=${CWD}/custom/phpmyadmin/config.inc.php
    PMA_THEMES=${CWD}/custom/phpmyadmin/themes

    ## Reference: Paths:

    WWWDIR=/usr/local/www
    ##REALPATH=${WWWDIR}/phpMyAdmin-${PHPMYADMIN_VER}
    REALPATH=/usr/local/www/phpMyAdmin
    ALIASPATH=${WWW_DIR}/phpMyAdmin
    CONFIG=${REALPATH}/config.inc.php

    ## Scripted reference:

    ## If custom config exists
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

    ## Copy sample config:
    cp ${WWW_DIR}/phpMyAdmin/config.sample.inc.php ${WWW_DIR}/phpMyAdmin/config.inc.php

    ## Update phpMyAdmin configuration file:
    ${PERL} -pi -e "s#\['host'\] = 'localhost'#\['host'\] = 'localhost'#" ${WWW_DIR}/phpMyAdmin/config.inc.php
    ${PERL} -pi -e "s#\['host'\] = ''#\['host'\] = 'localhost'#" ${WWW_DIR}/phpMyAdmin/config.inc.php
    ${PERL} -pi -e "s#\['auth_type'\] = 'cookie'#\['auth_type'\] = 'http'#" ${WWW_DIR}/phpMyAdmin/config.inc.php
    ${PERL} -pi -e "s#\['extension'\] = 'mysql'#\['extension'\] = 'mysqli'#" ${WWW_DIR}/phpMyAdmin/config.inc.php

    # Copy custom themes:
    if [ -d ${PMA_THEMES} ]; then
        echo "Installing custom PhpMyAdmin themes: ${PMA_THEMES}"
        cp -Rf ${PMA_THEMES} ${REALPATH}
    fi

    ## Update alias path via symlink (not done):
    rm -f ${ALIASPATH} >/dev/null 2>&1
    ln -s ${REALPATH} ${ALIASPATH}


    ## Create logs directory:
    if [ ! -d ${REALPATH}/log ]; then
        mkdir -p ${REALPATH}/log
    fi

    ## Set permissions:
    chown -R ${WEBAPPS_USER}:${WEBAPPS_GROUP} ${REALPATH}
    chown -h ${WEBAPPS_USER}:${WEBAPPS_GROUP} ${ALIASPATH}
    chmod 755 ${REALPATH}


    ## Set permissions (same as above, remove this):
    chown -R ${WEBAPPS_USER}:${WEBAPPS_GROUP} ${WWW_DIR}/phpMyAdmin
    chown -h ${WEBAPPS_USER}:${WEBAPPS_GROUP} ${WWW_DIR}/phpMyAdmin
    chmod 755 ${WWW_DIR}/phpMyAdmin

    ## Symlink:
    ln -s ${WWW_DIR}/phpMyAdmin ${WWW_DIR}/phpmyadmin
    ln -s ${WWW_DIR}/phpMyAdmin ${WWW_DIR}/pma

## verify:

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

    ## Update /etc/groups (verify):
    #access:*:1164:apache,nobody,mail,majordomo,daemon,clamav
}

## Apache Post-Installation Tasks
apache_post_install() {

    ## Symlink for backwards compatability:
    mkdir -p /etc/httpd/conf
    ln -s /usr/local/etc/apache24 /etc/httpd/conf

    ## CustomBuild2 looking for Apache modules in /usr/lib/apache*
    ## Symlink for backcomp (done):

    mkdir -p /usr/lib/apache
    ln -s /usr/local/libexec/apache24 /usr/lib/apache

    ## Since DirectAdmin/CB2 reference /var/www/html often, we'll symlink for compat:
    mkdir -p /var/www
    ln -s /usr/local/www /var/www/html
    chown -h webapps:webapps /var/www/html

    ## CustomBuild2 reference /etc/httpd/conf/ssl
    ## Create empty files for CB2 to generate

    ## Symlink for compat:
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

    ln -s ${APACHE_DIR}/ssl/server.crt /usr/local/etc/apache24/ssl.crt/server.crt
    ln -s ${APACHE_DIR}/ssl/server.ca /usr/local/etc/apache24/ssl.crt/server.ca
    ln -s ${APACHE_DIR}/ssl/server.key /usr/local/etc/apache24/ssl.key/server.key

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
    #
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
    #
}

## RoundCube Post-Installation Tasks
roundcube_post_install() {
    #
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
    ${PERL} -pi -e 's/idle_timeout = 10/idle_timeout = 24/' ${DEST}/webmail/inc/config.security.php

    ${PERL} -pi -e 's#\$temporary_directory = "./database/";#\$temporary_directory = "./tmp/";#' ${DEST}/webmail/inc/config.php
    ${PERL} -pi -e 's/= "ONE-FOR-EACH";/= "ONE-FOR-ALL";/' ${DEST}/webmail/inc/config.php
    ${PERL} -pi -e 's#\$smtp_server = "SMTP.DOMAIN.COM";#\$smtp_server = "localhost";#' ${DEST}/webmail/inc/config.php
    # ${PERL} -pi -e 's#\$default_mail_server = "POP3.DOMAIN.COM";#\$default_mail_server = "localhost";#' ${DEST}/webmail/inc/config.php
    ${PERL} -pi -e 's/POP3.DOMAIN.COM/localhost/' ${DEST}/webmail/inc/config.php

    rm -rf ${DEST}/webmail/install

    ## Copy redirect.php (done):
    cp -f ${DA_PATH}/scripts/redirect.php ${WWW_DIR}/redirect.php
}

## Secure php.ini (copied from CB2)
## $1 = php.ini file to update
secure_php_ini() {
    if [ -e $1 ]; then
        if grep -m1 -q -e disable_functions $1; then
            CURRENT_DISABLE_FUNCT="`grep -m1 'disable_functions' $1`"
            NEW_DISABLE_FUNCT="exec,system,passthru,shell_exec,escapeshellarg,escapeshellcmd,proc_close,proc_open,dl,popen,show_source,posix_kill,posix_mkfifo,posix_getpwuid,posix_setpgid,posix_setsid,posix_setuid,posix_setgid,posix_seteuid,posix_setegid,posix_uname"
            ${PERL} -pi -e "s#${CURRENT_DISABLE_FUNCT}#disable_functions \= ${NEW_DISABLE_FUNCT}#" $1
        else
            echo "disable_functions = ${NEW_DISABLE_FUNCT}" >> $1
        fi

        ${PERL} -pi -e 's/^register_globals = On/register_globals = Off/' $1

        ${PERL} -pi -e 's/^mysql.allow_local_infile = On/mysql.allow_local_infile = Off/' $1
        ${PERL} -pi -e 's/^mysqli.allow_local_infile = On/mysqli.allow_local_infile = Off/' $1
        ${PERL} -pi -e 's/^;mysqli.allow_local_infile = On/mysqli.allow_local_infile = Off/' $1

        ${PERL} -pi -e 's/^expose_php = On/expose_php = Off/' $1
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
    if [ -e ${PHP_CUSTOM_PHP_CONF_D_INI_PATH}/50-webapps.ini ]; then
        echo "Using custom ${PHP_CUSTOM_PHP_CONF_D_INI_PATH}/50-webapps.ini for ${PHP_INI_WEBAPPS}"
        cp -f ${PHP_CUSTOM_PHP_CONF_D_INI_PATH}/50-webapps.ini ${PHP_INI_WEBAPPS}
    else
        echo "[PATH=${WWW_DIR}]" > ${PHP_INI_WEBAPPS}
        echo "session.save_path=${WWW_TMP_DIR}" >> ${PHP_INI_WEBAPPS}
        echo "upload_tmp_dir=${WWW_TMP_DIR}" >> ${PHP_INI_WEBAPPS}
        echo "disable_functions=exec,system,passthru,shell_exec,escapeshellarg,escapeshellcmd,proc_close,proc_open,dl,popen,show_source,posix_kill,posix_mkfifo,posix_getpwuid,posix_setpgid,posix_setsid,posix_setuid,posix_setgid,posix_seteuid,posix_setegid,posix_uname" >> ${PHP_INI_WEBAPPS}
    fi
}

## Ensure Webapps tmp (copied from CB2)
verify_webapps_tmp() {

    if [ ! -d {$WWW_TMP_DIR} ]; then
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
    PHP1_MOD="FPM"
    PHP1_VERSION="56"

    ## Copy custom/ file
    if [ -e ${WORKDIR}/custom/ap2/conf/extra/httpd-hostname.conf ]; then
        cp -pf ${WORKDIR}/custom/ap2/conf/extra/httpd-hostname.conf ${HOSTCONF}
    else
        echo -n '' > ${HOSTCONF}

        # if [ "${HAVE_FPM_CGI}" = "yes" ]; then
        #   echo 'SetEnvIfNoCase ^Authorization$ "(.+)" HTTP_AUTHORIZATION=$1' >> ${HOSTCONF}
        # fi

        echo '<Directory ${WWW_DIR}>' >> ${HOSTCONF}

        if [ "${PHP1_MODE}" = "FPM" ]; then
            echo '<FilesMatch "\.(inc|php|php3|php4|php44|php5|php52|php53|php54|php55|php56|php70|php6|phtml|phps)$">' >> ${HOSTCONF}
            echo "AddHandler \"proxy:unix:/usr/local/php${PHP1_VERSION}/sockets/webapps.sock|fcgi://localhost\" .inc .php .php5 .php${PHP1_VERSION} .phtml" >> ${HOSTCONF}
            echo '</FilesMatch>' >> ${HOSTCONF}
        fi

        echo '  Options +SymLinksIfOwnerMatch +IncludesNoExec' >> ${HOSTCONF}
        echo '  AllowOverride AuthConfig FileInfo Indexes Limit Options=Includes,IncludesNOEXEC,Indexes,ExecCGI,MultiViews,SymLinksIfOwnerMatch,None' >> ${HOSTCONF}
        echo ''                                         >> ${HOSTCONF}
        echo '  Order Allow,Deny'                       >> ${HOSTCONF}
        echo '  Allow from all'                         >> ${HOSTCONF}
        echo '  <IfModule mod_suphp.c>'                 >> ${HOSTCONF}
        echo '      suPHP_Engine On'                    >> ${HOSTCONF}
        echo '      suPHP_UserGroup ${WEBAPPS_USER} ${WEBAPPS_GROUP}'    >> ${HOSTCONF}
        echo '  </IfModule>'                            >> ${HOSTCONF}

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
            SUEXEC_PER_DIR="`/usr/local/sbin/suexec -V 2>&1 | grep -c 'AP_PER_DIR'`"
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

        echo '</Directory>' >> ${HOSTCONF}
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
    cd ${DA_PATH}
    ./directadmin i
}

## DirectAdmin Permissions
exec_da_permissions() {
    cd ${DA_PATH}
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
    ##
}



## ./portsbuild selection screen
case "$1" in
    "") ;;
#    create_options)  ;;
#    set)  ;;
#    check_options) ;;
    install) ;; ## install PB+DirectAdmin
    #setup) ;; ## (alias for 'install'?)
    update) ;; ## update PB script
    verify) ;; ## verify system state
    all) ;;
esac

################################################################

## EOF

