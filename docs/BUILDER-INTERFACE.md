# Builder-Schnittstelle, Schema 1

Die WPF-Oberfläche startet den vorhandenen Builder als eigenen Prozess. Sie implementiert keinen zweiten Build-Ablauf. Windows PowerShell 5.1 ist lokal getestet; ein kompletter Build mit echten Medien bleibt ein gesonderter Test.

## Aufruf

```powershell
$runId = [guid]::NewGuid()
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build.ps1 `
    -WindowsIso "D:\ISO\Windows11.iso" `
    -VirtioIso "D:\ISO\virtio-win.iso" `
    -Profile "lab-config" `
    -Version "0.7.0" `
    -RunId $runId
```

Der Prozess benötigt Administratorrechte. Das Kennwort wird über die Prozessumgebung `ISO_LAB_PASSWORD` übergeben, nicht als Befehlszeilenparameter. Eine Oberfläche soll Argumente getrennt übergeben und keine aus Benutzereingaben zusammengesetzte PowerShell-Befehlszeichenfolge ausführen.

`RunId` ist optional; ohne Angabe erzeugt der Builder eine neue GUID. Die Oberfläche erzeugt pro Start eine neue GUID und kennt dadurch vorab diese beiden Pfade relativ zum Repository:

- `build/logs/build-<RunId>.log`: Konsolenprotokoll.
- `build/logs/build-<RunId>.json`: aktueller Status und abschließendes Ergebnis.

Eine bereits verwendete RunId wird abgewiesen. Die zugehörige Statusdatei wird nicht überschrieben. Frühe Fehler wie ungültige Parameter, eine fehlende Hilfsdatei oder ein nicht beschreibbarer Log-Ordner können auftreten, bevor eine Statusdatei existiert; deshalb auch Prozessende und Fehlerausgabe auswerten.

## Laufoptionen und Produktschlüssel

`Tools`, `WebSearch`, `UBlockLite` und `QemuGuestAgent` sind optionale Parameter mit `Profile` (Standard), `On` oder `Off`. `WebSearch=On` bedeutet: bestehendes Search-Skript ausführen, um Bing-/Websuche abzuschalten. GUI-Checkboxen werden als explizites On/Off übergeben. `IncludeVirtioDrivers` bleibt ein Boolean im Profil. Gemeinsame Profilvalidierung und Vorgaben liegen in `Resolve-BuildProfile`.

`VirtioIso` ist nur erforderlich, wenn VirtIO-Treiber oder QEMU aktiv sind. Ohne beide Komponenten wird weder der VirtIO-Pfad geprüft noch die ISO geöffnet. Die Windows-ISO wird weiterhin eingehängt; die Edition wird auch ohne Treiberintegration aus install.wim oder install.esd ermittelt.

`ISO_PRODUCT_KEY` enthält optional den Setup-Produktschlüssel. Kein entsprechender Befehlszeilenparameter. Die GUI setzt ihn nur in der Kindprozessumgebung und entfernt eine geerbte Vorgabe, wenn ihr Feld leer ist. Der Builder validiert das Format vor Medienarbeiten und schreibt ihn nur in die erzeugte Antwortdatei. Leere Werte lassen die Vorlage unverändert. Siehe README für Editions-/Aktivierungsverhalten und OEM-Einschränkungen von SetupComplete.

## Statusdatei

Die JSON-Datei wird beim Start, bei jedem Schrittwechsel und zum Abschluss geschrieben. Aktualisierungen ersetzen die Datei atomisch. `SchemaVersion` ist `1`; unbekannte zusätzliche Felder dürfen Leser ignorieren.

Eine Oberfläche öffnet die Datei nur kurz und mit `FileShare.ReadWrite | FileShare.Delete`, damit sie das Ersetzen nicht blockiert.

| Feld | Bedeutung |
| --- | --- |
| `RunId` | GUID dieses Laufs |
| `Status` | `Running`, `Succeeded` oder `Failed` |
| `Step`, `TotalSteps`, `StepName` | Aktueller Schritt; 0 beim Start, danach 1 bis 10 |
| `Profile`, `Version`, `TargetOS`, `VirtioTarget`, `Edition` | Gewählte Konfiguration; noch nicht aufgelöste Werte können `null` sein |
| `IncludeVirtioDrivers`, `QemuGuestAgent` | Aufgelöste Boolean-Optionen nach erfolgreicher Profilvalidierung |
| `Adjustments` | Aufgelöste Booleans Search, Explorer, WindowsDefaults, Edge, UBlockLite und Tools |
| `ProductKeyProvided` | Nur Boolean, ob für diesen Lauf ein Setup-Schlüssel übergeben wurde; niemals der Wert |
| `StartedAt`, `UpdatedAt`, `CompletedAt` | UTC-Zeitpunkte im ISO-8601-Format; Abschluss zunächst `null` |
| `DurationSeconds` | Gesamtdauer bei Abschluss, vorher `null` |
| `LogPath` | Absoluter Pfad zum Protokoll |
| `IsoPath`, `IsoSizeBytes`, `Sha256`, `HashFile` | Ergebnisdaten ausschließlich bei Erfolg, sonst `null` |
| `Error` | Fehlermeldung bei regulär behandeltem Build-Fehler, sonst `null` |

Die zehn Schritte haben unterschiedliche Laufzeiten. `Step / TotalSteps` ist daher kein zeitgenauer Prozentfortschritt. Innerhalb eines langen Kopier- oder DISM-Schritts muss sich die Statusdatei nicht ändern; dies ist allein kein Anzeichen für einen hängenden Prozess.

Bei Start mit `powershell.exe -File` bedeutet Exitcode 0 erfolgreicher Skriptabschluss; ein unbehandelter Fehler führt zu Exitcode 1. Die Oberfläche meldet Erfolg erst nach Prozessende mit Exitcode 0 **und** `Status = Succeeded` für die passende RunId. Bei fehlender/ungültiger JSON-Datei, einem anderen Exitcode oder verbleibendem `Running` liegt kein bestätigter Erfolg vor.

Ein hart beendeter Prozess kann keinen Endstatus schreiben. Die Datei kann dann `Running` behalten. Automatisches Fortsetzen oder erzwungenes Beenden während DISM ist noch nicht implementiert.

## Sperre und Ergebnisse

`build/build.lock` wird mit exklusivem Dateizugriff gehalten. Ein zweiter Build desselben Arbeitsverzeichnisses bricht ab, bevor er ISO-Arbeitsdateien verändert. Die Datei bleibt nach Abschluss liegen; ihre Existenz allein bedeutet keine aktive Sperre. Windows gibt den Dateihandle auch nach einem Prozessabbruch frei. Getrennte Repository-Kopien sind davon nicht erfasst.

ISO und SHA256-Datei heißen weiterhin `ISO-Werkstatt-<Profile>-v<Version>.iso` und `.iso.sha256`. Gleiche Profil-/Versionskombinationen verwenden denselben Zielnamen. Ein früherer Erfolgsdatensatz ist deshalb eine historische Aufzeichnung, kein Beweis für den aktuellen Inhalt dieser Datei; bei Bedarf den Hash erneut prüfen.

## Zielsysteme

`TargetOS` ist ein optionaler Profilwert. Fehlende Angaben entsprechen `Windows11`.

| TargetOS | VirtIO-Unterordner | Build-Freigabe |
| --- | --- | --- |
| `Windows11` | `w11/amd64` | Ja |
| `Windows10` | `w10/amd64` | Ja; echte Installation noch zu testen |
| `Server2022` | `2k22/amd64` | Ja; echte Installation noch zu testen |
| `Server2025` | `2k25/amd64` | Ja; echte Installation noch zu testen |

Die Zuordnung betrifft die bereits eingebundenen vier Treiber. Ihre Dateien müssen in der angegebenen VirtIO-ISO tatsächlich vorhanden sein. Die mitgelieferten Serverprofile verwenden eigene Antwortdateien mit AdministratorPassword. InstallationMode ist Desktop (Standard) oder Core; Core ist ausschließlich für Server zulässig. WindowsDefaults ist bei Server gesperrt, Core sperrt zusätzlich Search, Explorer, Edge und UBlockLite.

## FirstLogon ist ein eigener Testbereich

Ein erfolgreicher ISO-Build bestätigt nicht den Erfolg der Windows-Installation. In der VM liefern `C:\ISO-Werkstatt\firstlogon.log` und `firstlogon-result.json` die Ergebnisse der Anpassungen. Die JSON-Datei enthält SchemaVersion 1, Status, Start-/Endzeit und `Steps` mit `Name`, `Status` (`Succeeded`, `Failed`, `Skipped`) und `Errors`.

Fehler werden je Gruppe erfasst. Nach einem Fehler laufen die übrigen Gruppen weiter. Fehlende oder ungültige Anpassungskonfigurationen verhindern die Ausführung aller Gruppen. FirstLogon schreibt eine Abschlusszusammenfassung und wirft bei Fehlern eine Ausnahme. Das Ergebnis prüft die Skriptausführung, nicht etwa den späteren Download einer Edge-Erweiterung oder den Dienstzustand des separat installierten Guest Agent.

## Lokales Konto

`LocalUserName` ist ein optionaler Profilwert und CLI-Parameter. Ein expliziter Parameter hat Vorrang. Die GUI übergibt den Feldinhalt als separat maskiertes Prozessargument. Die gemeinsame Validierung lehnt leere/ungültige Namen vor den ISO-Arbeiten ab. Der aufgelöste Name steht als zusätzliches `LocalUserName`-Feld im Schema-1-Status. Konto, Anzeigename und AutoLogon werden gemeinsam über XML-Knoten gesetzt; Kennwörter werden nicht per Textersetzung umbenannt.

## Editionsabfrage

`gui/Read-Editions.ps1` nimmt `WindowsIso`, `ResultPath` und `RunId` entgegen. Der Aufrufer reserviert einen eigenen TEMP-Ordner; der Worker legt dort die Ergebnisdatei exklusiv an. JSON enthält RunId, WindowsIso, Status (Succeeded/Failed), Editions (Index/Name/TargetOS/InstallationMode) und Error. Erfolg erfordert Exitcode 0 und passende Zuordnung. Die GUI entfernt das temporäre Ergebnis nach der Auswertung. Kennwort und Produktschlüssel werden dem Abfrageprozess nicht vererbt.

`Get-BuildIsoEditions` verwendet dieselbe exklusive `build/build.lock` wie ein Build und die bestehenden ISO-Hilfsfunktionen. Es liest nur Metadaten von install.wim oder install.esd, ohne WIM-Mount oder Treiberintegration. Fehler und Cleanup geben die Sperre im finally frei. Windows-Storage-Zeitlimits bleiben wirksam; für die DISM-Metadatenabfrage selbst gibt es keinen separaten Abbruchknopf.

## GUI-Sprache und Profilspeicherung

`gui/Localization.ps1` übersetzt ausschließlich Oberflächentexte. Ein eigener UI-Timer aktualisiert dynamische Anzeigen in der gewählten Sitzungssprache. Eingabefelder, Profil-/Editionswerte und Originallogs werden nicht übersetzt; die Builder-Schnittstelle und Statuswerte bleiben unverändert.

`gui/ProfileEditor.ps1` lädt Profile über die gemeinsame Validierung. Beim Öffnen wird ein Dateihash erfasst. Speichern serialisiert ausschließlich die bekannten, validierten Werte in PSD1-Syntax mit korrekt maskierten Zeichenfolgen. Ein vorhandenes Original wird atomar ersetzt und vorher erneut auf Änderungen geprüft; neue Namen werden ohne Überschreiben angelegt. Unbekannte Schlüssel werden abgewiesen. Der Editor verändert keine laufenden Builds und speichert keine Geheimnisse.

## Zusätzliche Zielsystem-Metadaten

Schema 1 enthält zusätzlich `InstallationMode`, `InstallationTested` sowie nach der Abbildprüfung `ImageVersion` und `ImageInstallationType`. `InstallationTested` beschreibt den bekannten Teststand des Zielsystems, nicht den Erfolg der aktuellen Installation. Neue Zielsysteme haben hier `false`.

Der Builder prüft x64, Client/Server, Versionsfamilie und Desktop/Core vor WIM-Mounts. Server 2022 verlangt Build 20348, Server 2025 Build 26100. Eine ESD wird nach erfolgreicher Prüfung mit der ausgewählten Edition nach install.wim exportiert; der neue Index wird in der Antwortdatei verwendet. Nur die Arbeitskopie der ESD wird nach erfolgreichem Export entfernt.

`scripts/target.psd1` im Zielsystem enthält TargetOS und InstallationMode. FirstLogon überspringt auf Core alle Desktop-Schritte einschließlich Tools-Verknüpfung und Explorer-Start. Ohne diese Datei gilt für ältere Installationen weiterhin Desktop. Details zu Profilen und Installationstests: [MULTI-OS.md](MULTI-OS.md).
Die GUI zeigt ausschließlich PC-Lokal und Proxmox VM. MediaSelection.ps1 ordnet nach erfolgreicher ISO-Erkennung ein internes Profil zu; Core ist eine separate, standardmäßig ausgeschaltete Auswahl. DISM-Detailmetadaten jedes Index bestimmen TargetOS und InstallationMode. Ein ISO-Wechsel verwirft die Erkennung, ein Build benötigt eine passende Edition und aktuelle Profilzuordnung. Die CLI-Profilnamen bleiben unverändert.
