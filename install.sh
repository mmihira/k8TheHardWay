#!/bin/bash

docker run -it -v $PWD:/workspace -w /workspace k8thw:0.0 destroy -auto-approve
docker run -it -v $PWD:/workspace -w /workspace k8thw:0.0 apply -auto-approve
docker run -it -v $PWD:/workspace -w /workspace k8thw:0.0 show -json > out.json
./certs/generate.sh

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
LB1_PRIV_IP=$(echo $LB | jq  '.values.network_interface[0].network_ip' -r)

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

KUBERNETES_ADDRESS=$LB1_PRIV_IP
instances=("$WORKER0_HOST" "$WORKER1_HOST")

cd ./certs
kctl="docker run -it -v $PWD:/workspace -w /workspace --user $(id -u):$(id -g) k8kc:0.0"
for instance in ${instances[@]}; do
  docker run -it -v $PWD:/workspace -w /workspace --user $(id -u):$(id -g) k8kc:0.0 config set-cluster kubernetes-the-hard-way \
    --certificate-authority=./ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_ADDRESS}:6443 \
    --kubeconfig=${instance}.kubeconfig

  docker run -it -v $PWD:/workspace -w /workspace --user $(id -u):$(id -g) k8kc:0.0 config set-credentials system:node:${instance} \
    --client-certificate=./${instance}.pem \
    --client-key=./${instance}-key.pem \
    --embed-certs=true \
    --kubeconfig=${instance}.kubeconfig

  docker run -it -v $PWD:/workspace -w /workspace --user $(id -u):$(id -g) k8kc:0.0 config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:node:${instance} \
    --kubeconfig=${instance}.kubeconfig

docker run -it -v $PWD:/workspace -w /workspace --user $(id -u):$(id -g) k8kc:0.0 config use-context default --kubeconfig=${instance}.kubeconfig
done

$kctl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://${KUBERNETES_ADDRESS}:6443 \
  --kubeconfig=kube-proxy.kubeconfig
$kctl config set-credentials system:kube-proxy \
  --client-certificate=kube-proxy.pem \
  --client-key=kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-proxy.kubeconfig
$kctl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig
$kctl config use-context default --kubeconfig=kube-proxy.kubeconfig

$kctl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=kube-controller-manager.kubeconfig
$kctl config set-credentials system:kube-controller-manager \
  --client-certificate=kube-controller-manager.pem \
  --client-key=kube-controller-manager-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-controller-manager.kubeconfig
$kctl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-controller-manager \
  --kubeconfig=kube-controller-manager.kubeconfig
$kctl config use-context default --kubeconfig=kube-controller-manager.kubeconfig

$kctl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=kube-scheduler.kubeconfig
$kctl config set-credentials system:kube-scheduler \
  --client-certificate=kube-scheduler.pem \
  --client-key=kube-scheduler-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-scheduler.kubeconfig
$kctl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-scheduler \
  --kubeconfig=kube-scheduler.kubeconfig
$kctl config use-context default --kubeconfig=kube-scheduler.kubeconfig

$kctl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=admin.kubeconfig
$kctl config set-credentials admin \
  --client-certificate=admin.pem \
  --client-key=admin-key.pem \
  --embed-certs=true \
  --kubeconfig=admin.kubeconfig
$kctl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=admin \
  --kubeconfig=admin.kubeconfig
$kctl config use-context default --kubeconfig=admin.kubeconfig

scp -o StrictHostKeyChecking=no -i ./../ssh_key \
  ./$WORKER0_HOST-kubeconfig \
  ./kube-proxy.kubeconfig \
  ubuntu@$WORKER0_PUB_IP:~/

scp -o StrictHostKeyChecking=no -i ./../ssh_key \
  ./$WORKER1_HOST-kubeconfig \
  ./kube-proxy.kubeconfig \
  ubuntu@$WORKER1_PUB_IP:~/

scp -o StrictHostKeyChecking=no -i ./../ssh_key \
  ./admin.kubeconfig \
  ./kube-controller-manager.kubeconfig \
  ./kube-scheduler.kubeconfig \
  ubuntu@$CTRL0_PUB_IP:~/

scp -o StrictHostKeyChecking=no -i ./../ssh_key \
  ./admin.kubeconfig \
  ./kube-controller-manager.kubeconfig \
  ./kube-scheduler.kubeconfig \
  ubuntu@$CTRL1_PUB_IP:~/
