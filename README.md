# VPS Remote Access Workflows

This repository contains GitHub Actions workflows designed to provide secure, temporary remote access to GitHub-hosted runners for Ubuntu (via VNC), Windows (via RDP), and macOS (via VNC). These workflows are ideal for debugging, interactive development, or performing tasks that require a desktop environment.

## Available Workflows

| Workflow | File | Runner | Access | Description |
|----------|------|--------|--------|-------------|
| **Windows AI Server** | `windows-ai-editor.yml` | `windows-latest` | RDP over Tailscale | Windows with **Cursor** and **Windsurf** AI editors pre-installed |
| **Windows RDP Server** | `windows-rdp.yml` | `windows-latest` | RDP over Tailscale | Windows with VS Code pre-installed |
| **Ubuntu VNC (GNOME)** | `ubuntu-vnc.yml` | `ubuntu-24.04` | VNC over Tailscale | Ubuntu with GNOME desktop |
| **Ubuntu VNC (XFCE)** | `ubuntu-vnc-new.yml` | `ubuntu-24.04-arm` | VNC over Tailscale/ngrok | ARM64 Ubuntu with lightweight XFCE desktop |
| **macOS VNC Server** | `macos-vnc.yml` | `macos-13` | VNC over Tailscale | macOS Ventura with Vine Server |

## Required Secrets

Go to **Settings** → **Secrets and variables** → **Actions** → **New repository secret** to add these:

### Required for All Workflows

| Secret | Required | Description |
|--------|----------|-------------|
| `TAILSCALE_AUTH_KEY` | **Yes** | Reusable auth key from [Tailscale Admin Console](https://login.tailscale.com/admin/settings/keys) |

### Optional Secrets

| Secret | Used By | Description |
|--------|---------|-------------|
| `RDP_PASSWORD` | Windows workflows | Fixed RDP password for user `vum`. If not set, a random password is generated each run |
| `VNC_PASSWORD` | `ubuntu-vnc-new.yml` | Fixed VNC password. If not set, defaults to `vncpassword` |
| `NGROK_AUTH_TOKEN` | `ubuntu-vnc-new.yml` | [ngrok](https://ngrok.com/) auth token for public tunnel access (alternative to Tailscale) |

## Quick Start

1. **Fork this repository** to your GitHub account

2. **Add required secrets:**
   ```
   TAILSCALE_AUTH_KEY = tskey-auth-xxxxx-xxxxxxxxx
   ```

3. **Run a workflow:**
   - Go to **Actions** tab
   - Select a workflow (e.g., "Windows AI Server")
   - Click **Run workflow**

4. **Connect:**
   - Check the workflow logs for connection details
   - Connect via your Tailscale client using the displayed IP address

## Workflow Details

### Windows AI Server (`windows-ai-editor.yml`)

Provisions a Windows runner with AI-powered code editors:

- **Pre-installed editors:**
  - [Cursor](https://cursor.sh/) - AI-first code editor
  - [Windsurf](https://windsurf.com/) - Codeium's AI IDE
- **Access:** RDP on port 3389 via Tailscale
- **Username:** `vum`
- **Password:** From `RDP_PASSWORD` secret or shown in logs
- **Editors location:** `C:\AI_Editors\` with shortcuts on Public Desktop

### Windows RDP Server (`windows-rdp.yml`)

Basic Windows runner with VS Code:

- **Pre-installed:** Visual Studio Code (via Chocolatey)
- **Access:** RDP on port 3389 via Tailscale
- **Username:** `vum`
- **Password:** Shown in workflow logs (random each run)

### Ubuntu VNC - GNOME (`ubuntu-vnc.yml`)

Full GNOME desktop on Ubuntu:

- **Desktop:** GNOME
- **Access:** VNC on port 5900 via Tailscale
- **Password:** Shown in workflow logs (random each run)

### Ubuntu VNC - XFCE (`ubuntu-vnc-new.yml`)

Lightweight XFCE desktop on ARM64:

- **Desktop:** XFCE4
- **Access:** VNC on port 5900 via Tailscale or ngrok
- **Password:** From `VNC_PASSWORD` secret or `vncpassword`
- **Includes:** Chromium browser with desktop shortcut

### macOS VNC Server (`macos-vnc.yml`)

macOS Ventura with Vine Server:

- **VNC Server:** Vine Server (OSXvnc)
- **Access:** VNC on port 5900 via Tailscale
- **Password:** Shown in workflow logs (random each run)

## Session Duration

| Workflow | Timeout |
|----------|---------|
| Windows workflows | 60 hours (3600 min) |
| Ubuntu GNOME | 60 hours (3600 min) |
| Ubuntu XFCE (ARM) | 6 hours (360 min) |
| macOS | 60 hours (3600 min) |

> **Note:** GitHub may terminate workflows earlier based on their usage policies.

## Connecting

### Via Tailscale (Recommended)

1. Install [Tailscale](https://tailscale.com/download) on your local machine
2. Log in with the same account used for `TAILSCALE_AUTH_KEY`
3. Use the Tailscale IP shown in workflow logs:
   - **Windows:** `mstsc /v:<TAILSCALE_IP>` or Remote Desktop app
   - **VNC:** Any VNC client to `<TAILSCALE_IP>:5900`

### Via ngrok (Ubuntu XFCE only)

1. Set `NGROK_AUTH_TOKEN` secret
2. Check workflow logs or download the `vnc-connection-info` artifact
3. Connect to the ngrok tunnel URL with any VNC client

## Contributing

Feel free to fork this repository, open issues, or submit pull requests to improve these workflows.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
