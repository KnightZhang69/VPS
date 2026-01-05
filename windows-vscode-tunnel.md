# Windows Runner: VS Code Remote Tunnel (Browser Access)

This document explains how to (re)start from a **running Windows GitHub Actions runner** and get **VS Code in your browser** via **Remote Tunnel**.

> Your tunnel name in this repo is typically:
>
> `gh-<GITHUB_RUN_ID>`
>
> Example URL:
>
> `https://vscode.dev/tunnel/gh-20711697574`

---

## Preconditions

- The **GitHub Actions workflow run is still running** (runner is alive).
- VS Code is installed on the runner (your workflow installs it via Chocolatey).
- You have access to the workflow logs **or** you can RDP into the runner.

---

## A) Start tunnel from workflow logs (normal path)

### 1) Open the workflow run logs

- GitHub → **Actions** → your workflow run
- Open step: `Start VS Code Remote Tunnel (Web IDE)`

### 2) Find the device login prompt

You should see something like:

- `To grant access to the server, please log into https://github.com/login/device and use code XXXX-XXXX`

### 3) Complete GitHub device login

1. Open: `https://github.com/login/device`
2. Sign in with the **GitHub account that will own the tunnel**
3. Enter the device code from logs
4. Authorize

### 4) Open the browser IDE

Open the URL printed in logs:

- `https://vscode.dev/tunnel/gh-<RUN_ID>`

If you get “找不到名为 … 的隧道 / tunnel not found”:

- In `vscode.dev`, click **选择其他帐户**
- Sign in using the **same GitHub account** you used at `github.com/login/device`

---

## B) Start tunnel directly on the runner (best for troubleshooting)

If you can RDP into the runner, start the tunnel in the foreground so you can see output.

### 1) Open PowerShell on the runner

### 2) Run tunnel command

```powershell
$codeCmd = "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd"
& $codeCmd tunnel --accept-server-license-terms --name "gh-$env:GITHUB_RUN_ID"
```

Keep this PowerShell window open. It should print:

- device login URL + device code

### 3) Complete device login

Same as Section A-3:

- `https://github.com/login/device`
- enter the code
- authorize

### 4) Open the browser IDE

- `https://vscode.dev/tunnel/gh-<RUN_ID>`

---

## C) Verify tunnel is running (on the runner)

Run these on the runner (PowerShell):

```powershell
Get-Process code -ErrorAction SilentlyContinue
Get-Process node -ErrorAction SilentlyContinue
```

If the tunnel was started in the foreground, the PowerShell session running `code tunnel ...` should still be active.

---

## Common Problems & Fixes

### 1) “找不到名为 <tunnel> 的隧道 / tunnel not found”

Most common causes:

- You are signed into **a different GitHub account** on `vscode.dev`
- Device login was not completed or expired
- The workflow ended / runner stopped (tunnel disappears)

Fix:

- Complete device login again (rerun workflow if code expired)
- In `vscode.dev`, switch to the account used for device login
- Ensure workflow run is still **in progress**

### 2) Device code expired

- Re-run the workflow to generate a new code
- Complete login again

### 3) Runner finished / cancelled

- Start a new workflow run
- Use the new `gh-<RUN_ID>` tunnel URL

---

## Notes about “Where does compute run?”

When you access `vscode.dev/tunnel/...`:

- All terminals, builds, and file operations run on the **GitHub runner**.
- Your browser is only the UI.

---

## Recommended persistence

Because runners are ephemeral, to keep consistent settings:

- Enable **VS Code Settings Sync** (cloud)
- Keep repo `.vscode/settings.json` and `.vscode/extensions.json` (applied each run by workflow)

---

## Quick Checklist

- Workflow run is **still running**
- Device login completed at `https://github.com/login/device`
- Same GitHub account used in `vscode.dev`
- Open `https://vscode.dev/tunnel/gh-<RUN_ID>`
