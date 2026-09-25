param([string]$SourceRoot=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
. (Join-Path $SourceRoot 'BuildSupport.ps1')
. (Join-Path $SourceRoot 'gui\GuiSupport.ps1')
. (Join-Path $SourceRoot 'gui\GuiWindow.ps1')
$ui=New-BuilderWindow -Root $SourceRoot -ViewPath (Join-Path $SourceRoot 'gui\BuilderWindow.xaml')
function Get-GuiBuildState { param($Run) return @{Status='Running';Step=3;TotalSteps=10;StepName='VirtIO-Komponenten extrahieren'} }
function Read-SharedText { param($Path) return 'Originalprotokoll bleibt deutsch.' }
try {
    # Die Statusaktualisierung muss ohne nachträglichen Übersetzungstimer korrekt sein.
    $ui.LocalizationTimer.Stop()
    $ui.Run=@{StartedAt=[DateTime]::UtcNow.AddSeconds(-10);LogPath='unused';Process=@{HasExited=$false}}
    $ui.Active=$true
    Set-GuiLanguage -Ui $ui -Language en
    $changes=[Collections.Generic.List[string]]::new()
    $descriptor=[ComponentModel.DependencyPropertyDescriptor]::FromProperty([Windows.Controls.TextBlock]::TextProperty,[Windows.Controls.TextBlock])
    $handler=[EventHandler]{param($sender,$eventArgs) $changes.Add($sender.Text)}.GetNewClosure()
    $descriptor.AddValueChanged($ui.Controls.Status,$handler)
    try {
        for($i=0;$i -lt 5;$i++){
            Update-BuilderWindow -Ui $ui
            if($ui.Controls.Status.Text -cne 'Step 3/10: Extract VirtIO components' -or $ui.Controls.Duration.Text -notlike 'Elapsed: *'){throw 'Status zunächst auf Deutsch geschrieben.'}
            Update-GuiLanguage -Ui $ui
        }
        if(@($changes | Where-Object {$_ -like 'Schritt *'}).Count){throw 'Deutscher Zwischenzustand: Flackern.'}
        if($changes.Count -ne 1){throw 'Unveränderter Status wird wiederholt umgeschrieben.'}
        Set-GuiLanguage -Ui $ui -Language de
        Update-BuilderWindow -Ui $ui
        if($ui.Controls.Status.Text -cne 'Schritt 3/10: VirtIO-Komponenten extrahieren'){throw 'Deutsch-Rückwechsel fehlerhaft.'}
        Set-GuiLanguage -Ui $ui -Language en
        Update-BuilderWindow -Ui $ui
        if($ui.Controls.Status.Text -cne 'Step 3/10: Extract VirtIO components'){throw 'Englisch-Rückwechsel fehlerhaft.'}
        if($ui.Controls.LogPreview.Text -cne 'Originalprotokoll bleibt deutsch.'){throw 'Originallog wurde übersetzt.'}
    } finally {$descriptor.RemoveValueChanged($ui.Controls.Status,$handler)}
    Write-Host 'PASS: Status sofort in Sitzungssprache, kein Sprachflackern, DE/EN-Wechsel und Originallog.'
} finally {$ui.Active=$false;$ui.Window.Close()}
