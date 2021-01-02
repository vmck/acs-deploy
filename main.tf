terraform {
  backend "consul" {
    address = "10.42.1.1:8500"
    scheme = "http"
    path = "terraform_state"
  }
}

provider "nomad" {
  address = "http://10.42.1.1:4646"
  version = "~> 1.4"
}

resource "nomad_job" "vmck" {
  jobspec = "${file("${path.module}/nomad_jobs/vmck.hcl")}"
}

resource "nomad_job" "acs-interface" {
  jobspec = "${file("${path.module}/nomad_jobs/acs-interface.hcl")}"
}

resource "nomad_job" "vmck-images-sync" {
  jobspec = "${file("${path.module}/nomad_jobs/vmck-images-sync.hcl")}"
}

resource "nomad_job" "ingress" {
  jobspec = "${file("${path.module}/nomad_jobs/ingress.hcl")}"
}

resource "nomad_job" "drone" {
  jobspec = "${file("${path.module}/nomad_jobs/drone.hcl")}"
}
