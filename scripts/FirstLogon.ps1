$ErrorActionPreference = "Stop"

$ScriptRoot = "C:\ISO-Werkstatt\scripts"
$Log = "C:\ISO-Werkstatt\firstlogon.log"
$ResultPath = "C:\ISO-Werkstatt\firstlogon-result.json"
$FirstLogonStarted = [DateTimeOffset]::UtcNow
$StepResults = [Collections.Generic.List[object]]::new()
$FatalError = $null

function Invoke-FirstLogonStep {
    param([string]$StepName, [scriptblock]$Action, [bool]$Enabled = $true)
    if (-not $Enabled) {
        "[SKIP] $StepName (Profil oder Ordner nicht vorhanden)" | Out-File $Log -Append
        $StepResults.Add([pscustomobject]@{ Name = $StepName; Status = "Skipped"; Errors = @() })
        return
    }
    $StepErrors = [Collections.Generic.List[string]]::new()
    "[START] $StepName" | Out-File $Log -Append
    try {
        & $Action 2>&1 | ForEach-Object {
            if ($_ -is [Management.Automation.ErrorRecord]) {
                $StepErrors.Add($_.ToString())
            }
            $_ | Out-File $Log -Append
        }
    }
    catch {
        $StepErrors.Add($_.Exception.Message)
        "[FEHLER] $($_.Exception.Message)" | Out-File $Log -Append
    }
    $StepStatus = if ($StepErrors.Count -eq 0) { "Succeeded" } else { "Failed" }
    $StepResults.Add([pscustomobject]@{ Name = $StepName; Status = $StepStatus; Errors = @($StepErrors.ToArray()) })
    "[$StepStatus] $StepName" | Out-File $Log -Append
}

"=== ISO-Werkstatt FirstLogon ===" | Out-File $Log
"User: $env:USERNAME" | Out-File $Log -Append
"Time: $($FirstLogonStarted.ToString('o'))" | Out-File $Log -Append

try {
    $IsCore=$false
    $TargetPath=Join-Path $ScriptRoot 'target.psd1'
    if(Test-Path -LiteralPath $TargetPath){
        $RuntimeTarget=Import-PowerShellDataFile -LiteralPath $TargetPath -ErrorAction Stop
        if($RuntimeTarget.TargetOS -notin @('Windows11','Windows10','Server2022','Server2025')){throw 'Ungültiges Laufzeit-Zielsystem.'}
        if($RuntimeTarget.InstallationMode -notin @('Desktop','Core')){throw 'Ungültiger Laufzeit-InstallationMode.'}
        $IsCore=$RuntimeTarget.InstallationMode -eq 'Core'
    }
    $AdjustmentNames = @("Search", "Explorer", "WindowsDefaults", "Edge", "UBlockLite")
    $Adjustments = Import-PowerShellDataFile -LiteralPath (Join-Path $ScriptRoot "adjustments.psd1") -ErrorAction Stop
    foreach ($Name in ($AdjustmentNames + @("Tools"))) {
        if ($Adjustments[$Name] -isnot [bool]) {
            throw "Ungültiger oder fehlender Anpassungsschalter: $Name"
        }
    }
    foreach ($Name in $Adjustments.Keys) {
        if ($Name -notin ($AdjustmentNames + @("Tools"))) {
            throw "Unbekannter Anpassungsschalter: $Name"
        }
    }

    foreach ($Name in $AdjustmentNames) {
        Invoke-FirstLogonStep -StepName $Name -Enabled ($Adjustments[$Name] -and -not $IsCore) -Action {
            & (Join-Path $ScriptRoot "$Name.ps1")
        }
    }

    $ToolsPath = "C:\ISO-Werkstatt\Tools"
    Invoke-FirstLogonStep -StepName "ToolsShortcut" -Enabled (-not $IsCore -and $Adjustments.Tools -and (Test-Path -LiteralPath $ToolsPath -PathType Container)) -Action {
        $DesktopPath = [Environment]::GetFolderPath("DesktopDirectory")
        if ([string]::IsNullOrWhiteSpace($DesktopPath)) {
            throw "Desktop-Verzeichnis konnte nicht ermittelt werden."
        }
        New-Item -ItemType Directory -Path $DesktopPath -Force -ErrorAction Stop | Out-Null
        $ShortcutPath = Join-Path $DesktopPath "Tools.lnk"
        $Shell = New-Object -ComObject WScript.Shell -ErrorAction Stop
        $Shortcut = $Shell.CreateShortcut($ShortcutPath)
        $Shortcut.TargetPath = $ToolsPath
        $Shortcut.WorkingDirectory = $ToolsPath
        $Shortcut.Description = "Portable Werkzeuge der ISO-Werkstatt"
        $Shortcut.Save()
        "Tools-Verknüpfung erstellt: $ShortcutPath"
    }

    Invoke-FirstLogonStep -StepName "OpenExplorer" -Enabled ($Adjustments.Explorer -and -not $IsCore) -Action {
        Start-Sleep -Seconds 3
        Start-Process explorer.exe "shell:MyComputerFolder" -ErrorAction Stop
        "Dieser PC geöffnet."
    }
}
catch {
    $FatalError = $_
    "[FEHLER] FirstLogon: $($_.Exception.Message)" | Out-File $Log -Append
    $StepResults.Add([pscustomobject]@{ Name = "FirstLogon"; Status = "Failed"; Errors = @($_.Exception.Message) })
}
finally {
    $FailedSteps = @($StepResults | Where-Object Status -eq "Failed")
    $SucceededSteps = @($StepResults | Where-Object Status -eq "Succeeded")
    $SkippedSteps = @($StepResults | Where-Object Status -eq "Skipped")
    $OverallStatus = if ($FailedSteps.Count -eq 0) { "Succeeded" } else { "Failed" }
    [ordered]@{
        SchemaVersion = 1
        Status = $OverallStatus
        StartedAt = $FirstLogonStarted.ToString("o")
        CompletedAt = [DateTimeOffset]::UtcNow.ToString("o")
        Steps = @($StepResults.ToArray())
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ResultPath -Encoding UTF8
    ("=== FirstLogon {0}: {1} erfolgreich, {2} übersprungen, {3} fehlgeschlagen ===" -f
        $OverallStatus, $SucceededSteps.Count, $SkippedSteps.Count, $FailedSteps.Count) | Out-File $Log -Append
}

if ($FatalError) { throw $FatalError }
if ($FailedSteps.Count -gt 0) {
    throw "FirstLogon enthält fehlgeschlagene Schritte. Details: $Log"
}
