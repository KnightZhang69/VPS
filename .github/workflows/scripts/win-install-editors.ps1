# .github/workflows/scripts/win-install-editors.ps1

Write-Host "--- Installing AI Editors (Cursor & Windsurf) ---"

# --- NETWORK FIX: Disable IPv6 (Common cause of CI timeouts) ---
# Instead of changing DNS servers (which can be blocked), we disable IPv6
# to force the runner to use the working IPv4 stack provided by Azure.
Write-Host "Disabling IPv6 on all adapters..."
Get-NetAdapterBinding -ComponentID ms_tcpip6 | Disable-NetAdapterBinding -ErrorAction SilentlyContinue
Write-Host "IPv6 Disabled."

# Flush DNS to clear any bad cached states
Clear-DnsClientCache
# ---------------------------------------------------------------

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
    
    # 1. Download using curl.exe
    # We use curl with specific flags to work around CI network flakiness.
    Write-Host "Downloading $Name from $Url..."
    
    $curlArgs = @(
        "--ipv4",                                      # Force IPv4 Resolution
        "-L",                                          # Follow Redirects
        "-f",                                          # Fail on HTTP errors
        "--retry", "5",                                # Retry 5 times
        "--retry-delay", "3",                          # Wait 3s between retries
        "--connect-timeout", "10",                     # Timeout connection after 10s
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
        # Wait for file locks to release
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