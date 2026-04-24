# SSH Key
output "private_key_pem" {
  description = "Private key PEM — pipe to a file: terraform output -raw private_key_pem > deployer_key.pem && chmod 400 deployer_key.pem"
  value       = tls_private_key.deployer.private_key_pem
  sensitive   = true
}

# EC2 Public IP
output "instance_public_ip" {
  description = "Public IP of Jenkins EC2"
  value       = aws_instance.jenkins.public_ip
}

# Service URLs
output "jenkins_url" {
  description = "Jenkins access URL"
  value       = "http://${aws_instance.jenkins.public_ip}:${var.jenkins_port}"
}

output "sonarqube_url" {
  description = "SonarQube access URL"
  value       = "http://${aws_instance.jenkins.public_ip}:${var.sonarqube_port}"
}

output "react_app_url" {
  description = "React App access URL"
  value       = "http://${aws_instance.jenkins.public_ip}:${var.react_port}"
}

# Logging
output "vpc_flow_log_group_name" {
  description = "CloudWatch Logs group for VPC Flow Logs"
  value       = aws_cloudwatch_log_group.vpc_flow_logs.name
}
