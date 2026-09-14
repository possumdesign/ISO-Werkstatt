# ISO-Werkstatt

Builder für eine angepasste Windows-11-VM-ISO für die Labor-/Proxmox-Umgebung. Das Standardprofil ist auf Windows 11 Pro x64 mit deutscher Oberfläche und Tastatur ausgelegt.

## Aktueller Stand: v0.7 – Robustheit und Build-Profile

- Vollautomatischer Build aus einer Windows-ISO und einer VirtIO-ISO.
- Unbeaufsichtigtes Setup mit UEFI/GPT, lokalem Administrator `LabAdmin` und einmaliger automatischer Anmeldung.
- VirtIO-Treiber: `vioscsi` und `NetKVM` in `boot.wim` (Index 2); zusätzlich `Balloon` und `vioserial` in der gewählten Edition von `install.wim`.
- QEMU Guest Agent wird über `SetupComplete.cmd` installiert.
- Windows-Anpassungen beim ersten Anmelden: Websuche reduzieren, Dateiendungen und versteckte Dateien anzeigen, Explorer mit „Dieser PC“ öffnen, Widgets und Werbe-/Consumer-Inhalte reduzieren sowie Edge konfigurieren.
- Edge erhält eine Richtlinie zur automatischen Installation von uBlock Origin Lite aus dem Edge-Store; die Erweiterung wird nicht offline in die ISO eingebettet.
- Optionale portable Tools werden kopiert; ZIP-Dateien werden jeweils in einen eigenen Unterordner entpackt. Beim ersten Anmelden entsteht auf dem Desktop des angemeldeten Benutzers eine Verknüpfung namens „Tools“ zu C:\ISO-Werkstatt\Tools. Sie wird unabhängig von den vier Anpassungsschaltern angelegt, sofern der Ordner vorhanden ist; das Ergebnis steht im FirstLogon-Log.
- Syntaxprüfung der eingebundenen PowerShell-Skripte, XML-/Platzhalterprüfung, gezieltes Cleanup alter WIM-Mounts, Build-Protokoll, SHA256-Prüfsumme und JSON-Status/Ergebnis pro Lauf.
- Build-Profile für Zielsystem, Edition, Antwortdatei, Tools-Ordner und vier einzeln schaltbare Windows-Anpassungsgruppen. Windows 11 ist freigegeben; Windows 10 und Server 2022/2025 sind als Zuordnung vorbereitet, aber noch gesperrt.
- Exklusive Build-Sperre, einheitliche Schritte 1–10 und FirstLogon-Abschlussbericht.

## Voraussetzungen

- Windows-Build-Rechner mit PowerShell und den DISM-/DiskImage-Cmdlets; PowerShell als Administrator starten.
- Windows ADK mit Deployment Tools. Der Builder erwartet `oscdimg.exe` unter:

  ```text
  C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe
  ```

- Windows-Installations-ISO mit `sources\install.wim`, `sources\boot.wim` und der gewünschten Edition. Eine ISO mit ausschließlich `install.esd` wird derzeit nicht unterstützt.
- VirtIO-ISO mit den Windows-11-amd64-Treibern für `vioscsi`, `NetKVM`, `Balloon`, `vioserial` und `guest-agent\qemu-ga-x86_64.msi`.
- Ausreichend freier Speicher für entpackte Installationsdateien, WIM-Mounts und fertige ISO.

Die Standard-Antwortdatei löscht während der Windows-Installation Datenträger 0 und partitioniert ihn neu. Sie ist für die vorgesehene Labor-VM bestimmt. Das Kennwort wird in die erzeugte Antwortdatei und damit in die ISO geschrieben; Build-Artefakte entsprechend behandeln.

## Build starten

Im Repository-Verzeichnis in einer administrativen PowerShell ausführen. Die ISO-Pfade im Beispiel durch die eigenen Pfade ersetzen:

```powershell
$env:ISO_LAB_PASSWORD = Read-Host "Kennwort für LabAdmin"

.\build.ps1 `
    -WindowsIso "D:\ISO\Windows11.iso" `
    -VirtioIso "D:\ISO\virtio-win.iso" `
    -Version "0.7.0"
```

`Read-Host` in diesem Beispiel zeigt die Eingabe sichtbar an. Der Builder maskiert XML-Sonderzeichen wie `&`, `<`, `>` und Anführungszeichen automatisch. Das Kennwort bleibt nach dem Einlesen der XML unverändert; in XML 1.0 unzulässige Zeichen werden abgewiesen.

| Parameter | Bedeutung | Standard |
| --- | --- | --- |
| `-WindowsIso` | Pfad zur Windows-ISO | Pflichtangabe |
| `-VirtioIso` | Pfad zur VirtIO-ISO | Pflichtangabe |
| `-Profile` | Dateiname unter `config/`, ohne `.psd1` | `lab-config` |
| `-Edition` | Überschreibt die Edition aus dem Profil | Profilwert |
| `-Version` | Versionsbezeichnung für Ausgabe und Dateiname | `0.7.0` |
| `-RunId` | Eindeutige GUID zur Zuordnung von Log und JSON-Status | Automatisch neu erzeugt |

Der Versionsstandard ist jetzt `0.7.0`; der bisherige Aufruf bleibt gültig. Mit `-Version` lässt sich der Wert überschreiben. Die Versionsbezeichnung beginnt mit einem Buchstaben oder einer Ziffer und darf danach auch Punkte, Unterstriche und Bindestriche enthalten.

## Build-Profile

Das Standardprofil `config/lab-config.psd1` enthält die bisherigen Einstellungen:

```powershell
@{
    TargetOS       = "Windows11"
    Edition        = "Windows 11 Pro"
    AnswerTemplate = "answer\Autounattend.xml"
    ToolsDirectory = "tools"
}
```

Die Pfade beziehen sich auf das Repository. Edition, AnswerTemplate und ToolsDirectory sind erforderlich und müssen nicht leere Zeichenfolgen sein. Unbekannte Schlüssel und fehlende Profile führen vor den ISO-Arbeiten zum Abbruch.

Für ein weiteres Profil die Datei beispielsweise nach `config/test.psd1` kopieren, die Werte anpassen und beim Build zusätzlich `-Profile test` angeben. Profilnamen beginnen mit einem Buchstaben oder einer Ziffer und dürfen anschließend auch Bindestriche und Unterstriche enthalten. Ein ausdrücklich übergebenes `-Edition` hat Vorrang vor dem Profilwert.

Die optionale Angabe `TargetOS` bestimmt den VirtIO-Unterordner; ohne Angabe gilt `Windows11`. Weitere Zielsysteme sind noch nicht für Builds freigegeben. Zusätzliche Dienste werden hier nicht gesteuert. Kennwörter gehören nicht ins Profil; dafür wird weiterhin `ISO_LAB_PASSWORD` verwendet.

### Windows-Anpassungen auswählen

Im Profil kann zusätzlich die Hashtable `Adjustments` stehen:

```powershell
Adjustments = @{
    Search          = $true
    Explorer        = $true
    WindowsDefaults = $true
    Edge            = $false
}
```

Dieses Beispiel führt alle bisherigen Anpassungen außer Edge aus. `Edge = $false` überspringt auch die uBlock-Origin-Lite-Richtlinie. `Explorer = $false` überspringt die Explorer-Einstellungen und das abschließende Öffnen von „Dieser PC“.

Der gesamte Abschnitt ist optional; fehlende Schalter gelten als `$true`, sodass bestehende Profile unverändert weiterarbeiten. Werte müssen echte PowerShell-Booleans (`$true` oder `$false`) sein, keine Zeichenfolgen. Unbekannte Namen oder falsche Typen führen vor den ISO-Arbeiten zum Abbruch.

Der Builder schreibt die vier aufgelösten Schalter nach `C:\ISO-Werkstatt\scripts\adjustments.psd1` in der VM. FirstLogon prüft diese Datei und protokolliert ausgeführte sowie übersprungene Gruppen. Fehlt die Datei oder ist sie ungültig, bricht FirstLogon mit einer Fehlermeldung im Log ab. Deaktivieren bedeutet, eine Anpassung bei dieser Installation auszulassen; bereits gesetzte Einstellungen werden dadurch nicht zurückgenommen.

## Ablauf und Ergebnisse

1. Protokoll und Statusdatei anlegen, Build sperren, Profil/Voraussetzungen und Skriptsyntax prüfen.
2. Windows-ISO nach build/iso-root kopieren.
3. VirtIO-Komponenten extrahieren.
4. Edition ermitteln, alte WIM-Mounts gezielt bereinigen und Treiber integrieren.
5. Autounattend.xml erzeugen und prüfen.
6. OEM-Struktur und Guest-Agent-Paket vorbereiten.
7. Skripte und Anpassungsschalter übernehmen.
8. Portable Tools übernehmen.
9. ISO mit oscdimg erstellen.
10. SHA256 und Ergebnis speichern.
Für das Standardprofil mit `-Version "0.7.0"` entstehen:

```text
build/
  ISO-Werkstatt-lab-config-v0.7.0.iso
  ISO-Werkstatt-lab-config-v0.7.0.iso.sha256
  logs/
    build-<RunId>.log
    build-<RunId>.json
```

Die Prüfsummendatei enthält `SHA256 *ISO-Dateiname`. Zum manuellen Gegenprüfen:

```powershell
Get-FileHash -LiteralPath ".\build\ISO-Werkstatt-lab-config-v0.7.0.iso" -Algorithm SHA256
Get-Content -LiteralPath ".\build\ISO-Werkstatt-lab-config-v0.7.0.iso.sha256"
```

Jeder Lauf erhält ein eigenes Transcript. Bei abgefangenen Fehlern wird die Fehlermeldung vor dem Abschluss des Logs ausgegeben und der Fehler weitergereicht. Ein hart beendeter Prozess kann das Log nicht regulär abschließen.

Verschiedene Profile erhalten verschiedene ISO-Dateinamen. Für dasselbe Profil und dieselbe Version bleibt der Zielname identisch. Die Arbeitsverzeichnisse werden gemeinsam verwendet: Ein zweiter Build desselben Repository-Verzeichnisses wird durch eine Dateisperre abgewiesen. Die Datei build/build.lock bleibt liegen; nur ein geöffneter Dateihandle bedeutet eine aktive Sperre. Bestehende ISOs mit dem früheren Namen werden nicht automatisch umbenannt oder entfernt.

## Protokolle in der installierten VM

Unter `C:\ISO-Werkstatt\` liegen:

- `setup.log`: Ausführung von SetupComplete und Guest-Agent-Exitcode.
- `qemu-ga-install.log`: MSI-Installationsprotokoll des QEMU Guest Agent.
- `firstlogon.log`: Windows-Anpassungen mit Abschlusszusammenfassung. Fehlerhafte Gruppen verhindern nicht die Ausführung der übrigen Gruppen.
- `firstlogon-result.json`: Erfolg, Fehler und übersprungene Schritte beim ersten Anmelden.
- `Tools\`: die übernommenen portablen Werkzeuge.

## Repository-Struktur

| Pfad | Inhalt |
| --- | --- |
| `build.ps1` | Build-Ablauf und Prüfungen |
| `BuildSupport.ps1` | Sperre, Zielzuordnung und Statusdatei |
| `docs/` | Builder-Schnittstelle und gemeinsamer VM-Testplan |
| `tests/` | Isolierte Tests ohne echte Installationsmedien |
| `answer/` | Vorlagen für unbeaufsichtigtes Windows Setup |
| `config/` | Build-Profile im PSD1-Format |
| `scripts/` | SetupComplete und Windows-Anpassungsskripte |
| `tools/` | Optionale portable Werkzeuge für die VM |
| `source/` | Ablage für originale Installationsmedien |
| `drivers/` | Ablage für externe Treiber; der aktuelle Builder nutzt die VirtIO-ISO |
| `build/` | Arbeitsverzeichnisse, fertige ISOs, Prüfsummen und Logs |

Build-Ausgaben, ISO-Dateien und Logs sind durch `.gitignore` ausgeschlossen.

## Status für die spätere Oberfläche

Jeder Lauf schreibt eine JSON-Datei neben sein Log. Sie enthält Running, Succeeded oder Failed, den aktuellen Schritt, Profil/Zielsystem, Zeitpunkte und Dauer sowie bei Erfolg ISO-Pfad, Größe und SHA256. Nach einem harten Prozessabbruch kann der Status auf Running stehen bleiben; Prozessende und Status müssen gemeinsam ausgewertet werden.

Die genaue Schnittstelle steht in [docs/BUILDER-INTERFACE.md](docs/BUILDER-INTERFACE.md). Der [gemeinsame Testplan](docs/TESTPLAN.md) bündelt die Änderungen in einen Windows-11-Installationsdurchlauf. Die lokalen Ersatzmedien-Tests ersetzen keinen echten DISM-/VM-Test.
## Noch offen

- Eigene Antwortdateien und Installationstests für Windows 10, Server 2022 und Server 2025; bei Server zusätzlich Desktop Experience/Core berücksichtigen.
- Grafische Oberfläche auf Basis der dokumentierten Builder-Schnittstelle.
- RDP und OpenSSH als optionale Anpassungen.
- Optionale Softwarepakete: `Packages.ps1` ist bisher nicht in den Build-/FirstLogon-Ablauf eingebunden.
- Weitere Profiloptionen über die vier vorhandenen Anpassungsgruppen hinaus.
