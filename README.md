# Scalable CI/CD Pipeline for AWS DevSecOps

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5.0-blue)](https://www.terraform.io/) [![Jenkins](https://img.shields.io/badge/Jenkins-LTS-blue)](https://www.jenkins.io/) [![Docker](https://img.shields.io/badge/Docker-%3E%3D20.10-blue)](https://www.docker.com/) [![SonarQube](https://img.shields.io/badge/SonarQube-LTS-blue)](https://www.sonarqube.org/) [![Trivy](https://img.shields.io/badge/Trivy-%3E%3D0.46-blue)](https://github.com/aquasecurity/trivy)

AWS DevSecOps CI/CD pipeline deploying a React frontend on EC2 with Terraform, Jenkins, Docker, SonarQube, Trivy, and OWASP Dependency-Check.

---

## Quickstart (For Experienced Users)

```bash
# 1. Clone repo and enter terraform folder
git clone https://github.com/r-ramos2/scalable-ci-cd-pipeline-for-aws-devsecops.git
cd scalable-ci-cd-pipeline-for-aws-devsecops/terraform

# 2. Configure your IP
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars → set allowed_cidr = "YOUR_PUBLIC_IP/32"

# 3. Deploy infrastructure
terraform init
terraform apply -auto-approve

# 4. Connect to EC2
ssh -i ./deployer_key.pem ec2-user@$(terraform output -raw instance_public_ip)

# 5. Access Jenkins: http://$(terraform output -raw instance_public_ip):8080
```

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
9. [Application Folder (/app)](#application-folder-app)
10. [Cleanup](#cleanup)
11. [Best Practices](#best-practices)
12. [Security Considerations](#security-considerations)
13. [Next Steps & Enhancements](#next-steps--enhancements)
14. [Resources](#resources)

---

## Topology

![Architecture Diagram](images/architecture-diagram.png)
Single public VPC with one EC2 host running Jenkins, Docker, SonarQube, and Trivy; secured by a dedicated security group.

---

## Getting Started

### 1. Clone the repo

```bash
git clone https://github.com/r-ramos2/scalable-ci-cd-pipeline-for-aws-devsecops.git
cd scalable-ci-cd-pipeline-for-aws-devsecops/terraform
```

### 2. Configure variables & keypair

Terraform auto-generates an RSA keypair. 

**Important:** Terraform creates `terraform/deployer_key.pem` and may overwrite an existing file with that name. Back up any existing key.

Edit `terraform.tfvars` to set your public IP:

```hcl
allowed_cidr  = "203.0.113.25/32"  # REPLACE with YOUR_PUBLIC_IP/32
instance_type = "t3.large"
```

**Do not leave example RFC-5737 addresses in place when you deploy.**

### 3. Provision infrastructure

```bash
terraform init
terraform validate
terraform plan -out=plan.tf
terraform apply plan.tf
```

Outputs: `deployer_key.pem` (sensitive), `instance_public_ip`, `jenkins_url`, `sonarqube_url`, `react_app_url`

---

## Instance Configuration

Connect:

```bash
ssh -i ./deployer_key.pem ec2-user@$(terraform output -raw instance_public_ip)
```

Bootstrap logs: `/var/log/bootstrap.log`

Verify services:

```bash
sudo systemctl status jenkins
docker ps
trivy --version
```

The bootstrap script automatically installs:
- Java 17 (Amazon Corretto)
- Docker Engine with persistent volumes
- Jenkins with systemd service
- SonarQube container with data persistence
- Trivy CLI scanner

---

## Jenkins Configuration & Tools

1. Open Jenkins: `http://<instance_public_ip>:8080`
2. Get initial password: `sudo cat /var/lib/jenkins/secrets/initialAdminPassword`
3. Install plugins:
   - Docker Pipeline
   - SonarQube Scanner
   - OWASP Dependency-Check
   - Pipeline Utility Steps
   - AnsiColor

4. Configure Global Tools (Manage Jenkins → Tools):
   * JDK 17 → name: `jdk17`
   * NodeJS 16 → name: `node16`
   * SonarQube Scanner → name: `sonar-scanner`
   * Dependency-Check → name: `DP-Check`

5. Add Credentials (Manage Jenkins → Credentials):
   * **Docker Hub:**
     - Kind: Username with password
     - ID: `dockerhub-creds`
     - Username: Your Docker Hub username
     - Password: Your Docker Hub access token
   
   * **SonarQube Token:**
     - Kind: Secret text
     - ID: `sonar-server`
     - Secret: (Generate in SonarQube UI)

6. Configure SonarQube webhook:
   - Access SonarQube: `http://<instance_public_ip>:9000`
   - Login: `admin/admin` (change password on first login)
   - Create token: My Account → Security → Generate Token
   - Add webhook: Administration → Webhooks
     - Name: `Jenkins`
     - URL: `http://<instance_public_ip>:8080/sonarqube-webhook/`

---

## Pipeline Setup

1. Create Pipeline job: New Item → Pipeline → Name: `amazon-frontend-pipeline`
2. Pipeline section:
   - Definition: Pipeline script from SCM
   - SCM: Git
   - Repository URL: `https://github.com/r-ramos2/scalable-ci-cd-pipeline-for-aws-devsecops.git`
   - Branch: `*/main`
   - Script Path: `Jenkinsfile`

**Before running, update Jenkinsfile:**
- Line 13: `IMAGE_REPO = 'YOUR_DOCKERHUB_USERNAME/amazon'`

---

## Application Folder (/app)

Local quick test:

```bash
docker build -t amazon-frontend ./app
docker run -d -p 3000:80 amazon-frontend
# Open http://localhost:3000
```

The app uses:
- Multi-stage Docker build (node:16 → nginx:alpine)
- `.dockerignore` to optimize build context
- Health checks for container monitoring

---

## Cleanup

```bash
cd terraform
terraform destroy -auto-approve
```

Also remove Docker containers/volumes on EC2:

```bash
ssh -i ./deployer_key.pem ec2-user@<instance_ip>
docker rm -f $(docker ps -aq)
docker volume prune -f
```

---

## Best Practices

* Use least-privilege IAM for Terraform and resources
* Restrict SSH ingress to your IP (`/32`)
* Use remote state (S3 + DynamoDB) for team collaboration
* Enable CloudTrail for audit logging
* Set AWS billing alerts
* Rotate SSH keys regularly

---

## Security Considerations

This is a **DevSecOps homelab** intentionally simplified to run on a single EC2 instance with a public IP for demonstration. It demonstrates CI/CD with security tooling integration (SonarQube, Dependency-Check, Trivy) while keeping setup reproducible.

**For production, apply these hardening steps:**

* Move Jenkins and SonarQube to **private subnets** behind a bastion host or VPN
* Front the app with an **ALB** using TLS via ACM
* Integrate AWS security services: GuardDuty, Inspector, WAF, CloudTrail, Config
* Use IAM roles and least privilege
* Separate services and scale out for resilience
* Enable EBS encryption and IMDSv2 (already implemented)

---

## Next Steps & Enhancements

* Migrate to EKS for container orchestration
* Add CloudWatch dashboards and alerts
* Implement Argo CD for GitOps
* Configure Jenkins as code (JCasC)
* Add automated backup solutions
* Integrate Slack/email notifications
* Implement blue-green deployments

---

## Resources

* [AWS Documentation](https://aws.amazon.com/documentation/)
* [Terraform Documentation](https://www.terraform.io/docs)
* [Jenkins Pipeline Syntax](https://www.jenkins.io/doc/book/pipeline/syntax/)
* [SonarQube Documentation](https://docs.sonarqube.org/)
* [Trivy GitHub](https://github.com/aquasecurity/trivy)
* [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
