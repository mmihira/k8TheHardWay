#!/bin/bash

DIR="$( cd "$( dirname "$0" )" && pwd )"
ROOT=$(dirname $DIR)
source $DIR/var.sh

echo "Copying certs to worker 0"
scp -o StrictHostKeyChecking=no -i ./ssh_key \
  ./certs/ca.pem \
  ./certs/$WORKER0_HOST-key.pem \
  ./certs/$WORKER0_HOST.pem \
  ./certs/$WORKER0_HOST.kubeconfig \
  ubuntu@$WORKER0_PUB_IP:~/

echo "Copying certs to worker 1"
scp -o StrictHostKeyChecking=no -i ./ssh_key \
  ./certs/ca.pem \
  ./certs/$WORKER1_HOST-key.pem \
  ./certs/$WORKER1_HOST.pem \
  ./certs/$WORKER1_HOST.kubeconfig \
  ubuntu@$WORKER1_PUB_IP:~/

echo "Copying certs to controller 0"
scp -o StrictHostKeyChecking=no -i ./ssh_key \
  ./certs/ca.pem \
  ./certs/ca-key.pem \
  ./certs/kubernetes-key.pem  \
  ./certs/kubernetes.pem \
  ./certs/service-account-key.pem \
  ./certs/service-account.pem  \
  ubuntu@$CTRL0_PUB_IP:~/

echo "Copying certs to controller 1"
scp -o StrictHostKeyChecking=no -i ./ssh_key \
  ./certs/ca.pem \
  ./certs/ca-key.pem \
  ./certs/kubernetes-key.pem  \
  ./certs/kubernetes.pem \
  ./certs/service-account-key.pem \
  ./certs/service-account.pem  \
  ubuntu@$CTRL1_PUB_IP:~/
