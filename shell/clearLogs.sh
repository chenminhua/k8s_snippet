#!/bin/bash
LOG_DIR=/var/log
ROOT_UID=0

if [ "$UID" -ne "$ROOT_UID" ]
then
    echo "must be root user"
    exit 1
fi

cd $LOG_DIR || {
    echo "cannot change to $LOG_DIR"
    exit 1
}

cat /dev/null > messages && {
    echo "Logs cleaned up"
    exit 0
}

echo "Logs cleaned up fail"
exit 1
