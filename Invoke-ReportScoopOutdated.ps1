class PackageRecord {
    [string] $Name
    [string] $InstalledVersion
    [string] $LatestVersion
    [string] $MissingDependencies
    [string] $Info

    PackageRecord([string]$Name, [string]$InstalledVersion, [string]$LatestVersion, [string]$MissingDependencies, [string]$Info) {
        $this.Name = $Name
        $this.InstalledVersion = $InstalledVersion
        $this.LatestVersion = $LatestVersion
        $this.MissingDependencies = $MissingDependencies
        $this.Info = $Info
    }
}

function Get-OutdatedPackages {
    [CmdletBinding()]
    [OutputType([PackageRecord[]])]
    param()
    $runner = New-CommandRunner
    $text = $runner.Run("choco", @("outdated", "--no-color", "--limit-output"))
    $lines = $text -split "`r?`n"
    $packages = foreach ($line in $lines) {
        $parts = $line -split "\|"
        if ($parts.Length -eq 4) {
            [PackageRecord]::new($parts[0], $parts[1], $parts[2], $parts[3])
        }
    }
    return $packages
}

function Invoke-ReportChocolateyOutdated {
    [CmdletBinding()]
    [OutputType([void])]
    param()
    $packages = @(Get-OutdatedPackages)

    if ($packages.Count -eq 0) {
        Write-Host -ForegroundColor Green "All packages are up to date."

        $sleepSeconds = 60
        Write-Host "No outdated packages found. Exiting in ${sleepSeconds} seconds..."
        Start-Sleep -Seconds $sleepSeconds

        return
    }

    Write-Host "Outdated packages:"
    $packages | Format-Table -Property Id, Version, AvailableVersion, Pinned -AutoSize

    $sudoCommand = Get-Command "sudo"

    foreach ($package in $packages) {
        $id = $package.Id
        $version = $package.Version
        $availableVersion = $package.AvailableVersion
        $versionHistroyUrl = "https://community.chocolatey.org/packages/${id}/#versionhistory"
        $upgradeCommand = "choco upgrade ${id}"

        Write-Host "## $id"

        Write-Host -NoNewLine "To check Downloads, Last updated, Status, visit: "
        Write-Host -ForegroundColor Yellow "$versionHistroyUrl"

        Write-Host -NoNewLine "To upgrade from "
        Write-Host -NoNewLine -ForegroundColor Red ${version}
        Write-Host -NoNewLine " to "
        Write-Host -NoNewLine -ForegroundColor Green ${availableVersion}
        Write-Host -NoNewLine ", run: ``"
        Write-Host -NoNewLine -ForegroundColor Yellow ${upgradeCommand}
        Write-Host -NoNewLine "``"

        if ($sudoCommand) {
            Write-Host ", or run the following command:"
            Write-Host -ForegroundColor Yellow "sudo powershell.exe -NoProfile -NoExit -Command `"${upgradeCommand}`""
        } else {
            Write-Host "."
        }
        Write-Host ""

    }
    Read-Host "Press Enter to exit..."
}

function Remove-EscapeSequencesFromString {
    param([string]$string)
    $string -replace '\x1b\[[0-9;]*m', ''
}

function Remove-EscapeSequencesFromLines {
    param([string[]]$lines)
    $lines | ForEach-Object { Remove-EscapeSequencesFromString $_ }
}

function Get-TableLinesFromScoopStatusLines {
    param([string[]]$Lines)
    [OutputType([System.Collections.Generic.List[string]])]

    $tableLines = [System.Collections.Generic.List[string]]::new()
    $lineIndex = 0
    $state = 0
    while ($lineIndex -lt $Lines.Length) {
        $line = $Lines[$lineIndex]
        if ($state -eq 0 -and $line -match "^Name") {
            $state = 1
            $tableLines.Add($line)
        } elseif ($state -eq 1) {
            if ($line -match "^\s*$") {
                $state = 2
            } else {
                $tableLines.Add($line)
            }
        }
        $lineIndex++
    }

    return $tableLines
}

function Invoke-ReportScoopOutdated {
    [CmdletBinding()]
    [OutputType([void])]
    param()

    $linesWithEscapeSequences = & scoop.cmd status 2>&1
    $lines = Remove-EscapeSequencesFromLines $linesWithEscapeSequences
    $text = $lines -join "`n"
    $needScoopUpdate = $text -notmatch "Scoop is up to date"

    $tableLines = Get-TableLinesFromScoopStatusLines $lines

    $tableBodyLines = $tableLines | Select-Object -Skip 2
    [PackageRecord[]] $packages = $tableBodyLines |
        Where-Object { $_.Trim() } |
        ForEach-Object {
            $columns = $_ -split '\s+', 5

            $name = $columns[0]
            $installedVersion = if ($columns.Count -ge 2) { $columns[1] } else { $null }
            $latestVersion = if ($columns.Count -ge 3) { $columns[2] } else { $null }
            $missingDependencies = if ($columns.Count -ge 4) { $columns[3] } else { $null }
            $info = if ($columns.Count -ge 5) { $columns[4] } else { $null }

            [PackageRecord]::new(
                $name,
                $installedVersion,
                $latestVersion,
                $missingDependencies,
                $info
            )
        }

    if ($needScoopUpdate) {
        Write-Host -NoNewLine "Scoop itself is outdated. Please run ``"
        Write-Host -NoNewLine -ForegroundColor Yellow "scoop update"
        Write-Host "`` to update Scoop first."
        Write-Host ""
    }

    if ($packages.Count -eq 0) {
        Write-Host -ForegroundColor Green "All packages are up to date."

        $sleepSeconds = 60
        Write-Host "No outdated packages found. Exiting in ${sleepSeconds} seconds..."
        Start-Sleep -Seconds $sleepSeconds

        return
    }

    Write-Host "Outdated packages:"
    $packages

    foreach ($package in $packages) {
        $id = $package.Name
        $version = $package.InstalledVersion
        $availableVersion = $package.LatestVersion
        $upgradeCommand = "scoop update ${id}"

        Write-Host "## $id"

        Write-Host -NoNewLine "To upgrade from "
        Write-Host -NoNewLine -ForegroundColor Red ${version}
        Write-Host -NoNewLine " to "
        Write-Host -NoNewLine -ForegroundColor Green ${availableVersion}
        Write-Host -NoNewLine ", run: ``"
        Write-Host -NoNewLine -ForegroundColor Yellow ${upgradeCommand}
        Write-Host -NoNewLine "``"

        Write-Host "."
        Write-Host ""
    }
    Read-Host "Press Enter to exit..."
}

Invoke-ReportScoopOutdated
