#!/bin/bash
set -e

# 0. Ensure script runs as root where needed
if [ "$EUID" -ne 0 ]; then
  SUDO='sudo'
else
  SUDO=''
fi

# 1. Update OS and install prerequisites
echo "[INFO] Updating system and installing prerequisites..."
${SUDO} yum update -y
${SUDO} yum install -y git wget unzip curl

# 2. Install Java 17 (Amazon Corretto 17)
echo "[INFO] Installing Java 17 (Amazon Corretto)..."
${SUDO} amazon-linux-extras enable corretto17 || true
${SUDO} yum install -y java-17-amazon-corretto-devel
java -version

# 3. Install Docker
echo "[INFO] Installing Docker..."
${SUDO} amazon-linux-extras install docker -y || ${SUDO} yum install -y docker
${SUDO} systemctl enable --now docker
# Add ec2-user to docker group if exists
if id ec2-user >/dev/null 2>&1; then
  ${SUDO} usermod -a -G docker ec2-user || true
fi

# 4. Install Jenkins
echo "[INFO] Installing Jenkins..."
${SUDO} wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
${SUDO} rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key || true
${SUDO} yum install -y jenkins
${SUDO} systemctl enable --now jenkins

# 5. Run SonarQube in Docker
echo "[INFO] Deploying SonarQube container..."
${SUDO} docker pull sonarqube:lts
# Run as non-blocking container; use a volume if desired
${SUDO} docker run -d --name sonarqube -p 9000:9000 sonarqube:lts

# 6. Install Trivy (robust installer)
echo "[INFO] Installing Trivy..."
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | ${SUDO} sh -s -- -b /usr/local/bin
if ! command -v trivy >/dev/null 2>&1; then
  echo "ERROR: trivy installation failed"
  exit 1
fi

# 7. Verify installations
echo "[INFO] Verifying installations..."
java --version || true
${SUDO} systemctl status jenkins --no-pager || true
${SUDO} docker ps || true
trivy --version

# Done
echo "[INFO] Jenkins bootstrap complete."
echo "[INFO] Access Jenkins at port 8080, SonarQube at port 9000."
