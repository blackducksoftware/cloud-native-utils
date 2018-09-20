#!/bin/bash
yum update -y

function setup {
    yum install -y tmux git wget unzip
    yum install -y yum-utils
    rpm --import "https://sks-keyservers.net/pks/lookup?op=get&search=0xee6d536cf7dc86e2d7d56f59a178ac6c6238f52e"
    yum-config-manager --add-repo https://packages.docker.com/1.12/yum/repo/main/centos/7
    yum -y update
    yum -y install docker-engine-1.12.6.cs9-1.el7.centos
    systemctl start docker
    systemctl enable docker
}

function install-go {
    go_ver=1.9.2.linux-amd64
    wget -c https://storage.googleapis.com/golang/go${go_ver}.tar.gz
    tar -C /usr/local -xvzf go${go_ver}.tar.gz
    export PATH=$PATH:/usr/local/go/bin
    sudo ln -s /usr/local/go/bin/go /usr/bin/go
}

# TODO - Instead of retrieving the hard coded OpenShift origin client tool v3.7.0, 
#        need to build and install from the source, so that it can be used for any OpenShift build
function install-oc {
    oc_client_version=v3.7.0
    oc_client_full_version=openshift-origin-client-tools-v3.7.0-7ed6862-linux-64bit
    curl -sSL https://github.com/openshift/origin/releases/download/${oc_client_version}/${oc_client_full_version}.tar.gz -o oc-client.tar.gz
    tar -zxvf oc-client.tar.gz
    mv ${oc_client_full_version}/oc /usr/bin
    rm -rf oc-client.tar.gz
    echo "Installed OpenShift origin client tool version 3.7"
}

setup
install-go
install-oc

# Note this is somewhate EC2 specific, i.e. the metadata_endpoint Stuff !
sudo cat <<  EOF > /etc/docker/daemon.json
{
   "insecure-registries": [
     "172.30.0.0/16", "172.30.1.1:5000"
   ]
}
EOF

service docker restart

metadata_endpoint="http://169.254.169.254/latest/meta-data"
public_ip=$(curl ${metadata_endpoint}/public-ipv4)
public_hostname=$(curl ${metadata_endpoint}/public-hostname)

# Spin up the OpenShift cluster
oc cluster up --public-hostname="${public_hostname}" --routing-suffix="${public_ip}.xip.io" --skip-registry-check=true

# Add cluster admin role to the admin user
oc login -u admin -p admin
oc adm policy add-cluster-role-to-user cluster-admin admin --config=/var/lib/origin/openshift.local.config/master/admin.kubeconfig

ifconfig docker0 promisc
