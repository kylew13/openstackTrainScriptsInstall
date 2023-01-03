#!/bin/bash
#Define variables here
ext_ip=<Compute Node external ip>
hostname=<Compute Node hostname>
controlNodeHostname=<Control Node hostname
controlNode_ip=<Control Node ip> 
#
echo "$ext_ip $hostname" >> /etc/hosts
echo "$controlNode_ip $controlNodeHostname" >> /etc/hosts
yum install chrony -y
systemctl restart chronyd.service
systemctl enable chronyd.service
chronyc sources
#
echo "Disabling SELINUX"
sed -ir 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
setenforce 0
#
echo "Disabling firewalld"
systemctl stop firewalld
systemctl disable firewalld
#
echo "Installing OpenStack repository" 
yum install https://rdoproject.org/repos/rdo-release.rpm -y
yum install python-openstackclient -y
yum install openstack-utils -y
#
