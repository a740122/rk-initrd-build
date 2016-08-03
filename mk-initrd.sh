#!/bin/bash -e

genext2fs -b 36768 -d ./initrd -i 8192 -U  initrd.img
tune2fs -O extents,uninit_bg,dir_index initrd.img
e2fsck -p -f  initrd.img
resize2fs -M initrd.img