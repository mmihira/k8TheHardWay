# k8TheHardWay
K8 The Hard Way

### Credentials
- Create a service account and service account key on glcoud.
  Save as `gcloud_creds.json` in root dir.

### Project Name
Change the project name in main.tf to the specific project name you are using.

### Build
- Build the terraform docker file `docker build -f Dockerfile_terraform -t snssqst:0 .`
- Build the gcloud docker file `docker build -f Dockerfile_terraform -t snssqst:0 .`

### Terraform
- Init the project. This will create terraform config files
  in this directory
  `docker run -it -v $PWD:/workspace -w /workspace snssqst:0 init`

- To plan
  `docker run -it -v $PWD:/workspace -w /workspace teratut:0 plan`

- To apply
  `docker run -it -v $PWD:/workspace -w /workspace teratut:0 apply`

- Print output
  `docker run -it -v $PWD:/workspace -w /workspace teratut:0 show -json > out.json`

### Gcloud
Test if gcloud works. Make sure to use the specific project name

`docker run -v $PWD:/workspace -w /workspace -it k8gc:0.0 gcloud --project k8hardway-333211 services list`

