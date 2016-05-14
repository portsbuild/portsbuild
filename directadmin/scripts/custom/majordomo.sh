#!/bin/sh
## This script is written by DirectAdmin
## http://www.directadmin.com
## Script to install Majordomo (FreeBSD systems only)
## 2016-05-12: PortsBuild version
## PB: do:

MAKE=/usr/bin/make
PATCH=/usr/bin/patch
PERL=/usr/local/bin/perl
PW=/usr/sbin/pw

SERVER=http://files.directadmin.com/services/all/majordomo
ADDPATCHES=1

SOURCEPATH="/usr/local/directadmin/scripts/packages/majordomo-1.94.5"
TARGETPATH=/etc/virtual/majordomo

if [ ! -e "${SOURCEPATH}/Makefile" ]; then
	printf "The source path for Majordomo does not exist. Make sure the correct path is set in majordomo.sh\n"
	exit 0
fi

/bin/mkdir -p "${TARGETPATH}"

MDGID=$(id -g daemon)

${PW} useradd majordomo -b "${TARGETPATH}" -g daemon -s /sbin/nologin 2> /dev/null

MDUID=$(id -u majordomo)

## PB: Todo:
${PERL} -pi -e 's/PERL = .*/PERL = \/usr\/local\/bin\/perl/' ${SOURCEPATH}/Makefile
${PERL} -pi -e 's/W_HOME = .*/W_HOME = \/etc\/virtual\/majordomo/' ${SOURCEPATH}/Makefile

# Perl and Bash weren't getting along. MDUID wasn't showing up so I did it this way.
STR="${PERL} -pi -e 's/W_USER = .*/W_USER = ${MDUID}/' ${SOURCEPATH}/Makefile"
eval "$STR"

STR="${PERL} -pi -e 's/W_GROUP = .*/W_GROUP = ${MDGID}/' ${SOURCEPATH}/Makefile"
eval "$STR"

STR="${PERL} -pi -e 's/TMPDIR = .*/TMPDIR = \/tmp/' ${SOURCEPATH}/Makefile"
eval "$STR"

# Fix REALLY-TO value in digests file
STR="${PERL} -pi -e 's/\$ARGV\[0\];/\$ARGV\[0\].\${whereami};/' ${SOURCEPATH}/digest"
eval "$STR"

STR="${PERL} -pi -e 's#/usr/test/majordomo#/etc/virtual/majordomo#' ${SOURCEPATH}/sample.cf"
eval "$STR"

## PB: Todo: Remove directory changing
cd ${SOURCEPATH} || exit

${MAKE} -C ${SOURCEPATH} wrapper
${MAKE} -C ${SOURCEPATH} install
${MAKE} -C ${SOURCEPATH} install-wrapper

${PERL} -pi -e 's#/usr/test/majordomo#/etc/virtual/majordomo#' "${TARGETPATH}/majordomo.cf"

if [ $ADDPATCHES -eq 0 ]; then
	exit 0
fi

PATCH1=majordomo.patch
PATCH1_PATH="${TARGETPATH}/${PATCH1}"
if [ ! -s "${PATCH1_PATH}" ]; then
	wget -O ${PATCH1_PATH} ${SERVER}/${PATCH1}
fi

if [ -s "${PATCH1_PATH}" ]; then
	cd "${TARGETPATH}" || exit
	${PATCH} -p0 < majordomo.patch
else
	printf "Cannot find %s to patch Majordomo.\n" "${PATCH1_PATH}"
fi

## DA: Just to put up back where we were... likely not needed.
## PB: # cd ${SOURCEPATH} || exit

chmod 750 "${TARGETPATH}"

exit 0
