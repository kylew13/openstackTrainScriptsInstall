#!/bin/bash
#Define variables here
ext_interface=<external interface/provider interface>
#Following IP is for management network
ext_ip=<local ip/management ip>
hostname=<hostname>
#
mysql -u root <<EOF
CREATE DATABASE neutron;
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY 'NEUTRON_DBPASS';
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY 'NEUTRON_DBPASS';
EOF
echo "logging in as admin"
source ~/.bashrc
openstack user create --domain default --password NEUTRON_PASS neutron
openstack role add --project service --user neutron admin
openstack service create --name neutron --description "OpenStack Networking" network
echo "Creating public, internal, and admin endpoint"
openstack endpoint create --region RegionOne network public http://$hostname:9696
openstack endpoint create --region RegionOne network internal http://$hostname:9696
openstack endpoint create --region RegionOne network admin http://$hostname:9696
yum install -y openstack-neutron openstack-neutron-ml2 openstack-neutron-linuxbridge ebtables
cp -a /etc/neutron/neutron.conf{,.bak}
grep -Ev '^$|#' /etc/neutron/neutron.conf.bak > /etc/neutron/neutron.conf
echo "Configuring Neutron service"
openstack-config --set /etc/neutron/neutron.conf database connection mysql+pymysql://neutron:NEUTRON_DBPASS@$hostname/neutron
openstack-config --set /etc/neutron/neutron.conf DEFAULT core_plugin ml2
openstack-config --set /etc/neutron/neutron.conf DEFAULT service_plugins router
openstack-config --set /etc/neutron/neutron.conf DEFAULT allow_overlapping_ips true
openstack-config --set /etc/neutron/neutron.conf DEFAULT transport_url rabbit://openstack:RABBIT_PASS@$hostname
openstack-config --set /etc/neutron/neutron.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_status_changes true
openstack-config --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_data_changes true
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken www_authenticate_uri http://$hostname:5000
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_url http://$hostname:5000
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken memcached_servers $hostname:11211
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_type password
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken project_domain_name default
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken user_domain_name default
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken project_name service
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken username neutron
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken password NEUTRON_PASS
openstack-config --set /etc/neutron/neutron.conf oslo_concurrency lock_path /var/lib/neutron/tmp
openstack-config --set /etc/neutron/neutron.conf nova auth_url http://$hostname:5000
openstack-config --set /etc/neutron/neutron.conf nova auth_type password
openstack-config --set /etc/neutron/neutron.conf nova project_domain_name default
openstack-config --set /etc/neutron/neutron.conf nova user_domain_name default
openstack-config --set /etc/neutron/neutron.conf nova region_name RegionOne
openstack-config --set /etc/neutron/neutron.conf nova project_name service
openstack-config --set /etc/neutron/neutron.conf nova username nova
openstack-config --set /etc/neutron/neutron.conf nova password NOVA_PASS
echo "Configuring ML2 plugin"
cp -a /etc/neutron/plugins/ml2/ml2_conf.ini{,.bak}
grep -Ev '^$|#' /etc/neutron/plugins/ml2/ml2_conf.ini.bak > /etc/neutron/plugins/ml2/ml2_conf.ini
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers flat,vlan,vxlan
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types vxlan
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers linuxbridge,l2population
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 extension_drivers port_security
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_flat flat_networks provider
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vxlan vni_ranges 1:1000
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_ipset  true
echo "Configuring Linux bridge agent"
cp -a /etc/neutron/plugins/ml2/linuxbridge_agent.ini{,.bak}
grep -Ev '^$|#' /etc/neutron/plugins/ml2/linuxbridge_agent.ini.bak > /etc/neutron/plugins/ml2/linuxbridge_agent.ini
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini linux_bridge physical_interface_mappings  provider:$ext_interface
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan enable_vxlan  true
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan local_ip $ext_ip
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan l2_population true
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup enable_security_group  true
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup firewall_driver  neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
echo 'net.bridge.bridge-nf-call-iptables=1' >> /etc/sysctl.conf
echo 'net.bridge.bridge-nf-call-ip6tables=1' >> /etc/sysctl.conf
modprobe br_netfilter
echo "Checking IP tables"
sysctl -p
echo "Configuring layer 3 agent"
cp -a /etc/neutron/l3_agent.ini{,.bak}
grep -Ev '^$|#' /etc/neutron/l3_agent.ini.bak > /etc/neutron/l3_agent.ini
openstack-config --set /etc/neutron/l3_agent.ini DEFAULT interface_driver linuxbridge
echo "Configuring DHCP agent"
cp -a /etc/neutron/dhcp_agent.ini{,.bak}
grep -Ev '^$|#' /etc/neutron/dhcp_agent.ini.bak > /etc/neutron/dhcp_agent.ini
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT interface_driver linuxbridge
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT dhcp_driver neutron.agent.linux.dhcp.Dnsmasq
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT enable_isolated_metadata true
echo "Configuring Metadata agent"
cp -a /etc/neutron/metadata_agent.ini{,.bak}
grep -Ev '^$|#' /etc/neutron/metadata_agent.ini.bak > /etc/neutron/metadata_agent.ini
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT nova_metadata_host $hostname
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT metadata_proxy_shared_secret METADATA_SECRET
echo "Configuring Nova service for Neutron"
#openstack-config --set /etc/nova/nova.conf neutron url http://$hostname:9696
openstack-config --set /etc/nova/nova.conf neutron auth_url http://$hostname:5000
openstack-config --set /etc/nova/nova.conf neutron auth_type password
openstack-config --set /etc/nova/nova.conf neutron project_domain_name default
openstack-config --set /etc/nova/nova.conf neutron user_domain_name default
openstack-config --set /etc/nova/nova.conf neutron region_name RegionOne
openstack-config --set /etc/nova/nova.conf neutron project_name service
openstack-config --set /etc/nova/nova.conf neutron username neutron
openstack-config --set /etc/nova/nova.conf neutron password NEUTRON_PASS
openstack-config --set /etc/nova/nova.conf neutron service_metadata_proxy true
openstack-config --set /etc/nova/nova.conf neutron metadata_proxy_shared_secret METADATA_SECRET
echo "Populating database"
ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron
systemctl restart openstack-nova-api.service
systemctl enable neutron-server.service neutron-linuxbridge-agent.service neutron-dhcp-agent.service neutron-metadata-agent.service neutron-l3-agent.service
systemctl start neutron-server.service neutron-linuxbridge-agent.service neutron-dhcp-agent.service neutron-metadata-agent.service neutron-l3-agent.service
echo "Checking Neutron status" 
systemctl status neutron-server.service neutron-linuxbridge-agent.service neutron-dhcp-agent.service neutron-metadata-agent.service neutron-l3-agent.service

