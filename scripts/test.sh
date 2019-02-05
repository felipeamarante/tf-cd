#!/bin/bash -xe

yum -y install cowsay

cowsay hello from deployment group ${DEPLOYMENT_GROUP_NAME}

echo bye!
