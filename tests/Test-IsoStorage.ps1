param([string]$SourceRoot = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference = "Stop"
. (Join-Path $SourceRoot "BuildSupport.ps1")
function Assert-Iso { param([bool]$Condition, [string]$Message) if (-not $Condition) { throw $Message } }

$value = Invoke-IsoStorageJob -Operation "Test: erfolgreicher Auftrag" -TimeoutSeconds 10 -StartJob { Start-Job { "ready" } }
Assert-Iso ($value -eq "ready") "Auftragsergebnis fehlt."
$timer = [Diagnostics.Stopwatch]::StartNew()
$failed = $false
try { Invoke-IsoStorageJob -Operation "Test: Zeitlimit" -TimeoutSeconds 1 -StartJob { Start-Job { Start-Sleep -Seconds 30 } } }
catch { $failed = $_.Exception.Message -match "Zeitlimit" }
Assert-Iso ($failed -and $timer.Elapsed.TotalSeconds -lt 10) "Auftrag hängt trotz Zeitlimit."
$failed = $false
try { Invoke-IsoStorageJob -Operation "Test: Fehler" -TimeoutSeconds 10 -StartJob { Start-Job { throw "fixture-storage-error" } } }
catch { $failed = $_.Exception.Message -match "fixture-storage-error" }
Assert-Iso $failed "Storage-Fehler wurde verschluckt."

# Funktionsablauf mit Ersatz-Storage: keine echten ISOs oder Laufwerke verändern.
function Invoke-IsoStorageJob { param($StartJob, $Operation, $TimeoutSeconds) & $StartJob }
function Get-DiskImage {
    param($ImagePath, [switch]$AsJob, $ErrorAction)
    [pscustomobject]@{ Attached=$script:Attached; ImagePath=$ImagePath }
}
function Mount-DiskImage {
    param($ImagePath, $StorageType, [switch]$PassThru, [switch]$AsJob, $ErrorAction)
    $script:Mounts++
    $script:Attached=$true
    [pscustomobject]@{ Attached=$true; ImagePath=$ImagePath }
}
function Get-Volume {
    param($DiskImage, [switch]$AsJob, $ErrorAction)
    $script:Queries++
    if ($script:Queries -ge $script:ReadyAfter) { [pscustomobject]@{ DriveLetter="Z" } }
}
function Dismount-DiskImage {
    param($ImagePath, [switch]$AsJob, $ErrorAction)
    $script:Dismounts++
    if ($script:FailCleanup) { throw "fixture-cleanup-error" }
    $script:Attached=$false
}
$script:Mounts=0; $script:Dismounts=0; $script:Queries=0; $script:ReadyAfter=1; $script:Attached=$true; $script:FailCleanup=$false
$context=@{}
$drive=Open-BuildIso -ImagePath "fixture.iso" -Label "Test-ISO" -Context $context
Close-BuildIso -Context $context
Assert-Iso ($drive -eq "Z:" -and $script:Mounts -eq 0 -and $script:Dismounts -eq 0) "Vorhandene Einhängung verändert."

$script:Attached=$false; $script:Queries=0; $script:ReadyAfter=2
$context=@{}
$drive=Open-BuildIso -ImagePath "fixture.iso" -Label "Test-ISO" -Context $context -VolumeTimeoutSeconds 3
Close-BuildIso -Context $context
Assert-Iso ($drive -eq "Z:" -and $script:Mounts -eq 1 -and $script:Dismounts -eq 1) "Verzögerter Laufwerksbuchstabe oder eigenes Cleanup fehlerhaft."

$script:Attached=$false; $script:Queries=0; $script:ReadyAfter=1000
$context=@{}; $failed=$false
try { Open-BuildIso -ImagePath "fixture.iso" -Label "Test-ISO" -Context $context -VolumeTimeoutSeconds 1 }
catch { $failed=$_.Exception.Message -match "keinen Laufwerksbuchstaben" }
finally { Close-BuildIso -Context $context -PreserveError $failed }
Assert-Iso ($failed -and -not $script:Attached) "Fehlender Laufwerksbuchstabe nicht behandelt."

$script:FailCleanup=$true
$context=@{ Owned=$true; ImagePath="fixture.iso"; Label="Test-ISO" }
$failure=$null
try {
    try { throw "fixture-original-error" }
    catch { $failure=$_; throw }
    finally { Close-BuildIso -Context $context -PreserveError ([bool]$failure) }
}
catch { Assert-Iso ($_.Exception.Message -eq "fixture-original-error") "Cleanup hat ursprünglichen Fehler ersetzt." }
Write-Host "PASS: Storage-Zeitlimit, Fehlerweitergabe, vorhandene/eigene Einhängung und verzögerter Laufwerksbuchstabe."
