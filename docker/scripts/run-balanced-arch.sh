#Setting environment vars used by Docker runs
#Domain names are defined as <container_name>.<image_name>.$ENV.$DOMAIN_NAME
export ENV=demo
export DOMAIN_NAME=acme.com
export DNS_IP=`ifconfig docker0| grep 'inet '| cut -d: -f2| awk '{ print $2}'`

#Running Skydock (for DNS naming resolution)
docker run -d -p $DNS_IP:53:53/udp --name skydns crosbymichael/skydns -nameserver 8.8.8.8:53 -domain $DOMAIN_NAME
docker run -d -v /var/run/docker.sock:/docker.sock --name skydock crosbymichael/skydock -ttl 30 -environment $ENV -s /docker.sock -domain $DOMAIN_NAME -name skydns

sleep 3

#Running Data Container (data.busybox.demo.acme.com)
docker run --name data --dns $DNS_IP -v /var/lib/tomcat7/alf_data/contentstore -d busybox /bin/sh -c "chmod -R 777 /var/lib/tomcat7/alf_data/contentstore ; watch top"

#Running DB (db.mysql.demo.acme.com)
docker run -d --name db --dns $DNS_IP -e MYSQL_DATABASE="alfresco" -e MYSQL_USER="alfresco" -e MYSQL_PASSWORD="alfresco" orchardup/mysql

sleep 3

#Running Apache HTTP load-balancer (lb.apache-lb.demo.acme.com)
docker run --name lb --dns $DNS_IP -d -p 80:80 maoo/apache-lb:latest /bin/sh -c "/etc/init.d/apache2 start ; sleep 1 ; tail -f /var/log/apache2/error.log"

#Running 2 Alfresco Enterprise nodes  ([alf1|alf2].alf-precise.demo.acme.com)
docker run --name alf1 --dns $DNS_IP -d -p 8080:8080 -p 5701 -v /alfboxes/docker/license/alf42.lic:/alflicense/alf42.lic --volumes-from data maoo/alfresco-allinone-enterprise:latest /bin/sh -c "/etc/init.d/tomcat7 start ; sleep 1 ; tail -f /var/log/tomcat7/catalina.out"

#Alfresco needs some time to bootstrap db and contentstore
sleep 30

docker run --name alf2 --dns $DNS_IP -d -p 8081:8080 -p 5701 -v /alfboxes/docker/license/alf42.lic:/alflicense/alf42.lic --volumes-from data maoo/alfresco-allinone-enterprise:latest /bin/sh -c "/etc/init.d/tomcat7 start ; sleep 1 ; tail -f /var/log/tomcat7/catalina.out"
