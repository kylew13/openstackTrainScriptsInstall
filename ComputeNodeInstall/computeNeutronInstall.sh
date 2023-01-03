#!/bin/bash
#Define variables
ext_interface=<Network interface for external>
int_ip=<Internal ip/local ip>
controlNodeHostname=<Compute Node hostname>
#
echo "Installing Neutron for compute node"
yum install openstack-neutron-linuxbridge ebtables ipset -y
echo "Configuring neutron"
cp -a /etc/neutron/neutron.conf{,.bak}
grep -Ev '^$|#' /etc/neutron/neutron.conf.bak > /etc/neutron/neutron.conf
openstack-config --set /etc/neutron/neutron.conf DEFAULT transport_url rabbit://openstack:RABBIT_PASS@$controlNodeHostname
openstack-config --set /etc/neutron/neutron.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken www_authenticate_uri http://$controlNodeHostname:5000
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_url http://$controlNodeHostname:5000
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken memcached_servers $controlNodeHostname:11211
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_type password
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken project_domain_name default
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken user_domain_name default
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken project_name service
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken username neutron
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken password NEUTRON_PASS 
openstack-config --set /etc/neutron/neutron.conf oslo_concurrency lock_path /var/lib/neutron/tmp
echo "Configuring Linux bridge agent"
cp -a /etc/neutron/plugins/ml2/linuxbridge_agent.ini{,.bak}
grep -Ev '^$|#' /etc/neutron/plugins/ml2/linuxbridge_agent.ini.bak > /etc/neutron/plugins/ml2/linuxbridge_agent.ini
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini linux_bridge physical_interface_mappings provider:$ext_interface
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan enable_vxlan true
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan local_ip $int_ip
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan l2_population true
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup enable_security_group true
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
echo "Configuring sysctl.conf"
echo 'net.bridge.bridge-nf-call-iptables=1' >> /etc/sysctl.conf
echo 'net.bridge.bridge-nf-call-ip6tables=1' >> /etc/sysctl.conf
modprobe br_netfilter
sysctl -p
echo "Configuring Nova service"
openstack-config --set /etc/nova/nova.conf neutron auth_url http://$controlNodeHostname:5000
openstack-config --set /etc/nova/nova.conf neutron auth_type password
openstack-config --set /etc/nova/nova.conf neutron project_domain_name default
openstack-config --set /etc/nova/nova.conf neutron user_domain_name default
openstack-config --set /etc/nova/nova.conf neutron region_name RegionOne
openstack-config --set /etc/nova/nova.conf neutron project_name service
openstack-config --set /etc/nova/nova.conf neutron username neutron
openstack-config --set /etc/nova/nova.conf neutron password NEUTRON_PASS
echo "Restarting Nova service"
systemctl restart openstack-nova-compute.service
echo "Starting Neutron service"
systemctl enable neutron-linuxbridge-agent.service
systemctl start neutron-linuxbridge-agent.service
echo "Neutron compute script finished, please verify by using 'openstack extension list --network' and 'openstack network agent list' in the control node"
systemctl status neutron-linuxbridge-agent.service


