# VPS Remote Access Workflows

This repository contains GitHub Actions workflows designed to provide secure, temporary remote access to GitHub-hosted runners for both Ubuntu (via VNC) and Windows (via RDP). These workflows are ideal for debugging, interactive development, or performing tasks that require a desktop environment or direct shell access on a runner.

## Features

-   **Ubuntu VNC Server:** Provision an Ubuntu runner with a GNOME desktop and access it securely via VNC over Tailscale.
-   **Windows RDP Server:** Provision a Windows runner and access it securely via RDP over Tailscale.
-   **Secure Access:** All remote connections are tunneled through [Tailscale](https://tailscale.com/), providing a secure, peer-to-peer VPN connection.
-   **Dynamic Credentials:** VNC and RDP passwords are generated dynamically for each workflow run, ensuring unique and temporary access.
-   **Long-Running Sessions:** Workflows are configured for extended sessions, allowing ample time for your tasks.

## Getting Started

### Prerequisites

To use these workflows, you will need:

1.  **GitHub Account:** To run the workflows in your repository.
2.  **Tailscale Account:** A free Tailscale account is required to connect to the VPN.
3.  **Tailscale Auth Key:** You need to generate a reusable authentication key from your Tailscale admin console. This key will be stored as a GitHub Secret.

### Setup

1.  **Fork this Repository (Optional but Recommended):** It's recommended to fork this repository to your own GitHub account to customize and run the workflows.
2.  **Add Tailscale Auth Key to GitHub Secrets:**
    -   Go to your repository settings on GitHub.
    -   Navigate to `Secrets and variables` -> `Actions`.
    -   Click on `New repository secret`.
    -   Name the secret `TAILSCALE_AUTH_KEY`.
    -   Paste your generated Tailscale authentication key into the `Value` field.
    -   Click `Add secret`.

## Usage

Detailed instructions on how to run and connect to each workflow are provided in the dedicated workflows documentation:

➡️ **[View Detailed Workflows Documentation](./.github/docs/WORKFLOWS.md)**

## Contributing

Feel free to fork this repository, open issues, or submit pull requests to improve these workflows.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
