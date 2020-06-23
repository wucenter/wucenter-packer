#!/bin/bash

########
# CONF #
########

APT_PACK_DEL="
accountsservice
bind9-host
busybox-static
command-not-found
dmidecode
dosfstools
friendly-recovery
geoip-database
hdparm
info
install-info
installation-report
iso-codes
krb5-locales
language-selector-common
laptop-detect
lshw
mlocate
mtr-tiny
nano
ntfs-3g
os-prober
parted
plymouth
popularity-contest
powermgmt-base
publicsuffix
python-apt-common
shared-mime-info
tasksel
tcpdump
ufw
usbutils
uuid-runtime
xdg-user-dirs

crda
eject
fuse
irqbalance
iw
wireless-regdb

ed
emacsen-common
strace
ltrace
lsof
bash-completion

bzip2
ftp
iputils-tracepath
isc-dhcp-client
isc-dhcp-common
less
psmisc
netcat-openbsd
telnet
wget
xz-utils

fuse
logrotate
networkd-dispatcher
ubuntu-advantage-tools
xauth

dictionaries-common
wamerican
wbritish

groff-base
manpages
man-db

console-setup
console-setup-linux
kbd
keyboard-configuration

language-pack-en
language-pack-gnome-en

libatm1
libfribidi0
libglib2.0-data
libnss-systemd
"



########
# INIT #
########

# ERR
set -e

# LOG
set -x
exec 3>&1 4>&2 ; trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>/root/late_cmd.log 2>&1

# ENV
export RUNLEVEL=1 DEBIAN_FRONTEND=noninteractive

# ARG
SSH_USERNAME=${SSH_USERNAME:-ansibler}



########
# DIST #
########

# Disable the auto updater
systemctl mask apt-daily.timer apt-daily-upgrade.timer apt-daily.service apt-daily-upgrade.service

# Disable the release upgrader
sed -i 's/^Prompt=.*$/Prompt=never/' /etc/update-manager/release-upgrades
apt-get -y purge ubuntu-release-upgrader-core
rm -rf /var/lib/ubuntu-release-upgrader
rm -rf /var/lib/update-manager

# Configure FR keyboard
tee <<'EOK' /etc/default/keyboard
# Automatically set by packer-vmware-ubuntu
XKBMODEL="pc105"
XKBLAYOUT="fr"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
EOK



#######
# NET #
#######

# Disable IPv6 + Oldschool network IF names + Fast grub boot
sed -i \
    -e 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' \
    -e 's/^GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX="ipv6.disable=1 net.ifnames=0 biosdevname=0 audit=1"/' \
    -e 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet nosplash"/' \
    /etc/default/grub
# TIP: update-grub will get triggered by kernel installation below

# Temporary DNS config from netplan
ns=$( awk -F'"' 'NF>2{print $2;exit}' /etc/netplan/01-netcfg.yaml )
rm /etc/resolv.conf
tee <<EOR /etc/resolv.conf
# Automatically set by packer-vmware-ubuntu
nameserver $ns
EOR



########
# PACK #
########

# APT purge
apt-get -y purge \
    $APT_PACK_DEL \
    $( dpkg --list | awk '{print $2}' | grep -- '-doc$' ) \
    $( dpkg --get-selections | awk '/^linux-(image|headers|modules)-/&&($2!="deinstall")&&($2!="purge"){print $1}' ) \
    $( dpkg --get-selections | awk '/:i386/&&($2!="deinstall")&&($2!="purge"){print substr($1,1,index($1,":")-1)":i386"}' )
apt-get -y autoremove --purge

# APT upgrade
apt-get update
apt-get -y upgrade
apt-get -y dist-upgrade

# APT orphan
apt-get -y install --no-install-recommends deborphan
deborphan --find-config | xargs apt-get -y purge
while [ -n "$( deborphan --guess-all )" ]; do deborphan --guess-all | xargs apt-get -y purge ; done
apt-get -y purge deborphan

# APT install
apt-get -y install --no-install-recommends \
    linux-virtual \
    open-vm-tools perl-modules-5.30 cloud-init \
    sudo policykit-1 \
    openssh-server \
    python3-apt

# APT clean
apt-get -y autoremove --purge
apt-get autoclean
apt-get clean
rm -rf /var/lib/apt/lists
find /var/lib/apt /var/cache/apt/ -type f -exec truncate --size=0 {} \;



########
# USER #
########

echo $SSH_USERNAME' ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/$SSH_USERNAME
chmod 440 /etc/sudoers.d/$SSH_USERNAME



#######
# SSH #
#######

sed -E -i \
    -e '0,/^[#]?\s*PasswordAuthentication (yes|no)\s*$/ s/^[#]?\s*PasswordAuthentication (yes|no)\s*$/PasswordAuthentication yes/' \
    -e '0,/^[#]?\s*UseDNS (yes|no)\s*$/ s/^[#]?\s*UseDNS (yes|no)\s*$/PasswordAuthentication no/' \
    /etc/ssh/sshd_config



########
# MOTD #
########

# TODO dpkg-divert /etc/update-motd.d/??-*


#########
# CLEAN #
#########

rm /root/LATE_UFO.SH
rm -rf /tmp/*
find /var/log -type f -exec truncate --size=0 {} \;

# TRIM
dd if=/dev/zero of=/EMPTY bs=1M || true # TIP: dd returns false on disk full
rm -f /EMPTY
sync



#######
# END #
#######

# DBG
dpkg --get-selections | grep -v deinstall
df -h /

exit 0
