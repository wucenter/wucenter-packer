# WUcenter Packer template provisioner

:building_construction: Build a minimal Ubuntu image for VMware vCenter or ESXi in minutes

Official template builder for [WUcenter Ansible framework](https://github.com/wucenter/wucenter-ansible).

## Features

- Dual VMware products support
    + Supports vCenter cluster API (`vsphere-iso`)
    + Supports single ESXi host (`vmware-iso`)
- Ubuntu products support
    + Supports Bionic Server (18.04.04)
    + Supports Focal Server (20.04)
- Minimal & Up-To-Date
    + ~220 packages, ~850MB
    + Static IP assignment
    + Oldschool NIC names, no IPv6
    + HWE Virtual Kernel
- Provisioning-ready
    + Python 3.6, compat Ansible >=2.5
    + OpenSSH server, PasswordAuthentication=yes, UseDNS=no
    + `ansibler` user/pass, uid 999, password-less sudoer

## VMware vCenter prerequisites

- Since [Packer 1.5.2](https://releases.hashicorp.com/packer/1.5.2/), vSphere builder (`vsphere-iso`) is natively supported
- Previously, [Packer 1.3.5](https://releases.hashicorp.com/packer/1.3.5/) was compatible with [vSphere Builder by JetBrains](https://github.com/jetbrains-infra/packer-builder-vsphere)

## VMware ESXi prerequisites

VMware ESXi is natively supported by Packer `vmware-iso` builder.

As seen [here](https://web.archive.org/web/20200206152031/https://blog.ukotic.net/2019/03/05/configuring-esxi-prerequisites-for-packer/) some tweaking is required on the ESXi server.

~~~ bash
# Enable GuestIPHack for Hashicorp Packer
esxcli system settings advanced set -o /Net/GuestIPHack -i 1

# Un-firewall VNC ports for Hashicorp Packer
chmod 644  /etc/vmware/firewall/service.xml
sed -i '/<\/ConfigRoot>/d' /etc/vmware/firewall/service.xml
cat <<'EOF' >>/etc/vmware/firewall/service.xml
<!-- Hashicorp Packer enablement: open 5900-6000 TCP ports (VNC)  -->
<service id="1000">
  <id>packer-vnc-custom</id>
  <rule id="0000">
    <direction>inbound</direction>
    <protocol>tcp</protocol>
    <porttype>dst</porttype>
    <port>
      <begin>5900</begin>
      <end>6000</end>
    </port>
  </rule>
  <enabled>true</enabled>
  <required>true</required>
</service>
</ConfigRoot>
EOF
chmod 444 /etc/vmware/firewall/service.xml
esxcli network firewall refresh
~~~

## Installation

- Clone the project somewhere
- Copy latest Packer [binary](https://releases.hashicorp.com/packer/) in project or `$PATH`

## Configuration

Create a configuration file from `samples/*.json`:
- Setup static network configuration: `NET_*`.
- Setup VMware server credentials: `VMW_*`

Remeber, 3 configuration levels are available:
1. Default variables in `ubuntu-{bionic,focal}.{exsi,vcenter}.json`
2. Custom variables in `samples/{exsi,vcenter}.json`
3. Runtime arguments as `-var 'VMW_USERNAME=user@vc.lan' -var 'VMW_PASSWORD=<secret>'`

## Usage

Recommended usage is using `var-file`s for config, except maybe for secrets and of course shell variables:

- This command will build a bionic VM on vCenter server:

~~~ bash
time PACKER_LOG=1 packer build -on-error=ask -force \
  -var-file=samples/vcenter.json \
  -var 'NAME=MY_TEMPLATE_' \
  -var 'VERSION=1.1' \
  ubuntu-bionic.vcenter.json
~~~

- This command will build a bionic VM on ESXi server:

~~~ bash
time PACKER_LOG=1 packer build -on-error=ask -force \
  -var-file=samples/esxi.json \
  -var 'NAME=MY_TEMPLATE_NAME_' \
  -var 'VERSION=1.1' \
  ubuntu-bionic.esxi.json
~~~

- This command will create a focal VM template on vCenter cluster:

~~~ bash
time PACKER_LOG=1 packer build -on-error=ask -force \
  -var-file=samples/vcenter.json \
  -var 'VERSION=2.1' \
  ubuntu-focal.vcenter.json
~~~

## Documentation

### Configuration

The following self-explaining template variables are used:

- NAME
- VERSION
- RSC_CPU
- RSC_RAM
- RSC_DISK
- NET_GW
- NET_IP
- NET_NM
- NET_NS
- VMW_VCENTER
- VMW_USERNAME
- VMW_PASSWORD
- VMW_CLUSTER
- VMW_DATASTORE
- VMW_NETWORK
- VMW_FOLDER
- SSH_USERNAME
- SSH_PASSWORD

Note that modifing SSH_USERNAME & SSH_PASSWORD also requires editing `passwd/*` values in corresponding `d-i/SEED_*.CFG` file.

### Implementation

`d-i` is preseeded with a virtual floppy.

`d-i` is extended by a custom script triggered by `preseed/late_command`.

Networking is configured from Linux kernel boot command.

### Hacking

You can simply customize your template by editing debian-installer seed and corresponding "late" script in `d-i/`

### References

- Packer vCenter builder <https://github.com/jetbrains-infra/packer-builder-vsphere#parameter-reference>
- Packer ESXi builder <https://packer.io/docs/builders/vmware-iso.html#vmware-iso-builder-configuration-reference>
- Ubuntu preseeding <https://help.ubuntu.com/lts/installation-guide/s390x/apbs04.html>

## Roadmap

- Workaround more VMware bugs on bionic
  + <https://kb.vmware.com/s/article/54986>
  + <https://kb.vmware.com/s/article/56409>
