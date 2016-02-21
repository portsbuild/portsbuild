#!/bin/sh

# Source: http://help.directadmin.com/item.php?id=330
#
# Usage:
# chmod 755 fix_namedb.sh
# ./fix_namedb.sb


NAMED_DIR=/etc/namedb
DA_USERS_DIR=/usr/local/directadmin/data/users
NS1=`grep ns1= /usr/local/directadmin/conf/directadmin.conf | cut -d= -f2`
NS2=`grep ns2= /usr/local/directadmin/conf/directadmin.conf | cut -d= -f2`

for DA_USER in `ls ${DA_USERS_DIR}`; do
{
          for DOMAIN in `cat ${DA_USERS_DIR}/${DA_USER}/domains.list; cat ${DA_USERS_DIR}/${DA_USER}/domains/*.pointers 2>/dev/null | cut -d= -f1;`; do
          {
                    echo $DOMAIN
                    rm ${NAMED_DIR}/${DOMAIN}.db

                    if [ ! -r "${NAMED_DIR}/${DOMAIN}.db" ]; then
                              IP=`cat ${DA_USERS_DIR}/${DA_USER}/domains/${DOMAIN}.conf | grep ip= | cut -d= -f2`
                              if [ "$IP" = "" ]; then
                                         IP=`cat ${DA_USERS_DIR}/${DA_USER}/user.conf | grep ip= | cut -d= -f2`
                              fi

                              echo "\$TTL 14400"  >  ${NAMED_DIR}/${DOMAIN}.db
                              echo "@         IN      SOA     ${NS1}.         hostmaster.${DOMAIN}. ("        >> ${NAMED_DIR}/${DOMAIN}.db
                              echo "                                                          2010101901"                     >> ${NAMED_DIR}/${DOMAIN}.db
                              echo "                                                          14400"                          >> ${NAMED_DIR}/${DOMAIN}.db
                              echo "                                                          3600"                           >> ${NAMED_DIR}/${DOMAIN}.db
                              echo "                                                          1209600"                        >> ${NAMED_DIR}/${DOMAIN}.db
                              echo "                                                          86400 )"                        >> ${NAMED_DIR}/${DOMAIN}.db
                              echo ""                                                                                         >> ${NAMED_DIR}/${DOMAIN}.db
                              echo "${DOMAIN}.        14400   IN              NS      ${NS1}."                >> ${NAMED_DIR}/${DOMAIN}.db
                              echo "${DOMAIN}.        14400   IN              NS      ${NS2}."                >> ${NAMED_DIR}/${DOMAIN}.db
                              echo ""  >> ${NAMED_DIR}/${DOMAIN}.db
                              echo "${DOMAIN}.        14400   IN              A       ${IP}"                             >> ${NAMED_DIR}/${DOMAIN}.db
                              echo "ftp               14400   IN              A       ${IP}"                             >> ${NAMED_DIR}/${DOMAIN}.db
                              echo "localhost         14400   IN              A       127.0.0.1"                              >> ${NAMED_DIR}/${DOMAIN}.db
                              echo "mail              14400   IN              A       ${IP}"                             >> ${NAMED_DIR}/${DOMAIN}.db
                              echo "pop               14400   IN              A       ${IP}"                             >> ${NAMED_DIR}/${DOMAIN}.db
                              echo "smtp              14400   IN              A       ${IP}"                             >> ${NAMED_DIR}/${DOMAIN}.db
                              echo "www               14400   IN              A       ${IP}"                             >> ${NAMED_DIR}/${DOMAIN}.db
                              echo ""  >> ${NAMED_DIR}/${DOMAIN}.db
                              echo "${DOMAIN}.        14400   IN              MX      10 mail"                                >> ${NAMED_DIR}/${DOMAIN}.db
                              echo "${DOMAIN}.        14400   IN              TXT     \"v=spf1 a mx ip4:${IP} -all\""    >> ${NAMED_DIR}/${DOMAIN}.db

                              echo ""  >> ${NAMED_DIR}/${DOMAIN}.db

                              for SUB in `cat ${DA_USERS_DIR}/${DA_USER}/domains/${DOMAIN}.subdomains`; do
                              {
                                echo "${SUB}              14400   IN              A       ${IP}"                             >> ${NAMED_DIR}/${DOMAIN}.db
                              }
                              done;

                              chown bind:bind ${NAMED_DIR}/${DOMAIN}.db

                              echo "  - database created."

                    fi
          }
          done;
}
done;
