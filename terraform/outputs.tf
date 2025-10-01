# SSH Key
output "private_key_path" {
  description = "Path to the generated SSH private key"
  value       = local_file.private_key_pem.filename
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
