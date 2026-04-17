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

function Remove-EscapeSequencesFromString {
    param([string]$string)
    $string -replace '\x1b\[[0-9;]*m', ''
}

function Remove-EscapeSequencesFromLines {
    param([string[]]$Lines)
    $Lines | ForEach-Object { Remove-EscapeSequencesFromString $_ }
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

    Write-Host "Checking for outdated Scoop packages..."
    $linesWithEscapeSequences = & scoop.cmd status 2>&1
    $lines = Remove-EscapeSequencesFromLines $linesWithEscapeSequences

    $text = $lines -join "`n"
    $needScoopUpdate = $text -notmatch "Scoop is up to date"
    if ($needScoopUpdate) {
        Write-Host "Scoop itself is outdated. Running 'scoop update' to update Scoop first..."
        & scoop update

        Write-Host "Re-checking for outdated Scoop packages..."
        $linesWithEscapeSequences = & scoop.cmd status 2>&1
        $lines = Remove-EscapeSequencesFromLines $linesWithEscapeSequences
    }

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
        $name = $package.Name
        $installedVersion = $package.InstalledVersion
        $latestVersion = $package.LatestVersion
        $updateCommand = "scoop update ${name}"

        # TODO: get last 10 version and commit date from scoop bucket repository.

        Write-Host "## $name"

        Write-Host -NoNewLine "To upgrade from "
        Write-Host -NoNewLine -ForegroundColor Red ${installedVersion}
        Write-Host -NoNewLine " to "
        Write-Host -NoNewLine -ForegroundColor Green ${latestVersion}
        Write-Host -NoNewLine ", run: ``"
        Write-Host -NoNewLine -ForegroundColor Yellow ${updateCommand}
        Write-Host -NoNewLine "``"

        Write-Host "."
        Write-Host ""
    }
    Read-Host "Press Enter to exit..."
}

Invoke-ReportScoopOutdated
