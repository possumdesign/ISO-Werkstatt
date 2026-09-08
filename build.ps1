param(
    [string]$Version = "0.4.4"
)

$ErrorActionPreference = "Stop"

# ------------------------------------------------------------
# ISO-Werkstatt Build Configuration
# ------------------------------------------------------------

$Root = $PSScriptRoot

$AnswerTemplate = Join-Path $Root "answer\Autounattend.xml"
$ScriptsSource  = Join-Path $Root "scripts"
$ToolsSource    = Join-Path $Root "tools"

$IsoRoot = Join-Path $Root "build\iso-root"

$OemRoot = Join-Path $IsoRoot 'sources\$OEM$'
$OemScripts = Join-Path $OemRoot '$1\ISO-Werkstatt\scripts'
$OemTools   = Join-Path $OemRoot '$1\ISO-Werkstatt\Tools'
$SetupScripts = Join-Path $OemRoot '$$\Setup\Scripts'

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

if (-not (Test-Path $IsoRoot)) {
    throw "ISO-Root fehlt: $IsoRoot"
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


# ------------------------------------------------------------
# Autounattend.xml erzeugen
# ------------------------------------------------------------

Write-Host "[1/5] Erzeuge Autounattend.xml..."

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

Write-Host "[2/5] Bereite OEM-Struktur vor..."

New-Item -ItemType Directory -Force $OemScripts | Out-Null
New-Item -ItemType Directory -Force $OemTools | Out-Null
New-Item -ItemType Directory -Force $SetupScripts | Out-Null


# ------------------------------------------------------------
# Skripte synchronisieren
# ------------------------------------------------------------

Write-Host "[3/5] Synchronisiere Skripte..."

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

Write-Host "[4/5] Synchronisiere Portable Tools..."

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

Write-Host "[5/5] Backe ISO..."

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