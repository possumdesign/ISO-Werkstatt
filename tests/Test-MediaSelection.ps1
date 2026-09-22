param([string]$SourceRoot=(Split-Path $PSScriptRoot -Parent),[string]$PreviewPath)
$ErrorActionPreference='Stop'
. (Join-Path $SourceRoot 'BuildSupport.ps1')
. (Join-Path $SourceRoot 'gui\GuiSupport.ps1')
. (Join-Path $SourceRoot 'gui\GuiWindow.ps1')
function Assert-Media($condition,$message){if(-not $condition){throw $message}}
$ui=New-BuilderWindow -Root $SourceRoot -ViewPath (Join-Path $SourceRoot 'gui\BuilderWindow.xaml')
try {
    Assert-Media ($ui.Controls.Profile.Items.Count -eq 2 -and -not $ui.Controls.StartBuild.IsEnabled -and -not $ui.Controls.BuildOptions.IsEnabled) 'Start ohne ISO freigegeben.'
    foreach($target in @('Windows11','Windows10','Server2022','Server2025')) {
        $ui.Controls.WindowsIso.Text="C:\ISO\$target.iso"
        $editions=@([pscustomobject]@{Index=2;Name="$target Desktop Standard";TargetOS=$target;InstallationMode='Desktop'},[pscustomobject]@{Index=4;Name="$target Desktop Datacenter";TargetOS=$target;InstallationMode='Desktop'})
        if($target -like 'Server*'){$editions+= [pscustomobject]@{Index=1;Name="$target Core Standard";TargetOS=$target;InstallationMode='Core'}}
        Set-GuiMedia -Ui $ui -Source $ui.Controls.WindowsIso.Text -Editions $editions
        Assert-Media (-not $ui.Controls.CoreInstall.IsChecked -and $ui.Controls.Edition.Items.Count -eq 2) 'Desktop-Standard oder Filter falsch.'
        Assert-Media (($ui.Controls.CoreInstall.Visibility -eq 'Visible') -eq ($target -like 'Server*')) 'Core-Haken bei falschem Medium sichtbar.'
        foreach($purpose in @('PC-Lokal','Proxmox VM')) {
            $ui.Controls.Profile.SelectedItem=$purpose
            Assert-GuiMediaSelection -Ui $ui
            Assert-Media ($ui.ProfileInfo.TargetOS -eq $target -and $ui.ProfileInfo.InstallationMode -eq 'Desktop') 'Falsche Zielzuordnung.'
            Assert-Media ($ui.ProfileInfo.IncludeVirtioDrivers -eq ($purpose -eq 'Proxmox VM')) 'Falsche Treibervorgabe.'
            if($target -like 'Server*') {
                $ui.Controls.CoreInstall.IsChecked=$true
                Assert-GuiMediaSelection -Ui $ui
                Assert-Media ($ui.ProfileInfo.InstallationMode -eq 'Core' -and $ui.Controls.Edition.Items.Count -eq 1 -and -not $ui.Controls.IncludeUBlockLite.IsEnabled) 'Core-Profil/Filter falsch.'
                $ui.Controls.CoreInstall.IsChecked=$false
                Assert-GuiMediaSelection -Ui $ui
            }
        }
    }
    if($PreviewPath){
        $visual=$ui.Window.Content; $visual.Background=$ui.Window.Background
        $visual.Measure([Windows.Size]::new(1040,820));$visual.Arrange([Windows.Rect]::new(0,0,1040,820));$visual.UpdateLayout()
        $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new(1040,820,96,96,[Windows.Media.PixelFormats]::Pbgra32);$bitmap.Render($visual)
        $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
        $stream=[IO.File]::Create($PreviewPath);try{$encoder.Save($stream)}finally{$stream.Dispose()}
    }
    Set-GuiMedia -Ui $ui -Source $ui.Controls.WindowsIso.Text -Editions @([pscustomobject]@{Index=1;Name='Core only';TargetOS='Server2025';InstallationMode='Core'})
    Assert-Media (-not $ui.Controls.StartBuild.IsEnabled -and -not $ui.Controls.CoreInstall.IsChecked) 'Core-only startet ohne ausdrückliche Auswahl.'
    $ui.Controls.CoreInstall.IsChecked=$true
    Assert-Media $ui.Controls.StartBuild.IsEnabled 'Core-only bleibt gesperrt.'
    $ui.Controls.WindowsIso.Text='C:\ISO\Andere.iso'
    Assert-Media (-not $ui.Controls.BuildOptions.IsEnabled -and -not $ui.Controls.CoreInstall.IsChecked -and $ui.Controls.CoreInstall.Visibility -eq 'Collapsed' -and $ui.Controls.Edition.Items.Count -eq 0) 'ISO-Wechsel behält alte Optionen.'
    $rejected=$false;try{Assert-GuiMediaSelection -Ui $ui}catch{$rejected=$true}
    Assert-Media $rejected 'Build ohne aktuelle Erkennung möglich.'
    Write-Host 'PASS: ISO zuerst, zwei Einsatzarten, alle Zielzuordnungen, Core-Filter und Zurücksetzen.'
} finally {$ui.Window.Close()}
