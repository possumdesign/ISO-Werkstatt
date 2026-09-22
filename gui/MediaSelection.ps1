function Reset-GuiMedia {
    param($Ui)
    $Ui.EditionSource=$null
    $Ui.MediaEditions=@()
    $Ui.EffectiveProfile=$null
    $Ui.ProfileInfo=$null
    $Ui.Controls.Validation.Text=''
    $Ui.Controls.CoreInstall.IsChecked=$false
    $Ui.Controls.CoreInstall.Visibility='Collapsed'
    $Ui.Controls.Edition.Items.Clear()
    $Ui.Controls.Edition.Text=''
    $Ui.Controls.BuildOptions.IsEnabled=$false
    $Ui.Controls.StartBuild.IsEnabled=$false
    $Ui.Controls.ProfileSummary.Text='Bitte zuerst eine Windows-ISO auswählen und erkennen lassen.'
}

function Set-GuiMedia {
    param($Ui,$Editions,[string]$Source)
    $targets=@($Editions | Select-Object -ExpandProperty TargetOS -Unique)
    if($targets.Count -ne 1 -or $targets[0] -notin @('Windows11','Windows10','Server2022','Server2025')){throw 'Die ISO enthält kein eindeutig unterstütztes Windows-Zielsystem.'}
    if(@($Editions | Where-Object { $_.InstallationMode -notin @('Desktop','Core') -or ($targets[0] -like 'Windows*' -and $_.InstallationMode -eq 'Core') }).Count){throw 'Ungültige Installationsvariante in der ISO.'}
    $Ui.Controls.EditionHint.Text="$($Editions.Count) Editionen gefunden. Auswahl vor dem Build prüfen."
    $Ui.MediaEditions=@($Editions)
    $Ui.EditionSource=$Source
    $Ui.Controls.CoreInstall.IsChecked=$false
    $hasCore=$targets[0] -like 'Server*' -and @($Editions | Where-Object InstallationMode -eq 'Core').Count -gt 0
    $Ui.Controls.CoreInstall.Visibility=if($hasCore){'Visible'}else{'Collapsed'}
    $Ui.Controls.BuildOptions.IsEnabled=$true
    Update-GuiProfile -Ui $Ui
}

function Get-GuiEffectiveProfile {
    param($Ui)
    if(-not $Ui.EditionSource -or -not $Ui.MediaEditions.Count){throw 'Bitte zuerst eine Windows-ISO auswählen und erkennen lassen.'}
    $target=$Ui.MediaEditions[0].TargetOS
    $local=$Ui.Controls.Profile.SelectedItem -eq 'PC-Lokal'
    $suffix=if($local){'local'}else{'vm'}
    if($target -eq 'Windows11'){if($local){return 'pc-local'}else{return 'lab-config'}}
    if($target -eq 'Windows10'){return "win10-$suffix"}
    $mode=if($Ui.Controls.CoreInstall.IsChecked){'core'}else{'desktop'}
    return "$($target.ToLowerInvariant())-$mode-$suffix"
}

function Assert-GuiMediaSelection {
    param($Ui)
    $path=$Ui.Controls.WindowsIso.Text.Trim()
    if(-not [IO.Path]::IsPathRooted($path)){$path=Join-Path $Ui.Root $path}
    if(-not $Ui.EditionSource -or [IO.Path]::GetFullPath($path) -ine $Ui.EditionSource){throw 'Bitte zuerst eine Windows-ISO auswählen und erkennen lassen.'}
    $mode=if($Ui.Controls.CoreInstall.IsChecked){'Core'}else{'Desktop'}
    $matches=@($Ui.MediaEditions | Where-Object { $_.Name -eq $Ui.Controls.Edition.Text -and $_.InstallationMode -eq $mode })
    if($matches.Count -ne 1){throw 'Bitte eine passende Edition aus der ISO auswählen.'}
    $expected=Get-GuiEffectiveProfile -Ui $Ui
    if($Ui.EffectiveProfile -ne $expected){throw 'Die Profilauswahl ist nicht mehr aktuell.'}
    $profile=Get-GuiProfile -Path (Join-Path $Ui.Root "config\$expected.psd1")
    if($profile.TargetOS -ne $matches[0].TargetOS -or $profile.InstallationMode -ne $mode){throw 'Das gespeicherte Profil passt nicht zur erkannten ISO.'}
}
