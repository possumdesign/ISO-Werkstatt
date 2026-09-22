param(
    [Parameter(Mandatory=$true)][string]$WindowsIso,
    [Parameter(Mandatory=$true)][string]$ResultPath,
    [Parameter(Mandatory=$true)][guid]$RunId
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'BuildSupport.ps1')
$reservation = [IO.File]::Open($ResultPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::Read)
$reservation.Dispose()
$result = [ordered]@{ RunId=$RunId.ToString(); WindowsIso=$WindowsIso; Status='Failed'; Editions=@(); Error=$null }
try {
    $result.Editions = @(Get-BuildIsoEditions -WindowsIso $WindowsIso -LockPath (Join-Path $root 'build\build.lock'))
    $result.Status = 'Succeeded'
}
catch { $result.Error = $_.Exception.Message }
Write-BuildState -State $result -Path $ResultPath
if ($result.Status -ne 'Succeeded') { exit 1 }
