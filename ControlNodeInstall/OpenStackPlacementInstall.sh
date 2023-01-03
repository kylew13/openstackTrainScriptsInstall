#!/bin/bash
#Define variables here
hostname=<hostname>
#
mysql -u root <<EOF
CREATE DATABASE placement;
GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'localhost' IDENTIFIED BY 'PLACEMENT_DBPASS';
GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'%' IDENTIFIED BY 'PLACEMENT_DBPASS';
EOF
echo "Logging in as admin"
source ~/.bashrc
echo "Creating user"
openstack user create --domain default --password PLACEMENT_PASS placement
openstack role add --project service --user placement admin
echo "Creating public, internal, admin endpoint for Placement service"
openstack service create --name placement --description "Placement API" placement
openstack endpoint create --region RegionOne placement public http://$hostname:8778
openstack endpoint create --region RegionOne placement internal http://$hostname:8778
openstack endpoint create --region RegionOne placement admin http://$hostname:8778
echo "Installing Placement service" 
yum install openstack-placement-api -y
cp /etc/placement/placement.conf /etc/placement/placement.conf.bak
grep -Ev '^$|#' /etc/placement/placement.conf.bak > /etc/placement/placement.conf
echo "Configuring Placement"
openstack-config --set  /etc/placement/placement.conf placement_database connection mysql+pymysql://placement:PLACEMENT_DBPASS@$hostname/placement
openstack-config --set  /etc/placement/placement.conf api auth_strategy keystone
openstack-config --set  /etc/placement/placement.conf keystone_authtoken auth_url http://$hostname:5000/v3
openstack-config --set  /etc/placement/placement.conf keystone_authtoken memcached_servers $hostname:11211
openstack-config --set  /etc/placement/placement.conf keystone_authtoken auth_type password
openstack-config --set  /etc/placement/placement.conf keystone_authtoken project_domain_name Default
openstack-config --set  /etc/placement/placement.conf keystone_authtoken user_domain_name Default
openstack-config --set  /etc/placement/placement.conf keystone_authtoken project_name service
openstack-config --set  /etc/placement/placement.conf keystone_authtoken username placement
openstack-config --set  /etc/placement/placement.conf keystone_authtoken password PLACEMENT_PASS
echo "Populating database"
su -s /bin/sh -c "placement-manage db sync" placement
#Edit the 00-placement-api.conf file and then restart httpd and verify operation
echo "Configure the 00-placement-api.conf file manually to prevent errors when verifying operation"
