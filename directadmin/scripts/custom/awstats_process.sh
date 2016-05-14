#!/bin/sh
# This script is written by Martynas Bendorius and DirectAdmin
# http://www.directadmin.com
# It is used to process AWstats for a domain
# Official AWstats webpage: http://www.awstats.org
# Usage:
# ./awstats_user.sh <user> <domain>

## 2016-05-12: PortsBuild Version
## PB: Todo:

ADD_CGI=1
ADD_HTML=1

#set this to 1 if you need the script to reset the awstats link for each domain to root (when harden symlinks patch is enabled in apache)
#this should only need to be enabled once, and can be disabled after that one run.
ENSURE_ROOT_LINKS=0

ROOTGRP=wheel

if [ "${ADD_CGI}" -eq 0 ] && [ "${ADD_HTML}" -eq 0 ]; then
  printf "One of ADD_CGI and ADD_HTML must be set to 1\n"
  exit 10
fi

AUID=$(/usr/bin/id -u)
if [ "$AUID" != 0 ]; then
  printf "You require root access to run this script\n"
  exit 1
fi

if [ $# != 2 ] && [ $# != 3 ]; then
  printf "Usage:\n"
  printf "%s <user> <domain> (<subdomain>)" "$0"
  printf "you gave #$#: %s %s %s" "$0" "$1" "$2"
  exit 2
fi

/usr/bin/id ${1} >/dev/null 2>&1
RET=$?
if [ "${RET}" -ne 0 ]; then
  printf "User %s does not exist.\n" "${1}"
  exit 3
fi

SUB="";
if [ $# = 3 ]; then
  SUB=$3
fi

USER=$1
DOMAIN=$2
UHOME=$(grep -e "^${USER}:" /etc/passwd | head -n 1 | cut -d: -f6)

TOP_DOMAIN=$2

if [ "$UHOME" = "" ]; then
  printf "Could not find a home path for user %s in /etc/passwd" "${USER}"
  exit 4
fi

HTTPD=httpd
if [ "$(/usr/local/directadmin/directadmin c | grep ^nginx= | cut -d= -f2)" -eq 1 ]; then
  HTTPD=nginx
fi
if [ "$(/usr/local/directadmin/directadmin c | grep ^nginx_proxy= | cut -d= -f2)" -eq 1 ]; then
  HTTPD=nginx
fi

AWSTATS=/usr/local/awstats
MODEL=${AWSTATS}/wwwroot/cgi-bin/awstats.model.conf
STATS_DIR=${UHOME}/domains/${DOMAIN}/awstats
DATA=.data
DATA_DIR=${STATS_DIR}/${DATA}
LOGDIR=/var/log/${HTTPD}/domains

if [ "${SUB}" != "" ]; then
  STATS_DIR=$STATS_DIR/${SUB}
  DATA_DIR=${STATS_DIR}/${DATA}
  CONFIG=${DATA_DIR}/awstats.${SUB}.${DOMAIN}.conf
  LOG=${LOGDIR}/${DOMAIN}.${SUB}.log

  #we change the domain name at the last possible moment, after we're done with DOMAIN.
  #all calls to DOMAIN from this point onwards will see sub.domain.com
  DOMAIN=${SUB}.${DOMAIN}
else
  CONFIG=${DATA_DIR}/awstats.${DOMAIN}.conf
  LOG=${LOGDIR}/${DOMAIN}.log
fi

if [ ! -e ${AWSTATS} ]; then
  printf "%s does not exist!\n" "${AWSTATS}"
  exit 5
fi

if [ ! -e "${STATS_DIR}" ]; then
  mkdir "${STATS_DIR}"
  chmod 755 "${STATS_DIR}"
else
  if [ -h "${STATS_DIR}" ]; then
    printf "%s is a symbolic link. Aborting.\n" "${STATS_DIR}"
    exit 8
  fi
fi

if [ ! -e "${DATA_DIR}" ]; then
  mkdir "${DATA_DIR}"
  chmod 755 "${DATA_DIR}"
else
  if [ -h "${DATA_DIR}" ]; then
    printf "%s is a symbolic link. Aborting.\n" "${DATA_DIR}"
    exit 9
  fi
fi

#this bit is to fix the 700 that backups cannot see. (bug)
#http://www.directadmin.com/features.php?id=915
chmod 755 "${DATA_DIR}"

#do it every time.  Users must not be able to edit the config directly.
chown -R root:${ROOTGRP} "${DATA_DIR}"

if [ ! -s "${CONFIG}" ]; then
  if [ ! -s ${MODEL} ]; then
    printf "%s does not exist or is empty.\n" "${MODEL}"
    exit 6
  fi

  cp -f ${MODEL} "${CONFIG}"
  chmod 644 "${CONFIG}"

  perl -pi -e "s#LogFile=\"/var/log/httpd/mylog.log\"#LogFile=\"${LOG}\"#" "${CONFIG}"
  perl -pi -e "s#SiteDomain=\"\"#SiteDomain=\"${DOMAIN}\"#" "${CONFIG}"
  perl -pi -e "s#DirData=\".\"#DirData=\"${DATA_DIR}\"#" "${CONFIG}"
  perl -pi -e "s#DirCgi=\"/cgi-bin\"#DirCgi=\/awstats\"#" "${CONFIG}"
  #perl -pi -e "s#DirIcons=\"/icon\"#DirIcons=\"${STATS_DIR}\"#" ${CONFIG} #moved below to different value
  perl -pi -e "s#ValidHTTPCodes=\"200 304\"#ValidHTTPCodes=\"200 304 206\"#" "${CONFIG}"

  #Oct 24, 2010
  perl -pi -e "s#DirIcons=\"/icon\"#DirIcons=\"icon\"#" "${CONFIG}"

  #mkdir -p ${STATS_DIR}  #not required anymore

  #April 17, changed to link, below
      #cp -Rp ${AWSTATS}/wwwroot/icon ${STATS_DIR}

  chown -R root:${ROOTGRP} "${STATS_DIR}"
  chown ${USER}:${USER} "${STATS_DIR}"
else
  perl -pi -e "s#DirIcons=\"${STATS_DIR}\"#DirIcons=\"icon\"#" "${CONFIG}"
fi

ensure_root() {

  if [ "$ENSURE_ROOT_LINKS" != 1 ]; then
    return
  fi

  F=$1
  if [ ! -h $F ]; then
    return
  fi

  FOWNER=$(ls -la $F | awk '{print $3}')

  if [ "$FOWNER" = "$USER" ]; then
    echo "Setting link $F to root";
    chown -h root:${ROOTGRP} $F
  fi
}


ICON=${STATS_DIR}/icon
if [ ! -h $ICON ]; then
  rm -rf $ICON
  ln -sf ${AWSTATS}/wwwroot/icon $ICON
fi

ensure_root $ICON

#Oct 24, 2010
if [ "${ADD_CGI}" -eq 1 ]; then
  #copy cgi-bin bits to awstats directory.

  if [ ! -e "${STATS_DIR}/awstats.pl}" ]; then
    cp ${AWSTATS}/wwwroot/cgi-bin/awstats.pl ${STATS_DIR}/awstats.pl

    #make a few changes so it can find the config.
    #perl -pi -e "s#\"\$DIR\",\s+\"/etc/awstats\",#\"\$DIR\",\t\"${UHOME}/domains/${DOMAIN}/awstats/.data\",#" ${STATS_DIR}/awstats.pl
    perl -pi -e "s#\"\$DIR\",\s+\"/etc/awstats\",#\"\$DIR\",\t\"${DATA_DIR}\",#" ${STATS_DIR}/awstats.pl

    #repeat for variations of the awstats.pl files
    #perl -pi -e "s#\"\$DIR\",\"/etc/awstats\",#\"\$DIR\",\"${UHOME}/domains/${DOMAIN}/awstats/.data\",#" ${STATS_DIR}/awstats.pl
    #perl -pi -e "s#\"/etc/awstats\"#\"${UHOME}/domains/${DOMAIN}/awstats/.data\"#" ${STATS_DIR}/awstats.pl
    perl -pi -e "s#\"/etc/awstats\"#\"${DATA_DIR}\"#" ${STATS_DIR}/awstats.pl

    chown ${USER}:${USER} ${STATS_DIR}/awstats.pl
  fi

  chmod 755 ${STATS_DIR}/awstats.pl

  if [ ! -e "${STATS_DIR}/lang" ]; then
    ln -s ${AWSTATS}/wwwroot/cgi-bin/lang ${STATS_DIR}/lang
  fi
  ensure_root ${STATS_DIR}/lang

  if [ ! -e "${STATS_DIR}/lib" ]; then
    ln -s ${AWSTATS}/wwwroot/cgi-bin/lib ${STATS_DIR}/lib
  fi
  ensure_root ${STATS_DIR}/lib

  if [ ! -e "${STATS_DIR}/plugins" ]; then
    ln -s ${AWSTATS}/wwwroot/cgi-bin/plugins ${STATS_DIR}/plugins
  fi
  ensure_root ${STATS_DIR}/plugins

  #WWWCONFIG=${DATA_DIR}/awstats.www.${DOMAIN}.conf
  #if [ ! -e ${WWWCONFIG} ]; then
  #   ln -s awstats.${DOMAIN}.conf ${WWWCONFIG}
  #fi

  EXECCGI=1;
  DC=/usr/local/directadmin/data/users/${USER}/domains/${TOP_DOMAIN}.conf
  if [ -s ${DC} ]; then
    C=`grep -c "^cgi=OFF" $DC`
    if [ "${C}" -gt 0 ]; then
      EXECCGI=0;
    fi
  fi

  HTACCESS=${STATS_DIR}/.htaccess
  ADD_HTA=0
  if [ ! -e ${HTACCESS} ]; then
    ADD_HTA=1
  else
    #check it's contents
    COUNT=`grep -c 'DirectoryIndex awstats.pl' ${HTACCESS}`

    if [ "${COUNT}" -eq 0 ] && [ "${EXECCGI}" -eq 1 ]; then
      ADD_HTA=1
    fi
    if [ "${COUNT}" -eq 1 ] && [ "${EXECCGI}" -eq 0 ]; then
      ADD_HTA=1
    fi
  fi

  if [ -h ${HTACCESS} ]; then
    echo "${HTACCESS} is a symbolic link. Aborting."
    exit 11
  fi

  if [ "${ADD_HTA}" -eq 1 ]; then
    if [ "${EXECCGI}" -eq 1 ]; then
      echo "Options -Indexes +ExecCGI" > ${HTACCESS}
      echo "AddHandler cgi-script .pl" >> ${HTACCESS}
      echo "DirectoryIndex awstats.pl" >> ${HTACCESS}
    else
      echo "Options -Indexes" > ${HTACCESS}
    fi

    echo "" >> ${HTACCESS}
    echo "RewriteEngine On" >> ${HTACCESS}
    echo "RewriteCond %{HTTP_HOST} ^www.${DOMAIN}\$ [NC]" >> ${HTACCESS}
    echo "RewriteRule ^(.*)\$ http://${DOMAIN}/awstats/\$1 [R=301,L]" >> ${HTACCESS}
  fi
fi


if [ "${ADD_HTML}" -eq 1 ]; then
  BD='-builddate=%YY%MM'

  #this doesn't work because there are 4 hours of the next month in the logs on the first day.
  #They empty the stats from the old html for last month.
  #DAY=`date +%e`
  #if [ "$DAY" -eq 1 ]; then
  #   YYMM=`date --date='yesterday' +%y%m`
  #   BD="-builddate=$YYMM"
  #fi

  #-lang=en
  /usr/bin/perl ${AWSTATS}/tools/awstats_buildstaticpages.pl -config=${DOMAIN} -configdir=${DATA_DIR} -update -diricons=icon -awstatsprog=${AWSTATS}/cgi-bin/awstats.pl -dir=${STATS_DIR} $BD
  RET=$?

  #if [ "$DAY" -eq 1 ]; then
  #   MAIN_FILE=awstats.${DOMAIN}.`date --date='yesterday' +%y%m`.html
  #else
  #we stil need to set a value though:
  MAIN_FILE=awstats.${DOMAIN}.`date +%y%m`.html
  #fi

  MAIN_HTML=${STATS_DIR}/${MAIN_FILE}
  INDEX_HTML=${STATS_DIR}/index.html

  #changes per month
  ln -sf ${MAIN_FILE} ${INDEX_HTML}
  ensure_root ${INDEX_HTML}
  ensure_root ${MAIN_HTML}

else
  #this is for the case where we dont want to waste time with static html files (ADD_HTML=0) but ADD_CGI is still on.
  #due to the check check for !ADD_HTML&&!ADD_CGI above, ADD_CGI must be 1 at this point.

  /usr/bin/perl ${AWSTATS}/tools/awstats_updateall.pl now -configdir=${DATA_DIR} -awstatsprog=${AWSTATS}/cgi-bin/awstats.pl
  # -excludeconf=awstats.www.${DOMAIN}.conf we're using mod_rewrite to change www.domain.com/awstast to domain.com/awstats, since only domain.com/awstats works unless we link every single data file (ugly).
  RET=$?
fi

exit $RET
