#!/bin/sh

# In order to get ssh access to the instance
echo "${public_key}" >> ~/.ssh/authorized_keys

# https://docs.aws.amazon.com/codedeploy/latest/userguide/codedeploy-agent-operations-install-cli.html

# Amazon AMI
# sudo yum update
# sudo yum install -y ruby
# sudo yum install wget
# # https://docs.aws.amazon.com/codedeploy/latest/userguide/resource-kit.html#resource-kit-bucket-names
# wget https://${code_deploy_bucket_name}.s3.${code_deploy_region}.amazonaws.com/latest/install
# chmod +x ./install
# sudo ./install auto
# sudo service codedeploy-agent start

## Ubuntu
# export CODE_DEPLOY_VERSION=1.4.1-2244_all
export CODE_DEPLOY_VERSION=${code_deploy_agent_version}

sudo apt-get update
sudo apt-get install ruby-full ruby-webrick wget -y
cd /tmp
wget https://${code_deploy_bucket_name}.s3.${code_deploy_region}.amazonaws.com/releases/codedeploy-agent_$CODE_DEPLOY_VERSION.deb
mkdir codedeploy-agent_$CODE_DEPLOY_VERSION
dpkg-deb -R codedeploy-agent_$CODE_DEPLOY_VERSION.deb codedeploy-agent_$CODE_DEPLOY_VERSION
sed 's/Depends:.*/Depends:ruby3.0/' -i ./codedeploy-agent_$CODE_DEPLOY_VERSION/DEBIAN/control
dpkg-deb -b codedeploy-agent_$CODE_DEPLOY_VERSION/
sudo dpkg -i codedeploy-agent_$CODE_DEPLOY_VERSION.deb
sudo systemctl list-units --type=service | grep codedeploy
sudo service codedeploy-agent status
