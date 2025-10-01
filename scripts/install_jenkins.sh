#!/bin/bash
# Idempotent bootstrap script for Amazon Linux 2
# Installs: Jenkins, Docker, SonarQube (containerized), Trivy
# Logs everything to /var/log/bootstrap.log

set -euo pipefail
exec > /var/log/bootstrap.log 2>&1

# Determine sudo requirement
if [ "$EUID" -ne 0 ]; then
  SUDO='sudo'
else
  SUDO=''
fi

echo "=========================================="
echo "[INFO] Bootstrap started at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "=========================================="

# ============================================
# 1. Update system and install prerequisites
# ============================================
echo "[INFO] Updating system and installing prerequisites..."
${SUDO} yum update -y
${SUDO} yum install -y git wget unzip curl ca-certificates jq

# ============================================
# 2. Install Java 17 (Amazon Corretto)
# ============================================
echo "[INFO] Installing Java 17 (Amazon Corretto)..."
${SUDO} amazon-linux-extras enable corretto17 2>/dev/null || true
${SUDO} yum install -y java-17-amazon-corretto-devel

echo "[INFO] Java version:"
java -version

# ============================================
# 3. Install Docker
# ============================================
echo "[INFO] Installing Docker..."
if ! command -v docker &> /dev/null; then
  if ${SUDO} amazon-linux-extras list | grep -q docker; then
    ${SUDO} amazon-linux-extras install docker -y
  else
    ${SUDO} yum install -y docker
  fi
fi

${SUDO} systemctl enable docker
${SUDO} systemctl start docker

# Add users to docker group
for user in ec2-user jenkins; do
  if id "$user" >/dev/null 2>&1; then
    ${SUDO} usermod -a -G docker "$user"
    echo "[INFO] Added $user to docker group"
  fi
done

echo "[INFO] Docker version:"
docker --version

# ============================================
# 4. Install Jenkins
# ============================================
echo "[INFO] Installing Jenkins..."
JENKINS_REPO="/etc/yum.repos.d/jenkins.repo"

if [ ! -f "${JENKINS_REPO}" ]; then
  ${SUDO} wget -q -O "${JENKINS_REPO}" https://pkg.jenkins.io/redhat-stable/jenkins.repo
  ${SUDO} rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
fi

${SUDO} yum install -y jenkins

${SUDO} systemctl enable jenkins
${SUDO} systemctl start jenkins

echo "[INFO] Waiting for Jenkins to create home directory..."
sleep 5

# ============================================
# 5. Deploy SonarQube container with volumes
# ============================================
echo "[INFO] Deploying SonarQube container with persistent volumes..."

# Create Docker volumes for persistence
${SUDO} docker volume create sonarqube_data 2>/dev/null || true
${SUDO} docker volume create sonarqube_extensions 2>/dev/null || true
${SUDO} docker volume create sonarqube_logs 2>/dev/null || true

# Remove existing container if present
if ${SUDO} docker ps -a --format '{{.Names}}' | grep -q '^sonarqube$'; then
  echo "[INFO] Removing existing SonarQube container..."
  ${SUDO} docker rm -f sonarqube
fi

# Pull latest LTS image
${SUDO} docker pull sonarqube:lts-community

# Run SonarQube with volume mounts
${SUDO} docker run -d \
  --name sonarqube \
  --restart unless-stopped \
  -p 9000:9000 \
  -v sonarqube_data:/opt/sonarqube/data \
  -v sonarqube_extensions:/opt/sonarqube/extensions \
  -v sonarqube_logs:/opt/sonarqube/logs \
  -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true \
  sonarqube:lts-community

echo "[INFO] SonarQube container started (allow 2-3 minutes for initialization)"

# ============================================
# 6. Install Trivy
# ============================================
echo "[INFO] Installing Trivy..."
if ! command -v trivy &> /dev/null; then
  curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | ${SUDO} sh -s -- -b /usr/local/bin
fi

if ! command -v trivy &> /dev/null; then
  echo "[ERROR] Trivy installation failed"
  exit 1
fi

echo "[INFO] Trivy version: $(trivy --version | head -n1)"

# ============================================
# 7. Configure system limits for SonarQube
# ============================================
echo "[INFO] Configuring system limits for SonarQube..."
${SUDO} sysctl -w vm.max_map_count=524288 || true
${SUDO} sysctl -w fs.file-max=131072 || true

# Make limits persistent
if ! grep -q "vm.max_map_count" /etc/sysctl.conf; then
  echo "vm.max_map_count=524288" | ${SUDO} tee -a /etc/sysctl.conf
fi
if ! grep -q "fs.file-max" /etc/sysctl.conf; then
  echo "fs.file-max=131072" | ${SUDO} tee -a /etc/sysctl.conf
fi

# ============================================
# 8. Restart Jenkins with new configurations
# ============================================
echo "[INFO] Restarting Jenkins to apply group membership and PATH changes..."
${SUDO} systemctl daemon-reload
${SUDO} systemctl restart jenkins

# ============================================
# 9. Verification
# ============================================
echo "[INFO] Verifying service status..."
echo "=========================================="

if ${SUDO} systemctl is-active --quiet jenkins; then
  echo "✅ Jenkins is running"
else
  echo "⚠️  Jenkins is not active yet (may still be starting)"
fi

if ${SUDO} systemctl is-active --quiet docker; then
  echo "✅ Docker is running"
else
  echo "❌ Docker is not running"
fi

echo ""
echo "[INFO] Docker containers:"
${SUDO} docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}' || true

echo ""
echo "[INFO] Installed tools:"
echo "  - Java: $(java -version 2>&1 | head -n1)"
echo "  - Docker: $(docker --version)"
echo "  - Trivy: $(trivy --version | head -n1)"

# ============================================
# 10. Post-installation instructions
# ============================================
echo ""
echo "=========================================="
echo "[INFO] Bootstrap completed at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "=========================================="
echo ""
echo "📋 Next Steps:"
echo "  1. Access Jenkins at: http://<instance-ip>:8080"
echo "  2. Get initial admin password: sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
echo "  3. Access SonarQube at: http://<instance-ip>:9000 (default credentials: admin/admin)"
echo "  4. Wait 2-3 minutes for SonarQube to fully initialize"
echo ""
echo "⚠️  IMPORTANT: Log out and log back in for Docker group membership to take effect"
echo "=========================================="
