#!/bin/bash
#Define variables here, use the 'TZ database name' column for the time zone value from this link: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones 
#Only works with self-service (option 2) networking option
hostname=<Control Node hostname>
timezone=<Time zone of region>
#
echo "Installing Horizon"
yum install openstack-dashboard -y
cp /etc/openstack-dashboard/local_settings /etc/openstack-dashboard/local_settings.bak
sed -i '/OPENSTACK_HOST = "127.0.0.1"/c\OPENSTACK_HOST = "'$hostname'"' /etc/openstack-dashboard/local_settings
sed -i '/TIME_ZONE = "UTC"/c\TIME_ZONE = "'$timezone'"' /etc/openstack-dashboard/local_settings
echo 'OPENSTACK_KEYSTONE_DEFAULT = "Default"' >> /etc/openstack-dashboard/local_settings
echo 'OPENSTACK_KEYSTONE_ROLE = "user"' >> /etc/openstack-dashboard/local_settings
echo 'OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = True' >> /etc/openstack-dashboard/local_settings
echo 'OPENSTACK_API_VERSIONS = {"identity": 3, "image": 2, "volume": 3, }' >> /etc/openstack-dashboard/local_settings
echo "SESSION_ENGINE = 'django.contrib.sessions.backends.cache'" >> /etc/openstack-dashboard/local_settings
echo "CACHES = { 'default': { 'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache','LOCATION': '$hostname:11211', } }" >> /etc/openstack-dashboard/local_settings
