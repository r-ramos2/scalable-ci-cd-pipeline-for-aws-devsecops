# Scalable CI/CD Pipeline for AWS DevSecOps

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5.0-blue)](https://www.terraform.io/) [![Jenkins](https://img.shields.io/badge/Jenkins-LTS-blue)](https://www.jenkins.io/) [![Docker](https://img.shields.io/badge/Docker-%3E%3D20.10-blue)](https://www.docker.com/) [![SonarQube](https://img.shields.io/badge/SonarQube-LTS-blue)](https://www.sonarqube.org/) [![Trivy](https://img.shields.io/badge/Trivy-%3E%3D0.46-blue)](https://github.com/aquasecurity/trivy)

☁️ **AWS DevSecOps Homelab**

Automated CI/CD pipeline deploying a React frontend on EC2 with Terraform, Jenkins, Docker, SonarQube, Trivy, and OWASP Dependency-Check.

---

## Quickstart (For Experienced Users)

```bash
# 1. Clone repo and enter terraform folder
git clone https://github.com/r-ramos2/scalable-ci-cd-pipeline-for-aws-devsecops.git
cd scalable-ci-cd-pipeline-for-aws-devsecops/terraform

# 2. Configure your IP
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars → set my_ip = "YOUR_PUBLIC_IP/32" and allowed_cidr = "YOUR_PUBLIC_IP/32"

# 3. Deploy infrastructure
terraform init
terraform apply -auto-approve

# 4. Connect to EC2
ssh -i ./deployer_key.pem ec2-user@$(terraform output -raw instance_public_ip)

# 5. Access Jenkins: http://$(terraform output -raw instance_public_ip):8080
```

---

## Table of Contents

1. Topology
2. Architecture Overview
3. Prerequisites
4. Repository Structure
5. Getting Started
6. Instance Configuration
7. Jenkins Configuration & Tools
8. Pipeline Setup
9. Application Folder (`/app`)
10. Cleanup
11. Best Practices
12. Security Considerations (Portfolio note)
13. Next Steps & Enhancements
14. Resources

---

## Topology

![Architecture Diagram](images/architecture-diagram.png)
Single public VPC with one EC2 host running Jenkins, Docker, SonarQube, and Trivy; secured by a dedicated security group.

---

## Architecture Overview

* VPC & Subnet provisioned by Terraform.
* Security Group opens limited ports: SSH (22), HTTP (80), HTTPS (443), Jenkins (8080), SonarQube (9000), App (3000).
* EC2 instance: Amazon Linux 2 (`t3.large`) running Jenkins, Docker, SonarQube (container), Trivy CLI.

---

## Prerequisites

* AWS CLI configured (`aws configure`).
* Terraform >= 1.5.0.
* Docker Hub account.
* Jenkins admin credentials.
* (Optional) existing EC2 keypair if you prefer not to use the generated key.

---

## Repository Structure

```text
.
├── app/                   # React frontend (public/, src/, Dockerfile)
├── images/                # Diagrams (architecture-diagram.png)
├── scripts/               # Bootstrap script (install_jenkins.sh)
├── terraform/             # Terraform configs: provider.tf, variables.tf, main.tf, outputs.tf
├── Jenkinsfile            # Pipeline definition
└── README.md              # This file
```

---

## Getting Started

### 1. Clone the repo

```bash
git clone https://github.com/r-ramos2/scalable-ci-cd-pipeline-for-aws-devsecops.git
cd scalable-ci-cd-pipeline-for-aws-devsecops/terraform
```

### 2. Configure variables & keypair

Terraform can auto-generate an RSA keypair. If you want the repo to generate `deployer_key.pem`, keep defaults.
Important: Terraform will create `terraform/deployer_key.pem` and may overwrite an existing file with that name. Back up any existing key.

Edit `terraform.tfvars` (or set via CLI) to point to your public IP:

```hcl
my_ip        = "203.0.113.25/32"  # REPLACE with your public IP/32
allowed_cidr = "203.0.113.25/32"  # REPLACE with your public IP/32
instance_type = "t3.large"
```

*(Do not leave example RFC-5737 addresses in place when you actually deploy.)*

### 3. Provision infra

```bash
terraform init
terraform validate
terraform plan -out=plan.tf
terraform apply plan.tf
```

Outputs: `deployer_key.pem` (sensitive), `instance_public_ip`, `jenkins_url`, `sonarqube_url`, `react_app_url`.

---

## Instance Configuration

Connect:

```bash
ssh -i ../terraform/deployer_key.pem ec2-user@${instance_public_ip}
```

Bootstrap logs: `/var/log/bootstrap.log`. Verify services:

```bash
sudo systemctl status jenkins
docker ps
trivy --version
```

---

## Jenkins Configuration & Tools

1. Open Jenkins: `http://${instance_public_ip}:8080`.
2. Plugins to install: Docker Pipeline, SonarQube Scanner, OWASP Dependency-Check.
3. Configure Global Tools (match names used in Jenkinsfile):

   * JDK 17 → `jdk17`
   * NodeJS 16 → `node16`
   * SonarQube Scanner → `sonar-scanner`
   * Dependency-Check → `DP-Check`
4. Add Credentials:

   * DockerHub credentials id: `dockerhub-creds`
   * SonarQube token id: `sonar-server`
5. SonarQube webhook: configure in Sonar UI to point to:

```
http://<instance_public_ip>:8080/sonarqube-webhook/
```

This makes `waitForQualityGate` reliable.

---

## Pipeline Setup

1. Create Pipeline job `amazon-frontend`.
2. Use repo `Jenkinsfile`.

**Update these placeholders before running:**

* `git` URL in Jenkinsfile → your repo URL.
* `IMAGE_REPO` in Jenkinsfile → `yourdockerhubuser/imagename`.

---

## Application Folder (`/app`)

Local quick test:

```bash
docker build -t amazon-frontend ./app
docker run -d -p 3000:3000 amazon-frontend
# open http://localhost:3000
```

---

## Cleanup

```bash
terraform destroy -auto-approve
```

Also remove Docker containers/images on EC2 when finished.

---

## Best Practices

* Use least-privilege IAM for Terraform and resources.
* Restrict SSH ingress to your IP (`/32`).
* Use remote state (S3 + DynamoDB).
* Modularize Terraform configurations.

---

## Security Considerations (Portfolio note)

This repo is a **DevSecOps homelab** intentionally simplified to run on a single EC2 instance with a public IP for demonstration. It demonstrates CI/CD plus security tooling integration (SonarQube, Dependency-Check, Trivy), while keeping the setup easy to reproduce.

For production or a higher-security demo, apply these hardening steps:

* Move Jenkins and SonarQube to **private subnets** behind a bastion host or VPN.
* Front the app with an **ALB** using TLS via ACM.
* Integrate AWS security services: GuardDuty, Inspector, WAF, CloudTrail, Config.
* Use IAM roles and least privilege.
* Separate services and scale out for resilience.

---

## Next Steps & Enhancements

* EKS migration / container orchestration.
* CloudWatch dashboards and alerts.
* Argo CD for GitOps.
* Jenkins configuration-as-code and backup.
* Add IDS/IPS and automated incident alerts.

---

## Resources

* AWS Docs: [https://aws.amazon.com/documentation/](https://aws.amazon.com/documentation/)
* Terraform: [https://www.terraform.io/docs](https://www.terraform.io/docs)
* Jenkins: [https://www.jenkins.io/doc/](https://www.jenkins.io/doc/)
* SonarQube: [https://docs.sonarqube.org/](https://docs.sonarqube.org/)
* Trivy: [https://github.com/aquasecurity/trivy](https://github.com/aquasecurity/trivy)
