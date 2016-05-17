#!/bin/sh

FILE=$1

if [ -n "$(/usr/local/bin/clamdscan --infected --no-summary "${FILE}")" ]; then
	echo 0
else
	echo 1
fi

exit 0
