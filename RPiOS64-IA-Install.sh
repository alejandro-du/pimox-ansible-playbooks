# !/bin/bash
#######################################################################
# Name:     RPiOS64-IA-Install.sh           Version:      0.1.2       #
# Created:  07.09.2021                      Modified: 22.02.2022      #
# Author:   TuxfeatMac J.T.                                           #
# Purpose:  interactive, automatic, Pimox7 installation RPi4B, RPi3B+ #
#########################################################################################################################################
# Tested with image from:														                                                                                                 #
# https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2021-11-08/2021-10-30-raspios-bullseye-arm64-lite.zip	 #
#########################################################################################################################################

#### SET SOME COLOURS ###################################################################################################################
NORMAL=$(tput sgr0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
GREY=$(tput setaf 8)

#### SCRIPT IS MENT TO BE TO RUN AS ROOT! NOT AS PI WITH SUDO ###########################################################################
if [ $USER != root ]
 then
  printf "${RED}PLEASE RUN THIS SCRIPT AS ROOT! DONT USE SUDO! $NORMAL \n"
  exit
fi
printf " $YELLOW
====================================================================
!    PLEASE DONT USE SUDO, USE SU TO LOGIN TO THE ROOT USER        !
! PLEASE STOP THIS SCRIPT NOW WITH CONTROL+C IF YOU ARE USING SUDO !
!               CONTINUING SETUP IN 3 SECONDS...                   !
====================================================================
$NORMAL\n" && sleep 3

#### GET THE RPI MODEL #### EXTRA STEPS FOR RPI3B+ ##################### UNTESTED #######################################################
RPIMOD=$(cat /sys/firmware/devicetree/base/model | cut -d ' ' -f 3)
if [ $RPIMOD == 3 ]
 then
  printf "Officially, the only supported model is Raspberry Pi 4. Unfortunately, you have a model 3.\n"
  printf "Edit installer.sh manually.. I hope you know what you are doing..."
  exit
  ## WORKS BUT DOSEN'T SHOW RPI 3 WARNINGS YET ...
  # [ ] ADD WARNING MESSAGES
  # [ ] GET RPI3 VALUES SWAP ZRAM INSTED OF HARD CODING ?
  PI3_ZRAM='1664'                 # zram 1,6GB
  PI3_SWAP='384'                  # dphys-swapfile 0,4GB
  ##
  apt install -y zram-tools
  printf "SIZE=$PI3_ZRAM\nPRIORITY=100\nALGO=lz4\n" >> /etc/default/zramswap
  printf "CONF_SWAPSIZE=$PI3_SWAP\n" >> /etc/dphys-swapfile
  vm.swappiness=100 >> /etc/sysctl.d/99-sysctl.conf
  # fix net names eth0 | enxMAC # !
  RPIMAC=$(ip a | grep ether | cut -d ' ' -f 6)
  printf "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"?*\", ATTR{address}==\"$RPIMAC\", ATTR{dev_id}==\"0x0\", ATTR{type}==\"1\", KERNEL==\"eth*\", NAME=\"eth0\"\n" > /etc/udev/rules.d/70-presistant-net.rules
fi

#### GET USER INPUTS #### HOSTNAME ######################################################################################################
read -p "Enter new hostname without .local e.g. rpi01 (.local will be automatically appended): " HOSTNAME_WITHOUT_LOCAL
while [[ "$HOSTNAME_WITHOUT_LOCAL" == *.* ]]
 do
  printf " --->$RED $HOSTNAME_WITHOUT_LOCAL $NORMAL<--- Is NOT an valid HOSTNAME, try again...\n"
  read -p "Enter new hostname without .local e.g.: rpi01  : " HOSTNAME
done
HOSTNAME="$HOSTNAME_WITHOUT_LOCAL.local"

#### IP AND NETMASK ! ###################################################################################################################
read -p "Enter new static IP and NETMASK e.g. 192.168.0.100/24 : " RPI_IP
while [[ ! "$RPI_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}+\/[0-9]+$ ]]
 do
  printf " --->$RED $RPI_IP $NORMAL<--- Is NOT an valid IPv4 ADDRESS with NETMASK, try again...\n"
  read -p "IPADDRESS & NETMASK ! E.G.: 192.168.0.100/24 : " RPI_IP
done
RPI_IP_ONLY=$(echo "$RPI_IP" | cut -d '/' -f 1)

#### GATEWAY ############################################################################################################################
GATEWAY="$(echo $RPI_IP | cut -d '.' -f 1,2,3).1"
read -p"Is $GATEWAY the correct gateway ?  y / n : " CORRECT
if [ "$CORRECT" != "y" ]
 then
  read -p "Enter the gateway  e.g. 192.168.0.1 : " GATEWAY
  while [[ ! "$GATEWAY" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$  ]]
   do
    printf " --->$RED $GATEWAY $NORMAL<--- Is NOT an valid IPv4 GATEWAY, try again...\n"
    read -p "THE GATEWAY IP ! E.G. 192.168.0.1 : " GATEWAY
  done
fi

#### INTERNAL IP ! ###################################################################################################################
read -p "Enter new bridge IP and NETMASK IP e.g. 10.10.10.11/24 : " BRIDGE_IP
while [[ ! "$BRIDGE_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}+\/[0-9]+$ ]]
 do
  printf " --->$RED $BRIDGE_IP $NORMAL<--- Is NOT an valid IPv4 ADDRESS with NETMASK, try again...\n"
  read -p "IPADDRESS ! E.G.: 10.10.10.11/24 : " BRIDGE_IP
done

# calculate network IP with mask from BRIDGE_IP
BRIDGE_NETWORK=$(echo $BRIDGE_IP | cut -d '.' -f 1,2,3).0/$(echo $BRIDGE_IP | cut -d '/' -f 2)

#### AGREE TO CHANGES ###################################################################################################################
printf "
$YELLOW#########################################################################################
=========================================================================================$NORMAL
THE NEW HOSTNAME WILL BE:$GREEN $HOSTNAME $NORMAL
=========================================================================================
THE DHCP SERVER ($YELLOW dhcpcd5 $NORMAL) WILL BE $RED REMOVED $NORMAL !!!
=========================================================================================
THE PIMOX REPO WILL BE ADDED IN : $YELLOW /etc/apt/sources.list.d/pimox.list $NORMAL CONFIGURATION :
$GRAY# Pimox 7 Development Repo$NORMAL
deb https://raw.githubusercontent.com/pimox/pimox7/master/ dev/
=========================================================================================
THE NETWORK CONFIGURATION IN : $YELLOW /etc/network/interfaces $NORMAL WILL BE $RED CHANGED $NORMAL !!! TO :
auto lo
iface lo inet loopback

iface eth0 inet manual

auto wlan0
iface wlan0 inet static
	address $RPI_IP
	gateway $GATEWAY
	wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf
	dns-nameservers $GATEWAY 1.1.1.1 8.8.8.8

auto vmbr0
iface vmbr0 inet static
	address $BRIDGE_IP
	bridge-ports none
	bridge-stp off
	bridge-fd 0
	post-up   echo 1 > /proc/sys/net/ipv4/ip_forward
	post-up   iptables -t nat -A POSTROUTING -s '$BRIDGE_NETWORK' -o wlan0 -j MASQUERADE
	post-down iptables -t nat -D POSTROUTING -s '$BRIDGE_NETWORK' -o wlan0 -j MASQUERADE
	post-up   iptables -t raw -I PREROUTING -i fwbr+ -j CT --zone 1
	post-down iptables -t raw -D PREROUTING -i fwbr+ -j CT --zone 1
=========================================================================================
THE HOSTNAMES IN : $YELLOW /etc/hosts $NORMAL WILL BE $RED OVERWRITTEN $NORMAL !!! WITH :
127.0.0.1\tlocalhost
$RPI_IP_ONLY\t$HOSTNAME
$RPI_IP_ONLY\t$HOSTNAME_WITHOUT_LOCAL
=========================================================================================
THESE STATEMENTS WILL BE $RED ADDED $NORMAL TO THE $YELLOW /boot/cmdline.txt $NORMAL IF NONE EXISTENT :
cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1
$YELLOW=========================================================================================
#########################################################################################\n $NORMAL
"

#### PROMPT FOR CONFORMATION ############################################################################################################
read -p "YOU ARE OKAY WITH THESE CHANGES ? YOUR DECLARATIONS ARE CORRECT ? CONTINUE ? y / n : " CONFIRM
if [ "$CONFIRM" != "y" ]; then exit; fi

#### SET A ROOT PWD FOR WEB GUI LOGIN ###################################################################################################
printf "
=========================================================================================
                          $RED ! SETUP NEW ROOT PASSWORD ! $NORMAL
=========================================================================================\n
" && passwd
if [ $? != 0 ]; then exit; fi

#### BASE UPDATE, DEPENDENCIES INSTALLATION #############################################################################################
printf "
=========================================================================================
 Begin installation, Normal duration on a default RPi4 ~ 30 minutes, be patient...
=========================================================================================\n
"

#### SET NEW HOSTNAME ###################################################################################################################
hostnamectl set-hostname $HOSTNAME

#### ADD SOURCE PIMOX7 + KEY & UPDATE & INSTALL RPI-KERNEL-HEADERS #######################################################################
printf "# PiMox7 Development Repo
deb https://raw.githubusercontent.com/pimox/pimox7/master/ dev/ \n" > /etc/apt/sources.list.d/pimox.list
curl https://raw.githubusercontent.com/pimox/pimox7/master/KEY.gpg |  apt-key add -
apt update && apt upgrade -y

#### REMOVE DHCP, CLEAN UP ###############################################################################################################
apt purge -y dhcpcd5
apt autoremove -y

#### FIX CONTAINER STATS NOT SHOWING UP IN WEB GUI #######################################################################################
if [ "$(cat /boot/cmdline.txt | grep cgroup)" != "" ]
 then
  printf "Seems to be already fixed!"
 else
  sed -i "1 s|$| cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1|" /boot/cmdline.txt
fi

#### INSTALL PIMOX7 AND REBOOT ###########################################################################################################

#### Install pve-manager separately, and without recommended packages, to avoid packaging issue later.
DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends -o Dpkg::Options::="--force-confdef" pve-manager

#### Continue with remaining packages
DEBIAN_FRONTEND=noninteractive apt install -y -o Dpkg::Options::="--force-confdef" proxmox-ve

#### RECONFIGURE NETWORK #### /etc/hosts REMOVE IPv6 #### /etc/network/interfaces.new CONFIGURE NETWORK TO CHANGE ON REBOOT ##############
printf "
=========================================================================================
$GREEN ! FIXING NETWORK CONFIGURATION.... ERRORS ARE NOMALAY FINE AND RESOLVED AFTER REBOOT ! $NORMAL
=========================================================================================
\n"
printf "127.0.0.1\tlocalhost
$RPI_IP_ONLY\t$HOSTNAME
$RPI_IP_ONLY\t$HOSTNAME_WITHOUT_LOCAL
" > /etc/hosts
printf "auto lo
iface lo inet loopback

iface eth0 inet manual

auto wlan0
iface wlan0 inet static
	address $RPI_IP
	gateway $GATEWAY
	wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf
	dns-nameservers $GATEWAY 1.1.1.1 8.8.8.8

auto vmbr0
iface vmbr0 inet static
	address $BRIDGE_IP
	bridge-ports none
	bridge-stp off
	bridge-fd 0
	post-up   echo 1 > /proc/sys/net/ipv4/ip_forward
	post-up   iptables -t nat -A POSTROUTING -s '$BRIDGE_NETWORK' -o wlan0 -j MASQUERADE
	post-down iptables -t nat -D POSTROUTING -s '$BRIDGE_NETWORK' -o wlan0 -j MASQUERADE
	post-up   iptables -t raw -I PREROUTING -i fwbr+ -j CT --zone 1
	post-down iptables -t raw -D PREROUTING -i fwbr+ -j CT --zone 1
" > /etc/network/interfaces.new

### FINAL MESSAGE ########################################################################################################################
printf "
=========================================================================================
                   $GREEN     ! INSTALATION COMPLETED ! WAIT ! REBOOT ! $NORMAL
=========================================================================================

    after reboot the PVE web interface will be reachable here :
      --->  $GREEN https://$RPI_IP_ONLY:8006/ $NORMAL <---

         run ---> $YELLOW apt upgrade -y $NORMAL <---
           in a root shell to complete the installation.

\n" && sleep 10 && reboot

#### EOF ####
