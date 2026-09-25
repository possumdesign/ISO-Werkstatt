# Eigene portable Tools / Your portable tools

Dieses Repository enthält keine Programme oder Pakete Dritter.

Nach der ISO-Erkennung unter **Zusätzliche Anpassungen → Tools-Ordner öffnen** den Ordner der aktuellen Profilvorlage öffnen. Eigene portable Programme, Unterordner oder ZIP-Dateien dort ablegen. Der Ordner wird bei Bedarf angelegt. Eine ausgeschaltete Tools-Option verhindert nur die Übernahme in die ISO, nicht das Öffnen des Ordners.

Bei aktivierter Tools-Option kopiert der Builder den Inhalt nach `C:\ISO-Werkstatt\Tools`. ZIP-Dateien werden jeweils in einen Unterordner mit dem Archivnamen entpackt; andere Archive werden nur kopiert. Programme werden nicht automatisch installiert. Auf Desktop-Systemen entsteht eine Verknüpfung, auf Server Core nur der Ordner.

Dateien selbst beim jeweiligen Hersteller beziehen und dessen Lizenzbedingungen beachten, insbesondere beim Weitergeben einer erzeugten ISO. Keine Kennwörter, Tokens, persönlichen Konfigurationen oder anderen vertraulichen Dateien ablegen. Die MIT-Lizenz dieses Projekts gilt nicht für eigene hinzugefügte Fremdsoftware.

Git ignoriert im Standardordner `tools/` alle Inhalte außer dieser Anleitung. Bei abweichendem ToolsDirectory eigene Ausschlussregeln ergänzen. Bereits verfolgte oder mit `git add -f` hinzugefügte Dateien werden durch .gitignore nicht geschützt.

## English

No third-party programs are bundled. After ISO detection, choose **Additional adjustments → Open tools folder** and add your own portable programs, folders or ZIP archives. Enable the tools option to include them in your ISO. Obtain files from their publishers and comply with their licenses, especially when redistributing an ISO. Do not include credentials or personal configuration. Only this README is tracked in the default tools folder.
