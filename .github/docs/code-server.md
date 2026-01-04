# Ubuntu Code Server Workflow Guide

This workflow provides a high-performance Ubuntu ARM64 development environment accessible via your browser.

## Overview

The `ubuntu-code-server.yml` workflow sets up a comprehensive development stack:
- **IDE:** [code-server](https://github.com/coder/code-server) (VS Code in the browser)
- **Data Science:** Jupyter Lab with Miniconda
- **Web Development:** Node.js (nvm), Yarn, pnpm
- **Desktop:** XFCE VNC Server (optional)

## How to Start

1. Go to **Actions** > **Ubuntu Code server**.
2. Click **Run workflow**.
3. (Optional) Provide `VNC_PASSWORD`, `NGROK_AUTH_TOKEN`, or `TAILSCALE_AUTH_KEY` as secrets to customize access.

## How to Connect

Once the workflow is running, wait for the `Save connection info` step to complete.

### Method 1: Ngrok (Easiest)
Check the `vnc-connection-info` artifact or the workflow logs for the Ngrok URLs:
- **Code-Server:** `https://<random-id>.ngrok-free.app` (Port 8080)
- **Jupyter Lab:** `https://<random-id>.ngrok-free.app` (Port 8888)
- **VNC:** `tcp://<random-id>.tcp.ngrok.io:<port>` (Port 5900)

### Method 2: Tailscale (Secure VPN)
Connect your local machine to Tailscale, then use the runner's Tailscale IP:
- **code-server:** `http://<tailscale-ip>:8080`
- **Jupyter:** `http://<tailscale-ip>:8888`
- **VNC:** `<tailscale-ip>:5900`

### Method 3: SSH (Command Line)
Directly connect to the terminal via Tailscale:
```bash
ssh runner@<tailscale-ip>
```
- **User:** `runner`
- **Password:** Same as your VNC/Code-Server password (`vncpassword` by default).

## Pre-installed Software

### Python & Data Science
- **Environment:** Miniconda3
- **Libraries:** `numpy`, `pandas`, `scipy`, `matplotlib`, `scikit-learn`
- **Tools:** `pytest`, `black`, `pylint`, `ipython`

### Web Development
- **Node.js:** LTS (via nvm)
- **Package Managers:** `npm`, `yarn`, `pnpm`
- **Tools:** `typescript`, `ts-node`, `nodemon`

### VS Code Extensions
- Python (Microsoft)
- ESLint
- Prettier
- Tailwind CSS IntelliSense

## Termination
The workflow will run for up to **360 minutes**. To stop it early, manually **Cancel** the workflow run in the Actions tab.
