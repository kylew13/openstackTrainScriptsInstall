# OpenStack Train Installation Scripts Information
Author: Kyle Wangsameteegoon
These script files are meant to run once and currently tested on Centos 7 and RedHat 7. Variables will also need to be assigned inside each of these scripts. 

### When using RedHat 7, you may need to use this command depending on your subscription before installing any packages:
```
subscription-manager repos --enable=rhel-7-server-optional-rpms --enable=rhel-7-server-extras-rpms --enable=rhel-7-server-rh-common-rpms
```
## For control node scripts, please run the scripts for the services in the following order:
1. environmentInstall
2. Keystone (OpenStackKeystoneInstall)
3. Glance (OpenStackGlanceInstall)
4. Placement (OpenStackPlacementInstall)

After running the placement script, add this to the 00-placement-api.conf file:
```
<Directory /usr/bin>
  <IfVersion >= 2.4>
     Require all granted
  </IfVersion>
  <IfVersion < 2.4>
     Order allow,deny
     Allow from all
  </IfVersion>
</Directory>
```
Restart httpd when done
```
systemctl restart httpd
```
5. Nova (OpenStackNovaInstall)
6. Neutron (OpenStackNeutronInstall)
7. Horizon (Uses OpenStackHorizonInstall and can be completed after setting up the compute node)

### Further configuration is needed in the /etc/openstack-dashboard/local_settings file for Horizon and additional steps:

Specific hosts can be assigned for accessing the dashboard for an example:
```
ALLOWED_HOSTS = ['one.example.com', 'two.example.com']
```
If you want to allow all hosts, change the value to ['*'] but it is not recommended for production.

To rebuild the dashboard configuration file run the following commands.
```
cd /usr/share/openstack-dashboard
```
```
python manage.py make_web_conf --apache > /etc/httpd/conf.d/openstack-dashboard.conf
```

Set up the httpd and memcached service for Horizon.
```
systemctl enable httpd.service
```
```
systemctl restart httpd.service memcached.service
```
## For compute node script run the scripts in this order:
1. computeEnvironmentInstall
2. Nova (computeNovaInstall)

After running the Nova script, go back to the control node discover compute node hosts: \
Check if the compute node can be detected by control node
```
openstack compute service list --service nova-compute
```
Use this command to discover hosts for cell_v2.
```
su -s /bin/sh -c "nova-manage cell_v2 discover_hosts --verbose" nova
```
This can also be automatically done by in /etc/nova/nova.conf in the scheduler section but it is optional.
```
[scheduler]
discover_hosts_in_cells_interval = 300
```
Restart Nova-api when finished
```
systemctl restart openstack-nova-api.service
```

3. Neutron (computeNeutronInstall)

After finishing installation verify if the services are working as expected. The chrony service can be configured or add hosts for compute node and control node in the hosts file if needed. 
