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
