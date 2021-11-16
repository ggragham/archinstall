#!/bin/env bash

selectedDevice=""

lsblkAlias() {
	lsblk --nodeps --exclude 7 --noheadings --paths --output TYPE,NAME,SIZE,MODEL
}

errorCheck() {
	statusCode=$1
	if [ "$statusCode" -ne 0 ]; then
		echo -e "Error: $statusCode"
		exit
	fi
}

selectDisk() {
	LINE_COUNT="0"
	selectedDiskNumber=""

	LINE_COUNT=$(lsblkAlias | wc -l)

	echo -e "Disks:"
	lsblkAlias | sed '=' | sed 'N;s/\n/\) /'
	read -rp "Select the disk to which Linux will be installed: " selectedDiskNumber

	while :; do
		if [[ $selectedDiskNumber -gt $LINE_COUNT ]] || [[ $selectedDiskNumber -le 0 ]]; then
			read -rp "Select the disk to which Linux will be installed: " selectedDiskNumber
			continue
		fi
		selectedDevice=$(lsblkAlias | awk -v disk="$selectedDiskNumber" 'NR==disk{print $2}')
		break
	done

}

makePartitions() {
	echo -e "\nMaking partitions"
	(
		echo o # Create a new empty MBR partition table
		echo n # Add a new partition
		echo p # Primary partition
		echo 1 # Partition number
		echo   # First sector
		echo   # Last sector
		echo w # Write changes
	) | sudo fdisk "$selectedDevice" &>/dev/null

	errorCheck "$?"
	echo -e "Creating filesystems"
	mkfs.ext4 "$selectedDevice"1 &>/dev/null
	errorCheck "$?"
}

mountPartitions() {
	echo -e "Mounting partition to /mnt"
	mount "$selectedDevice"1 /mnt
	errorCheck "$?"
}

main() {
	echo -e "Partitioning\n"
	selectDisk
	makePartitions
	mountPartitions
	echo -e "Partitioning completed"
}
