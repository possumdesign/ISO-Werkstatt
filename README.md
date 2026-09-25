# ISO-Werkstatt

Lokaler Builder mit grafischer Oberfläche für angepasste Windows-10/11- und Windows-Server-2022/2025-ISOs: Labor-/Proxmox-VM oder PC mit lokalem Konto. Das Standardprofil ist auf Windows 11 Pro x64 mit deutscher Oberfläche und Tastatur ausgelegt.

## Aktueller Stand: v0.7 – Robustheit und Build-Profile

- Build aus einer Windows-ISO; eine VirtIO-ISO wird nur für aktivierte VirtIO-Treiber oder den QEMU Guest Agent benötigt.
- Laborprofil: unbeaufsichtigtes Setup mit UEFI/GPT, lokalem Administrator `LabAdmin` und einmaliger automatischer Anmeldung.
- VirtIO-Treiber: `vioscsi` und `NetKVM` in `boot.wim` (Index 2); zusätzlich `Balloon` und `vioserial` in der gewählten Edition von `install.wim`.
- PC-Profil `pc-local`: ohne VirtIO-Treiber und QEMU, manuelle Zielpartition, lokales Konto und optionales Produktschlüsselfeld.
- QEMU Guest Agent wird bei aktivierter Option über `SetupComplete.cmd` installiert.
- Windows-Anpassungen beim ersten Anmelden: Websuche reduzieren, Dateiendungen und versteckte Dateien anzeigen, Explorer mit „Dieser PC“ öffnen, Widgets und Werbe-/Consumer-Inhalte reduzieren sowie Edge konfigurieren.
- Edge erhält eine Richtlinie zur automatischen Installation von uBlock Origin Lite aus dem Edge-Store; die Erweiterung wird nicht offline in die ISO eingebettet.
- Optionale portable Tools werden kopiert; ZIP-Dateien werden jeweils in einen eigenen Unterordner entpackt. Beim ersten Anmelden entsteht auf dem Desktop des angemeldeten Benutzers eine Verknüpfung namens „Tools“ zu C:\ISO-Werkstatt\Tools. Sie wird bei aktivierter Tools-Option und vorhandenem Ordner angelegt; das Ergebnis steht im FirstLogon-Log.
- Syntaxprüfung der eingebundenen PowerShell-Skripte, XML-/Platzhalterprüfung, gezieltes Cleanup alter WIM-Mounts, Build-Protokoll, SHA256-Prüfsumme und JSON-Status/Ergebnis pro Lauf.
- Build-Profile für Zielsystem, Edition, Antwortdatei, Tools-Ordner und vier einzeln schaltbare Windows-Anpassungsgruppen. Windows 11 ist installationsgetestet; Windows 10 und Server 2022/2025 (Desktop Experience und Core) sind im Builder verfügbar, echte Installationstests stehen noch aus.
- Exklusive Build-Sperre, einheitliche Schritte 1–10 und FirstLogon-Abschlussbericht.

## Voraussetzungen

- Windows-Build-Rechner mit PowerShell und den DISM-/DiskImage-Cmdlets; PowerShell als Administrator starten.
- Windows ADK mit Deployment Tools. Der Builder erwartet `oscdimg.exe` unter:

  ```text
  C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe
  ```

- Windows-x64-Installations-ISO mit `sources\install.wim` oder `sources\install.esd`, `sources\boot.wim` und der gewünschten Edition. Bei ESD exportiert der Builder die gewählte Edition in eine bearbeitbare WIM. Geteilte SWM-Abbilder werden nicht unterstützt.
- Bei aktivierten VirtIO-Treibern: VirtIO-ISO mit zum Zielsystem passenden amd64-Treibern für `vioscsi`, `NetKVM`, `Balloon`, `vioserial`. Bei aktiviertem QEMU Guest Agent muss sie außerdem `guest-agent\qemu-ga-x86_64.msi` enthalten.
- Ausreichend freier Speicher für entpackte Installationsdateien, WIM-Mounts und fertige ISO.

Die Standard-Antwortdatei löscht während der Windows-Installation Datenträger 0 und partitioniert ihn neu. Sie ist für die vorgesehene Labor-VM bestimmt. Das neue Profil `pc-local` verwendet `answer/Autounattend-PC.xml` ohne automatische Datenträgerlöschung; im Setup die Zielpartition selbst auswählen. Kennwort und ein optional eingegebener Produktschlüssel stehen in der erzeugten Antwortdatei unter `build/iso-root` und damit in der ISO; Build-Artefakte entsprechend behandeln.

## Grafische Oberfläche

Im Repository **Start-Builder.cmd** doppelt anklicken und die Windows-Administratorabfrage bestätigen. Danach zuerst die Windows-ISO auswählen und erkennen lassen, anschließend PC-Lokal oder Proxmox VM wählen; die VirtIO-ISO wird nur bei Bedarf verlangt. Kennwort und optionalen Produktschlüssel eingeben. Unter **Zusätzliche Anpassungen** Tools, Bing-/Websuche, uBlock Lite und QEMU einzeln wählen, dann **ISO erstellen** anklicken.

Die Oberfläche zeigt Fortschritt, Laufzeit, Protokoll und Ergebnis an. Sie startet den vorhandenen Builder in einem eigenen Prozess. Profilvorgaben können über **Profil bearbeiten** gespeichert werden; Eingaben im Hauptfenster gelten nur für den jeweiligen Lauf. Die Anleitung einschließlich schneller Tests steht in [docs/GUI.md](docs/GUI.md).

## Build über PowerShell starten

Im Repository-Verzeichnis in einer administrativen PowerShell ausführen. Die ISO-Pfade im Beispiel durch die eigenen Pfade ersetzen:

```powershell
$env:ISO_LAB_PASSWORD = Read-Host "Kennwort für das lokale Konto"

.\build.ps1 `
    -WindowsIso "D:\ISO\Windows11.iso" `
    -VirtioIso "D:\ISO\virtio-win.iso" `
    -Version "0.7.0"
```

`Read-Host` in diesem Beispiel zeigt die Eingabe sichtbar an. Der Builder maskiert XML-Sonderzeichen wie `&`, `<`, `>` und Anführungszeichen automatisch. Das Kennwort bleibt nach dem Einlesen der XML unverändert; in XML 1.0 unzulässige Zeichen werden abgewiesen.

| Parameter | Bedeutung | Standard |
| --- | --- | --- |
| `-WindowsIso` | Pfad zur Windows-ISO | Pflichtangabe |
| `-VirtioIso` | Pfad zur VirtIO-ISO | Nur bei Treiberintegration oder QEMU erforderlich |
| `-LocalUserName` | Lokaler Kontoname und automatische Anmeldung | `Winuser` (PC), `LabAdmin` (VM) |
| `-Profile` | Dateiname unter `config/`, ohne `.psd1` | `lab-config` |
| `-Edition` | Überschreibt die Edition aus dem Profil | Profilwert |
| `-Version` | Versionsbezeichnung für Ausgabe und Dateiname | `0.7.0` |
| `-Tools` | Tools kopieren und Desktop-Verknüpfung anlegen | `Profile` |
| `-WebSearch` | `On` schaltet Bing-/Websuche ab; `Off` lässt sie unverändert | `Profile` |
| `-UBlockLite` | Edge-Richtlinie zur Installation der Erweiterung | `Profile` |
| `-QemuGuestAgent` | Guest-Agent-Paket und Installation übernehmen | `Profile` |
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

Die optionale Angabe `TargetOS` bestimmt den VirtIO-Unterordner; ohne Angabe gilt `Windows11`. Windows10, Server2022 und Server2025 sind ebenfalls verfügbar. `InstallationMode` ist Desktop (Standard) oder bei Server auch Core; die gewählte Edition wird anhand der Abbildmetadaten geprüft. VirtIO-Treiber werden über `IncludeVirtioDrivers` gesteuert, QEMU über `Features.QemuGuestAgent`. Kennwort und Produktschlüssel gehören nicht ins Profil; dafür dienen `ISO_LAB_PASSWORD` und `ISO_PRODUCT_KEY`.

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

Dieses Beispiel führt die bisherigen Anpassungen außer Edge aus. Ohne expliziten `Features.UBlockLite`-Wert folgt uBlock aus Kompatibilitätsgründen dem Edge-Schalter. Mit `Features.UBlockLite` oder der Laufoption lässt sich die Erweiterung unabhängig davon wählen. `Explorer = $false` überspringt die Explorer-Einstellungen und das abschließende Öffnen von „Dieser PC“.

Der gesamte Abschnitt ist optional; fehlende Schalter gelten als `$true`, sodass bestehende Profile unverändert weiterarbeiten. Werte müssen echte PowerShell-Booleans (`$true` oder `$false`) sein, keine Zeichenfolgen. Unbekannte Namen oder falsche Typen führen vor den ISO-Arbeiten zum Abbruch.

Der Builder schreibt die vier Anpassungsschalter sowie `UBlockLite` und `Tools` nach `C:\ISO-Werkstatt\scripts\adjustments.psd1` in der VM. FirstLogon prüft diese Datei und protokolliert ausgeführte sowie übersprungene Gruppen. Fehlt die Datei oder ist sie ungültig, bricht FirstLogon mit einer Fehlermeldung im Log ab. Deaktivieren bedeutet, eine Anpassung bei dieser Installation auszulassen; bereits gesetzte Einstellungen werden dadurch nicht zurückgenommen.

### PC-Profil und zusätzliche Optionen

`config/pc-local.psd1` verwendet Windows 11 Pro, das lokale Konto Winuser und die einmalige automatische Anmeldung, aber keine VirtIO-Treiber und keinen QEMU-Agent. Tools und Windows-Anpassungen sind zunächst aktiv. Die Zielpartition wird im Windows-Setup manuell gewählt.

Diese optionalen Profilwerte steuern die Zusätze dauerhaft:

```powershell
IncludeVirtioDrivers = $false
Features = @{
    Tools          = $true
    UBlockLite     = $true
    QemuGuestAgent = $false
}
```

Ohne diese Werte behalten bestehende Profile ihr Verhalten: Treiber, Tools und QEMU aktiv, uBlock entsprechend dem Edge-Schalter. Die vier Laufparameter akzeptieren `Profile`, `On` und `Off`; sie überschreiben keine Profildatei. In der GUI setzt ein Profilwechsel die Kästchen auf die Profilvorgaben zurück. VirtIO-Treiber und QEMU sind voneinander unabhängig.

PC-Build ohne VirtIO-ISO und ohne Tools:

```powershell
$env:ISO_LAB_PASSWORD = Read-Host "Kennwort für das lokale Konto"
.\build.ps1 -WindowsIso "D:\ISO\Windows11.iso" -Profile pc-local -Tools Off
```

Den optionalen Schlüssel vorzugsweise im verdeckten GUI-Feld eingeben. Bei CLI-Nutzung wird er aus `ISO_PRODUCT_KEY` gelesen, niemals als Build-Parameter. Bei Windows 10 ohne Eingabe übernimmt der Builder den exakt zur DISM-EditionId passenden Standard-Setup-Schlüssel aus sources/product.ini des Mediums, sofern die Vorlage keinen eigenen Schlüssel enthält. Fehlt eine eindeutige Zuordnung, bricht der Build vor der Treiberintegration ab und verlangt einen passenden Schlüssel. Dieser Standard-Schlüssel dient der Installation, nicht der Aktivierung. Bei anderen Zielsystemen bedeutet leer weiterhin unveränderte Antwortvorlage: Das Laborprofil behält seinen bisherigen generischen Setup-Schlüssel; die PC-Vorlage enthält keinen festen Schlüssel. Das Verhalten ohne Schlüssel hängt auch von Installationsmedium und einem möglichen Firmware-Schlüssel ab.

Geprüft wird nur das Format `XXXXX-XXXXX-XXXXX-XXXXX-XXXXX`, keine Lizenzgültigkeit. Der Schlüssel wird unter `Microsoft-Windows-Setup/UserData/ProductKey` eingesetzt und muss zur ausgewählten Edition passen. Windows-Aktivierung ist ein separater Schritt; das Feld setzt keinen Aktivierungsschlüssel unter `Microsoft-Windows-Shell-Setup`. Siehe [Microsoft: ProductKey-Einstellungen](https://learn.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/microsoft-windows-setup-userdata-productkey).

Bei OEM-Schlüsseln kann Windows Pro `SetupComplete.cmd` auslassen; damit würde ein zusätzlich aktivierter QEMU-Agent nicht automatisch installiert. Das PC-Profil hat QEMU standardmäßig ausgeschaltet. Siehe [Microsoft: SetupComplete bei OEM-Schlüsseln](https://learn.microsoft.com/en-us/troubleshoot/mem/configmgr/os-deployment/os-deployment-task-sequence-not-continue).

## Ablauf und Ergebnisse

1. Protokoll und Statusdatei anlegen, Build sperren, Profil/Voraussetzungen und Skriptsyntax prüfen.
2. Windows-ISO nach build/iso-root kopieren.
3. Benötigte VirtIO-Komponenten extrahieren oder den Schritt überspringen.
4. Edition ermitteln; bei aktivierten VirtIO-Treibern alte WIM-Mounts gezielt bereinigen und Treiber integrieren.
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

- `setup.log`: bei aktiviertem QEMU Ausführung von SetupComplete und Guest-Agent-Exitcode.
- `qemu-ga-install.log`: bei aktiviertem QEMU das MSI-Installationsprotokoll des QEMU Guest Agent.
- `firstlogon.log`: Windows-Anpassungen mit Abschlusszusammenfassung. Fehlerhafte Gruppen verhindern nicht die Ausführung der übrigen Gruppen.
- `firstlogon-result.json`: Erfolg, Fehler und übersprungene Schritte beim ersten Anmelden.
- `Tools\`: bei aktivierter Tools-Option die übernommenen portablen Werkzeuge.

## Repository-Struktur

| Pfad | Inhalt |
| --- | --- |
| `Start-Builder.cmd`, `builder-gui.ps1` | Start der grafischen Oberfläche |
| `gui/` | WPF-Fenster und Prozess-/Statusanbindung |
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

## Status für die Oberfläche

Jeder Lauf schreibt eine JSON-Datei neben sein Log. Sie enthält Running, Succeeded oder Failed, den aktuellen Schritt, Profil/Zielsystem, Zeitpunkte und Dauer sowie bei Erfolg ISO-Pfad, Größe und SHA256. Nach einem harten Prozessabbruch kann der Status auf Running stehen bleiben; Prozessende und Status müssen gemeinsam ausgewertet werden.

Die genaue Schnittstelle steht in [docs/BUILDER-INTERFACE.md](docs/BUILDER-INTERFACE.md). Der [gemeinsame Testplan](docs/TESTPLAN.md) bündelt die Prüfungen pro Zielsystem und Installationsvariante. Die lokalen Ersatzmedien-Tests ersetzen keinen echten DISM-/VM-Test.
## Wenn eine Quell-ISO beim Einhängen hängen bleibt

Der Builder protokolliert Statusabfrage, Einhängen, Laufwerksabfrage und Aushängen jetzt einzeln mit Zeitstempel. Storage-Aufträge laufen als Hintergrundjobs: maximal 60 Sekunden für das Einhängen, 30 Sekunden für eine Statusabfrage bzw. das Aushängen und ein Zeitbudget von 30 Sekunden für den Laufwerksbuchstaben. Meldet Windows zunächst keinen Buchstaben, wird innerhalb dieses Budgets erneut abgefragt.

Bereits eingehängte Quell-ISOs werden wiederverwendet und anschließend eingehängt gelassen. Nur selbst angeforderte Einhängungen werden aufgeräumt. Ein Cleanup-Fehler verdeckt nicht den ursprünglichen Build-Fehler. Nach einem Zeitlimit kann ein Windows-Storage-Auftrag trotz Stoppanforderung noch nachlaufen; vor dem nächsten Versuch den ISO-Status prüfen. Während des Builds die Quellen nicht manuell aushängen.

Die neuen Ablauf- und Zeitlimitprüfungen lassen sich ohne echte ISO ausführen:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-IsoStorage.ps1
```
## Noch offen

- Echte Installationstests für Windows 10, Server 2022 und Server 2025, bei Server jeweils Desktop Experience und Core; Profile und Antwortdateien sind implementiert.
- RDP und OpenSSH als optionale Anpassungen.
- Optionale Softwarepakete: `Packages.ps1` ist bisher nicht in den Build-/FirstLogon-Ablauf eingebunden.
- Weitere Profiloptionen über die vier vorhandenen Anpassungsgruppen hinaus.

## Lokaler Kontoname

Das Feld **Lokaler Kontoname** ist frei änderbar. Profilvorgaben: `Winuser` bei `pc-local`, `LabAdmin` bei `lab-config`. Ein Profilwechsel lädt den jeweiligen Standard neu. Der Name gilt für das angelegte Konto, dessen Anzeigenamen und die automatische Anmeldung; die Administratorrechte bleiben wie bisher.

In eigenen Profilen setzt `LocalUserName = 'MeinBenutzer'` den Standard. Ohne diesen Wert gilt bei deaktivierten VirtIO-Treibern Winuser, sonst LabAdmin. Die Laufoption `-LocalUserName 'MeinBenutzer'` überschreibt nur diesen Build. Leere oder ungültige Namen werden vor den ISO-Arbeiten abgewiesen. Kontonamen sind keine Geheimnisse und stehen auch im JSON-Buildstatus.

Unterstützt werden 1–20 Zeichen ohne die von Windows verbotenen Zeichen. Zusätzlich werden äußere Leerzeichen, abschließende Punkte und bekannte eingebaute Konto-/Gruppennamen abgewiesen. Grundlage: [Microsoft: lokale Kontonamen](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.localaccounts/new-localuser?view=powershell-5.1). Eigene Antwortdateien müssen genau ein lokales Konto mit Name/DisplayName und genau eine AutoLogon-Username-Angabe enthalten.

## ISO zuerst: Zielsystem und Edition erkennen

Die Oberfläche gibt Optionen erst nach erfolgreicher ISO-Erkennung frei. Im Profilfeld stehen ausschließlich **PC-Lokal** und **Proxmox VM**. Zielsystem, Antwortdatei und Treiberzuordnung werden automatisch aus den Abbildmetadaten und der Einsatzart abgeleitet; die bisherigen PSD1-Profile bleiben intern sowie per CLI erhalten.

Bei Server-Medien mit Core-Editionen erscheint **Core – Headless**, standardmäßig ohne Haken. Die Editionsliste zeigt entsprechend Desktop Experience oder Core. Reine Core-Medien benötigen den gesetzten Haken. Bei Windows 10/11 bleibt er ausgeblendet. Ein ISO-Wechsel setzt Erkennung und Core-Auswahl zurück.

Nach Auswahl im Dateidialog startet die WIM-/ESD-Abfrage automatisch. Eingetippte Pfade lassen sich mit **↻** neben der ISO-Auswahl einlesen. Unbekannte Zielsysteme, unpassende Architektur und fehlgeschlagene Abfragen lassen den Build gesperrt. Die Abfrage verwendet die gemeinsame Build-Sperre und verändert keine Installationsabbilder.

## Oberflächensprache und Profileditor

Oben rechts schalten die Buttons mit deutscher und US-Flagge zwischen **Deutsch** und **Englisch** um. Standard beim Start ist Deutsch. Beschriftungen, Hinweise und Statusanzeige wechseln während der Sitzung; Eingaben und laufende Vorgänge bleiben erhalten. Die Sprache der Windows-Installation, Profilwerte, Editionsnamen und Originalprotokolle werden dadurch nicht geändert. Technische Meldungen von Windows/DISM oder eigenen Skripten bleiben im Original erhalten.

**Profil bearbeiten** öffnet die automatisch zugeordnete interne Vorlage. Kontoname, Tools-Verzeichnis, VirtIO und Anpassungen können gespeichert werden. Die aus der ISO abgeleiteten Felder sowie Profilname und Antwortdatei sind schreibgeschützt. Kopien eigener PSD1-Profile können weiterhin über die CLI genutzt werden. Details stehen in [docs/GUI.md](docs/GUI.md).

## Windows 10 und Windows Server

Die neuen Profile, Unterschiede bei Server Core und der gebündelte Installationstest stehen in [docs/MULTI-OS.md](docs/MULTI-OS.md). Bestehende Windows-11-Profile behalten ihre Vorgaben.

## Lizenz

ISO-Werkstatt / ISO-Crafter steht unter der [MIT-Lizenz](LICENSE).
Copyright (c) 2026 possumdesign.

Die Lizenz gilt für den eigenen Projektcode. Windows-Installationsmedien, VirtIO-Treiber, QEMU und andere Komponenten Dritter unterliegen ihren jeweiligen Lizenzen; die Projektlizenz erteilt keine zusätzlichen Rechte daran.
