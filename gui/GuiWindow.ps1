Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
. (Join-Path $PSScriptRoot 'EditionQuery.ps1')
. (Join-Path $PSScriptRoot 'MediaSelection.ps1')
. (Join-Path $PSScriptRoot 'Localization.ps1')
. (Join-Path $PSScriptRoot 'ProfileEditor.ps1')

function Update-GuiProfile {
    param($Ui)
    try {
        $name = Get-GuiEffectiveProfile -Ui $Ui
        if ([string]::IsNullOrWhiteSpace($name)) { throw "Im Ordner config wurde kein Profil gefunden." }
        $profile = Get-GuiProfile -Path (Join-Path $Ui.Root "config\$name.psd1")
        $mode=if($Ui.Controls.CoreInstall.IsChecked){'Core'}else{'Desktop'}
        if($profile.TargetOS -ne $Ui.MediaEditions[0].TargetOS -or $profile.InstallationMode -ne $mode){throw 'Das gespeicherte Profil passt nicht zur erkannten ISO.'}
        $selected=$Ui.Controls.Edition.Text
        $names=@($Ui.MediaEditions | Where-Object InstallationMode -eq $mode | Select-Object -ExpandProperty Name)
        $Ui.Controls.Edition.Items.Clear()
        foreach($editionName in $names){[void]$Ui.Controls.Edition.Items.Add($editionName)}
        if($selected -notin $names){$selected=if($profile.Edition -in $names){$profile.Edition}elseif($names.Count){$names[0]}else{''}}
        $Ui.Controls.Edition.SelectedItem=$selected
        $Ui.EffectiveProfile=$name
        $Ui.Controls.LocalUserName.Text = $profile.LocalUserName
        $Ui.ProfileInfo = $profile
        $isCore=$profile.InstallationMode -eq 'Core'
        $Ui.Controls.DisableWebSearch.IsEnabled=-not $isCore
        $Ui.Controls.IncludeUBlockLite.IsEnabled=-not $isCore
        $Ui.Controls.IncludeTools.IsChecked = $profile.Features.Tools
        $Ui.Controls.DisableWebSearch.IsChecked = $profile.Adjustments.Search
        $Ui.Controls.IncludeUBlockLite.IsChecked = $profile.Features.UBlockLite
        $Ui.Controls.IncludeQemu.IsChecked = $profile.Features.QemuGuestAgent
        $driverText = if ($profile.IncludeVirtioDrivers) { 'mit VirtIO-Treibern' } else { 'ohne VirtIO-Treiber' }
        if ($Ui.Controls.Profile.SelectedItem -eq 'PC-Lokal') { $driverText += ' · Zielpartition manuell wählen' }
        $Ui.Controls.ProfileSummary.Text = "$($profile.TargetOS) · $($profile.InstallationMode) · $driverText"
        if(-not $profile.InstallationTested){$Ui.Controls.ProfileSummary.Text += ' · Installationstest ausstehend'}
        Update-GuiVirtioRequirement -Ui $Ui
        $Ui.Controls.Validation.Text = ""
        if (-not $profile.Supported) { throw "Dieses Zielsystem ist vorbereitet, aber noch nicht für Builds freigegeben." }
        $Ui.Controls.StartBuild.IsEnabled = $names.Count -gt 0 -and -not ($Ui.Active -or $Ui.EditionRun)
        if(-not $names.Count){$Ui.Controls.Validation.Text='Keine Desktop-Edition vorhanden. Für diese ISO Core – Headless auswählen.'}
    }
    catch {
        $Ui.Controls.Validation.Text = $_.Exception.Message
        $Ui.Controls.StartBuild.IsEnabled = $false
    }
}

function Update-GuiVirtioRequirement {
    param($Ui)
    $needed = $Ui.ProfileInfo.IncludeVirtioDrivers -or [bool]$Ui.Controls.IncludeQemu.IsChecked
    $Ui.Controls.VirtioIso.IsEnabled = $needed
    $Ui.Controls.BrowseVirtio.IsEnabled = $needed
    $Ui.Controls.VirtioHint.Text = if ($needed) { 'Benötigt für VirtIO-Treiber oder QEMU Guest Agent.' } else { 'Für diese Auswahl nicht benötigt.' }
}

function Update-BuilderWindow {
    param($Ui)
    if (-not $Ui.Active) { return }
    $run = $Ui.Run
    $state = $null
    $stateError = $null
    try { $state = Get-GuiBuildState -Run $run }
    catch { $stateError = $_.Exception.Message }
    $elapsed = [DateTime]::UtcNow - $run.StartedAt
    $Ui.Controls.Duration.Text = Convert-GuiText -Text ("Laufzeit: {0:00}:{1:00}:{2:00}" -f [int][Math]::Floor($elapsed.TotalHours), $elapsed.Minutes, $elapsed.Seconds) -Language $Ui.Language
    if ($state -and $state.Status -eq "Running") {
        $Ui.Controls.Status.Text = Convert-GuiText -Text ("Schritt $($state.Step)/$($state.TotalSteps): $($state.StepName)") -Language $Ui.Language
        $Ui.Controls.Progress.IsIndeterminate = $false
        if ($state.TotalSteps -gt 0) {
            $Ui.Controls.Progress.Value = [Math]::Max(0, [Math]::Min(99, (($state.Step - 1) * 100 / $state.TotalSteps)))
        }
    }
    try {
        $log = Read-SharedText -Path $run.LogPath
        if ($log) {
            if ($log.Length -gt 14000) { $log = $log.Substring($log.Length - 14000) }
            if ($Ui.Controls.LogPreview.Text -cne $log) {
                $Ui.Controls.LogPreview.Text = $log
                $Ui.Controls.LogPreview.ScrollToEnd()
            }
            $Ui.Controls.OpenLog.IsEnabled = $true
        }
    }
    catch { } # Ein kurz nicht lesbares Log unterbricht den Build nicht.
    if (-not $run.Process.HasExited) { return }
    # Keine synchronen ReadToEnd-Aufrufe auf dem UI-Thread.
    if (-not $run.Stdout.IsCompleted -or -not $run.Stderr.IsCompleted) { return }
    $Ui.Timer.Stop()
    $Ui.Active = $false
    $Ui.Controls.InputPanel.IsEnabled = $true
    $Ui.Controls.StartBuild.Content = Convert-GuiText -Text ("Weitere ISO erstellen") -Language $Ui.Language
    $Ui.Controls.StartBuild.IsEnabled = $true
    $Ui.Controls.Progress.IsIndeterminate = $false
    $Ui.LastResult = $state
    if (Test-GuiBuildSuccess -Run $run -State $state) {
        $Ui.Controls.Status.Text = Convert-GuiText -Text ("Build erfolgreich") -Language $Ui.Language
        $Ui.Controls.Status.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString("#126C60")
        $Ui.Controls.Progress.Value = 100
        $Ui.Controls.Result.Text = Convert-GuiText -Text ("{0}`n{1:N2} GB · Fertige ISO" -f $state.IsoPath, ($state.IsoSizeBytes / 1GB)) -Language $Ui.Language
        $Ui.Controls.Hash.Text = $state.Sha256
        $Ui.Controls.Hash.Visibility = "Visible"
        $Ui.Controls.CopyHash.IsEnabled = -not [string]::IsNullOrWhiteSpace($state.Sha256)
        $Ui.Controls.OpenOutput.IsEnabled = $true
    }
    else {
        $Ui.Controls.Status.Text = Convert-GuiText -Text ("Build fehlgeschlagen") -Language $Ui.Language
        $Ui.Controls.Status.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString("#AC3030")
        $message = if ($state -and $state.Error) { $state.Error }
            elseif ($stateError) { $stateError }
            elseif ($run.Stderr.Status -eq "RanToCompletion" -and $run.Stderr.Result) { $run.Stderr.Result.Trim() }
            else { "Der Prozess wurde ohne bestätigtes Ergebnis beendet (Exitcode $($run.Process.ExitCode))." }
        $message = [string]$message
        if ($message.Length -gt 1800) { $message = $message.Substring(0, 1800) }
        $Ui.Controls.Result.Text = Convert-GuiText -Text ($message) -Language $Ui.Language
        if (-not $Ui.Controls.OpenLog.IsEnabled -and $run.Stdout.Status -eq "RanToCompletion") {
            $Ui.Controls.LogPreview.Text = $run.Stdout.Result
        }
    }
    $run.Process.Dispose()
}

function Start-BuilderWindowRun {
    param($Ui)
    if ($Ui.Active -or $Ui.EditionRun) { return }
    $Ui.Controls.Validation.Text = ""
    try {
        Assert-GuiMediaSelection -Ui $Ui
        $run = Start-GuiBuild -Root $Ui.Root -WindowsIso $Ui.Controls.WindowsIso.Text.Trim() `
            -VirtioIso $Ui.Controls.VirtioIso.Text.Trim() -Profile $Ui.EffectiveProfile `
            -Edition $Ui.Controls.Edition.Text.Trim() -Version $Ui.Controls.Version.Text.Trim() `
            -LocalUserName $Ui.Controls.LocalUserName.Text -Password $Ui.Controls.Password.Password -ProductKey $Ui.Controls.ProductKey.Password -Options @{
                Tools=[bool]$Ui.Controls.IncludeTools.IsChecked
                WebSearch=[bool]$Ui.Controls.DisableWebSearch.IsChecked
                UBlockLite=[bool]$Ui.Controls.IncludeUBlockLite.IsChecked
                QemuGuestAgent=[bool]$Ui.Controls.IncludeQemu.IsChecked
            }
        $Ui.Run = $run
        $Ui.Active = $true
        $Ui.LastResult = $null
        $Ui.Controls.Password.Clear()
        $Ui.Controls.ProductKey.Clear()
        $Ui.Controls.InputPanel.IsEnabled = $false
        $Ui.Controls.StartBuild.IsEnabled = $false
        $Ui.Controls.StartBuild.Content = Convert-GuiText -Text ("Build läuft …") -Language $Ui.Language
        $Ui.Controls.OpenOutput.IsEnabled = $false
        $Ui.Controls.CopyHash.IsEnabled = $false
        $Ui.Controls.OpenLog.IsEnabled = $false
        $Ui.Controls.Hash.Text = ""
        $Ui.Controls.Hash.Visibility = "Collapsed"
        $Ui.Controls.Status.Text = Convert-GuiText -Text ("Builder wird gestartet …") -Language $Ui.Language
        $Ui.Controls.Status.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString("#126C60")
        $Ui.Controls.Result.Text = Convert-GuiText -Text ("Die einzelnen Schritte können unterschiedlich lange dauern.") -Language $Ui.Language
        $Ui.Controls.Progress.IsIndeterminate = $true
        $Ui.Controls.LogPreview.Text = "Warte auf das Build-Protokoll …"
        $Ui.Timer.Start()
    }
    catch { $Ui.Controls.Validation.Text = $_.Exception.Message }
}

function New-BuilderWindow {
    param([string]$Root, [string]$ViewPath)
    $reader = [Xml.XmlReader]::Create([IO.StringReader]::new([IO.File]::ReadAllText($ViewPath)))
    try { $window = [Windows.Markup.XamlReader]::Load($reader) } finally { $reader.Dispose() }
    $ui = @{
        MediaEditions=@(); EffectiveProfile=$null; Language='de'; LocalizationTimer=[Windows.Threading.DispatcherTimer]::new(); EditionRun=$null; EditionSource=$null; Root=$Root; Window=$window; Controls=@{}; Run=$null; Active=$false; LastResult=$null
        Timer=[Windows.Threading.DispatcherTimer]::new()
    }
    foreach ($name in @("BuildOptions", "CoreInstall", "LanguageDE", "LanguageEN", "EditProfile", "InputPanel", "WindowsIso", "VirtioIso", "BrowseWindows", "BrowseVirtio", "Profile", "ProfileSummary",
        "Edition", "ReadEditions", "EditionHint", "Version", "LocalUserName", "Password", "Validation", "StartBuild", "Status", "Progress", "Duration", "Result", "Hash",
        "OpenToolsFolder", "OpenOutput", "CopyHash", "LogPreview", "OpenLog", "ProductKey", "IncludeTools", "DisableWebSearch", "IncludeUBlockLite", "IncludeQemu", "VirtioHint", "OptionsMenu")) {
        $ui.Controls[$name] = $window.FindName($name)
        if (-not $ui.Controls[$name]) { throw "UI-Element fehlt: $name" }
    }
    $tokens = $null; $parseErrors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $Root "build.ps1"), [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count) { throw "build.ps1 enthält Syntaxfehler." }
    $versionParam = $ast.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq "Version" }
    $ui.Controls.Version.Text = [string]$versionParam.DefaultValue.SafeGetValue()
    $ui.Controls.IncludeQemu.Add_Checked({ Update-GuiVirtioRequirement -Ui $ui }.GetNewClosure())
    $ui.Controls.IncludeQemu.Add_Unchecked({ Update-GuiVirtioRequirement -Ui $ui }.GetNewClosure())
    $ui.Controls.Profile.Add_SelectionChanged({ Update-GuiProfile -Ui $ui }.GetNewClosure())
    [void]$ui.Controls.Profile.Items.Add('PC-Lokal')
    [void]$ui.Controls.Profile.Items.Add('Proxmox VM')
    $ui.Controls.Profile.SelectedItem='Proxmox VM'
    $ui.Controls.CoreInstall.Add_Checked({if($ui.EditionSource){Update-GuiProfile -Ui $ui}}.GetNewClosure())
    $ui.Controls.CoreInstall.Add_Unchecked({if($ui.EditionSource){Update-GuiProfile -Ui $ui}}.GetNewClosure())
    Reset-GuiMedia -Ui $ui
    $ui.Controls.BrowseWindows.Add_Click({
        $dialog = [Microsoft.Win32.OpenFileDialog]::new()
        $dialog.Title = Convert-GuiText "Windows-ISO auswählen" $ui.Language; $dialog.Filter = Convert-GuiText "ISO-Dateien (*.iso)|*.iso" $ui.Language; $dialog.CheckFileExists = $true
        if ($dialog.ShowDialog($ui.Window)) { $ui.Controls.WindowsIso.Text = $dialog.FileName; Start-BuilderEditionQuery -Ui $ui }
    }.GetNewClosure())
    $ui.Controls.BrowseVirtio.Add_Click({
        $dialog = [Microsoft.Win32.OpenFileDialog]::new()
        $dialog.Title = Convert-GuiText "VirtIO-ISO auswählen" $ui.Language; $dialog.Filter = Convert-GuiText "ISO-Dateien (*.iso)|*.iso" $ui.Language; $dialog.CheckFileExists = $true
        if ($dialog.ShowDialog($ui.Window)) { $ui.Controls.VirtioIso.Text = $dialog.FileName }
    }.GetNewClosure())
    $ui.Controls.WindowsIso.Add_TextChanged({
        Reset-GuiMedia -Ui $ui
        $ui.Controls.EditionHint.Text='Bitte zuerst eine Windows-ISO auswählen und erkennen lassen.'
    }.GetNewClosure())
    $ui.Controls.ReadEditions.Add_Click({ Start-BuilderEditionQuery -Ui $ui }.GetNewClosure())
    $ui.Controls.OpenToolsFolder.Add_Click({
        try { Open-GuiToolsFolder -Ui $ui }
        catch { $ui.Controls.Validation.Text=Convert-GuiText -Text $_.Exception.Message -Language $ui.Language }
    }.GetNewClosure())
    $ui.Controls.StartBuild.Add_Click({ Start-BuilderWindowRun -Ui $ui }.GetNewClosure())
    $ui.Controls.OpenLog.Add_Click({
        try {
            if ($ui.Run -and [IO.File]::Exists($ui.Run.LogPath)) {
                Start-Process -FilePath "notepad.exe" -ArgumentList (ConvertTo-ProcessArgument $ui.Run.LogPath) -ErrorAction Stop
            }
        } catch { $ui.Controls.Validation.Text = $_.Exception.Message }
    }.GetNewClosure())
    $ui.Controls.OpenOutput.Add_Click({
        try {
            if ($ui.LastResult -and [IO.File]::Exists($ui.LastResult.IsoPath)) {
                Start-Process -FilePath "explorer.exe" -ArgumentList ('/select,' + (ConvertTo-ProcessArgument $ui.LastResult.IsoPath)) -ErrorAction Stop
            }
        } catch { $ui.Controls.Validation.Text = $_.Exception.Message }
    }.GetNewClosure())
    $ui.Controls.CopyHash.Add_Click({
        try { [Windows.Clipboard]::SetText($ui.Controls.Hash.Text) }
        catch { $ui.Controls.Validation.Text = "Die Zwischenablage ist gerade nicht verfügbar." }
    }.GetNewClosure())
    $ui.Timer.Interval = [TimeSpan]::FromSeconds(1)
    $ui.Timer.Add_Tick({
        try { Update-BuilderEditionQuery -Ui $ui; Update-BuilderWindow -Ui $ui }
        catch { $ui.Controls.Validation.Text = "Statusanzeige: $($_.Exception.Message)" }
    }.GetNewClosure())
    $window.Add_Closing({
        param($sender, $eventArgs)
        if ($ui.Active -or $ui.EditionRun) {
            $eventArgs.Cancel = $true
            $ui.Controls.Validation.Text = "Build oder Editionsabfrage läuft noch. Bitte das Fenster bis zum Abschluss geöffnet lassen; Minimieren ist möglich."
        }
    }.GetNewClosure())
    $window.Add_Closed({ $ui.LocalizationTimer.Stop(); $ui.Timer.Stop(); $ui.Controls.Password.Clear(); $ui.Controls.ProductKey.Clear() }.GetNewClosure())
    $ui.TextTargets=@(Get-GuiTextTargets -Node $window)
    $ui.Controls.LanguageDE.Add_Click({Set-GuiLanguage -Ui $ui -Language de}.GetNewClosure())
    $ui.Controls.LanguageEN.Add_Click({Set-GuiLanguage -Ui $ui -Language en}.GetNewClosure())
    $ui.Controls.EditProfile.Add_Click({Show-BuilderProfileEditor -Ui $ui}.GetNewClosure())
    $ui.LocalizationTimer.Interval=[TimeSpan]::FromMilliseconds(250)
    $ui.LocalizationTimer.Add_Tick({Update-GuiLanguage -Ui $ui}.GetNewClosure())
    $ui.LocalizationTimer.Start()
    Set-GuiLanguage -Ui $ui -Language de
    return $ui
}
