param(
    [Parameter(Mandatory = $true)]
    [string]$WindowsIso,

    [Parameter(Mandatory = $true)]
    [string]$VirtioIso,

    [string]$Edition = "Windows 11 Pro",

    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9_-]*$')]
    [string]$Profile = "lab-config",

    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*$')]
    [string]$Version = "0.7.0",

    [guid]$RunId = [guid]::NewGuid()
)

# ------------------------------------------------------------
# Build-Protokoll (ein eigenes Log pro Lauf)
# ------------------------------------------------------------

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "BuildSupport.ps1")
$LogDirectory = Join-Path $PSScriptRoot "build\logs"
New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
$BuildLog = Join-Path $LogDirectory "build-$RunId.log"
$StatePath = Join-Path $LogDirectory "build-$RunId.json"
$StartedAt = [DateTimeOffset]::UtcNow
$BuildTimer = [Diagnostics.Stopwatch]::StartNew()
$BuildLock = $null
$TranscriptStarted = $false
$StateReserved = $false
$BuildState = [ordered]@{
    SchemaVersion = 1
    RunId = $RunId.ToString()
    Status = "Running"
    Step = 0
    TotalSteps = 10
    StepName = "Start"
    Profile = $Profile
    Version = $Version
    TargetOS = $null
    VirtioTarget = $null
    Edition = $null
    StartedAt = $StartedAt.ToString("o")
    UpdatedAt = $StartedAt.ToString("o")
    CompletedAt = $null
    DurationSeconds = $null
    LogPath = $BuildLog
    IsoPath = $null
    IsoSizeBytes = $null
    Sha256 = $null
    HashFile = $null
    Error = $null
}

try {
    # Eine RunId darf niemals einen früheren oder laufenden Status überschreiben.
    $Reservation = [IO.File]::Open($StatePath, [IO.FileMode]::CreateNew,
        [IO.FileAccess]::Write, [IO.FileShare]::Read)
    $Reservation.Dispose()
    $StateReserved = $true
    Write-BuildState -State $BuildState -Path $StatePath
    Start-Transcript -LiteralPath $BuildLog -NoClobber -ErrorAction Stop | Out-Null
    $TranscriptStarted = $true
    Write-Host "Build-Log: $BuildLog"
    Write-Host "Build-Status: $StatePath"
    $BuildLock = Enter-BuildLock -Path (Join-Path $PSScriptRoot "build\build.lock")
    Set-BuildStep -State $BuildState -Path $StatePath -Number 1 -Name "Profil und Voraussetzungen prüfen"
# Profil vor den Build-Arbeiten laden und prüfen.
$ProfilePath = Join-Path $PSScriptRoot "config\$Profile.psd1"
if (-not (Test-Path -LiteralPath $ProfilePath -PathType Leaf)) {
    throw "Build-Profil fehlt: $ProfilePath"
}
$BuildProfile = Import-PowerShellDataFile -LiteralPath $ProfilePath -ErrorAction Stop
$ProfileKeys = @("Edition", "AnswerTemplate", "ToolsDirectory")
foreach ($Key in $ProfileKeys) {
    if ($BuildProfile[$Key] -isnot [string] -or [string]::IsNullOrWhiteSpace($BuildProfile[$Key])) {
        throw "Build-Profil '$Profile': '$Key' muss eine nicht leere Zeichenfolge sein."
    }
}
foreach ($Key in $BuildProfile.Keys) {
    if ($Key -notin ($ProfileKeys + @("Adjustments", "TargetOS"))) {
        throw "Build-Profil '$Profile': unbekannte Einstellung '$Key'."
    }
}
# Ohne Zielangabe bleiben bestehende Profile Windows-11-Profile.
$TargetOS = "Windows11"
if ($BuildProfile.ContainsKey("TargetOS")) {
    if ($BuildProfile.TargetOS -isnot [string] -or [string]::IsNullOrWhiteSpace($BuildProfile.TargetOS)) {
        throw "Build-Profil '$Profile': 'TargetOS' muss eine nicht leere Zeichenfolge sein."
    }
    $TargetOS = $BuildProfile.TargetOS
}
$TargetConfig = Get-BuildTarget -TargetOS $TargetOS
$VirtioTarget = $TargetConfig.VirtioTarget
$BuildState.TargetOS = $TargetOS
$BuildState.VirtioTarget = $VirtioTarget
if (-not $TargetConfig.Supported) {
    throw "Zielsystem '$TargetOS' ist vorbereitet, aber noch nicht für Builds freigegeben. Antwortdatei und Installationstest stehen aus."
}
# Fehlende Schalter behalten das bisherige Verhalten (alle aktiv).
$AdjustmentNames = @("Search", "Explorer", "WindowsDefaults", "Edge")
$Adjustments = [ordered]@{}
foreach ($Name in $AdjustmentNames) {
    $Adjustments[$Name] = $true
}
if ($BuildProfile.ContainsKey("Adjustments")) {
    if ($BuildProfile.Adjustments -isnot [System.Collections.IDictionary]) {
        throw "Build-Profil '$Profile': 'Adjustments' muss eine Hashtable sein."
    }
    foreach ($Name in $BuildProfile.Adjustments.Keys) {
        if ($Name -notin $AdjustmentNames) {
            throw "Build-Profil '$Profile': unbekannte Anpassung '$Name'."
        }
        if ($BuildProfile.Adjustments[$Name] -isnot [bool]) {
            throw "Build-Profil '$Profile': '$Name' muss ein Boolean sein."
        }
        $Adjustments[$Name] = $BuildProfile.Adjustments[$Name]
    }
}
foreach ($Name in $AdjustmentNames) {
    Write-Host ("Anpassung {0}: {1}" -f $Name, $Adjustments[$Name])
}
if (-not $PSBoundParameters.ContainsKey("Edition")) {
    $Edition = $BuildProfile.Edition
}
$BuildState.Edition = $Edition
Write-Host "Zielsystem: $TargetOS (VirtIO: $VirtioTarget)"
Write-Host "Profil    : $Profile"
Write-Host "WindowsIso: $WindowsIso"
Write-Host "VirtioIso : $VirtioIso"
Write-Host "Edition   : $Edition"
Write-Host "Version   : $Version"
Write-Host ""

$ErrorActionPreference = "Stop"

if (-not (Test-Path $WindowsIso)) {
    throw "Windows-ISO nicht gefunden: $WindowsIso"
}

if (-not (Test-Path $VirtioIso)) {
    throw "VirtIO-ISO nicht gefunden: $VirtioIso"
}

# ------------------------------------------------------------
# ISO-Werkstatt Build Configuration
# ------------------------------------------------------------

$Root = $PSScriptRoot

$AnswerTemplate = Join-Path $Root $BuildProfile.AnswerTemplate
$ScriptsSource  = Join-Path $Root "scripts"

$RuntimeScripts = @(
    "Search.ps1",
    "Explorer.ps1",
    "WindowsDefaults.ps1",
    "Edge.ps1",
    "FirstLogon.ps1"
)

$ToolsSource    = Join-Path $Root $BuildProfile.ToolsDirectory
$VirtioStage = Join-Path $Root "build\virtio"
$MountRoot    = Join-Path $Root "build\mount"
$BootMount    = Join-Path $MountRoot "boot"
$InstallMount = Join-Path $MountRoot "install"
$IsoRoot = Join-Path $Root "build\iso-root"

$OemRoot = Join-Path $IsoRoot 'sources\$OEM$'
$OemScripts = Join-Path $OemRoot '$1\ISO-Werkstatt\scripts'
$OemTools   = Join-Path $OemRoot '$1\ISO-Werkstatt\Tools'
$SetupScripts = Join-Path $OemRoot '$$\Setup\Scripts'
$OemPackages = Join-Path $OemRoot '$1\ISO-Werkstatt\packages'
$FinalAnswer = Join-Path $IsoRoot "Autounattend.xml"

$Oscdimg = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"

$OutputIso = Join-Path $Root "build\ISO-Werkstatt-$Profile-v$Version.iso"



# ------------------------------------------------------------
# Header
# ------------------------------------------------------------

Write-Host ""
Write-Host "========================================"
Write-Host " ISO-Werkstatt Build v$Version"
Write-Host "========================================"
Write-Host ""


# ------------------------------------------------------------
# Voraussetzungen prüfen
# ------------------------------------------------------------
$CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()

$Principal = New-Object Security.Principal.WindowsPrincipal($CurrentUser)

$IsAdmin = $Principal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if (-not $IsAdmin) {
    throw "ISO-Werkstatt muss für WIM-Anpassungen als Administrator ausgeführt werden."
}


if (-not (Test-Path $AnswerTemplate)) {
    throw "Autounattend-Template fehlt: $AnswerTemplate"
}

if (-not (Test-Path $Oscdimg)) {
    throw "oscdimg wurde nicht gefunden: $Oscdimg"
}

if (-not $env:ISO_LAB_PASSWORD) {
    throw "Umgebungsvariable ISO_LAB_PASSWORD ist nicht gesetzt."
}

$WindowsIsoPath = (Resolve-Path $WindowsIso).Path
$VirtioIsoPath  = (Resolve-Path $VirtioIso).Path

# ------------------------------------------------------------
# PowerShell-Skripte validieren
# ------------------------------------------------------------

Write-Host "[PRECHECK] Prüfe PowerShell-Skripte..."

foreach ($Script in $RuntimeScripts) {

    $ScriptPath = Join-Path $ScriptsSource $Script

    if (-not (Test-Path $ScriptPath)) {
        throw "Benötigtes Skript fehlt: $ScriptPath"
    }

    $Tokens = $null
    $ParseErrors = $null

    [System.Management.Automation.Language.Parser]::ParseFile(
        $ScriptPath,
        [ref]$Tokens,
        [ref]$ParseErrors
    ) | Out-Null

    if ($ParseErrors.Count -gt 0) {

        Write-Host ""
        Write-Host "[FEHLER] Syntaxfehler in $Script" -ForegroundColor Red

        foreach ($ParseError in $ParseErrors) {
            Write-Host (
                "  Zeile {0}, Spalte {1}: {2}" -f `
                $ParseError.Extent.StartLineNumber,
                $ParseError.Extent.StartColumnNumber,
                $ParseError.Message
            ) -ForegroundColor Red
        }

        throw "PowerShell-Syntaxprüfung fehlgeschlagen."
    }

    Write-Host "      [OK] $Script"
}

Write-Host "      Alle PowerShell-Skripte sind syntaktisch gültig."
Write-Host ""

# ------------------------------------------------------------
# Windows-ISO vorbereiten
# ------------------------------------------------------------

Set-BuildStep -State $BuildState -Path $StatePath -Number 2 -Name "Windows-ISO vorbereiten"

# Altes Build-Verzeichnis entfernen
if (Test-Path $IsoRoot) {
    Write-Host "      Entferne altes ISO-Root..."
    Remove-Item `
        $IsoRoot `
        -Recurse `
        -Force
}

New-Item `
    -ItemType Directory `
    -Force `
    $IsoRoot | Out-Null


# Windows-ISO mounten
$WinDisk = $null

try {

    Write-Host "      Mounte Windows-ISO..."

    $WinDisk = Mount-DiskImage `
        -ImagePath $WindowsIsoPath `
        -PassThru

    $WinVolume = $WinDisk | Get-Volume

    if (-not $WinVolume.DriveLetter) {
        throw "Windows-ISO wurde gemountet, besitzt aber keinen Laufwerksbuchstaben."
    }

    $WinDrive = "$($WinVolume.DriveLetter):"

    Write-Host "      Windows-ISO: $WinDrive"


    # ISO-Inhalt kopieren
    Write-Host "      Kopiere Windows-Installationsdateien..."

    Copy-Item `
        "$WinDrive\*" `
        $IsoRoot `
        -Recurse `
        -Force


    # Schreibschutz der von ISO kopierten Dateien entfernen
    Write-Host "      Entferne ReadOnly-Attribute..."

    Get-ChildItem `
        $IsoRoot `
        -Recurse `
        -Force `
        -File |
        ForEach-Object {
            $_.IsReadOnly = $false
        }

}
finally {

    if ($WinDisk) {
        Write-Host "      Hänge Windows-ISO aus..."

        Dismount-DiskImage `
            -ImagePath $WindowsIsoPath | Out-Null
    }
}


# Kontrolle
$InstallWim = Join-Path $IsoRoot "sources\install.wim"
$BootWim    = Join-Path $IsoRoot "sources\boot.wim"

if (-not (Test-Path $InstallWim)) {
    throw "install.wim wurde im Windows-ISO nicht gefunden."
}

if (-not (Test-Path $BootWim)) {
    throw "boot.wim wurde im Windows-ISO nicht gefunden."
}

Write-Host "      Windows-ISO erfolgreich vorbereitet."
Write-Host ""

# ------------------------------------------------------------
# VirtIO-ISO vorbereiten
# ------------------------------------------------------------

Set-BuildStep -State $BuildState -Path $StatePath -Number 3 -Name "VirtIO-Komponenten extrahieren"

# Alten VirtIO-Staging-Bereich entfernen
if (Test-Path $VirtioStage) {
    Write-Host "      Entferne alten VirtIO-Staging-Bereich..."

    Remove-Item `
        $VirtioStage `
        -Recurse `
        -Force
}

New-Item `
    -ItemType Directory `
    -Force `
    $VirtioStage | Out-Null


$VirtDisk = $null

try {

    Write-Host "      Mounte VirtIO-ISO..."

    $VirtDisk = Mount-DiskImage `
        -ImagePath $VirtioIsoPath `
        -PassThru

    $VirtVolume = $VirtDisk |
        Get-Volume |
        Where-Object DriveLetter |
        Select-Object -First 1

    if (-not $VirtVolume) {
        throw "VirtIO-ISO wurde gemountet, besitzt aber keinen Laufwerksbuchstaben."
    }

    $VirtDrive = "$($VirtVolume.DriveLetter):"

    Write-Host "      VirtIO-ISO: $VirtDrive"


    # Zum Zielsystem passende x64-Treiber
    $VirtioDrivers = @{
        "vioscsi"   = "$VirtDrive\vioscsi\$VirtioTarget\amd64"
        "NetKVM"    = "$VirtDrive\NetKVM\$VirtioTarget\amd64"
        "Balloon"   = "$VirtDrive\Balloon\$VirtioTarget\amd64"
        "vioserial" = "$VirtDrive\vioserial\$VirtioTarget\amd64"
    }


    foreach ($DriverName in $VirtioDrivers.Keys) {

        $Source = $VirtioDrivers[$DriverName]
        $Target = Join-Path $VirtioStage $DriverName

        if (-not (Test-Path $Source)) {
            throw "VirtIO-Treiber fehlt: $Source"
        }

        Write-Host "      -> $DriverName"

        Copy-Item `
            $Source `
            $Target `
            -Recurse `
            -Force
    }


    # QEMU Guest Agent
    $GuestAgentSource = "$VirtDrive\guest-agent\qemu-ga-x86_64.msi"
    $GuestAgentTarget = Join-Path $VirtioStage "qemu-ga-x86_64.msi"

    if (-not (Test-Path $GuestAgentSource)) {
        throw "QEMU Guest Agent nicht gefunden: $GuestAgentSource"
    }

    Write-Host "      -> QEMU Guest Agent"

    Copy-Item `
        $GuestAgentSource `
        $GuestAgentTarget `
        -Force

}
finally {

    if ($VirtDisk) {

        Write-Host "      Hänge VirtIO-ISO aus..."

        Dismount-DiskImage `
            -ImagePath $VirtioIsoPath | Out-Null
    }
}


Write-Host "      VirtIO-Komponenten erfolgreich vorbereitet."
Write-Host ""

# ------------------------------------------------------------
# Windows-Edition ermitteln und VirtIO-Treiber integrieren
# ------------------------------------------------------------

Set-BuildStep -State $BuildState -Path $StatePath -Number 4 -Name "Edition ermitteln und Treiber integrieren"

# Gewünschte Edition im install.wim suchen
$Images = Get-WindowsImage -ImagePath $InstallWim

$EditionMatches = @(
    $Images | Where-Object {
        $_.ImageName -eq $Edition
    }
)

if ($EditionMatches.Count -eq 0) {
    throw "Edition '$Edition' wurde in install.wim nicht gefunden."
}

if ($EditionMatches.Count -gt 1) {
    throw "Edition '$Edition' wurde mehrfach in install.wim gefunden."
}

$ImageIndex = $EditionMatches[0].ImageIndex

Write-Host "      Edition : $Edition"
Write-Host "      WIM-Index: $ImageIndex"


# ------------------------------------------------------------
# Alte WIM-Mounts bereinigen und Mount-Verzeichnisse vorbereiten
# ------------------------------------------------------------

Write-Host "      Prüfe vorhandene WIM-Mounts..."

$MountedImages = @(
    Get-WindowsImage -Mounted -ErrorAction SilentlyContinue
)

foreach ($MountDir in @($BootMount, $InstallMount)) {

    $TargetPath = [System.IO.Path]::GetFullPath($MountDir).TrimEnd("\")

    $ExistingMount = $MountedImages | Where-Object {

        if (-not $_.Path) {
            return $false
        }

        $ExistingPath = [System.IO.Path]::GetFullPath($_.Path).TrimEnd("\")

        $ExistingPath -ieq $TargetPath
    }

    if ($ExistingMount) {

        Write-Host "      Alter WIM-Mount gefunden: $MountDir" `
            -ForegroundColor Yellow

        Write-Host "      Verwerfe alten Mount..."

        Dismount-WindowsImage `
            -Path $MountDir `
            -Discard `
            -ErrorAction Stop | Out-Null
    }

    if (Test-Path $MountDir) {

        Write-Host "      Bereinige Mount-Verzeichnis: $MountDir"

        Remove-Item `
            $MountDir `
            -Recurse `
            -Force
    }

    New-Item `
        -ItemType Directory `
        -Path $MountDir `
        -Force | Out-Null
}

Write-Host "      [OK] WIM-Mount-Verzeichnisse bereit"

# ------------------------------------------------------------
# boot.wim
# ------------------------------------------------------------

Write-Host "      Mounte boot.wim Index 2..."

$BootMounted = $false

try {

    Mount-WindowsImage `
        -ImagePath $BootWim `
        -Index 2 `
        -Path $BootMount | Out-Null

    $BootMounted = $true

    Write-Host "      -> boot.wim: vioscsi"

    Add-WindowsDriver `
        -Path $BootMount `
        -Driver (Join-Path $VirtioStage "vioscsi") `
        -Recurse | Out-Null

    Write-Host "      -> boot.wim: NetKVM"

    Add-WindowsDriver `
        -Path $BootMount `
        -Driver (Join-Path $VirtioStage "NetKVM") `
        -Recurse | Out-Null

    Write-Host "      Speichere boot.wim..."

    Dismount-WindowsImage `
        -Path $BootMount `
        -Save | Out-Null

    $BootMounted = $false
}
catch {

    if ($BootMounted) {
        Dismount-WindowsImage `
            -Path $BootMount `
            -Discard `
            -ErrorAction SilentlyContinue | Out-Null
    }

    throw
}


# ------------------------------------------------------------
# install.wim
# ------------------------------------------------------------

Write-Host "      Mounte install.wim Index $ImageIndex..."

$InstallMounted = $false

try {

    Mount-WindowsImage `
        -ImagePath $InstallWim `
        -Index $ImageIndex `
        -Path $InstallMount | Out-Null

    $InstallMounted = $true

    $InstallDrivers = @(
        "vioscsi",
        "NetKVM",
        "Balloon",
        "vioserial"
    )

    foreach ($DriverName in $InstallDrivers) {

        Write-Host "      -> install.wim: $DriverName"

        Add-WindowsDriver `
            -Path $InstallMount `
            -Driver (Join-Path $VirtioStage $DriverName) `
            -Recurse | Out-Null
    }

    Write-Host "      Speichere install.wim..."

    Dismount-WindowsImage `
        -Path $InstallMount `
        -Save | Out-Null

    $InstallMounted = $false
}
catch {

    if ($InstallMounted) {
        Dismount-WindowsImage `
            -Path $InstallMount `
            -Discard `
            -ErrorAction SilentlyContinue | Out-Null
    }

    throw
}

Write-Host "      VirtIO-Treiber erfolgreich integriert."
Write-Host ""

# ------------------------------------------------------------
# Autounattend.xml erzeugen
# ------------------------------------------------------------

Set-BuildStep -State $BuildState -Path $StatePath -Number 5 -Name "Autounattend.xml erzeugen"

$Xml = Get-Content $AnswerTemplate -Raw

# XML-Sonderzeichen maskieren, ohne das tatsächliche Kennwort zu verändern.
try {
    [void][System.Xml.XmlConvert]::VerifyXmlChars($env:ISO_LAB_PASSWORD)
}
catch {
    throw "ISO_LAB_PASSWORD enthält Zeichen, die in XML 1.0 nicht zulässig sind."
}
$XmlPassword = [System.Security.SecurityElement]::Escape($env:ISO_LAB_PASSWORD)
# Unterstriche schützen vor Platzhalter-Ersetzung/-Prüfung; CR vor XML-Normalisierung.
$XmlPassword = $XmlPassword.Replace("_", "&#95;").Replace("`r", "&#13;")
$Xml = $Xml.Replace(
    "__LAB_PASSWORD__",
    $XmlPassword
)

$Xml = $Xml.Replace(
    "__IMAGE_INDEX__",
    [string]$ImageIndex
)

# XML-Struktur prüfen
try {
    [void]([xml]$Xml)
}
catch {
    throw "Autounattend.xml ist kein gültiges XML: $($_.Exception.Message)"
}

# Prüfen, ob noch Platzhalter übrig sind
$RemainingPlaceholders = [regex]::Matches(
    $Xml,
    '__[A-Z0-9_]+__'
) | ForEach-Object {
    $_.Value
} | Sort-Object -Unique

if ($RemainingPlaceholders.Count -gt 0) {
    throw "Nicht ersetzte Platzhalter in Autounattend.xml: $($RemainingPlaceholders -join ', ')"
}

Write-Host "      [OK] Autounattend.xml ist gültig"

Set-Content `
    -Path $FinalAnswer `
    -Value $Xml `
    -Encoding UTF8


# ------------------------------------------------------------
# OEM-Struktur erzeugen
# ------------------------------------------------------------

Set-BuildStep -State $BuildState -Path $StatePath -Number 6 -Name "OEM-Struktur vorbereiten"

New-Item -ItemType Directory -Force $OemScripts | Out-Null
New-Item -ItemType Directory -Force $OemTools | Out-Null
New-Item -ItemType Directory -Force $SetupScripts | Out-Null
New-Item -ItemType Directory -Force $OemPackages | Out-Null

Copy-Item `
    (Join-Path $VirtioStage "qemu-ga-x86_64.msi") `
    (Join-Path $OemPackages "qemu-ga-x86_64.msi") `
    -Force


# ------------------------------------------------------------
# Skripte synchronisieren
# ------------------------------------------------------------

Set-BuildStep -State $BuildState -Path $StatePath -Number 7 -Name "Skripte synchronisieren"


foreach ($Script in $RuntimeScripts) {

    $Source = Join-Path $ScriptsSource $Script

    if (-not (Test-Path $Source)) {
        throw "Benötigtes Skript fehlt: $Source"
    }

    Copy-Item `
        $Source `
        $OemScripts `
        -Force
}

# Nur die validierten Schalter in die VM übernehmen, keine Build-Geheimnisse.
$AdjustmentLines = @("@{")
foreach ($Name in $AdjustmentNames) {
    $BooleanLiteral = if ($Adjustments[$Name]) { '$true' } else { '$false' }
    $AdjustmentLines += "    $Name = $BooleanLiteral"
}
$AdjustmentLines += "}"
$AdjustmentLines | Set-Content -LiteralPath (Join-Path $OemScripts "adjustments.psd1") -Encoding UTF8
$SetupComplete = Join-Path $ScriptsSource "SetupComplete.cmd"

if (-not (Test-Path $SetupComplete)) {
    throw "SetupComplete.cmd fehlt."
}

Copy-Item `
    $SetupComplete `
    (Join-Path $SetupScripts "SetupComplete.cmd") `
    -Force


# ------------------------------------------------------------
# Portable Tools synchronisieren
# ------------------------------------------------------------

Set-BuildStep -State $BuildState -Path $StatePath -Number 8 -Name "Portable Tools synchronisieren"

if (Test-Path $ToolsSource) {

    # Alten Inhalt entfernen, damit keine veralteten Tools
    # aus vorherigen Builds in der ISO verbleiben
    if (Test-Path $OemTools) {
        Remove-Item `
            "$OemTools\*" `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue
    }

    New-Item `
        -ItemType Directory `
        -Force `
        $OemTools | Out-Null

    $Tools = @(Get-ChildItem $ToolsSource -Force)

    if ($Tools.Count -gt 0) {

        foreach ($Tool in $Tools) {

            Write-Host "      -> $($Tool.Name)"

            if ($Tool.Extension -eq ".zip") {

                $TargetFolder = Join-Path $OemTools $Tool.BaseName

                New-Item `
                    -ItemType Directory `
                    -Force `
                    $TargetFolder | Out-Null

                Expand-Archive `
                    -Path $Tool.FullName `
                    -DestinationPath $TargetFolder `
                    -Force
            }
            else {

                Copy-Item `
                    $Tool.FullName `
                    $OemTools `
                    -Recurse `
                    -Force
            }
        }

    }
    else {
        Write-Host "      Keine Portable Tools vorhanden."
    }

}
else {
    Write-Host "      Tools-Ordner nicht vorhanden - wird übersprungen."
}


# ------------------------------------------------------------
# ISO erzeugen
# ------------------------------------------------------------

Set-BuildStep -State $BuildState -Path $StatePath -Number 9 -Name "ISO erstellen"

$BiosBoot = Join-Path $IsoRoot "boot\etfsboot.com"
$UefiBoot = Join-Path $IsoRoot "efi\microsoft\boot\efisys.bin"

if (-not (Test-Path $BiosBoot)) {
    throw "BIOS Boot-Datei fehlt."
}

if (-not (Test-Path $UefiBoot)) {
    throw "UEFI Boot-Datei fehlt."
}

$BootData = "-bootdata:2#p0,e,b$BiosBoot#pEF,e,b$UefiBoot"

& $Oscdimg `
    -m `
    -o `
    -u2 `
    -udfver102 `
    $BootData `
    $IsoRoot `
    $OutputIso

if ($LASTEXITCODE -ne 0) {
    throw "oscdimg ist mit ExitCode $LASTEXITCODE fehlgeschlagen."
}


# ------------------------------------------------------------
# SHA256 der erfolgreich erzeugten ISO
# ------------------------------------------------------------

Set-BuildStep -State $BuildState -Path $StatePath -Number 10 -Name "SHA256 und Ergebnis speichern"
$IsoHash = Get-FileHash -LiteralPath $OutputIso -Algorithm SHA256
$HashFile = "$OutputIso.sha256"
"{0} *{1}" -f $IsoHash.Hash, [System.IO.Path]::GetFileName($OutputIso) |
    Set-Content -LiteralPath $HashFile -Encoding ASCII

# ------------------------------------------------------------
# Ergebnis
# ------------------------------------------------------------

$Result = Get-Item -LiteralPath $OutputIso
$BuildState.Status = "Succeeded"
$BuildState.CompletedAt = [DateTimeOffset]::UtcNow.ToString("o")
$BuildState.DurationSeconds = [Math]::Round($BuildTimer.Elapsed.TotalSeconds, 2)
$BuildState.IsoPath = $Result.FullName
$BuildState.IsoSizeBytes = $Result.Length
$BuildState.Sha256 = $IsoHash.Hash
$BuildState.HashFile = $HashFile
Write-BuildState -State $BuildState -Path $StatePath
Write-Progress -Activity "ISO-Werkstatt" -Completed
Write-Host "Ergebnisdatei: $StatePath"
Write-Host ("Dauer: {0:N1} Minuten" -f $BuildTimer.Elapsed.TotalMinutes)

Write-Host ""
Write-Host "========================================"
Write-Host " BUILD ERFOLGREICH"
Write-Host "========================================"
Write-Host ""
Write-Host "ISO:"
Write-Host $Result.FullName
Write-Host ""
Write-Host "Groesse:"
Write-Host ("{0:N2} GB" -f ($Result.Length / 1GB))
Write-Host ""
Write-Host "SHA256: $($IsoHash.Hash)"
Write-Host "Pruefsummendatei: $HashFile"
Write-Host "Build-Log: $BuildLog"
Write-Host ""
}
catch {
    $Failure = $_
    if ($StateReserved) {
        $BuildState.Status = "Failed"
        $BuildState.CompletedAt = [DateTimeOffset]::UtcNow.ToString("o")
        $BuildState.DurationSeconds = [Math]::Round($BuildTimer.Elapsed.TotalSeconds, 2)
        $Message = $Failure.Exception.Message
        if ($env:ISO_LAB_PASSWORD) {
            $Message = $Message.Replace($env:ISO_LAB_PASSWORD, "[REDACTED]")
        }
        $BuildState.Error = $Message
        # Fehlerstatus darf niemals eine möglicherweise ältere ISO als Erfolg ausgeben.
        $BuildState.IsoPath = $null
        $BuildState.IsoSizeBytes = $null
        $BuildState.Sha256 = $null
        $BuildState.HashFile = $null
        try {
            Write-BuildState -State $BuildState -Path $StatePath
        }
        catch {
            Write-Warning "Build-Fehlerstatus konnte nicht gespeichert werden." -WarningAction Continue
        }
        Write-Host ("[FEHLER] Build abgebrochen: {0}" -f $Message) -ForegroundColor Red
    }
    throw
}
finally {
    $BuildTimer.Stop()
    if ($BuildLock) {
        $BuildLock.Dispose()
    }
    Write-Progress -Activity "ISO-Werkstatt" -Completed
    if ($TranscriptStarted) {
        try {
            Stop-Transcript -ErrorAction Stop | Out-Null
        }
        catch {
            Write-Warning ("Build-Log konnte nicht abgeschlossen werden: {0}" -f $_.Exception.Message) -WarningAction Continue
        }
    }
}