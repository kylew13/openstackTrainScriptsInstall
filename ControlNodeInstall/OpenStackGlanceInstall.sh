#!/bin/bash
#Define variables, leave no spaces at the end of the value
hostname=<hostname>
#
mysql -u root <<EOF
CREATE DATABASE glance;
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY 'GLANCE_DBPASS';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY 'GLANCE_DBPASS';
EOF
echo "Logging in as admin"
source ~/.bashrc
echo "Creating user"
openstack user create --domain default --password GLANCE_PASS glance
openstack role add --project service --user glance admin
echo "Creating public, internal, admin endpoints"
openstack service create --name glance --description "OpenStack Image" image
openstack endpoint create --region RegionOne image public http://$hostname:9292
openstack endpoint create --region RegionOne image internal http://$hostname:9292
openstack endpoint create --region RegionOne image admin http://$hostname:9292
echo "Installing Glance"
yum install openstack-glance -y
cp -a /etc/glance/glance-api.conf{,.bak}
cp -a /etc/glance/glance-registry.conf{,.bak}
grep -Ev '^$|#' /etc/glance/glance-api.conf.bak > /etc/glance/glance-api.conf
grep -Ev '^$|#' /etc/glance/glance-registry.conf.bak > /etc/glance/glance-registry.conf
echo "Configuring"
openstack-config --set /etc/glance/glance-api.conf database connection mysql+pymysql://glance:GLANCE_DBPASS@$hostname/glance
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken www_authenticate_uri http://$hostname:5000
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_url http://$hostname:5000
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken memcached_servers $hostname:11211
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_type password
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken project_domain_name Default
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken user_domain_name Default
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken project_name service
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken username glance
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken password GLANCE_PASS
openstack-config --set /etc/glance/glance-api.conf paste_deploy flavor keystone
openstack-config --set /etc/glance/glance-api.conf glance_store stores file,http
openstack-config --set /etc/glance/glance-api.conf glance_store default_store file
openstack-config --set /etc/glance/glance-api.conf glance_store filesystem_store_datadir /var/lib/glance/images/
echo "Populating databse"
su -s /bin/sh -c "glance-manage db_sync" glance
echo "Starting Glance service"
systemctl enable openstack-glance-api.service
systemctl start openstack-glance-api.service
echo "Downloading Cirros image"
wget http://download.cirros-cloud.net/0.4.0/cirros-0.4.0-x86_64-disk.img
echo "Uploading image to service"
glance image-create --name "cirros" --file cirros-0.4.0-x86_64-disk.img --disk-format qcow2 --container-format bare --visibility public
echo "Verify operation"
glance image-list
