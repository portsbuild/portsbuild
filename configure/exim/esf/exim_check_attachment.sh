#/bin/sh

if [ "${1}" != "zip" ]; then
  echo "$0: we can only scan zip files";
  exit 0
fi

UNZIP=/usr/bin/unzip

P=/var/spool/exim/scan/${2}
Z=${D}/${3}

cd "${P}"

if [ ! -s $Z ]; then
  exit 0
fi

if [ $( ${UNZIP} -l "${Z}" | \
  tail -n +4 |head -n -2 | \
  egrep -i '[.](bat|btm|cmd|com|cpl|dat|dll|exe|lnk|msi|pif|prf|reg|scr|vb|vbs|url|zip|js)$' | \
  wc -l ) -gt 0 ]
then
 exit 1
fi

exit 0
