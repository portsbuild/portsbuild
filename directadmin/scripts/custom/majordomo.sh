#!/bin/sh
# Script to install majordomo
# PortsBuild edition

# This script is written originally by DirectAdmin
# http://www.directadmin.com

OS=$(uname)

SERVER=http://files.directadmin.com/services/all/majordomo
ADDPATCHES=1

SOURCEPATH="/usr/local/directadmin/scripts/packages/majordomo-1.94.5"

if [ ! -e ${SOURCEPATH}/Makefile ]
then
	echo "The source path for majordomo does not exist. Make sure the correct path is set in majordomo.sh";
	exit 0;
fi

/bin/mkdir -p /etc/virtual/majordomo

MDGID=$(id -g daemon)

if  [ "$OS" = "FreeBSD" ]; then
	/usr/sbin/pw useradd majordomo -b /etc/virtual/majordomo -g daemon -s /sbin/nologin 2> /dev/null
fi

MDUID=$(id -u majordomo)

/usr/local/bin/perl -pi -e 's/PERL = .*/PERL = \/usr\/local\/bin\/perl/' ${SOURCEPATH}/Makefile;
/usr/local/bin/perl -pi -e 's/W_HOME = .*/W_HOME = \/etc\/virtual\/majordomo/' ${SOURCEPATH}/Makefile;

# Perl and Bash weren't getting along. MDUID wasn't showing up so I did it this way.
STR="/usr/local/bin/perl -pi -e 's/W_USER = .*/W_USER = ${MDUID}/' ${SOURCEPATH}/Makefile";
eval "$STR";

STR="/usr/local/bin/perl -pi -e 's/W_GROUP = .*/W_GROUP = ${MDGID}/' ${SOURCEPATH}/Makefile";
eval "$STR";

STR="/usr/local/bin/perl -pi -e 's/TMPDIR = .*/TMPDIR = \/tmp/' ${SOURCEPATH}/Makefile";
eval "$STR";

# Fix REALLY-TO value in digests file
STR="/usr/local/bin/perl -pi -e 's/\$ARGV\[0\];/\$ARGV\[0\].\${whereami};/' ${SOURCEPATH}/digest";
eval "$STR";

STR="/usr/local/bin/perl -pi -e 's#/usr/test/majordomo#/etc/virtual/majordomo#' ${SOURCEPATH}/sample.cf";
eval "$STR";

cd ${SOURCEPATH} || exit

make wrapper
make install
make install-wrapper

/usr/local/bin/perl -pi -e 's#/usr/test/majordomo#/etc/virtual/majordomo#' /etc/virtual/majordomo/majordomo.cf

if [ $ADDPATCHES -eq 0 ]; then
	exit 0;
fi

PATCH1=majordomo.patch
PATCH1_PATH=/etc/virtual/majordomo/${PATCH1}
if [ ! -s "${PATCH1_PATH}" ]; then
	wget -O ${PATCH1_PATH} ${SERVER}/${PATCH1}
fi

if [ -s "${PATCH1_PATH}" ]; then
	cd /etc/virtual/majordomo || exit
	patch -p0 < majordomo.patch
else
	echo "Cannot find ${PATCH1_PATH} to patch majordomo.";
fi

 # Just to put up back where we were... likely not needed.
cd ${SOURCEPATH} || exoit

chmod 750 /etc/virtual/majordomo

exit 0
