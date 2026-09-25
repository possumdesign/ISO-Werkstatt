# Gemeinsamer Builder- und Installationstest

## Schnelle lokale Prüfung

Aus dem Repository, ohne Administratorrechte und ohne echte Installationsmedien:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-Builder.ps1
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\tests\Test-Gui.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-IsoStorage.ps1
```

Der Test arbeitet in einem eigenen Ordner unter TEMP. Dort werden eine Kopie des Builders, kleine Ersatzmedien und Ersatzskripte verwendet. DISM-/DiskImage-Aufrufe und oscdimg sind in diesem Test ersetzt. Echte Windows-Anpassungen werden nicht ausgeführt; die echte Verknüpfung wird ausschließlich im Testordner angelegt. Testartefakte bleiben zur Diagnose erhalten, ihr Pfad wird ausgegeben.

Geprüft werden Prozesssperre und Freigabe, Zielzuordnung, erfolgreicher Build-Ablauf, SHA256-Ergebnis, doppelte RunId, fehlgeschlagene ISO-Erstellung trotz älterer ISO, Sperre nicht freigegebener Zielsysteme sowie FirstLogon-Erfolg, Fehler, übersprungene Gruppen, Konfigurationsfehler und Tools-Verknüpfung.

## Ein gebündelter Windows-11-Build und VM-Test

1. Standardprofil `lab-config` verwenden; alle vier Anpassungen aktiv lassen. Den bisherigen ISO-Aufruf verwenden, optional mit dem bereits getesteten Sonderzeichen-Testkennwort. Standardversion ist jetzt `0.7.0`.
2. Am Build-Rechner prüfen: Schritte 1 bis 10, abschließend „BUILD ERFOLGREICH“, ISO und SHA256-Datei sowie `build/logs/build-<RunId>.json` mit `Status = Succeeded`, passendem ISO-Pfad und Hash.
3. Die neue ISO in einer frischen Labor-VM installieren. Setup und automatische Anmeldung müssen wie bisher funktionieren.
4. Auf dem Desktop die neue Verknüpfung „Tools“ öffnen: Sie soll nach `C:\ISO-Werkstatt\Tools` führen.
5. Die vier Anpassungsgruppen stichprobenartig prüfen: Suche, Explorer, Windows-Voreinstellungen, Edge. Für den tatsächlichen Download von uBlock Origin Lite ist der Zugriff auf den Edge-Store erforderlich.
6. `C:\ISO-Werkstatt\firstlogon.log` muss mit einer Zusammenfassung ohne fehlgeschlagene Schritte enden. In `firstlogon-result.json` wird `Status = Succeeded` erwartet; beim Standardprofil mit vorhandenem Tools-Ordner sind sieben Schritte erfolgreich (uBlock jetzt separat).
7. Guest-Agent-Installation separat anhand von `setup.log`, `qemu-ga-install.log` und der Anzeige in Proxmox prüfen.

Deaktivierte Gruppen und absichtliche Skriptfehler sind bereits durch die lokalen Tests abgedeckt. Für diese Fälle ist kein weiterer kompletter ISO-/Installationsdurchlauf vorgesehen. Windows 10 und Server werden erst bei ihrer eigentlichen Freigabe jeweils separat installiert und getestet.

## Quell-ISO-Einhängung

Zusätzlich tests/Test-IsoStorage.ps1 mit Windows PowerShell ausführen. Der Test prüft erfolgreiche, fehlgeschlagene und zeitüberschreitende Aufträge sowie verspätete Laufwerksbuchstaben und die Unterscheidung zwischen vorhandenen und eigenen Einhängungen. Er verwendet Ersatz-Storage und verändert keine echten Laufwerke.

Ein kurzer isolierter Test der neuen Einhängung über den GUI-Hintergrundprozess mit den vorhandenen Windows-11- und VirtIO-Quellen war erfolgreich. Für den nächsten normalen Build die Oberfläche neu starten, damit der aktuelle Skriptstand geladen wird. Der vollständige Build mit dieser Änderung wurde anschließend vom Benutzer erfolgreich getestet; eine neue VM-Installation ist wegen dieser reinen Quellmedien-Behandlung nicht erforderlich.
## Aktuell: PC-Profil und Zusatzmenü

Die lokalen Tests decken alle vier Kombinationen aus VirtIO-Treibern und QEMU ab, außerdem fehlende/unbenötigte VirtIO-Pfade, Kopieren oder Auslassen der Tools, getrenntes uBlock/Edge, übersprungene FirstLogon-Schritte, XML mit Schlüssel und Sonderzeichen-Passwort sowie die Übergabe der GUI-Optionen an einen echten Kindprozess. Profilwechsel und Fehlerfälle werden ebenfalls geprüft. Dabei werden keine echten WIMs oder Registry-Einstellungen verändert.

Der folgende gebündelte PC-Test wurde am 16.09.2026 vom Benutzer als vollständig erfolgreich bestätigt (damals noch mit festem Kontonamen LabAdmin):

1. Oberfläche neu starten, Profil **pc-local** wählen. VirtIO-Auswahl muss deaktiviert sein; QEMU bleibt aus. Tools, Bing-Abschaltung und uBlock für diesen Test aktiv lassen. Optional einen zur Edition passenden Setup-Schlüssel eingeben; leer testet die Vorlage ohne festen Schlüssel.
2. ISO erstellen. Im Log darf keine VirtIO-ISO geöffnet und keine WIM-Treiberintegration ausgeführt werden. Status muss IncludeVirtioDrivers=false und QemuGuestAgent=false melden. ISO, Hashdatei und Erfolgsstatus prüfen.
3. In einer frischen UEFI-Test-VM eine von Windows ohne VirtIO erkannte Platte verwenden (beispielsweise SATA) und gegebenenfalls eine passende emulierte Netzwerkkarte. Im Setup muss die Zielpartition manuell ausgewählt werden. Ausschließlich die leere Testplatte verwenden.
4. LabAdmin-Anmeldung, Tools-Verknüpfung, Bing-/Websuche, Explorer und Windows-/Edge-Einstellungen prüfen. Mit Store-Zugriff muss uBlock Lite nachgeladen werden. Kein QEMU-Agent-Paket und kein installierter Guest Agent erwartet.
5. firstlogon-result.json muss Succeeded mit sieben erfolgreichen Schritten melden, sofern alle Optionen wie oben aktiv und der Tools-Ordner vorhanden sind. Setup-/QEMU-Logs sind bei deaktiviertem Agent nicht erforderlich.
6. Bei verwendetem Schlüssel Editionsauswahl prüfen; Aktivierung bleibt ein separater Vorgang. Produktschlüssel und Kennwort nicht mit Log-Auszügen oder Screenshots weitergeben.

Für die vier Schalter ist dank der lokalen Kombinationstests keine eigene VM-Installation pro Schalter vorgesehen. Der PC-Installationstest ersetzt keine Hardware-Kompatibilitätsprüfung auf den später eingesetzten Rechnern.

## Änderbarer Kontoname

Lokale Tests: VM-Vorgabe LabAdmin, PC-Vorgabe Winuser, Profilwechsel, Prozessübergabe mit Leerzeichen/& sowie XML-Konto/Anzeigename/AutoLogon mit identischen Namen; das Kennwort bleibt unverändert. Ungültige Namen werden vor Medienzugriff abgewiesen.

Beim nächsten ohnehin geplanten Installationstest einen eigenen Kontonamen setzen und prüfen, dass Anmeldung, Benutzerprofil, Tools-Verknüpfung und FirstLogon wie bisher funktionieren. Dafür jetzt keinen eigenen zusätzlichen 25-Minuten-Durchlauf ansetzen.

## Editionsauswahl ohne neue Installation testen

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-Editions.ps1` prüft den echten Abfrageprozess mit Ersatzmedien: Editionen, Zuordnung, leere Liste, fehlendes WIM, DISM-Fehler, Sperre und Cleanup. Der GUI-Test prüft zusätzlich die Liste, Erhalt der Auswahl, Fehleranzeige, Freigabe des Formulars und Zurücksetzen bei ISO-Wechsel.

Im neu gestarteten Builder die bekannte Windows-11-ISO auswählen und die Editionsliste prüfen. Windows 11 Pro sollte weiterhin ausgewählt sein, wenn es enthalten ist. Dieser Schritt braucht keinen ISO-Build und keine Installation. Den frei gewählten Kontonamen anschließend beim nächsten regulären Installationstest mitprüfen.

Prüfstand 16.09.2026: Builder-, GUI-, Editionsworker- und Storage-Tests mit Ersatzmedien erfolgreich. Der direkte Versuch mit der echten Windows-11-ISO aus der Agent-Shell wurde von Windows wegen fehlender erhöhter Rechte abgewiesen. Am 21.09.2026 hat der Benutzer den Testplan als erfolgreich bestätigt und die problemlose Installation auf einem Mini-PC gemeldet.

## DE/EN und Profileditor – ohne Neuinstallation

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\tests\Test-GuiProfiles.ps1
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\tests\Test-Gui.ps1
```

Die Tests verwenden WPF und Kopien der Profile in TEMP. Sie prüfen DE/EN und Rückwechsel, unveränderte Eingaben/Geheimnisse/Logs, dynamische Status- und Validierungstexte, Profilkopien, Speichern, Anführungszeichen in Profilwerten, Namenskollisionen, ungültige Namen, konkurrierende Änderungen und Abbrechen.

Manuell die Oberfläche neu starten, auf die US-Flagge und zurück auf DE klicken. Danach **Profil bearbeiten**, unter neuem Namen eine Testkopie speichern und kontrollieren, dass sie ausgewählt ist. Abbrechen und erneutes Öffnen prüfen. Für diese reinen GUI-Änderungen ist kein zusätzlicher ISO-/Installationstest erforderlich. Gewollte neue Profilinhalte können beim nächsten regulären Build mitgetestet werden.

## Neue Zielsysteme

Windows 10 und Server 2022/2025 (Desktop Experience und Core) sind implementiert. Die fünf erforderlichen echten Installationsdurchläufe und ihre gebündelten Prüfpunkte stehen in [MULTI-OS.md](MULTI-OS.md). Automatisierte Ersatzmedien-Tests ersetzen diese Durchläufe nicht.

## ISO-zuerst-Oberfläche (22.09.2026)

Ohne neuen Installationsdurchlauf prüfen: Start ohne ISO sperrt Optionen; nach Windows-10-Erkennung genau PC-Lokal/Proxmox VM und kein Core-Haken. Bei Server-ISO ist Core sichtbar, zunächst aus; Umschalten filtert die Editionen. Wechsel zurück zu Client-ISO entfernt Core und alte Editionen. Fehler bei der Erkennung dürfen keinen Build freigeben. Ein reines Core-Medium benötigt den ausdrücklich gesetzten Haken.

Automatisiert: `powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\tests\Test-MediaSelection.ps1`. Ergänzend prüfen Test-Editions.ps1 die Zielerkennung aus simulierten DISM-Metadaten und Test-Gui.ps1 den Hintergrundprozess einschließlich Fehlerfällen.

## Windows-10-Setup: ProductKey (24.09.2026)

Erster echter Test von Windows 10 Pro / Proxmox VM: Setup meldet, dass ProductKey nicht aus der Antwortdatei gelesen werden kann. Build ohne Benutzerschlüssel erfolgreich, erzeugte XML ohne ProductKey-Knoten. Korrektur: editionsgenauer Standard-Setup-Schlüssel aus product.ini für Windows 10, Benutzereingabe und vorhandene Vorlagenschlüssel haben Vorrang. Keine Umstellung auf KMS und keine automatische Aktivierung.

Erneut testen: Windows-10-Pro-ISO bei leerem Schlüsselfeld neu bauen, neue ISO in Proxmox einlegen und Setup neu starten. Prüfen, ob Setup die bisherige Fehlerstelle passiert und die gewünschte Edition installiert. Erst danach als installationsgeprüft markieren. Automatisiert: Test-SetupKey.ps1 und Test-Builder.ps1; diese ersetzen den Setup-Test nicht.

## Bestätigte Proxmox-Installationen (24.09.2026)

Benutzerrückmeldung nach echten Installationen: Windows 10 Pro, Server 2022 Desktop Experience/Core und Server 2025 Desktop Experience/Core liefen als Proxmox-VM mit QEMU Guest Agent erfolgreich durch. Unter Windows 10 wurden zusätzlich Edge-Einstellungen, die Erweiterung und rein lokale Suche bestätigt. Der vorherige Windows-10-ProductKey-Abbruch trat beim Wiederholungstest nicht mehr auf.

Offener Nebenbefund bei Windows 10: sichtbare desktop.ini auf dem Desktop und im Editor geöffnet. Benutzer bestätigt: automatisch nach der Anmeldung geöffnet. Explorer.ps1 setzt bereits ShowSuperHidden=0; Dateiattribute und Herkunft sind daher zu prüfen, bevor eine Korrektur festgelegt wird. Keine vollständige Fehlerfreiheit behauptet. Die Rückmeldung betrifft Proxmox-VMs, keine zusätzlichen Tests der neuen lokalen Hardwareprofile.

Gezielte Reparatur ergänzt: scripts/Repair-DesktopIni.ps1 setzt an vorhandenen desktop.ini-Dateien in Benutzer-/gemeinsamem Desktop und Autostart Hidden und System, protokolliert die vorherigen Attribute und erhält Inhalte sowie übrige Attribute. Explorer.ps1 ruft die Reparatur bei neuen Installationen innerhalb der Explorer-Anpassungsgruppe auf. Auf bestehenden VMs das Skript als Administrator unter dem betroffenen Benutzer ausführen, Editor schließen und neu anmelden. Fehlende Schutzattribute sind eine Arbeitshypothese; Ausgabe und Wiederholungstest müssen die Ursache bestätigen. Ein bereits beim ersten Login geöffnetes Editorfenster wird nicht geschlossen; FirstLogon garantiert keine Ausführung vor dem Autostart. Keine Neuinstallation für die Prüfung erforderlich.

### desktop.ini: bestätigte Rechteursache und Reparatur v3

VM-Diagnose: erhöhte LabAdmin-Sitzung, öffentliche Desktop- und gemeinsame Autostart-desktop.ini nur Archive. Besitzer TrustedInstaller; Administratoren und SYSTEM jeweils nur ReadAndExecute. Benutzerdateien besitzen bereits Hidden/System. Deshalb scheitert der bisherige FileInfo.Attributes-Schreibzugriff auch erhöht.

Reparatur v3 versucht nach fehlgeschlagenem Standardzugriff FILE_WRITE_ATTRIBUTES mit Backup-Semantik und vorübergehend aktiviertem SeRestorePrivilege. Besitzer und DACL werden nicht verändert; das vorherige Privileg wird im finally wiederhergestellt. Nur desktop.ini-Dateien, keine Verzeichnisse oder Reparse-Dateien; Dateiinhalte und Zeitstempel bleiben erhalten. Diagnose bleibt rein lesend. Der Starttext enthält eindeutig „repair v3“.

Test-DesktopIniProtected.ps1 prüft den nativen Dateiattributzugriff und den Erhalt von Inhalt, Besitzer, ACL und Schreibzeit an temporären Dateien. Ohne erhöhtes Windows-Token wird der geschützte Zugriff erwartungsgemäß abgewiesen; die erfolgreiche Wiederherstellung auf den TrustedInstaller-Dateien muss noch in der VM bestätigt werden. Reparatur dort als Administrator ausführen, Editor schließen, ab- und anmelden. Keine Neuinstallation erforderlich. Die Herkunft der fehlenden Attribute im Installationsabbild ist noch nicht abschließend geklärt.
