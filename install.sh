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
LVM='false'
ENCRYPTION='false'

wecomeMessage() {
	echo -e '\t=========================================================='
	echo -e "\t*\t   Welcome to ${LIGHTBLUE}${BOLD}ArchLinux${NORMAL}${NC} Install script\t\t *"
	echo -e '\t* Author made this script personally for himself\t *'
	echo -e "\t* If you suddenly decide to use this script for yourself *\n\t* author is ${RED}not responsible${NC} for any consequences\t *"
	echo -e '\t=========================================================='
	echo -e '\n\n\n'
}

helpMessage() {
	echo -e "\t${BOLD}How to use${NC}"
	echo -e "Just type:"
	echo -e "bash install.sh --install"
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

	if mountpoint -q $MOUNT_POINT; then
		echo -e "Mount point: $MOUNT_POINT"
		FILESYSTEM=$(findmnt $MOUNT_POINT --noheadings --output FSTYPE,TARGET | awk '$MOUNT_POINT {print $1}')
		echo -e "Filesystem: $FILESYSTEM"
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
	if lvdisplay "$BLOCK_DEVICE" &>/dev/null; then
		echo -e "LVM detected"
		LVM="true"
	else
		echo -e "LVM undetected"
		LVM="false"
	fi
}

checkEncryption() {
	if [[ $LVM == lvm2 ]]; then
		ENCRYPTED_DEVICE="$(lvs -o devices,lv_dm_path | awk -v var="$BLOCK_DEVICE" '$0 ~ var {match($1, "^/dev/[a-z0-9/_]+",a)}END{print a[0]}')"
		cryptsetup isLuks "$(cryptsetup status "$ENCRYPTED_DEVICE" 2>/dev/null | awk '/device/ {print $2}') 2>/dev/null"
		ENCRYPTION=$?
	else
		cryptsetup isLuks "$BLOCK_DEVICE"
		ENCRYPTION=$?
	fi

	if [[ $ENCRYPTION -eq 0 ]]; then
		echo -e "Encryption detected"
		ENCRYPTION="true"
	else
		echo -e "Encryption undetected"
		ENCRYPTION="false"
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
	if [[ $LVM == "true" ]]; then
		lvm_pkg="lvm2"
	else
		lvm_pkg=""
	fi

	pacstrap /mnt base base-devel vim linux linux-headers linux-firmware man-db man-pages texinfo dhcpcd $lvm_pkg
}

fstabGen() {
	genfstab -U $MOUNT_POINT >> $MOUNT_POINT/etc/fstab
}

makeChroot() {
	cp -r "$(pwd)" "$MOUNT_POINT/root/"
	chmod +x "/root/${PWD##*/}/$0"
	arch-chroot $MOUNT_POINT bash -c "/root/${PWD##*/}/$0" --continue $ENCRYPTION $LVM
}

stage1() {
	wecomeMessage
	diskPartition
	preparation
	updateSystemClock
	bootstrapBaseSystem
	fstabGen
	makeChroot
}

stage2() {
	ENCRYPTION="$1"
	LVM="$2"
	echo -e "Ecnryption: $ENCRYPTION"
	echo -e "LVM: $LVM"
	#TODO
}

main() {
	case $1 in
	--install)
		stage1
		;;
	--continue)
		stage2 "$2" "$3"
		;;
	*)
		wecomeMessage
		helpMessage
		;;
	esac
}

main "$1" "$2" "$3"
