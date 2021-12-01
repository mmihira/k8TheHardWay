# k8TheHardWay
K8 The Hard Way

### Credentials
- Create a service account and service account key on glcoud.
  Save as `gcloud_creds.json` in root dir.

### Project Name
Change the project name in main.tf to the specific project name you are using.

### Instructions

- Build the terraform docker file `docker build -f Dockerfile_terraform -t k8gc:0 .`
- Build the gcloud docker file `docker build -f Dockerfile_terraform -t k8gc:0 .`
- Generate key pairs `ssh-keygen -t rsa -b 4096 -C "email.com"` name it `ssh_key` inside this dir
- Run `docker run -it -v $PWD:/workspace -w /workspace k8gc:0 apply`
- Run `docker run -it -v $PWD:/workspace -w /workspace k8gc:0 show -json > out.json`
- Run `./certs/generate.sh`

### Terraform
- Init the project. This will create terraform config files
  in this directory
  `docker run -it -v $PWD:/workspace -w /workspace k8gc:0 init`

- To plan
  `docker run -it -v $PWD:/workspace -w /workspace k8gc:0 plan`

- To apply
  `docker run -it -v $PWD:/workspace -w /workspace k8gc:0 apply`

- Print output
  `docker run -it -v $PWD:/workspace -w /workspace k8gc:0 show -json > out.json`

### GCloud
Test if gcloud works. Make sure to use the specific project name

`docker run -v $PWD:/workspace -w /workspace -it k8gc:0.0 gcloud --project k8hardway-333211 services list`

