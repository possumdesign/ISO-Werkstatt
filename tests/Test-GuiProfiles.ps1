param([string]$SourceRoot=(Split-Path $PSScriptRoot -Parent),[string]$PreviewDirectory)
$ErrorActionPreference='Stop'
. (Join-Path $SourceRoot 'BuildSupport.ps1')
. (Join-Path $SourceRoot 'gui\GuiSupport.ps1')
. (Join-Path $SourceRoot 'gui\GuiWindow.ps1')
function Assert-Ui($condition,$message){if(-not $condition){throw $message}}
function Save-Preview($window,$path){
    $visual=$window.Content;$visual.Background=$window.Background
    $width=[int]$window.Width;$height=[int]$window.Height
    $visual.Measure([Windows.Size]::new($width,$height));$visual.Arrange([Windows.Rect]::new(0,0,$width,$height));$visual.UpdateLayout()
    $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new($width,$height,96,96,[Windows.Media.PixelFormats]::Pbgra32);$bitmap.Render($visual)
    $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $stream=[IO.File]::Create($path);try{$encoder.Save($stream)}finally{$stream.Dispose()}
}
$root=Join-Path ([IO.Path]::GetTempPath()) ('ISO-Werkstatt-profiles-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root | Out-Null
foreach($dir in @('config','answer')){Copy-Item (Join-Path $SourceRoot $dir) $root -Recurse}
Copy-Item (Join-Path $SourceRoot 'build.ps1') $root
$ui=New-BuilderWindow -Root $root -ViewPath (Join-Path $SourceRoot 'gui\BuilderWindow.xaml')
try{
    $ui.Controls.Profile.SelectedItem='PC-Lokal'
    $ui.Controls.WindowsIso.Text='C:\ISO\Quelle & Test.iso'
    Set-GuiMedia -Ui $ui -Source $ui.Controls.WindowsIso.Text -Editions @([pscustomobject]@{Index=1;Name='Windows 11 Pro';TargetOS='Windows11';InstallationMode='Desktop'})
    $ui.Controls.LocalUserName.Text='Eigener Name'
    $ui.Controls.Password.Password='secret fixture'
    $ui.Controls.ProductKey.Password='ABCDE-FGHIJ-KLMNO-PQRST-UVWXY'
    $ui.Controls.IncludeTools.IsChecked=$false
    Set-GuiLanguage -Ui $ui -Language en
    Assert-Ui ($ui.Controls.StartBuild.Content -ceq 'Create ISO' -and $ui.Controls.EditProfile.Content -ceq 'Edit profile') 'Englische Buttons fehlen.'
    Assert-Ui ($ui.Controls.Profile.SelectedItem -ceq 'PC-Lokal' -and $ui.Controls.LocalUserName.Text -ceq 'Eigener Name' -and $ui.Controls.WindowsIso.Text -ceq 'C:\ISO\Quelle & Test.iso') 'Sprachwechsel verändert Eingaben.'
    Assert-Ui ($ui.Controls.Password.Password -ceq 'secret fixture' -and $ui.Controls.ProductKey.Password -ceq 'ABCDE-FGHIJ-KLMNO-PQRST-UVWXY' -and -not $ui.Controls.IncludeTools.IsChecked) 'Sprachwechsel verändert Geheimnisse/Optionen.'
    $ui.Controls.Status.Text='Schritt 3/10: VirtIO-Komponenten extrahieren'
    $ui.Controls.Validation.Text='Bitte das Kennwort für das lokale Konto eingeben.'
    $ui.Run=@{RunId='fixture'}
    $ui.Controls.LogPreview.Text='Build erfolgreich'
    Update-GuiLanguage -Ui $ui
    Assert-Ui ($ui.Controls.Status.Text -ceq 'Step 3/10: Extract VirtIO components') 'Laufstatus nicht übersetzt.'
    Assert-Ui ($ui.Controls.Validation.Text -ceq 'Please enter the local account password.') 'Validierung nicht übersetzt.'
    Assert-Ui ($ui.Controls.LogPreview.Text -ceq 'Build erfolgreich') 'Originalprotokoll übersetzt.'
    Set-GuiLanguage -Ui $ui -Language de
    Assert-Ui ($ui.Controls.StartBuild.Content -ceq 'ISO erstellen' -and $ui.Controls.Status.Text -ceq 'Schritt 3/10: VirtIO-Komponenten extrahieren') 'Rückwechsel fehlgeschlagen.'
    $ui.Run=$null
    $ui.Controls.Password.Clear();$ui.Controls.ProductKey.Clear();$ui.Controls.Validation.Text=''
    if($PreviewDirectory){
        New-Item -ItemType Directory -Path $PreviewDirectory -Force | Out-Null
        Save-Preview $ui.Window (Join-Path $PreviewDirectory 'builder-de.png')
        Set-GuiLanguage -Ui $ui -Language en
        Save-Preview $ui.Window (Join-Path $PreviewDirectory 'builder-en.png')
    }
    Set-GuiLanguage -Ui $ui -Language en
    $editor=New-GuiProfileEditor -Ui $ui
    Assert-Ui ($editor.Window.Title -ceq 'Edit profile' -and $editor.Controls.LocalUserName.Text -ceq 'Winuser') 'Editor lädt Sprache/Profil nicht korrekt.'
    if($PreviewDirectory){Save-Preview $editor.Window (Join-Path $PreviewDirectory 'profile-en.png')}
    $originalPath=Join-Path $root 'config\pc-local.psd1';$originalHash=(Get-FileHash $originalPath).Hash
    $editor.Controls.ProfileName.Text='pc-copy'
    $editor.Controls.LocalUserName.Text='Testkonto'
    $editor.Controls.ToolsDirectory.Text="tools\O'Neil"
    $editor.Controls.Tools.IsChecked=$false
    Save-BuilderProfileEditor -Editor $editor
    Assert-Ui ($editor.SavedName -ceq 'pc-copy') "Neue Profilkopie fehlt: $($editor.Controls.Error.Text)"
    $copyPath=Join-Path $root 'config\pc-copy.psd1'
    $data=Import-PowerShellDataFile $copyPath
    Assert-Ui ($data.LocalUserName -ceq 'Testkonto' -and $data.ToolsDirectory -ceq "tools\O'Neil" -and -not $data.Features.Tools) 'Profilwerte beim Speichern verändert.'
    Assert-Ui ((Get-FileHash $originalPath).Hash -ceq $originalHash) 'Kopie überschreibt Original.'
    Assert-Ui ((Get-Content $copyPath -Raw) -notmatch 'secret fixture|ABCDE-FGHIJ|Password|ProductKey') 'Geheimnisse im Profil.'
    $snapshot=Get-EditableGuiProfile -Root $root -Name 'pc-copy'
    $data.Edition='Windows 11 Pro N'
    $saved=Save-GuiProfile -Root $root -Name 'PC-COPY' -Data $data -OriginalName $snapshot.Name -OriginalHash $snapshot.Hash
    Assert-Ui ($saved -ceq 'pc-copy' -and (Import-PowerShellDataFile $copyPath).Edition -ceq 'Windows 11 Pro N') 'Vorhandenes Profil nicht aktualisiert.'
    foreach($badName in @('pc-local','..\escape','CON','bad.name')){
        $rejected=$false;try{Save-GuiProfile -Root $root -Name $badName -Data $data -OriginalName 'pc-copy' -OriginalHash (Get-FileHash $copyPath).Hash | Out-Null}catch{$rejected=$true}
        Assert-Ui $rejected 'Kollision oder ungültiger Profilname akzeptiert.'
    }
    $snapshot=Get-EditableGuiProfile -Root $root -Name 'pc-copy'
    Add-Content $copyPath '# concurrent edit'
    $concurrent=[IO.File]::ReadAllText($copyPath)
    $rejected=$false;try{Save-GuiProfile -Root $root -Name 'pc-copy' -Data $data -OriginalName $snapshot.Name -OriginalHash $snapshot.Hash | Out-Null}catch{$rejected=$true}
    Assert-Ui ($rejected -and [IO.File]::ReadAllText($copyPath) -ceq $concurrent) 'Zwischenzeitliche Änderung überschrieben.'
    $data.Password='must not save'
    $rejected=$false;try{Save-GuiProfile -Root $root -Name 'bad-secret' -Data $data}catch{$rejected=$true}
    Assert-Ui ($rejected -and -not (Test-Path (Join-Path $root 'config\bad-secret.psd1'))) 'Unbekannte Profilwerte gespeichert.'
    $editor=New-GuiProfileEditor -Ui $ui
    $editor.Controls.LocalUserName.Text='not/supported'
    Save-BuilderProfileEditor -Editor $editor
    Assert-Ui (-not $editor.SavedName -and $editor.Controls.Error.Text -match 'Invalid account name') 'Editor-Validierung fehlt.'
    $editor.Window.Close()
    Assert-Ui ((Get-FileHash $originalPath).Hash -ceq $originalHash) 'Fehler/Abbrechen verändert Profil.'
    Set-GuiMedia -Ui $ui -Source $ui.Controls.WindowsIso.Text -Editions @([pscustomobject]@{Index=1;Name='Server Core';TargetOS='Server2025';InstallationMode='Core'})
    $ui.Controls.CoreInstall.IsChecked=$true
    Assert-Ui ($ui.Controls.StartBuild.IsEnabled -and -not $ui.Controls.IncludeUBlockLite.IsEnabled -and -not $ui.Controls.DisableWebSearch.IsEnabled) 'Core-Profil oder Desktop-Optionssperre falsch.'
    $editor=New-GuiProfileEditor -Ui $ui
    Assert-Ui ($editor.Controls.InstallationMode.SelectedItem -eq 'Core') 'Core-Modus im Editor verloren.'
    $editor.Controls.ProfileName.Text='server-core-copy'
    Save-BuilderProfileEditor -Editor $editor
    Assert-Ui ((Import-PowerShellDataFile (Join-Path $root 'config\server-core-copy.psd1')).InstallationMode -eq 'Core') 'Core-Modus nicht gespeichert.'
    Set-GuiMedia -Ui $ui -Source $ui.Controls.WindowsIso.Text -Editions @([pscustomobject]@{Index=1;Name='Windows 10 Pro';TargetOS='Windows10';InstallationMode='Desktop'})
    Assert-Ui ($ui.Controls.StartBuild.IsEnabled -and $ui.Controls.IncludeUBlockLite.IsEnabled) 'Windows-10-Profil gesperrt.'
}finally{$ui.Window.Close()}
Write-Host 'PASS: DE/EN, Eingaben/Geheimnisse/Logs unverändert, Profile öffnen/kopieren/speichern, Validierung, Konflikte und Abbrechen.'
Write-Host "Testartefakte: $root"
