# Scalable CI/CD Pipeline for AWS DevSecOps

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5.0-blue)](https://www.terraform.io/) [![Jenkins](https://img.shields.io/badge/Jenkins-LTS-blue)](https://www.jenkins.io/) [![Docker](https://img.shields.io/badge/Docker-%3E%3D20.10-blue)](https://www.docker.com/) [![SonarQube](https://img.shields.io/badge/SonarQube-LTS-blue)](https://www.sonarqube.org/) [![Trivy](https://img.shields.io/badge/Trivy-%3E%3D0.46-blue)](https://github.com/aquasecurity/trivy)

☁️ **AWS DevSecOps Homelab**  
Automated CI/CD pipeline deploying a React frontend on EC2 with Terraform, Jenkins, Docker, SonarQube, Trivy, OWASP Dependency-Check.

---

## Table of Contents

1. [Topology](#topology)  
2. [Architecture Overview](#architecture-overview)  
3. [Prerequisites](#prerequisites)  
4. [Repository Structure](#repository-structure)  
5. [Getting Started](#getting-started)  
6. [Instance Configuration](#instance-configuration)  
7. [Jenkins Configuration & Tools](#jenkins-configuration--tools)  
8. [Pipeline Setup](#pipeline-setup)  
9. [Application Folder (`/app`)](#application-folder-app)  
10. [Cleanup](#cleanup)  
11. [Best Practices](#best-practices)  
12. [Next Steps & Enhancements](#next-steps--enhancements)  
13. [Resources](#resources)

---

## Topology

![Architecture Diagram](images/architecture-diagram.png)

Single public VPC with one EC2 host running Jenkins, Docker, SonarQube, and Trivy; secured by a dedicated SG.

---

## Architecture Overview

- **VPC & Subnet**: provisioned by Terraform  
- **Security Group**: SSH (22), HTTP (80), HTTPS (443), Jenkins (8080), SonarQube (9000), React (3000)  
- **EC2 Instance**: Amazon Linux 2 (`t3.large`) running:
  - Jenkins  
  - Docker Engine & SonarQube container  
  - Trivy CLI

---

## Prerequisites

- AWS CLI (`aws configure`)  
- Terraform >= 1.5.0  
- Docker Hub account  
- Jenkins admin creds  
- (Optionally) existing EC2 keypair

---

## Repository Structure

```text
.
├── app/                   # React frontend
├── images/                # Diagrams
├── scripts/               # Bootstrap script
│   └── install_jenkins.sh # loaded via Terraform file()
├── terraform/             # Terraform configs
│   ├── provider.tf
│   ├── variables.tf
│   ├── main.tf
│   └── outputs.tf
├── Jenkinsfile            # Pipeline definition
└── README.md              # This file
````

---

## Getting Started

### 1. Clone the repo

```bash
git clone https://github.com/r-ramos2/scalable-ci-cd-pipeline-for-aws-devsecops.git
cd scalable-ci-cd-pipeline-for-aws-devsecops/terraform
```

### 2. Configure Variables & Keypair

Terraform auto-generates an RSA keypair with random suffix. Override defaults in `variables.tf` or `terraform.tfvars`:

```hcl
region          = "us-east-1"
ami_name_filter = "amzn2-ami-hvm-*-gp2"
instance_type   = "t3.large"  # t3.medium for light, c5.large for compute
my_ip           = "203.0.113.0/32"
```

### 3. Provision Infrastructure

```bash
terraform init
terraform validate
tf plan -out=plan.tf
terraform apply plan.tf
```

Outputs:

- `deployer_key.pem`
- `instance_public_ip`
- `jenkins_url`, `sonarqube_url`, `react_app_url`

---

## Instance Configuration

```bash
ssh -i ../terraform/deployer_key.pem ec2-user@${instance_public_ip}
```

Verify:

```bash
sudo systemctl status jenkins
docker ps
trivy --version
```

---

## Jenkins Configuration & Tools

1. Browse to `http://${instance_public_ip}:8080`.
2. Install plugins: Docker Pipeline, SonarQube Scanner, OWASP Dependency-Check.
3. Configure global tools and credentials:
   - JDK, NodeJS, SonarQube Scanner, Dependency-Check, Docker.
   - Credentials: DockerHub (`dockerhub-creds`), SonarQube token (`sonar-server`).

---

## Pipeline Setup

1. Create Pipeline job (`amazon-frontend`).
2. Use `Jenkinsfile` in root; update Git URL, DockerHub creds, image name.

---

## Application Folder (`/app`)

```bash
docker build -t amazon-frontend ./app
docker run -d -p 3000:3000 amazon-frontend
```

Visit `http://localhost:3000`.

---

## Cleanup

```bash
terraform destroy -auto-approve
```

---

## Best Practices

- Least-privilege IAM
- Restricted SSH ingress
- Remote state (S3 + DynamoDB)
- Modular Terraform

---

## Next Steps & Enhancements

- EKS Migration
- CloudWatch alerts
- Argo CD GitOps
- Jenkins config backup
- Additional security scans

---

## Resources

- AWS Docs: [https://aws.amazon.com/documentation/](https://aws.amazon.com/documentation/)
- Terraform: [https://www.terraform.io/docs](https://www.terraform.io/docs)
- Jenkins: [https://www.jenkins.io/doc/](https://www.jenkins.io/doc/)
- SonarQube: [https://docs.sonarqube.org/](https://docs.sonarqube.org/)
- Trivy: [https://github.com/aquasecurity/trivy](https://github.com/aquasecurity/trivy)
