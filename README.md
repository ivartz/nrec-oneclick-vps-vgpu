# Hermes VPS — One-Click OpenStack Deployment

Spins up an Ubuntu 24.04 LTS VPS on NREC OpenStack with GNOME desktop accessed via TurboVNC:

1. GNOME desktop with Xorg (GNOME Classic) + TurboVNC
2. NVIDIA vGPU verification (nvidia-smi)
3. Ollama with configurable model
4. Hermes Desktop (connected to local Ollama)
5. Obsidian with vault directory

## Overview

Terraform + cloud-init. Single GPU-enabled VM. Ready-to-use remote workstation. Uses Xorg with GNOME Classic since TurboVNC does not support Wayland.

## Prerequisites

- Terraform >= 1.5
- NREC OpenStack credentials (API access)
- SSH client and VNC client (TigerVNC, RealVNC, or similar)

## File layout

| File | Purpose |
|------|---------|
| main.tf | OpenStack resources + cloud-init wait |
| cloud-init.yaml.tftpl | In-guest bootstrap (GNOME, TurboVNC, Ollama, Hermes, Obsidian) |
| variables.tf | Input variables |
| outputs.tf | Outputs (IPs, passwords, tunnel commands) |
| versions.tf | Provider pinning |
| env.sh | OpenStack credentials (source before apply) |
| env.sh.template | Template for safe credential management |
| terraform.tfvars | NREC-specific values |
| terraform.tfvars.example | Example config with placeholders |
| deploy.sh | One-click deploy script (Linux, macOS, Termux) |
| deploy.ps1 | One-click deploy script (Windows PowerShell) |
| https_proxy.py | Termux DNS workaround proxy (auto-started by deploy.sh) |
| .terraformrc | Offline provider mirror config (Termux) |

## Usage — first time

1. Copy env.sh.template to env.sh and fill in real credentials:
   ```
   cp env.sh.template env.sh
   nano env.sh
   ```

2. Review terraform.tfvars — adjust flavor, image, or model if needed.

3. Initialize and apply:
   ```
   source env.sh
   terraform init
   terraform apply
   ```

4. Terraform outputs:
   - VM IPv4 / IPv6
   - Admin password
   - SSH command

## One-click deploy scripts

Instead of running terraform manually, use the deploy scripts which handle credentials, tfvars generation, and platform-specific setup:

- **Linux / macOS:** `bash deploy.sh`
- **Windows PowerShell:** `powershell -ExecutionPolicy Bypass -File deploy.ps1`

The scripts auto-detect your public IP, generate a random deployment ID, write terraform.tfvars, and run init + apply.

## Termux / Android

Terraform on Termux has two quirks that prevent direct operation; `deploy.sh` handles both automatically:

1. **DNS resolution fails.** Terraform is built with Go's `netgo` resolver, which reads `/etc/resolv.conf`. On Android, `/etc` is a read-only symlink to `/system/etc` with no `resolv.conf`, so every DNS lookup fails. `deploy.sh` starts `https_proxy.py` — a local HTTPS CONNECT proxy that resolves DNS via Python's libc resolver (which works on Termux) — and routes terraform through it via `HTTP_PROXY`/`HTTPS_PROXY` on `127.0.0.1:9080`.

2. **No registry access.** Termux cannot reach `registry.terraform.io` for provider downloads. The `.terraformrc` file points to a local mirror (`.terraform-mirror/`) containing all required providers. `deploy.sh` sets `TF_CLI_CONFIG_FILE` to use it. On other platforms, if the mirror path doesn't exist, the scripts fall back to downloading from the registry.

To deploy from Termux:

```bash
bash deploy.sh
```

No manual proxy setup or environment variables needed — the script detects Termux and configures everything.

## After deployment

### Start TurboVNC via SSH:
```bash
ssh -i keys/<deployment_id>.pem ubuntu@<vm_ip>
su - ${admin_user} -c 'vncserver :1'
```

### Connect VNC client via SSH tunnel:
```bash
ssh -L 55901:localhost:5901 -i keys/<deployment_id>.pem ubuntu@<vm_ip>
```

Connect VNC client to localhost:55901.
Password: admin_password from terraform output.

Note: TurboVNC uses Xorg with GNOME Classic (gnome-session-flashback).

## Two-user model

- **ubuntu** — created by Ubuntu cloud image; SSH keys auto-injected via cloud-init
- **hermes** — created by cloud-init with random password; for desktop login

## Network

- Default: NREC IPv6 network (public IPv6, private IPv4 via NAT)
- Fallback: dualStack if local machine has no IPv6
- No floating IPs
- Security group: SSH-only ingress locked to your IP (/32 IPv4, /128 IPv6)

## Notes

- TurboVNC replaces GNOME Remote Desktop (which requires initial login)
- TurboVNC must be started manually after SSH login (headless limitation)
- TurboVNC server continues running until explicitly stopped
- NVIDIA vGPU driver is pre-installed in NREC image; cloud-init verifies with nvidia-smi
- Ollama runs as systemd service at localhost:11434
- Obsidian vault at /home/<admin_user>/Documents/ObsidianVault
- Terraform waits for cloud-init via /var/lib/cloud/instance/boot-finished

## Smoke test (after apply)

```bash
ssh -i keys/<deployment_id>.pem ubuntu@<ip>
```

Verify inside VM:
```bash
nvidia-smi                              # should show GPU info
curl http://localhost:11434/api/tags   # should show model list
hermes version                          # should show version
dpkg -l obsidian                        # should show 1.7.7
vncserver :1                            # should start TurboVNC
```

Stop TurboVNC session:
```bash
vncserver -kill :1
```

## Tear down

```
terraform destroy
```

Removes VM, security group, keypair, all supporting resources.