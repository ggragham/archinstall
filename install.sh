#!/usr/bin/env bash

BOLD=$(tput bold)
UNDERLINE='\033[4m'
NORMAL=$(tput sgr0)
RED='\033[0;31m'
LIGHTBLUE='\033[1;34m'
NC='\033[0m'

#Global vars
MOUNT_POINT='/mnt'
CHROOT_POINT="/root/${PWD##*/}"
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
	select="*"
	echo -e 'Disk Partition'
	echo -e "${RED}${BOLD}NOT COMPLETED${NORMAL}${NC}"
	echo -e ""

	while :; do
		case $select in
		y)
			chmod +x "$(pwd)/partitioning.sh"
			bash -c "$(pwd)/partitioning.sh"
			break
			;;
		n)
			echo -e 'Partition the disk manually'
			echo -e 'Format the partitions to the desired filesystem and mount them to /mnt'
			echo -e 'You are free to use LVM and/or Encryption'
			echo -e "For more information visit ${UNDERLINE}https://wiki.archlinux.org/title/Installation_guide#Partition_the_disks${NORMAL}"
			break
			;;
		*)
			read -rp "Use automatic partition? (May be buggy) [y/n]: " select
			continue
			;;
		esac
	done
	echo -e ''
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
	genfstab -U $MOUNT_POINT >>$MOUNT_POINT/etc/fstab
}

makeChroot() {
	cp -r "$(pwd)" "$MOUNT_POINT/root/"
	chmod +x "$MOUNT_POINT$CHROOT_POINT/$0"
	arch-chroot $MOUNT_POINT bash -c "$CHROOT_POINT/$0 --continue $ENCRYPTION $LVM $CHROOT_POINT $BLOCK_DEVICE"
}

setLocales() {
	cat "$CHROOT_POINT/config/locale.gen" >/etc/locale.gen
	locale-gen

	LOCALES_LINE_COUNT=$(wc -l <"$CHROOT_POINT/config/locale.gen")
	selectedLocaleNumber="0"

	while :; do
		if [[ $selectedLocaleNumber -gt $LOCALES_LINE_COUNT ]] || [[ $selectedLocaleNumber -le 0 ]]; then
			cat "$CHROOT_POINT/config/locale.gen" | sed '=' | sed 'N;s/\n/\) /'
			read -rp "Select default locale: " selectedLocaleNumber
			continue
		fi
		cat "$CHROOT_POINT/config/locale.conf" >/etc/locale.conf
		selectedLocale=$(awk -v selectedLocale="$selectedLocaleNumber" 'NR==selectedLocale{print $1}' <"/etc/locale.gen")
		sed -i "/LANG/s/\$SET_LOCALE/$selectedLocale/" /etc/locale.conf
		break
	done
}

setHostname() {
	read -rp "Enter hostname: " hostname
	echo -e "$hostname" > /etc/hostname
}

addUsers() {
	read -rp "Enter username: " username
	useradd -m -G wheel -s /bin/bash "$username"
	passwd "$username"
}

installBootloader() {
	pacman -Sy --noconfirm grub os-prober
	grub_target=$(echo -e "$BLOCK_DEVICE" | tr -d '0-9')
	grub-install "$grub_target"
	grub-mkconfig -o /boot/grub/grub.cfg
}

installEnvironment() {
	pacman -Sy --noconfirm networkmanager gdm gnome-shell gnome-terminal gnome-control-center
	systemctl enable NetworkManager
	systemctl enable gdm
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
	CHROOT_POINT="$3"
	BLOCK_DEVICE="$4"

	setLocales
	setHostname
	addUsers
	# Add wheel group to sudoers
	sed -i '/%wheel ALL=(ALL) ALL/s/^# //' /etc/sudoers
	installBootloader
	installEnvironment
	echo -e "\nInstalation fisished!\nNow reboot"
}

main() {
	case $1 in
	--install)
		stage1
		;;
	--continue)
		stage2 "$2" "$3" "$4" "$5"
		;;
	*)
		wecomeMessage
		helpMessage
		;;
	esac
}

main "$1" "$2" "$3" "$4" "$5"
