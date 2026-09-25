# Windows 10 und Windows Server

Der Builder unterstützt Windows 10 sowie Server 2022/2025 mit Desktop Experience und Server Core, jeweils x64. Die automatisierten Tests verwenden Ersatzmedien und simuliertes DISM. Am 24.09.2026 wurden erfolgreiche Proxmox-Installationen von Windows 10 Pro sowie Server 2022/2025 jeweils mit Desktop Experience und Core, einschließlich QEMU Guest Agent, vom Benutzer bestätigt. Unter Windows 10 funktionieren auch Edge-Einstellungen, Erweiterung und lokale Suche. Offen ist ein Nebenbefund zu desktop.ini (siehe TESTPLAN.md). Neue lokale Hardwareprofile sind damit noch nicht separat installationsgetestet. Windows 11 wurde bereits in VM und auf einem Mini-PC getestet.

## Interne Profile und CLI-Auswahl

| Ziel | VM-Profil | Lokales Profil |
| --- | --- | --- |
| Windows 10 | `win10-vm` | `win10-local` |
| Server 2022 Desktop Experience | `server2022-desktop-vm` | `server2022-desktop-local` |
| Server 2022 Core | `server2022-core-vm` | `server2022-core-local` |
| Server 2025 Desktop Experience | `server2025-desktop-vm` | `server2025-desktop-local` |
| Server 2025 Core | `server2025-core-vm` | `server2025-core-local` |

In der GUI zuerst die ISO laden, danach nur **PC-Lokal** oder **Proxmox VM** wählen. Die folgende Zuordnung erfolgt automatisch; Server Core wird über den standardmäßig ausgeschalteten Haken **Core – Headless** gewählt. Die Tabellennamen sind interne Profile und CLI-Parameter.

VM-Profile partitionieren Datenträger 0 automatisch (UEFI/GPT), integrieren VirtIO und QEMU und verwenden LabAdmin. Lokale Profile lassen die Zielpartition manuell wählen, verzichten auf VirtIO/QEMU und verwenden Winuser. Der Kontoname bleibt änderbar. Tools sind in allen Profilen voreingestellt.

Die Vorlagen verwenden deutsche Sprache und Tastatur. Die Editionsnamen sind Vorschläge: Nach Auswahl der ISO die tatsächlich vorhandene Edition auswählen. Standard, Datacenter und Evaluation werden nicht anhand ihres Namens ausgeschlossen; Architektur, Windows-Version und Installationsvariante müssen passen. Core und Desktop Experience erfordern getrennte Installationen; ein späterer Wechsel ist nicht vorgesehen ([Microsoft](https://learn.microsoft.com/en-us/windows-server/get-started/getting-started-with-server-with-desktop-experience)).

Neue Vorlagen enthalten keinen festen Produktschlüssel. Windows 10 erhält bei leerem Eingabefeld automatisch den zur DISM-EditionId passenden Standard-Setup-Schlüssel aus sources/product.ini des Mediums; ein eigener Vorlagenschlüssel bleibt erhalten. Fehlt eine eindeutige Zuordnung, verlangt der Builder einen passenden eingegebenen Schlüssel. Server erhält keinen solchen automatischen Fallback. Ein optionaler Schlüssel muss zum Medium und zur Edition passen. Server setzt das eingegebene Kennwort sowohl für das benannte lokale Administratorkonto als auch für den eingebauten Administrator; ein Kennwort entsprechend der Windows-Kennwortrichtlinie verwenden. Rollen, Domänenbeitritt und Aktivierung werden nicht eingerichtet.

## Anpassungen und Medien

- Windows 10: bisherige Client-Anpassungen; statt Windows-11-Widgets wird „Neuigkeiten und interessante Themen“ über die Windows-Feeds-Richtlinie abgeschaltet.
- Server Desktop: Explorer-Anpassungen aktiv; Search, WindowsDefaults, Edge und uBlock standardmäßig aus. WindowsDefaults ist auf Server gesperrt.
- Server Core: alle Desktop-Anpassungen gesperrt. Tools werden nach `C:\ISO-Werkstatt\Tools` kopiert, ohne Desktop-Verknüpfung oder Explorer-Start. VirtIO und QEMU bleiben unabhängig davon verwendbar.
- VirtIO benötigt die vorhandenen Treiberverzeichnisse `w10/amd64`, `2k22/amd64` bzw. `2k25/amd64`; es gibt keinen automatischen Rückgriff auf andere Versionen.
- WIM und ESD werden gelesen. Bei ESD exportiert der Builder nur die gewählte Edition in eine WIM und verwendet deren neuen Index. Die Quell-ISO bleibt unverändert. Geteilte SWM-Abbilder sind nicht unterstützt.

## Gebündelter Installationstest

Für jede der fünf Tabellenzeilen einmal einen echten Build und eine frische Installation durchführen. Dafür werden noch passende Quell-ISOs benötigt. Zunächst VM-Profile auf einer leeren Testplatte verwenden; lokale Profile danach bei Bedarf mit manueller Partitionierung auf Zielhardware prüfen.

Pro Durchlauf gemeinsam prüfen:

1. ISO auswählen, Edition einlesen und passend zum Profil wählen. Bei einem verfügbaren ESD-Medium zusätzlich die Exportstrecke testen.
2. Kontonamen ändern, Kennwort setzen, bei Bedarf passenden Setup-Schlüssel eingeben. Build muss ISO, SHA256, Log und erfolgreichen JSON-Status erzeugen.
3. UEFI-Start, Partitionierung, gewünschte Edition und einmalige automatische Anmeldung prüfen. Lokales Konto muss Administratorrechte haben; bei Server auch Anmeldung des eingebauten Administrators prüfen.
4. Bei VM VirtIO-Geräte und QEMU-Dienst prüfen; Setup-/Guest-Agent-Protokolle unter `C:\ISO-Werkstatt` kontrollieren.
5. Tools und `firstlogon-result.json` prüfen. Bei Standardprofilen: Windows 10 sieben erfolgreiche Schritte; Server Desktop drei erfolgreiche und vier übersprungene Schritte; Core sieben übersprungene Schritte mit Gesamtstatus Succeeded. Auf Core dürfen Explorer und Desktop-Verknüpfung nicht gestartet/angelegt werden.
6. Neu starten: kein erneuter automatischer Login, Einstellungen und Dienste weiterhin vorhanden. Ergebnisse und verwendete ISO/Edition im Testprotokoll festhalten.

Ein erfolgreicher Build allein bestätigt weder Setup noch FirstLogon auf dem neuen System. Weitere allgemeine Prüfungen und vorhandene Regressionstests stehen im [Testplan](TESTPLAN.md).
