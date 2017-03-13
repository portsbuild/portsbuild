#!/bin/sh
# This script is written by Martynas Bendorius and DirectAdmin
# It is used to create/renew let's encrypt certificate for a domain
# Official DirectAdmin webpage: http://www.directadmin.com
# Usage:
# ./letsencrypt.sh <domain> <key-size>

## 2016-05-12: PortsBuild version
## 2017-02-26: Upgraded to version 1.06
## Todo:

DA_PATH=/usr/local/directadmin
TASKQ="${DA_PATH}/data/task.queue"
PERL=/usr/local/bin/perl
CURL=/usr/local/bin/curl
OPENSSL=/usr/bin/openssl


MYUID=$(/usr/bin/id -u)
if [ "${MYUID}" != 0 ]; then
  printf "You require root access to run this script\n"
  exit 0
fi

DEFAULT_KEY_SIZE=""

if [ $# -lt 2 ]; then
  echo "Usage:";
  echo "$0 request|renew|revoke <domain> <key-size> (<csr-config-file>)";
  echo "you gave #$#: $0 $1 $2 $3";
  exit 0;
elif [ $# -lt 3 ]; then
  # No key size specified, assign default one
  DEFAULT_KEY_SIZE=4096
fi

if [ ! -s ${DA_PATH}/directadmin ]; then
  printf "Unable to find DirectAdmin binary /usr/local/directadmin/directadmin. Exiting...\n"
  exit 1
fi

# Staging/development
# API_URI="acme-staging.api.letsencrypt.org"
API_URI="acme-v01.api.letsencrypt.org"
API="https://${API_URI}"
LICENSE="https://letsencrypt.org/documents/LE-SA-v1.1.1-August-1-2016.pdf"
CHALLENGETYPE="http-01"
LICENSE_KEY_MIN_DATE=1470383674

CURL=/usr/local/bin/curl
if [ ! -x ${CURL} ]; then
    CURL=/usr/bin/curl
fi

CURL_OPTIONS="--connect-timeout 15 -k"

TIMESTAMP=`date +%s`

LETSENCRYPT_OPTION=$(${DA_PATH}/directadmin c | grep '^letsencrypt=' | cut -d= -f2)
ACCESS_GROUP_OPTION=$(${DA_PATH}/directadmin c | grep '^secure_access_group=' | cut -d= -f2)

FILE_CHOWN="diradmin:diradmin"
FILE_CHMOD="640"
if [ "${ACCESS_GROUP_OPTION}" != "" ]; then
  FILE_CHOWN="diradmin:${ACCESS_GROUP_OPTION}"
fi


# Encode data using base64 with URL-safe chars
base64_encode() {
  ${OPENSSL} base64 -e | tr -d '\n\r' | tr "+/" "-_" | tr -d '= '
}


#Send signed request
send_signed_request() {
  REQ_TYPE="${1}"
  URL="${2}"
  PAYLOAD="${3}"

  #Use base64 for the payload
  PAYLOAD64="`echo -n \"${PAYLOAD}\" | base64_encode`"

  #Get nonce from acme-server
  NONCE="`${CURL} --silent -I ${API}/directory | grep '^Replay-Nonce:' | cut -d' ' -f2 | tr -d '\n\r'`"

  #Create header without nonce, use thumbprint
  HEADER="{\"alg\": \"RS256\", \"jwk\": ${FOR_THUMBPRINT}}"

  #Create header with nonce encode as base64
  PROTECTED="{\"nonce\": \"${NONCE}\", \"alg\": \"RS256\", \"jwk\": ${FOR_THUMBPRINT}}"

  PROTECTED64="`echo -n ${PROTECTED} | base64_encode`"

  SIGN64="`echo -n \"${PROTECTED64}.${PAYLOAD64}\" | ${OPENSSL} dgst -sha256 -sign \"${LETSENCRYPT_ACCOUNT_KEY}\" | base64_encode`"

  #Form the BODY to send
  BODY="{\"header\": ${HEADER}, \"protected\": \"${PROTECTED64}\", \"payload\": \"${PAYLOAD64}\", \"signature\": \"${SIGN64}\"}"

  #Send the BODY, save the response
  if [ "${REQ_TYPE}" = "cert" ]; then
    CERT64="`${CURL} --silent -X POST --data \"${BODY}\" \"${URL}\" | ${OPENSSL} base64 -e`"
  else
    RESPONSE="`${CURL} -i --silent -X POST --data \"${BODY}\" \"${URL}\"`"

    #HTTP status code
    HTTP_STATUS=`echo "${RESPONSE}" | grep -v 'HTTP.*100 Continue' | grep -m1 'HTTP.*' | awk '{print $2}'`
  fi
}

ACTION=$1
DOMAIN=$2
if [ "${DEFAULT_KEY_SIZE}" = "" ]; then
  KEY_SIZE=$3
else
  KEY_SIZE=${DEFAULT_KEY_SIZE}
fi

CSR_CF_FILE=$4
DOCUMENT_ROOT=$5
#We need the domain to match in /etc/virtual/domainowners, if we use grep -F, we cannot use any regex'es including ^
DOMAIN_ESCAPED="`echo ${DOMAIN} | perl -p0 -e 's#\.#\\\.#'`"

if grep -m1 -q "^${DOMAIN_ESCAPED}:" /etc/virtual/domainowners; then
  USER=`grep -m1 "^${DOMAIN_ESCAPED}:" /etc/virtual/domainowners | cut -d' ' -f2`
  HOSTNAME=0
elif grep -m1 -q "^${DOMAIN_ESCAPED}$" /etc/virtual/domains; then
  USER="root"
  if /usr/local/directadmin/directadmin c | grep -m1 -q "^servername=${DOMAIN_ESCAPED}\$"; then
    echo "Setting up certificate for a hostname: ${DOMAIN}"
    HOSTNAME=1
  else
    echo "Domain exists in /etc/virtual/domains, but is not set as a hostname in DirectAdmin. Unable to find 'servername=${DOMAIN}' in the output of '/usr/local/directadmin/directadmin c'. Exiting..."
    exit 1
  fi
else
  echo "Domain does not exist on the system. Unable to find ${DOMAIN} in /etc/virtual/domainowners. Exiting..."
  exit 1
fi

if [ ${KEY_SIZE} -ne 2048 ] && [ ${KEY_SIZE} -ne 4096 ]; then
  echo "Wrong key size. It must be 2048 or 4096. Exiting..."
  exit 1
fi

if [ "${CSR_CF_FILE}" != "" ] && [ ! -s ${CSR_CF_FILE} ]; then
  echo "CSR config file ${CSR_CF_FILE} passed but does not exist or is empty."
  ls -la ${CSR_CF_FILE}
  exit 1
fi

EMAIL="${USER}@${DOMAIN}"

DA_USERDIR="/usr/local/directadmin/data/users/${USER}"
DA_CONFDIR="/usr/local/directadmin/conf"
HOSTNAME_DIR="/var/www/html"

if [ ! -d "${DA_USERDIR}" ] && [ "${HOSTNAME}" -eq 0 ]; then
    echo "${DA_USERDIR} not found, exiting..."
    exit 1
elif [ ! -d "${DA_CONFDIR}" ] && [ "${HOSTNAME}" -eq 1 ]; then
    echo "${DA_CONFDIR} not found, exiting..."
    exit 1
fi

if [ "${HOSTNAME}" -eq 0 ]; then
    LETSENCRYPT_ACCOUNT_KEY="${DA_USERDIR}/letsencrypt.key"
    KEY="${DA_USERDIR}/domains/${DOMAIN}.key"
    CERT="${DA_USERDIR}/domains/${DOMAIN}.cert"
    CACERT="${DA_USERDIR}/domains/${DOMAIN}.cacert"
    CSR="${DA_USERDIR}/domains/${DOMAIN}.csr"
    SAN_CONFIG="${DA_USERDIR}/domains/${DOMAIN}.san_config"
    if [ "${DOCUMENT_ROOT}" != "" ]; then
        DOMAIN_DIR="${DOCUMENT_ROOT}"
    else
        USER_HOMEDIR="`grep -m1 \"^${USER}:\" /etc/passwd | cut -d: -f6`"
        DOMAIN_DIR="${USER_HOMEDIR}/domains/${DOMAIN}/public_html"
    fi
    WELLKNOWN_PATH="${DOMAIN_DIR}/.well-known/acme-challenge"
else
    LETSENCRYPT_ACCOUNT_KEY="${DA_CONFDIR}/letsencrypt.key"
    KEY="${DA_CONFDIR}/cakey.pem"
    CERT="${DA_CONFDIR}/cacert.pem"
    CACERT="${DA_CONFDIR}/carootcert.pem"
    CSR="${DA_CONFDIR}/ca.csr"
    SAN_CONFIG="${DA_CONFDIR}/ca.san_config"
    DOMAIN_DIR="${HOSTNAME_DIR}"
    WELLKNOWN_PATH="${DOMAIN_DIR}/.well-known/acme-challenge"
fi

if [ "${CSR_CF_FILE}" != "" ] && [ -s ${CSR_CF_FILE} ]; then
    if grep -q -m1 '^emailAddress' ${CSR_CF_FILE}; then
        EMAIL="`grep '^emailAddress' ${CSR_CF_FILE} | awk '{print $3}'`"
    fi
elif [ "${CSR_CF_FILE}" = "" ] && [ -s ${SAN_CONFIG} ]; then
        if grep -q -m1 '^emailAddress' ${SAN_CONFIG}; then
                EMAIL="`grep '^emailAddress' ${SAN_CONFIG} | awk '{print $3}'`"
        fi
fi

#It could be a symlink, so we use -e
if [ ! -e "${DOMAIN_DIR}" ]; then
    echo "${DOMAIN_DIR} does not exist. Exiting..."
    exit 1
fi

#Create account KEY if it does not exist
OLD_KEY=1
if [ ! -s "${LETSENCRYPT_ACCOUNT_KEY}" ]; then
    echo "Generating ${KEY_SIZE} bit RSA key for let's encrypt account..."
    echo "openssl genrsa ${KEY_SIZE} > \"${LETSENCRYPT_ACCOUNT_KEY}\""
    ${OPENSSL} genrsa ${KEY_SIZE} > "${LETSENCRYPT_ACCOUNT_KEY}"
    chown diradmin:diradmin ${LETSENCRYPT_ACCOUNT_KEY}
    chmod 600 ${LETSENCRYPT_ACCOUNT_KEY}
    OLD_KEY=0
fi

#We use perl here to convert HEX to BIN
PUBLIC_EXPONENT64=`${OPENSSL} rsa -in "${LETSENCRYPT_ACCOUNT_KEY}" -noout -text | grep "^publicExponent:" | awk '{print $3}' | cut -d'(' -f2 | cut -d')' -f1 | tr -d '\r\n' | tr -d 'x' | perl -n0 -e 's/([0-9a-f]{2})/print chr hex $1/gie' | base64_encode`
PUBLIC_MODULUS64=`${OPENSSL} rsa -in "${LETSENCRYPT_ACCOUNT_KEY}" -noout -modulus | cut -d'=' -f2 | perl -n0 -e 's/([0-9a-f]{2})/print chr hex $1/gie' | base64_encode`

FOR_THUMBPRINT="{\"e\": \"${PUBLIC_EXPONENT64}\", \"kty\": \"RSA\", \"n\": \"${PUBLIC_MODULUS64}\"}"
THUMBPRINT=`echo -n "${FOR_THUMBPRINT}" | tr -d ' ' | ${OPENSSL} sha -sha256 -binary | base64_encode`

#Register the new key with the acme-server
if [ ${OLD_KEY} -eq 0 ]; then
    send_signed_request "normal" "${API}/acme/new-reg" '{"resource": "new-reg", "contact":["'"mailto:${EMAIL}"'"], "agreement": "'"${LICENSE}"'"}'
    if [ "${HTTP_STATUS}" = "" ] || [ "${HTTP_STATUS}" -eq 201 ] ; then
        echo "Account has been registered."
    elif [ "${HTTP_STATUS}" -eq 409 ] ; then
        echo "Account is already registered."
    else
        echo "Account registration error. Response: ${RESPONSE}."
        exit 1
    fi
fi

if [ "${ACTION}" = "revoke" ]; then
    if [ ! -e ${CERT} ]; then
        echo "Certificate ${CERT} does not exist, there is nothing to revoke."
        exit 1
    fi
    DER64="`${OPENSSL} x509 -in ${CERT} -inform PEM -outform DER | base64_encode`"
    send_signed_request "normal" "${API}/acme/revoke-cert" '{"resource": "revoke-cert", "certificate": "'"${DER64}"'"}'
    if [ "${HTTP_STATUS}" = "" ] || [ "${HTTP_STATUS}" -eq 200 ] ; then
        echo "Certificate has been successfully revoked."
    else
        echo "Certificate revocation error. Response: ${RESPONSE}."
        exit 1
    fi
    exit 0
fi

#Overwrite san_config file if csr_cf_file path is different
if [ "${CSR_CF_FILE}" != "" ] && [ "${CSR_CF_FILE}" != "${SAN_CONFIG}" ]; then
    cp -f ${CSR_CF_FILE} ${SAN_CONFIG}
fi

#For multi-domains (www and non-www one)
SAN=""

if [ -s ${SAN_CONFIG} ]; then
    SAN="`cat \"${SAN_CONFIG}\" | grep '^subjectAltName=' | cut -d= -f2`"
elif [ "${HOSTNAME}" -eq 0 ]; then
    if ! echo "${DOMAIN}" | grep -q "^www\."; then
        #We have a domain without www., add www domain to to SAN too
        SAN="DNS:${DOMAIN}, DNS:www.${DOMAIN}"
    else
        #We have a domain with www., drop www and add it to SAN too
        DOMAIN2=`echo ${DOMAIN} | perl -p0 -e 's#^www.##'`
        SAN="DNS:${DOMAIN2}, DNS:www.${DOMAIN2}"
    fi
else
    #For hostname, we add www, mail, ftp, pop, smtp to the SAN
    if ! echo "${DOMAIN}" | grep -q "^www\."; then
        #We have a domain without www., add www domain to to SAN too
        SAN="DNS:${DOMAIN}, DNS:www.${DOMAIN}, DNS:mail.${DOMAIN}, DNS:ftp.${DOMAIN}, DNS:pop.${DOMAIN}, DNS:smtp.${DOMAIN}"
    else
        #We have a domain with www., drop www and add it to SAN too
        DOMAIN2=`echo ${DOMAIN} | perl -p0 -e 's#^www.##'`
        SAN="DNS:${DOMAIN2}, DNS:www.${DOMAIN2}, DNS:mail.${DOMAIN2}, DNS:ftp.${DOMAIN2}, DNS:pop.${DOMAIN2}, DNS:smtp.${DOMAIN2}"
    fi
fi

DOMAINS="`echo ${SAN} | tr -d '\",' | perl -p0 -e 's#DNS:##g'`"

#Create san_config
if [ ! -s ${SAN_CONFIG} ]; then
    echo "[ req_distinguished_name ]" > ${SAN_CONFIG}
    echo "CN = ${DOMAIN}" >> ${SAN_CONFIG}
    echo "[ req ]" >> ${SAN_CONFIG}
    echo "distinguished_name = req_distinguished_name" >> ${SAN_CONFIG}
    echo "[SAN]" >> ${SAN_CONFIG}
    echo "subjectAltName=${SAN}" >> ${SAN_CONFIG}
fi

chown diradmin:diradmin ${SAN_CONFIG}
chmod 600 ${SAN_CONFIG}

#For each of the domains, we need to verify them
for single_domain in ${DOMAINS}; do {
    # Connect to the acme-server to get a new challenge token to verify the domain
    echo "Getting challenge for ${single_domain} from acme-server..."
    send_signed_request "normal" "${API}/acme/new-authz" '{"resource": "new-authz", "identifier": {"type": "dns", "value": "'"${single_domain}"'"}}'

    #Account has a key for let's encrypt, but it's not registered
    if [ "${HTTP_STATUS}" -eq 403 ] ; then
        echo "User let's encrypt key has been found, but not registered. Registering..."
        send_signed_request "normal" "${API}/acme/new-reg" '{"resource": "new-reg", "contact":["'"mailto:${EMAIL}"'"], "agreement": "'"${LICENSE}"'"}'
        if [ "${HTTP_STATUS}" = "" ] || [ "${HTTP_STATUS}" -eq 201 ] ; then
            echo "Account has been registered."
        elif [ "${HTTP_STATUS}" -eq 409 ] ; then
            echo "Account is already registered."
        else
            echo "Account registration error. Response: ${RESPONSE}."
            exit 1
        fi

        echo "Getting challenge for ${DOMAIN} from acme-server..."
        send_signed_request "normal" "${API}/acme/new-authz" '{"resource": "new-authz", "identifier": {"type": "dns", "value": "'"${single_domain}"'"}}'
    fi

    if [ "${HTTP_STATUS}" -ne 201 ] ; then
        echo "new-authz error: ${RESPONSE}. Exiting..."
        exit 1
    fi

    CHALLENGE="`echo "${RESPONSE}" | egrep -o '{[^{]*\"type\":\"http-01\"[^}]*'`"

    CHALLENGE_TOKEN="`echo \"${CHALLENGE}\" | tr ',' '\n' | grep -m1 '\"token\":' | cut -d'\"' -f4`"
    CHALLENGE_URI="`echo \"${CHALLENGE}\" | tr ',' '\n' | grep -m1 '\"uri\":' | cut -d'\"' -f4`"
    CHALLENGE_STATUS="`echo \"${CHALLENGE}\" | tr ',' '\n' | grep -m1 '\"status\":' | cut -d'\"' -f4`"

    KEYAUTH="${CHALLENGE_TOKEN}.${THUMBPRINT}"

    if [ "${HOSTNAME}" -eq 1 ]; then
        mkdir -p ${WELLKNOWN_PATH}
        chown webapps:webapps ${HOSTNAME_DIR}/.well-known
        chown webapps:webapps ${WELLKNOWN_PATH}
    fi

    if [ ! -d "${WELLKNOWN_PATH}" ]; then
        echo "Cannot find ${WELLKNOWN_PATH}. Create this path, ensure it's chowned to the User.";
        exit 1;
    fi

    echo "${KEYAUTH}" > "${WELLKNOWN_PATH}/${CHALLENGE_TOKEN}"
    send_signed_request "normal" "${CHALLENGE_URI}" "{\"resource\": \"challenge\", \"keyAuthorization\": \"${KEYAUTH}\"}"

    if [ ${HTTP_STATUS} -ne 202 ] ; then
        echo "Challenge error: ${RESPONSE}. Exiting..."
        exit 1
    fi

    echo "Waiting for domain verification..."
    while [ "${CHALLENGE_STATUS}" = "pending" ]; do
        sleep 1
        FULL_CHALLENGE_STATUS="`${CURL} --silent -X GET \"${CHALLENGE_URI}\"`"
        CHALLENGE_STATUS="`echo ${FULL_CHALLENGE_STATUS} | tr ',' '\n' | grep -m1 '\"status\":' | cut -d'\"' -f4`"
        CHALLENGE_DETAIL="`echo ${FULL_CHALLENGE_STATUS} | tr ',' '\n' | grep -m1 '\"detail\":' | cut -d'\"' -f4`"
    done

    rm -f "${WELLKNOWN_PATH}/${CHALLENGE_TOKEN}"

    if [ "${CHALLENGE_STATUS}" = "valid" ]; then
        echo "Challenge is valid."
    else
        echo "Challenge is ${CHALLENGE_STATUS}. Details: ${CHALLENGE_DETAIL}. Exiting..."
        exit 1
    fi
}
done


#Create domain key, also generate CSR for the domain
echo "Generating ${KEY_SIZE} bit RSA key for ${DOMAIN}..."
echo "openssl genrsa ${KEY_SIZE} > \"${KEY}.new\""
${OPENSSL} genrsa ${KEY_SIZE} > "${KEY}.new"

${OPENSSL} req -new -sha256 -key "${KEY}.new" -subj "/CN=${DOMAIN}" -reqexts SAN -config "${SAN_CONFIG}" -out "${CSR}"

#Request certificate from let's encrypt
DER64="`${OPENSSL} req -in ${CSR} -outform DER | base64_encode`"

send_signed_request "cert" "${API}/acme/new-cert" "{\"resource\": \"new-cert\", \"csr\": \"${DER64}\"}"

SIZE_OF_CERT64="`echo ${CERT64} | wc -c`"
#It's likely text encoded if there are less than 500 chars, so we have a JSON response
if [ ${SIZE_OF_CERT64} -lt 500 ]; then
    echo "Size of certificate response is smaller than 500 characters, it means something went wrong. Printing response..."
    echo "${CERT64}" | ${OPENSSL} enc -base64 -d | grep -o '"detail":"[^"]*"'
    echo ""
    exit 1
fi

echo "-----BEGIN CERTIFICATE-----" > ${CERT}.new
echo "${CERT64}" >> ${CERT}.new
echo "-----END CERTIFICATE-----" >> ${CERT}.new

${OPENSSL} x509 -text < ${CERT}.new > /dev/null
if [ $? -ne 0 ]; then
    echo "Certificate error in ${CERT}. Exiting..."
    /bin/rm -f ${KEY}.new ${CERT}.new
    exit 1
fi

CACERT64=`${CURL} --silent -X GET "${API}/acme/issuer-cert" | ${OPENSSL} base64 -e`
SIZE_OF_CACERT64="`echo ${CERT64} | wc -c`"
if [ ${SIZE_OF_CACERT64} -gt 500 ]; then
    echo "-----BEGIN CERTIFICATE-----" > ${CACERT}
    echo "${CACERT64}" >> ${CACERT}
    echo "-----END CERTIFICATE-----" >> ${CACERT}
fi

#everything went well, move the new files.
/bin/mv -f ${KEY}.new ${KEY}
/bin/mv -f ${CERT}.new ${CERT}
date +%s > ${CERT}.creation_time

chown diradmin:diradmin ${KEY} ${CERT} ${CACERT} ${CSR} ${CERT}.creation_time
chmod 600 ${KEY} ${CERT} ${CACERT} ${CSR} ${CERT}.creation_time

#Change exim, apache/nginx certs
if [ "${HOSTNAME}" -eq 1 ]; then
    echo "DirectAdmin certificate has been setup."

    #Exim
    echo "Setting up cert for Exim..."
    EXIMKEY="/etc/exim.key"
    EXIMCERT="/etc/exim.cert"
    cp -f ${KEY} ${EXIMKEY}
    cat ${CERT} ${CACERT} > ${EXIMCERT}
    chown mail:mail ${EXIMKEY} ${EXIMCERT}
    chmod 600 ${EXIMKEY} ${EXIMCERT}

    echo "action=exim&value=restart" >> ${TASKQ}
    echo "action=dovecot&value=restart" >> ${TASKQ}

    #Apache
    echo "Setting up cert for WWW server..."
    if [ -d /etc/httpd/conf/ssl.key ] && [ -d /etc/httpd/conf/ssl.crt ]; then
        APACHEKEY="/etc/httpd/conf/ssl.key/server.key"
        APACHECERT="/etc/httpd/conf/ssl.crt/server.crt"
        APACHECACERT="/etc/httpd/conf/ssl.crt/server.ca"
        APACHECERTCOMBINED="${APACHECERT}.combined"
        cp -f ${KEY} ${APACHEKEY}
        cp -f ${CERT} ${APACHECERT}
        cp -f ${CACERT} ${APACHECACERT}
        cat ${APACHECERT} ${APACHECACERT} > ${APACHECERTCOMBINED}
        chown root:root ${APACHEKEY} ${APACHECERT} ${APACHECACERT} ${APACHECERTCOMBINED}
        chmod 600 ${APACHEKEY} ${APACHECERT} ${APACHECACERT} ${APACHECERTCOMBINED}

        echo "action=httpd&value=restart" >> ${TASKQ}
    fi

    #Nginx
    if [ -d /etc/nginx/ssl.key ] && [ -d /etc/nginx/ssl.crt ]; then
        NGINXKEY="/etc/nginx/ssl.key/server.key"
        NGINXCERT="/etc/nginx/ssl.crt/server.crt"
        NGINXCACERT="/etc/nginx/ssl.crt/server.ca"
        NGINXCERTCOMBINED="${NGINXCERT}.combined"
        cp -f ${KEY} ${NGINXKEY}
        cp -f ${CERT} ${NGINXCERT}
        cp -f ${CACERT} ${NGINXCACERT}
        cat ${NGINXCERT} ${NGINXCACERT} > ${NGINXCERTCOMBINED}
        chown root:root ${NGINXKEY} ${NGINXCERT} ${NGINXCACERT} ${NGINXCERTCOMBINED}
        chmod 600 ${NGINXKEY} ${NGINXCERT} ${NGINXCACERT} ${NGINXCERTCOMBINED}

        echo "action=nginx&value=restart" >> ${TASKQ}
    fi

    #FTP
    echo "Setting up cert for FTP server..."
    cat ${KEY} ${CERT} ${CACERT} > /etc/pure-ftpd.pem
    chmod 600 /etc/pure-ftpd.pem
    chown root:root /etc/pure-ftpd.pem

    if /usr/local/directadmin/directadmin c | grep -m1 -q "^pureftp=1\$"; then
        echo "action=pure-ftpd&value=restart" >> ${TASKQ}
    else
        echo "action=proftpd&value=restart" >> ${TASKQ}
    fi

    echo "action=directadmin&value=restart" >> ${TASKQ}

    echo "The services will be retarted in about 1 minute via the dataskq."
fi

echo "Certificate for ${DOMAIN} has been created successfully!"
exit 0
