# .github/workflows/scripts/win-install-editors.ps1

Write-Host "--- Installing AI Editors (Cursor & Windsurf) ---"

$destBase = "C:\AI_Editors"
New-Item -ItemType Directory -Force -Path $destBase | Out-Null
$publicDesktop = [Environment]::GetFolderPath("CommonDesktopDirectory")

function Install-Editor {
    param (
        [string]$Name,
        [string]$Url,
        [string]$ProcessName
    )

    Write-Host "Processing $Name..."
    $installer = "$env:TEMP\$Name-setup.exe"
    
    # 1. Download using curl.exe with DNS over HTTPS (DoH)
    # The runner's local DNS is failing, so we force curl to resolve via Cloudflare (HTTPS).
    Write-Host "Downloading $Name from $Url..."
    
    $curlArgs = @(
        "-4",                                          # Force IPv4
        "-L",                                          # Follow Redirects
        "-f",                                          # Fail on HTTP errors
        "--retry", "3",                                # Retry 3 times
        "--retry-delay", "5",                          # Wait 5s between retries
        "--doh-url", "https://cloudflare-dns.com/dns-query", # <--- BYPASS LOCAL DNS
        "-o", $installer,                              # Output file
        $Url,                                          # Target URL
        "-A", "Mozilla/5.0"                            # User Agent
    )
    
    $process = Start-Process -FilePath "curl.exe" -ArgumentList $curlArgs -Wait -PassThru -NoNewWindow
    
    if ($process.ExitCode -ne 0) {
        Write-Warning "Failed to download $Name. Curl exit code: $($process.ExitCode)"
        return
    }

    Write-Host "Download complete."

    # 2. Install (Silent)
    Write-Host "Installing $Name..."
    try {
        Start-Process -FilePath $installer -ArgumentList "/S" -Wait -PassThru | Out-Null
        Start-Sleep -Seconds 5
    } catch {
        Write-Warning "Installer failed to run: $($_.Exception.Message)"
        return
    }
    
    # 3. Locate Installation
    $localAppData = "$env:LOCALAPPDATA\Programs"
    $possiblePaths = @(
        "$localAppData\$ProcessName", 
        "$localAppData\$Name", 
        "$localAppData\${Name} user"
    )

    $installPath = $possiblePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

    if ($installPath) {
        Write-Host "Installation found at: $installPath"
        
        # 4. Move to Shared Location
        $sharedPath = "$destBase\$Name"
        if (Test-Path $sharedPath) { Remove-Item $sharedPath -Recurse -Force }
        
        Copy-Item -Path $installPath -Destination $sharedPath -Recurse -Force

        # 5. Create Shortcut
        $WshShell = New-Object -comObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut("$publicDesktop\$Name.lnk")
        $Shortcut.TargetPath = "$sharedPath\$Name.exe"
        $Shortcut.Save()
        
        Write-Host "Shortcut created on Public Desktop."
    } else {
        Write-Warning "Could not locate installed files for $Name. Checked: $($possiblePaths -join ', ')"
    }
}

# --- Install Cursor ---
Install-Editor -Name "Cursor" -Url "https://downloader.cursor.sh/windows/x64" -ProcessName "cursor"

# --- Install Windsurf ---
Install-Editor -Name "Windsurf" -Url "https://windsurf.codeium.com/api/windows/x64/stable" -ProcessName "Windsurf"

Write-Host "AI Editors installation process complete."