#!/usr/bin/env bash

BOLD=$(tput bold)
NORMAL=$(tput sgr0)
RED='\033[0;31m'
LIGHTBLUE='\033[1;34m'
NC='\033[0m'

#Global vars
MOUNT_POINT='/mnt'
BOOTMODE=''
BLOCK_DEVICE=''
ENCRYPTED_DEVICE=''
FILESYSTEM=''
LVM='1'
ENCRYPTION='1'
USERNAME=''
PASSWORD=''
ROOT_PASSWORD=''

wecomeMessage() {
	echo -e '\t========================================================='
	echo -e "\t*\t   Welcome to ${LIGHTBLUE}${BOLD}ArchLinux${NORMAL}${NC} Install script\t\t*"
	echo -e '\t* Author made this script personally for himself\t*'
	echo -e "\t* If you suddenly decide to use this script for yourself *\n\t* author is ${RED}not responsible${NC} for any consequences\t*"
	echo -e '\t========================================================='
	echo -e '\n\n\n'
}

diskPartition() {
	echo -e '\tDisk Partition'
	echo -e "\t${RED}${BOLD}NOT COMPLETED${NORMAL}${NC}"
	echo -e '\tPartition the disk manually'
	echo -e '\tFormat the partitions to the desired filesystem and mount to /mnt'
	echo -e '\tYou are free to use LVM and Encryption'
	echo -e '\n\n\n'
}

checkBootMode() {
	if [ -d /sys/firmware/efi/ ]; then
		BOOTMODE=UEFI
	else
		BOOTMODE=BIOS
	fi
	echo -e "Boot mode: $BOOTMODE"
}

checkMountpoint() {
	mountpoint -q $MOUNT_POINT
	if [[ $? -eq 0 ]]; then
		echo -e "Mount point: $MOUNT_POINT"
		echo -e "Filesystem: $(findmnt $MOUNT_POINT --noheadings --output FSTYPE,TARGET | awk '$MOUNT_POINT {print $1}')"
	else
		echo -e "Filesystem isn't mounted"
		exit 1
	fi
}

checkBlockDevice() {
	BLOCK_DEVICE=$(findmnt $MOUNT_POINT --noheadings --output SOURCE,TARGET | awk '$MOUNT_POINT {print $1}')
	echo -e "Block device: $BLOCK_DEVICE"
}

checkLVM() {
	lvdisplay $BLOCK_DEVICE &>/dev/null
	if [[ $? -eq 0 ]]; then
		echo -e "LVM detected"
		LVM="lvm2"
	else
		echo -e "LVM undetected"
		LVM=""
	fi
}

checkEncryption() {
	if [[ $LVM == lvm2 ]]; then
		ENCRYPTED_DEVICE=$(lvs -o devices,lv_dm_path | awk -v var=$BLOCK_DEVICE '$0 ~ var {match($1, "^/dev/[a-z0-9/_]+",a)}END{print a[0]}')
		cryptsetup isLuks $(cryptsetup status $ENCRYPTED_DEVICE 2>/dev/null | awk '/device/ {print $2}') 2>/dev/null
		ENCRYPTION=$?
	else
		cryptsetup isLuks $BLOCK_DEVICE
		ENCRYPTION=$?
		echo -e "2"
	fi

	if [[ $ENCRYPTION -eq 0 ]]; then
		echo -e "Encryption detected"
		ENCRYPTION="1"
	else
		echo -e "Encryption undetected"
		ENCRYPTION=""
	fi

}

preparation() {
	checkBootMode
	checkMountpoint
	checkBlockDevice
	checkLVM
	checkEncryption
}

updateSystemClock() {
	timedatectl set-ntp true
}

bootstrapBaseSystem() {
	pacstrap /mnt base base-devel vim linux linux-headers linux-firmware man-db man-pages texinfo dhcpcd $LVM
}

fstabGen() {
	genfstab -U $MOUNT_POINT >>$MOUNT_POINT/etc/fstab
}

main() {
	wecomeMessage
	diskPartition
	preparation
	updateSystemClock
	bootstrapBaseSystem
	fstabGen
}

main
