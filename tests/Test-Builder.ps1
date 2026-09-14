param([string]$SourceRoot = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference = "Stop"
$TestRoot = Join-Path ([IO.Path]::GetTempPath()) ("ISO-Werkstatt-tests-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $TestRoot | Out-Null
function Assert-Test { param([bool]$Condition, [string]$Message) if (-not $Condition) { throw $Message } }

. (Join-Path $SourceRoot "BuildSupport.ps1")
$lockPath = Join-Path $TestRoot "build.lock"
$lock = Enter-BuildLock $lockPath
try {
    # Zweiter Prozess muss scheitern; nach Freigabe muss die Datei erneut nutzbar sein.
    $probe = Join-Path $TestRoot "lock-probe.ps1"
    @'
param($Support, $LockPath)
. $Support
try { $handle = Enter-BuildLock $LockPath; $handle.Dispose(); exit 1 } catch { exit 0 }
'@ | Set-Content -LiteralPath $probe -Encoding UTF8
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $probe (Join-Path $SourceRoot "BuildSupport.ps1") $lockPath
    Assert-Test ($LASTEXITCODE -eq 0) "Paralleler Zugriff wurde nicht verhindert."
}
finally { $lock.Dispose() }
$lock = Enter-BuildLock $lockPath
$lock.Dispose()
foreach ($target in @("Windows11", "Windows10", "Server2022", "Server2025")) {
    $expected = @{ Windows11="w11"; Windows10="w10"; Server2022="2k22"; Server2025="2k25" }
    Assert-Test ((Get-BuildTarget $target).VirtioTarget -eq $expected[$target]) "Treiberzuordnung falsch."
}

# Vollständiger Builder in isolierter Kopie. Nur Adminprüfung und oscdimg-Pfad
# werden dort ersetzt; DISM/DiskImage-Cmdlets arbeiten ausschließlich als Stubs.
$Fixture = Join-Path $TestRoot "fixture"
New-Item -ItemType Directory -Path $Fixture | Out-Null
foreach ($dir in @("config", "scripts", "answer")) {
    Copy-Item -LiteralPath (Join-Path $SourceRoot $dir) -Destination $Fixture -Recurse
}
Copy-Item -LiteralPath (Join-Path $SourceRoot "BuildSupport.ps1") -Destination $Fixture
$buildCode = [IO.File]::ReadAllText((Join-Path $SourceRoot "build.ps1"))
Assert-Test ($buildCode.Contains('if (-not $IsAdmin)')) "Admin-Testmarker fehlt."
$buildCode = $buildCode.Replace('if (-not $IsAdmin)', 'if ($false)')
$oscdimgLine = '$Oscdimg = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"'
Assert-Test ($buildCode.Contains($oscdimgLine)) "Oscdimg-Testmarker fehlt."
$buildCode = $buildCode.Replace($oscdimgLine, '$Oscdimg = Join-Path $PSScriptRoot "oscdimg-stub.ps1"')
[IO.File]::WriteAllText((Join-Path $Fixture "build.ps1"), $buildCode, [Text.UTF8Encoding]::new($true))
@'
[IO.File]::WriteAllText($args[-1], "fixture-iso")
$global:LASTEXITCODE = 0
'@ | Set-Content -LiteralPath (Join-Path $Fixture "oscdimg-stub.ps1") -Encoding UTF8
$WinMedia = Join-Path $TestRoot "windows-media"
$VirtMedia = Join-Path $TestRoot "virtio-media"
foreach ($file in @("sources\install.wim", "sources\boot.wim", "boot\etfsboot.com", "efi\microsoft\boot\efisys.bin")) {
    $path = Join-Path $WinMedia $file
    New-Item -ItemType Directory -Path (Split-Path $path) -Force | Out-Null
    Set-Content -LiteralPath $path -Value "fixture"
}
foreach ($driver in @("vioscsi", "NetKVM", "Balloon", "vioserial")) {
    $path = Join-Path $VirtMedia "$driver\w11\amd64"
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $path "driver.inf") -Value "fixture"
}
New-Item -ItemType Directory -Path (Join-Path $VirtMedia "guest-agent") | Out-Null
Set-Content -LiteralPath (Join-Path $VirtMedia "guest-agent\qemu-ga-x86_64.msi") -Value "fixture"
$WinIso = Join-Path $TestRoot "windows.iso"
$VirtIso = Join-Path $TestRoot "virtio.iso"
Set-Content -LiteralPath $WinIso -Value "fixture"
Set-Content -LiteralPath $VirtIso -Value "fixture"
New-PSDrive -Name ISOTestWin -PSProvider FileSystem -Root $WinMedia | Out-Null
New-PSDrive -Name ISOTestVirt -PSProvider FileSystem -Root $VirtMedia | Out-Null
function Mount-DiskImage { param($ImagePath, [switch]$PassThru) [pscustomobject]@{ ImagePath=$ImagePath } }
function Get-Volume { process { [pscustomobject]@{ DriveLetter = $(if ($_.ImagePath -eq $WinIso) { "ISOTestWin" } else { "ISOTestVirt" }) } } }
function Dismount-DiskImage { param($ImagePath) }
function Get-WindowsImage {
    param($ImagePath, [switch]$Mounted)
    if (-not $Mounted) { [pscustomobject]@{ ImageName="Windows 11 Pro"; ImageIndex=1 } }
}
function Mount-WindowsImage { param($ImagePath, $Index, $Path) }
function Add-WindowsDriver { param($Path, $Driver, [switch]$Recurse) }
function Dismount-WindowsImage { param($Path, [switch]$Save, [switch]$Discard, $ErrorAction) }
$savedPassword = $env:ISO_LAB_PASSWORD
try {
    $env:ISO_LAB_PASSWORD = 'Fixture&<__IMAGE_INDEX__>!'
    $run = [guid]::NewGuid()
    & (Join-Path $Fixture "build.ps1") -WindowsIso $WinIso -VirtioIso $VirtIso -RunId $run
    $statePath = Join-Path $Fixture "build\logs\build-$run.json"
    $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    Assert-Test ($state.Status -eq "Succeeded" -and $state.Step -eq 10) "Erfolgsstatus falsch."
    Assert-Test ($state.Version -eq "0.7.0" -and $state.TargetOS -eq "Windows11") "Standardwerte falsch."
    Assert-Test ($state.Sha256 -eq (Get-FileHash -LiteralPath $state.IsoPath).Hash) "SHA256 im Ergebnis falsch."
    Assert-Test ($state.DurationSeconds -ge 0 -and $state.CompletedAt) "Abschlussdaten fehlen."
    Assert-Test (-not ([IO.File]::ReadAllText($statePath).Contains($env:ISO_LAB_PASSWORD))) "Kennwort im Ergebnis."
    $before = [IO.File]::ReadAllText($statePath)
    $failed = $false
    try { & (Join-Path $Fixture "build.ps1") -WindowsIso $WinIso -VirtioIso $VirtIso -RunId $run } catch { $failed=$true }
    Assert-Test ($failed -and [IO.File]::ReadAllText($statePath) -ceq $before) "Doppelte RunId überschreibt Status."

    $lock = Enter-BuildLock (Join-Path $Fixture "build\build.lock")
    $blockedRun = [guid]::NewGuid()
    try {
        # Windows PowerShell 5.1 behandelt umgeleitetes natives stderr als Fehlerstream.
        $ErrorActionPreference = "Continue"
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Fixture "build.ps1") -WindowsIso $WinIso -VirtioIso $VirtIso -RunId $blockedRun *> (Join-Path $TestRoot "blocked-process.log")
        $blockedExit = $LASTEXITCODE
        $ErrorActionPreference = "Stop"
        Assert-Test ($blockedExit -eq 1) "Blockierter Builder liefert keinen Fehler-Exitcode."
        $blockedState = Get-Content (Join-Path $Fixture "build\logs\build-$blockedRun.json") -Raw | ConvertFrom-Json
        Assert-Test ($blockedState.Status -eq "Failed" -and $blockedState.Step -eq 0) "Blockierter Builder erreicht ISO-Arbeiten."
    }
    finally { $ErrorActionPreference = "Stop"; $lock.Dispose() }

    # Fehlgeschlagener oscdimg-Lauf bei bereits vorhandener ISO muss Failed sein.
    '$global:LASTEXITCODE = 7' | Set-Content -LiteralPath (Join-Path $Fixture "oscdimg-stub.ps1")
    $run = [guid]::NewGuid()
    $failed = $false
    try { & (Join-Path $Fixture "build.ps1") -WindowsIso $WinIso -VirtioIso $VirtIso -RunId $run } catch { $failed=$true }
    $state = Get-Content (Join-Path $Fixture "build\logs\build-$run.json") -Raw | ConvertFrom-Json
    Assert-Test ($failed -and $state.Status -eq "Failed" -and $state.Step -eq 9) "Fehlerstatus falsch."
    Assert-Test ($null -eq $state.IsoPath -and $null -eq $state.Sha256) "Altes Ergebnis als Erfolg ausgegeben."
    $lock = Enter-BuildLock (Join-Path $Fixture "build\build.lock")
    $lock.Dispose()

    # Weitere Ziele sind vorbereitet, aber dürfen noch keine ISO-Arbeiten starten.
    $profilePath = Join-Path $Fixture "config\lab-config.psd1"
    $profileCode = [IO.File]::ReadAllText($profilePath)
    [IO.File]::WriteAllText($profilePath, $profileCode.Replace('"Windows11"', '"Server2025"'))
    $run = [guid]::NewGuid()
    try { & (Join-Path $Fixture "build.ps1") -WindowsIso $WinIso -VirtioIso $VirtIso -RunId $run } catch { }
    $state = Get-Content (Join-Path $Fixture "build\logs\build-$run.json") -Raw | ConvertFrom-Json
    Assert-Test ($state.Status -eq "Failed" -and $state.Step -eq 1 -and $state.VirtioTarget -eq "2k25") "Nicht freigegebenes Ziel startet Build."
}
finally {
    $env:ISO_LAB_PASSWORD = $savedPassword
    Remove-PSDrive ISOTestWin, ISOTestVirt
}

# FirstLogon komplett mit harmlosen Ersatzskripten und echtem Shortcut im Testordner.
$Runtime = Join-Path $TestRoot "runtime"
New-Item -ItemType Directory -Path $Runtime | Out-Null
New-Item -ItemType Directory -Path (Join-Path $Runtime "Tools") | Out-Null
$first = [IO.File]::ReadAllText((Join-Path $SourceRoot "scripts\FirstLogon.ps1"))
$first = $first.Replace('$ScriptRoot = "C:\ISO-Werkstatt\scripts"', '$ScriptRoot = $PSScriptRoot')
$first = $first.Replace('$Log = "C:\ISO-Werkstatt\firstlogon.log"', '$Log = Join-Path $PSScriptRoot "firstlogon.log"')
$first = $first.Replace('$ResultPath = "C:\ISO-Werkstatt\firstlogon-result.json"', '$ResultPath = Join-Path $PSScriptRoot "firstlogon-result.json"')
$first = $first.Replace('$ToolsPath = "C:\ISO-Werkstatt\Tools"', '$ToolsPath = Join-Path $PSScriptRoot "Tools"')
$first = $first.Replace('[Environment]::GetFolderPath("DesktopDirectory")', '(Join-Path $PSScriptRoot "Desktop")')
$firstPath = Join-Path $Runtime "FirstLogon.ps1"
[IO.File]::WriteAllText($firstPath, $first, [Text.UTF8Encoding]::new($true))
function Start-Sleep { param($Seconds) }
function Start-Process { param($FilePath, $ArgumentList, $ErrorAction) "Explorer test" }
foreach ($name in @("Search", "Explorer", "WindowsDefaults", "Edge")) {
    "'Executed:$name'" | Set-Content -LiteralPath (Join-Path $Runtime "$name.ps1")
}
$runtimeConfig = Join-Path $Runtime "adjustments.psd1"
'@{ Search=$true; Explorer=$true; WindowsDefaults=$true; Edge=$true }' | Set-Content $runtimeConfig
& $firstPath
$result = Get-Content (Join-Path $Runtime "firstlogon-result.json") -Raw | ConvertFrom-Json
Assert-Test ($result.Status -eq "Succeeded" -and $result.Steps.Count -eq 6) "FirstLogon-Erfolg falsch."
$shell = New-Object -ComObject WScript.Shell
$link = $shell.CreateShortcut((Join-Path $Runtime "Desktop\Tools.lnk"))
Assert-Test ($link.TargetPath -eq (Join-Path $Runtime "Tools")) "Tools-Verknüpfung falsch."

'Write-Error "fixture failure" -ErrorAction Continue' | Set-Content (Join-Path $Runtime "Search.ps1")
'throw "fixture terminating failure"' | Set-Content (Join-Path $Runtime "WindowsDefaults.ps1")
'@{ Search=$true; Explorer=$true; WindowsDefaults=$true; Edge=$false }' | Set-Content $runtimeConfig
$failed = $false
try { & $firstPath } catch { $failed=$true }
$result = Get-Content (Join-Path $Runtime "firstlogon-result.json") -Raw | ConvertFrom-Json
Assert-Test ($failed -and $result.Status -eq "Failed") "FirstLogon-Fehler nicht erkannt."
Assert-Test (@($result.Steps | Where-Object Status -eq "Failed").Count -eq 2) "Fehleranzahl falsch."
Assert-Test (($result.Steps | Where-Object Name -eq "Explorer").Status -eq "Succeeded") "Weitere Gruppen nicht ausgeführt."
Assert-Test (($result.Steps | Where-Object Name -eq "Edge").Status -eq "Skipped") "Deaktivierte Gruppe ausgeführt."
'@{ Search=$false; Explorer=$false; WindowsDefaults=$false; Edge=$false }' | Set-Content $runtimeConfig
& $firstPath
$result = Get-Content (Join-Path $Runtime "firstlogon-result.json") -Raw | ConvertFrom-Json
Assert-Test ($result.Status -eq "Succeeded") "Deaktivierte fehlerhafte Skripte wurden ausgeführt."
Assert-Test (($result.Steps | Where-Object Name -eq "OpenExplorer").Status -eq "Skipped") "Explorer trotz deaktiviertem Schalter gestartet."
Assert-Test (($result.Steps | Where-Object Name -eq "ToolsShortcut").Status -eq "Succeeded") "Tools-Verknüpfung an Explorer-Schalter gekoppelt."
'@{ Search="false" }' | Set-Content $runtimeConfig
try { & $firstPath } catch { }
$result = Get-Content (Join-Path $Runtime "firstlogon-result.json") -Raw | ConvertFrom-Json
Assert-Test ($result.Status -eq "Failed" -and $result.Steps.Count -eq 1) "Ungültige Konfiguration ohne Abschlussstatus."
Write-Host "PASS: Sperre, Zielsysteme, Build-Erfolg/Fehler, RunId, SHA256, FirstLogon und Tools-Verknüpfung."
Write-Host "Testartefakte: $TestRoot"
