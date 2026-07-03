#!/bin/bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

source env.sh

OPERATOR_IP=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null || echo "")
[ -n "$OPERATOR_IP" ] && echo "Public IP: $OPERATOR_IP" || echo "Could not detect public IP"

DEPLOYMENT_ID="hermes-$(head -c 6 /dev/urandom | od -An -tx1 | tr -d ' \n' | head -c 6)"

cat > terraform.tfvars << EOF
flavor_name          = "gr1.L40S.24g.4xlarge"
image_name           = "vGPU Ubuntu 24.04 LTS"
admin_user           = "hermes"
ssh_user             = "ubuntu"
ollama_model         = "ornith"
local_vnc_port       = 55901
local_ollama_port    = 51434
operator_public_ip   = "${OPERATOR_IP}"
operator_public_ipv6 = ""
deployment_id        = "${DEPLOYMENT_ID}"
EOF

echo "Deploying ${DEPLOYMENT_ID}..."

# Termux DNS workaround
if [ -d /data/data/com.termux ]; then
    export TF_CLI_CONFIG_FILE="$PWD/.terraformrc"
    PROXY_PORT=9080
    if curl -s --max-time 1 -o /dev/null "http://127.0.0.1:${PROXY_PORT}/" 2>/dev/null; then
        :
    elif [ -f "https_proxy.py" ]; then
        python3 https_proxy.py >/dev/null 2>&1 &
        for _ in $(seq 1 10); do
            curl -s --max-time 1 -o /dev/null "http://127.0.0.1:${PROXY_PORT}/" 2>/dev/null && break
            sleep 0.3
        done
        curl -s --max-time 1 -o /dev/null "http://127.0.0.1:${PROXY_PORT}/" 2>/dev/null || { echo "ERROR: proxy failed" >&2; exit 1; }
    else
        echo "ERROR: https_proxy.py not found" >&2; exit 1
    fi
    export HTTP_PROXY="http://127.0.0.1:${PROXY_PORT}"
    export HTTPS_PROXY="http://127.0.0.1:${PROXY_PORT}"
fi

terraform init -input=false
terraform plan -input=false
terraform apply -auto-approve -input=false

echo ""
echo "VM IP: $(terraform output -raw vm_ipv4)"
echo "Key:   $(terraform output -raw private_key_path)"
echo "Pass:  $(terraform output -raw admin_password)"
echo ""
terraform output -raw vnc_tunnel_command
terraform output -raw ollama_tunnel_command
