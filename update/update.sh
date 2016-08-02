#!/bin/sh

COLOR_ERROR='\033[01;31m'
COLOR_DEBUG='\033[01;34m'
COLOR_NOTIFY='\033[01;33m'
COLOR_RESET='\033[00;00m'

DEBUG()
{
    LOG_TEXT=$1
    /bin/echo -e "${COLOR_DEBUG}${LOG_TEXT}${COLOR_RESET}"
}

INFO()
{
    LOG_TEXT=$1
    /bin/echo "${LOG_TEXT}"
}

ERROR()
{
    LOG_TEXT=$1
    /bin/echo -e "${COLOR_ERROR}${LOG_TEXT}${COLOR_RESET}"
}

NOTIFY()
{
    LOG_TEXT=$1
    /bin/echo -e "${COLOR_NOTIFY}${LOG_TEXT}${COLOR_RESET}"
}

# We don't run the script if system is not booted in ramdisk
IS_RAMBOOT=`cat /proc/cmdline | /bin/grep -o "/dev/ram0"`
if [ "$IS_RAMBOOT" != "/dev/ram0" ]; then
    ERROR "System not booted with ramdisk, update exit"
    exit
fi

################# DEFINITIONS #################################################
LCD="/dev/null" #"/dev/tty0"
VERIFICATION_TOOL=/usr/sbin/verify
PUBLIC_KEY=/etc/verify_pub.pem
BOOT_IMAGE=boot.img
BOOT_SIGNATURE=boot.sgn
ROOTFS_IMAGE=rootfs.img
ROOTFS_SIGNATURE=rootfs.sgn


################## PARTITION INFO  ############################################
#device
node=/dev/mmcblk1 #emmc
fpath=/mnt/mmc/update

#partition numbers
part_boot=${node}"p6"
part_rootfs=${node}"p7"

update_fail() 
{
    ERROR "UPDATE FAILED," | tee ${LCD}
}

update_success()
{
    # to prevent possible data loss, sync and drop caches.
    /bin/sync
    echo 3 > /proc/sys/vm/drop_caches
    NOTIFY "UPDATE COMPLETE," | tee ${LCD}
    NOTIFY "YOU MAY REBOOT NOW." | tee ${LCD}
    exit 0
}

################# UPDATE INIT : Check files, unmount partitions ################ 
update_init() 
{
    DEBUG "+++++++++++++++++++++++++++++++++++++++++++++++++++++"
    DEBUG " INITIALIZE UPDATE ... "
    DEBUG "-----------------------------------------------------"

    DEBUG "STARTED UPDATE,"  | tee ${LCD}
    DEBUG "PLEASE STAND BY." | tee ${LCD}
    DEBUG " " | tee ${LCD}

    #unmount boot
    mount_check=`/bin/mount | /bin/grep -o ${part_boot}`
    if [ ! -z "${mount_check}" ];then
        /bin/umount -f ${part_boot}
        if [ $? -ne 0 ]; then
            ERROR "Failed to unmount ${part_boot}"
            update_fail
        fi
    fi

    #unmount rootfs
    mount_check=`/bin/mount | /bin/grep -o ${part_rootfs}`
    if [ ! -z "${mount_check}" ];then
        /bin/umount -f ${part_rootfs}
        if [ $? -ne 0 ]; then
            ERROR "Failed to unmount ${part_rootfs}"
            update_fail
        fi
    fi
}

################# PARTITION EMMC ##############################################
partition()
{
    echo partition
}

################# UPDATE BOOT ##################################################
update_boot() 
{
    DEBUG "+++++++++++++++++++++++++++++++++++++++++++++++++++++"
    DEBUG " UPDATING BOOT "
    DEBUG "-----------------------------------------------------"

    if [ ! -f ${fpath}/${BOOT_IMAGE} ] ; then
        ERROR "${BOOT_IMAGE}  not found"
        update_fail
    fi

    # ${VERIFICATION_TOOL} ${fpath}/${BOOT_IMAGE} ${fpath}/${BOOT_SIGNATURE} ${PUBLIC_KEY}
    # if [ $? -ne 0 ]; then
    #     ERROR "Failed to verify ${BOOT_IMAGE}"
    #     update_fail
    # fi

    INFO "Writing ${BOOT_IMAGE} on ${part_boot} ..."
    /bin/dd if=${fpath}/${BOOT_IMAGE} of=${part_boot}
    if [ $? -ne 0 ]; then
        ERROR "Failed to write ${BOOT_IMAGE} to ${part_boot}"
        update_fail
    fi
} 

################# UPDATE ROOTFS ##################################################
update_rootfs()
{
    DEBUG "+++++++++++++++++++++++++++++++++++++++++++++++++++++"
    DEBUG " UPDATING ROOTFS "
    DEBUG "-----------------------------------------------------"

    if [ ! -f ${fpath}/${ROOTFS_IMAGE} ]; then
        ERROR "${ROOTFS_IMAGE} not found."
        update_fail
    fi

    # ${VERIFICATION_TOOL} ${fpath}/${ROOTFS_IMAGE} ${fpath}/${ROOTFS_SIGNATURE} ${PUBLIC_KEY}
    # if [ $? -ne 0 ]; then
    #     ERROR "Failed to verify rootfs"
    #     update_fail
    # fi

    /bin/dd if=${fpath}/${ROOTFS_IMAGE} of=${part_rootfs}
    if [ $? -ne 0 ]; then
        ERROR "Failed to write rootfs"
        update_fail
    fi

    INFO "Checking filesystem [${part_rootfs}] ..."
    /sbin/e2fsck -y ${part_rootfs}

    INFO "Resizing filesystem [${part_rootfs}] ..."
    /sbin/resize2fs -F ${part_rootfs}
}

########################## MAIN ################################################
NOTIFY "-----------------------------------------------------"
NOTIFY "UPDATE EMMC "
NOTIFY "-----------------------------------------------------"


update_init
update_boot
update_rootfs
#if update is successful, we come here, call update_success.
update_success

