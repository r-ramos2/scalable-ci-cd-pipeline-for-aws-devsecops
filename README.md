# Scalable CI/CD Pipeline for AWS DevSecOps

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5.0-blue)](https://www.terraform.io/) [![Jenkins](https://img.shields.io/badge/Jenkins-LTS-blue)](https://www.jenkins.io/) [![Docker](https://img.shields.io/badge/Docker-%3E%3D20.10-blue)](https://www.docker.com/) [![SonarQube](https://img.shields.io/badge/SonarQube-LTS-blue)](https://www.sonarqube.org/) [![Trivy](https://img.shields.io/badge/Trivy-%3E%3D0.46-blue)](https://github.com/aquasecurity/trivy)

☁️ **AWS DevSecOps Homelab**
Automated CI/CD pipeline deploying a React frontend on EC2 with Terraform, Jenkins, Docker, SonarQube, Trivy, and OWASP Dependency-Check. Includes a full **bootstrap script** with optional cleanup scheduling.

---

## Table of Contents

1. [Topology](#topology)
2. [Architecture Overview](#architecture-overview)
3. [Prerequisites](#prerequisites)
4. [Repository Structure](#repository-structure)
5. [Getting Started](#getting-started)
6. [Bootstrap Script & Cleanup](#bootstrap-script--cleanup)
7. [Instance Configuration](#instance-configuration)
8. [Jenkins Configuration & Tools](#jenkins-configuration--tools)
9. [Pipeline Setup](#pipeline-setup)
10. [Application Folder (`/app`)](#application-folder-app)
11. [Best Practices](#best-practices)
12. [Next Steps & Enhancements](#next-steps--enhancements)
13. [Resources](#resources)

---

## Topology

![Architecture Diagram](images/architecture-diagram.png)

Single public VPC with one EC2 host running Jenkins, Docker, SonarQube, and Trivy; secured by a dedicated SG.

---

## Architecture Overview

* **VPC & Subnet**: provisioned by Terraform
* **Security Group**: SSH (22), HTTP (80), HTTPS (443), Jenkins (8080), SonarQube (9000), React (3000)
* **EC2 Instance**: Amazon Linux 2 (`t3.large`) running:

  * Jenkins
  * Docker Engine & SonarQube container
  * Trivy CLI

---

## Prerequisites

* AWS CLI (`aws configure`)
* Terraform >= 1.5.0
* Docker Hub account
* Jenkins admin creds
* (Optionally) existing EC2 keypair

---

## Repository Structure

```text
.
├── app/                   # React frontend
├── images/                # Diagrams
├── scripts/               # Bootstrap scripts
├── terraform/             # Terraform configs
├── Jenkinsfile            # Pipeline definition
└── README.md              # This file
```

---

## Getting Started

### 1. Clone the repo

```bash
git clone https://github.com/your-repo/scalable-ci-cd-pipeline-for-aws-devsecops.git
cd scalable-ci-cd-pipeline-for-aws-devsecops/terraform
```

### 2. Configure Terraform Variables & Keypair

Use `variables.tf` or create a `terraform.tfvars`:

```hcl
region        = "us-east-1"
instance_type = "t3.large"
my_ip         = "203.0.113.0/32"
```

### 3. Provision Infrastructure

```bash
terraform init
terraform validate
terraform plan -out=plan.tf
terraform apply plan.tf
```

Outputs include `deployer_key.pem`, instance public IP, Jenkins URL, SonarQube URL, and React app URL.

---

## Bootstrap Script & Cleanup

The `scripts/bootstrap.sh` automates:

* Terraform backend bootstrapping
* Main infrastructure & EKS deployment
* Jenkins, Docker, SonarQube, Trivy installation
* Optional cleanup after a user-defined delay

**Usage Examples:**

```bash
# Default: auto-cleanup after 1 hour
./scripts/bootstrap.sh

# No cleanup (leave infra running)
./scripts/bootstrap.sh --no-cleanup

# Custom cleanup after 30 minutes
./scripts/bootstrap.sh --cleanup-after 30
```

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

   * JDK, NodeJS, SonarQube Scanner, Dependency-Check, Docker
   * Credentials: DockerHub, SonarQube token

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

## Best Practices

* Least-privilege IAM
* Restricted SSH ingress
* Remote state (S3 + DynamoDB)
* Modular Terraform

---

## Next Steps & Enhancements

* EKS Migration
* CloudWatch alerts
* Argo CD GitOps
* Jenkins config backup
* Additional security scans

---

## Resources

* AWS Docs: [https://aws.amazon.com/documentation/](https://aws.amazon.com/documentation/)
* Terraform: [https://www.terraform.io/docs](https://www.terraform.io/docs)
* Jenkins: [https://www.jenkins.io/doc/](https://www.jenkins.io/doc/)
* SonarQube: [https://docs.sonarqube.org/](https://docs.sonarqube.org/)
* Trivy: [https://github.com/aquasecurity/trivy](https://github.com/aquasecurity/trivy)
