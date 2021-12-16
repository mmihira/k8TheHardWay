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

ctrl0ssh="ssh -o StrictHostKeyChecking=no -i ./ssh_key ubuntu@$CTRL0_PUB_IP"
ctrl1ssh="ssh -o StrictHostKeyChecking=no -i ./ssh_key ubuntu@$CTRL1_PUB_IP"
lbssh="ssh -o StrictHostKeyChecking=no -i ./ssh_key ubuntu@$LB1_PUB_IP"
w0ssh="ssh -o StrictHostKeyChecking=no -i ./ssh_key ubuntu@$WORKER0_PUB_IP"
w1ssh="ssh -o StrictHostKeyChecking=no -i ./ssh_key ubuntu@$WORKER1_PUB_IP"

ssh-keygen -f ~/.ssh/known_hosts -R $WORKER0_PUB_IP
ssh-keygen -f ~/.ssh/known_hosts -R $WORKER1_PUB_IP
ssh-keygen -f ~/.ssh/known_hosts -R $CTRL0_PUB_IP
ssh-keygen -f ~/.ssh/known_hosts -R $CTRL1_PUB_IP
ssh-keygen -f ~/.ssh/known_hosts -R $LB1_PUB_IP

hurryup ubuntu $WORKER0_PUB_IP
hurryup ubuntu $WORKER1_PUB_IP
hurryup ubuntu $CTRL0_PUB_IP
hurryup ubuntu $CTRL1_PUB_IP
hurryup ubuntu $LB1_PUB_IP

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
scp -o StrictHostKeyChecking=no -i $DIR/ssh_key \
  ./$WORKER0_HOST.kubeconfig \
  ./kube-proxy.kubeconfig \
  ubuntu@$WORKER0_PUB_IP:~/

scp -o StrictHostKeyChecking=no -i $DIR/ssh_key \
  ./$WORKER1_HOST.kubeconfig \
  ./kube-proxy.kubeconfig \
  ubuntu@$WORKER1_PUB_IP:~/

scp -o StrictHostKeyChecking=no -i $DIR/ssh_key \
  ./admin.kubeconfig \
  ./kube-controller-manager.kubeconfig \
  ./kube-scheduler.kubeconfig \
  ubuntu@$CTRL0_PUB_IP:~/

scp -o StrictHostKeyChecking=no -i $DIR/ssh_key \
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

scp -o StrictHostKeyChecking=no -i ./../ssh_key \
  ./encryption-config.yaml \
  ubuntu@$CTRL0_PUB_IP:~/
scp -o StrictHostKeyChecking=no -i ./../ssh_key \
  ./encryption-config.yaml \
  ubuntu@$CTRL1_PUB_IP:~/

cd  $DIR
echo $PWD

echo "-----------------------------------------------------"
echo "Installing etcd"
echo "-----------------------------------------------------"

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

echo "-----------------------------------------------------"
echo "Installing control plane"
echo "-----------------------------------------------------"

scp -o StrictHostKeyChecking=no -i ./ssh_key \
  ./sdstatus.sh \
  ubuntu@$CTRL1_PUB_IP:~/

scp -o StrictHostKeyChecking=no -i ./ssh_key \
  ./sdstatus.sh \
  ubuntu@$CTRL0_PUB_IP:~/

$ctrl1ssh \
  chmod u+x ./sdstatus.sh
$ctrl0ssh \
  chmod u+x ./sdstatus.sh

$ctrl1ssh sudo mkdir -p /etc/kubernetes/config

$ctrl0ssh sudo mkdir -p /etc/kubernetes/config

$ctrl1ssh wget -q --timestamping \
  "https://storage.googleapis.com/kubernetes-release/release/v1.10.2/bin/linux/amd64/kube-apiserver"
$ctrl1ssh wget -q --timestamping \
  "https://storage.googleapis.com/kubernetes-release/release/v1.10.2/bin/linux/amd64/kube-controller-manager"
$ctrl1ssh wget -q --timestamping \
  "https://storage.googleapis.com/kubernetes-release/release/v1.10.2/bin/linux/amd64/kube-scheduler"
$ctrl1ssh wget -q --timestamping \
  "https://storage.googleapis.com/kubernetes-release/release/v1.10.2/bin/linux/amd64/kubectl"

$ctrl0ssh wget -q --timestamping \
  "https://storage.googleapis.com/kubernetes-release/release/v1.10.2/bin/linux/amd64/kube-apiserver"
$ctrl0ssh wget -q --timestamping \
  "https://storage.googleapis.com/kubernetes-release/release/v1.10.2/bin/linux/amd64/kube-controller-manager"
$ctrl0ssh wget -q --timestamping \
  "https://storage.googleapis.com/kubernetes-release/release/v1.10.2/bin/linux/amd64/kube-scheduler"
$ctrl0ssh wget -q --timestamping \
  "https://storage.googleapis.com/kubernetes-release/release/v1.10.2/bin/linux/amd64/kubectl"

$ctrl1ssh \
  chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl
$ctrl0ssh \
  chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl

$ctrl1ssh \
  sudo mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/local/bin/
$ctrl0ssh \
  sudo mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/local/bin/

$ctrl1ssh sudo mkdir -p /var/lib/kubernetes/
$ctrl1ssh sudo cp ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
 service-account-key.pem service-account.pem \
 encryption-config.yaml /var/lib/kubernetes/

$ctrl0ssh sudo mkdir -p /var/lib/kubernetes/
$ctrl0ssh sudo cp ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
 service-account-key.pem service-account.pem \
 encryption-config.yaml /var/lib/kubernetes/

echo "-----------------------------------------------------"
echo "Setting up kube api service"
echo "-----------------------------------------------------"

INTERNAL_IP0=$CTRL0_PRIV_IP
INTERNAL_IP1=$CTRL1_PRIV_IP
CONTROLLER0_IP=$CTRL0_PRIV_IP
CONTROLLER1_IP=$CTRL1_PRIV_IP

cat << EOF | tee ./kube-apiserver0.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes
[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=${INTERNAL_IP0} \\
  --allow-privileged=true \\
  --apiserver-count=3 \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\
  --enable-admission-plugins=Initializers,NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --enable-swagger-ui=true \\
  --etcd-cafile=/var/lib/kubernetes/ca.pem \\
  --etcd-certfile=/var/lib/kubernetes/kubernetes.pem \\
  --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem \\
  --etcd-servers=https://$CONTROLLER0_IP:2379,https://$CONTROLLER1_IP:2379 \\
  --event-ttl=1h \\
  --experimental-encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\
  --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\
  --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\
  --kubelet-https=true \\
  --runtime-config=api/all \\
  --service-account-key-file=/var/lib/kubernetes/service-account.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
  --v=2 \\
  --kubelet-preferred-address-types=InternalIP,InternalDNS,Hostname,ExternalIP,ExternalDNS
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF

cat << EOF | tee ./kube-apiserver1.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes
[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=${INTERNAL_IP1} \\
  --allow-privileged=true \\
  --apiserver-count=3 \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\
  --enable-admission-plugins=Initializers,NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --enable-swagger-ui=true \\
  --etcd-cafile=/var/lib/kubernetes/ca.pem \\
  --etcd-certfile=/var/lib/kubernetes/kubernetes.pem \\
  --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem \\
  --etcd-servers=https://$CONTROLLER0_IP:2379,https://$CONTROLLER1_IP:2379 \\
  --event-ttl=1h \\
  --experimental-encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\
  --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\
  --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\
  --kubelet-https=true \\
  --runtime-config=api/all \\
  --service-account-key-file=/var/lib/kubernetes/service-account.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
  --v=2 \\
  --kubelet-preferred-address-types=InternalIP,InternalDNS,Hostname,ExternalIP,ExternalDNS
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF

scp -o StrictHostKeyChecking=no -i ./ssh_key \
  ./kube-apiserver0.service \
  ubuntu@$CTRL0_PUB_IP:~/

scp -o StrictHostKeyChecking=no -i ./ssh_key \
  ./kube-apiserver1.service \
  ubuntu@$CTRL1_PUB_IP:~/

$ctrl0ssh \
  sudo mv ./kube-apiserver0.service /etc/systemd/system/kube-apiserver.service
$ctrl1ssh \
  sudo mv ./kube-apiserver1.service /etc/systemd/system/kube-apiserver.service

echo "-----------------------------------------------------"
echo "Setting up control manager"
echo "-----------------------------------------------------"

$ctrl0ssh \
sudo cp kube-controller-manager.kubeconfig /var/lib/kubernetes/

$ctrl1ssh \
sudo cp kube-controller-manager.kubeconfig /var/lib/kubernetes/

cat << EOF | tee ./kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes
[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --address=0.0.0.0 \\
  --cluster-cidr=10.200.0.0/16 \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \\
  --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \\
  --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
  --leader-elect=true \\
  --root-ca-file=/var/lib/kubernetes/ca.pem \\
  --service-account-private-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --use-service-account-credentials=true \\
  --v=2
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF

scp -o StrictHostKeyChecking=no -i ./ssh_key \
  ./kube-controller-manager.service \
  ubuntu@$CTRL0_PUB_IP:~/

scp -o StrictHostKeyChecking=no -i ./ssh_key \
  ./kube-controller-manager.service \
  ubuntu@$CTRL1_PUB_IP:~/

$ctrl0ssh \
sudo cp kube-controller-manager.service /etc/systemd/system/kube-controller-manager.service

$ctrl1ssh \
sudo cp kube-controller-manager.service /etc/systemd/system/kube-controller-manager.service

echo "-----------------------------------------------------"
echo "Setting up kube scheduler"
echo "-----------------------------------------------------"

$ctrl0ssh \
sudo cp kube-scheduler.kubeconfig /var/lib/kubernetes/

$ctrl1ssh \
sudo cp kube-scheduler.kubeconfig /var/lib/kubernetes/

cat << EOF | tee ./kube-scheduler.yaml
apiVersion: componentconfig/v1alpha1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: "/var/lib/kubernetes/kube-scheduler.kubeconfig"
leaderElection:
  leaderElect: true
EOF

scp -o StrictHostKeyChecking=no -i ./ssh_key \
  ./kube-scheduler.yaml \
  ubuntu@$CTRL0_PUB_IP:~/

scp -o StrictHostKeyChecking=no -i ./ssh_key \
  ./kube-scheduler.yaml \
  ubuntu@$CTRL1_PUB_IP:~/

$ctrl0ssh \
sudo cp kube-scheduler.yaml /etc/kubernetes/config/kube-scheduler.yaml

$ctrl1ssh \
sudo cp kube-scheduler.yaml /etc/kubernetes/config/kube-scheduler.yaml

cat << EOF | tee ./kube-scheduler.service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --config=/etc/kubernetes/config/kube-scheduler.yaml \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

scp -o StrictHostKeyChecking=no -i ./ssh_key \
  ./kube-scheduler.service \
  ubuntu@$CTRL0_PUB_IP:~/

scp -o StrictHostKeyChecking=no -i ./ssh_key \
  ./kube-scheduler.service \
  ubuntu@$CTRL1_PUB_IP:~/

$ctrl0ssh \
sudo cp kube-scheduler.service /etc/systemd/system/kube-scheduler.service

$ctrl1ssh \
sudo cp kube-scheduler.service /etc/systemd/system/kube-scheduler.service

$ctrl0ssh \
sudo systemctl daemon-reload
$ctrl0ssh \
sudo systemctl enable kube-apiserver kube-controller-manager kube-scheduler
$ctrl0ssh \
sudo systemctl start kube-apiserver kube-controller-manager kube-scheduler

$ctrl1ssh \
sudo systemctl daemon-reload
$ctrl1ssh \
sudo systemctl enable kube-apiserver kube-controller-manager kube-scheduler
$ctrl1ssh \
sudo systemctl start kube-apiserver kube-controller-manager kube-scheduler

$ctrl0ssh \
sudo systemctl status kube-apiserver kube-controller-manager kube-scheduler

$ctrl1ssh \
sudo systemctl status kube-apiserver kube-controller-manager kube-scheduler

$ctrl0ssh \
  kubectl get componentstatuses --kubeconfig admin.kubeconfig

$ctrl1ssh \
  kubectl get componentstatuses --kubeconfig admin.kubeconfig

echo "-----------------------------------------------------"
echo "Setting up RBAC"
echo "-----------------------------------------------------"

scp -o StrictHostKeyChecking=no -i ./ssh_key \
  ./rbac.sh \
  ubuntu@$CTRL0_PUB_IP:~/

$ctrl0ssh ./rbac.sh

echo "-----------------------------------------------------"
echo "Setting up Load Balancer"
echo "-----------------------------------------------------"

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

echo "-----------------------------------------------------"
echo "Settup worker nodes"
echo "-----------------------------------------------------"

$w0ssh sudo yum -y install wget socat conntrack ipset
$w1ssh sudo yum -y install wget socat conntrack ipset

echo "Downloading worker 0 binaries"
$w0ssh wget -q --timestamping \
 https://github.com/kubernetes-incubator/cri-tools/releases/download/v1.0.0-beta.0/crictl-v1.0.0-beta.0-linux-amd64.tar.gz \
 https://storage.googleapis.com/kubernetes-the-hard-way/runsc \
 https://github.com/opencontainers/runc/releases/download/v1.0.0-rc5/runc.amd64 \
 https://github.com/containernetworking/plugins/releases/download/v0.6.0/cni-plugins-amd64-v0.6.0.tgz \
 https://github.com/containerd/containerd/releases/download/v1.1.0/containerd-1.1.0.linux-amd64.tar.gz \
 https://storage.googleapis.com/kubernetes-release/release/v1.10.2/bin/linux/amd64/kubectl \
 https://storage.googleapis.com/kubernetes-release/release/v1.10.2/bin/linux/amd64/kube-proxy \
 https://storage.googleapis.com/kubernetes-release/release/v1.10.2/bin/linux/amd64/kubelet
echo "Done"

echo "Downloading worker 1 binaries"
$w1ssh wget -q --timestamping \
 https://github.com/kubernetes-incubator/cri-tools/releases/download/v1.0.0-beta.0/crictl-v1.0.0-beta.0-linux-amd64.tar.gz \
 https://storage.googleapis.com/kubernetes-the-hard-way/runsc \
 https://github.com/opencontainers/runc/releases/download/v1.0.0-rc5/runc.amd64 \
 https://github.com/containernetworking/plugins/releases/download/v0.6.0/cni-plugins-amd64-v0.6.0.tgz \
 https://github.com/containerd/containerd/releases/download/v1.1.0/containerd-1.1.0.linux-amd64.tar.gz \
 https://storage.googleapis.com/kubernetes-release/release/v1.10.2/bin/linux/amd64/kubectl \
 https://storage.googleapis.com/kubernetes-release/release/v1.10.2/bin/linux/amd64/kube-proxy \
 https://storage.googleapis.com/kubernetes-release/release/v1.10.2/bin/linux/amd64/kubelet
echo "Done"

$w0ssh sudo mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes

$w0ssh sudo mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes

$w0ssh chmod +x kubectl kube-proxy kubelet runc.amd64 runsc
$w0ssh sudo mv runc.amd64 runc
$w0ssh sudo mv kubectl kube-proxy kubelet runc runsc /usr/local/bin/
$w0ssh sudo tar -xvf crictl-v1.0.0-beta.0-linux-amd64.tar.gz -C /usr/local/bin/
$w0ssh sudo tar -xvf cni-plugins-amd64-v0.6.0.tgz -C /opt/cni/bin/
$w0ssh sudo tar -xvf containerd-1.1.0.linux-amd64.tar.gz -C /bin/

$w1ssh sudo mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes

$w1ssh sudo mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes

$w1ssh chmod +x kubectl kube-proxy kubelet runc.amd64 runsc
$w1ssh sudo mv runc.amd64 runc
$w1ssh sudo mv kubectl kube-proxy kubelet runc runsc /usr/local/bin/
$w1ssh sudo tar -xvf crictl-v1.0.0-beta.0-linux-amd64.tar.gz -C /usr/local/bin/
$w1ssh sudo tar -xvf cni-plugins-amd64-v0.6.0.tgz -C /opt/cni/bin/
$w1ssh sudo tar -xvf containerd-1.1.0.linux-amd64.tar.gz -C /bin/

echo "Configuring containerd"
$w0ssh sudo mkdir -p /etc/containerd/
$w1ssh sudo mkdir -p /etc/containerd/

scp -o StrictHostKeyChecking=no -i ./ssh_key \
  ./containerd/config.toml \
  ubuntu@$WORKER0_PUB_IP:~/
$w0ssh sudo mv config.toml /etc/containerd/config.toml

scp -o StrictHostKeyChecking=no -i ./ssh_key \
  ./containerd/containerd.service \
  ubuntu@$WORKER0_PUB_IP:~/
$w0ssh sudo mv containerd.service /etc/systemd/system/containerd.service

scp -o StrictHostKeyChecking=no -i ./ssh_key \
  ./containerd/config.toml \
  ubuntu@$WORKER1_PUB_IP:~/
$w1ssh sudo mv config.toml /etc/containerd/config.toml

scp -o StrictHostKeyChecking=no -i ./ssh_key \
  ./containerd/containerd.service \
  ubuntu@$WORKER1_PUB_IP:~/
$w1ssh sudo mv containerd.service /etc/systemd/system/containerd.service

$w0ssh sudo mv "$WORKER0_HOST-key.pem" "$WORKER0_HOST.pem" /var/lib/kubelet/
$w0ssh sudo mv "$WORKER0_HOST.kubeconfig" /var/lib/kubelet/kubeconfig
$w0ssh sudo mv ca.pem /var/lib/kubernetes/

$w1ssh sudo mv "$WORKER1_HOST-key.pem" "$WORKER1_HOST.pem" /var/lib/kubelet/
$w1ssh sudo mv "$WORKER1_HOST.kubeconfig" /var/lib/kubelet/kubeconfig
$w1ssh sudo mv ca.pem /var/lib/kubernetes/

cat << EOF | tee ./kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubernetes/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "10.32.0.10"
runtimeRequestTimeout: "15m"
tlsCertFile: "/var/lib/kubelet/${WORKER0_HOST}.pem"
tlsPrivateKeyFile: "/var/lib/kubelet/${WORKER0_HOST}-key.pem"
EOF

cat << EOF | tee ./kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --container-runtime=remote \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --network-plugin=cni \\
  --register-node=true \\
  --v=2 \\
  --hostname-override=${WORKER0_HOST} \\
  --allow-privileged=true
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF

scp -o StrictHostKeyChecking=no -i ./ssh_key \
  ./kublet-config.yaml \
  ./kublet.service \
  ubuntu@$WORKER0_PUB_IP:~/

cat << EOF | tee ./kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubernetes/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "10.32.0.10"
runtimeRequestTimeout: "15m"
tlsCertFile: "/var/lib/kubelet/${WORKER1_HOST}.pem"
tlsPrivateKeyFile: "/var/lib/kubelet/${WORKER1_HOST}-key.pem"
EOF

cat << EOF | tee ./kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --container-runtime=remote \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --network-plugin=cni \\
  --register-node=true \\
  --v=2 \\
  --hostname-override=${WORKER1_HOST} \\
  --allow-privileged=true
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF

scp -o StrictHostKeyChecking=no -i ./ssh_key \
  ./kublet-config.yaml \
  ./kublet.service \
  ubuntu@$WORKER1_PUB_IP:~/

$w1ssh sudo mv ./kublet-config.yaml /var/lib/kublet/kublet-config.yaml
$w1ssh sudo mv ./kublet.service /etc/systemd/system/kublet.service
$w0ssh sudo mv ./kublet-config.yaml /var/lib/kublet/kublet-config.yaml
$w0ssh sudo mv ./kublet.service /etc/systemd/system/kublet.service


rm ./*.service
rm ./kube-scheduler.yaml
rm ./nginx-lb-kubernetes.conf
rm ./kubelet.service
rm ./kubelet-config.yaml
