#!/bin/sh

################################################################################################################################
## Validation
################################################################################################################################

## Verify if PortsBuild directory exists.
if [ ! -d "/usr/local/directadmin/portsbuild" ]; then
  FOUND_PORTSBUILD=0
else
  FOUND_PORTSBUILD=1
fi

## Keep track of existing binaries and configuration files.
FOUND_NAMED=0
FOUND_NAMED_CONF=0
FOUND_PHP_INI=0



## Verify if pkg(8) is activated:
FOUND_PKG=$(/usr/sbin/pkg -N > /dev/null 2>&1)

if [ $? -gt 0 ]; then
  # echo "*** Warning: FreeBSD pkg(8) system not activated."
  FOUND_PKG=0
else
  FOUND_PKG=1
fi



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






# BIND_ADDRESS=--bind-address=$IP
# if [ "${DA_LAN}" -eq 1 ]; then
#   BIND_ADDRESS="";
# fi
