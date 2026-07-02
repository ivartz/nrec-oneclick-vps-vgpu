# Hermes VPS — One-Click OpenStack Deployment

Spins up an Ubuntu 24.04 LTS VPS on NREC OpenStack with everything pre-installed:

1. GNOME desktop + RDP via xrdp
2. NVIDIA vGPU verification (nvidia-smi)
3. Ollama with `ornith` model
4. Hermes Desktop (connected to local Ollama)
5. Obsidian with shared vault

## Overview

Terraform + cloud-init. Single GPU-enabled VM. Ready-to-use remote workstation.

## Prerequisites

- Terraform >= 1.5
- NREC OpenStack credentials (API access)
- Your local machine must have SSH and an RDP client (Windows App on macOS, Remmina on Linux, mstsc on Windows)

## File layout

| File | Purpose |
|------|---------|
| main.tf | OpenStack resources + cloud-init wait |
| cloud-init.yaml.tftpl | In-guest bootstrap (GNOME, Ollama, Hermes, Obsidian) |
| variables.tf | Input variables |
| outputs.tf | Outputs (IPs, passwords, tunnel commands) |
| versions.tf | Provider pinning |
| env.sh | OpenStack credentials (source before apply) |
| terraform.tfvars | NREC-specific values |
| terraform.tfvars.example | Example config with placeholders |

## Usage — first time

1. Copy env.sh values or source it:
   ```
   source env.sh
   ```

2. Review terraform.tfvars — adjust flavor, image, or model if needed.

3. Initialize and apply:
   ```
   terraform init
   terraform apply
   ```

4. Terraform will output:
   - VM IPv4 / IPv6
   - Admin password (sensitive — use `-json` or `terraform output admin_password`)
   - SSH command
   - RDP tunnel command
   - Ollama tunnel command

5. Start the RDP tunnel:
   ```
   <rdp_tunnel_command from output>
   ```

6. Connect your RDP client to `localhost:53389`.

7. Log in with `hermes` / `<admin_password>`.

## Two-user model

- **ubuntu** — created by the Ubuntu cloud image; SSH keys are auto-injected via cloud-init (no OpenStack keypair).
- **hermes** — created by cloud-init with a random password; for RDP/desktop login and console access.

## Network

- Default: NREC IPv6 network (public IPv6, private IPv4 via NAT).
- Fallback: dualStack if your local machine has no IPv6 (public IPv4 + IPv6).
- No floating IPs.
- Security group: SSH-only ingress locked to your IP (/32 IPv4, /128 IPv6).

## Connecting

Start the RDP tunnel (from terraform output):
```
ssh -L 53389:localhost:3389 -i keys/hermes-<id>.pem ubuntu@<vm_ip>
```

Then connect your RDP client:
- macOS: Windows App -> Add PC -> localhost:53389
- Linux: Remmina -> localhost:53389
- Windows: mstsc -> localhost:53389

Ollama API (optional tunnel):
```
ssh -L 51434:localhost:11434 -i keys/hermes-<id>.pem ubuntu@<vm_ip>
```

## Deployment lifecycle

- Fresh deploy: `terraform apply`
- Re-run for existing: set `deployment_id` in terraform.tfvars, then `terraform apply`
- Tear down: `terraform destroy`

## Notes

- xrdp provides RDP for headless VMs (spawns GNOME session per connection).
- NVIDIA vGPU driver is pre-installed in the NREC image; cloud-init verifies with `nvidia-smi`.
- Ollama runs as a systemd service, accessible at localhost:11434 inside the VM.
- Obsidian vault at `/home/hermes/Documents/ObsidianVault`.
- Terraform waits for cloud-init to finish via `null_resource` (checks `/var/lib/cloud/instance/boot-finished`), then prints all outputs.

## Smoke test (after apply)

```bash
ssh -i keys/hermes-<id>.pem ubuntu@<ip>
```

Then verify inside the VM:
```bash
nvidia-smi                           # should show L40S-24Q
curl http://localhost:11434/api/tags # should show ornith
hermes version                       # should show v0.18.0+
dpkg -l obsidian                     # should show v1.7.7
systemctl is-active xrdp             # should show active
```

## Tear down

```
terraform destroy
```

Removes the VM, security group, keypair, and all supporting resources.
