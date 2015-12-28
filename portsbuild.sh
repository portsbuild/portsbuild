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
        /usr/sbin/portsnap fetch extract
    fi
fi


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
setOpt() {
    ## $1 = option name
    ## $2 = value

    if [ "$1" = "email" ]; then
        OPT_VALUE1="`grep -m1 "^$1=" ${OPTIONS_CONF} | cut -d= -f2 | cut -d\@ -f 1`"
        OPT_VALUE2="`grep -m1 "^$1=" ${OPTIONS_CONF} | cut -d= -f2 | cut -d\@ -f 2`"
        OPT_NEW_VALUE1="`echo "$2" | cut -d\@ -f 1`"
        OPT_NEW_VALUE2="`echo "$2" | cut -d\@ -f 2`"
        perl -pi -e "s#$1=${OPT_VALUE1}\@${OPT_VALUE2}#$1=${OPT_NEW_VALUE1}\@${OPT_NEW_VALUE2}#" ${PB_CONF}
        # if [ "${HIDE_CHANGES}" = "0" ]; then
        #     echo "Changed ${boldon}$1${boldoff} option from ${boldon}${OPT_VALUE1}@${OPT_VALUE2}${boldoff} to ${boldon}$2${boldoff}"
        # fi
    else
        VAR=`echo $1 | tr "[a-z]" "[A-Z]"`
        if [ -z "$(eval_var ${VAR}_DEF)" ]; then
            echo "${1} is not a valid option."
            EXIT_CODE=50
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
            EXIT_CODE=51
            return
        fi
        OPT_VALUE="`grep -m1 "^$1=" ${OPTIONS_CONF} | cut -d= -f2`"
        perl -pi -e "s#$1=${OPT_VALUE}#$1=$2#" ${PB_CONF}
        # if [ "${HIDE_CHANGES}" = "0" ]; then
        #     echo "Changed ${boldon}$1${boldoff} option from ${boldon}${OPT_VALUE}${boldoff} to ${boldon}$2${boldoff}"
        # fi
    fi
}


## Set Value (copied from CB2)
## Sets the value of $1 to $2 in the file $3
setVal() {
    if [ ! -e $3 ]; then
        return
    fi

    if ! grep -m1 -q ${1}= ${3}; then
        #ok, it's not there, add it.
        echo "$1=$2" >> $3
        return
    else
        #ok, the value is already in the file $3, so use perl to regex it.
        /usr/local/bin/perl -pi -e "s/`grep ${1}= ${3}`/${1}=${2}/" ${3}
    fi
}


## Do basic checks
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
        echo "*** Error: cannot find the named binary. Please install: dns/bind99 ***";
        RET=1;
    fi

    # if [ ! -e /usr/local/etc/namedb/named.conf ]; then
    #   echo "*** Error: Cannot find /usr/local/etc/namedb/named.conf.  Make sure Bind is completely installed. ***";
    #   RET=1;
    # fi

    # if [ ! -e /usr/local/bin/gcc ]; then
    #   echo "*** Error: gcc not found. Please install: lang/gcc48 ***";
    #   RET=1;
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
    #   echo "*** Error: patch not found in the Base System (/usr/bin/patch), which is odd. ***";
    #   RET=1;
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
            install_deps;
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
    update_pkg();
}

## pkg update
update_pkg() {
    ${PKG} update
}

## Setup /usr/ports
setup_ports() {
    ${PORTSNAP} fetch extract
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
            ${PKGI} ${PORT_PERL}
            if [ $? eq 0 ]; then
                ln -s /usr/local/bin/perl /usr/bin/perl
            fi
        fi
    fi

    # pkg install -y gcc gmake perl5 wget bison flex cyrus-sasl cmake python autoconf libtool libarchive iconv bind99 mailx

    # Make sure pkg is installed. Check ports?
    # if [ ! -e /usr/sbin/pkg ]; then
    #   pkg
    # fi

}

## Post-Install Tasks
post_install() {
    # cleanup leftover files?
    exit 0;
}

## Install Dependencies
install_deps() {

    if [ ${OS_MAJ} -eq 10 ]; then
        /usr/sbin/pkg install -y devel/gmake lang/perl5.20 ftp/wget devel/bison textproc/flex graphics/gd security/cyrus-sasl2 devel/cmake lang/python devel/autoconf devel/libtool archivers/libarchive mail/mailx dns/bind910
    else if [ ${OS_MAJ} -eq 9 ]; then
        /usr/sbin/pkg install -y devel/gmake lang/perl5.20 ftp/wget devel/bison textproc/flex graphics/gd security/cyrus-sasl2 devel/cmake lang/python devel/autoconf devel/libtool archivers/libarchive mail/mailx
    fi
}

## Install Compat Libraries
install_compats() {

    if [ ${OS_MAJ} -eq 10 ]; then
        pkg install -y misc/compat4x misc/compat5x misc/compat6x misc/compat8x misc/compat9x
    elif [ ${OS_MAJ} -eq 9 ]; then
        pkg install -y misc/compat4x misc/compat5x misc/compat6x misc/compat8x
    fi
}

## Install CCache
install_ccache() {
    ${PKGI} ${PORT_CCACHE}

    if [ $? == 0 ]; then
        if [ -e /etc/make.conf ]; then
            echo "WITH_CCACHE_BUILD=yes" >> /etc/make.conf
        fi
    fi
}

## Disable sendmail
disable_sendmail() {

    ${PERL} -pi -e 's/sendmail_enable=\"YES\"/sendmail_enable=\"NONE\"/' /etc/rc.conf
    ${PERL} -pi -e 's/sendmail_enable=\"NO\"/sendmail_enable=\"NONE\"/' /etc/rc.conf

    COUNT=`grep -c sendmail_enable=\"NONE\" /etc/rc.conf`
    if [ "$COUNT" -eq 0 ]; then
        echo -e "sendmail_enable=\"NONE\"" >> /etc/rc.conf
    fi

    COUNT=`grep -c sendmail_submit_enable=\"NO\" /etc/rc.conf`
    if [ "$COUNT" -eq 0 ]; then
        echo -e "sendmail_submit_enable=\"NO\"" >> /etc/rc.conf
    fi

    COUNT=`grep -c sendmail_outbound_enable=\"NO\" /etc/rc.conf`
    if [ "$COUNT" -eq 0 ]; then
        echo -e "sendmail_outbound_enable=\"NO\"" >> /etc/rc.conf
    fi

    COUNT=`grep -c sendmail_msp_queue_enable=\"NO\" /etc/rc.conf`
    if [ "$COUNT" -eq 0 ]; then
        echo -e "sendmail_msp_queue_enable=\"NO\"" >> /etc/rc.conf
    fi

    ## echo "sendmail_enable=\"NONE\"" >> /etc/rc.conf
    ## echo "sendmail_submit_enable=\"NO\"" >> /etc/rc.conf
    ## echo "sendmail_outbound_enable=\"NO\"" >> /etc/rc.conf
    ## echo "sendmail_msp_queue_enable=\"NO\"" >> /etc/rc.conf

    ${SERVICE} sendmail onestop
}

## Enable SSH Daemon
enable_sshd() {

    ${PERL} -pi -e 's/sshd_enable=\"NO\"/sshd_enable=\"YES\"/' /etc/rc.conf

    COUNT=`grep -c sshd_enable=\"YES\" /etc/rc.conf`
    if [ "$COUNT" -eq 0 ]; then
        echo "sshd_enable=\"YES\"" >> /etc/rc.conf
    fi

    ${SERVICE} sshd start
}

## Update /etc/rc.conf
update_rc() {

    if [ ! -e /etc/rc.conf ]; then
        touch /etc/rc.conf
    fi

    ## From DA/setup.sh:
    COUNT=`grep -c ipv6_ipv4mapping /etc/rc.conf`
    if [ "$COUNT" -eq 0 ]; then
        echo "ipv6_ipv4mapping=\"YES\"" >> /etc/rc.conf
    fi

    disable_sendmail;

    enable_sshd;

    #set_hostname;

}

## Update /etc/sysctl.conf
update_sysctl() {

    ## From DA/setup.sh
    COUNT=`grep -c net.inet6.ip6.v6only /etc/sysctl.conf`
    if [ "$COUNT" -eq 0 ]; then
        echo "net.inet6.ip6.v6only=0" >> /etc/sysctl.conf
    fi

    /sbin/sysctl net.inet6.ip6.v6only=0
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
}

## Create custombuild/options.conf
create_cb_options() {

    touch ${CB_CONF};
}

## Create a spoof CustomBuild2 options.conf for DirectAdmin compatibility.
create_cb_options() {

    if [ !-d ${CB_PATH} ]; then
        mkdir -p ${CB_PATH}
    fi

    ${WGET} -O ${CB_CONF} ${PB_MIRROR}/conf/options.conf

    if [ -e ${CB_OPTIONS} ]; then
        chmod 755 ${CB_OPTIONS}
    fi
}


## Create portsbuild/options.conf
create_pb_options() {
    touch ${DA_PATH}/portsbuild/options.conf
}


### DirectAdmin Installation ###

## The next two functions replace DirectAdmin's setup.sh

## Prepare DirectAdmin Installation (replaces setup.sh)
setup_directadmin() {

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
    pw useradd -g apache -n apache -d /usr/local/www -s /sbin/nologin 2> /dev/null

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
    chown diradmin:diradmin /usr/local/directadmin/data/users/admin/backup.conf


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


## Install DA cron (from: scripts/install.sh)
install_cron() {

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

    #fix: cp /etc/newsyslog.conf.d/directadmin.conf /usr/local/etc/newsyslog.conf.d/

    /usr/sbin/newsyslog
}

## Exim-specific stuff (from: scripts/install.sh)
prepare_exim() {

    mkdir -p ${VIRTUAL};
    chown mail:mail ${VIRTUAL};
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

    chown mail:mail ${VIRTUAL}/*;
}

## Secure php.ini (copied from CB2)
secure_phpini() {
    if [ -e $1 ]; then
        if grep -m1 -q -e disable_functions $1; then
            CURRENT_DISABLE_FUNCT="`grep -m1 'disable_functions' $1`"
            NEW_DISABLE_FUNCT="exec,system,passthru,shell_exec,escapeshellarg,escapeshellcmd,proc_close,proc_open,dl,popen,show_source,posix_kill,posix_mkfifo,posix_getpwuid,posix_setpgid,posix_setsid,posix_setuid,posix_setgid,posix_seteuid,posix_setegid,posix_uname"
            perl -pi -e "s#${CURRENT_DISABLE_FUNCT}#disable_functions \= ${NEW_DISABLE_FUNCT}#" $1
        else
            echo "disable_functions = ${NEW_DISABLE_FUNCT}" >> $1
        fi

        perl -pi -e 's/^register_globals = On/register_globals = Off/' $1

        perl -pi -e 's/^mysql.allow_local_infile = On/mysql.allow_local_infile = Off/' $1
        perl -pi -e 's/^mysqli.allow_local_infile = On/mysqli.allow_local_infile = Off/' $1
        perl -pi -e 's/^;mysqli.allow_local_infile = On/mysqli.allow_local_infile = Off/' $1

        perl -pi -e 's/^expose_php = On/expose_php = Off/' $1
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

## Apache Host Configuration
## Copied from CB2
do_ApacheHostConf() {

    HOSTCONF=${APACHE_DIR}/extra/httpd-hostname.conf

    ## Set this for now since PB only supports 1 instance of PHP.
    PHP1_MODE_OPT="php-fpm"

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
        echo '      suPHP_UserGroup webapps webapps'    >> ${HOSTCONF}
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

## ./portsbuild selection screen
case "$1" in
    "") ;;
#    create_options)  ;;
#    set)  ;;
#    check_options) ;;
    install) ;; ## install DirectAdmin
    setup) ;; ## setup DirectAdmin (alias for 'install'?)
    update) ;; ## update PB script
    verify) ;; ## verify system state
    all) ;;
esac
