#!/bin/bash

DIR="$( cd "$( dirname "$0" )" && pwd )"
ROOT=$(dirname $DIR)
source $DIR/var.sh

KUBERNETES_ADDRESS=$LB1_PRIV_IP
instances=("$WORKER0_HOST" "$WORKER1_HOST")

echo "Creating kubeconfig files"
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


echo "Copying kube configs to servers"
scp -o StrictHostKeyChecking=no -i ../ssh_key \
  ./$WORKER0_HOST.kubeconfig \
  ./kube-proxy.kubeconfig \
  ubuntu@$WORKER0_PUB_IP:~/

scp -o StrictHostKeyChecking=no -i ../ssh_key \
  ./$WORKER1_HOST.kubeconfig \
  ./kube-proxy.kubeconfig \
  ubuntu@$WORKER1_PUB_IP:~/

scp -o StrictHostKeyChecking=no -i ../ssh_key \
  ./admin.kubeconfig \
  ./kube-controller-manager.kubeconfig \
  ./kube-scheduler.kubeconfig \
  ubuntu@$CTRL0_PUB_IP:~/

scp -o StrictHostKeyChecking=no -i ../ssh_key \
  ./admin.kubeconfig \
  ./kube-controller-manager.kubeconfig \
  ./kube-scheduler.kubeconfig \
  ubuntu@$CTRL1_PUB_IP:~/

echo "Generating encryption-config"
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
cat > encryption-config.yaml << EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF

scp -o StrictHostKeyChecking=no -i ../ssh_key \
  ./encryption-config.yaml \
  ubuntu@$CTRL0_PUB_IP:~/
scp -o StrictHostKeyChecking=no -i ../ssh_key \
  ./encryption-config.yaml \
  ubuntu@$CTRL1_PUB_IP:~/

cd -

