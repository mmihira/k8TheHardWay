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


resource "google_compute_instance" "node1" {
  name = "node1"
  hostname = "node1.kb.ht"
  machine_type = "g1-small"
  zone = "australia-southeast2-b"
  tags =[
    "name","node1"
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

resource "google_compute_instance" "node2" {
  name = "node2"
  hostname = "node2.kb.ht"
  machine_type = "g1-small"
  zone = "australia-southeast2-b"
  tags =[
    "name","node2"
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

resource "google_compute_instance" "cntrl1" {
  name = "cntrl1"
  hostname = "cntrl1.kb.ht"
  machine_type = "g1-small"
  zone = "australia-southeast2-b"
  tags =[
    "name","cntrl1"
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

resource "google_compute_instance" "cntrl2" {
  name = "cntrl2"
  hostname = "cntrl2.kb.ht"
  machine_type = "g1-small"
  zone = "australia-southeast2-b"
  tags =[
    "name","cntrl2"
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

resource "google_compute_instance" "lb" {
  name = "lb"
  hostname = "lb.kb.ht"
  machine_type = "g1-small"
  zone = "australia-southeast2-b"
  tags =[
    "name","lb"
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
