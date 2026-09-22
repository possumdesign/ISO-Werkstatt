param([string]$SourceRoot=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
function Assert-Edition($condition,$message){if(-not $condition){throw $message}}
$root=Join-Path ([IO.Path]::GetTempPath()) ('ISO-Werkstatt-edition-test-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $root 'gui'),(Join-Path $root 'media\sources'),(Join-Path $root 'build') -Force | Out-Null
Copy-Item (Join-Path $SourceRoot 'BuildSupport.ps1') $root
Copy-Item (Join-Path $SourceRoot 'gui\Read-Editions.ps1') (Join-Path $root 'gui')
# Echte Worker-/Sperr-/Ergebnislogik; nur Medienzugriff und DISM werden ersetzt.
@'
function Open-BuildIso { param($ImagePath,$Label,$Context) $Context.Owned=$true; Set-Content (Join-Path $PSScriptRoot 'opened.txt') 'opened'; return (Join-Path $PSScriptRoot 'media') }
function Close-BuildIso { param($Context,$PreserveError) Set-Content (Join-Path $PSScriptRoot 'closed.txt') 'closed' }
function Get-WindowsImage {
    param($ImagePath,$Index,$ErrorAction)
    $mode=Get-Content (Join-Path $PSScriptRoot 'mode.txt') -Raw
    if($mode.Trim() -eq 'fail'){throw 'fixture DISM error'}
    if($mode.Trim() -eq 'empty'){return}
    if($Index){
        $version='10.0.26100.1';$kind='Client';$arch=9
        if($mode.Trim() -eq 'win10'){$version='10.0.19045.1'}
        if($mode.Trim() -eq 'server2022'){$version='10.0.20348.1';$kind=if($Index -eq 1){'Server Core'}else{'Server'}}
        if($mode.Trim() -eq 'server2025'){$kind=if($Index -eq 1){'Server Core'}else{'Server'}}
        if($mode.Trim() -eq 'arm64'){$arch=12}
        return [pscustomobject]@{Architecture=$arch;Version=$version;InstallationType=$kind}
    }
    [pscustomobject]@{ImageIndex=1;ImageName='Windows 11 Home'}
    [pscustomobject]@{ImageIndex=6;ImageName='Windows 11 Pro'}
}
'@ | Add-Content (Join-Path $root 'BuildSupport.ps1') -Encoding UTF8
$iso=Join-Path $root 'Windows & test.iso'
Set-Content $iso 'fixture'
$wim=Join-Path $root 'media\sources\install.wim'
Set-Content $wim 'fixture'
foreach($mode in @('success','esd','win10','server2022','server2025','arm64','fail','empty','missing-wim','locked')){
    Set-Content (Join-Path $root 'mode.txt') $mode
    [IO.File]::Delete((Join-Path $root 'media\sources\install.esd'))
    if($mode -in @('missing-wim','esd')){[IO.File]::Delete($wim)}else{Set-Content $wim 'fixture'}
    if($mode -eq 'esd'){Set-Content (Join-Path $root 'media\sources\install.esd') 'fixture esd'}
    foreach($name in @('opened.txt','closed.txt')){[IO.File]::Delete((Join-Path $root $name))}
    $handle=$null
    if($mode -eq 'locked'){$handle=[IO.File]::Open((Join-Path $root 'build\build.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}
    $id=[guid]::NewGuid()
    $path=Join-Path $root "$id.json"
    try{
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'gui\Read-Editions.ps1') -WindowsIso $iso -ResultPath $path -RunId $id
        $code=$LASTEXITCODE
    }finally{if($handle){$handle.Dispose()}}
    $result=Get-Content $path -Raw|ConvertFrom-Json
    Assert-Edition ($result.RunId -eq $id -and $result.WindowsIso -ceq $iso) 'Falsche Zuordnung der Editionsabfrage.'
    if($mode -in @('success','esd','win10','server2022','server2025')){
        Assert-Edition ($code -eq 0 -and $result.Status -eq 'Succeeded' -and $result.Editions.Count -eq 2 -and $result.Editions[1].Name -ceq 'Windows 11 Pro') 'Editionserkennung fehlgeschlagen.'
        $expected=switch($mode){'win10'{'Windows10'} 'server2022'{'Server2022'} 'server2025'{'Server2025'} default{'Windows11'}}
        Assert-Edition ($result.Editions[0].TargetOS -eq $expected) 'Zielsystem aus DISM-Metadaten falsch.'
        if($mode -like 'server*'){Assert-Edition ($result.Editions[0].InstallationMode -eq 'Core' -and $result.Editions[1].InstallationMode -eq 'Desktop') 'Core/Desktop falsch erkannt.'}
    }else{Assert-Edition ($code -eq 1 -and $result.Status -eq 'Failed' -and $result.Error) "Fehler nicht erkannt: $mode"}
    if($mode -eq 'locked'){Assert-Edition (-not (Test-Path (Join-Path $root 'opened.txt'))) 'Medienzugriff trotz Build-Sperre.'}
    else{Assert-Edition (Test-Path (Join-Path $root 'closed.txt')) 'ISO-Cleanup wurde ausgelassen.'}
    $handle=[IO.File]::Open((Join-Path $root 'build\build.lock'),[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    $handle.Dispose()
}
Write-Host 'PASS: Editionsworker, Ergebniszuordnung, DISM-Fehler, leere Liste, fehlendes WIM, Sperre und Cleanup.'
Write-Host "Testartefakte: $root"
