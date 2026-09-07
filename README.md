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