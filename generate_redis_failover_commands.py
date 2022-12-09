#Generate failover commands for a Redis node based on current cluster status
#!/usr/bin/env python
#Need to run the following prerequisites:
#   echo "yes" | subscription-manager repos --enable rhel-server-rhscl-7-rpms; yum install python27-python-pip scl-utils -y
#   scl enable python27 bash
#   pip install redis

import redis
import glob
import ntpath
import re
redis_info_hash = {}

for file in glob.glob('/etc/redis/redis*.conf'):
    with open(file) as redis_config_file:
        for line in redis_config_file.readlines():
            #Parse redis config file for 'redis_port' and 'auth'
            if 'port' in line:
                redis_port = (line.split()[1])
            if 'auth' in line:
                auth = (line.split()[1]).replace('"', "")
            #Open sentinel config file which corresponds with currently open redis config file
            with open(file.replace('redis.','sentinel.')) as sentinel_config_file:
                #Read 'sentinel_cluster_name' and 'sentinel_port' from parsed sentinel config file
                for line in sentinel_config_file.readlines():
                    if 'auth-pass' in line:
                        sentinel_cluster_name = (line.split()[2])
                    if 'port' in line:
                        sentinel_port = (line.split()[1])
        #Create a redis connection and parse returned info to get redis role
        redis_connection = redis.StrictRedis(host='localhost', port=redis_port, password=auth, db=3)
        data = redis_connection.execute_command('INFO')
        role = data['role'].encode("ascii")
        #Append all info gathered above to redis_info_hash
        redis_info_hash[(ntpath.basename(file).rsplit(".",1)[0])] = {'role': role, 'auth': auth, 'redis_port': redis_port, 'sentinel_cluster_name': sentinel_cluster_name, 'sentinel_port': sentinel_port}
#Loop through redis hash and generate failover commands if node is master. Failover commands are appended to '/sentinel_failover.sh'
for redis_instance, redis_instance_attributes in redis_info_hash.items():
    if redis_instance_attributes['role'] == 'master':
                print('Instance '+redis_instance+' is configured as a master.\n A failover will be required')
                with open('/sentinel_failover.sh', 'a+') as the_file:
                    the_file.write('redis-cli -h $(hostname -i) -p '+redis_instance_attributes['sentinel_port']+' -a '+redis_instance_attributes['auth']+' SENTINEL failover '+' '+redis_instance_attributes['sentinel_cluster_name']+'\n')
                    
                

