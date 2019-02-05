#!/bin/bash -xe


## Running this mambo jambo first ##

yum -y install httpd
chkconfig httpd on
echo "HELLO, NO DEPLOYMENTS WERE DONE YET"  >> /var/www/html/index.html
service httpd start


## Code Deploy Setup One liner ##

#DEP - jq ruby2.0

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
AUTOUPDATE=false

function installdep(){

if [ ${PLAT} = "ubuntu" ]; then

  apt-get -y update
  # Satisfying even ubuntu older versions.
  apt-get -y install jq awscli ruby2.0 || apt-get -y install jq awscli ruby



elif [ ${PLAT} = "amz" ]; then
  yum -y update
  yum install -y aws-cli ruby jq

fi

}

function platformize(){

#Rudimentar OS detection, please let me know if you have a better one#
 if hash lsb_release; then
   echo "Ubuntu Server OS detected"
   export PLAT="ubuntu"


elif hash yum; then
  echo "Amz Linux detected"
  export PLAT="amz"

 else
   echo "Unsupported Release"
   exit 1

 fi
}


function execute(){

if [ ${PLAT} = "ubuntu" ]; then

  cd /tmp/
  wget https://aws-codedeploy-${REGION}.s3.amazonaws.com/latest/install
  chmod +x ./install

  if ./install auto; then
    echo "Instalation Completed"
      if ! ${AUTOUPDATE}; then
            echo "Disabling Auto Update"
            sed -i '/@reboot/d' /etc/cron.d/codedeploy-agent-update
            chattr +i /etc/cron.d/codedeploy-agent-update
            rm -f /tmp/install
      fi
    exit 0
  else
    echo "Instalation Script Failed, please investigate"
    rm -f /tmp/install
    exit 1
  fi

elif [ ${PLAT} = "amz" ]; then

  cd /tmp/
  wget https://aws-codedeploy-${REGION}.s3.amazonaws.com/latest/install
  chmod +x ./install

    if ./install auto; then
      echo "Instalation Completed"
        if ! ${AUTOUPDATE}; then
            echo "Disabling Auto Update"
            sed -i '/@reboot/d' /etc/cron.d/codedeploy-agent-update
            chattr +i /etc/cron.d/codedeploy-agent-update
            rm -f /tmp/install
        fi
      exit 0
    else
      echo "Instalation Script Failed, please investigate"
      rm -f /tmp/install
      exit 1
    fi

else
  echo "Unsupported Platform ''${PLAT}''"
fi

}

platformize
installdep
REGION=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r ".region")
execute
