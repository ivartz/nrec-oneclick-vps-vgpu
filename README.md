# Hermes VPS — One-Click OpenStack Deployment

Ubuntu 24.04 LTS VPS on NREC OpenStack with GNOME desktop (TurboVNC), NVIDIA vGPU, Ollama, Hermes Desktop, Chromium, and Obsidian. Terraform + cloud-init only.

## Prerequisites

- Terraform >= 1.5
- NREC OpenStack credentials
- SSH + VNC client

## Deploy

```bash
cp env.sh.template env.sh   # fill in credentials
bash deploy.sh              # Linux, macOS, Termux
```

Windows: `powershell -ExecutionPolicy Bypass -File deploy.ps1`

Termux: `deploy.sh` auto-starts `https_proxy.py` (DNS workaround) and uses the offline provider mirror.

## After deploy

```bash
ssh -i keys/<id>.pem ubuntu@<ip>
sudo -u hermes /opt/TurboVNC/bin/vncserver :1
```

The default session is GNOME Flashback (Metacity) — a lightweight classic
desktop. To use the modern GNOME desktop instead, pass `-wm gnome`:

```bash
sudo -u hermes /opt/TurboVNC/bin/vncserver :1 -wm gnome              # modern GNOME
sudo -u hermes /opt/TurboVNC/bin/vncserver :1 -wm gnome-flashback-metacity  # flashback (default)
```

Connect VNC via tunnel:
```bash
ssh -L 55901:localhost:5901 -i keys/<id>.pem ubuntu@<ip>
# vncviewer localhost:55901
```

End VNC session:
```bash
sudo -u hermes /opt/TurboVNC/bin/vncserver -kill :1
```

Passwords (all the same):
- VNC password: `cat keys/<id>.vncpass` (local)
- On VM: `cat /home/ubuntu/.vnc-passwd` or `cat /home/hermes/.admin-password`

## Verify

```bash
nvidia-smi
curl http://localhost:11434/api/tags
which chromium
hermes --version
```

## Network

- NREC IPv6 network (public IPv6, private IPv4) or dualStack fallback
- SSH-only ingress, locked to operator IP
- No floating IPs, no public VNC/Ollama ports

## Tear down

```bash
terraform destroy
```
