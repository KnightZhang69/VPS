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
    
    # 1. Download
    try {
        Invoke-WebRequest -Uri $Url -OutFile $installer -ErrorAction Stop
        Write-Host "Downloaded $Name."
    } catch {
        Write-Warning "Failed to download $Name. Skipping."
        return
    }

    # 2. Install (Silent)
    # These electron apps usually install to %LOCALAPPDATA%\Programs\<AppName>
    Start-Process -FilePath $installer -ArgumentList "/S" -Wait -PassThru | Out-Null
    
    # 3. Locate Installation (The installer runs as the current runner user)
    # Cursor installs to 'cursor', Windsurf usually to 'Windsurf'
    $localAppData = "$env:LOCALAPPDATA\Programs"
    $possiblePaths = @(
        "$localAppData\$ProcessName", 
        "$localAppData\$Name", 
        "$localAppData\${Name} user"
    )

    $installPath = $possiblePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

    if ($installPath) {
        Write-Host "Installation found at: $installPath"
        
        # 4. Move to Shared Location (so 'vum' user can access it easily)
        $sharedPath = "$destBase\$Name"
        Write-Host "Moving to $sharedPath..."
        Copy-Item -Path $installPath -Destination $sharedPath -Recurse -Force

        # 5. Create Desktop Shortcut for All Users
        $WshShell = New-Object -comObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut("$publicDesktop\$Name.lnk")
        $Shortcut.TargetPath = "$sharedPath\$Name.exe"
        $Shortcut.Save()
        
        Write-Host "Shortcut created on Public Desktop."
    } else {
        Write-Warning "Could not locate installed files for $Name in $localAppData"
    }
}

# --- Install Cursor ---
# Direct download link for Windows x64
Install-Editor -Name "Cursor" -Url "https://downloader.cursor.sh/windows/x64" -ProcessName "cursor"

# --- Install Windsurf ---
# Windsurf direct link (may vary, but this is the standard stable endpoint)
Install-Editor -Name "Windsurf" -Url "https://windsurf.codeium.com/api/windows/x64/stable" -ProcessName "Windsurf"

Write-Host "AI Editors installation process complete."