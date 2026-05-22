variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"  # Irlande (région des VMs Epitech)
}

# ─── IDs des instances existantes (fournies par Epitech) ─────────────────────
# À récupérer via : aws ec2 describe-instances --region eu-west-1
variable "instance_id_kube1" {
  description = "Instance ID de kube-1 (ex: i-0abc123def456)"
  type        = string
}

variable "instance_id_kube2" {
  description = "Instance ID de kube-2"
  type        = string
}

variable "instance_id_ingress" {
  description = "Instance ID du nœud ingress"
  type        = string
}

variable "instance_id_monitoring" {
  description = "Instance ID du nœud monitoring"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Chemin vers la clé privée SSH (.pem)"
  type        = string
  default     = "~/.ssh/kubequest.pem"
}
