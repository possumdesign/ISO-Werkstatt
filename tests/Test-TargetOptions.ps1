$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'BuildSupport.ps1')

foreach ($case in @(
    @{ Architecture=0; Version='10.0.19045.1'; InstallationType='Client'; Target='Windows10' },
    @{ Architecture=12; Version='10.0.26100.1'; InstallationType='Client'; Target='Windows11' },
    @{ Architecture=9; Version='invalid'; InstallationType='Client'; Target='Windows10' },
    @{ Architecture=9; Version='10.0.20348.1'; InstallationType='Server'; Target='Server2025' }
)) {
    $rejected = $false
    try { Assert-BuildImageTarget -Image ([pscustomobject]$case) -TargetOS $case.Target } catch { $rejected = $true }
    if (-not $rejected) { throw 'Unpassendes Abbild wurde akzeptiert.' }
}

# Registry-Zugriffe werden vollständig durch Aufzeichnungen ersetzt.
$fixture = Join-Path $env:TEMP ('ISO-Werkstatt-targets-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixture | Out-Null
Copy-Item (Join-Path $root 'scripts\WindowsDefaults.ps1') $fixture
foreach ($os in @('Windows10','Windows11','Server2022','Server2025')) {
    [IO.File]::WriteAllText((Join-Path $fixture 'target.psd1'), "@{ TargetOS='$os'; InstallationMode='Desktop' }")
    & {
        $recorded = [Collections.Generic.List[string]]::new()
        function New-Item { param($Path,[switch]$Force) $recorded.Add("key:$Path") }
        function New-ItemProperty { param($Path,$Name,$PropertyType,$Value,[switch]$Force) $recorded.Add("value:$Path/$Name=$Value") }
        function Test-Path { param($LiteralPath) if ($LiteralPath -like 'HK*:*') { return $true }; Microsoft.PowerShell.Management\Test-Path -LiteralPath $LiteralPath }
        & (Join-Path $fixture 'WindowsDefaults.ps1')
        $text = $recorded -join "`n"
        if ($os -eq 'Windows10' -and ($text -notmatch 'EnableFeeds=0' -or $text -match 'AllowNewsAndInterests')) { throw 'Windows-10-Feeds-Richtlinie falsch.' }
        if ($os -eq 'Windows11' -and ($text -notmatch 'AllowNewsAndInterests=0' -or $text -match 'EnableFeeds')) { throw 'Windows-11-Widgets-Richtlinie falsch.' }
        if ($os -like 'Server*' -and $recorded.Count -ne 0) { throw 'Client-Richtlinien auf Server ausgeführt.' }
        if ($text -match 'key:HKCU:') { throw 'Bestehender Benutzer-Registry-Schlüssel wird neu angelegt.' }
    }
}
Write-Host 'PASS: Architektur/Version und getrennte Client-/Server-Richtlinien ohne Registry-Änderungen.'
