param([string]$RepairScript=(Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts\Repair-DesktopIni.ps1'))
$ErrorActionPreference='Stop'
$root=Join-Path $env:TEMP ('ISO-Werkstatt-desktopini-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $root | Out-Null
$path=Join-Path $root 'desktop.ini'
[IO.File]::WriteAllText($path,"[.ShellClassInfo]`r`nLocalizedResourceName=@%SystemRoot%\system32\shell32.dll,-21787",[Text.Encoding]::Unicode)
$beforeHash=(Get-FileHash $path).Hash
[IO.File]::SetAttributes($path,([IO.FileAttributes]::Archive -bor [IO.FileAttributes]::ReadOnly))
$other=Join-Path $root 'other.txt';[IO.File]::WriteAllText($other,'untouched')
$otherAttributes=[IO.File]::GetAttributes($other)
& $RepairScript -Folders @($root,(Join-Path $root 'missing'),$root)
$expected=[IO.FileAttributes]::Hidden -bor [IO.FileAttributes]::System -bor [IO.FileAttributes]::Archive -bor [IO.FileAttributes]::ReadOnly
if([IO.File]::GetAttributes($path) -ne $expected -or (Get-FileHash $path).Hash -ne $beforeHash){throw 'Attribute oder Dateiinhalt fehlerhaft.'}
& $RepairScript -Folders @($root) | Out-Null
if([IO.File]::GetAttributes($path) -ne $expected -or [IO.File]::GetAttributes($other) -ne $otherAttributes){throw 'Wiederholung oder Abgrenzung fehlerhaft.'}
Write-Host 'PASS: Hidden/System ergänzt, Inhalt und übrige Attribute erhalten, keine anderen Dateien verändert.'
