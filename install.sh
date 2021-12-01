#!/bin/bash

# docker run -it -v $PWD:/workspace -w /workspace teratut:0 show -json > out.json
# ./certs/generate.sh

LB=$(cat ./out.json | jq '.values.root_module.resources[] | select(.name=="lb") | .')
C1=$(cat ./out.json | jq '.values.root_module.resources[] | select(.name=="cntrl1") | .')
C2=$(cat ./out.json | jq '.values.root_module.resources[] | select(.name=="cntrl2") | .')
N1=$(cat ./out.json | jq '.values.root_module.resources[] | select(.name=="node1") | .')
N2=$(cat ./out.json | jq '.values.root_module.resources[] | select(.name=="node2") | .')

WORKER0_HOST=$(echo $N1 | jq  '.values.hostname' -r)
WORKER0_PUB_IP=$(echo $N1 | jq  '.values.network_interface[0].access_config[0].nat_ip' -r)
WORKER1_HOST=$(echo $N1 | jq  '.values.hostname' -r )
WORKER1_PUB_IP=$(echo $N1 | jq  '.values.network_interface[0].access_config[0].nat_ip' -r)
CTRL0_HOST=$(echo $C1 | jq  '.values.hostname' -r)
CTRL0_PUB_IP=$(echo $C1 | jq  '.values.network_interface[0].access_config[0].nat_ip' -r)
CTRL1_HOST=$(echo $C1 | jq  '.values.hostname' -r )
CTRL1_PUB_IP=$(echo $C1 | jq  '.values.network_interface[0].access_config[0].nat_ip' -r)
LB1_HOST=$(echo $LB | jq  '.values.hostname' -r )
LB1_PUB_IP=$(echo $LB | jq  '.values.network_interface[0].access_config[0].nat_ip' -r)

scp -o StrictHostKeyChecking=no -i ./ssh_key \
  ./certs/ca.pem \
  ./certs/$WORKER0_HOST-key.pem \
  ./certs/$WORKER0_HOST.pem \
  ubuntu@$WORKER0_PUB_IP:~/
scp -o StrictHostKeyChecking=no -i ./ssh_key \
  ./certs/ca.pem \
  ./certs/$WORKER1_HOST-key.pem \
  ./certs/$WORKER1_HOST.pem \
  ubuntu@$WORKER1_PUB_IP:~/

scp -o StrictHostKeyChecking=no -i ./ssh_key \
  ./certs/ca.pem \
  ./certs/ca-key.pem \
  ./certs/kubernetes-key.pem  \
  ./certs/kubernetes.pem \
  ./certs/service-account-key.pem \
  ./certs/service-account.pem  \
  ubuntu@$CTRL0_PUB_IP:~/

scp -o StrictHostKeyChecking=no -i ./ssh_key \
  ./certs/ca.pem \
  ./certs/ca-key.pem \
  ./certs/kubernetes-key.pem  \
  ./certs/kubernetes.pem \
  ./certs/service-account-key.pem \
  ./certs/service-account.pem  \
  ubuntu@$CTRL1_PUB_IP:~/
