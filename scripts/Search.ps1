# Windows-Suche: Web/Bing deaktivieren

# Systemweite Search-Policies
$PolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"

New-Item -Path $PolicyPath -Force | Out-Null

New-ItemProperty `
    -Path $PolicyPath `
    -Name "DisableWebSearch" `
    -PropertyType DWord `
    -Value 1 `
    -Force | Out-Null

New-ItemProperty `
    -Path $PolicyPath `
    -Name "ConnectedSearchUseWeb" `
    -PropertyType DWord `
    -Value 0 `
    -Force | Out-Null

# Benutzerbezogene Bing-/Websuche deaktivieren
$SearchPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"

New-Item -Path $SearchPath -Force | Out-Null

New-ItemProperty `
    -Path $SearchPath `
    -Name "BingSearchEnabled" `
    -PropertyType DWord `
    -Value 0 `
    -Force | Out-Null

# Suchfeld-/Explorer-Vorschläge deaktivieren
$ExplorerPolicy = "HKCU:\Software\Policies\Microsoft\Windows\Explorer"

New-Item -Path $ExplorerPolicy -Force | Out-Null

New-ItemProperty `
    -Path $ExplorerPolicy `
    -Name "DisableSearchBoxSuggestions" `
    -PropertyType DWord `
    -Value 1 `
    -Force | Out-Null
