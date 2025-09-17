#!/bin/bash
# idempotent bootstrap for Amazon Linux 2 (or compatible)
# Logs everything to /var/log/bootstrap.log
set -euo pipefail
exec > /var/log/bootstrap.log 2>&1

# run as root where needed
if [ "$EUID" -ne 0 ]; then
  SUDO='sudo'
else
  SUDO=''
fi

echo "[INFO] Bootstrap started at $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# 1. Update OS and install prerequisites
echo "[INFO] Updating system and installing prerequisites..."
${SUDO} yum update -y
${SUDO} yum install -y git wget unzip curl ca-certificates jq

# 2. Install Java 17 (Amazon Corretto 17) idempotent
echo "[INFO] Installing Java 17 (Amazon Corretto)..."
${SUDO} amazon-linux-extras enable corretto17 || true
${SUDO} yum install -y java-17-amazon-corretto-devel || true
echo "[INFO] java version:"
java -version || true

# 3. Install Docker
echo "[INFO] Installing Docker..."
# Try amazon-linux-extras first; fallback to yum
if ! ${SUDO} amazon-linux-extras list | grep -q docker; then
  ${SUDO} yum install -y docker || true
else
  ${SUDO} amazon-linux-extras install docker -y || ${SUDO} yum install -y docker
fi
${SUDO} systemctl enable --now docker
# Add ec2-user and jenkins to docker group if those accounts exist
for u in ec2-user jenkins; do
  if id "$u" >/dev/null 2>&1; then
    ${SUDO} usermod -a -G docker "$u" || true
  fi
done

# 4. Install Jenkins (idempotent)
echo "[INFO] Installing Jenkins..."
JENKINS_REPO="/etc/yum.repos.d/jenkins.repo"
${SUDO} wget -q -O "${JENKINS_REPO}" https://pkg.jenkins.io/redhat-stable/jenkins.repo || true
${SUDO} rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key || true
${SUDO} yum install -y jenkins || true
${SUDO} systemctl enable --now jenkins

# Give Jenkins a moment to create its home directory
sleep 3

# 5. Run SonarQube in Docker (detached). SonarQube needs RAM.
echo "[INFO] Deploying SonarQube container (detached)..."
# If container exists, recreate gracefully
if ${SUDO} docker ps -a --format '{{.Names}}' | grep -q '^sonarqube$'; then
  ${SUDO} docker rm -f sonarqube || true
fi
# Use a named volume for persistence (optional)
${SUDO} docker pull sonarqube:lts
${SUDO} docker run -d --name sonarqube -p 9000:9000 \
  -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true \
  sonarqube:lts

# 6. Install Trivy using official installer (robust)
echo "[INFO] Installing Trivy..."
if ! command -v trivy >/dev/null 2>&1; then
  curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | ${SUDO} sh -s -- -b /usr/local/bin
fi
if ! command -v trivy >/dev/null 2>&1; then
  echo "[ERROR] trivy installation failed"
  exit 1
fi
echo "[INFO] trivy version: $(trivy --version | head -n1)"

# 7. Ensure PATH changes are picked up by services (reload systemd environment)
${SUDO} systemctl daemon-reload || true

# Restart Jenkins so it inherits docker group membership and PATH
echo "[INFO] Restarting Jenkins so it picks up group membership and PATH"
${SUDO} systemctl restart jenkins || true

# 8. Basic verification (non-blocking)
echo "[INFO] Verifying services (non-blocking) ..."
${SUDO} systemctl is-active --quiet jenkins && echo "[OK] jenkins running" || echo "[WARN] jenkins not active yet"
${SUDO} docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}' || true

echo "[INFO] Bootstrap finished at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "[INFO] Access Jenkins at port 8080, SonarQube at port 9000 (allow some minutes for Sonar to be healthy)."
