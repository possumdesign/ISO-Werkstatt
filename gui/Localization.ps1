# Nur Oberflächentexte übersetzen; Profilwerte, Pfade, Editionsnamen und Logs bleiben unverändert.
$script:GuiEnglish = @{
    'Bearbeitet die Vorgaben für die erkannte ISO und Einsatzart. Zielsystem und Installationsvariante werden automatisch gewählt. Kennwort und Produktschlüssel werden nicht gespeichert.'='Edit defaults for the identified ISO and usage. Operating system and installation mode are selected automatically. Password and product key are not saved.'
    'Bitte zuerst eine Windows-ISO auswählen und erkennen lassen.'='Select a Windows ISO first and let the builder identify it.'
    'Core – Headless'='Core – Headless'
    'Edition aus der erkannten ISO auswählen.'='Select an edition from the identified ISO.'
    'Keine Desktop-Edition vorhanden. Für diese ISO Core – Headless auswählen.'='No desktop edition available. Select Core – Headless for this ISO.'
    'Bitte eine passende Edition aus der ISO auswählen.'='Select a matching edition from the ISO.'
    'Das gespeicherte Profil passt nicht zur erkannten ISO.'='The saved profile does not match the identified ISO.'
    'ISO-Werkstatt – Builder'='ISO-Crafter – Builder'
    'ISO-Werkstatt'='ISO-Crafter'
    'Windows-Installationsmedien für Labor und PC'='Windows installation media for lab and PC'
    'LOKALER BUILDER'='LOCAL BUILDER'
    'Build vorbereiten'='Prepare build'
    'Windows-ISO'='Windows ISO'; 'VirtIO-ISO'='VirtIO ISO'; 'Auswählen'='Browse'
    'Pfad zur Windows-Installations-ISO'='Path to the Windows installation ISO'
    'Pfad zur VirtIO-Treiber-ISO'='Path to the VirtIO driver ISO'
    'Profil'='Profile'; 'Edition'='Edition'; 'Version'='Version'
    'Profil bearbeiten'='Edit profile'; 'Profile bearbeiten'='Edit profiles'
    'Edition aus der ISO auswählen oder den exakten Namen eingeben.'='Select an edition from the ISO or enter its exact name.'
    'Editionen neu einlesen'='Refresh editions'
    'ISO auswählen oder Editionen lesen. Manuelle Eingabe bleibt möglich.'='Select an ISO or read its editions. Manual entry is also available.'
    'Windows-Produktschlüssel (optional)'='Windows product key (optional)'
    'Für Setup und Editionsauswahl; Aktivierung separat. Leer: Vorgabe der Antwortdatei, beim PC-Profil ohne festen Schlüssel.'='Used for setup and edition selection; activation is separate. Leave blank to use the answer file default. The PC profile has no fixed key.'
    'Zusätzliche Anpassungen'='Additional options'
    'Tools-Ordner und Desktop-Verknüpfung'='Tools folder and desktop shortcut'
    'Bing / Websuche abschalten'='Disable Bing / web search'
    'uBlock Origin Lite installieren'='Install uBlock Origin Lite'
    'QEMU Guest Agent installieren'='Install QEMU Guest Agent'
    'Gilt für diesen Build. Ein Profilwechsel setzt die Auswahl zurück.'='Applies to this build. Changing the profile resets these options.'
    'Lokaler Kontoname'='Local account name'; 'Kennwort für das lokale Konto'='Local account password'
    '1–20 Zeichen. Profilwechsel lädt den Standardnamen. Gilt auch für die automatische Anmeldung.'='1–20 characters. Changing the profile loads its default. Also used for automatic sign-in.'
    'Kennwort und optionaler Produktschlüssel werden in die Installations-ISO übernommen, nicht in Profil oder Build-Protokoll gespeichert.'='The password and optional product key are included in the installation ISO, but are not saved in profiles or build logs.'
    'ISO erstellen'='Create ISO'; 'Weitere ISO erstellen'='Create another ISO'; 'Build läuft …'='Building …'
    'Build-Status'='Build status'; 'Bereit für den ersten Build'='Ready to build'; 'Noch kein Lauf gestartet'='No build started yet'
    'Nach dem Build findest du hier die fertige ISO und ihre Prüfsumme.'='The finished ISO and its checksum will appear here.'
    'ISO anzeigen'='Show ISO'; 'SHA256 kopieren'='Copy SHA256'; 'Protokoll'='Log'; 'Der Build-Verlauf erscheint hier.'='Build output will appear here.'
    'Vollständiges Log öffnen'='Open full log'
    'Lokaler Builder für Windows 10/11 und Server 2022/2025. Neue Zielprofile zuerst testen.'='Local builder for Windows 10/11 and Server 2022/2025. Test new target profiles first.'
    'Benötigt für VirtIO-Treiber oder QEMU Guest Agent.'='Required for VirtIO drivers or QEMU Guest Agent.'
    'Für diese Auswahl nicht benötigt.'='Not required for these options.'
    'Build erfolgreich'='Build succeeded'; 'Build fehlgeschlagen'='Build failed'; 'Builder wird gestartet …'='Starting builder …'
    'Die einzelnen Schritte können unterschiedlich lange dauern.'='Build steps can take different amounts of time.'
    'Warte auf das Build-Protokoll …'='Waiting for build output …'
    'Editionen werden aus der ISO gelesen …'='Reading editions from the ISO …'
    'Windows-ISO auswählen'='Select Windows ISO'; 'VirtIO-ISO auswählen'='Select VirtIO ISO'; 'ISO-Dateien (*.iso)|*.iso'='ISO files (*.iso)|*.iso'
    'Die Zwischenablage ist gerade nicht verfügbar.'='The clipboard is currently unavailable.'
    'Build oder Editionsabfrage läuft noch. Bitte das Fenster bis zum Abschluss geöffnet lassen; Minimieren ist möglich.'='A build or edition query is still running. Keep this window open until it finishes; you can minimize it.'
    'Bitte ein gültiges Profil auswählen.'='Please select a valid profile.'
    'Bitte eine gültige Versionsbezeichnung eingeben.'='Please enter a valid version label.'
    'Bitte das Kennwort für das lokale Konto eingeben.'='Please enter the local account password.'
    'Dieses Zielsystem ist noch nicht für Builds freigegeben.'='This operating system is not yet enabled for builds.'
    'Dieses Zielsystem ist vorbereitet, aber noch nicht für Builds freigegeben.'='This operating system is prepared but not yet enabled for builds.'
    'Die Antwortdatei des Profils fehlt.'='The profile answer file is missing.'
    'Bitte eine Windows-ISO auswählen.'='Please select a Windows ISO.'
    'Bitte zuerst eine Windows-ISO auswählen.'='Please select a Windows ISO first.'
    'Bitte eine vorhandene Windows-ISO auswählen.'='Please select an existing Windows ISO.'
    'Für VirtIO-Treiber oder QEMU Guest Agent wird eine VirtIO-ISO benötigt.'='A VirtIO ISO is required for VirtIO drivers or QEMU Guest Agent.'
    'Der Build-Prozess konnte nicht gestartet werden.'='The build process could not be started.'
    'Die Statusdatei passt nicht zum aktuellen Build.'='The status file does not match this build.'
    'Die Statusdatei enthält ungültige Fortschrittsdaten.'='The status file contains invalid progress data.'
    'Die Editionsabfrage lieferte kein passendes Ergebnis.'='The edition query did not return a matching result.'
    'Die Editionsabfrage ist fehlgeschlagen.'='The edition query failed.'
    'Die Editionsliste ist leer oder ungültig.'='The edition list is empty or invalid.'
    'Editionsabfrage konnte nicht gestartet werden.'='The edition query could not be started.'
    'Im Ordner config wurde kein Profil gefunden.'='No profile was found in the config folder.'
    'Kontoname ungültig: 1–20 Zeichen, keine Windows-Sonderzeichen, keine äußeren Leerzeichen oder abschließenden Punkte.'='Invalid account name: use 1–20 characters, no Windows special characters, leading/trailing spaces or trailing periods.'
    'Dieser Kontoname ist für ein Windows-Konto oder eine Windows-Gruppe reserviert.'='This name is reserved for a Windows account or group.'
    'Der Produktschlüssel muss aus fünf Gruppen mit jeweils fünf Buchstaben/Ziffern bestehen.'='The product key must contain five groups of five letters or digits.'
    'Profilname'='Profile name'; 'Zielsystem'='Operating system'; 'Antwortdatei'='Answer file'; 'Tools-Verzeichnis'='Tools directory'
    'VirtIO-Treiber integrieren'='Integrate VirtIO drivers'; 'Explorer anpassen'='Customize Explorer'; 'Windows-Vorgaben anpassen'='Customize Windows defaults'; 'Edge anpassen'='Customize Edge'
    'Speichern'='Save'; 'Abbrechen'='Cancel'
    'Neuer Name speichert eine Kopie. Gleicher Name aktualisiert das geöffnete Profil. Kennwort und Produktschlüssel werden nicht gespeichert.'='A new name saves a copy. The same name updates this profile. Passwords and product keys are not saved.'
    'Pfade relativ zum Repository. Core: Desktop-Anpassungen ausschalten. Neue Zielsysteme zuerst testen.'='Paths are relative to the repository. Disable desktop options for Core. Test new operating systems first.'
    'Installationsvariante'='Installation mode'
    'Profilname ungültig. Erlaubt sind Buchstaben, Ziffern, Bindestriche und Unterstriche.'='Invalid profile name. Use letters, digits, hyphens and underscores.'
    'Der Zielname ist bereits vergeben. Bitte einen anderen Profilnamen wählen.'='That name already exists. Choose a different profile name.'
    'Das Profil wurde zwischenzeitlich geändert. Bitte den Editor erneut öffnen.'='The profile has changed since it was opened. Please reopen the editor.'
}
$script:GuiSteps = @('Start','Profil und Voraussetzungen prüfen','Windows-ISO vorbereiten','VirtIO-Komponenten extrahieren','Edition ermitteln und Treiber integrieren','Autounattend.xml erzeugen','OEM-Struktur vorbereiten','Skripte synchronisieren','Portable Tools synchronisieren','ISO erstellen','SHA256 und Ergebnis speichern')
$script:GuiStepsEn = @('Start','Check profile and prerequisites','Prepare Windows ISO','Extract VirtIO components','Find edition and integrate drivers','Create Autounattend.xml','Prepare OEM files','Copy scripts','Copy portable tools','Create ISO','Save SHA256 and results')
$script:GuiGerman=@{}
foreach($key in $script:GuiEnglish.Keys){$script:GuiGerman[$script:GuiEnglish[$key]]=$key}

function Convert-GuiText {
    param([AllowEmptyString()][string]$Text, [string]$Language='de')
    if (-not $Text) { return $Text }
    # Zuerst auf die deutsche Quellform zurückführen, damit Umschalten verlustfrei ist.
    if($script:GuiGerman.ContainsKey($Text)){$Text=$script:GuiGerman[$Text]}
    $Text=$Text -replace '^Elapsed: ','Laufzeit: ' -replace '^Step (\d+/\d+): ','Schritt $1: ' -replace ' GB · Finished ISO$',' GB · Fertige ISO'
    $Text=$Text -replace '^(\d+) editions found\. Check the selection before building\.$','$1 Editionen gefunden. Auswahl vor dem Build prüfen.'
    $Text=$Text -replace ' · with VirtIO drivers',' · mit VirtIO-Treibern' -replace ' · without VirtIO drivers',' · ohne VirtIO-Treiber' -replace ' · select the target partition manually',' · Zielpartition manuell wählen' -replace ' · installation test pending',' · Installationstest ausstehend'
    foreach ($pair in @(@('Could not read editions: ','Editionen konnten nicht gelesen werden: '),@('Please select an existing ISO file: ','Bitte eine vorhandene ISO-Datei auswählen: '),@('Status display: ','Statusanzeige: '))) {
        if ($Text.StartsWith($pair[0])) { $Text=$pair[1]+$Text.Substring($pair[0].Length) }
        if ($Text.StartsWith($pair[1])) {
            $prefix=if($Language -eq 'en'){$pair[0]}else{$pair[1]}
            return $prefix+(Convert-GuiText -Text $Text.Substring($pair[1].Length) -Language $Language)
        }
    }
    if ($Text -match '^Schritt (\d+)/(\d+): (.*)$') {
        $step=[int]$Matches[1]; $total=$Matches[2]; $label=$Matches[3]
        if($step -ge 0 -and $step -lt $script:GuiSteps.Count -and $label -in @($script:GuiSteps[$step],$script:GuiStepsEn[$step])){$label=if($Language -eq 'en'){$script:GuiStepsEn[$step]}else{$script:GuiSteps[$step]}}
        if($Language -eq 'en'){return "Step $step/${total}: $label"}; return "Schritt $step/${total}: $label"
    }
    if ($Language -ne 'en') { return $Text }
    if ($script:GuiEnglish.ContainsKey($Text)) { return $script:GuiEnglish[$Text] }
    $Text=$Text -replace '^Laufzeit: ','Elapsed: ' -replace ' GB · Fertige ISO$',' GB · Finished ISO'
    $Text=$Text -replace '^(\d+) Editionen gefunden\. Auswahl vor dem Build prüfen\.$','$1 editions found. Check the selection before building.'
    $Text=$Text -replace ' · mit VirtIO-Treibern',' · with VirtIO drivers' -replace ' · ohne VirtIO-Treiber',' · without VirtIO drivers' -replace ' · Zielpartition manuell wählen',' · select the target partition manually' -replace ' · Installationstest ausstehend',' · installation test pending'
    return $Text
}

function Get-GuiTextTargets {
    param($Node)
    if ($Node -isnot [Windows.DependencyObject]) { return }
    $properties=@('ToolTip')
    if($Node -is [Windows.Controls.TextBlock]){$properties+='Text'}
    if($Node -is [Windows.Controls.ContentControl] -and $Node.Content -is [string]){$properties+='Content'}
    if($Node -is [Windows.Controls.HeaderedContentControl]){$properties+='Header'}
    if($Node -is [Windows.Window]){$properties+='Title'}
    if($Node -is [Windows.Controls.TextBox] -and $Node.Name -in @('Result','LogPreview')){$properties+='Text'}
    foreach($property in $properties){if($Node.$property -is [string]){[pscustomobject]@{Node=$Node;Property=$property}}}
    foreach($child in [Windows.LogicalTreeHelper]::GetChildren($Node)){Get-GuiTextTargets -Node $child}
}

function Update-GuiLanguage {
    param($Ui)
    foreach($target in $Ui.TextTargets){
        if($target.Node.Name -eq 'LogPreview' -and $Ui.Run){continue}
        $property=$target.Property
        $value=Convert-GuiText -Text $target.Node.$property -Language $Ui.Language
        if($target.Node.$property -cne $value){$target.Node.$property=$value}
    }
}

function Set-GuiLanguage {
    param($Ui,[ValidateSet('de','en')][string]$Language)
    $Ui.Language=$Language
    $Ui.Controls.LanguageDE.IsEnabled=$Language -ne 'de'
    $Ui.Controls.LanguageEN.IsEnabled=$Language -ne 'en'
    Update-GuiLanguage -Ui $Ui
}
