$ErrorActionPreference = "Stop"

$Template = ".\answer\Autounattend.xml"
$Destination = ".\build\iso-root\Autounattend.xml"

if (-not $env:ISO_LAB_PASSWORD) {
    throw "Umgebungsvariable ISO_LAB_PASSWORD ist nicht gesetzt."
}

$Xml = Get-Content $Template -Raw

$Xml = $Xml.Replace(
    "__LAB_PASSWORD__",
    $env:ISO_LAB_PASSWORD
)

Set-Content `
    -Path $Destination `
    -Value $Xml `
    -Encoding UTF8

Write-Host "Autounattend.xml wurde erzeugt:"
Write-Host $Destination