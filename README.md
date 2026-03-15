# PSScoopOutdatedReporter

PSScoopOutdatedReporter is a small PowerShell script for checking outdated Scoop packages on Windows.
It runs `scoop status`, shows the current and available versions in a readable format, and prints the commands and package pages you can use to review and upgrade each package.

## Requirements

- Windows 11+
- PowerShell 5.1+
- [Scoop](https://scoop.sh/) 0.5+

## Usage

```powershell
# powershell
git clone https://github.com/kumarstack55/PSScoopOutdatedReporter.git
Set-Location .\PSScoopOutdatedReporter
.\Invoke-ReportScoopOutdated.ps1
```

If you want to run this script in startup, you can create a shortcut and add it to the startup folder.

```powershell
# powershell
Set-Location .\PSScoopOutdatedReporter

$location = Get-Location
$path = $location.Path
$scriptPath = Join-Path $path "Invoke-ReportScoopOutdated.ps1"

$startupFolder = [Environment]::GetFolderPath("Startup")
$shortcutPath = Join-Path $startupFolder "ReportScoopOutdated.lnk"

$wshShell = New-Object -ComObject WScript.Shell
$shortcut = $wshShell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "powershell.exe"
$shortcut.Arguments = "-ExecutionPolicy Bypass -NoProfile -File `"$scriptPath`""
$shortcut.Save()
```

## License

MIT
