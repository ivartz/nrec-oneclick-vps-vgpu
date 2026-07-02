#!/bin/bash
# deploy.sh — One-click NREC OpenStack VPS deployment (Windows WSL, Git Bash, Linux, macOS)
#
# Prerequisites:
#   1. Terraform installed
#   2. Edit env.sh and fill in your NREC OpenStack credentials
#
# Usage:
#   bash deploy.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Source credentials
source env.sh

# Auto-detect public IPv4
OPERATOR_IP=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null || echo "")
if [ -n "$OPERATOR_IP" ]; then
    echo "Detected public IPv4: $OPERATOR_IP"
else
    echo "Could not detect public IP — SSH open to 0.0.0.0/0"
fi

# Write terraform.tfvars with runtime values
SUFFIX=$(head -c 6 /dev/urandom | od -An -tx1 | tr -d ' \n' | head -c 6)
DEPLOYMENT_ID="hermes-${SUFFIX}"

cat > terraform.tfvars << EOF
flavor_name          = "gr1.L40S.24g.4xlarge"
image_name           = "vGPU Ubuntu 24.04 LTS"
admin_user           = "hermes"
ssh_user             = "ubuntu"
ollama_model         = "ornith"
local_rdp_port       = 53389
local_ollama_port    = 51434
operator_public_ip   = "${OPERATOR_IP}"
operator_public_ipv6 = ""
deployment_id        = "${DEPLOYMENT_ID}"
EOF

echo "Deployment ID: ${DEPLOYMENT_ID}"
echo ""
echo "========================================"
echo "  Deploying ${DEPLOYMENT_ID}"
echo "========================================"
echo ""

echo "[1/3] terraform init..."
terraform init -input=false

echo ""
echo "[2/3] terraform plan..."
terraform plan -input=false

echo ""
echo "[3/3] terraform apply (5-10 min for cloud-init)..."
terraform apply -auto-approve -input=false

echo ""
echo "========================================"
echo "  DEPLOYMENT COMPLETE"
echo "========================================"
echo ""

VM_IP=$(terraform output -raw vm_ipv4 2>/dev/null || echo "unknown")
ADMIN_USER=$(terraform output -raw admin_user 2>/dev/null || echo "hermes")
ADMIN_PWD=$(terraform output -raw admin_password 2>/dev/null || echo "***")
KEY_PATH=$(terraform output -raw private_key_path 2>/dev/null || echo "keys/${DEPLOYMENT_ID}.pem")

echo "VM IP: ${VM_IP}"
echo "Private key: ${KEY_PATH}"
echo "Admin user: ${ADMIN_USER}"
echo "Admin password: ${ADMIN_PWD}"
echo ""
echo "--- SSH ---"
echo "ssh -i ${KEY_PATH} ubuntu@${VM_IP}"
echo ""
echo "--- RDP tunnel (START FIRST, then connect to localhost:53389) ---"
echo "ssh -L 53389:localhost:3389 -N -i ${KEY_PATH} ubuntu@${VM_IP}"
echo ""
echo "--- Ollama tunnel ---"
echo "ssh -L 51434:localhost:11434 -N -i ${KEY_PATH} ubuntu@${VM_IP}"
echo ""
echo "--- Verify services (after SSH) ---"
echo "  cloud-init status --long"
echo "  nvidia-smi"
echo "  systemctl is-active ollama"
echo "  systemctl is-active gnome-remote-desktop"
