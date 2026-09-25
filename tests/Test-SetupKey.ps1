param([string]$SourceRoot=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
. (Join-Path $SourceRoot 'BuildSupport.ps1')
$root=Join-Path $env:TEMP ('ISO-Werkstatt-key-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory (Join-Path $root 'sources') | Out-Null
$path=Join-Path $root 'sources\product.ini'
$xml=Get-Content (Join-Path $SourceRoot 'answer\Autounattend-Windows10-vm.xml') -Raw
$fixture="[cmi]`r`nProfessional=AAAAA-BBBBB-CCCCC-DDDDD-EEEEE`r`nProfessionalN=FFFFF-GGGGG-HHHHH-IIIII-JJJJJ`r`n[Other]`r`nProfessional=KKKKK-LLLLL-MMMMM-NNNNN-OOOOO"
Set-Content $path $fixture
foreach($id in @('Professional','ProfessionalN')){
    $expected=if($id -eq 'Professional'){'AAAAA-BBBBB-CCCCC-DDDDD-EEEEE'}else{'FFFFF-GGGGG-HHHHH-IIIII-JJJJJ'}
    $key=Get-Windows10SetupKey -Xml $xml -EditionId $id -MediaRoot $root
    if($key -cne $expected){throw 'Falsche Edition oder INI-Sektion ausgewählt.'}
    [xml]$answer=Set-SetupProductKey -Xml $xml -ProductKey $key
    $ns=[Xml.XmlNamespaceManager]::new($answer.NameTable);$ns.AddNamespace('u','urn:schemas-microsoft-com:unattend')
    if($answer.SelectSingleNode('//u:UserData/u:ProductKey/u:Key',$ns).InnerText -ne $expected){throw 'Setup-Key nicht in XML übernommen.'}
}
$explicit='PPPPP-QQQQQ-RRRRR-SSSSS-TTTTT'
if((Get-Windows10SetupKey -Xml $xml -ProductKey $explicit -MediaRoot $root) -ne $explicit){throw 'Benutzerschlüssel überschrieben.'}
$custom=Set-SetupProductKey -Xml $xml -ProductKey $explicit
if((Get-Windows10SetupKey -Xml $custom -MediaRoot $root) -ne ''){throw 'Vorlagenschlüssel überschrieben.'}
foreach($contents in @($fixture,"[cmi]`nProfessional=invalid","[cmi]`nProfessional=$explicit`nProfessional=$explicit",'')){
    Set-Content $path $contents
    $id=if($contents -eq $fixture){'Core'}else{'Professional'}
    $failed=$false;try{Get-Windows10SetupKey -Xml $xml -EditionId $id -MediaRoot $root | Out-Null}catch{$failed=$true}
    if(-not $failed){throw 'Fehlender, ungültiger oder doppelter Schlüssel akzeptiert.'}
}
Write-Host 'PASS: Editionsgenaue Setup-Keys, Eingabe-/Vorlagenvorrang und fehlende/ungültige Zuordnungen.'
