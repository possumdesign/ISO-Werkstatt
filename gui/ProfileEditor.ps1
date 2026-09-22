function Get-EditableGuiProfile {
    param([string]$Root,[string]$Name)
    if($Name -notmatch '^[A-Za-z0-9][A-Za-z0-9_-]*$'){throw 'Profilname ungültig. Erlaubt sind Buchstaben, Ziffern, Bindestriche und Unterstriche.'}
    $path=Join-Path $Root "config\$Name.psd1"
    $code=[IO.File]::ReadAllBytes($path)
    $sha=[Security.Cryptography.SHA256]::Create()
    try{$hash=[BitConverter]::ToString($sha.ComputeHash($code)).Replace('-','')}finally{$sha.Dispose()}
    # Hash vor/nach Import schützt auch Änderungen während des Einlesens.
    $data=Import-PowerShellDataFile -LiteralPath $path -ErrorAction Stop
    if((Get-FileHash -LiteralPath $path).Hash -ne $hash){throw 'Das Profil wurde zwischenzeitlich geändert. Bitte den Editor erneut öffnen.'}
    [pscustomobject]@{Name=$Name;Hash=$hash;Data=(Resolve-BuildProfile -Data $data)}
}

function Save-GuiProfile {
    param([string]$Root,[string]$Name,[Collections.IDictionary]$Data,[string]$OriginalName,[string]$OriginalHash)
    if($Name -notmatch '^[A-Za-z0-9][A-Za-z0-9_-]*$' -or $Name -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$'){
        throw 'Profilname ungültig. Erlaubt sind Buchstaben, Ziffern, Bindestriche und Unterstriche.'
    }
    $profile=Resolve-BuildProfile -Data $Data
    $flags=@{Search=$profile.Adjustments.Search;Explorer=$profile.Adjustments.Explorer;WindowsDefaults=$profile.Adjustments.WindowsDefaults;Edge=$profile.Adjustments.Edge;UBlockLite=$profile.Features.UBlockLite}
    Assert-BuildTargetOptions -TargetOS $profile.TargetOS -InstallationMode $profile.InstallationMode -Adjustments $flags
    if(-not [IO.File]::Exists((Join-Path $Root $profile.AnswerTemplate))){throw 'Die Antwortdatei des Profils fehlt.'}
    $path=Join-Path $Root "config\$Name.psd1"
    $overwrite=$Name -ieq $OriginalName
    if($overwrite){
        if(-not $OriginalHash -or -not [IO.File]::Exists($path) -or (Get-FileHash -LiteralPath $path).Hash -ne $OriginalHash){throw 'Das Profil wurde zwischenzeitlich geändert. Bitte den Editor erneut öffnen.'}
    }elseif([IO.File]::Exists($path)){throw 'Der Zielname ist bereits vergeben. Bitte einen anderen Profilnamen wählen.'}
    $lines=@('@{')
    foreach($key in @('TargetOS','InstallationMode','Edition','AnswerTemplate','ToolsDirectory','LocalUserName')){
        $value=([string]$profile.$key).Replace("'","''")
        $lines+="    $key = '$value'"
    }
    $boolean=if($profile.IncludeVirtioDrivers){'$true'}else{'$false'}
    $lines+="    IncludeVirtioDrivers = $boolean"
    foreach($group in @('Adjustments','Features')){
        $lines+="    $group = @{"
        foreach($key in $profile.$group.Keys){$boolean=if($profile.$group[$key]){'$true'}else{'$false'};$lines+="        $key = $boolean"}
        $lines+='    }'
    }
    $lines+='}'
    $temporary=Join-Path (Split-Path $path -Parent) ('.profile-'+[guid]::NewGuid().ToString('N')+'.tmp')
    try{
        [IO.File]::WriteAllText($temporary,($lines -join "`r`n")+"`r`n",[Text.UTF8Encoding]::new($true))
        # Neue Namen niemals überschreiben. Bestehende Profile atomar ersetzen.
        if($overwrite){
            if((Get-FileHash -LiteralPath $path).Hash -ne $OriginalHash){throw 'Das Profil wurde zwischenzeitlich geändert. Bitte den Editor erneut öffnen.'}
            [IO.File]::Replace($temporary,$path,[NullString]::Value)
        }else{[IO.File]::Move($temporary,$path)}
    }finally{if([IO.File]::Exists($temporary)){[IO.File]::Delete($temporary)}}
    if($overwrite){return $OriginalName}
    return $Name
}

function New-GuiProfileEditor {
    param($Ui)
    $original=Get-EditableGuiProfile -Root $Ui.Root -Name $Ui.EffectiveProfile
    $reader=[Xml.XmlReader]::Create([IO.StringReader]::new([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'ProfileEditor.xaml'))))
    try{$window=[Windows.Markup.XamlReader]::Load($reader)}finally{$reader.Dispose()}
    $editor=@{Window=$window;Root=$Ui.Root;Original=$original;Controls=@{};Language=$Ui.Language;Run=$null;SavedName=$null}
    foreach($name in @('ProfileName','TargetOS','InstallationMode','Edition','LocalUserName','AnswerTemplate','ToolsDirectory','IncludeVirtioDrivers','Search','Explorer','WindowsDefaults','Edge','Tools','UBlockLite','QemuGuestAgent','Save','Cancel','Error')){$editor.Controls[$name]=$window.FindName($name)}
    $editor.Controls.ProfileName.Text=$original.Name
    foreach($key in @('Edition','LocalUserName','AnswerTemplate','ToolsDirectory')){$editor.Controls[$key].Text=$original.Data.$key}
    foreach($target in @('Windows11','Windows10','Server2022','Server2025')){[void]$editor.Controls.TargetOS.Items.Add($target)}
    $editor.Controls.TargetOS.SelectedItem=$original.Data.TargetOS
    foreach($mode in @('Desktop','Core')){[void]$editor.Controls.InstallationMode.Items.Add($mode)}
    $editor.Controls.InstallationMode.SelectedItem=$original.Data.InstallationMode
    $editor.Controls.IncludeVirtioDrivers.IsChecked=$original.Data.IncludeVirtioDrivers
    foreach($group in @('Adjustments','Features')){foreach($key in $original.Data.$group.Keys){$editor.Controls[$key].IsChecked=$original.Data.$group[$key]}}
    # Die ISO bestimmt diese Werte; der Editor bearbeitet die passende interne Vorlage.
    foreach($key in @('ProfileName','TargetOS','InstallationMode','AnswerTemplate','Edition')){$editor.Controls[$key].IsEnabled=$false}
    $editor.TextTargets=@(Get-GuiTextTargets -Node $window)
    Update-GuiLanguage -Ui $editor
    $editor.Controls.Save.Add_Click({Save-BuilderProfileEditor -Editor $editor}.GetNewClosure())
    $editor.Controls.Cancel.Add_Click({$editor.Window.Close()}.GetNewClosure())
    return $editor
}

function Save-BuilderProfileEditor {
    param($Editor)
    try{
        $data=@{TargetOS=[string]$Editor.Controls.TargetOS.SelectedItem;InstallationMode=[string]$Editor.Controls.InstallationMode.SelectedItem;IncludeVirtioDrivers=[bool]$Editor.Controls.IncludeVirtioDrivers.IsChecked;Adjustments=@{};Features=@{}}
        foreach($key in @('Edition','LocalUserName','AnswerTemplate','ToolsDirectory')){$data[$key]=$Editor.Controls[$key].Text}
        foreach($key in @('Search','Explorer','WindowsDefaults','Edge')){$data.Adjustments[$key]=[bool]$Editor.Controls[$key].IsChecked}
        foreach($key in @('Tools','UBlockLite','QemuGuestAgent')){$data.Features[$key]=[bool]$Editor.Controls[$key].IsChecked}
        $Editor.SavedName=Save-GuiProfile -Root $Editor.Root -Name $Editor.Controls.ProfileName.Text -Data $data -OriginalName $Editor.Original.Name -OriginalHash $Editor.Original.Hash
        $Editor.Window.Close()
    }catch{$Editor.Controls.Error.Text=Convert-GuiText -Text $_.Exception.Message -Language $Editor.Language}
}

function Show-BuilderProfileEditor {
    param($Ui)
    if($Ui.Active -or $Ui.EditionRun -or -not $Ui.EffectiveProfile){return}
    try{
        $editor=New-GuiProfileEditor -Ui $Ui
        $editor.Window.Owner=$Ui.Window
        [void]$editor.Window.ShowDialog()
        if($editor.SavedName){
            Update-GuiProfile -Ui $Ui
        }
    }catch{$Ui.Controls.Validation.Text=Convert-GuiText -Text $_.Exception.Message -Language $Ui.Language}
}
