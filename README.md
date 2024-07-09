# Pimox (Proxmox for Raspberry Pi) Ansible playbooks

This repository contains [Ansible](https://www.ansible.com) playbooks for a quick set up of [Pimox](https://github.com/pimox/pimox7) on [Raspberry Pi clusters](https://dzone.com/articles/building-a-24-core-raspberry-pi-cluster-from-scrat) using WiFi.

## Prerequisites

- A bunch of Raspberry Pies (duh!)
- WiFi connection (duh! x 2)
- Raspberry Pies should be connected to the WiFi network
- Raspberry Pies should be accessible via SSH
- Ansible installed on your workstation

## Creating an Ansible inventory

Define an inventory in the __/etc/ansible/hosts__ file with the following variables for each host:

- `hostname`: the desired hostname without any domain
- `new_ip`: the desired static IP address for the host
- `internal_ip`: the internal bridge network (`vmbr0`) IP address
- `new_root_password`: the new root password for the host

Here's an example:

```yml
[proxmox_rpies]
192.168.1.151	ansible_user=pi	hostname=rpi01	new_ip=192.168.1.151/24	bridge_ip=10.10.11.10	new_root_password=PiPassword123!
192.168.1.152	ansible_user=pi	hostname=rpi02	new_ip=192.168.1.152/24	bridge_ip=10.10.12.10	new_root_password=PiPassword123!
192.168.1.153	ansible_user=pi	hostname=rpi03	new_ip=192.168.1.153/24	bridge_ip=10.10.13.10	new_root_password=PiPassword123!
```

## Installing Pimox

Clone this repository and run the following playbook:

```shell
ansible-playbook install.yml
```

Be patient! All Raspberry Pi devices will be rebooted after Pimox/Proxmox is installed.

## Creating the Proxmox cluster

1. Point your browser to the Proxmox GUI on one of the nodes (for example: [https://192.168.1.151:8006](https://192.168.1.151:8006)). Make sure to use HTTPS.
2. Login with `root` and the password you set for the host (for example: `Password123!`).
3. Click on __Datacenter > Cluster > Create Cluster__, set a name for the cluster and create it.
4. Click on __Join Information__ and copy the information.
5. For each other node in the cluster, use the Proxmox GUI to:
   1. Click on __Datacenter > Cluster > Join Cluster__.
   2. Paste the copied information.
   3. Type the root password of the node to join (the one from which you copied the information).
   4. Join the cluster.

You should have a Proxmox cluster up and running.

## Creating your first VM

Use the standard procedure to create VMs but:

- In __OS__ select __Do not use any media__
- In __System__ use __OVMF (UEFI)__ as the __BIOS__ and select the corresponding EFI storage.
- Go to __Hardware__ and remove the CD/DVD drive.
- Add a new CD/DVD drive and use SCSI (Raspberry Pi devices don't have IDE)
- Select the ISO image of the operating system that you want to install
- Change the boot order so that the CD/DVD drive is used first (__Options > Boot Order__)

Configure the network using the supplied bridge network information. For example, here's a possible VM's __etc/network/interfaces__ file:

```plain
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
        address 10.10.13.101
        netmask 255.255.255.0
        gateway 10.10.13.10
```

To make the VMs visible from your workstation, add routes from the bridge networks to the Raspberry Pi IPs. For example, on macOS:

```shell
sudo route -n add -net 10.10.11.0/24 192.168.1.151
sudo route -n add -net 10.10.12.0/24 192.168.1.152
sudo route -n add -net 10.10.13.0/24 192.168.1.153
```
