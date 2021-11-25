# k8TheHardWay
K8 The Hard Way

### Credentials

- Create a service account and service account key on glcou.
  Save as `gcloud_creds.json` in root dir.

### Build
- Build the terraform docker file `docker build ./ -t snssqst:0`

- Init the project. This will create terraform config files
  in this directory
  `docker run -it -v $PWD:/workspace -w /workspace snssqst:0 init`

- To plan
  `docker run -it -v $PWD:/workspace -w /workspace teratut:0 plan`

- To apply
  `docker run -it -v $PWD:/workspace -w /workspace teratut:0 apply`

- Login as the IAM user to see resources that were provisioned
