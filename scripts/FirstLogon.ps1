$ErrorActionPreference = "Continue"

$ScriptRoot = "C:\ISO-Werkstatt\scripts"
$Log = "C:\ISO-Werkstatt\firstlogon.log"

"=== ISO-Werkstatt FirstLogon ===" | Out-File $Log
"User: $env:USERNAME" | Out-File $Log -Append
"SID: $([System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value)" | Out-File $Log -Append
"Time: $(Get-Date)" | Out-File $Log -Append

"Starte Search.ps1" | Out-File $Log -Append
& "$ScriptRoot\Search.ps1" 2>&1 | Out-File $Log -Append

"Starte Explorer.ps1" | Out-File $Log -Append
& "$ScriptRoot\Explorer.ps1" 2>&1 | Out-File $Log -Append

"Starte WindowsDefaults.ps1" | Out-File $Log -Append
& "$ScriptRoot\WindowsDefaults.ps1" 2>&1 | Out-File $Log -Append

"HKCU Test: $(Get-ItemPropertyValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name HideFileExt -ErrorAction SilentlyContinue)" |
    Out-File $Log -Append

"Scripts beendet." | Out-File $Log -Append

# Kurz warten, bis die Windows-Shell vollständig bereit ist
Start-Sleep -Seconds 3

# "Dieser PC" explizit öffnen
Start-Process explorer.exe "shell:MyComputerFolder"

"Dieser PC geöffnet." | Out-File $Log -Append
"=== FirstLogon beendet ===" | Out-File $Log -Append