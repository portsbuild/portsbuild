#!/bin/sh
## discover.sh
## Please do not modify this file.
##
## Discover features and options on the current system.

## System level
#FOUND_HOSTNAME=$(hostname)

## DirectAdmin
#FOUND_DA_PATH=
#FOUND_SETUP_TXT=


## Keep track of existing binaries and configuration files.
FOUND_NAMED=0
FOUND_NAMED_CONF=0
FOUND_PHP_INI=0

## Verify if /usr/ports exists:
if [ ! -d ${PORTS_BASE}/ ]; then
  #  echo "*** Warning: FreeBSD ports directory (/usr/ports) not initialized."
    FOUND_PORTS=0
else
  FOUND_PORTS=1
fi

################################################################################################################################

## Verify if pkg(8) is activated:
FOUND_PKG=$(/usr/sbin/pkg -N > /dev/null 2>&1)

if [ $? -gt 0 ]; then
    echo "*** Warning: FreeBSD pkg(8) system not activated."
    FOUND_PKG=0
else
  FOUND_PKG=1
fi

################################################################################################################################

## Find named (BIND)
FOUND_NAMED=0

if [ "${OS_MAJ}" -eq 10 ]; then
  if [ ! -e /usr/local/sbin/named ]; then
    #echo "*** Error: Cannot find the named binary.";
    FOUND_NAMED=0
  else
    FOUND_NAMED=1
  fi
  if [ ! -e /usr/local/etc/namedb/named.conf ]; then
    #echo "*** Error: Cannot find /usr/local/etc/namedb/named.conf.";
    FOUND_NAMED_CONF=0
  else
    FOUND_NAMED_CONF=1
  fi
elif [ "$OS_MAJ" -eq 9 ]; then
  if [ ! -e /usr/sbin/named ]; then
    #echo "*** Error: Cannot find the named binary.";
    FOUND_NAMED=0
  else
    FOUND_NAMED=1
  fi
  if [ ! -e /var/named/etc/namedb/named.conf ]; then
    #echo "*** Error: Cannot find /var/named/etc/namedb/named.conf. Make sure Bind is completely installed.";
    FOUND_NAMED_CONF=0
  else
    FOUND_NAMED_CONF=1
  fi
fi

################################################################################################################################

## See if IPV6 is enabled in DirectAdmin:
IPV6_ENABLED=0
if [ -e "${DA_BIN}" ]; then
  IPV6_ENABLED=$(${DA_BIN} c | grep -m1 '^ipv6=' | cut -d= -f2)
fi

# echo "IPV6_ENABLED: ${IPV6_ENABLED}"

################################################################################################################################

## Have PHP System (from CB2)
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
