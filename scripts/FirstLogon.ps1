$ErrorActionPreference = "Continue"

$ScriptRoot = "C:\ISO-Werkstatt\scripts"
$Log = "C:\ISO-Werkstatt\firstlogon.log"

"=== ISO-Werkstatt FirstLogon ===" | Out-File $Log
"User: $env:USERNAME" | Out-File $Log -Append
"SID: $([System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value)" | Out-File $Log -Append
"Time: $(Get-Date)" | Out-File $Log -Append

# Der Builder erzeugt diese Datei aus dem gewählten Profil.
$AdjustmentNames = @("Search", "Explorer", "WindowsDefaults", "Edge")
try {
    $Adjustments = Import-PowerShellDataFile -LiteralPath (Join-Path $ScriptRoot "adjustments.psd1") -ErrorAction Stop
    foreach ($Name in $AdjustmentNames) {
        if ($Adjustments[$Name] -isnot [bool]) {
            throw "Ungültiger oder fehlender Anpassungsschalter: $Name"
        }
    }
    foreach ($Name in $Adjustments.Keys) {
        if ($Name -notin $AdjustmentNames) {
            throw "Unbekannter Anpassungsschalter: $Name"
        }
    }
}
catch {
    "FEHLER: Anpassungen nicht gestartet: $($_.Exception.Message)" | Out-File $Log -Append
    throw
}

foreach ($Name in $AdjustmentNames) {
    if ($Adjustments[$Name]) {
        "Starte $Name.ps1" | Out-File $Log -Append
        & (Join-Path $ScriptRoot "$Name.ps1") 2>&1 | Out-File $Log -Append
    }
    else {
        "Ueberspringe $Name.ps1 (Profil)" | Out-File $Log -Append
    }
}
"HKCU Test: $(Get-ItemPropertyValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name HideFileExt -ErrorAction SilentlyContinue)" |
    Out-File $Log -Append

"Scripts beendet." | Out-File $Log -Append

if ($Adjustments.Explorer) {
    # Kurz warten, bis die Windows-Shell vollständig bereit ist.
    Start-Sleep -Seconds 3
    Start-Process explorer.exe "shell:MyComputerFolder"
    "Dieser PC geöffnet." | Out-File $Log -Append
}
"=== FirstLogon beendet ===" | Out-File $Log -Append
