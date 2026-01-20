terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = "default"
}

# provider "helm" {
#  kubernetes = {
#  config_path = "~/.kube/config"
#  }

#  registries = [
#    {
#      url = "https://argoproj.github.io/argo-helm/"
#    },
#  ]
# }

# provider "kubernetes" {
#  config_path    = "~/.kube/config"
#  config_context = "my-context"
# }