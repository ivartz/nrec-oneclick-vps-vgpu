$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
Set-Location $PSScriptRoot

$envFile = Join-Path $PSScriptRoot "env.ps1"
if (-not (Test-Path $envFile)) { Write-Host "ERROR: env.ps1 not found" -ForegroundColor Red; exit 1 }
. $envFile

foreach ($v in @("OS_USERNAME", "OS_PASSWORD", "OS_AUTH_URL")) {
    if (-not (Get-ItemVariable "env:$v" -ErrorAction SilentlyContinue)) { Write-Host "ERROR: $v not set in env.ps1" -ForegroundColor Red; exit 1 }
}

$operatorIp = try { (Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 5) } catch { "" }

$tfvars = @"
flavor_name          = "gr1.L40S.24g.4xlarge"
image_name           = "vGPU Ubuntu 24.04 LTS"
admin_user           = "hermes"
ssh_user             = "ubuntu"
ollama_model         = "ornith"
local_vnc_port       = 55901
local_ollama_port    = 51434
operator_public_ip   = "$operatorIp"
operator_public_ipv6 = ""
"@
$deploymentId = "hermes-$(-join ((48..57) + (97..122) | Get-Random -Count 6 | ForEach-Object { [char]$_ }))"
$tfvars += "`ndeployment_id        = `"$deploymentId`""
$tfvars += "`ninsecure             = false"
Set-Content -Path (Join-Path $PSScriptRoot "terraform.tfvars") -Value $tfvars -Encoding UTF8
Write-Host "Deploying $deploymentId..."

$tfrc = Join-Path $PSScriptRoot ".terraformrc"
if (Test-Path $tfrc) {
    $m = (Get-Content $tfrc | Select-String 'path\s*=\s*"([^"]+)"')
    if ($m -and (Test-Path $m.Matches[0].Groups[1].Value)) { $env:TF_CLI_CONFIG_FILE = $tfrc }
}

terraform init -input=false
if ($LASTEXITCODE) { throw "init failed" }
terraform plan -input=false
if ($LASTEXITCODE) { throw "plan failed" }
terraform apply -auto-approve -input=false
if ($LASTEXITCODE) { Write-Host "ERROR: apply failed" -ForegroundColor Red; exit 1 }

Write-Host "`nVM IP: $(terraform output -raw vm_ipv4)"
Write-Host "Key:   $(terraform output -raw private_key_path)"
Write-Host "Pass:  $(terraform output -raw admin_password)"
Write-Host ""
Write-Host (terraform output -raw vnc_tunnel_command)
Write-Host (terraform output -raw ollama_tunnel_command)
