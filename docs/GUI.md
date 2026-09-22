# Grafischer Builder

## Start

Im Repository `Start-Builder.cmd` doppelt anklicken. Windows fragt bei Bedarf nach Administratorrechten, weil der Build WIM-Dateien einhängt und bearbeitet. Die Abfrage erfolgt vor der Kennworteingabe. Es ist keine zusätzliche Installation und kein Webserver nötig; verwendet werden Windows PowerShell 5.1 und WPF.

1. Zuerst **Windows-ISO** auswählen. Der Builder erkennt Zielsystem und Editionen aus den WIM-/ESD-Metadaten. Bei eingetipptem Pfad mit **↻** neben der ISO-Auswahl einlesen. Bis zur erfolgreichen Erkennung sind die Build-Optionen gesperrt.
2. **PC-Lokal** oder **Proxmox VM** auswählen. Nur diese zwei Einsatzarten stehen im Dropdown. Passende Antwortdatei, Treiberzuordnung und Vorgaben werden intern automatisch gewählt.
3. Bei Server-ISOs mit Core-Editionen erscheint **Core – Headless**, standardmäßig ausgeschaltet. Ohne Haken werden Desktop-Experience-Editionen angezeigt, mit Haken nur Core-Editionen. Ein reines Core-Medium verlangt das ausdrückliche Setzen des Hakens.
4. Edition, optionale VirtIO-ISO, Anpassungen, Kontoname, Kennwort und optionalen Produktschlüssel prüfen. **PC-Lokal** verwendet standardmäßig keine VirtIO-Treiber und keinen QEMU-Agent.
5. **ISO erstellen** starten; danach ISO und Prüfsumme über die Ergebnisbuttons öffnen.

Ein ISO-Wechsel oder eine fehlgeschlagene Erkennung entfernt die bisherigen Editionen und setzt Core zurück. Die Editionsauswahl enthält ausschließlich zum Modus passende Einträge der erkannten ISO; freie Eingabe ist nicht mehr vorgesehen. Vor dem Start werden Auswahl und internes Profil nochmals abgeglichen. Die Abfrage läuft im Hintergrund, hält die Build-Sperre und räumt nur selbst angeforderte ISO-Einhängungen auf.

Dauerhafte Vorgaben stehen in den PSD1-Dateien; Änderungen der Kästchen im Hauptfenster gelten nur für diesen Lauf. Im separaten Profileditor lassen sich die gespeicherten Vorgaben bearbeiten. Die vier bisherigen Gruppen bleiben im Profil steuerbar; uBlock ist unabhängig von Edge.

## Sprache umschalten

Die deutsche und die US-Flagge oben rechts schalten die Oberfläche sofort zwischen Deutsch und Englisch um. Beide Flaggen sind kleine Vektorgrafiken und benötigen keine Downloads oder Emoji-Schriftarten. Deutsch ist der Standard beim Start. Die Umschaltung verändert keine Eingaben, Kennwörter, Profile oder Installationssprache. Auch während eines Builds bleiben die Sprachbuttons bedienbar. Originalprotokolle und externe technische Fehlermeldungen behalten ihre Sprache.

## Profilvorgaben bearbeiten

**Profil bearbeiten** öffnet nach erfolgreicher ISO-Erkennung die passende interne Vorlage für Zielsystem, Einsatzart und Desktop/Core. Kontoname, Tools-Verzeichnis, VirtIO und Anpassungen bleiben bearbeitbar. Profilname, Zielsystem, Installationsvariante, Antwortdatei und Editionsvorgabe sind schreibgeschützt, da sie automatisch zugeordnet werden. Die konkrete Edition wird im Hauptfenster ausgewählt.

Speichern aktualisiert diese Vorlage; Abbrechen lässt sie unverändert. Zwischenzeitliche Dateiänderungen werden erkannt. Kennwort und Produktschlüssel werden nicht gespeichert. Die PSD1-Datei wird einheitlich formatiert; Kommentare werden nicht übernommen. Eigene zusätzliche PSD1-Profile bleiben über die CLI verwendbar und erscheinen nicht im Dropdown.

## Laufender Build

Der vorhandene Builder läuft in einem eigenen, unsichtbaren PowerShell-Prozess. Das Fenster bleibt bedienbar und aktualisiert Schritt, Laufzeit und Protokoll. Die Fortschrittsleiste zeigt den Schrittfortschritt; ein langer DISM-Schritt kann längere Zeit unverändert bleiben.

Die Eingabefelder werden während des Builds gesperrt. Minimieren ist möglich; normales Schließen wird bis zum Abschluss verhindert. Ein Abbruchknopf ist noch nicht enthalten, da der Builder noch keinen kontrollierten Abbruch während DISM unterstützt.

Erfolg wird erst nach Ende des Prozesses mit Exitcode 0 und einer passenden, erfolgreichen Statusdatei samt Ergebnisdateien angezeigt. Fehlende, ungültige oder widersprüchliche Ergebnisse führen zur Fehleranzeige. Details stehen im Log oder bei frühen Fehlern in der Fehlerausgabe des Prozesses.

## Kennwort und Einstellungen

Kennwort und optionaler Produktschlüssel werden nur über die Umgebung des Kindprozesses übergeben; beide stehen nicht in dessen Befehlszeile. Nach dem Start werden beide Felder geleert. Der Builder übernimmt sie in die erzeugte Antwortdatei unter build/iso-root und in die ISO, aber nicht in Profil, Protokoll oder JSON-Status. Ein leeres Schlüsselfeld übernimmt keinen Schlüssel aus der Umgebung der GUI. Format, Editionsbezug, getrennte Aktivierung und die OEM-Einschränkung für QEMU sind in der README beschrieben.

## Tests ohne neue VM-Installation

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\tests\Test-Gui.ps1
```

Der Test benötigt keine Administratorrechte. Er lädt das echte WPF-Fenster ohne es anzuzeigen und betreibt die echten Timer-/Prozessfunktionen mit einem Ersatz-Builder in einem TEMP-Ordner. Geprüft werden Eingaben, Argumente mit Sonderzeichen, Kennwortübergabe, Protokollanzeige, Erfolg, verschiedene Fehlerfälle und die Abweisung ungültiger Zielsysteme. Es werden keine echten ISOs gebaut und keine Windows-Anpassungen ausgeführt.

Für den manuellen Test zunächst nur das Fenster öffnen und die Felder prüfen. Danach einen normalen Windows-11-Build aus der Oberfläche starten. Das Windows-11-PC-Profil wurde auf einem Mini-PC erfolgreich installiert. Für die neuen Zielsysteme stehen echte Installationstests aus; siehe [MULTI-OS.md](MULTI-OS.md). Details stehen in [TESTPLAN.md](TESTPLAN.md).

Bei Core-Profilen sind Bing-/Websuche und uBlock im Hauptfenster deaktiviert. Im Profileditor müssen alle Desktop-Anpassungen ausgeschaltet sein; ungültige Kombinationen werden beim Speichern abgewiesen. Die Profilzusammenfassung zeigt bei neuen Zielsystemen den ausstehenden Installationstest an.
