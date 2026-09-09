# Microsoft Edge - Lab Defaults

$EdgePolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"

New-Item -Path $EdgePolicy -Force | Out-Null

# First-Run / Einrichtung überspringen
New-ItemProperty `
    -Path $EdgePolicy `
    -Name "HideFirstRunExperience" `
    -PropertyType DWord `
    -Value 1 `
    -Force | Out-Null

# Microsoft-Inhalte / News auf neuer Tab-Seite aus
New-ItemProperty `
    -Path $EdgePolicy `
    -Name "NewTabPageContentEnabled" `
    -PropertyType DWord `
    -Value 0 `
    -Force | Out-Null

# Sidebar aus
New-ItemProperty `
    -Path $EdgePolicy `
    -Name "HubsSidebarEnabled" `
    -PropertyType DWord `
    -Value 0 `
    -Force | Out-Null

# Kein wiederholtes Browserdaten-Import-Gefrage
New-ItemProperty `
    -Path $EdgePolicy `
    -Name "ImportOnEachLaunch" `
    -PropertyType DWord `
    -Value 0 `
    -Force | Out-Null

# ------------------------------------------------------------
# uBlock Origin Lite automatisch installieren
# ------------------------------------------------------------

$ExtensionPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist"

New-Item -Path $ExtensionPolicy -Force | Out-Null

New-ItemProperty `
    -Path $ExtensionPolicy `
    -Name "1" `
    -PropertyType String `
    -Value "cimighlppcgcoapaliogpjjdehbnofhn;https://edge.microsoft.com/extensionwebstorebase/v1/crx" `
    -Force | Out-Null