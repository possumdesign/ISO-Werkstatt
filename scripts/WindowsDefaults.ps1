$RuntimeTargetPath=Join-Path $PSScriptRoot 'target.psd1'
$RuntimeOS=if(Test-Path -LiteralPath $RuntimeTargetPath){(Import-PowerShellDataFile -LiteralPath $RuntimeTargetPath).TargetOS}else{'Windows11'}
if($RuntimeOS -like 'Server*'){return}
if($RuntimeOS -eq 'Windows10'){
    $Feeds='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds'
    New-Item -Path $Feeds -Force | Out-Null
    New-ItemProperty -Path $Feeds -Name 'EnableFeeds' -PropertyType DWord -Value 0 -Force | Out-Null
}else{
# Widgets abschalten
$DshPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"

New-Item -Path $DshPolicy -Force | Out-Null

New-ItemProperty `
    -Path $DshPolicy `
    -Name "AllowNewsAndInterests" `
    -PropertyType DWord `
    -Value 0 `
    -Force | Out-Null


}
# Consumer Experience reduzieren
$CloudContent = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"

New-Item -Path $CloudContent -Force | Out-Null

New-ItemProperty `
    -Path $CloudContent `
    -Name "DisableWindowsConsumerFeatures" `
    -PropertyType DWord `
    -Value 1 `
    -Force | Out-Null


# Vorschläge / Werbung / Tipps reduzieren
$ContentDelivery = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"

if(-not (Test-Path -LiteralPath $ContentDelivery)) { New-Item -Path $ContentDelivery -Force | Out-Null }
$Values = @{
    "ContentDeliveryAllowed"        = 0
    "OemPreInstalledAppsEnabled"    = 0
    "PreInstalledAppsEnabled"       = 0
    "PreInstalledAppsEverEnabled"   = 0
    "SilentInstalledAppsEnabled"    = 0
    "SubscribedContent-338388Enabled" = 0
    "SubscribedContent-338389Enabled" = 0
    "SubscribedContent-353694Enabled" = 0
    "SubscribedContent-353696Enabled" = 0
    "SystemPaneSuggestionsEnabled"  = 0
}

foreach ($Name in $Values.Keys) {
    New-ItemProperty `
        -Path $ContentDelivery `
        -Name $Name `
        -PropertyType DWord `
        -Value $Values[$Name] `
        -Force | Out-Null
}
