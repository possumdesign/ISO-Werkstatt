param(
    [string]$SourceRoot = (Split-Path $PSScriptRoot -Parent),
    [string]$PreviewPath
)
$ErrorActionPreference = "Stop"
. (Join-Path $SourceRoot "BuildSupport.ps1")
. (Join-Path $SourceRoot "gui\GuiSupport.ps1")
. (Join-Path $SourceRoot "gui\GuiWindow.ps1")
function Assert-Gui { param([bool]$Condition, [string]$Message) if (-not $Condition) { throw $Message } }
function Wait-GuiRun {
    param($Ui)
    $deadline = [DateTime]::UtcNow.AddSeconds(20)
    while (($Ui.Active -or $Ui.EditionRun) -and [DateTime]::UtcNow -lt $deadline) {
        # Den echten WPF-Timer/Dispatcher ausführen, kein manuelles Status-Update.
        $frame = [Windows.Threading.DispatcherFrame]::new()
        [void]$Ui.Window.Dispatcher.BeginInvoke([Windows.Threading.DispatcherPriority]::Background,
            [Action]{ $frame.Continue = $false }.GetNewClosure())
        [Windows.Threading.Dispatcher]::PushFrame($frame)
        Start-Sleep -Milliseconds 50
    }
    Assert-Gui (-not $Ui.Active -and -not $Ui.EditionRun) "GUI-Vorgang beendet sich nicht."
}
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("ISO-Werkstatt-GUI-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $testRoot | Out-Null
foreach ($dir in @("config", "answer")) { Copy-Item -LiteralPath (Join-Path $SourceRoot $dir) -Destination $testRoot -Recurse }
$stub = @'
param($WindowsIso, $VirtioIso, $Profile, $Edition, [string]$Version="0.7.0", $RunId, $LocalUserName, $Tools, $WebSearch, $UBlockLite, $QemuGuestAgent)
$ErrorActionPreference="Stop"
$dir=Join-Path $PSScriptRoot "build\logs"
New-Item -ItemType Directory -Path $dir -Force | Out-Null
$resultFile=Join-Path $dir "build-$RunId.json"
$logFile=Join-Path $dir "build-$RunId.log"
$modeFile=Join-Path $PSScriptRoot "mode.txt"
$mode=if(Test-Path $modeFile){(Get-Content $modeFile -Raw).Trim()}else{"success"}
if($mode -eq "no-status"){Write-Error "Testfehler vor Statusdatei";exit 1}
$state=[ordered]@{SchemaVersion=1;RunId=$RunId;Status="Running";Step=3;TotalSteps=10;StepName="Testschritt";Error=$null;IsoPath=$null;Sha256=$null;HashFile=$null}
$state|ConvertTo-Json|Set-Content $resultFile -Encoding UTF8
"GUI-Testprotokoll" | Set-Content $logFile -Encoding UTF8
Start-Sleep -Milliseconds 250
@{LocalUserName=$LocalUserName;ProductKeyCorrect=($env:ISO_PRODUCT_KEY -ceq "ABCDE-FGHIJ-KLMNO-PQRST-UVWXY"); ProductKeyEmpty=[string]::IsNullOrEmpty($env:ISO_PRODUCT_KEY); Tools=$Tools;WebSearch=$WebSearch;UBlockLite=$UBlockLite;QemuGuestAgent=$QemuGuestAgent;WindowsIso=$WindowsIso;VirtioIso=$VirtioIso;Edition=$Edition;PasswordCorrect=($env:ISO_LAB_PASSWORD -ceq 'Fixture&<GUI>!')}|ConvertTo-Json|Set-Content (Join-Path $PSScriptRoot 'received.json') -Encoding UTF8
if($mode -eq "failed"){$state.Status="Failed";$state.Error="Absichtlicher GUI-Testfehler";$state|ConvertTo-Json|Set-Content $resultFile -Encoding UTF8;exit 1}
$iso=Join-Path $PSScriptRoot "fixture.iso"
[IO.File]::WriteAllText($iso,"test-iso")
$hash=Get-FileHash $iso
$hash.Hash|Set-Content "$iso.sha256"
$state.Status="Succeeded";$state.Step=10;$state.IsoPath=$iso;$state.Sha256=$hash.Hash;$state.HashFile="$iso.sha256";$state.IsoSizeBytes=8
if($mode -eq "wrong-run"){$state.RunId=[guid]::NewGuid().ToString()}
if($mode -eq "invalid-state"){$state.Step="invalid"}
$state|ConvertTo-Json|Set-Content $resultFile -Encoding UTF8
if($mode -eq "bad-exit"){exit 3}
exit 0
'@
[IO.File]::WriteAllText((Join-Path $testRoot "build.ps1"), $stub, [Text.UTF8Encoding]::new($true))
$winIso=Join-Path $testRoot 'Windows & $(literal) sample.iso'
$virtIso=Join-Path $testRoot "VirtIO ' sample.iso"
[IO.File]::WriteAllText($winIso,"fixture")
[IO.File]::WriteAllText($virtIso,"fixture")
$ui=New-BuilderWindow -Root $testRoot -ViewPath (Join-Path $SourceRoot "gui\BuilderWindow.xaml")
New-Item -ItemType Directory -Path (Join-Path $testRoot 'gui') | Out-Null
@'
param($WindowsIso,$ResultPath,$RunId)
$modePath=Join-Path (Split-Path $PSScriptRoot -Parent) 'edition-mode.txt'
$mode=if(Test-Path $modePath){(Get-Content $modePath -Raw).Trim()}else{'success'}
Start-Sleep -Milliseconds 250
$state=@{RunId=$RunId;WindowsIso=$WindowsIso;Status='Succeeded';Editions=@(@{Index=1;Name='Windows 11 Home';TargetOS='Windows11';InstallationMode='Desktop'},@{Index=6;Name='Windows 11 Pro';TargetOS='Windows11';InstallationMode='Desktop'})}
if($mode -eq 'wrongrun'){$state.RunId='wrong'}
if($mode -eq 'empty'){$state.Editions=@()}
if($mode -eq 'failed'){$state.Status='Failed';$state.Error='fixture query error'}
$state|ConvertTo-Json -Depth 5|Set-Content $ResultPath -Encoding UTF8
if($mode -eq 'badexit' -or $mode -eq 'failed'){exit 1}
'@ | Set-Content (Join-Path $testRoot 'gui\Read-Editions.ps1') -Encoding UTF8
Assert-Gui ($ui.Controls.Version.Text -eq "0.7.0") "Versionsvorgabe fehlt."
Assert-Gui (-not $ui.Controls.BuildOptions.IsEnabled -and -not $ui.Controls.StartBuild.IsEnabled -and $ui.Controls.Profile.Items.Count -eq 2) 'ISO-zuerst-Sperre oder zwei Profile fehlen.'

$ui.Controls.WindowsIso.Text=$winIso
Start-BuilderEditionQuery -Ui $ui
Assert-Gui ($null -ne $ui.EditionRun -and -not $ui.Controls.StartBuild.IsEnabled) 'Editionsabfrage startet nicht oder erlaubt parallelen Build.'
$editionResultPath=$ui.EditionRun.ResultPath
Wait-GuiRun -Ui $ui
Assert-Gui ($ui.Controls.Edition.Items.Count -eq 2 -and $ui.Controls.Edition.Text -ceq 'Windows 11 Pro') 'Editionsliste oder bestehende Auswahl falsch.'
Assert-Gui (-not (Test-Path $editionResultPath)) 'Temporäres Editionsergebnis nicht aufgeräumt.'
foreach($mode in @('failed','wrongrun','empty','badexit')){
    Set-Content (Join-Path $testRoot 'edition-mode.txt') $mode
    Start-BuilderEditionQuery -Ui $ui
    Wait-GuiRun -Ui $ui
    Assert-Gui ($ui.Controls.EditionHint.Text -match 'nicht gelesen' -and $ui.Controls.InputPanel.IsEnabled) "Abfragefehler nicht behandelt: $mode"
}
$ui.Controls.WindowsIso.Text=''
Assert-Gui ($ui.Controls.Edition.Items.Count -eq 0) 'Alte Editionen nach ISO-Wechsel erhalten.'

if ($PreviewPath) {
    $ui.Controls.OptionsMenu.IsExpanded=$true
    $visual=$ui.Window.Content
    $visual.Background=$ui.Window.Background
    $visual.Measure([Windows.Size]::new(1040,820))
    $visual.Arrange([Windows.Rect]::new(0,0,1040,820))
    $visual.UpdateLayout()
    $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new(1040,820,96,96,[Windows.Media.PixelFormats]::Pbgra32)
    $bitmap.Render($visual)
    $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new()
    $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $stream=[IO.File]::Create($PreviewPath)
    try{$encoder.Save($stream)}finally{$stream.Dispose()}
    # Den unteren Formularbereich ebenfalls rendern: Menü und Kennwort müssen erreichbar sein.
    $ui.Window.FindName('FormScroll').ScrollToEnd()
    $visual.UpdateLayout()
    $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new(1040,820,96,96,[Windows.Media.PixelFormats]::Pbgra32)
    $bitmap.Render($visual)
    $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new()
    $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $stream=[IO.File]::Create("$PreviewPath.options.png")
    try{$encoder.Save($stream)}finally{$stream.Dispose()}
}

Start-BuilderWindowRun -Ui $ui
Assert-Gui (-not $ui.Active -and $ui.Controls.Validation.Text) "Leere Eingaben akzeptiert."
$ui.Controls.WindowsIso.Text=[IO.Path]::GetFileName($winIso)
Set-Content (Join-Path $testRoot 'edition-mode.txt') 'success'
Start-BuilderEditionQuery -Ui $ui
Wait-GuiRun -Ui $ui
$ui.Controls.VirtioIso.Text=$virtIso
$edition='Windows "Pro" & $(literal) trailing\'
$ui.MediaEditions+= [pscustomobject]@{Index=8;Name=$edition;TargetOS='Windows11';InstallationMode='Desktop'}
[void]$ui.Controls.Edition.Items.Add($edition)
$ui.Controls.Edition.SelectedItem=$edition
$ui.Controls.Password.Password='Fixture&<GUI>!'
$previousPassword=$env:ISO_LAB_PASSWORD
$ui.Controls.ProductKey.Password='abcde-fghij-klmno-pqrst-uvwxy'
Start-BuilderWindowRun -Ui $ui
Assert-Gui ($ui.Active -and -not $ui.Controls.InputPanel.IsEnabled) "Formular während Build aktiv."
Assert-Gui ($ui.Controls.Password.Password.Length -eq 0) "Kennwortfeld nicht geleert."
Assert-Gui (-not $ui.Run.Process.StartInfo.EnvironmentVariables.ContainsKey("ISO_LAB_PASSWORD")) "Kennwort im ProcessStartInfo verblieben."
Assert-Gui ($env:ISO_LAB_PASSWORD -ceq $previousPassword) "Elternumgebung verändert."
Wait-GuiRun -Ui $ui
Assert-Gui ($ui.Controls.Status.Text -eq "Build erfolgreich" -and $ui.Controls.OpenOutput.IsEnabled) "GUI-Erfolg nicht angezeigt."
$received=Get-Content (Join-Path $testRoot "received.json") -Raw|ConvertFrom-Json
Assert-Gui ($received.WindowsIso -ceq $winIso -and $received.VirtioIso -ceq $virtIso -and $received.Edition -ceq $edition) "Argumente verändert oder ausgewertet."
Assert-Gui ($received.ProductKeyCorrect -and $ui.Controls.ProductKey.Password.Length -eq 0) 'Keyübergabe oder Leeren des Felds fehlgeschlagen.'
Assert-Gui (-not $ui.Run.Process.StartInfo.EnvironmentVariables.ContainsKey('ISO_PRODUCT_KEY')) 'Key in ProcessStartInfo verblieben.'
Assert-Gui ($ui.Run.Process.StartInfo.Arguments -notmatch 'abcde|fghij') 'Key in Befehlszeile.'
Assert-Gui $received.PasswordCorrect "Kennwort nicht exakt an Kindprozess übergeben."
Assert-Gui ($ui.Controls.LogPreview.Text -match "GUI-Testprotokoll") "Log nicht angezeigt."

$ui.Controls.Profile.SelectedItem='PC-Lokal'
Assert-Gui ($ui.Controls.LocalUserName.Text -ceq 'Winuser') 'PC-Kontoname falsch.'
$ui.Controls.LocalUserName.Text='Technik & Test'
Assert-Gui (-not $ui.Controls.VirtioIso.IsEnabled -and -not $ui.Controls.IncludeQemu.IsChecked) 'PC-Vorgaben falsch.'
$ui.Controls.IncludeQemu.IsChecked=$true
Assert-Gui ($ui.Controls.VirtioIso.IsEnabled) 'QEMU fordert keine VirtIO-ISO.'
$ui.Controls.IncludeQemu.IsChecked=$false
$ui.Controls.VirtioIso.Text='nicht-vorhanden.iso'
$ui.Controls.IncludeTools.IsChecked=$false
$ui.Controls.DisableWebSearch.IsChecked=$false
$ui.Controls.IncludeUBlockLite.IsChecked=$false
$ui.Controls.Password.Password='Fixture&<GUI>!'
$previousKey=$env:ISO_PRODUCT_KEY
try {
    $env:ISO_PRODUCT_KEY='must-not-leak-from-parent'
    Start-BuilderWindowRun -Ui $ui
    Assert-Gui ($ui.Active) 'PC-Build verlangt unnötige VirtIO-ISO.'
    Wait-GuiRun -Ui $ui
    $received=Get-Content (Join-Path $testRoot 'received.json') -Raw|ConvertFrom-Json
    Assert-Gui ($received.LocalUserName -ceq 'Technik & Test') 'Kontoname bei Prozessübergabe verändert.'
    Assert-Gui ($received.ProductKeyEmpty -and $received.Tools -eq 'Off' -and $received.WebSearch -eq 'Off' -and $received.UBlockLite -eq 'Off' -and $received.QemuGuestAgent -eq 'Off') 'GUI-Auswahl nicht im Kindprozess angekommen.'
    Assert-Gui ($env:ISO_PRODUCT_KEY -ceq 'must-not-leak-from-parent') 'Elternschlüssel verändert.'
} finally { $env:ISO_PRODUCT_KEY=$previousKey }
$ui.Controls.Profile.SelectedItem='Proxmox VM'
Assert-Gui ($ui.Controls.LocalUserName.Text -ceq 'LabAdmin') 'Kontoname bei Profilwechsel nicht zurückgesetzt.'
$ui.Controls.VirtioIso.Text=$virtIso
Assert-Gui ($ui.Controls.IncludeTools.IsChecked -and $ui.Controls.IncludeQemu.IsChecked -and $ui.Controls.DisableWebSearch.IsChecked -and $ui.Controls.IncludeUBlockLite.IsChecked) 'Profilwechsel setzt Auswahl nicht zurück.'
foreach($mode in @("failed","bad-exit","wrong-run","invalid-state","no-status")) {
    Set-Content (Join-Path $testRoot "mode.txt") $mode
    $ui.Controls.Password.Password='Fixture&<GUI>!'
    Start-BuilderWindowRun -Ui $ui
    Assert-Gui (-not $ui.Controls.OpenOutput.IsEnabled -and -not $ui.Controls.CopyHash.IsEnabled) "Altes Ergebnis nicht zurückgesetzt."
    Wait-GuiRun -Ui $ui
    Assert-Gui ($ui.Controls.Status.Text -eq "Build fehlgeschlagen" -and -not $ui.Controls.OpenOutput.IsEnabled) "Falscher Erfolgsstatus für $mode."
}
$profilePath=Join-Path $testRoot "config\lab-config.psd1"
$profile=[IO.File]::ReadAllText($profilePath)
[IO.File]::WriteAllText($profilePath,$profile.Replace('"Windows11"','"UnknownOS"'),[Text.UTF8Encoding]::new($true))
Update-GuiProfile -Ui $ui
Assert-Gui (-not $ui.Controls.StartBuild.IsEnabled) "Ungültiges Zielsystem freigegeben."
$ui.Window.Close()
Write-Host "PASS: WPF-Fenster, PC/VM-Profile, Zusatzoptionen, Schlüssel/Kennwort, Prozess/Status/Fehler und Logs."
Write-Host "Testartefakte: $testRoot"
