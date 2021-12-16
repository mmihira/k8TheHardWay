#!/bin/bash

DIR="$( cd "$( dirname "$0" )" && pwd )"
ROOT=$(dirname $DIR)


LB=$(cat ./out.json | jq '.values.root_module.resources[] | select(.name=="lb") | .')
C1=$(cat ./out.json | jq '.values.root_module.resources[] | select(.name=="cntrl1") | .')
C2=$(cat ./out.json | jq '.values.root_module.resources[] | select(.name=="cntrl2") | .')
N1=$(cat ./out.json | jq '.values.root_module.resources[] | select(.name=="node1") | .')
N2=$(cat ./out.json | jq '.values.root_module.resources[] | select(.name=="node2") | .')

WORKER0_HOST=$(echo $N1 | jq  '.values.name' -r)
WORKER0_PUB_IP=$(echo $N1 | jq  '.values.network_interface[0].access_config[0].nat_ip' -r)
WORKER0_PRIV_IP=$(echo $N1 | jq  '.values.network_interface[0].network_ip' -r)
WORKER1_HOST=$(echo $N2 | jq  '.values.name' -r )
WORKER1_PUB_IP=$(echo $N2 | jq  '.values.network_interface[0].access_config[0].nat_ip' -r)
WORKER1_PRIV_PUB_IP=$(echo $N2 | jq  '.values.network_interface[0].network_ip' -r)
CTRL0_HOST=$(echo $C1 | jq  '.values.name' -r)
CTRL0_PUB_IP=$(echo $C1 | jq  '.values.network_interface[0].access_config[0].nat_ip' -r)
CTRL0_PRIV_IP=$(echo $C1 | jq  '.values.network_interface[0].network_ip' -r)
CTRL1_HOST=$(echo $C2 | jq  '.values.name' -r )
CTRL1_PUB_IP=$(echo $C2 | jq  '.values.network_interface[0].access_config[0].nat_ip' -r)
CTRL1_PRIV_IP=$(echo $C2 | jq  '.values.network_interface[0].network_ip' -r)
LB1_HOST=$(echo $LB | jq  '.values.name' -r )
LB1_PUB_IP=$(echo $LB | jq  '.values.network_interface[0].access_config[0].nat_ip' -r)
LB1_PRIV_IP=$(echo $LB | jq  '.values.network_interface[0].network_ip' -r)

ssh -o StrictHostKeyChecking=no -i ./ssh_key ubuntu@$WORKER0_PUB_IP
