# ArchLinux installation script
*Only for personal use*

Script not fully completed. Use only on VM

## Installation instructions
1. Download ArchLinux ISO from <https://archlinux.org/download/>
2. Write ISO on Flash Drive
3. Boot up from Flash Drive with ArchLinux ISO
4. Clone this repo
```bash
git clone https://github.com/ggragham/archinstall.git
```
5. Change to the directory with the script
```bash
cd archinstall/
```
6. Execute the script
```bash
bash install.sh --install
```
7. Follow the instructions

## TODO
* [ ] Add more variables of Environments
* [ ] Add automatic detection of GPU and CPU driver
* [ ] Add RAID detection
* [ ] Add BTRFS detection
* [ ] Add UEFI specific bootloader
* [ ] Make more flexible Disk Partition
* [ ] Add selection menu for kernels, editors, etc
