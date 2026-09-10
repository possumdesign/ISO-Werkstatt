param(
    [Parameter(Mandatory = $true)]
    [string]$WindowsIso,

    [Parameter(Mandatory = $true)]
    [string]$VirtioIso,

    [string]$Edition = "Windows 11 Pro",

    [string]$Version = "0.6.0"
)

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

$AnswerTemplate = Join-Path $Root "answer\Autounattend.xml"
$ScriptsSource  = Join-Path $Root "scripts"
$ToolsSource    = Join-Path $Root "tools"
$VirtioStage = Join-Path $Root "build\virtio"

$IsoRoot = Join-Path $Root "build\iso-root"

$OemRoot = Join-Path $IsoRoot 'sources\$OEM$'
$OemScripts = Join-Path $OemRoot '$1\ISO-Werkstatt\scripts'
$OemTools   = Join-Path $OemRoot '$1\ISO-Werkstatt\Tools'
$SetupScripts = Join-Path $OemRoot '$$\Setup\Scripts'
$OemPackages = Join-Path $OemRoot '$1\ISO-Werkstatt\packages'
$FinalAnswer = Join-Path $IsoRoot "Autounattend.xml"

$Oscdimg = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"

$OutputIso = Join-Path $Root "build\ISO-Werkstatt-W11Pro-v$Version.iso"


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
# Windows-ISO vorbereiten
# ------------------------------------------------------------

Write-Host "[1/6] Erzeuge frisches ISO-Root aus Windows-ISO..."

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
            -ImagePath $WindowsIsoPath
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

Write-Host "[2/7] Extrahiere VirtIO-Komponenten..."

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


    # Benötigte Windows-11-x64-Treiber
    $VirtioDrivers = @{
        "vioscsi"   = "$VirtDrive\vioscsi\w11\amd64"
        "NetKVM"    = "$VirtDrive\NetKVM\w11\amd64"
        "Balloon"   = "$VirtDrive\Balloon\w11\amd64"
        "vioserial" = "$VirtDrive\vioserial\w11\amd64"
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
            -ImagePath $VirtioIsoPath
    }
}


Write-Host "      VirtIO-Komponenten erfolgreich vorbereitet."
Write-Host ""

# ------------------------------------------------------------
# Autounattend.xml erzeugen
# ------------------------------------------------------------

Write-Host "[2/7] Erzeuge Autounattend.xml..."

$Xml = Get-Content $AnswerTemplate -Raw

$Xml = $Xml.Replace(
    "__LAB_PASSWORD__",
    $env:ISO_LAB_PASSWORD
)

Set-Content `
    -Path $FinalAnswer `
    -Value $Xml `
    -Encoding UTF8


# ------------------------------------------------------------
# OEM-Struktur erzeugen
# ------------------------------------------------------------

Write-Host "[2/7] Bereite OEM-Struktur vor..."

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

Write-Host "[3/7] Synchronisiere Skripte..."

$RuntimeScripts = @(
    "Search.ps1",
    "Explorer.ps1",
    "WindowsDefaults.ps1",
    "Edge.ps1",
    "FirstLogon.ps1"
)

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

Write-Host "[4/7] Synchronisiere Portable Tools..."

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

Write-Host "[5/7] Backe ISO..."

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
# Ergebnis
# ------------------------------------------------------------

$Result = Get-Item $OutputIso

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