terraform {
  required_providers {
    flux = {
      source  = "fluxcd/flux"
      version = "1.0.0-rc.3"
    }
  }
}

# GitHub infrastructure repository
module "github_repository" {
  source                   = "github.com/den-vasyliev/tf-github-repository"
  github_owner             = var.GITHUB_OWNER
  github_token             = var.GITHUB_TOKEN
  repository_name          = var.FLUX_GITHUB_REPO
  public_key_openssh       = module.tls_private_key.public_key_openssh
  public_key_openssh_title = "flux0"

  # Add configs to repository to automatically run PET project in Flux
  configs_path_local       = "clusters/demo"
  configs_path_remote      = "${var.FLUX_GITHUB_TARGET_PATH}/demo"
}

# Use kubernetes in docker for local testing
module "kind_cluster" {
  source = "github.com/sergeypashkov/tf-kind-cluster"
}

# GKE cluster for cloud deployment.
# Note, here we pass the machine type, the default is set to n1-standard-4
# because deployment with less powerful configuration hangs and fails with timeout.
#  module "gke_cluster" {
#  source = "github.com/sergeypashkov/tf-google-gke-cluster"
#  GOOGLE_REGION = var.GOOGLE_REGION
#  GOOGLE_PROJECT = var.GOOGLE_PROJECT
#  GKE_NUM_NODES = 1
#  GKE_MACHINE_TYPE = var.GKE_MACHINE_TYPE
# }

# Generate SSH keys
module "tls_private_key" {
  source    = "github.com/den-vasyliev/tf-hashicorp-tls-keys"
  algorithm = "RSA"
}

# Use Flux provider directly
provider "flux" {
  kubernetes = {
    config_path = module.kind_cluster.kubeconfig
  }
  git = {
    url = "ssh://github.com/${var.GITHUB_OWNER}/${var.FLUX_GITHUB_REPO}.git"
    ssh = {
      username    = "git"
      private_key = module.tls_private_key.private_key_pem
    }
  }
}

# It depends on repository and its SSH key, so wait for creation 
resource "flux_bootstrap_git" "this" {
  depends_on = [module.github_repository]
  path       = var.FLUX_GITHUB_TARGET_PATH
}


