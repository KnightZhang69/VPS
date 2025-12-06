# .github/workflows/scripts/win-install-editors.ps1

Write-Host "--- Installing AI Editors (Cursor & Windsurf) ---"

$destBase = "C:\AI_Editors"
New-Item -ItemType Directory -Force -Path $destBase | Out-Null
$publicDesktop = [Environment]::GetFolderPath("CommonDesktopDirectory")

function Download-WithFallback {
    param (
        [string]$Name,
        [string[]]$Urls,
        [string]$OutFile
    )
    
    foreach ($url in $Urls) {
        Write-Host "Attempting download from: $url"
        
        # Method 1: Try Invoke-WebRequest (uses Windows native HTTP stack)
        try {
            $ProgressPreference = 'SilentlyContinue'  # Speed up download
            Invoke-WebRequest -Uri $url -OutFile $OutFile -UseBasicParsing -TimeoutSec 120
            if (Test-Path $OutFile) {
                $size = (Get-Item $OutFile).Length
                if ($size -gt 1000000) {  # File should be > 1MB
                    Write-Host "Download successful via Invoke-WebRequest ($([math]::Round($size/1MB, 2)) MB)"
                    return $true
                }
            }
        } catch {
            Write-Host "Invoke-WebRequest failed: $($_.Exception.Message)"
        }
        
        # Method 2: Try curl.exe as fallback
        Write-Host "Trying curl.exe fallback..."
        # Note: User-Agent must be quoted properly to avoid argument splitting
        $curlCmd = "curl.exe -L -f --retry 3 --retry-delay 2 --connect-timeout 30 -o `"$OutFile`" `"$url`""
        $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c", $curlCmd -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -eq 0 -and (Test-Path $OutFile)) {
            $size = (Get-Item $OutFile).Length
            if ($size -gt 1000000) {
                Write-Host "Download successful via curl ($([math]::Round($size/1MB, 2)) MB)"
                return $true
            }
        }
        
        Write-Host "Failed with URL: $url"
        if (Test-Path $OutFile) { Remove-Item $OutFile -Force }
    }
    
    return $false
}

function Install-Editor {
    param (
        [string]$Name,
        [string[]]$Urls,
        [string]$ProcessName
    )

    Write-Host "`nProcessing $Name..."
    $installer = "$env:TEMP\$Name-setup.exe"
    
    # 1. Download with multiple URL fallbacks
    $downloaded = Download-WithFallback -Name $Name -Urls $Urls -OutFile $installer
    
    if (-not $downloaded) {
        Write-Warning "Failed to download $Name from all sources."
        return
    }

    Write-Host "Download complete."

    # 2. Install (Silent with timeout)
    Write-Host "Installing $Name (timeout: 120s)..."
    try {
        # Use /VERYSILENT /NORESTART for NSIS-based installers, /S for others
        # Run with timeout to prevent hanging
        $installProcess = Start-Process -FilePath $installer -ArgumentList "/VERYSILENT", "/NORESTART", "/SUPPRESSMSGBOXES", "/SP-" -PassThru
        $completed = $installProcess.WaitForExit(120000)  # 120 second timeout
        
        if (-not $completed) {
            Write-Host "Installation taking too long, attempting to continue..."
            Stop-Process -Id $installProcess.Id -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 3
        } else {
            Write-Host "Installer exited with code: $($installProcess.ExitCode)"
        }
        
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
# Use downloads.cursor.com CDN (most reliable)
$cursorUrls = @(
    "https://downloads.cursor.com/production/21a2ed198584d56a91c0b996d1a09c93f8538440/win32/x64/user-setup/CursorUserSetup-x64-2.1.49.exe",
    "https://downloader.cursor.sh/windows/x64"
)
Install-Editor -Name "Cursor" -Urls $cursorUrls -ProcessName "cursor"

# --- Install Windsurf ---
# Try winget first (most reliable on GitHub Actions), then direct URLs
Write-Host "`nProcessing Windsurf..."
$windsurfInstalled = $false

# Method 1: Try winget (bypasses DNS issues entirely)
Write-Host "Attempting Windsurf install via winget..."
try {
    $wingetResult = Start-Process -FilePath "winget" -ArgumentList "install", "--id", "Codeium.Windsurf", "-e", "--silent", "--accept-package-agreements", "--accept-source-agreements" -Wait -PassThru -NoNewWindow
    if ($wingetResult.ExitCode -eq 0) {
        Write-Host "Windsurf installed successfully via winget"
        $windsurfInstalled = $true
    } else {
        Write-Host "Winget install failed with exit code: $($wingetResult.ExitCode)"
    }
} catch {
    Write-Host "Winget not available or failed: $($_.Exception.Message)"
}

# Method 2: Try direct download if winget failed
if (-not $windsurfInstalled) {
    $windsurfUrls = @(
        "https://windsurf-stable.codeiumdata.com/win32-x64/stable/latest/WindsurfSetup-x64.exe",
        "https://windsurf.codeium.com/api/windows/x64/stable"
    )
    Install-Editor -Name "Windsurf" -Urls $windsurfUrls -ProcessName "Windsurf"
} else {
    # Create shortcut for winget-installed Windsurf
    $windsurfPath = "$env:LOCALAPPDATA\Programs\Windsurf\Windsurf.exe"
    if (Test-Path $windsurfPath) {
        $WshShell = New-Object -comObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut("$publicDesktop\Windsurf.lnk")
        $Shortcut.TargetPath = $windsurfPath
        $Shortcut.Save()
        Write-Host "Windsurf shortcut created on Public Desktop."
    }
}

Write-Host "`nAI Editors installation process complete."