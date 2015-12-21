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
#  - New installs, run: ./portsbuild install USER_ID LICENSE_ID IP_ADDRESS
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

### If you want to modify PortsBuild settings, please check out 'conf/options.conf'

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

. conf/options.conf
. conf/ports.conf
. conf/constants.conf
#. conf/make.conf


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

## Disable sendmail
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

    ## magic goes here
}

## Setup BIND (named)
setup_bind() {

    ## File target paths:
    ## 10.2: /var/named/etc/namedb/named.conf
    ## 9.3: /etc/namedb/named.conf

    if [ ${OS_BSD} -eq 10 ]; then
        ## FreeBSD 10.2 with BIND 9.9.5 from ports
        wget -O /var/named/etc/namedb/named.conf https://raw.githubusercontent.com/portsbuild/portsbuild/master/conf/named10.conf
    else if [ ${OS_BSD} -eq 9 ]; then
        ## FreeBSD 9.3 with BIND 9.9.5 from base
        wget -O /etc/namedb/named.conf https://raw.githubusercontent.com/portsbuild/portsbuild/master/conf/named9.conf
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

    /usr/local/big/wget -O ${CB_CONF} ${PB_MIRROR}/conf/options.conf

    if [ -e ${CB_OPTIONS} ]; then
        chmod 755 ${CB_OPTIONS}
    fi
}


## Create portsbuild/options.conf
create_pb_options() {

    touch /usr/local/directadmin/portsbuild/options.conf
}


### DirectAdmin Installation ###

## The next two functions replace DirectAdmin's setup.sh

## Prepare DirectAdmin Installation
setup_directadmin() {

    ## Update /etc/aliases
    echo "diradmin: :blackhole:" >> /etc/aliases
    /usr/bin/newaliases

    ## Create the directory
    mkdir /usr/local/directadmin

    ## Get DirectAdmin License

    ## Replace SERVER_IP_ADDRESS, USER_ID, and LICENSE_ID):
    if [ $DA_LAN eq 0 ]; then
        wget --no-check-certificate -S -O ${DA_PATH}/update.tar.gz --bind-address=${DA_SERVER_IP} "https://www.directadmin.com/cgi-bin/daupdate?uid=${DA_USER_ID}&lid=${DA_LICENSE_ID}"
    else if [ $DA_LAN eq 1 ]; then
        wget --no-check-certificate -S -O ${DA_PATH}/update.tar.gz "https://www.directadmin.com/cgi-bin/daupdate?uid=${DA_USER_ID}&lid=${DA_LICENSE_ID}"
    fi



# Extract update.tar.gz into /usr/local/directadmin:

    cd /usr/local/directadmin
    tar zxvf update.tar.gz

#Verify: User Welcome message not created?

    touch /usr/local/directadmin/data/users/admin/u_welcome.txt


#Verify: Create backup.conf (wasn't created?)

    chown diradmin:diradmin /usr/local/directadmin/data/users/admin/backup.conf

# From setup.sh: generate setup.txt

    echo "hostname=${SERVER_FQDN}"            >  /usr/local/directadmin/scripts/setup.txt;
    echo "email=root@example.com"             >> /usr/local/directadmin/scripts/setup.txt;
    echo "mysql=${DA_SQL_PASSWORD}"           >> /usr/local/directadmin/scripts/setup.txt;
    echo "mysqluser=${DA_SQLDB_USERNAME}"     >> /usr/local/directadmin/scripts/setup.txt;
    echo "adminname=${DA_ADMIN_USERNAME}"     >> /usr/local/directadmin/scripts/setup.txt;
    echo "adminpass=${DA_ADMIN_PASSWORD}"     >> /usr/local/directadmin/scripts/setup.txt;
    echo "ns1=ns1.${SERVER_DOMAIN}"           >> /usr/local/directadmin/scripts/setup.txt;
    echo "ns2=ns2.${SERVER_DOMAIN}"           >> /usr/local/directadmin/scripts/setup.txt;
    echo "ip=${DA_SERVER_IP}"                 >> /usr/local/directadmin/scripts/setup.txt;
    echo "netmask=${DA_SERVER_IP_MASK}"       >> /usr/local/directadmin/scripts/setup.txt;
    echo "uid=${DA_USER_ID}"                  >> /usr/local/directadmin/scripts/setup.txt;
    echo "lid=${DA_LICENSE_ID}"               >> /usr/local/directadmin/scripts/setup.txt;
    echo "services=${DA_FREEBSD_SERVICES}"    >> /usr/local/directadmin/scripts/setup.txt;
}


## Install DirectAdmin
install_directadmin() {

    #
}


## Install DA cron (scripts/install.sh)
install_cron() {

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

    cp /etc/newsyslog.conf.d/directadmin.conf /usr/local/etc/newsyslog.conf.d/
}


## COPIED:
## Exim-specific stuff
## (from scripts/install.sh)
prepare_exim() {

    mkdir -p ${VIRTUAL};
    chown mail:mail ${VIRTUAL};
    chmod 755 ${VIRTUAL};

    echo "`hostname`" >> ${VIRTUAL}/domains;

    if [ ! -s ${VIRTUAL}/limit ]; then
        echo "1000" > ${VIRTUAL}/limit
    fi

    if [ ! -s ${VIRTUAL}/limit_unknown ]; then
        echo "0" > ${VIRTUAL}/limit_unknown
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

## Apache Host Configuration
## Copied from CB2
do_ApacheHostConf() {

    HOSTCONF=/usr/local/etc/apache24/extra/httpd-hostname.conf

    ## Set this for now since PB only supports 1 instance of PHP.
    PHP1_MODE_OPT="php-fpm"

    ## Copy existing file
    if [ -e ${WORKDIR}/custom/ap2/conf/extra/httpd-hostname.conf ]; then
        cp -pf ${WORKDIR}/custom/ap2/conf/extra/httpd-hostname.conf ${HOSTCONF}
    else
        echo -n '' > ${HOSTCONF}

        # if [ "${HAVE_FPM_CGI}" = "yes" ]; then
        #   echo 'SetEnvIfNoCase ^Authorization$ "(.+)" HTTP_AUTHORIZATION=$1' >> ${HOSTCONF}
        # fi

        echo '<Directory /usr/local/www>' >> ${HOSTCONF}

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