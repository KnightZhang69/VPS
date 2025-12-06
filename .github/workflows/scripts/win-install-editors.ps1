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
    
    # 1. Download using Invoke-WebRequest with retry logic
    # PowerShell's Invoke-WebRequest handles DNS resolution better than curl.exe in GitHub Actions
    Write-Host "Downloading $Name from $Url..."
    
    $maxRetries = 3
    $retryDelay = 5
    $retryCount = 0
    $downloadSuccess = $false
    
    # Try to resolve DNS first
    try {
        $uri = [System.Uri]$Url
        $hostname = $uri.Host
        Write-Host "Resolving DNS for $hostname..."
        $dnsResult = [System.Net.Dns]::GetHostAddresses($hostname)
        Write-Host "DNS resolved successfully. IP addresses: $($dnsResult -join ', ')"
    } catch {
        Write-Warning "DNS resolution failed: $($_.Exception.Message)"
        Write-Host "Will attempt download anyway..."
    }
    
    while ($retryCount -lt $maxRetries -and -not $downloadSuccess) {
        try {
            $ProgressPreference = 'SilentlyContinue'  # Suppress progress bar
            Invoke-WebRequest -Uri $Url -OutFile $installer -UserAgent "Mozilla/5.0" -TimeoutSec 300 -ErrorAction Stop
            $downloadSuccess = $true
            Write-Host "Download complete."
        } catch {
            $retryCount++
            if ($retryCount -lt $maxRetries) {
                Write-Warning "Download attempt $retryCount failed: $($_.Exception.Message)"
                Write-Host "Retrying in $retryDelay seconds... ($($maxRetries - $retryCount) retries left)"
                Start-Sleep -Seconds $retryDelay
            } else {
                Write-Warning "Failed to download $Name after $maxRetries attempts. Error: $($_.Exception.Message)"
                return
            }
        }
    }
    
    if (-not $downloadSuccess) {
        Write-Warning "Failed to download $Name after all retry attempts."
        return
    }

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