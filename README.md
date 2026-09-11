# ISO-Werkstatt

Reproduzierbarer Builder für eine angepasste Windows-11-Pro-VM-ISO.

## Ziel

Windows 11 Pro x64 DE für die Labor-/Proxmox-Umgebung.

### v0.1

- Unattended Windows Setup
- Windows 11 Pro
- Sprache: Deutsch
- Tastatur: Deutsch
- UEFI / GPT
- Lokaler Administrator
- OOBE automatisieren
- VirtIO Storage
- VirtIO Netzwerk
- QEMU Guest Agent

### Spätere Anpassungen

- Windows-Websuche deaktivieren
- Edge bereinigen
- uBlock Origin Lite vorinstallieren
- Explorer konfigurieren
- Consumer-/Werbeinhalte reduzieren
- RDP
- OpenSSH
- optionale Softwarepakete

## Repository-Struktur

- `answer/` – Windows Answer Files
- `config/` – Profile und Builder-Konfiguration
- `drivers/` – externe Treiber
- `scripts/` – Windows-Anpassungen
- `source/` – originale Installationsmedien
- `tools/` – externe Build-Werkzeuge
- `build/` – erzeugte ISO-Dateien
## Build-Profile

Ohne zusätzlichen Parameter verwendet der Builder config/lab-config.psd1.
Dieses Profil enthält die bisherigen Werte für Edition, Antwortdatei und Tools-Ordner.
Die Pfade beziehen sich auf das Repository. Ein ausdrücklich angegebenes
-Edition überschreibt die Edition aus dem Profil.

Für ein weiteres Profil die Datei beispielsweise nach config/test.psd1
kopieren und die drei Werte anpassen. Beim bisherigen Build-Aufruf zusätzlich
-Profile test angeben (Dateiname ohne .psd1).

Fehlende Profile, unbekannte Einstellungen und leere oder falsch typisierte Werte
führen vor den ISO-Arbeiten zum Abbruch. Der Profilname erscheint im Build-Log.
Profile enthalten keine Passwörter; ISO_LAB_PASSWORD wird weiterhin verwendet.
Die Windows-Anpassungsskripte und der Name der Ausgabe-ISO bleiben unverändert.
