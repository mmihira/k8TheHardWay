variable "project_name" {
  type = string
  default = "k8hardway-333211"
}

locals {
  network_name                   = "kubernetes-cluster"
  subnet_name                    = "${google_compute_network.vpc.name}--subnet"
  region = "australia-southeast2"
}


# Specify the provider (GCP, AWS, Azure)
provider "google"{
  credentials = file("gcloud_creds.json")
  project = var.project_name
  region = local.region
}


resource "google_compute_network" "vpc" {
  name                            = local.network_name
  auto_create_subnetworks         = false
  routing_mode                    = "GLOBAL"
  delete_default_routes_on_create = true
}

resource "google_compute_subnetwork" "subnet" {
  name                     = local.subnet_name
  ip_cidr_range            = "10.10.0.0/16"
  region                   = local.region
  network                  = google_compute_network.vpc.name
  private_ip_google_access = true
}

resource "google_compute_route" "egress_internet" {
  name             = "egress-internet"
  dest_range       = "0.0.0.0/0"
  network          = google_compute_network.vpc.name
  next_hop_gateway = "default-internet-gateway"
}

resource "google_compute_router" "router" {
  name    = "${local.network_name}-router"
  region  = google_compute_subnetwork.subnet.region
  network = google_compute_network.vpc.name
}

resource "google_compute_router_nat" "nat_router" {
  name                               = "${google_compute_subnetwork.subnet.name}-nat-router"
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.subnet.name
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

resource "google_compute_instance" "node1" {
  name = "node1"
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
    subnetwork = local.subnet_name
    access_config {
    }
  }

  metadata = {
    ssh-keys = "ubuntu:${file("ssh_key.pub")}"
  }
}

resource "google_compute_instance" "node2" {
  name = "node2"
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
    subnetwork = local.subnet_name
    access_config {
    }
  }

  metadata = {
    ssh-keys = "ubuntu:${file("ssh_key.pub")}"
  }
}

resource "google_compute_instance" "cntrl1" {
  name = "cntrl1"
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
    subnetwork = local.subnet_name
    access_config {
    }
  }

  metadata = {
    ssh-keys = "ubuntu:${file("ssh_key.pub")}"
  }
}

resource "google_compute_instance" "cntrl2" {
  name = "cntrl2"
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
    subnetwork = local.subnet_name
    access_config {
    }
  }

  metadata = {
    ssh-keys = "ubuntu:${file("ssh_key.pub")}"
  }
}

resource "google_compute_instance" "lb" {
  name = "lb"
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
    subnetwork = local.subnet_name
    access_config {
    }
  }

  metadata = {
    ssh-keys = "ubuntu:${file("ssh_key.pub")}"
  }
}

resource "google_compute_firewall" "vpc-default" {
  name    = "ssh-firewall"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "intra-node" {
  name    = "intra-node"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.10.0.0/16"]
}

resource "google_compute_firewall" "lb-80" {
  name    = "lb-80"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags = ["lb"]
}
