#!/bin/bash
sleep 1
mkdir -p /mnt/vault
mount -o uid=1000,gid=1000,dmask=077,fmask=177 /dev/disk/by-uuid/73A4-3845 /mnt/vault
