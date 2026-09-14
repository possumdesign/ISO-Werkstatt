# Builder-Schnittstelle, Schema 1

Die spätere Oberfläche startet den vorhandenen Builder als eigenen Prozess. Sie implementiert keinen zweiten Build-Ablauf. Windows PowerShell 5.1 ist lokal getestet; ein kompletter Build mit echten Medien bleibt ein gesonderter Test.

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

## Statusdatei

Die JSON-Datei wird beim Start, bei jedem Schrittwechsel und zum Abschluss geschrieben. Aktualisierungen ersetzen die Datei atomisch. `SchemaVersion` ist `1`; unbekannte zusätzliche Felder dürfen Leser ignorieren.

Eine Oberfläche öffnet die Datei nur kurz und mit `FileShare.ReadWrite | FileShare.Delete`, damit sie das Ersetzen nicht blockiert.

| Feld | Bedeutung |
| --- | --- |
| `RunId` | GUID dieses Laufs |
| `Status` | `Running`, `Succeeded` oder `Failed` |
| `Step`, `TotalSteps`, `StepName` | Aktueller Schritt; 0 beim Start, danach 1 bis 10 |
| `Profile`, `Version`, `TargetOS`, `VirtioTarget`, `Edition` | Gewählte Konfiguration; noch nicht aufgelöste Werte können `null` sein |
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
| `Windows10` | `w10/amd64` | Noch nicht; eigene Antwortdatei und Installationstest fehlen |
| `Server2022` | `2k22/amd64` | Noch nicht; eigene Antwortdatei und Installationstest fehlen |
| `Server2025` | `2k25/amd64` | Noch nicht; eigene Antwortdatei und Installationstest fehlen |

Die Zuordnung betrifft die bereits eingebundenen vier Treiber. Ihre Dateien müssen in der angegebenen VirtIO-ISO tatsächlich vorhanden sein. Die neue Zielangabe macht die Windows-11-Antwortdatei nicht automatisch servergeeignet. Desktop Experience/Core und serverbezogene Anpassungen folgen bei der jeweiligen Erweiterung.

## FirstLogon ist ein eigener Testbereich

Ein erfolgreicher ISO-Build bestätigt nicht den Erfolg der Windows-Installation. In der VM liefern `C:\ISO-Werkstatt\firstlogon.log` und `firstlogon-result.json` die Ergebnisse der Anpassungen. Die JSON-Datei enthält SchemaVersion 1, Status, Start-/Endzeit und `Steps` mit `Name`, `Status` (`Succeeded`, `Failed`, `Skipped`) und `Errors`.

Fehler werden je Gruppe erfasst. Nach einem Fehler laufen die übrigen Gruppen weiter. Fehlende oder ungültige Anpassungskonfigurationen verhindern die Ausführung aller Gruppen. FirstLogon schreibt eine Abschlusszusammenfassung und wirft bei Fehlern eine Ausnahme. Das Ergebnis prüft die Skriptausführung, nicht etwa den späteren Download einer Edge-Erweiterung oder den Dienstzustand des separat installierten Guest Agent.
