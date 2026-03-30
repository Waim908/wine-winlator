#!/bin/bash
case $1 in
  mount)
    sudo mount --bind /proc $2/proc
    sudo mount --bind /sys $2/sys
    sudo mount --bind /dev $2/dev
    sudo mount --bind /tmp $2/tmp
  ;;
  unmount)
    sudo umount -l $2/dev
    sudo umount -l $2/sys
    sudo umount -l $2/proc
    sudo umount -l $2/tmp
  ;;
esac