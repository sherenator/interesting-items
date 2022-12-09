#Run this script on a squid proxy server to configure artifact hosting

#Hostname at which you intend to access artifacts
artifact_domain="artifacts.corp.io"
#Loopback address for the proxy server / address where nginx lives
proxy_server_name="localhost"


#Install nginx
	echo "yes" | yum install nginx

#backup default nginx config
	cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf-bak

#remove comments from nginx config
	sed -i '/^[ \t]*#/d' /etc/nginx/nginx.conf

#Add error logging and enable autoindex
	sed -i 's/server {/server {\n\tautoindex on;/g' /etc/nginx/nginx.conf

#Update '/' to '/artifacts/'. Using '#' as nonstandard sed delimmitter
	sed -i 's#location / {#location /artifacts/ {\n\t\tautoindex on;#g' /etc/nginx/nginx.conf

#Create required directories and set permissions
	mkdir /home/www-data/logs/ -p
	mkdir /usr/share/nginx/html/artifacts
	chmod 755 /home/www-data/logs/nginx_www.error.log
	chmod 755 /usr/share/nginx/html/artifacts

#Restart nginx
systemctl restart nginx

#Write perl script to file
cat <<EOF > /etc/squid/redirect_program.pl
#!/usr/bin/perl
use strict;
$| = 1;
while (<>) { 
    my @elems = split; # splits \$_ on whitespace by default  
    my \$url = \$elems[0]; 
    if (\$url =~ m#^http://$artifact_domain(/.*)?#i) {     
        \$url = "http://$proxy_server_name\${1}";    
        print "\$url\n";        
    }
    else {      
        print "\$url\n"; 
    }
}
EOF

#Set perl script to be executable and accessible
chmod 755 /etc/squid/redirect_program.pl


#Add URL rewrite directive to squid.conf
echo "url_rewrite_program /etc/squid/redirect_program.pl" >> /etc/squid/squid.conf

#restart squid
systemctl restart squid

#Host setup
#	To access artifacts on proxy connected hosts, update hosts file as follows:
#		echo "10.10.19.53    artifacts.corp.io" >> /etc/hosts
#	
#	In the example above, 10.10.19.53 is the squid proxy IP address
#	For a host to be "proxy connected" as mentioned above, run the following
#	
#	rm -rf /etc/profile.d/http_proxy.sh
#	sudo touch /etc/profile.d/http_proxy.sh
#	echo "export http_proxy=http://10.10.19.53:3128/" >> /etc/profile.d/http_proxy.sh






