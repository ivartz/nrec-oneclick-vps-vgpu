# deploy.ps1 — One-click NREC OpenStack VPS deployment on Windows 10/11
#
# Prerequisites:
#   1. Terraform installed (https://developer.hashicorp.com/terraform/install)
#      PowerShell: winget install Terraform --source winget
#   2. Edit env.ps1 and fill in your NREC OpenStack credentials
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File deploy.ps1
#
# What it does:
#   - Provisions an Ubuntu 24.04 VM with NVIDIA vGPU
#   - Installs GNOME + TurboVNC (Xorg VNC)
#   - Installs Ollama + nemotron-mini model
#   - Installs Hermes Desktop
#   - Installs Obsidian with shared vault
#   - Outputs SSH, VNC, and Ollama tunnel commands

$ErrorActionPreference = "Stop"
$ProgressPreference    = "SilentlyContinue"

# ---------------------------------------------------------------------------
# Configuration — edit env.ps1 instead of this file
# ---------------------------------------------------------------------------
$envFile = Join-Path $PSScriptRoot "env.ps1"
if (-not (Test-Path $envFile)) {
    Write-Host "ERROR: env.ps1 not found. Copy env.ps1.example and fill in your credentials." -ForegroundColor Red
    exit 1
}
. $envFile

# Verify required environment variables
$required = @("OS_USERNAME", "OS_PASSWORD", "OS_AUTH_URL")
foreach ($var in $required) {
    if (-not (Get-ItemVariable "env:$var" -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR: $env:$var is not set. Edit env.ps1 and fill in your credentials." -ForegroundColor Red
        exit 1
    }
}

# ---------------------------------------------------------------------------
# Detect operator public IP
# ---------------------------------------------------------------------------
function Get-OperatorIP {
    try {
        $ip = (Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 5)
        Write-Host "Detected public IPv4: $ip"
        return $ip
    } catch {
        Write-Host "Could not auto-detect public IP — SSH will be open to 0.0.0.0/0" -ForegroundColor Yellow
        return ""
    }
}

$operatorIp = Get-OperatorIP

# ---------------------------------------------------------------------------
# Write terraform.tfvars with runtime values
# ---------------------------------------------------------------------------
$tfvarsPath = Join-Path $PSScriptRoot "terraform.tfvars"
$tfvarsContent = @"
flavor_name          = "gr1.L40S.24g.4xlarge"
image_name           = "vGPU Ubuntu 24.04 LTS"
admin_user           = "hermes"
ssh_user             = "ubuntu"
ollama_model         = "ornith"
local_vnc_port       = 5901
local_ollama_port    = 51434
operator_public_ip   = "$operatorIp"
operator_public_ipv6 = ""
"@

# Use a fresh random deployment_id
Write-Host "Generating fresh deployment name..." -ForegroundColor Cyan
$suffix = -join ((48..57) + (97..122) | Get-Random -Count 6 | ForEach-Object { [char]$_ })
$deploymentId = "hermes-$suffix"
$tfvarsContent += "`ndeployment_id        = `"$deploymentId`""

Set-Content -Path $tfvarsPath -Value $tfvarsContent -Encoding UTF8
Write-Host "Deployment ID: $deploymentId" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Terraform init + apply
# ---------------------------------------------------------------------------
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  Deploying $deploymentId" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Set-Location $PSScriptRoot

# ---------------------------------------------------------------------------
# Offline provider mirror (optional)
# On Windows, Go DNS resolves natively — no HTTPS proxy needed (unlike
# Termux/Android). TF_CLI_CONFIG_FILE is only set if .terraformrc exists AND
# its mirror path is valid; otherwise terraform downloads from the registry.
# ---------------------------------------------------------------------------
$tfrc = Join-Path $PSScriptRoot ".terraformrc"
if (Test-Path $tfrc) {
    $mirrorLine = (Get-Content $tfrc | Where-Object { $_ -match '^\s*path\s*=' })
    if ($mirrorLine -match '"([^"]+)"') {
        $mirrorPath = $Matches[1]
        if (Test-Path $mirrorPath) {
            $env:TF_CLI_CONFIG_FILE = $tfrc
            Write-Host "Using offline provider mirror: $mirrorPath" -ForegroundColor Cyan
        } else {
            Write-Host "Note: .terraformrc mirror path not found ($mirrorPath) — downloading providers from registry" -ForegroundColor Yellow
        }
    }
}

Write-Host "[1/3] terraform init..." -ForegroundColor Yellow
terraform init -input=false
if ($LASTEXITCODE -ne 0) { throw "terraform init failed" }

Write-Host "`n[2/3] terraform plan..." -ForegroundColor Yellow
$planOutput = terraform plan -input=false
if ($LASTEXITCODE -ne 0) { throw "terraform plan failed" }

# Show summary
$match = [regex]::Match($planOutput, 'Plan: (\d+) to add, \d+ to change, \d+ to destroy\.')
if ($match.Success) {
    Write-Host "Plan: $($match.Groups[1].Value) resources to create" -ForegroundColor Cyan
}

Write-Host "`n[3/3] terraform apply (this takes 5-10 minutes for cloud-init)..." -ForegroundColor Yellow
$applyOutput = terraform apply -auto-approve -input=false
if ($LASTEXITCODE -ne 0) {
    Write-Host "`nERROR: terraform apply failed. Check the output above." -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------------------
# Extract outputs
# ---------------------------------------------------------------------------
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  DEPLOYMENT COMPLETE" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

$vmIp      = (terraform output -raw vm_ipv4 2>$null)
$sshCmd    = (terraform output -raw ssh_command 2>$null)
$vncCmd    = (terraform output -raw vnc_tunnel_command 2>$null)
$ollamaCmd = (terraform output -raw ollama_tunnel_command 2>$null)
$adminUser = (terraform output -raw admin_user 2>$null)
$adminPwd  = (terraform output -raw admin_password 2>$null)
$keyPath   = (terraform output -raw private_key_path 2>$null)

Write-Host "VM IP: $vmIp"
Write-Host "Private key: $keyPath"
Write-Host "Admin user: $adminUser"
Write-Host "Admin password: $adminPwd"
Write-Host ""
Write-Host "--- SSH ---" -ForegroundColor Cyan
Write-Host $sshCmd
Write-Host ""
Write-Host "--- VNC tunnel (START FIRST, then connect VNC client to localhost:5901) ---" -ForegroundColor Cyan
Write-Host $vncCmd
Write-Host ""
Write-Host "--- Ollama tunnel ---" -ForegroundColor Cyan
Write-Host $ollamaCmd
Write-Host ""
Write-Host "--- Verify services (after SSH) ---" -ForegroundColor Cyan
Write-Host "  cloud-init status --long"
Write-Host "  nvidia-smi"
Write-Host "  systemctl is-active ollama"
Write-Host "  vncserver :1                              # start TurboVNC manually"
Write-Host ""
Write-Host "--- Destroy ---" -ForegroundColor Yellow
Write-Host "  powershell -ExecutionPolicy Bypass -File deploy.ps1 -Destroy"
