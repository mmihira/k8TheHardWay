#!/bin/bash

DIR="$( cd "$( dirname "$0" )" && pwd )"
ROOT=$(dirname $DIR)
source $DIR/var.sh

$lbssh sudo yum install -y nginx
$lbssh sudo systemctl enable nginx
$lbssh sudo mkdir -p /etc/nginx/tcpconf.d
$lbssh sudo yum -y install nginx-mod-stream

cat << EOF | tee ./nginx-lb-kubernetes.conf
stream {
  upstream kubernetes {
    server $CTRL0_PRIV_IP:6443;
    server $CTRL1_PRIV_IP:6443;
  }
  server {
    listen 6443;
    listen 443;
    proxy_pass kubernetes;
  }
}


http {
    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 4096;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    # Load modular configuration files from the /etc/nginx/conf.d directory.
    # See http://nginx.org/en/docs/ngx_core_module.html#include
    # for more information.
    include /etc/nginx/conf.d/*.conf;

    server {
        listen       80;
        listen       [::]:80;
        server_name  _;
        root         /usr/share/nginx/html;

        # Load configuration files for the default server block.
        include /etc/nginx/default.d/*.conf;

        error_page 404 /404.html;
        location = /404.html {
        }

        error_page 500 502 503 504 /50x.html;
        location = /50x.html {
        }
    }
}
EOF

scp -o StrictHostKeyChecking=no -i ./ssh_key \
  ./nginx-lb-kubernetes.conf \
  ubuntu@$LB1_PUB_IP:~/

scp -o StrictHostKeyChecking=no -i ./ssh_key \
  ./nginx.conf \
  ubuntu@$LB1_PUB_IP:~/
$lbssh sudo mv ./nginx.conf /etc/nginx/nginx.conf
$lbssh sudo mv ./nginx-lb-kubernetes.conf /etc/nginx/tcpconf.d/kubernetes.conf
$lbssh sudo nginx

rm ./nginx-lb-kubernetes.conf

echo "Install docker on loadbalancer"

scp -o StrictHostKeyChecking=no -i ./ssh_key \
  ./docker/remote_docker_install.sh \
  ubuntu@$LB1_PUB_IP:~/
scp -o StrictHostKeyChecking=no -i ./ssh_key \
  ./docker/remote_compose_install.sh \
  ubuntu@$LB1_PUB_IP:~/
$lbssh ./remote_docker_install.sh
$lbssh ./remote_compose_install.sh
$lbssh sudo service docker start
$lbssh sudo docker info


