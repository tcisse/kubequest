terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }
  required_version = ">= 1.5.0"
}

provider "aws" {
  region = var.aws_region
}

# ─────────────────────────────────────────────────────────────────────────────
# NOTE : Les 4 VMs sont pré-provisionnées par Epitech.
# Ce fichier Terraform permet de les gérer (démarrage, état, infos réseau)
# sans les recréer.
# Pour récupérer les instance IDs :
#   aws ec2 describe-instances --region eu-west-1 \
#     --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Name`].Value|[0],State.Name,PublicIpAddress]' \
#     --output table
# ─────────────────────────────────────────────────────────────────────────────

# ─── Référence aux instances existantes ───────────────────────────────────────
data "aws_instance" "kube1" {
  instance_id = var.instance_id_kube1
}

data "aws_instance" "kube2" {
  instance_id = var.instance_id_kube2
}

data "aws_instance" "ingress" {
  instance_id = var.instance_id_ingress
}

data "aws_instance" "monitoring" {
  instance_id = var.instance_id_monitoring
}

# ─── Locals ───────────────────────────────────────────────────────────────────
locals {
  nodes = {
    kube1      = data.aws_instance.kube1
    kube2      = data.aws_instance.kube2
    ingress    = data.aws_instance.ingress
    monitoring = data.aws_instance.monitoring
  }
}
