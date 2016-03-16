#!/bin/sh
## Restart named (BIND) after a DNS entry has been written.
## Source: http://www.directadmin.com/features.php?id=450
## Created by PortsBuild

if [ -x /usr/sbin/named ] || [ -x /usr/local/sbin/named ]; then
  /usr/sbin/service named restart
fi

exit 0;
