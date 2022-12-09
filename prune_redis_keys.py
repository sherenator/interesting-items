#!/bin python
#usage:
#list keyspace info
#python  python /prune_redis_keys.py -h redis3 -p 26380 -a ******************** -l

#Display percentage of keys to be removed from specified DB (-r flag not specified)
#python  /prune_redis_keys.py -h redis3 -p 26380 -d 3 -a ******************** -i 43200

#Remove keys (-r flag specified)
#python  /prune_redis_keys.py -h redis3 -p 26380 -d 3 -a ******************** -i 43200 -r

import argparse
import redis
import json
import os
import sys
import logging
from collections import Counter

old_keys = [] #initialize key name collector list    

p = argparse.ArgumentParser(add_help=False)
p.add_argument("-h", '--host', type=str, default="127.0.0.1", help="redis host", required=False)
p.add_argument("-p", '--port', type=int, default=6379, help="redis port", required=False)
p.add_argument("-o", '--outputfile', type=str, default="/var/log/prune_redis_keys/output.log", help="output file", required=False)
p.add_argument("-d", '--db', type=int, default=0, help="redis database", required=False)
p.add_argument("-a", '--password', type=str, default="", help="redis password", required=False)
p.add_argument("-i", '--idletime', type=int, default=432000, help="redis idletime", required=False)
p.add_argument("-r", '--remove', action="store_true", help="remove keys")
p.add_argument("-l", '--listkeyspaceinfo', action="store_true", help="list keyspace info")

args = p.parse_args()

if not os.path.exists(os.path.dirname(args.outputfile)):
    os.makedirs(os.path.dirname(args.outputfile))

logging.basicConfig(filename=args.outputfile,
                            filemode='a',
                            format='%(asctime)s,%(msecs)d %(name)s %(levelname)s %(message)s',
                            datefmt='%m/%d/%Y %H:%M:%S',
                            level=logging.DEBUG)

logging.info("Starting "+os.path.basename(__file__)+" with args - "+"Host:"+args.host+" Port:"+str(args.port)+" DB:"+str(args.db)+" IdleTime:"+str(args.idletime))

def percentage(part, whole):
    if whole == 0:
        percentage = 0        
    else:
        percentage = 100 * float(part)/float(whole)
    return str(percentage) + "%"

r = redis.Redis(host=args.host, port=args.port, password=args.password, db=args.db)

if args.listkeyspaceinfo:
    keyspaceinfo = r.info('keyspace')
    print("-l flag specified. Printing keyspace info and exiting")
    print("avg_ttl of 0 indicates that no expiration is set")
    print(json.dumps(keyspaceinfo, sort_keys=True, indent=4, default=str))
else:
    if args.remove:
        print ("-r flag has been specified. Keys will be removed")
    else:
        print ("-r flag not specified. No keys will be removed")

    try:
        total_key_count = 0
        deleted_key_count = 0
        for key in r.scan_iter("*"): #Using 'scan' vs 'keys'. 'Keys' is blocking, 'scan' is non-blocking.
            total_key_count +=1
            idle = r.object("idletime", key)#idle time is in seconds passed as arg. 432000 is 5 days
            if idle > args.idletime:
                deleted_key_count += 1
                old_keys.append(str(key).split(":")[0])
                if args.remove:
                    r.delete(key)
        print ("Bad keys per application")
        logging.info("Bad keys per application")
        print (json.dumps(Counter(old_keys)))
        logging.info(json.dumps(Counter(old_keys)))        
        print ("Percentage of keys with idle time greater than "+str(args.idletime)+" seconds: "+percentage(deleted_key_count, total_key_count))
        logging.info("Percentage of keys with idle time greater than "+str(args.idletime)+" seconds: "+percentage(deleted_key_count, total_key_count))       
        

    except KeyboardInterrupt:
        pass
