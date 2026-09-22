function ConvertTo-ProcessArgument {
    param([AllowEmptyString()][string]$Value)
    # Windows CommandLineToArgvW-Regeln, keine PowerShell-Auswertung der Werte.
    $Value = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $Value = [regex]::Replace($Value, '(\\+)$', '$1$1')
    return '"' + $Value + '"'
}

function Read-SharedText {
    param([string]$Path)
    if (-not [IO.File]::Exists($Path)) { return $null }
    $stream = $null
    $reader = $null
    try {
        $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read,
            ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
        $reader = [IO.StreamReader]::new($stream, [Text.Encoding]::UTF8, $true)
        return $reader.ReadToEnd()
    }
    finally {
        if ($reader) { $reader.Dispose() }
        elseif ($stream) { $stream.Dispose() }
    }
}

function Get-GuiProfile {
    param([string]$Path)
    $data = Import-PowerShellDataFile -LiteralPath $Path -ErrorAction Stop
    Resolve-BuildProfile -Data $data
}

function Start-GuiBuild {
    param(
        [string]$Root, [string]$WindowsIso, [string]$VirtioIso,
        [string]$Profile, [string]$Edition, [string]$Version,
        [string]$Password, [string]$ProductKey, [string]$LocalUserName, [Collections.IDictionary]$Options = @{}
    )
    if ($Profile -notmatch '^[A-Za-z0-9][A-Za-z0-9_-]*$') { throw "Bitte ein gültiges Profil auswählen." }
    if ($Version -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') { throw "Bitte eine gültige Versionsbezeichnung eingeben." }
    if ([string]::IsNullOrEmpty($Password)) { throw "Bitte das Kennwort für das lokale Konto eingeben." }
    $profileInfo = Get-GuiProfile -Path (Join-Path $Root "config\$Profile.psd1")
    if (-not $profileInfo.Supported) { throw "Dieses Zielsystem ist noch nicht für Builds freigegeben." }
    if (-not [IO.File]::Exists((Join-Path $Root $profileInfo.AnswerTemplate))) { throw "Die Antwortdatei des Profils fehlt." }

    if (-not $PSBoundParameters.ContainsKey('LocalUserName')) { $LocalUserName = $profileInfo.LocalUserName }
    $LocalUserName = Test-BuildUserName -Value $LocalUserName
    $productKeyValue = ConvertTo-SetupProductKey -Value $ProductKey
    $flags = [ordered]@{ Tools=$profileInfo.Features.Tools; WebSearch=$profileInfo.Adjustments.Search; UBlockLite=$profileInfo.Features.UBlockLite; QemuGuestAgent=$profileInfo.Features.QemuGuestAgent }
    foreach ($key in $Options.Keys) {
        if (-not $flags.Contains($key) -or $Options[$key] -isnot [bool]) { throw "Ungültige Build-Option: $key" }
        $flags[$key] = $Options[$key]
    }
    $resolvedFlags=@{Search=$flags.WebSearch;Explorer=$profileInfo.Adjustments.Explorer;WindowsDefaults=$profileInfo.Adjustments.WindowsDefaults;Edge=$profileInfo.Adjustments.Edge;UBlockLite=$flags.UBlockLite}
    Assert-BuildTargetOptions -TargetOS $profileInfo.TargetOS -InstallationMode $profileInfo.InstallationMode -Adjustments $resolvedFlags
    $needVirtio = $profileInfo.IncludeVirtioDrivers -or $flags.QemuGuestAgent
    if ([string]::IsNullOrWhiteSpace($WindowsIso)) { throw 'Bitte eine Windows-ISO auswählen.' }
    if ($needVirtio -and [string]::IsNullOrWhiteSpace($VirtioIso)) { throw 'Für VirtIO-Treiber oder QEMU Guest Agent wird eine VirtIO-ISO benötigt.' }
    if (-not [IO.Path]::IsPathRooted($WindowsIso)) { $WindowsIso = Join-Path $Root $WindowsIso }
    $WindowsIso = [IO.Path]::GetFullPath($WindowsIso)
    $paths = @($WindowsIso)
    if ($needVirtio) {
        if (-not [IO.Path]::IsPathRooted($VirtioIso)) { $VirtioIso = Join-Path $Root $VirtioIso }
        $VirtioIso = [IO.Path]::GetFullPath($VirtioIso)
        $paths += $VirtioIso
    }
    foreach ($path in $paths) {
        if (-not [IO.File]::Exists($path) -or [IO.Path]::GetExtension($path) -ine '.iso') { throw "Bitte eine vorhandene ISO-Datei auswählen: $path" }
    }
    $runId = [guid]::NewGuid().ToString()
    $arguments = @("-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File",
        (Join-Path $Root "build.ps1"), "-WindowsIso", $WindowsIso,
        "-Profile", $Profile, "-Version", $Version, "-RunId", $runId, "-LocalUserName", $LocalUserName)
    if ($needVirtio) { $arguments += @('-VirtioIso', $VirtioIso) }
    foreach ($key in $flags.Keys) { $arguments += @("-$key", $(if ($flags[$key]) { 'On' } else { 'Off' })) }
    if (-not [string]::IsNullOrWhiteSpace($Edition)) { $arguments += @("-Edition", $Edition) }
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
    $info.Arguments = ($arguments | ForEach-Object { ConvertTo-ProcessArgument $_ }) -join " "
    $info.WorkingDirectory = $Root
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.EnvironmentVariables["ISO_LAB_PASSWORD"] = $Password
    $info.EnvironmentVariables.Remove('ISO_PRODUCT_KEY')
    if ($productKeyValue) { $info.EnvironmentVariables['ISO_PRODUCT_KEY'] = $productKeyValue }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $info
    try {
        if (-not $process.Start()) { throw "Der Build-Prozess konnte nicht gestartet werden." }
        # .NET liest beide Streams gleichzeitig: kein volles Pipe-Puffer und kein UI-Warten.
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
    }
    catch { $process.Dispose(); throw }
    finally { $info.EnvironmentVariables.Remove("ISO_LAB_PASSWORD"); $info.EnvironmentVariables.Remove("ISO_PRODUCT_KEY") }
    [pscustomobject]@{
        RunId=$runId; Process=$process; Stdout=$stdout; Stderr=$stderr
        StatePath=(Join-Path $Root "build\logs\build-$runId.json")
        LogPath=(Join-Path $Root "build\logs\build-$runId.log")
        StartedAt=[DateTime]::UtcNow
    }
}

function Get-GuiBuildState {
    param($Run)
    $text = Read-SharedText -Path $Run.StatePath
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }
    $state = $text | ConvertFrom-Json -ErrorAction Stop
    if ($state.SchemaVersion -ne 1 -or $state.RunId -ne $Run.RunId -or
        $state.Status -notin @("Running", "Succeeded", "Failed")) {
        throw "Die Statusdatei passt nicht zum aktuellen Build."
    }
    if ($state.Step -isnot [int] -or $state.TotalSteps -isnot [int] -or
        $state.TotalSteps -lt 1 -or $state.TotalSteps -gt 1000 -or
        $state.Step -lt 0 -or $state.Step -gt $state.TotalSteps) {
        throw "Die Statusdatei enthält ungültige Fortschrittsdaten."
    }
    return $state
}

function Test-GuiBuildSuccess {
    param($Run, $State)
    return ($Run.Process.HasExited -and $Run.Process.ExitCode -eq 0 -and
        $null -ne $State -and $State.RunId -eq $Run.RunId -and $State.Status -eq "Succeeded" -and
        -not [string]::IsNullOrWhiteSpace($State.IsoPath) -and [IO.File]::Exists($State.IsoPath) -and
        $State.Sha256 -match '^[A-Fa-f0-9]{64}$' -and [IO.File]::Exists($State.HashFile))
}
