#!/bin/sh

### LICENSE - (BSD 2-Clause) // ###
#
# Copyright (c) 2015, Daniel Plominski (Plominski IT Consulting)
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
# list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice, this
# list of conditions and the following disclaimer in the documentation and/or
# other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
# ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
### // LICENSE - (BSD 2-Clause) ###

### ### ### PLITC // ### ### ###

### stage0 // ###
DEBIAN=$(grep "ID" /etc/os-release | egrep -v "VERSION" | sed 's/ID=//g')
DEBVERSION=$(grep "VERSION_ID" /etc/os-release | sed 's/VERSION_ID=//g' | sed 's/"//g')
MYNAME=$(whoami)
### // stage0 ###

case "$1" in
'bootstrap')
### stage1 // ###
case $DEBIAN in
debian)
### stage2 // ###

### // stage2 ###
#
### stage3 // ###
if [ "$MYNAME" = "root" ]; then
   : # dummy
else
   echo "" # dummy
   echo "" # dummy
   echo "[ERROR] You must be root to run this script"
   exit 1
fi
if [ "$DEBVERSION" = "8" ]; then
   : # dummy
else
   echo "" # dummy
   echo "" # dummy
   echo "[ERROR] You need Debian 8 (Jessie) Version"
   exit 1
fi

#
### stage4 // ###
#
### ### ### ### ### ### ### ### ###

SCREEN=$(/usr/bin/which screen)
if [ -z "$SCREEN" ]; then
    echo "<--- --- --->"
    echo "need screen"
    echo "<--- --- --->"
    apt-get update
    apt-get install screen
    echo "<--- --- --->"
fi

LXC=$(/usr/bin/dpkg -l | grep lxc | awk '{print $2}')
if [ -z "$LXC" ]; then
    echo "<--- --- --->"
    echo "need lxc"
    echo "<--- --- --->"
    apt-get update
    apt-get install lxc
    echo "<--- --- --->"
fi

BRIDGEUTILS=$(/usr/bin/dpkg -l | grep bridge-utils | awk '{print $2}')
if [ -z "$BRIDGEUTILS" ]; then
    echo "<--- --- --->"
    echo "need bridge-utils"
    echo "<--- --- --->"
    apt-get update
    apt-get install bridge-utils
    echo "<--- --- --->"
fi

sleep 1
    echo ""
    lxc-checkconfig
    if [ $? -eq 0 ]
    then
       : # dummy
    else
       echo "[ERROR] lxc-checkconfig failed!"
       exit 1
    fi
sleep 1

## modify grub

CHECKGRUB1=$(grep "GRUB_CMDLINE_LINUX=" /etc/default/grub | grep "cgroup_enable=memory" | grep -c "swapaccount=1")
if [ "$CHECKGRUB1" = "1" ]; then
    : # dummy
else
    cp -prfv /etc/default/grub /etc/default/grub_BACKUP_lxctogo
    sed -i '/GRUB_CMDLINE_LINUX=/s/.$//' /etc/default/grub
    sed -i '/GRUB_CMDLINE_LINUX=/s/$/ cgroup_enable=memory swapaccount=1"/' /etc/default/grub

   ### grub update

   echo "" # dummy
   sleep 2
   grub-mkconfig
   echo "" # dummy
   sleep 2
   update-grub
   if [ "$?" != "0" ]; then
      echo "" # dummy
      sleep 5
      echo "[ERROR] something goes wrong let's restore the old configuration!" 1>&2
      cp -prfv /etc/default/grub_BACKUP_lxctogo /etc/default/grub
      echo "" # dummy
      sleep 2
      grub-mkconfig
      echo "" # dummy
      sleep 2
      update-grub
      exit 1
   fi
   echo ""
   echo "Please Reboot your System immediately! and continue the bootstrap"
   exit 0
fi

CHECKGRUB2=$(cat /proc/cmdline | grep "cgroup_enable=memory" | grep -c "swapaccount=1")
if [ "$CHECKGRUB2" = "1" ]; then
    : # dummy
else
   echo ""
   echo "Please Reboot your System immediately! and continue the bootstrap"
   exit 0
fi

### ### ###

### check ip_tables/ip6_tables kernel module

CHECKIPTABLES=$(lsmod | awk '{print $1}' | grep -c "ip_tables")
if [ "$CHECKIPTABLES" = "1" ]; then
    : # dummy
else
    modprobe ip_tables
fi

CHECKIP6TABLES=$(lsmod | awk '{print $1}' | grep -c "ip6_tables")
if [ "$CHECKIP6TABLES" = "1" ]; then
    : # dummy
else
    modprobe ip6_tables
fi

### ### ###

CREATEBRIDGE0=$(ip a | grep -c "vswitch0:")
if [ "$CREATEBRIDGE0" = "1" ]; then
    : # dummy
else
   brctl addbr vswitch0

   UDEVNET="/etc/udev/rules.d/70-persistent-net.rules"
   if [ -e "$UDEVNET" ]; then
      GETBRIDGEPORT0=$(grep 'SUBSYSTEM=="net"' /etc/udev/rules.d/70-persistent-net.rules | grep "eth" | head -n 1 | tr ' ' '\n' | grep "NAME" | sed 's/NAME="//' | sed 's/"//')
      brctl addif vswitch0 "$GETBRIDGEPORT0"
      sysctl -w net.ipv4.conf."$GETBRIDGEPORT0".forwarding=1
      sysctl -w net.ipv6.conf."$GETBRIDGEPORT0".forwarding=1
   else
      brctl addif vswitch0 eth0
      sysctl -w net.ipv4.conf.eth0.forwarding=1
      sysctl -w net.ipv6.conf.eth0.forwarding=1
   fi
   sysctl -w net.ipv4.conf.vswitch0.forwarding=1
   sysctl -w net.ipv6.conf.vswitch0.forwarding=1
fi

### ### ###
sleep 1; echo ""
### ### ###

CHECKLXCMANAGED=$(lxc-ls | grep -c "managed")
if [ "$CHECKLXCMANAGED" = "1" ]; then
    : # dummy
else
   lxc-create -n managed -t debian
   if [ "$?" != "0" ]; then
      echo "" # dummy
      echo '[ERROR] create "managed" lxc container failed'
      echo ""
         read -p "Do you wish to remove this corrupt LXC Container: managed ? (y/n) " LXCMANAGEDREMOVE
         if [ "$LXCMANAGEDREMOVE" = "y" ]; then
            lxc-destroy -n managed
         fi
      exit 1
   fi
fi

### ### ###
#/ sleep 1; echo ""
### ### ###

CREATEBRIDGE1=$(ip a | grep -c "vswitch1:")
if [ "$CREATEBRIDGE1" = "1" ]; then
    : # dummy
else
   brctl addbr vswitch1
   sysctl -w net.ipv4.conf.vswitch1.forwarding=1
   sysctl -w net.ipv6.conf.vswitch1.forwarding=1
fi

### ### ###
#/ sleep 1; echo ""
### ### ###

touch /etc/lxc/fstab.empty

LXCCONFIGFILEMANAGED=$(grep "lxc-to-go" /var/lib/lxc/managed/config | awk '{print $4}' | head -n 1)
if [ X"$LXCCONFIGFILEMANAGED" = X"lxc-to-go" ]; then
   echo "" # dummy
else
/bin/cat << LXCCONFIGMANAGED > /var/lib/lxc/managed/config
### ### ### lxc-to-go // ### ### ###

lxc.utsname=managed

# vswitch0 / untagged
lxc.network.type=veth
lxc.network.link=vswitch0
lxc.network.name=eth0
lxc.network.hwaddr=aa:bb:c0:0c:bb:aa
lxc.network.veth.pair=managed
lxc.network.flags=up

# vswitch1 / intern
lxc.network.type=veth
lxc.network.link=vswitch1
lxc.network.name=eth1
lxc.network.veth.pair=managed1
lxc.network.flags=up

lxc.mount=/etc/lxc/fstab.empty
lxc.rootfs=/var/lib/lxc/managed/rootfs

# mounts point
lxc.mount.entry = proc proc proc nodev,noexec,nosuid 0 0
lxc.mount.entry = sysfs sys sysfs defaults  0 0

#/ lxc.cgroup.memory.limit_in_bytes=268435456
#/ lxc.cgroup.memory.memsw.limit_in_bytes=268435456

### default ### lxc.cap.drop=audit_control audit_write mac_admin mac_override mknod setfcap setpcap sys_boot sys_module sys_pacct sys_rawio sys_resource sys_time sys_tty_config
#/ lxc.cap.drop=audit_control audit_write mac_admin mac_override mknod setfcap setpcap sys_boot sys_module sys_pacct sys_rawio sys_resource sys_time sys_tty_config

#
### LXC - jessie/systemd hacks // ###
lxc.autodev = 1
lxc.kmsg = 0

#!# lxc.cap.drop = sys_admin
#!# lxc.cap.drop = mknod
#!# lxc.cap.drop = audit_control
#!# lxc.cap.drop = audit_write
#!# lxc.cap.drop = setfcap
#!# lxc.cap.drop = setpcap
#!# lxc.cap.drop = sys_resource
#
lxc.cap.drop = sys_module
lxc.cap.drop = mac_admin
lxc.cap.drop = mac_override
lxc.cap.drop = sys_time
lxc.cap.drop = sys_boot
lxc.cap.drop = sys_pacct
lxc.cap.drop = sys_rawio
lxc.cap.drop = sys_tty_config

lxc.tty=2
lxc.pts = 1024
#/ lxc.mount.entry = /run/systemd/journal mnt/journal none bind,ro,create=dir 0 0
### // LXC - jessie/systemd hacks ###
#

lxc.cgroup.devices.deny = a
# tty
lxc.cgroup.devices.allow = c 5:0 rwm
lxc.cgroup.devices.allow = c 4:0 rwm
lxc.cgroup.devices.allow = c 4:1 rwm
# console
lxc.cgroup.devices.allow = c 5:1 rwm
# ptmx
lxc.cgroup.devices.allow = c 5:2 rwm
# pts/*
lxc.cgroup.devices.allow = c 136:* rwm
# null
lxc.cgroup.devices.allow = c 1:3 rwm
# zero
lxc.cgroup.devices.allow = c 1:5 rwm
# full
lxc.cgroup.devices.allow = c 1:7 rwm
# random
lxc.cgroup.devices.allow = c 1:8 rwm
# urandom
lxc.cgroup.devices.allow = c 1:9 rwm
# fuse
lxc.cgroup.devices.allow = c 10:229 rwm
# tun
lxc.cgroup.devices.allow = c 10:200 rwm

### ### ### // lxc-to-go ### ### ###
# EOF
LXCCONFIGMANAGED
fi

CHECKMANAGED1STATUS=$(screen -list | grep "managed" | awk '{print $1}')
CHECKMANAGED1=$(lxc-ls --active | grep -c "managed")
if [ "$CHECKMANAGED1" = "1" ]; then
   echo "... LXC Container (screen session: "$CHECKMANAGED1STATUS"): always running ..."
else
   echo "... LXC Container (screen session): managed starting ..."
   screen -d -m -S managed -- lxc-start -n managed
   sleep 1
   screen -list | grep "managed"
fi

### ### ###
echo ""
echo "... wait 15 seconds ..."
echo ""
sleep 15
### ### ###

CHECKUPDATELIST1=$(grep -c "jessie" /var/lib/lxc/managed/rootfs/etc/apt/sources.list)
if [ "$CHECKUPDATELIST1" = "1" ]; then
   : # dummy
else
   /bin/cat << CHECKUPDATELIST1IN > /var/lib/lxc/managed/rootfs/etc/apt/sources.list
### ### ### PLITC ### ### ###
deb http://ftp.de.debian.org/debian/ jessie main contrib non-free
deb-src http://ftp.de.debian.org/debian/ jessie main contrib non-free

deb http://ftp.de.debian.org/debian/ jessie-updates main contrib non-free
deb-src http://ftp.de.debian.org/debian/ jessie-updates main contrib non-free

deb http://ftp.de.debian.org/debian-security/ jessie/updates main contrib non-free
deb-src http://ftp.de.debian.org/debian-security/ jessie/updates main contrib non-free
### ### ### PLITC ### ### ###
# EOF
CHECKUPDATELIST1IN

   lxc-attach -n managed -- apt-get clean
   lxc-attach -n managed -- apt-get update
   if [ "$?" != "0" ]; then
      echo "[ERROR] can't fetch update list"
   fi
fi

DEBVERSIONMANAGED=$(grep "VERSION_ID" /var/lib/lxc/managed/rootfs/etc/os-release | sed 's/VERSION_ID=//g' | sed 's/"//g')
if [ "$DEBVERSIONMANAGED" = "8" ]; then
   : # dummy
else
   lxc-attach -n managed -- apt-get -y upgrade
   if [ "$?" != "0" ]; then
      echo "[ERROR] can't upgrade the LXC Container"
      echo '... try manually "lxc-attach -n managed -- apt-get -y upgrade"'
   fi
   lxc-attach -n managed -- apt-get -y dist-upgrade
   if [ "$?" != "0" ]; then
      echo "[ERROR] can't dist-upgrade the LXC Container"
      echo '... try manually "lxc-attach -n managed -- apt-get -y dist-upgrade"'
   fi
   lxc-attach -n managed -- apt-get -y autoremove
   if [ "$?" != "0" ]; then
      echo "[ERROR] can't autoremove the LXC Container"
      echo '... try manually "lxc-attach -n managed -- apt-get -y autoremove"'
   fi
   lxc-attach -n managed -- apt-get -y install --reinstall systemd-sysv
   if [ "$?" != "0" ]; then
      echo "[ERROR] can't reinstall systemd-sysv the LXC Container"
      echo '... try manually "lxc-attach -n managed -- apt-get -y install --reinstall systemd-sysv"'
   fi
   lxc-attach -n managed -- ln -s /dev/null /etc/systemd/system/systemd-udevd.service
   lxc-attach -n managed -- ln -s /dev/null /etc/systemd/system/systemd-udevd-control.socket
   lxc-attach -n managed -- ln -s /dev/null /etc/systemd/system/systemd-udevd-kernel.socket
   lxc-attach -n managed -- ln -s /dev/null /etc/systemd/system/proc-sys-fs-binfmt_misc.automount

   lxc-stop -n managed

   echo "... LXC Container (screen session): managed restarting ..."
   screen -d -m -S managed -- lxc-start -n managed
   sleep 1
   screen -list | grep "managed"
fi

### ### ###

CHECKMANAGEDIPTABLES1=$(lxc-attach -n managed -- dpkg -l | grep -c "iptables")
if [ "$CHECKMANAGEDIPTABLES1" = "1" ]; then
   : # dummy
else
   lxc-attach -n managed -- apt-get -y install iptables
fi

SYSCTLMANAGED=$(grep "lxc-to-go" /var/lib/lxc/managed/rootfs/etc/sysctl.conf | awk '{print $4}' | head -n 1)
if [ X"$SYSCTLMANAGED" = X"lxc-to-go" ]; then
   echo "" # dummy
else
/bin/cat << SYSCTLFILEMANAGED > /var/lib/lxc/managed/rootfs/etc/sysctl.conf
### ### ### lxc-to-go // ### ### ###
#
net.ipv4.conf.eth0.forwarding=1
net.ipv4.conf.eth1.forwarding=1
net.ipv6.conf.eth0.forwarding=1
net.ipv6.conf.eth1.forwarding=1
#
### ### ### // lxc-to-go ### ### ###
# EOF
SYSCTLFILEMANAGED
fi

lxc-attach -n managed -- sysctl -w net.ipv4.conf.eth0.forwarding=1
lxc-attach -n managed -- sysctl -w net.ipv4.conf.eth1.forwarding=1
lxc-attach -n managed -- sysctl -w net.ipv6.conf.eth0.forwarding=1
lxc-attach -n managed -- sysctl -w net.ipv6.conf.eth1.forwarding=1

### ### ###

RCLOCALMANAGED=$(grep "lxc-to-go" /var/lib/lxc/managed/rootfs/etc/rc.local | awk '{print $4}' | head -n 1)
if [ X"$RCLOCALMANAGED" = X"lxc-to-go" ]; then
   echo "" # dummy
else
/bin/cat << RCLOCALFILEMANAGED > /var/lib/lxc/managed/rootfs/etc/rc.local
#!/bin/sh -e
### ### ### lxc-to-go // ### ### ###
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.

##/ echo "stage0"
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

ip6tables -F
ip6tables -X
ip6tables -t nat -F
ip6tables -t nat -X
ip6tables -t mangle -F
ip6tables -t mangle -X
ip6tables -P INPUT ACCEPT
ip6tables -P FORWARD ACCEPT
ip6tables -P OUTPUT ACCEPT

##/ echo "stage0"
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sysctl net.ipv4.conf.default.forwarding=1
sysctl net.ipv4.conf.eth0.forwarding=1

##/ echo "stage1"
iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 60000 -j DNAT --to-destination 192.168.1.100:60000
iptables -t nat -A PREROUTING -i eth0 -p udp --dport 60000 -j DNAT --to-destination 192.168.1.100:60000
ip6tables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

##/ echo "stage2"
# ip -6 rule add from 2001::/64 table 100
# ip r a 2000::/3 dev eth0 via fe80:: table 100

##/ echo "stage3"
### IPredator // ###
# route add -net 46.246.38.0 netmask 255.255.255.0 gw 192.168.1.1
#
# mkdir -p /dev/net
# mknod /dev/net/tun c 10 200
# chmod 666 /dev/net/tun
#
# systemctl restart openvpn
### // IPredator ###

exit 0
#
### ### ### // lxc-to-go ### ### ###
# EOF
RCLOCALFILEMANAGED
fi





### ### ### ### ### ### ### ### ###
#
### // stage4 ###
#
### // stage3 ###
#
### // stage2 ###
   ;;
*)
   # error 1
   echo "" # dummy
   echo "" # dummy
   echo "[ERROR] Plattform = unknown"
   exit 1
   ;;
esac
#
### // stage1 ###
;;
'start')
### stage1 // ###
case $DEBIAN in
debian)
### stage2 // ###

### // stage2 ###
#
### stage3 // ###
if [ "$MYNAME" = "root" ]; then
   : # dummy
else
   echo "" # dummy
   echo "" # dummy
   echo "[ERROR] You must be root to run this script"
   exit 1
fi
if [ "$DEBVERSION" = "8" ]; then
   : # dummy
else
   echo "" # dummy
   echo "" # dummy
   echo "[ERROR] You need Debian 8 (Jessie) Version"
   exit 1
fi

#
### stage4 // ###
#
### ### ### ### ### ### ### ### ###



### ### ### ### ### ### ### ### ###
#
### // stage4 ###
#
### // stage3 ###
#
### // stage2 ###
   ;;
*)
   # error 1
   echo "" # dummy
   echo "" # dummy
   echo "[ERROR] Plattform = unknown"
   exit 1
   ;;
esac
#
### // stage1 ###
;;
'stop')
### stage1 // ###
case $DEBIAN in
debian)
### stage2 // ###

### // stage2 ###
#
### stage3 // ###
if [ "$MYNAME" = "root" ]; then
   : # dummy
else
   echo "" # dummy
   echo "" # dummy
   echo "[ERROR] You must be root to run this script"
   exit 1
fi
if [ "$DEBVERSION" = "8" ]; then
   : # dummy
else
   echo "" # dummy
   echo "" # dummy
   echo "[ERROR] You need Debian 8 (Jessie) Version"
   exit 1
fi

#
### stage4 // ###
#
### ### ### ### ### ### ### ### ###



### ### ### ### ### ### ### ### ###
#
### // stage4 ###
#
### // stage3 ###
#
### // stage2 ###
   ;;
*)
   # error 1
   echo "" # dummy
   echo "" # dummy
   echo "[ERROR] Plattform = unknown"
   exit 1
   ;;
esac
#
### // stage1 ###
;;
'create')
### stage1 // ###
case $DEBIAN in
debian)
### stage2 // ###

### // stage2 ###
#
### stage3 // ###
if [ "$MYNAME" = "root" ]; then
   : # dummy
else
   echo "" # dummy
   echo "" # dummy
   echo "[ERROR] You must be root to run this script"
   exit 1
fi
if [ "$DEBVERSION" = "8" ]; then
   : # dummy
else
   echo "" # dummy
   echo "" # dummy
   echo "[ERROR] You need Debian 8 (Jessie) Version"
   exit 1
fi

#
### stage4 // ###
#
### ### ### ### ### ### ### ### ###



### ### ### ### ### ### ### ### ###
#
### // stage4 ###
#
### // stage3 ###
#
### // stage2 ###
   ;;
*)
   # error 1
   echo "" # dummy
   echo "" # dummy
   echo "[ERROR] Plattform = unknown"
   exit 1
   ;;
esac
#
### // stage1 ###
;;
'delete')
### stage1 // ###
case $DEBIAN in
debian)
### stage2 // ###

### // stage2 ###
#
### stage3 // ###
if [ "$MYNAME" = "root" ]; then
   : # dummy
else
   echo "" # dummy
   echo "" # dummy
   echo "[ERROR] You must be root to run this script"
   exit 1
fi
if [ "$DEBVERSION" = "8" ]; then
   : # dummy
else
   echo "" # dummy
   echo "" # dummy
   echo "[ERROR] You need Debian 8 (Jessie) Version"
   exit 1
fi

#
### stage4 // ###
#
### ### ### ### ### ### ### ### ###



### ### ### ### ### ### ### ### ###
#
### // stage4 ###
#
### // stage3 ###
#
### // stage2 ###
;;
*)
   # error 1
   echo "" # dummy
   echo "" # dummy
   echo "[ERROR] Plattform = unknown"
   exit 1
   ;;
esac
#
### // stage1 ###
;;
*)
echo ""
echo "usage: $0 { bootstrap | start | stop | create | delete }"
;;
esac
exit 0
### ### ### PLITC ### ### ###
# EOF
