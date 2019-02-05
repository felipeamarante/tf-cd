#!/bin/bash -xe
pwd
echo "pretty hacky, but ok"
sed -i '77s@.*@'"Hello from deployment $DEPLOYMENT_ID"'@' /var/www/html/index.html
