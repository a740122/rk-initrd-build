#!/bin/sh                                                                                                                                                          
export device=/dev/$1
export target=$2
export LOGPATH=/dev/console
if [ -b ${device} ]; then
    echo "Mount USB storage [${device}] on ${target} " > ${LOGPATH}
    mount ${device} ${target}
else
    echo "Unmount ${target} " > ${LOGPATH}
    umount -f ${target}
fi
