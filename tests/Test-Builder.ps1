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
Add-Content -LiteralPath (Join-Path $Fixture "BuildSupport.ps1") -Value 'function Invoke-IsoStorageJob { param($StartJob, $Operation, $TimeoutSeconds) & $StartJob }'
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
Set-Content -LiteralPath (Join-Path $WinMedia 'sources\product.ini') -Value "[cmi]`nProfessional=AAAAA-BBBBB-CCCCC-DDDDD-EEEEE"
foreach ($folder in @('w11','w10','2k22','2k25')) {
foreach ($driver in @("vioscsi", "NetKVM", "Balloon", "vioserial")) {
    $path = Join-Path $VirtMedia "$driver\$folder\amd64"
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $path "driver.inf") -Value "fixture"
}
}
New-Item -ItemType Directory -Path (Join-Path $VirtMedia "guest-agent") | Out-Null
Set-Content -LiteralPath (Join-Path $VirtMedia "guest-agent\qemu-ga-x86_64.msi") -Value "fixture"
$WinIso = Join-Path $TestRoot "windows.iso"
$VirtIso = Join-Path $TestRoot "virtio.iso"
Set-Content -LiteralPath $WinIso -Value "fixture"
Set-Content -LiteralPath $VirtIso -Value "fixture"
New-PSDrive -Name ISOTestWin -PSProvider FileSystem -Root $WinMedia | Out-Null
New-PSDrive -Name ISOTestVirt -PSProvider FileSystem -Root $VirtMedia | Out-Null
function Get-DiskImage { param($ImagePath, [switch]$AsJob, $ErrorAction) [pscustomobject]@{ ImagePath=$ImagePath; Attached=$false } }
$TestCalls = @{ DiskMounts=0; DriverAdds=0; WimMounts=0 }

function Mount-DiskImage { param($ImagePath, [switch]$PassThru, [switch]$AsJob, $StorageType, $ErrorAction) $TestCalls.DiskMounts++; [pscustomobject]@{ ImagePath=$ImagePath } }
function Get-Volume { param($DiskImage, [switch]$AsJob, $ErrorAction) process { [pscustomobject]@{ DriveLetter = $(if ($DiskImage.ImagePath -eq $WinIso) { "ISOTestWin" } else { "ISOTestVirt" }) } } }
function Dismount-DiskImage { param($ImagePath, [switch]$AsJob, $ErrorAction) }
$FixtureImage=@{Name='Windows 11 Pro';Version='10.0.26100.1';Type='Client';Index=1;ExportFailed=$false;ExportIndex=0}
function Export-WindowsImage {
    param($SourceImagePath,$SourceIndex,$DestinationImagePath,$CompressionType,[switch]$CheckIntegrity,$ErrorAction)
    $FixtureImage.ExportIndex=$SourceIndex
    if($FixtureImage.ExportFailed){throw 'fixture export failure'}
    Set-Content -LiteralPath $DestinationImagePath -Value 'exported fixture'
}
function Get-WindowsImage {
    param($ImagePath, [switch]$Mounted, $Index, $ErrorAction)
    if($Mounted){return}
    if($PSBoundParameters.ContainsKey('Index')){return [pscustomobject]@{ImageName=$FixtureImage.Name;ImageIndex=$Index;EditionId='Professional';Architecture=9;Version=$FixtureImage.Version;InstallationType=$FixtureImage.Type}}
    $sourceIndex=if([IO.Path]::GetExtension($ImagePath) -eq '.esd'){$FixtureImage.Index}else{1}
    [pscustomobject]@{ImageName=$FixtureImage.Name;ImageIndex=$sourceIndex}
}
function Mount-WindowsImage { param($ImagePath, $Index, $Path) $TestCalls.WimMounts++ }
function Add-WindowsDriver { param($Path, $Driver, [switch]$Recurse) $TestCalls.DriverAdds++ }
function Dismount-WindowsImage { param($Path, [switch]$Save, [switch]$Discard, $ErrorAction) }
$savedProductKey = $env:ISO_PRODUCT_KEY
$savedPassword = $env:ISO_LAB_PASSWORD
try {
    $env:ISO_PRODUCT_KEY = $null
    $env:ISO_LAB_PASSWORD = 'Fixture&<__IMAGE_INDEX__>!'
    $run = [guid]::NewGuid()
    & (Join-Path $Fixture "build.ps1") -WindowsIso $WinIso -VirtioIso $VirtIso -RunId $run
    $statePath = Join-Path $Fixture "build\logs\build-$run.json"
    $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    Assert-Test ($state.Status -eq "Succeeded" -and $state.Step -eq 10) "Erfolgsstatus falsch."
    Assert-Test ($state.LocalUserName -ceq 'LabAdmin') 'VM-Standardname verändert.'
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

    # Alle vier Kombinationen Treiber/Agent, ohne echte Storage-/DISM-Aufrufe.
    $fixtureOem = Join-Path $Fixture 'build\iso-root\sources\$OEM$\$1\ISO-Werkstatt'
    New-Item -ItemType Directory -Path (Join-Path $Fixture 'tools') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $Fixture 'tools\test-tool.txt') -Value 'fixture-tool'
    foreach ($case in @(
        @{Profile='pc-local'; Agent='Off'; Drivers=0; Mounts=1; Tools='Off'},
        @{Profile='pc-local'; Agent='On'; Drivers=0; Mounts=2; Tools='On'},
        @{Profile='lab-config'; Agent='Off'; Drivers=6; Mounts=2; Tools='Off'},
        @{Profile='lab-config'; Agent='On'; Drivers=6; Mounts=2; Tools='On'}
    )) {
        $TestCalls.DiskMounts=0; $TestCalls.DriverAdds=0; $TestCalls.WimMounts=0
        $run=[guid]::NewGuid()
        $buildArgs=@{WindowsIso=$WinIso; Profile=$case.Profile; QemuGuestAgent=$case.Agent; Tools=$case.Tools; WebSearch='Off'; UBlockLite='On'; RunId=$run}
        if ($case.Mounts -gt 1) { $buildArgs.VirtioIso=$VirtIso }
        $env:ISO_PRODUCT_KEY='abcde-fghij-klmno-pqrst-uvwxy'
        & (Join-Path $Fixture 'build.ps1') @buildArgs
        Assert-Test ($TestCalls.DiskMounts -eq $case.Mounts -and $TestCalls.DriverAdds -eq $case.Drivers) "Falsche Treiber-/Mount-Aufrufe: $($case.Profile), $($case.Agent)"
        Assert-Test ($TestCalls.WimMounts -eq $(if ($case.Drivers) { 2 } else { 0 })) 'WIM-Mount trotz deaktivierter Treiber.'
        Assert-Test ((Test-Path (Join-Path $fixtureOem 'packages\qemu-ga-x86_64.msi')) -eq ($case.Agent -eq 'On')) 'QEMU-Auswahl falsch.'
        Assert-Test ((Test-Path (Join-Path $fixtureOem 'Tools\test-tool.txt')) -eq ($case.Tools -eq 'On')) 'Tools-Auswahl falsch.'
        $flags=Import-PowerShellDataFile (Join-Path $fixtureOem 'scripts\adjustments.psd1')
        Assert-Test (-not $flags.Search -and $flags.UBlockLite -and $flags.Tools -eq ($case.Tools -eq 'On')) 'Laufoptionen falsch.'
        $setup=Get-Content (Join-Path $Fixture 'build\iso-root\sources\$OEM$\$$\Setup\Scripts\SetupComplete.cmd') -Raw
        Assert-Test (($setup -match 'msiexec') -eq ($case.Agent -eq 'On')) 'QEMU-Setup trotz deaktiviertem Agent.'
        $answer=[xml](Get-Content (Join-Path $Fixture 'build\iso-root\Autounattend.xml') -Raw)
        $ns=[Xml.XmlNamespaceManager]::new($answer.NameTable); $ns.AddNamespace('u','urn:schemas-microsoft-com:unattend')
        Assert-Test ($answer.SelectSingleNode('//u:UserData/u:ProductKey/u:Key',$ns).InnerText -ceq $env:ISO_PRODUCT_KEY.ToUpperInvariant()) 'Produktschlüssel falsch.'
        Assert-Test ($answer.SelectSingleNode('//u:AutoLogon/u:Password/u:Value',$ns).InnerText -ceq $env:ISO_LAB_PASSWORD) 'XML-Passwort durch Schlüssel verändert.'
        if ($case.Profile -eq 'pc-local') {
            Assert-Test ($answer.SelectNodes('//u:DiskConfiguration|//u:InstallTo',$ns).Count -eq 0) 'PC-Profil partitioniert automatisch.'
        }
        foreach ($ext in @('json','log')) {
            $content=Get-Content (Join-Path $Fixture "build\logs\build-$run.$ext") -Raw
            Assert-Test ($content -notmatch [regex]::Escape($env:ISO_PRODUCT_KEY)) 'Produktschlüssel in Protokoll/Status.'
        }
    }
    $env:ISO_PRODUCT_KEY=$null
    $run=[guid]::NewGuid()
    & (Join-Path $Fixture 'build.ps1') -WindowsIso $WinIso -VirtioIso 'nonexistent.iso' -Profile pc-local -RunId $run
    $plainAnswer=[xml](Get-Content (Join-Path $Fixture 'build\iso-root\Autounattend.xml') -Raw)
    Assert-Test ($plainAnswer.OuterXml -notmatch 'ProductKey') 'PC-Build ohne Schlüssel setzt trotzdem ProductKey.'
    Assert-Test ($plainAnswer.unattend.settings.component.AutoLogon.Username -contains 'Winuser') 'PC-Standardname falsch.'
    foreach ($account in @('Technik & Test', 'Test__USER__', "O'Neil")) {
        & (Join-Path $Fixture 'build.ps1') -WindowsIso $WinIso -Profile pc-local -LocalUserName $account
        $custom=[xml](Get-Content (Join-Path $Fixture 'build\iso-root\Autounattend.xml') -Raw)
        $ns=[Xml.XmlNamespaceManager]::new($custom.NameTable); $ns.AddNamespace('u','urn:schemas-microsoft-com:unattend')
        foreach($xpath in @('//u:LocalAccount/u:Name','//u:LocalAccount/u:DisplayName','//u:AutoLogon/u:Username')) {
            Assert-Test ($custom.SelectSingleNode($xpath,$ns).InnerText -ceq $account) 'Kontoname oder Autologon abweichend.'
        }
        Assert-Test ($custom.SelectSingleNode('//u:AutoLogon/u:Password/u:Value',$ns).InnerText -ceq $env:ISO_LAB_PASSWORD) 'Kennwort durch Kontonamen verändert.'
    }
    foreach($bad in @('', '   ', 'a/b', 'a\b', 'a@b', 'a:b', 'a[b', 'a"b', 'a+b', 'a|b', 'a,b', 'a*b', 'a?b', 'a<b', 'a>b', 'a=b', 'a;b', ('x'*21), 'Administrator', '...', ' name', 'name.', "a`nb")) {
        $TestCalls.DiskMounts=0; $rejected=$false
        try { & (Join-Path $Fixture 'build.ps1') -WindowsIso $WinIso -Profile pc-local -LocalUserName $bad } catch { $rejected=$true }
        Assert-Test ($rejected -and $TestCalls.DiskMounts -eq 0) 'Ungültiger Kontoname startet Medienarbeiten.'
    }
    $template=[xml](Get-Content (Join-Path $Fixture 'answer\Autounattend-PC.xml') -Raw)
    Assert-Test ($template.OuterXml -notmatch 'ProductKey|WillWipeDisk|DiskConfiguration') 'PC-Vorlage enthält festen Key oder automatische Partitionierung.'
    $legacy=Resolve-BuildProfile @{Edition='Windows 11 Pro'; AnswerTemplate='answer\Autounattend.xml'; ToolsDirectory='tools'; Adjustments=@{Edge=$false}}
    Assert-Test (-not $legacy.Features.UBlockLite -and $legacy.IncludeVirtioDrivers -and $legacy.Features.QemuGuestAgent) 'Alte Profilvorgaben verändert.'
    $independent=Resolve-BuildProfile @{Edition='Windows 11 Pro'; AnswerTemplate='answer\Autounattend.xml'; ToolsDirectory='tools'; Adjustments=@{Edge=$false}; Features=@{UBlockLite=$true}}
    Assert-Test ($independent.Features.UBlockLite -and -not $independent.Adjustments.Edge) 'uBlock an Edge gekoppelt.'
    $env:ISO_PRODUCT_KEY='invalid-secret'
    $TestCalls.DiskMounts=0
    try { & (Join-Path $Fixture 'build.ps1') -WindowsIso $WinIso -Profile pc-local; throw 'Ungültiger Schlüssel akzeptiert.' } catch {
        Assert-Test ($_.Exception.Message -match 'Produktschlüssel muss') 'Unerwarteter Fehler bei Keyvalidierung.'
    }
    Assert-Test ($TestCalls.DiskMounts -eq 0) 'Keyvalidierung erst nach ISO-Arbeiten.'
    $env:ISO_PRODUCT_KEY=$null

    # Alle neuen Zielprofile, VM/Hardware und Desktop/Core durch den gesamten Builder.
    foreach($profileFile in @(Get-ChildItem (Join-Path $Fixture 'config') -File | Where-Object {$_.BaseName -match '^(win10|server2022|server2025)-'})){
        $profile=Resolve-BuildProfile (Import-PowerShellDataFile $profileFile.FullName)
        $FixtureImage.Name=$profile.Edition
        $FixtureImage.Version=switch($profile.TargetOS){Windows10{'10.0.19041.1'} Server2022{'10.0.20348.1'} Server2025{'10.0.26100.1'}}
        $FixtureImage.Type=if($profile.TargetOS -eq 'Windows10'){'Client'}elseif($profile.InstallationMode -eq 'Core'){'Server Core'}else{'Server'}
        $TestCalls.WimMounts=0;$TestCalls.DriverAdds=0
        $run=[guid]::NewGuid()
        & (Join-Path $Fixture 'build.ps1') -WindowsIso $WinIso -VirtioIso $VirtIso -Profile $profileFile.BaseName -RunId $run
        $state=Get-Content (Join-Path $Fixture "build\logs\build-$run.json") -Raw|ConvertFrom-Json
        Assert-Test ($state.Status -eq 'Succeeded' -and $state.TargetOS -eq $profile.TargetOS -and $state.InstallationMode -eq $profile.InstallationMode) 'Zielprofil nicht erfolgreich gebaut.'
        Assert-Test ($TestCalls.DriverAdds -eq $(if($profile.IncludeVirtioDrivers){6}else{0})) 'Treiberintegration für Zielprofil falsch.'
        $xml=[xml](Get-Content (Join-Path $Fixture 'build\iso-root\Autounattend.xml') -Raw)
        $ns=[Xml.XmlNamespaceManager]::new($xml.NameTable);$ns.AddNamespace('u','urn:schemas-microsoft-com:unattend')
        Assert-Test ($xml.SelectSingleNode('//u:AutoLogon/u:Username',$ns).InnerText -ceq $profile.LocalUserName) 'Zielkonto falsch.'
        Assert-Test (($xml.SelectNodes('//u:WillWipeDisk',$ns).Count -gt 0) -eq $profile.IncludeVirtioDrivers) 'VM/local-Partitionierung falsch.'
        if($profile.TargetOS -eq 'Windows10'){
            Assert-Test ($xml.SelectSingleNode('//u:UserData/u:ProductKey/u:Key',$ns).InnerText -eq 'AAAAA-BBBBB-CCCCC-DDDDD-EEEEE') 'Windows-10-Setup-Key aus Medium fehlt.'
            Assert-Test (-not $state.ProductKeyProvided) 'Automatischer Setup-Key als Benutzereingabe markiert.'
        }else{Assert-Test ($xml.SelectNodes('//u:UserData/u:ProductKey',$ns).Count -eq 0) 'Client-Setup-Key in Servervorlage.'}
        if($profile.TargetOS -like 'Server*'){
            Assert-Test ($xml.SelectSingleNode('//u:AdministratorPassword/u:Value',$ns).InnerText -ceq $env:ISO_LAB_PASSWORD) 'Server-Administratorkennwort fehlt oder wurde verändert.'
        }
        $runtimeTarget=Import-PowerShellDataFile (Join-Path $Fixture 'build\iso-root\sources\$OEM$\$1\ISO-Werkstatt\scripts\target.psd1')
        Assert-Test ($runtimeTarget.InstallationMode -eq $profile.InstallationMode) 'Core/Desktop-Laufzeitdatei fehlt.'
    }
    # Abweichendes Betriebssystem und Core/Desktop müssen vor WIM-Mounts scheitern.
    $FixtureImage.Name='Windows 10 Pro';$FixtureImage.Version='10.0.26100.1';$FixtureImage.Type='Client'
    $TestCalls.WimMounts=0;$rejected=$false
    try{& (Join-Path $Fixture 'build.ps1') -WindowsIso $WinIso -Profile win10-local}catch{$rejected=$true}
    Assert-Test ($rejected -and $TestCalls.WimMounts -eq 0) 'Falsches Betriebssystem akzeptiert.'
    $FixtureImage.Name='Windows Server 2025 SERVERSTANDARD';$FixtureImage.Type='Server'
    $rejected=$false
    try{& (Join-Path $Fixture 'build.ps1') -WindowsIso $WinIso -Profile server2025-core-local}catch{$rejected=$true}
    Assert-Test ($rejected -and $TestCalls.WimMounts -eq 0) 'Desktop-Abbild als Core akzeptiert.'
    # ESD-Edition wird vor Integration zu einem einzelnen WIM-Index 1 exportiert.
    [IO.File]::Move((Join-Path $WinMedia 'sources\install.wim'),(Join-Path $WinMedia 'sources\install.wim.saved'))
    Set-Content (Join-Path $WinMedia 'sources\install.esd') 'fixture esd'
    $FixtureImage.Name='Windows 10 Pro';$FixtureImage.Version='10.0.19041.1';$FixtureImage.Type='Client';$FixtureImage.Index=7
    & (Join-Path $Fixture 'build.ps1') -WindowsIso $WinIso -VirtioIso $VirtIso -Profile win10-vm
    $xml=[xml](Get-Content (Join-Path $Fixture 'build\iso-root\Autounattend.xml') -Raw)
    Assert-Test ($FixtureImage.ExportIndex -eq 7 -and $xml.SelectSingleNode('//u:MetaData/u:Value',$ns).InnerText -eq '1') 'ESD-Index nicht korrekt umgestellt.'
    Assert-Test (-not (Test-Path (Join-Path $Fixture 'build\iso-root\sources\install.esd'))) 'ESD blieb neben exportierter WIM bestehen.'
    $FixtureImage.ExportFailed=$true;$TestCalls.WimMounts=0;$rejected=$false
    try{& (Join-Path $Fixture 'build.ps1') -WindowsIso $WinIso -Profile win10-local}catch{$rejected=$true}
    Assert-Test ($rejected -and $TestCalls.WimMounts -eq 0 -and (Test-Path (Join-Path $Fixture 'build\iso-root\sources\install.esd'))) 'ESD-Exportfehler nicht sicher behandelt.'
    $FixtureImage.ExportFailed=$false
    [IO.File]::Delete((Join-Path $WinMedia 'sources\install.esd'))
    [IO.File]::Move((Join-Path $WinMedia 'sources\install.wim.saved'),(Join-Path $WinMedia 'sources\install.wim'))
    $FixtureImage.Name='Windows 11 Pro';$FixtureImage.Version='10.0.26100.1';$FixtureImage.Type='Client';$FixtureImage.Index=1

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

    # Eine Windows-11-Antwortdatei darf nicht für Server verwendet werden.
    $profilePath = Join-Path $Fixture "config\lab-config.psd1"
    $profileCode = [IO.File]::ReadAllText($profilePath)
    [IO.File]::WriteAllText($profilePath, $profileCode.Replace('"Windows11"', '"Server2025"').Replace('WindowsDefaults = $true','WindowsDefaults = $false'))
    $run = [guid]::NewGuid()
    try { & (Join-Path $Fixture "build.ps1") -WindowsIso $WinIso -VirtioIso $VirtIso -RunId $run } catch { }
    $state = Get-Content (Join-Path $Fixture "build\logs\build-$run.json") -Raw | ConvertFrom-Json
    Assert-Test ($state.Status -eq "Failed" -and $state.Step -eq 1 -and $state.VirtioTarget -eq "2k25") "Falsche Server-Antwortdatei startet Build."
}
finally {
    $env:ISO_LAB_PASSWORD = $savedPassword
    $env:ISO_PRODUCT_KEY = $savedProductKey
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
foreach ($name in @("Search", "Explorer", "WindowsDefaults", "Edge", "UBlockLite")) {
    "'Executed:$name'" | Set-Content -LiteralPath (Join-Path $Runtime "$name.ps1")
}
$runtimeConfig = Join-Path $Runtime "adjustments.psd1"
'@{ Search=$true; Explorer=$true; WindowsDefaults=$true; Edge=$true; UBlockLite=$true; Tools=$true }' | Set-Content $runtimeConfig
& $firstPath
$result = Get-Content (Join-Path $Runtime "firstlogon-result.json") -Raw | ConvertFrom-Json
Assert-Test ($result.Status -eq "Succeeded" -and $result.Steps.Count -eq 7) "FirstLogon-Erfolg falsch."
$shell = New-Object -ComObject WScript.Shell
$link = $shell.CreateShortcut((Join-Path $Runtime "Desktop\Tools.lnk"))
Assert-Test ($link.TargetPath -eq (Join-Path $Runtime "Tools")) "Tools-Verknüpfung falsch."

'Write-Error "fixture failure" -ErrorAction Continue' | Set-Content (Join-Path $Runtime "Search.ps1")
'throw "fixture terminating failure"' | Set-Content (Join-Path $Runtime "WindowsDefaults.ps1")
'@{ Search=$true; Explorer=$true; WindowsDefaults=$true; Edge=$false; UBlockLite=$true; Tools=$true }' | Set-Content $runtimeConfig
$failed = $false
try { & $firstPath } catch { $failed=$true }
$result = Get-Content (Join-Path $Runtime "firstlogon-result.json") -Raw | ConvertFrom-Json
Assert-Test ($failed -and $result.Status -eq "Failed") "FirstLogon-Fehler nicht erkannt."
Assert-Test (@($result.Steps | Where-Object Status -eq "Failed").Count -eq 2) "Fehleranzahl falsch."
Assert-Test (($result.Steps | Where-Object Name -eq "Explorer").Status -eq "Succeeded") "Weitere Gruppen nicht ausgeführt."
Assert-Test (($result.Steps | Where-Object Name -eq "Edge").Status -eq "Skipped") "Deaktivierte Gruppe ausgeführt."
'@{ Search=$false; Explorer=$false; WindowsDefaults=$false; Edge=$false; UBlockLite=$true; Tools=$true }' | Set-Content $runtimeConfig
& $firstPath
$result = Get-Content (Join-Path $Runtime "firstlogon-result.json") -Raw | ConvertFrom-Json
Assert-Test ($result.Status -eq "Succeeded") "Deaktivierte fehlerhafte Skripte wurden ausgeführt."
Assert-Test (($result.Steps | Where-Object Name -eq "OpenExplorer").Status -eq "Skipped") "Explorer trotz deaktiviertem Schalter gestartet."
Assert-Test (($result.Steps | Where-Object Name -eq "ToolsShortcut").Status -eq "Succeeded") "Tools-Verknüpfung an Explorer-Schalter gekoppelt."
Assert-Test (($result.Steps | Where-Object Name -eq 'UBlockLite').Status -eq 'Succeeded') 'uBlock trotz deaktiviertem Edge nicht ausgeführt.'
('@{ Search=$false; Explorer=$false; WindowsDefaults=$false; Edge=$false; UBlockLite=$false; Tools=$false }') | Set-Content $runtimeConfig
& $firstPath
$result = Get-Content (Join-Path $Runtime 'firstlogon-result.json') -Raw | ConvertFrom-Json
Assert-Test (@($result.Steps | Where-Object Status -ne 'Skipped').Count -eq 0) 'Deaktivierte Zusätze ausgeführt.'
# Core überspringt auch dann Desktop-Schritte, wenn alte Laufzeitflags aktiv sind.
('@{ TargetOS="Server2025"; InstallationMode="Core" }') | Set-Content (Join-Path $Runtime 'target.psd1')
('@{ Search=$true; Explorer=$true; WindowsDefaults=$true; Edge=$true; UBlockLite=$true; Tools=$true }') | Set-Content $runtimeConfig
& $firstPath
$result=Get-Content (Join-Path $Runtime 'firstlogon-result.json') -Raw|ConvertFrom-Json
Assert-Test ($result.Status -eq 'Succeeded' -and @($result.Steps | Where-Object Status -ne 'Skipped').Count -eq 0) 'Core führt Desktop-/Explorer-/Shortcut-Schritte aus.'
('@{ Search="false" }') | Set-Content $runtimeConfig
try { & $firstPath } catch { }
$result = Get-Content (Join-Path $Runtime "firstlogon-result.json") -Raw | ConvertFrom-Json
Assert-Test ($result.Status -eq "Failed" -and $result.Steps.Count -eq 1) "Ungültige Konfiguration ohne Abschlussstatus."
Write-Host "PASS: Build/Sperre/Hash, vier Treiber-Agent-Kombinationen, PC-XML, Schlüssel, Optionen und FirstLogon."
Write-Host "Testartefakte: $TestRoot"
