# Token Storage and Usage Explanation

In the context of this repository's workflows, the primary "token" is the **Tailscale Authentication Key**. This key is used to securely connect the GitHub-hosted runner to your Tailscale VPN.

## Where is the token stored?

The Tailscale authentication key is not stored in any file within this repository. Instead, it is stored as a **GitHub Secret**.

### What are GitHub Secrets?

GitHub Secrets are encrypted environment variables that you create in a repository or organization. They are the standard and secure way to store sensitive information, like tokens, passwords, or API keys, that are needed in GitHub Actions workflows.

Key characteristics of GitHub Secrets:
-   **Encrypted:** Secrets are encrypted and only exposed to the workflow run that you explicitly allow.
-   **Secure:** GitHub automatically redacts secrets that are printed to the logs.
-   **Managed:** You can manage secrets in your repository's settings under `Settings` > `Secrets and variables` > `Actions`.

In this project, the secret is expected to be named `TAILSCALE_AUTH_KEY`.

## How is the token used in the workflows?

The `TAILSCALE_AUTH_KEY` secret is accessed within the workflow files using the `${{ secrets.TAILSCALE_AUTH_KEY }}` syntax.

### 1. Ubuntu VNC Workflow (`.github/workflows/ubuntu-vnc.yml`)

The secret is used directly in a `run` step to authenticate with Tailscale.

```yaml
      - name: Connect to Tailscale
        run: |
          sudo tailscale up --authkey=${{ secrets.TAILSCALE_AUTH_KEY }} --hostname=gh-runner-${GITHUB_RUN_ID}
          echo "TAILSCALE_IP=$(tailscale ip -4)" >> "$GITHUB_ENV"
```
Here, `sudo tailscale up --authkey=` receives the secret value directly from the GitHub Actions runner environment.

### 2. Windows RDP Workflow (`.github/workflows/windows-rdp.yml`)

In the Windows workflow, the secret is first passed as an environment variable (`TAILSCALE_AUTH_KEY`) to a PowerShell script.

```yaml
      - name: Establish Tailscale Connection
        shell: pwsh
        env:
          TAILSCALE_AUTH_KEY: ${{ secrets.TAILSCALE_AUTH_KEY }}
        run: .github/workflows/scripts/win-establish-ts.ps1
```

The script `win-establish-ts.ps1` then uses this environment variable to run the Tailscale command.

```powershell
# From .github/workflows/scripts/win-establish-ts.ps1

& "$env:ProgramFiles\Tailscale\tailscale.exe" up --authkey=$env:TAILSCALE_AUTH_KEY --hostname=gh-runner-$env:GITHUB_RUN_ID
```

In both cases, the secret value is securely passed to the `tailscale` command without ever being exposed in the workflow logs or committed to the repository's code.
