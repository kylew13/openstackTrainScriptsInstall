#!/bin/bash
ext_ip=<external ip/management ip>
hostname=<hostname>
#
echo "$ext_ip $hostname" >> /etc/hosts
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
yum install openstack-selinux -y
yum install openstack-utils -y
#
echo "Installing mariadb"
yum install mariadb mariadb-server python2-PyMySQL -y
cat > /etc/my.cnf.d/openstack.cnf << EOF
[mysqld]
bind-address = $ext_ip 
 
default-storage-engine = innodb     #Default Storage Engine
innodb_file_per_table = on          #one database file for each table
max_connections = 4096              #maximum number of connections
collation-server = utf8_general_ci   #default character set
character-set-server = utf8
EOF
systemctl enable mariadb.service
systemctl start mariadb.service
#
echo "Installing RabbitMQ"
yum install rabbitmq-server -y
systemctl enable rabbitmq-server.service
systemctl start rabbitmq-server.service
rabbitmqctl add_user openstack RABBIT_PASS
rabbitmqctl set_permissions openstack ".*" ".*" ".*"
echo "Installing Memcache"
yum install memcached python-memcached -y
sed -i '/OPTIONS/c\OPTIONS="-l 0.0.0.0"' /etc/sysconfig/memcached
systemctl enable memcached.service
systemctl start memcached.service
echo "Installing etcd"
yum install etcd -y
cp -a /etc/etcd/etcd.conf{,.bak}
cat > /etc/etcd/etcd.conf <<EOF 
#[Member]
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"
ETCD_LISTEN_PEER_URLS="http://$ext_ip:2380"
ETCD_LISTEN_CLIENT_URLS="http://$ext_ip:2379"
ETCD_NAME="$hostname"
#[Clustering]
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://$ext_ip:2380"
ETCD_ADVERTISE_CLIENT_URLS="http://$ext_ip:2379"
ETCD_INITIAL_CLUSTER="$hostname=http://$ext_ip:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster-01"
ETCD_INITIAL_CLUSTER_STATE="new"
EOF
systemctl enable etcd
systemctl start etcd
echo "OpenStack environment installed"




