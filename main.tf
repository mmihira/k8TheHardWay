variable "project_name" {
  type = string
  default = "k8hardway-333211"
}


# Specify the provider (GCP, AWS, Azure)
provider "google"{
  credentials = file("gcloud_creds.json")
  project = var.project_name
  region = "australia-southeast2-b"
}


resource "google_compute_instance" "default" {
  name = "default"
  machine_type = "g1-small"
  zone = "us-east1-b"
  tags =[
    "name","default"
  ]

  boot_disk {
    auto_delete = true
    initialize_params {
      image = "centos-cloud/centos-7"
    }
  }


  labels = {
    container-vm = "cos-stable-69-10895-62-0"
  }

  network_interface {
    network = "default"
    access_config {
    }
  }
}
