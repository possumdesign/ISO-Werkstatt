# ISO-Werkstatt

Builder für eine angepasste Windows-11-VM-ISO für die Labor-/Proxmox-Umgebung. Das Standardprofil ist auf Windows 11 Pro x64 mit deutscher Oberfläche und Tastatur ausgelegt.

## Aktueller Stand: v0.7 – Robustheit und Build-Profile

- Vollautomatischer Build aus einer Windows-ISO und einer VirtIO-ISO.
- Unbeaufsichtigtes Setup mit UEFI/GPT, lokalem Administrator `LabAdmin` und einmaliger automatischer Anmeldung.
- VirtIO-Treiber: `vioscsi` und `NetKVM` in `boot.wim` (Index 2); zusätzlich `Balloon` und `vioserial` in der gewählten Edition von `install.wim`.
- QEMU Guest Agent wird über `SetupComplete.cmd` installiert.
- Windows-Anpassungen beim ersten Anmelden: Websuche reduzieren, Dateiendungen und versteckte Dateien anzeigen, Explorer mit „Dieser PC“ öffnen, Widgets und Werbe-/Consumer-Inhalte reduzieren sowie Edge konfigurieren.
- Edge erhält eine Richtlinie zur automatischen Installation von uBlock Origin Lite aus dem Edge-Store; die Erweiterung wird nicht offline in die ISO eingebettet.
- Optionale portable Tools werden kopiert; ZIP-Dateien werden jeweils in einen eigenen Unterordner entpackt.
- Syntaxprüfung der eingebundenen PowerShell-Skripte, XML-/Platzhalterprüfung, gezieltes Cleanup alter WIM-Mounts, Build-Protokoll und SHA256-Prüfsumme.
- Build-Profile für Edition, Antwortdatei, Tools-Ordner und vier einzeln schaltbare Windows-Anpassungsgruppen.

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

`Read-Host` in diesem Beispiel zeigt die Eingabe sichtbar an. Das Kennwort wird derzeit direkt in XML eingesetzt; XML-Sonderzeichen wie `&` oder `<` können deshalb die XML-Prüfung scheitern lassen.

| Parameter | Bedeutung | Standard |
| --- | --- | --- |
| `-WindowsIso` | Pfad zur Windows-ISO | Pflichtangabe |
| `-VirtioIso` | Pfad zur VirtIO-ISO | Pflichtangabe |
| `-Profile` | Dateiname unter `config/`, ohne `.psd1` | `lab-config` |
| `-Edition` | Überschreibt die Edition aus dem Profil | Profilwert |
| `-Version` | Versionsbezeichnung für Ausgabe und Dateiname | `0.6.0` |

Der Versionsstandard im Skript ist weiterhin `0.6.0`. Für entsprechend benannte v0.7-Artefakte `-Version "0.7.0"` ausdrücklich angeben.

## Build-Profile

Das Standardprofil `config/lab-config.psd1` enthält die bisherigen Einstellungen:

```powershell
@{
    Edition        = "Windows 11 Pro"
    AnswerTemplate = "answer\Autounattend.xml"
    ToolsDirectory = "tools"
}
```

Die Pfade beziehen sich auf das Repository. Alle drei Einstellungen sind erforderlich und müssen nicht leere Zeichenfolgen sein. Unbekannte Schlüssel und fehlende Profile führen vor den ISO-Arbeiten zum Abbruch.

Für ein weiteres Profil die Datei beispielsweise nach `config/test.psd1` kopieren, die Werte anpassen und beim Build zusätzlich `-Profile test` angeben. Profilnamen beginnen mit einem Buchstaben oder einer Ziffer und dürfen anschließend auch Bindestriche und Unterstriche enthalten. Ein ausdrücklich übergebenes `-Edition` hat Vorrang vor dem Profilwert.

Die Profile steuern keine Treiber oder zusätzlichen Dienste. Kennwörter gehören nicht ins Profil; dafür wird weiterhin `ISO_LAB_PASSWORD` verwendet.

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

1. Protokoll starten, Profil laden und Voraussetzungen prüfen.
2. Syntax von `Search.ps1`, `Explorer.ps1`, `WindowsDefaults.ps1`, `Edge.ps1` und `FirstLogon.ps1` prüfen.
3. Windows-ISO einhängen, nach `build/iso-root/` kopieren und wieder aushängen.
4. VirtIO-Komponenten nach `build/virtio/` extrahieren.
5. Edition ermitteln, alte Mounts an den beiden vorgesehenen Build-Mountpfaden verwerfen und Treiber integrieren.
6. Antwortdatei erzeugen, XML und verbliebene Platzhalter prüfen; Skripte, Guest Agent und Tools in die OEM-Struktur kopieren.
7. BIOS-/UEFI-bootfähige ISO mit `oscdimg` erstellen und dessen Exitcode prüfen.
8. SHA256 berechnen, Prüfsummendatei schreiben und Ergebnis ausgeben.

Für das Standardprofil mit `-Version "0.7.0"` entstehen:

```text
build/
  ISO-Werkstatt-lab-config-v0.7.0.iso
  ISO-Werkstatt-lab-config-v0.7.0.iso.sha256
  logs/
    build-<Zeitstempel>-<eindeutige ID>.log
```

Die Prüfsummendatei enthält `SHA256 *ISO-Dateiname`. Zum manuellen Gegenprüfen:

```powershell
Get-FileHash -LiteralPath ".\build\ISO-Werkstatt-lab-config-v0.7.0.iso" -Algorithm SHA256
Get-Content -LiteralPath ".\build\ISO-Werkstatt-lab-config-v0.7.0.iso.sha256"
```

Jeder Lauf erhält ein eigenes Transcript. Bei abgefangenen Fehlern wird die Fehlermeldung vor dem Abschluss des Logs ausgegeben und der Fehler weitergereicht. Ein hart beendeter Prozess kann das Log nicht regulär abschließen.

Verschiedene Profile erhalten verschiedene ISO-Dateinamen. Für dasselbe Profil und dieselbe Version bleibt der Zielname identisch. Die Arbeitsverzeichnisse werden gemeinsam verwendet: Builds deshalb nacheinander ausführen. Bestehende ISOs mit dem früheren Namen werden nicht automatisch umbenannt oder entfernt.

## Protokolle in der installierten VM

Unter `C:\ISO-Werkstatt\` liegen:

- `setup.log`: Ausführung von SetupComplete und Guest-Agent-Exitcode.
- `qemu-ga-install.log`: MSI-Installationsprotokoll des QEMU Guest Agent.
- `firstlogon.log`: Windows-Anpassungen beim ersten Anmelden.
- `Tools\`: die übernommenen portablen Werkzeuge.

## Repository-Struktur

| Pfad | Inhalt |
| --- | --- |
| `build.ps1` | Build-Ablauf und Prüfungen |
| `answer/` | Vorlagen für unbeaufsichtigtes Windows Setup |
| `config/` | Build-Profile im PSD1-Format |
| `scripts/` | SetupComplete und Windows-Anpassungsskripte |
| `tools/` | Optionale portable Werkzeuge für die VM |
| `source/` | Ablage für originale Installationsmedien |
| `drivers/` | Ablage für externe Treiber; der aktuelle Builder nutzt die VirtIO-ISO |
| `build/` | Arbeitsverzeichnisse, fertige ISOs, Prüfsummen und Logs |

Build-Ausgaben, ISO-Dateien und Logs sind durch `.gitignore` ausgeschlossen.

## Noch offen

- RDP und OpenSSH als optionale Anpassungen.
- Optionale Softwarepakete: `Packages.ps1` ist bisher nicht in den Build-/FirstLogon-Ablauf eingebunden.
- Weitere Profiloptionen über die vier vorhandenen Anpassungsgruppen hinaus.
