#!/bin/bash
#Declare variables here
ext_ip=<Compute Node external ip>
controller_Hostname=<Control Node hostname>
#
echo "Installing Nova compute"
yum -y install openstack-nova-compute
echo "Configuring Nova"
cp -a /etc/nova/nova.conf{,.bak}
grep -Ev '^$|#' /etc/nova/nova.conf.bak > /etc/nova/nova.conf
openstack-config --set /etc/nova/nova.conf DEFAULT enabled_apis osapi_compute,metadata
openstack-config --set /etc/nova/nova.conf DEFAULT transport_url rabbit://openstack:RABBIT_PASS@$controller_Hostname
openstack-config --set /etc/nova/nova.conf DEFAULT my_ip $ext_ip
openstack-config --set /etc/nova/nova.conf DEFAULT use_neutron true
openstack-config --set /etc/nova/nova.conf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver
openstack-config --set /etc/nova/nova.conf api auth_strategy keystone
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_url http://$controller_Hostname:5000/v3
openstack-config --set /etc/nova/nova.conf keystone_authtoken memcached_servers $controller_Hostname:11211
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_type password
openstack-config --set /etc/nova/nova.conf keystone_authtoken project_domain_name Default
openstack-config --set /etc/nova/nova.conf keystone_authtoken user_domain_name Default
openstack-config --set /etc/nova/nova.conf keystone_authtoken project_name service
openstack-config --set /etc/nova/nova.conf keystone_authtoken username nova
openstack-config --set /etc/nova/nova.conf keystone_authtoken password NOVA_PASS
openstack-config --set /etc/nova/nova.conf vnc enabled true
openstack-config --set /etc/nova/nova.conf vnc server_listen 0.0.0.0
openstack-config --set /etc/nova/nova.conf vnc server_proxyclient_address '$my_ip'
openstack-config --set /etc/nova/nova.conf vnc novncproxy_base_url http://$controller_Hostname:6080/vnc_auto.html
openstack-config --set /etc/nova/nova.conf glance api_servers http://$controller_Hostname:9292
openstack-config --set /etc/nova/nova.conf oslo_concurrency lock_path /var/lib/nova/tmp
openstack-config --set /etc/nova/nova.conf placement region_name RegionOne
openstack-config --set /etc/nova/nova.conf placement project_domain_name Default
openstack-config --set /etc/nova/nova.conf placement project_name service
openstack-config --set /etc/nova/nova.conf placement auth_type password
openstack-config --set /etc/nova/nova.conf placement user_domain_name Default
openstack-config --set /etc/nova/nova.conf placement auth_url http://$controller_Hostname:5000/v3
openstack-config --set /etc/nova/nova.conf placement username placement
openstack-config --set /etc/nova/nova.conf placement password PLACEMENT_PASS
openstack-config --set /etc/nova/nova.conf libvirt virt_type kvm
echo "Checking if the machine supports virtual machine hardware acceleration. If it does not, the virt_type value will change to qemu in the /etc/nova/nova.conf file"
hardware_Accel=$(egrep -c '(vmx|svm)' /proc/cpuinfo)
if [ $hardware_Accel -eq 0 ]; then
   openstack-config --set /etc/nova/nova.conf libvirt virt_type qemu
fi
systemctl enable libvirtd.service openstack-nova-compute.service
systemctl start libvirtd.service openstack-nova-compute.service
echo "Checking Nova compute status"
systemctl status libvirtd.service openstack-nova-compute.service
echo "Please go back to the control node for connecting with this compute node if the status is good"
 

