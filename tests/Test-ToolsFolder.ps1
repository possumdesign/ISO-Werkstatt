param([string]$SourceRoot=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
. (Join-Path $SourceRoot 'BuildSupport.ps1')
. (Join-Path $SourceRoot 'gui\GuiSupport.ps1')
. (Join-Path $SourceRoot 'gui\GuiWindow.ps1')
$root=Join-Path $env:TEMP ('ISO-Crafter-tools-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $root | Out-Null
foreach($dir in @('config','answer')){Copy-Item (Join-Path $SourceRoot $dir) $root -Recurse}
Copy-Item (Join-Path $SourceRoot 'build.ps1') $root
$ui=New-BuilderWindow -Root $root -ViewPath (Join-Path $SourceRoot 'gui\BuilderWindow.xaml')
$calls=[Collections.Generic.List[object]]::new()
function Start-Process {param($FilePath,$ArgumentList,$ErrorAction) $calls.Add(@{File=$FilePath;Arguments=$ArgumentList})}
try {
    if($ui.Controls.OpenToolsFolder.IsEnabled){throw 'Tools vor ISO-Erkennung bedienbar.'}
    $ui.Controls.WindowsIso.Text='C:\ISO\fixture.iso'
    Set-GuiMedia -Ui $ui -Source $ui.Controls.WindowsIso.Text -Editions @([pscustomobject]@{Index=1;Name='Windows 10 Pro';TargetOS='Windows10';InstallationMode='Desktop'})
    $ui.ProfileInfo.ToolsDirectory="tools & O'Neil"
    $ui.Controls.IncludeTools.IsChecked=$false
    $ui.Controls.OpenToolsFolder.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
    $path=Join-Path $root $ui.ProfileInfo.ToolsDirectory
    if(-not (Test-Path -LiteralPath $path -PathType Container) -or $calls.Count -ne 1 -or $calls[0].File -ne 'explorer.exe' -or $calls[0].Arguments -cne (ConvertTo-ProcessArgument $path)){throw 'Falscher Profilordner oder fehlerhaftes Explorer-Argument.'}
    $ui.Active=$true;Open-GuiToolsFolder -Ui $ui;$ui.Active=$false
    if($calls.Count -ne 1){throw 'Ordner während Build geöffnet.'}
    Set-GuiLanguage -Ui $ui -Language en
    if($ui.Controls.OpenToolsFolder.Content -cne 'Open tools folder' -or $ui.Controls.OpenToolsFolder.ToolTip -notlike 'Place your own*'){throw 'Englischer Button/Tooltip fehlt.'}
    Set-GuiLanguage -Ui $ui -Language de
    if($ui.Controls.OpenToolsFolder.Content -cne 'Tools-Ordner öffnen'){throw 'Rückwechsel fehlt.'}
    Write-Host 'PASS: Tools-Button, Profilpfad, Ordneranlage, ISO-/Build-Sperre und DE/EN-Hilfe.'
} finally {$ui.Active=$false;$ui.Window.Close()}
