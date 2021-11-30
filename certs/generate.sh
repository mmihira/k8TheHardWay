#!/bin/bash


alias cfssl=$GOPATH/bin/cfssl
alias cfssljson=$GOPATH/bin/cfssljson

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

WORKER0_HOST=<Public hostname of your first worker node cloud server>
WORKER0_IP=<Private IP of your first worker node cloud server>
WORKER1_HOST=<Public hostname of your second worker node cloud server>
WORKER1_IP=<Private IP of your second worker node cloud server>

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



