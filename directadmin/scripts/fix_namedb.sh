#!/bin/sh
# Script written by DirectAdmin
# URL: http://www.directadmin.com
# Source: http://help.directadmin.com/item.php?id=330
#
# Usage:
#   chmod 755 fix_namedb.sh
#   ./fix_namedb.sb

## 2016-05-13: PortsBuild version
## PB: Verify:

readonly DA_PATH=/usr/local/directadmin
readonly DA_USERS_DIR=${DA_PATH}/data/users
readonly BIND_USER=bind
readonly BIND_GROUP=bind
readonly CHOWN=/usr/sbin/chown

readonly TTL=14400

OS_MAJ=$(uname -r | cut -d. -f1) # 9, 10

if [ "${OS_MAJ}" -eq 10 ]; then
  NAMED_DIR=/usr/local/etc/namedb
elif [ "${OS_MAJ}" -eq 9 ]; then
  NAMED_DIR=/etc/namedb
else
  NAMED_DIR=/etc/namedb
fi

readonly NAMED_DIR

NS1=$(grep ns1= "${DA_PATH}/conf/directadmin.conf" | cut -d= -f2)
NS2=$(grep ns2= "${DA_PATH}/conf/directadmin.conf" | cut -d= -f2)

for DA_USER in $(ls ${DA_USERS_DIR}); do
{
  for DOMAIN in $(cat "${DA_USERS_DIR}/${DA_USER}/domains.list"; cat ${DA_USERS_DIR}/${DA_USER}/domains/*.pointers 2>/dev/null | cut -d= -f1;); do
  {
    printf "%s\n" "${DOMAIN}"
    rm "${NAMED_DIR}/${DOMAIN}.db"

    if [ ! -r "${NAMED_DIR}/${DOMAIN}.db" ]; then
      IP=$(grep ip= "${DA_USERS_DIR}/${DA_USER}/domains/${DOMAIN}.conf" | cut -d= -f2)
      if [ "$IP" = "" ]; then
        IP=$(grep ip= "${DA_USERS_DIR}/${DA_USER}/user.conf" | cut -d= -f2)
      fi

      ## Write to ${NAMED_DIR}/${DOMAIN}.db
      {
        printf "\$TTL %s\n" "${TTL}"
        printf "@         IN      SOA     %s.         hostmaster.%s. (\n" "${NS1}" "${DOMAIN}"
        printf "                                                          2010101901\n"
        printf "                                                          %s\n" "${TTL}"
        printf "                                                          3600\n"
        printf "                                                          1209600\n"
        printf "                                                          86400 )\n"
        printf "\n"
        printf "%s.        %s   IN              NS      %s.\n" "${DOMAIN}" "${TTL}" "${NS1}"
        printf "%s.        %s   IN              NS      %s.\n" "${DOMAIN}" "${TTL}" "${NS2}"
        printf "\n"
        printf "%s.        %s   IN              A       %s\n" "${DOMAIN}" "${TTL}" "${IP}"
        printf "ftp               %s   IN              A       %s\n" "${TTL}" "${IP}"
        printf "localhost         %s   IN              A       127.0.0.1\n" "${TTL}"
        printf "mail              %s   IN              A       %s\n" "${TTL}" "${IP}"
        printf "pop               %s   IN              A       %s\n" "${TTL}" "${IP}"
        printf "smtp              %s   IN              A       %s\n" "${TTL}" "${IP}"
        printf "www               %s   IN              A       %s\n" "${TTL}" "${IP}"
        printf "\n"
        printf "%s.        %s   IN              MX      10 mail\n" "${DOMAIN}" "${TTL}"
        printf "%s.        %s   IN              TXT     \"v=spf1 a mx ip4:%s -all\"\n" "${DOMAIN}" "${TTL}" "${IP}"
        printf "\n"
      } > "${NAMED_DIR}/${DOMAIN}.db"

      ## PB: Todo: Replace with while loop
      for SUB in $(cat "${DA_USERS_DIR}/${DA_USER}/domains/${DOMAIN}.subdomains"); do
      {
        printf "%s              %s   IN              A       %s\n" "${SUB}" "${TTL}" "${IP}" >> "${NAMED_DIR}/${DOMAIN}.db"
      }
      done

      ${CHOWN} "${BIND_USER}:${BIND_GROUP}" "${NAMED_DIR}/${DOMAIN}.db"

      printf "  - database created.\n"
    fi
  }
  done
}
done

exit 0
