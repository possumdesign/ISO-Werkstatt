# Gemeinsamer Test vor der Builder-Oberfläche

## Schnelle lokale Prüfung

Aus dem Repository, ohne Administratorrechte und ohne echte Installationsmedien:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-Builder.ps1
```

Der Test arbeitet in einem eigenen Ordner unter TEMP. Dort werden eine Kopie des Builders, kleine Ersatzmedien und Ersatzskripte verwendet. DISM-/DiskImage-Aufrufe und oscdimg sind in diesem Test ersetzt. Echte Windows-Anpassungen werden nicht ausgeführt; die echte Verknüpfung wird ausschließlich im Testordner angelegt. Testartefakte bleiben zur Diagnose erhalten, ihr Pfad wird ausgegeben.

Geprüft werden Prozesssperre und Freigabe, Zielzuordnung, erfolgreicher Build-Ablauf, SHA256-Ergebnis, doppelte RunId, fehlgeschlagene ISO-Erstellung trotz älterer ISO, Sperre nicht freigegebener Zielsysteme sowie FirstLogon-Erfolg, Fehler, übersprungene Gruppen, Konfigurationsfehler und Tools-Verknüpfung.

## Ein gebündelter Windows-11-Build und VM-Test

1. Standardprofil `lab-config` verwenden; alle vier Anpassungen aktiv lassen. Den bisherigen ISO-Aufruf verwenden, optional mit dem bereits getesteten Sonderzeichen-Testkennwort. Standardversion ist jetzt `0.7.0`.
2. Am Build-Rechner prüfen: Schritte 1 bis 10, abschließend „BUILD ERFOLGREICH“, ISO und SHA256-Datei sowie `build/logs/build-<RunId>.json` mit `Status = Succeeded`, passendem ISO-Pfad und Hash.
3. Die neue ISO in einer frischen Labor-VM installieren. Setup und automatische Anmeldung müssen wie bisher funktionieren.
4. Auf dem Desktop die neue Verknüpfung „Tools“ öffnen: Sie soll nach `C:\ISO-Werkstatt\Tools` führen.
5. Die vier Anpassungsgruppen stichprobenartig prüfen: Suche, Explorer, Windows-Voreinstellungen, Edge. Für den tatsächlichen Download von uBlock Origin Lite ist der Zugriff auf den Edge-Store erforderlich.
6. `C:\ISO-Werkstatt\firstlogon.log` muss mit einer Zusammenfassung ohne fehlgeschlagene Schritte enden. In `firstlogon-result.json` wird `Status = Succeeded` erwartet; beim Standardprofil mit vorhandenem Tools-Ordner sind sechs Schritte erfolgreich.
7. Guest-Agent-Installation separat anhand von `setup.log`, `qemu-ga-install.log` und der Anzeige in Proxmox prüfen.

Deaktivierte Gruppen und absichtliche Skriptfehler sind bereits durch die lokalen Tests abgedeckt. Für diese Fälle ist kein weiterer kompletter ISO-/Installationsdurchlauf vorgesehen. Windows 10 und Server werden erst bei ihrer eigentlichen Freigabe jeweils separat installiert und getestet.
