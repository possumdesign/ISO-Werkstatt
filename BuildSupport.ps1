# Hilfsfunktionen des Builders; Windows PowerShell 5.1 kompatibel.
function Enter-BuildLock {
    param([Parameter(Mandatory = $true)][string]$Path)
    try {
        # Die Datei bleibt liegen; nur der offene Handle sperrt den Build.
        # Windows gibt ihn auch nach einem Prozessabbruch frei.
        return [IO.File]::Open($Path, [IO.FileMode]::OpenOrCreate,
            [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    }
    catch {
        throw "Build-Verzeichnis kann nicht gesperrt werden. Läuft bereits ein Build? Pfad: $Path"
    }
}

function Get-BuildTarget {
    param([string]$TargetOS = "Windows11")
    $Targets = @{
        Windows11  = @{ VirtioTarget = "w11"; Supported = $true; InstallationTested = $true }
        Windows10  = @{ VirtioTarget = "w10"; Supported = $true; InstallationTested = $false }
        Server2022 = @{ VirtioTarget = "2k22"; Supported = $true; InstallationTested = $false }
        Server2025 = @{ VirtioTarget = "2k25"; Supported = $true; InstallationTested = $false }
    }
    if (-not $Targets.ContainsKey($TargetOS)) {
        throw "Unbekanntes Zielsystem '$TargetOS'. Erlaubt: Windows11, Windows10, Server2022, Server2025."
    }
    return $Targets[$TargetOS]
}

function Write-BuildState {
    param(
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$State,
        [Parameter(Mandatory = $true)][string]$Path
    )
    $State.UpdatedAt = [DateTimeOffset]::UtcNow.ToString("o")
    $TemporaryPath = "$Path.tmp"
    try {
        [IO.File]::WriteAllText($TemporaryPath, ($State | ConvertTo-Json -Depth 6),
            [Text.UTF8Encoding]::new($false))
        # Leser sehen entweder die alte oder die vollständige neue JSON-Datei.
        [IO.File]::Replace($TemporaryPath, $Path, [NullString]::Value)
    }
    finally {
        if ([IO.File]::Exists($TemporaryPath)) {
            [IO.File]::Delete($TemporaryPath)
        }
    }
}

function Set-BuildStep {
    param(
        [System.Collections.IDictionary]$State,
        [string]$Path,
        [int]$Number,
        [string]$Name
    )
    $State.Step = $Number
    $State.StepName = $Name
    Write-BuildState -State $State -Path $Path
    Write-Host ("[{0}/{1}] {2}" -f $Number, $State.TotalSteps, $Name)
    Write-Progress -Activity "ISO-Werkstatt" -Status $Name -PercentComplete (($Number - 1) * 100 / $State.TotalSteps)
}


function Invoke-IsoStorageJob {
    param([scriptblock]$StartJob, [string]$Operation, [int]$TimeoutSeconds = 30)
    Write-Host ("      [{0:HH:mm:ss}] {1} (max. {2} s)" -f (Get-Date), $Operation, $TimeoutSeconds)
    $job = $null
    try {
        $job = & $StartJob
        if ($job -isnot [Management.Automation.Job]) { throw "Storage-Auftrag wurde nicht gestartet: $Operation" }
        if (-not (Wait-Job -Job $job -Timeout $TimeoutSeconds)) {
            throw "Zeitlimit bei '$Operation' nach $TimeoutSeconds Sekunden. Windows antwortet nicht rechtzeitig; ISO-Status vor einem erneuten Versuch prüfen."
        }
        $output = @(Receive-Job -Job $job -ErrorAction Stop)
        if ($job.State -ne "Completed") { throw "Storage-Auftrag fehlgeschlagen: $Operation ($($job.State))" }
        Write-Host ("      [{0:HH:mm:ss}] {1}: abgeschlossen" -f (Get-Date), $Operation)
        return $output
    }
    finally {
        if ($job) {
            if ($job.State -notin @("Completed", "Failed", "Stopped")) {
                # CIM-Jobs asynchron stoppen, damit das Zeitlimit nicht beim Stoppen hängt.
                if ($job -is [Management.Automation.Job2]) { $job.StopJobAsync() }
                else { Stop-Job -Job $job -ErrorAction SilentlyContinue }
            }
            if ($job.State -in @("Completed", "Failed", "Stopped")) {
                Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

function Open-BuildIso {
    param(
        [string]$ImagePath, [string]$Label,
        [System.Collections.IDictionary]$Context,
        [int]$MountTimeoutSeconds = 60, [int]$VolumeTimeoutSeconds = 30
    )
    $Context.ImagePath = $ImagePath
    $Context.Label = $Label
    $Context.Owned = $false
    $disk = Invoke-IsoStorageJob -Operation "$Label Status prüfen" -StartJob {
        Get-DiskImage -ImagePath $ImagePath -AsJob -ErrorAction Stop
    }
    if ($disk.Attached) {
        Write-Host "      $Label ist bereits eingehängt; verwende vorhandene Einhängung."
    }
    else {
        # Auch bei einem Zeitlimit kann Windows den Mount noch abschließen.
        # Der finally-Block versucht deshalb gezielt, diesen eigenen Auftrag aufzuräumen.
        $Context.Owned = $true
        $disk = Invoke-IsoStorageJob -Operation "$Label einhängen" -TimeoutSeconds $MountTimeoutSeconds -StartJob {
            Mount-DiskImage -ImagePath $ImagePath -StorageType ISO -PassThru -AsJob -ErrorAction Stop
        }
    }
    $timer = [Diagnostics.Stopwatch]::StartNew()
    do {
        $remaining = [Math]::Max(1, [int][Math]::Ceiling($VolumeTimeoutSeconds - $timer.Elapsed.TotalSeconds))
        $volumes = @(Invoke-IsoStorageJob -Operation "$Label Laufwerksbuchstaben ermitteln" -TimeoutSeconds $remaining -StartJob {
            Get-Volume -DiskImage $disk -AsJob -ErrorAction Stop
        })
        $volume = $volumes | Where-Object DriveLetter | Select-Object -First 1
        if ($volume) { return "$($volume.DriveLetter):" }
        if ($timer.Elapsed.TotalSeconds -ge $VolumeTimeoutSeconds) { break }
        Write-Host "      $Label hat noch keinen Laufwerksbuchstaben; warte auf Windows."
        Start-Sleep -Milliseconds 500
        $remaining = [Math]::Max(1, [int][Math]::Ceiling($VolumeTimeoutSeconds - $timer.Elapsed.TotalSeconds))
        $disk = Invoke-IsoStorageJob -Operation "$Label Status aktualisieren" -TimeoutSeconds $remaining -StartJob {
            Get-DiskImage -ImagePath $ImagePath -AsJob -ErrorAction Stop
        }
        if (-not $disk.Attached) { throw "$Label wurde während der Laufwerksabfrage ausgehängt." }
    } while ($timer.Elapsed.TotalSeconds -lt $VolumeTimeoutSeconds)
    throw "$Label besitzt nach $VolumeTimeoutSeconds Sekunden keinen Laufwerksbuchstaben. Bitte die Windows-Laufwerkszuordnung prüfen."
}

function Close-BuildIso {
    param([System.Collections.IDictionary]$Context, [bool]$PreserveError = $false)
    if (-not $Context.Owned) { return }
    try {
        Invoke-IsoStorageJob -Operation "$($Context.Label) aushängen" -StartJob {
            Dismount-DiskImage -ImagePath $Context.ImagePath -AsJob -ErrorAction Stop
        } | Out-Null
        $Context.Owned = $false
    }
    catch {
        if (-not $PreserveError) { throw }
        Write-Warning ("Zusätzlich konnte die eigene ISO-Einhängung nicht aufgeräumt werden: {0}" -f $_.Exception.Message) -WarningAction Continue
    }
}


function Resolve-BuildProfile {
    param([Collections.IDictionary]$Data)
    $required = @('Edition', 'AnswerTemplate', 'ToolsDirectory')
    foreach ($key in $required) {
        if ($Data[$key] -isnot [string] -or [string]::IsNullOrWhiteSpace($Data[$key])) { throw "Profil: '$key' muss eine nicht leere Zeichenfolge sein." }
    }
    foreach ($key in $Data.Keys) {
        if ($key -notin ($required + @('TargetOS','Adjustments','Features','IncludeVirtioDrivers','LocalUserName','InstallationMode'))) { throw "Unbekannte Profileinstellung: $key" }
    }
    $target = 'Windows11'
    if ($Data.Contains('TargetOS')) {
        if ($Data.TargetOS -isnot [string] -or [string]::IsNullOrWhiteSpace($Data.TargetOS)) { throw 'Ungültiges Zielsystem.' }
        $target = $Data.TargetOS
    }
    $mode='Desktop'
    if($Data.Contains('InstallationMode')){
        if($Data.InstallationMode -isnot [string] -or $Data.InstallationMode -notin @('Desktop','Core')){throw 'InstallationMode muss Desktop oder Core sein.'}
        $mode=$Data.InstallationMode
    }
    if($mode -eq 'Core' -and $target -notlike 'Server*'){throw 'Server Core ist nur für Server-Zielsysteme verfügbar.'}
    $targetInfo = Get-BuildTarget $target
    $drivers = $true
    if ($Data.Contains('IncludeVirtioDrivers')) {
        if ($Data.IncludeVirtioDrivers -isnot [bool]) { throw 'IncludeVirtioDrivers muss ein Boolean sein.' }
        $drivers = $Data.IncludeVirtioDrivers
    }
    $adjustments = [ordered]@{ Search=$true; Explorer=$true; WindowsDefaults=$true; Edge=$true }
    if ($Data.Contains('Adjustments')) {
        if ($Data.Adjustments -isnot [Collections.IDictionary]) { throw 'Adjustments muss eine Hashtable sein.' }
        foreach ($key in $Data.Adjustments.Keys) {
            if (-not $adjustments.Contains($key) -or $Data.Adjustments[$key] -isnot [bool]) { throw "Ungültiger Anpassungsschalter: $key" }
            $adjustments[$key] = $Data.Adjustments[$key]
        }
    }
    $userName = if ($drivers) { 'LabAdmin' } else { 'Winuser' }
    if ($Data.Contains('LocalUserName')) {
        if ($Data.LocalUserName -isnot [string]) { throw 'LocalUserName muss eine Zeichenfolge sein.' }
        $userName = $Data.LocalUserName
    }
    $userName = Test-BuildUserName -Value $userName
    # Alte Profile: uBlock folgt zunächst dem bisherigen Edge-Schalter.
    $features = [ordered]@{ Tools=$true; UBlockLite=$adjustments.Edge; QemuGuestAgent=$true }
    if ($Data.Contains('Features')) {
        if ($Data.Features -isnot [Collections.IDictionary]) { throw 'Features muss eine Hashtable sein.' }
        foreach ($key in $Data.Features.Keys) {
            if (-not $features.Contains($key) -or $Data.Features[$key] -isnot [bool]) { throw "Ungültiger Zusatzschalter: $key" }
            $features[$key] = $Data.Features[$key]
        }
    }
    [pscustomobject]@{
        Edition=$Data.Edition; AnswerTemplate=$Data.AnswerTemplate; ToolsDirectory=$Data.ToolsDirectory
        TargetOS=$target; VirtioTarget=$targetInfo.VirtioTarget; Supported=$targetInfo.Supported; InstallationTested=$targetInfo.InstallationTested
        IncludeVirtioDrivers=$drivers; Adjustments=$adjustments; Features=$features; LocalUserName=$userName; InstallationMode=$mode
    }
}

function Resolve-BuildChoice {
    param([ValidateSet('Profile','On','Off')][string]$Choice='Profile', [bool]$Default)
    if ($Choice -eq 'Profile') { return $Default }
    return $Choice -eq 'On'
}

function ConvertTo-SetupProductKey {
    param([AllowEmptyString()][string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return '' }
    $normalized = $Value.Trim().ToUpperInvariant()
    if ($normalized -notmatch '^[A-Z0-9]{5}(-[A-Z0-9]{5}){4}$') { throw 'Der Produktschlüssel muss aus fünf Gruppen mit jeweils fünf Buchstaben/Ziffern bestehen.' }
    return $normalized
}

function Set-SetupProductKey {
    param([string]$Xml, [string]$ProductKey)
    if ([string]::IsNullOrEmpty($ProductKey)) { return $Xml }
    $document = [xml]$Xml
    $ns = [Xml.XmlNamespaceManager]::new($document.NameTable)
    $ns.AddNamespace('u','urn:schemas-microsoft-com:unattend')
    $userData = $document.SelectSingleNode('/u:unattend/u:settings[@pass="windowsPE"]/u:component[@name="Microsoft-Windows-Setup"]/u:UserData',$ns)
    if (-not $userData) { throw 'Die Antwortdatei enthält keinen Setup-UserData-Abschnitt für den Produktschlüssel.' }
    $keyElement = $userData.SelectSingleNode('u:ProductKey',$ns)
    if (-not $keyElement) {
        $keyElement = $document.CreateElement('ProductKey',$userData.NamespaceURI)
        [void]$userData.AppendChild($keyElement)
    }
    $key = $keyElement.SelectSingleNode('u:Key',$ns)
    if (-not $key) { $key=$document.CreateElement('Key',$userData.NamespaceURI); [void]$keyElement.PrependChild($key) }
    $key.InnerText = $ProductKey
    $show = $keyElement.SelectSingleNode('u:WillShowUI',$ns)
    if (-not $show) { $show=$document.CreateElement('WillShowUI',$userData.NamespaceURI); [void]$keyElement.AppendChild($show) }
    $show.InnerText = 'OnError'
    return $document.OuterXml
}

function Test-BuildUserName {
    param([AllowEmptyString()][string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value) -or $Value.Length -gt 20 -or
        $Value -match '["/\\\[\]:;|=,+*?<>@\p{Cc}]' -or $Value -match '^[. ]+$' -or
        $Value -ne $Value.Trim() -or $Value.EndsWith('.')) {
        throw 'Kontoname ungültig: 1–20 Zeichen, keine Windows-Sonderzeichen, keine äußeren Leerzeichen oder abschließenden Punkte.'
    }
    if ($Value -in @('Administrator','Administrators','Administratoren','Guest','Gast','Guests','Gäste','DefaultAccount','WDAGUtilityAccount','SYSTEM','Users','Benutzer')) {
        throw 'Dieser Kontoname ist für ein Windows-Konto oder eine Windows-Gruppe reserviert.'
    }
    return $Value
}

function Set-SetupLocalUser {
    param([string]$Xml, [string]$UserName)
    $UserName = Test-BuildUserName -Value $UserName
    $document = [Xml.XmlDocument]::new()
    $document.PreserveWhitespace = $true
    $document.LoadXml($Xml)
    $ns = [Xml.XmlNamespaceManager]::new($document.NameTable)
    $ns.AddNamespace('u','urn:schemas-microsoft-com:unattend')
    $shell = '/u:unattend/u:settings[@pass="oobeSystem"]/u:component[@name="Microsoft-Windows-Shell-Setup"]'
    $accounts = $document.SelectNodes("$shell/u:UserAccounts/u:LocalAccounts/u:LocalAccount",$ns)
    $logons = $document.SelectNodes("$shell/u:AutoLogon/u:Username",$ns)
    if ($accounts.Count -ne 1 -or $logons.Count -ne 1) {
        throw 'Die Antwortdatei muss genau ein lokales Konto und eine automatische Anmeldung enthalten.'
    }
    $name = $accounts[0].SelectSingleNode('u:Name',$ns)
    $display = $accounts[0].SelectSingleNode('u:DisplayName',$ns)
    if (-not $name -or -not $display) { throw 'Name oder DisplayName fehlt im lokalen Konto der Antwortdatei.' }
    $name.InnerText = $UserName
    $display.InnerText = $UserName
    $logons[0].InnerText = $UserName
    return $document.OuterXml
}

function Get-BuildIsoEditions {
    param([string]$WindowsIso, [string]$LockPath)
    if (-not [IO.File]::Exists($WindowsIso) -or [IO.Path]::GetExtension($WindowsIso) -ine '.iso') {
        throw 'Bitte eine vorhandene Windows-ISO auswählen.'
    }
    $WindowsIso = [IO.Path]::GetFullPath($WindowsIso)
    New-Item -ItemType Directory -Path (Split-Path $LockPath -Parent) -Force | Out-Null
    $handle = Enter-BuildLock -Path $LockPath
    $context = @{}
    $failure = $null
    try {
        $drive = Open-BuildIso -ImagePath $WindowsIso -Label 'Windows-ISO (Editionen)' -Context $context
        $wim = Get-BuildInstallImagePath -MediaRoot $drive
        $editions = @(Get-WindowsImage -ImagePath $wim -ErrorAction Stop | ForEach-Object {
            if ([string]::IsNullOrWhiteSpace($_.ImageName)) { throw 'Eine Edition besitzt keinen lesbaren Namen.' }
            $entry=$_
            $detail=Get-WindowsImage -ImagePath $wim -Index $entry.ImageIndex -ErrorAction Stop
            $target=$null
            $mode=if($detail.InstallationType -eq 'Server Core'){'Core'}else{'Desktop'}
            foreach($candidate in @('Windows11','Windows10','Server2022','Server2025')){
                try { Assert-BuildImageTarget -Image $detail -TargetOS $candidate -InstallationMode $mode; $target=$candidate; break } catch { }
            }
            if(-not $target){throw "Nicht unterstütztes Installationsabbild: $($entry.ImageName)."}
            [pscustomobject]@{ Index=[int]$entry.ImageIndex; Name=[string]$entry.ImageName; TargetOS=$target; InstallationMode=$mode }
        })
        if ($editions.Count -eq 0) { throw 'Keine Windows-Editionen in install.wim gefunden.' }
    }
    catch { $failure=$_; throw }
    finally {
        try { Close-BuildIso -Context $context -PreserveError ([bool]$failure) }
        finally { $handle.Dispose() }
    }
    return $editions
}


function Assert-BuildImageTarget {
    param($Image,[string]$TargetOS,[string]$InstallationMode='Desktop')
    if ([string]$Image.Architecture -notin @('9','amd64','x64')) { throw 'Nur x64-Installationsabbilder werden unterstützt.' }
    $version=$null
    if(-not [version]::TryParse([string]$Image.Version,[ref]$version)){throw 'Die Windows-Version des Abbilds konnte nicht geprüft werden.'}
    $kind=[string]$Image.InstallationType
    $matchesTarget=switch($TargetOS){
        'Windows11' { $version.Major -eq 10 -and $version.Build -ge 22000 -and $kind -eq 'Client' }
        'Windows10' { $version.Major -eq 10 -and $version.Build -ge 10240 -and $version.Build -lt 22000 -and $kind -eq 'Client' }
        'Server2022' { $version.Major -eq 10 -and $version.Build -eq 20348 -and $kind -in @('Server','Server Core') }
        'Server2025' { $version.Major -eq 10 -and $version.Build -eq 26100 -and $kind -in @('Server','Server Core') }
        default {$false}
    }
    if(-not $matchesTarget){throw "Das gewählte Abbild ($version, $kind) passt nicht zu TargetOS=$TargetOS."}
    $actualMode=if($kind -eq 'Server Core'){'Core'}else{'Desktop'}
    if($InstallationMode -ne $actualMode){throw "Die gewählte Edition ist $actualMode, das Profil verlangt $InstallationMode. Bitte die passende Edition oder das passende Profil auswählen."}
}

function Assert-BuildTargetOptions {
    param([string]$TargetOS,[string]$InstallationMode,$Adjustments)
    if($TargetOS -like 'Server*' -and $Adjustments.WindowsDefaults){throw 'WindowsDefaults ist nur für Windows-Clients vorgesehen. Im Serverprofil bitte deaktivieren.'}
    if($InstallationMode -eq 'Core'){
        foreach($name in @('Search','Explorer','WindowsDefaults','Edge','UBlockLite')){
            if($Adjustments[$name]){throw "Server Core unterstützt die Desktop-Anpassung '$name' nicht. Bitte deaktivieren."}
        }
    }
}

function Get-BuildInstallImagePath {
    param([string]$MediaRoot)
    foreach($name in @('install.wim','install.esd')){
        $path=Join-Path $MediaRoot "sources\$name"
        if(Test-Path -LiteralPath $path -PathType Leaf){return $path}
    }
    throw 'Weder sources\install.wim noch sources\install.esd wurde im Installationsmedium gefunden.'
}

function Get-Windows10SetupKey {
    param([string]$Xml, [string]$ProductKey, [string]$EditionId, [string]$MediaRoot)
    if (-not [string]::IsNullOrEmpty($ProductKey)) { return $ProductKey }
    $document=[xml]$Xml
    $ns=[Xml.XmlNamespaceManager]::new($document.NameTable)
    $ns.AddNamespace('u','urn:schemas-microsoft-com:unattend')
    $existing=$document.SelectSingleNode('/u:unattend/u:settings[@pass="windowsPE"]/u:component[@name="Microsoft-Windows-Setup"]/u:UserData/u:ProductKey/u:Key',$ns)
    if($existing -and -not [string]::IsNullOrWhiteSpace($existing.InnerText)){return ''}
    # Exakte DISM-EditionId verwenden, niemals einen Pro-Key für andere Editionen übernehmen.
    $path=Join-Path $MediaRoot 'sources\product.ini'
    $keys=@()
    if(-not [string]::IsNullOrWhiteSpace($EditionId) -and (Test-Path -LiteralPath $path -PathType Leaf)){
        $section=''
        foreach($line in [IO.File]::ReadAllLines($path)){
            $line=$line.Trim()
            if($line -match '^\[([^\]]+)\]$'){$section=$Matches[1];continue}
            if($section -ieq 'cmi' -and $line -match '^([^=;#]+)=(.*)$'){
                if($Matches[1].Trim() -ieq $EditionId){$keys+= $Matches[2].Trim()}
            }
        }
    }
    if($keys.Count -ne 1 -or $keys[0] -notmatch '^[A-Za-z0-9]{5}(-[A-Za-z0-9]{5}){4}$'){
        throw 'Für die gewählte Windows-10-Edition fehlt ein eindeutiger Standard-Setup-Schlüssel im Medium. Bitte einen passenden Produktschlüssel im Builder eingeben.'
    }
    return $keys[0].ToUpperInvariant()
}
