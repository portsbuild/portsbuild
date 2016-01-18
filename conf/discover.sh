#!/bin/sh
## discover.sh
## Please do not modify this file.
##
## Discover features and options on the system.

## System level
FOUND_HOSTNAME=$(hostname)

## DirectAdmin
#FOUND_DA_PATH=
#FOUND_SETUP_TXT=


## Keep track of existing configuration files.
#FOUND_NAMED_CONF=
#FOUND_PHP_INI=


## See if IPV6 is enabled in DirectAdmin:
IPV6_ENABLED=0
if [ -e ${DA_BIN} ]; then
  IPV6_ENABLED=$(${DA_BIN} c | grep -m1 '^ipv6=' | cut -d= -f2)
fi
echo "IPV6_ENABLED: ${IPV6_ENABLED}"


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
