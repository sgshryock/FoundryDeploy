# FoundryDeploy AWS EC2 Terraform Outputs

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.foundry.id
}

output "public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = local.instance_public_ip
}

output "public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.foundry.public_dns
}

output "foundry_url" {
  description = "URL to access Foundry VTT"
  value       = "https://${local.instance_public_ip}"
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${local.instance_public_ip}"
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.foundry.id
}

output "vpc_id" {
  description = "VPC ID"
  value       = local.vpc_id
}

output "subnet_id" {
  description = "Subnet ID"
  value       = local.subnet_id
}

output "setup_instructions" {
  description = "Instructions to complete Foundry setup"
  value       = <<-EOT
    Foundry VTT EC2 Instance Deployed!

    1. Wait a few minutes for cloud-init to complete
    2. SSH to the instance:
       ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${local.instance_public_ip}
    3. Switch to foundry user:
       sudo su - foundry
    4. Run setup:
       ./setup
    5. Access Foundry at:
       https://${local.instance_public_ip}
  EOT
}
