#!/bin/bash -xe


## Running this mambo jambo first ##

yum -y install httpd
chkconfig httpd on
echo "HELLO, NO DEPLOYMENTS WERE DONE YET"  >> /var/www/html/index.html
service httpd start
