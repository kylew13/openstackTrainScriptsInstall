#!/bin/bash
#Define variables, leave no spaces at the end of the value
hostname=<hostname>
ext_ip=<external ip/management ip>
mysql -u root <<EOF
CREATE DATABASE nova_api;
CREATE DATABASE nova;
CREATE DATABASE nova_cell0;
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY 'NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY 'NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY 'NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY 'NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'localhost' IDENTIFIED BY 'NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%' IDENTIFIED BY 'NOVA_DBPASS';
EOF
echo "Logging in as admin"
source ~/.bashrc
openstack user create --domain default --password NOVA_PASS nova
openstack role add --project service --user nova admin
openstack service create --name nova --description "OpenStack Compute" compute
openstack endpoint create --region RegionOne compute public http://$hostname:8774/v2.1
openstack endpoint create --region RegionOne compute internal http://$hostname:8774/v2.1
openstack endpoint create --region RegionOne compute admin http://$hostname:8774/v2.1
echo "Installing Nova service"
yum install -y openstack-nova-api openstack-nova-conductor openstack-nova-novncproxy openstack-nova-scheduler
cp -a /etc/nova/nova.conf{,.bak}
grep -Ev '^$|#' /etc/nova/nova.conf.bak > /etc/nova/nova.conf
echo "Configuring Nova"
openstack-config --set /etc/nova/nova.conf DEFAULT enabled_apis osapi_compute,metadata
openstack-config --set /etc/nova/nova.conf DEFAULT my_ip $ext_ip
openstack-config --set /etc/nova/nova.conf DEFAULT use_neutron true
openstack-config --set /etc/nova/nova.conf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver
openstack-config --set /etc/nova/nova.conf DEFAULT transport_url rabbit://openstack:RABBIT_PASS@$hostname:5672/
openstack-config --set /etc/nova/nova.conf api_database connection mysql+pymysql://nova:NOVA_DBPASS@$hostname/nova_api
openstack-config --set /etc/nova/nova.conf database connection mysql+pymysql://nova:NOVA_DBPASS@$hostname/nova
openstack-config --set /etc/nova/nova.conf api auth_strategy keystone
openstack-config --set /etc/nova/nova.conf keystone_authtoken www_authenticate_uri http://$hostname:5000/
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_url http://$hostname:5000/
openstack-config --set /etc/nova/nova.conf keystone_authtoken memcached_servers $hostname:11211
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_type password
openstack-config --set /etc/nova/nova.conf keystone_authtoken project_domain_name Default
openstack-config --set /etc/nova/nova.conf keystone_authtoken user_domain_name Default
openstack-config --set /etc/nova/nova.conf keystone_authtoken project_name service
openstack-config --set /etc/nova/nova.conf keystone_authtoken username nova
openstack-config --set /etc/nova/nova.conf keystone_authtoken password NOVA_PASS
openstack-config --set /etc/nova/nova.conf vnc enabled true
openstack-config --set /etc/nova/nova.conf vnc server_listen '$my_ip'
openstack-config --set /etc/nova/nova.conf vnc server_proxyclient_address '$my_ip'
openstack-config --set /etc/nova/nova.conf glance api_servers http://$hostname:9292
openstack-config --set /etc/nova/nova.conf oslo_concurrency lock_path /var/lib/nova/tmp
openstack-config --set /etc/nova/nova.conf placement region_name RegionOne
openstack-config --set /etc/nova/nova.conf placement project_domain_name Default
openstack-config --set /etc/nova/nova.conf placement project_name service
openstack-config --set /etc/nova/nova.conf placement auth_type password
openstack-config --set /etc/nova/nova.conf placement user_domain_name Default
openstack-config --set /etc/nova/nova.conf placement auth_url http://$hostname:5000/v3
openstack-config --set /etc/nova/nova.conf placement username placement
openstack-config --set /etc/nova/nova.conf placement password PLACEMENT_PASS
echo "Populating database"
su -s /bin/sh -c "nova-manage api_db sync" nova
su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova
su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova
su -s /bin/sh -c "nova-manage db sync" nova
su -s /bin/sh -c "nova-manage cell_v2 list_cells" nova
echo "Starting Nova service"
systemctl enable openstack-nova-api.service openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service
systemctl start openstack-nova-api.service openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service
echo "Nova service has started, checking operation, Cells_V2 check may fail if compute node has not been set up" 
nova-status upgrade check
