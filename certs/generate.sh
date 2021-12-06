#!/bin/bash

DIR="$( cd "$( dirname "$0" )" && pwd )"
ROOT=$(dirname $DIR)

cd $DIR

alias cfssl=$GOPATH/bin/cfssl
alias cfssljson=$GOPATH/bin/cfssljson

rm *.csr
rm *.json
rm *.pem
rm *.kubeconfig

LB=$(cat $ROOT/out.json | jq '.values.root_module.resources[] | select(.name=="lb") | .')
C1=$(cat $ROOT/out.json | jq '.values.root_module.resources[] | select(.name=="cntrl1") | .')
C2=$(cat $ROOT/out.json | jq '.values.root_module.resources[] | select(.name=="cntrl2") | .')
N1=$(cat $ROOT/out.json | jq '.values.root_module.resources[] | select(.name=="node1") | .')
N2=$(cat $ROOT/out.json | jq '.values.root_module.resources[] | select(.name=="node2") | .')

cat > ca-config.json << EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF

cat > ca-csr.json << EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [{
    "C": "US",
    "L": "Portland",
    "O": "Kubernetes",
    "OU": "CA",
    "ST": "Oregon"
  }]
}
EOF

cfssl gencert -initca ca-csr.json | cfssljson -bare ca

# -------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------

cat > admin-csr.json << EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [{
    "C": "US",
    "L": "Portland",
    "O": "system:masters",
    "OU": "Kubernetes The Hard Way",
    "ST": "Oregon"
    }]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  admin-csr.json | cfssljson -bare admin

# -------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------

WORKER0_HOST=$(echo $N1 | jq  '.values.name' -r)
WORKER0_IP=$(echo $N1 | jq  '.values.network_interface[0].network_ip' -r)
WORKER1_HOST=$(echo $N2 | jq  '.values.name' -r )
WORKER1_IP=$(echo $N2 | jq  '.values.network_interface[0].network_ip' -r)
CTRL0_HOST=$(echo $C1 | jq  '.values.name' -r)
CTRL0_IP=$(echo $C1 | jq  '.values.network_interface[0].network_ip' -r)
CTRL1_HOST=$(echo $C2 | jq  '.values.name' -r )
CTRL1_IP=$(echo $C2 | jq  '.values.network_interface[0].network_ip' -r)
LB1_HOST=$(echo $LB | jq  '.values.name' -r )
LB1_IP=$(echo $LB | jq  '.values.network_interface[0].network_ip' -r)

echo "----------------------------------"
echo "NODE VARS"
echo "----------------------------------"
echo $WORKER0_HOST
echo $WORKER0_IP
echo $WORKER1_HOST
echo $WORKER1_IP
echo $CTRL0_HOST
echo $CTRL0_IP
echo $CTRL1_HOST
echo $CTRL1_IP
echo $LB1_HOST
echo $LB1_IP
echo "----------------------------------"
echo "----------------------------------"

cat > ${WORKER0_HOST}-csr.json << EOF
{
  "CN": "system:node:${WORKER0_HOST}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [{
    "C": "US",
    "L": "Portland",
    "O": "system:nodes",
    "OU": "Kubernetes The Hard Way",
    "ST": "Oregon"
  }]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=${WORKER0_IP},${WORKER0_HOST} \
  -profile=kubernetes \
  ${WORKER0_HOST}-csr.json | cfssljson -bare ${WORKER0_HOST}

cat > ${WORKER1_HOST}-csr.json << EOF
{
  "CN": "system:node:${WORKER1_HOST}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [{
    "C": "US",
    "L": "Portland",
    "O": "system:nodes",
    "OU": "Kubernetes The Hard Way",
    "ST": "Oregon"
  } ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=${WORKER1_IP},${WORKER1_HOST} \
  -profile=kubernetes \
  ${WORKER1_HOST}-csr.json | cfssljson -bare ${WORKER1_HOST}



cat > kube-controller-manager-csr.json << EOF
{
  "CN": "system:kube-controller-manager",
    "key": {
      "algo": "rsa",
      "size": 2048
    },
    "names": [{
      "C": "US",
      "L": "Portland",
      "O": "system:kube-controller-manager",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager

cat > kube-proxy-csr.json << EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [ {
    "C": "US",
    "L": "Portland",
    "O": "system:node-proxier",
    "OU": "Kubernetes The Hard Way",
    "ST": "Oregon"
  }]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-proxy-csr.json | cfssljson -bare kube-proxy

cat > kube-scheduler-csr.json << EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [{
    "C": "US",
    "L": "Portland",
    "O": "system:kube-scheduler",
    "OU": "Kubernetes The Hard Way",
    "ST": "Oregon"
  }]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-scheduler-csr.json | cfssljson -bare kube-scheduler

CERT_HOSTNAME=10.32.0.1,$CTRL0_IP,$CTRL0_HOST,$CTRL1_IP,$CTRL1_HOST,$LB1_IP,$LB1_HOST,127.0.0.1,localhost,kubernetes.default,$WORKER0_IP,$WORKER0_HOST,$WORKER1_IP
echo "----------------------------------"
echo "CERT HOSTS"
echo "----------------------------------"
echo $CERT_HOSTNAME
echo "----------------------------------"

cat > kubernetes-csr.json << EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
     "size": 2048
   },
  "names": [{
    "C": "US",
    "L": "Portland",
    "O": "Kubernetes",
    "OU": "Kubernetes The Hard Way",
    "ST": "Oregon"
   }]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=${CERT_HOSTNAME} \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes

cat > service-account-csr.json << EOF
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [{
    "C": "US",
    "L": "Portland",
    "O": "Kubernetes",
    "OU": "Kubernetes The Hard Way",
    "ST": "Oregon"
  }]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  service-account-csr.json | cfssljson -bare service-account
