#!/bin/bash
###This script generates a kickstart file, sends it to NFS server, 
###and using it during the fully automated installtion of latest Centos 6 VM
###Before running this script on physical server, make sure:
###Interface eth0 belongs to br0, and eth1 belongs to br1, and new IPs are not busy 
###Installation requires an Internet connection
###Verify that VMNAME not in use by other servers
###Generate SSH keys, and ssh-copy-id to NFS server
###Check partitioning, CPU, RAM and DISKSIZE of a new VM (can be modified in this script) 
###After installation a new guest will be reachable using "virsh console <VMNAME>" command

VMNAME="ab2c19"
DISK="/vm/$VMNAME.img"
DISKSIZE="200G"
CPU="2"
ETH0_IP="192.168.57.169"
ETH1_IP="10.1.2.169"
NETMASK="255.255.255.0"
NFSSERVER="192.168.57.243"
RAM="16389"
KS="/nfs/$VMNAME.cfg"
CREATE_KS=$VMNAME.cfg

ping -c1 $ETH0_IP &>/dev/null && echo "FYI $ETH0_IP is used by other host, aborting..." && exit 1
ping -c1 $ETH1_IP &>/dev/null && echo "FYI $ETH1_IP is used by other host, aborting..." && exit 1
cat <<EOF >`pwd`/$CREATE_KS
#platform=x86, AMD64, or Intel EM64T
#version=DEVEL
# Firewall configuration
firewall --disabled
# Install OS instead of upgrade
install
# Use CDROM installation media
cdrom
# Root password
rootpw YourPasswordHere
# System authorization information
auth  --useshadow  --passalgo=sha512 --enablenis --nisdomain=amadeus.netvision --nisserver=10.1.2.112
# Use text mode install
text
# Run the Setup Agent on first boot
firstboot --enable
# System keyboard
keyboard us
# System language
lang en_US
# SELinux configuration
selinux --permissive
# Installation logging level
logging --level=info
# Reboot after installation
reboot
# System timezone
timezone  Asia/Jerusalem
# Network information
network  --bootproto=static --device=eth0 --gateway=192.168.57.250 --ip=$ETH0_IP --nameserver=8.8.8.8 --netmask=255.255.255.0 --onboot=on --hostname $VMNAME.amadeus.local
network  --bootproto=static --device=eth1 --ip=$ETH1_IP --netmask=$NETMASK --onboot=on
# System bootloader configuration
bootloader --location=mbr
# Partition clearing information
zerombr
clearpart --all --initlabel --drives=vda
# Disk partitioning information

part /boot --fstype="ext4" --size=512
part /home --fstype="ext4" --grow --size=1
part / --fstype="ext4" --size=100000 
part swap --fstype="swap" --size=16389

%packages
@core
%end
EOF
scp `pwd`/$CREATE_KS root@$NFSSERVER:/nfs/$VMNAME.cfg

[ -f $DISK ] && echo "$DISK exists, choose other disk name and restart the script" && exit 1 ||
/usr/bin/qemu-img create -f raw $DISK $DISKSIZE 
ping -c1 $NFSSERVER &>/dev/null || echo "NFS server is unreachable. Proceeding with interactive installation without kickstart..."
sleep 2
virt-install --connect=qemu:///system \
--network=bridge:br0 \
--network=bridge:br1 \
-x "ks=nfs:$NFSSERVER:$KS console=ttyS0 ip=$ETH0_IP netmask=$NETMASK ksdevice=eth0" \
-n $VMNAME --disk $DISK \
-r $RAM --vcpus=$CPU --check-cpu --accelerate \
-l http://mirror.centos.org/centos/6/os/x86_64/ --nographics 


