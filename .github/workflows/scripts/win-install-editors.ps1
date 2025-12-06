# .github/workflows/scripts/win-install-editors.ps1

Write-Host "--- Installing AI Editors (Cursor & Windsurf) ---"

# 1. Setup Network Security & Headers (Fixes 403/Blocked Downloads)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
$headers = @{
    "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
}

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
    
    # 2. Download with Retry Logic
    try {
        Write-Host "Downloading from $Url..."
        Invoke-WebRequest -Uri $Url -OutFile $installer -Headers $headers -ErrorAction Stop
        Write-Host "Successfully downloaded $Name."
    } catch {
        Write-Warning "Failed to download $Name."
        Write-Warning "Error Details: $($_.Exception.Message)"
        return
    }

    # 3. Install (Silent)
    Write-Host "Installing $Name..."
    try {
        Start-Process -FilePath $installer -ArgumentList "/S" -Wait -PassThru | Out-Null
    } catch {
        Write-Warning "Installer failed to run."
        return
    }
    
    # 4. Locate Installation
    # Cursor/Windsurf install to %LOCALAPPDATA% of the runner user
    $localAppData = "$env:LOCALAPPDATA\Programs"
    
    # List of possible installation folder names
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
        
        Write-Host "Moving files to shared folder $sharedPath..."
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