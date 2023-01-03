#!/bin/bash
#Define variables here
ext_ip=<external ip>
hostname=<hostname>
mysql -u root <<EOF
CREATE DATABASE keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY 'KEYSTONE_DBPASS';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY 'KEYSTONE_DBPASS';
EOF
echo "Installing Keystone"
yum install openstack-keystone httpd mod_wsgi -y
cp -a /etc/keystone/keystone.conf{,.bak}
grep -Ev '^$|#' /etc/keystone/keystone.conf.bak > /etc/keystone/keystone.conf
openstack-config --set /etc/keystone/keystone.conf database connection mysql+pymysql://keystone:KEYSTONE_DBPASS@$hostname/keystone
openstack-config --set /etc/keystone/keystone.conf token provider fernet
echo "Populating database"
su -s /bin/sh -c 'keystone-manage db_sync' keystone
echo "Setting up fernet repository"
keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
keystone-manage bootstrap --bootstrap-password ADMIN_PASS --bootstrap-admin-url http://$hostname:5000/v3/ --bootstrap-internal-url http://$hostname:5000/v3/ --bootstrap-public-url http://$hostname:5000/v3/ --bootstrap-region-id RegionOne
echo "ServerName $hostname" >> /etc/httpd/conf/httpd.conf
ln -s /usr/share/keystone/wsgi-keystone.conf /etc/httpd/conf.d/
systemctl enable httpd.service
systemctl restart httpd.service
echo "Adding admin credentials"
cat >> ~/.bashrc << EOF
export OS_USERNAME=admin
export OS_PASSWORD=ADMIN_PASS
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_AUTH_URL=http://$hostname:5000/v3
export OS_IDENTITY_API_VERSION=3
EOF
echo "Logging in as admin"
source ~/.bashrc
echo "Verifying operation"
openstack token issue
openstack project create --domain default --description "Service Project" service
openstack role create user
openstack role list

