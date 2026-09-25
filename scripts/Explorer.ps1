# Vor der Anzeige versteckter Dateien die Shell-Metadatenattribute wiederherstellen.
& (Join-Path $PSScriptRoot 'Repair-DesktopIni.ps1')

# Explorer-Defaults für LabAdmin

$ExplorerAdvanced = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

# Der Schlüssel existiert in Windows bereits.
# Absichtlich kein New-Item hier: Das hatte beim FirstLogon zu UnauthorizedAccessException geführt.

# Dateiendungen anzeigen
Set-ItemProperty `
    -Path $ExplorerAdvanced `
    -Name "HideFileExt" `
    -Value 0

# Versteckte Dateien anzeigen
Set-ItemProperty `
    -Path $ExplorerAdvanced `
    -Name "Hidden" `
    -Value 1

# Geschützte Systemdateien weiterhin versteckt
Set-ItemProperty `
    -Path $ExplorerAdvanced `
    -Name "ShowSuperHidden" `
    -Value 0

# Explorer startet mit "Dieser PC"
Set-ItemProperty `
    -Path $ExplorerAdvanced `
    -Name "LaunchTo" `
    -Value 1
