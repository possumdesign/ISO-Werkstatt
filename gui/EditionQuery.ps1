function Start-GuiEditionQuery {
    param([string]$Root, [string]$WindowsIso)
    if ([string]::IsNullOrWhiteSpace($WindowsIso)) { throw 'Bitte zuerst eine Windows-ISO auswählen.' }
    if (-not [IO.Path]::IsPathRooted($WindowsIso)) { $WindowsIso=Join-Path $Root $WindowsIso }
    $WindowsIso=[IO.Path]::GetFullPath($WindowsIso)
    if (-not [IO.File]::Exists($WindowsIso) -or [IO.Path]::GetExtension($WindowsIso) -ine '.iso') { throw 'Bitte eine vorhandene Windows-ISO auswählen.' }
    $id=[guid]::NewGuid().ToString()
    $directory=Join-Path ([IO.Path]::GetTempPath()) "ISO-Werkstatt-editions-$id"
    [void][IO.Directory]::CreateDirectory($directory)
    $path=Join-Path $directory 'result.json'
    $info=[Diagnostics.ProcessStartInfo]::new()
    $info.FileName=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $arguments=@('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',
        (Join-Path $Root 'gui\Read-Editions.ps1'),'-WindowsIso',$WindowsIso,'-ResultPath',$path,'-RunId',$id)
    $info.Arguments=($arguments | ForEach-Object { ConvertTo-ProcessArgument $_ }) -join ' '
    $info.WorkingDirectory=$Root
    $info.UseShellExecute=$false; $info.CreateNoWindow=$true
    $info.RedirectStandardOutput=$true; $info.RedirectStandardError=$true
    $info.EnvironmentVariables.Remove('ISO_LAB_PASSWORD')
    $info.EnvironmentVariables.Remove('ISO_PRODUCT_KEY')
    $process=[Diagnostics.Process]::new(); $process.StartInfo=$info
    try {
        if (-not $process.Start()) { throw 'Editionsabfrage konnte nicht gestartet werden.' }
        $stdout=$process.StandardOutput.ReadToEndAsync()
        $stderr=$process.StandardError.ReadToEndAsync()
    }
    catch {
        $process.Dispose()
        [IO.Directory]::Delete($directory)
        throw
    }
    [pscustomobject]@{ RunId=$id; WindowsIso=$WindowsIso; ResultPath=$path; Directory=$directory; Process=$process; Stdout=$stdout; Stderr=$stderr }
}

function Start-BuilderEditionQuery {
    param($Ui)
    if ($Ui.Active -or $Ui.EditionRun) { return }
    try {
        $Ui.EditionRun=Start-GuiEditionQuery -Root $Ui.Root -WindowsIso $Ui.Controls.WindowsIso.Text.Trim()
        Reset-GuiMedia -Ui $Ui
        $Ui.Controls.InputPanel.IsEnabled=$false
        $Ui.Controls.StartBuild.IsEnabled=$false
        $Ui.Controls.EditionHint.Text='Editionen werden aus der ISO gelesen …'
        $Ui.Controls.Validation.Text=''
        $Ui.Timer.Start()
    }
    catch { Reset-GuiMedia -Ui $Ui; $Ui.Controls.EditionHint.Text=$_.Exception.Message }
}

function Update-BuilderEditionQuery {
    param($Ui)
    $run=$Ui.EditionRun
    if (-not $run -or -not $run.Process.HasExited -or -not $run.Stdout.IsCompleted -or -not $run.Stderr.IsCompleted) { return }
    try {
        $result=Read-SharedText -Path $run.ResultPath | ConvertFrom-Json -ErrorAction Stop
        if (-not $result -or $result.RunId -ne $run.RunId -or $result.WindowsIso -ine $run.WindowsIso) { throw 'Die Editionsabfrage lieferte kein passendes Ergebnis.' }
        if ($run.Process.ExitCode -ne 0 -or $result.Status -ne 'Succeeded') {
            if ($result.Error) { throw [string]$result.Error }
            throw 'Die Editionsabfrage ist fehlgeschlagen.'
        }
        $editions=@($result.Editions)
        if (-not $editions.Count -or @($editions | Where-Object { $_.Name -isnot [string] -or [string]::IsNullOrWhiteSpace($_.Name) -or $_.Index -lt 1 }).Count) { throw 'Die Editionsliste ist leer oder ungültig.' }
        $current=$Ui.Controls.WindowsIso.Text.Trim()
        if(-not [IO.Path]::IsPathRooted($current)){$current=Join-Path $Ui.Root $current}
        if([IO.Path]::GetFullPath($current) -ine $run.WindowsIso){throw 'Die ISO-Auswahl wurde während der Abfrage geändert.'}
        Set-GuiMedia -Ui $Ui -Editions $editions -Source $run.WindowsIso
        $Ui.Controls.EditionHint.Text="$($editions.Count) Editionen gefunden. Auswahl vor dem Build prüfen."
    }
    catch { Reset-GuiMedia -Ui $Ui; $Ui.Controls.EditionHint.Text="Editionen konnten nicht gelesen werden: $($_.Exception.Message)" }
    finally {
        $run.Process.Dispose()
        $Ui.EditionRun=$null
        $Ui.Timer.Stop()
        $Ui.Controls.InputPanel.IsEnabled=$true
        if($Ui.EditionSource){Update-GuiProfile -Ui $Ui}
        try {
            if ([IO.File]::Exists($run.ResultPath)) { [IO.File]::Delete($run.ResultPath) }
            [IO.Directory]::Delete($run.Directory)
        } catch { } # Temporäre Diagnose darf eine erfolgreiche Abfrage nicht verdecken.
    }
}
