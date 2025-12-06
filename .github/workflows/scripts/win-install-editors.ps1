# .github/workflows/scripts/win-install-editors.ps1

Write-Host "--- Installing AI Editors (Cursor & Windsurf) ---"

# --- NETWORK FIX: Reset DNS on ALL Active Adapters ---
# This fixes "No such host is known" by forcing reliable Public DNS.
Write-Host "Configuring DNS on active adapters..."
$adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
foreach ($adapter in $adapters) {
    try {
        Write-Host "Setting DNS for $($adapter.Name)..."
        Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses ("8.8.8.8", "1.1.1.1") -ErrorAction SilentlyContinue
        Clear-DnsClientCache
    } catch {
        Write-Warning "Failed to set DNS on $($adapter.Name)"
    }
}
# -----------------------------------------------------

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
    
    # 1. Download using Start-BitsTransfer (Native Windows Service - Most Robust)
    Write-Host "Downloading $Name from $Url..."
    $downloaded = $false
    
    try {
        # BITS handles redirects and background transfer reliability automatically
        Start-BitsTransfer -Source $Url -Destination $installer -Priority Foreground -ErrorAction Stop
        Write-Host "Download complete (via BITS)."
        $downloaded = $true
    } catch {
        Write-Warning "BITS download failed. Error: $($_.Exception.Message)"
        Write-Host "Attempting fallback to WebClient..."
    }

    # 2. Fallback: .NET WebClient (if BITS failed)
    if (-not $downloaded) {
        try {
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($Url, $installer)
            Write-Host "Download complete (via WebClient)."
            $downloaded = $true
        } catch {
            Write-Warning "WebClient failed: $($_.Exception.Message)"
            return
        }
    }

    # 3. Install (Silent)
    Write-Host "Installing $Name..."
    try {
        Start-Process -FilePath $installer -ArgumentList "/S" -Wait -PassThru | Out-Null
        # Wait for file locks to release
        Start-Sleep -Seconds 5
    } catch {
        Write-Warning "Installer failed to run: $($_.Exception.Message)"
        return
    }
    
    # 4. Locate Installation
    $localAppData = "$env:LOCALAPPDATA\Programs"
    $possiblePaths = @(
        "$localAppData\$ProcessName", 
        "$localAppData\$Name", 
        "$localAppData\${Name} user"
    )

    $installPath = $possiblePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

    if ($installPath) {
        Write-Host "Installation found at: $installPath"
        
        # 5. Move to Shared Location
        $sharedPath = "$destBase\$Name"
        if (Test-Path $sharedPath) { Remove-Item $sharedPath -Recurse -Force }
        
        Copy-Item -Path $installPath -Destination $sharedPath -Recurse -Force

        # 6. Create Shortcut
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