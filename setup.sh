#!/bin/bash

set -e

export DEBIAN_FRONTEND=noninteractive

# Copy files
cp limits.conf /etc/security/limits.conf
cp sysctl/* /etc/sysctl.d/

mkdir -p /etc/kubernetes/
cp kubelet-config.json /etc/kubernetes/kubelet-config.json

# static manifests
mkdir -p /var/lib/gitpod/manifests
cp manifests/* /var/lib/gitpod/manifests

# Configure containerd
mkdir -p /etc/containerd/
cp containerd.toml /etc/containerd/config.toml

# Update OS
apt update && apt dist-upgrade -y

# Install required packages
apt --no-install-recommends install -y \
  apt-transport-https ca-certificates curl gnupg2 software-properties-common \
  iptables libseccomp2 socat conntrack ipset \
  fuse \
  jq \
  iproute2 \
  auditd \
  ethtool \
  net-tools \
  google-compute-engine google-osconfig-agent \
  dkms

# Enable modules
cat <<EOF > /etc/modules-load.d/k8s.conf
br_netfilter
overlay
fuse
shiftfs
EOF

# Disable modules
cat <<EOF > /etc/modprobe.d/kubernetes-blacklist.conf
blacklist dccp
blacklist sctp
EOF

# Enable cgroups2
#sed -i 's/GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="systemd.unified_cgroup_hierarchy=1 \1"/g' /etc/default/grub

# Install linux kernel 5.14
add-apt-repository -y ppa:tuxinvader/lts-mainline
apt-get update
apt-get install -y linux-generic-5.15

# Install containerd
curl -sSL https://github.com/containerd/nerdctl/releases/download/v0.14.0/nerdctl-full-0.14.0-linux-amd64.tar.gz -o - | tar -xz -C /usr/local

# copy the portmap plugin to support hostport
mkdir -p /opt/cni/bin
ln -s /usr/local/libexec/cni/portmap /opt/cni/bin

# Reload systemd
systemctl daemon-reload

# Start containerd and stargz
systemctl enable containerd

# Download k3s install script
curl -sSL https://get.k3s.io/ -o /usr/local/bin/install-k3s.sh
chmod +x /usr/local/bin/install-k3s.sh

# Install helm
curl -fsSL https://get.helm.sh/helm-v3.7.0-linux-amd64.tar.gz -o - | tar -xzvC /tmp/ --strip-components=1
cp /tmp/helm /usr/local/bin/helm

# cleanup temporal packages
apt-get clean
apt-get autoclean
apt-get autoremove -y

# cleanup journal logs
rm -rf /var/log/journal/*
rm -rf /tmp/*

rm /etc/resolv.conf
echo "nameserver 8.8.8.8" > /etc/resolv.conf
