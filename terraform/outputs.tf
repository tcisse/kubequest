output "nodes_info" {
  description = "Informations de connexion à toutes les VMs"
  value = {
    kube1 = {
      public_ip  = data.aws_instance.kube1.public_ip
      private_ip = data.aws_instance.kube1.private_ip
      state      = data.aws_instance.kube1.instance_state
      ssh        = "ssh -i ${var.ssh_private_key_path} ec2-user@${data.aws_instance.kube1.public_ip}"
    }
    kube2 = {
      public_ip  = data.aws_instance.kube2.public_ip
      private_ip = data.aws_instance.kube2.private_ip
      state      = data.aws_instance.kube2.instance_state
      ssh        = "ssh -i ${var.ssh_private_key_path} ec2-user@${data.aws_instance.kube2.public_ip}"
    }
    ingress = {
      public_ip  = data.aws_instance.ingress.public_ip
      private_ip = data.aws_instance.ingress.private_ip
      state      = data.aws_instance.ingress.instance_state
      ssh        = "ssh -i ${var.ssh_private_key_path} ec2-user@${data.aws_instance.ingress.public_ip}"
    }
    monitoring = {
      public_ip  = data.aws_instance.monitoring.public_ip
      private_ip = data.aws_instance.monitoring.private_ip
      state      = data.aws_instance.monitoring.instance_state
      ssh        = "ssh -i ${var.ssh_private_key_path} ec2-user@${data.aws_instance.monitoring.public_ip}"
    }
  }
}

output "kube1_private_ip" {
  description = "IP privée de kube-1 (pour les commandes de join des workers)"
  value       = data.aws_instance.kube1.private_ip
}
