# Hilfsfunktionen des Builders; Windows PowerShell 5.1 kompatibel.
function Enter-BuildLock {
    param([Parameter(Mandatory = $true)][string]$Path)
    try {
        # Die Datei bleibt liegen; nur der offene Handle sperrt den Build.
        # Windows gibt ihn auch nach einem Prozessabbruch frei.
        return [IO.File]::Open($Path, [IO.FileMode]::OpenOrCreate,
            [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    }
    catch {
        throw "Build-Verzeichnis kann nicht gesperrt werden. Läuft bereits ein Build? Pfad: $Path"
    }
}

function Get-BuildTarget {
    param([string]$TargetOS = "Windows11")
    $Targets = @{
        Windows11  = @{ VirtioTarget = "w11"; Supported = $true }
        Windows10  = @{ VirtioTarget = "w10"; Supported = $false }
        Server2022 = @{ VirtioTarget = "2k22"; Supported = $false }
        Server2025 = @{ VirtioTarget = "2k25"; Supported = $false }
    }
    if (-not $Targets.ContainsKey($TargetOS)) {
        throw "Unbekanntes Zielsystem '$TargetOS'. Erlaubt: Windows11, Windows10, Server2022, Server2025."
    }
    return $Targets[$TargetOS]
}

function Write-BuildState {
    param(
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$State,
        [Parameter(Mandatory = $true)][string]$Path
    )
    $State.UpdatedAt = [DateTimeOffset]::UtcNow.ToString("o")
    $TemporaryPath = "$Path.tmp"
    try {
        [IO.File]::WriteAllText($TemporaryPath, ($State | ConvertTo-Json -Depth 6),
            [Text.UTF8Encoding]::new($false))
        # Leser sehen entweder die alte oder die vollständige neue JSON-Datei.
        [IO.File]::Replace($TemporaryPath, $Path, [NullString]::Value)
    }
    finally {
        if ([IO.File]::Exists($TemporaryPath)) {
            [IO.File]::Delete($TemporaryPath)
        }
    }
}

function Set-BuildStep {
    param(
        [System.Collections.IDictionary]$State,
        [string]$Path,
        [int]$Number,
        [string]$Name
    )
    $State.Step = $Number
    $State.StepName = $Name
    Write-BuildState -State $State -Path $Path
    Write-Host ("[{0}/{1}] {2}" -f $Number, $State.TotalSteps, $Name)
    Write-Progress -Activity "ISO-Werkstatt" -Status $Name -PercentComplete (($Number - 1) * 100 / $State.TotalSteps)
}
