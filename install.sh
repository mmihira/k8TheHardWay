#!/bin/bash

function hurryup () {
    until ssh -o StrictHostKeyChecking=no -o ConnectTimeout=2 -i ./ssh_key "$1"@"$2" ls
        do sleep 1
    done
}

DIR="$( cd "$( dirname "$0" )" && pwd )"
ROOT=$(dirname $DIR)

docker run -it -v $PWD:/workspace -w /workspace k8thw:0.0 destroy -auto-approve
docker run -it -v $PWD:/workspace -w /workspace k8thw:0.0 apply -auto-approve
docker run -it -v $PWD:/workspace -w /workspace k8thw:0.0 show -json > out.json
echo "-----------------------------------------------------"
echo "Generating certs"
echo "-----------------------------------------------------"
./certs/generate.sh

echo "-----------------------------------------------------"
echo "Done generating certs"
echo "-----------------------------------------------------"

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

ssh-keygen -f "~/.ssh/known_hosts" -R $WORKER0_PUB_IP
ssh-keygen -f "~/.ssh/known_hosts" -R $WORKER1_PUB_IP
ssh-keygen -f "~/.ssh/known_hosts" -R $CTRL0_PUB_IP
ssh-keygen -f "~/.ssh/known_hosts" -R $CTRL1_PUB_IP

hurryup ubuntu $WORKER0_PUB_IP
hurryup ubuntu $WORKER1_PUB_IP
hurryup ubuntu $CTRL0_PUB_IP
hurryup ubuntu $CTRL1_PUB_IP

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

scp -o StrictHostKeyChecking=no -i ./../ssh_key \
  ./encryption-config.yaml \
  ubuntu@$CTRL0_PUB_IP:~/
scp -o StrictHostKeyChecking=no -i ./../ssh_key \
  ./encryption-config.yaml \
  ubuntu@$CTRL1_PUB_IP:~/

cd  $DIR
echo $PWD
ctrl0ssh="ssh -o StrictHostKeyChecking=no -i ./ssh_key ubuntu@$CTRL0_PUB_IP"
ctrl1ssh="ssh -o StrictHostKeyChecking=no -i ./ssh_key ubuntu@$CTRL1_PUB_IP"

$ctrl0ssh \
  sudo yum install wget -y
$ctrl1ssh \
  sudo yum install wget -y

$ctrl0ssh \
  wget -q --timestamping \
 "https://github.com/coreos/etcd/releases/download/v3.3.5/etcd-v3.3.5-linux-amd64.tar.gz"
$ctrl1ssh \
  wget -q --timestamping \
 "https://github.com/coreos/etcd/releases/download/v3.3.5/etcd-v3.3.5-linux-amd64.tar.gz"

$ctrl0ssh \
 tar -xvf etcd-v3.3.5-linux-amd64.tar.gz
$ctrl1ssh \
 tar -xvf etcd-v3.3.5-linux-amd64.tar.gz

$ctrl0ssh \
  sudo mv etcd-v3.3.5-linux-amd64/etcd* /usr/local/bin/
$ctrl1ssh \
  sudo mv etcd-v3.3.5-linux-amd64/etcd* /usr/local/bin/

$ctrl0ssh \
  sudo mkdir -p /etc/etcd /var/lib/etcd
$ctrl1ssh \
  sudo mkdir -p /etc/etcd /var/lib/etcd

$ctrl0ssh \
  sudo cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd
$ctrl1ssh \
  sudo cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd

ETCD_NAME0=$CTRL0_HOST
INTERNAL_IP0=$CTRL0_PRIV_IP
INITIAL_CLUSTER0=$CTRL0_HOST=https://$CTRL0_PRIV_IP:2380,$CTRL1_HOST=https://$CTRL1_PRIV_IP:2380

cat << EOF | tee ./etcd0.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos
[Service]
ExecStart=/usr/local/bin/etcd \\
 --name ${ETCD_NAME0} \\
 --cert-file=/etc/etcd/kubernetes.pem \\
 --key-file=/etc/etcd/kubernetes-key.pem \\
 --peer-cert-file=/etc/etcd/kubernetes.pem \\
 --peer-key-file=/etc/etcd/kubernetes-key.pem \\
 --trusted-ca-file=/etc/etcd/ca.pem \\
 --peer-trusted-ca-file=/etc/etcd/ca.pem \\
 --peer-client-cert-auth \\
 --client-cert-auth \\
 --initial-advertise-peer-urls https://${INTERNAL_IP0}:2380 \\
 --listen-peer-urls https://${INTERNAL_IP0}:2380 \\
 --listen-client-urls https://${INTERNAL_IP0}:2379,https://127.0.0.1:2379 \\
 --advertise-client-urls https://${INTERNAL_IP0}:2379 \\
 --initial-cluster-token etcd-cluster-0 \\
 --initial-cluster ${INITIAL_CLUSTER0} \\
 --initial-cluster-state new \\
 --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF

ETCD_NAME1=$CTRL1_HOST
INTERNAL_IP1=$CTRL1_PRIV_IP
INITIAL_CLUSTER1=$CTRL0_HOST=https://$CTRL0_PRIV_IP:2380,$CTRL1_HOST=https://$CTRL1_PRIV_IP:2380

scp -o StrictHostKeyChecking=no -i ./ssh_key \
  ./etcd0.service \
  ubuntu@$CTRL0_PUB_IP:~/

cat << EOF | tee ./etcd1.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos
[Service]
ExecStart=/usr/local/bin/etcd \\
 --name ${ETCD_NAME1} \\
 --cert-file=/etc/etcd/kubernetes.pem \\
 --key-file=/etc/etcd/kubernetes-key.pem \\
 --peer-cert-file=/etc/etcd/kubernetes.pem \\
 --peer-key-file=/etc/etcd/kubernetes-key.pem \\
 --trusted-ca-file=/etc/etcd/ca.pem \\
 --peer-trusted-ca-file=/etc/etcd/ca.pem \\
 --peer-client-cert-auth \\
 --client-cert-auth \\
 --initial-advertise-peer-urls https://${INTERNAL_IP1}:2380 \\
 --listen-peer-urls https://${INTERNAL_IP1}:2380 \\
 --listen-client-urls https://${INTERNAL_IP1}:2379,https://127.0.0.1:2379 \\
 --advertise-client-urls https://${INTERNAL_IP1}:2379 \\
 --initial-cluster-token etcd-cluster-0 \\
 --initial-cluster ${INITIAL_CLUSTER1} \\
 --initial-cluster-state new \\
 --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF

scp -o StrictHostKeyChecking=no -i ./ssh_key \
  ./etcd1.service \
  ubuntu@$CTRL1_PUB_IP:~/

$ctrl1ssh \
  sudo mv ./etcd1.service /etc/systemd/system/etcd.service
$ctrl0ssh \
  sudo mv ./etcd0.service /etc/systemd/system/etcd.service

$ctrl1ssh \
  sudo systemctl daemon-reload
$ctrl0ssh \
  sudo systemctl daemon-reload

$ctrl1ssh \
  sudo systemctl enable etcd
$ctrl0ssh \
  sudo systemctl enable etcd

$ctrl1ssh \
  sudo systemctl start etcd
$ctrl0ssh \
  sudo systemctl start etcd

