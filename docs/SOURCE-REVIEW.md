# Prüfung des öffentlichen Quellstands

Stand: 25.09.2026, Vorbereitung von `prerelease/v0.7.0-beta.1`.

## Umfang und Ergebnis

Die vom Git-Server angebotenen drei Branches wurden mit den lokalen Referenzen abgeglichen. Die Ausgangshistorie bis `dea9e7e` umfasst 21 Commits und 92 unterschiedliche Dateiobjekte. Dateinamen, Größen, Autorenmetadaten, persönliche/interne Pfade, Adressen, Passwort-/Tokenmuster und Antwortdateien wurden geprüft; auffällige Treffer wurden manuell eingeordnet. Anschließend werden der ergänzte Prerelease-Stand und sein Git-Quellarchiv kontrolliert.

- Keine Windows-/VirtIO-ISOs, WIM-/ESD-Abbilder, ausführbaren Fremdprogramme, Treiberpakete oder Archive in der untersuchten Git-Historie. Im Tools-Ordner wird nur README.md verfolgt.
- Keine echten Zugangsdaten in den untersuchten Dateiständen gefunden. Antwortdateien verwenden Passwortplatzhalter. Tests enthalten erkennbare synthetische Werte. Der vorhandene generische Windows-Setup-Schlüssel ist kein persönlicher Lizenzschlüssel.
- Treffer auf `10.x.x.x` waren Windows-Buildnummern in Tests, keine internen Netzwerkziele. Kein persönlicher Benutzerprofilpfad oder internes Serverziel im untersuchten Quelltext gefunden. Die lokale Remote-Konfiguration ist nicht Teil eines Git-Quellarchivs.
- Persönliche E-Mail-Adresse in historischen Autoren-/Committerfeldern gefunden. Vor Veröffentlichung wird eine separate Historie mit `possumdesign@users.noreply.github.com` vorbereitet. Die Originalhistorie bleibt zunächst intern erhalten. Keine automatische erzwungene Aktualisierung des Servers.
- Eigener Projektcode steht unter MIT, Copyright 2026 possumdesign. Keine zusätzliche Weitergabelizenz für fremde Programme wird behauptet.

Dies ist eine Prüfung des Git-Quellstands, keine Garantie gegen jedes denkbare Geheimnis. Nicht umfasst sind Serverdaten außerhalb von Git, etwa Issues, Wiki, Anhänge, bereits veröffentlichte Releases, fremde Forks oder Plattform-Caches. Die Spiegelkonfiguration und mögliche bereits veröffentlichte GitHub-Daten benötigen gesonderte Beachtung.

## Lieferumfang

Veröffentlicht werden Quellcode, Profile, Antwortvorlagen, Tests und Dokumentation. Windows, VirtIO/QEMU-Pakete, ADK/oscdimg, Tools, erzeugte ISOs und Logs gehören nicht in das Release-Archiv. Nutzer beziehen diese Komponenten selbst. uBlock Origin Lite wird bei aktivierter Option über eine Edge-Richtlinie aus dem Store installiert; ein Erweiterungspaket liegt nicht im Repository.

`tools/` wird vollständig ignoriert, mit der einzigen Ausnahme `tools/README.md`. Das schützt auch Begleitdateien, Konfigurationen und andere Archivformate. Alternative Tools-Verzeichnisse benötigen eigene Ignore-Regeln. `.gitignore` entfernt keine historischen oder bereits verfolgten Dateien.

Release-Quellpakete mit `git archive` aus dem geprüften Commit erzeugen, niemals den gesamten lokalen Arbeitsordner zippen. Dieser kann private Tools, Medien und Antwortdateien mit Kennwörtern enthalten.

## Historie und Spiegelung

Ein Push zum internen Git-Server kann durch die eingerichtete Spiegelung eine öffentliche Veröffentlichung auslösen. Deshalb die anonymisierte Historie erst nach Prüfung der betroffenen Branches und expliziter Freigabe übertragen. Die alten Branches dürfen nicht parallel unbereinigt in den öffentlichen Spiegel gelangen. `.mailmap` allein entfernt keine E-Mail-Adressen aus alten Commitobjekten.
