# VS Code Configuration Script
# Run this in the runner or add to workflow

# Install extensions
$extensions = @(
    "GitHub.copilot",
    "GitHub.copilot-chat", 
    "ms-python.python",
    "dbaeumer.vscode-eslint",
    "esbenp.prettier-vscode",
    "bradlc.vscode-tailwindcss",
    "continue.continue"
)

foreach ($ext in $extensions) {
    Write-Host "Installing extension: $ext"
    code --install-extension $ext
}

# Configure settings
$settingsPath = "$env:APPDATA\Code\User\settings.json"
$settings = @{
    "github.copilot.enable" = @{
        "asterisk" = $true
        "inlineSuggest" = @{
            "enable" = $true
        }
    }
    "editor.fontSize" = 14
    "editor.fontFamily" = "'Fira Code', 'Courier New', monospace"
    "workbench.colorTheme" = "Default Dark+"
    "python.defaultInterpreterPath" = "python"
    "extensions.autoUpdate" = $false
}

# Ensure directory exists
New-Item -ItemType Directory -Force -Path (Split-Path $settingsPath) | Out-Null

# Write settings
$settings | ConvertTo-Json -Depth 10 | Out-File -FilePath $settingsPath -Encoding utf8

Write-Host "VS Code configuration completed!"
