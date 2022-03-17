# Consent-Extraktion für den 6. Projectathon der MII
Datum: 17.03.22

Autorin: [julia.palm@med.uni-jena.de](mailto:julia.palm@med.uni-jena.de).

*Für eine Dokumentation der Änderungen, die seit Veröffentlichung des Skriptes gemacht wurden, siehe ganz unten.*

## Einführung

Dieser Branch des Projektes Projectathon-smith2 enthält eine Beispielimplementierung zur Filterung von konsentierten Encountern auf einem FHIR-Server. Das Skript selektiert alle Fälle (Einrichtungskontakte) auf dem FHIR-Server, die in den Gültigkeitsbereich einer definierten Consent-Provision fallen. 


## Funktionsweise
Neben der Einstellung von Authentifizierungsdaten für den Server können Folgende Einstellungen in der Datei config.R vorgenommen werden:
- `base`: Base-Url des FHIR-Servers
- `provisionCode`: Der Code der Provision, deren Gültigkeit konkret beurteilt werden soll, z.B. `"2.16.840.1.113883.3.1937.777.24.5.3.8"` für "MDAT_wissenschaftlich_nutzen_EU_DSGVO_NIVEAU"
- `identifierSystem`: Das (vermutlich DIZ-spezifische) System aus dem der Identifier stammen soll, der aus den Encounter-Ressourcen extrahiert wird.

Das Skript geht dann wie folgt vor:

1) Downloade alle Consent-Ressourcen, die auf dem in `base` definierten FHIR-Server vorhanden sind. Beispiel-Request: `base/Consent`

2) Extrahiere die Patienten-Id und den Gültigkeitszeitraum der in `provisionCode` definierten Provision.

3) Lade zu jedem Consent alle Einrichtungskontakt-Encounter, welche zu dem referenzierten Patienten gehören und mit dem Gültigkeitszeitraum aus 2) überlappen. Beispiel-Request: `base/Encounter?date=ge2020-09-01&date=le2050-08-31&subject=Patient/1&type=einrichtungskontakt`

4) Extrahiere die logical IDs der Patienten- und Encounter-Ressource(n), sowie den Identifier des Encounters aus `identifierSystem` und Start und Endzeitpunkt des Encounters (zu Validierungszwecken).

5) Erzeuge eine csv-Tabelle "Ergebnisse/Consented_Encounters.csv" in der jede Zeile einen konsentierten Fall (Einrichtungskontakt-Encounter) darstellt, mit den folgenden Variablen/Spalten:

|Variable             | Bedeutung|
|---------------------|----------|
|Patient.id                         | Logical id der Patient Ressource|
|Encounter.id                       | Logical id der Encounter Ressource|
|Encounter.identifier               | Identifier des Encounters in dem System, welches in `identifierSystem` in config.R angegeben wurde.|
|Encounter.start                    | Startzeitpunkt des Encounters|
|Encounter.end                      | Stoppzeitpunkt des Encounters|
|provision.display                  | Der display-Wert der Provision, die in `provisionCode` in config.R angegeben wurde |
|provision.start                    | Startzeitpunkt der Gültigkeit der gewählten Provision |
|provision.end                      | Endzeitpunkt der Gültigkeit der gewählten Provision |


Basierend auf diesen Informationen können nun z.B. alle Ressourcen gezogen werden, die zu einem der konsentierten Encounter gehören oder die in das in Provision angegebene Zeitfenster fallen.

## Verwendung
Es gibt zwei Möglichkeiten das R-Skript auszuführen: Direkt in R oder in einem Docker Container. Beide werden im folgenden beschrieben.

### Ausführung in R
#### Vor der ersten Nutzung
1. Um die Consent-Extraktion durchzuführen, muss der Inhalt des Git-Repository auf einen Rechner (PC, Server) gezogen werden, von dem aus der REST-Endpunkt des gewünschten FHIR-Servers (z.B. FHIR-Server der Clinical Domain im DIZ) erreichbar ist. 

2. Auf diesem Rechner muss R (aber nicht notwendigerweise RStudio) als genutzte Laufzeitumgebung installiert sein.

3. Die mitgelieferte Datei `./config.R.default` muss nach `./config.R` kopiert werden und lokal angepasst werden (s.o.); Erklärungen dazu finden sich auch direkt in dieser Datei. 


#### Start des Skripts
Beim ersten Start des Skripts wird überprüft, ob die zur Ausführung notwendigen R-Pakete (`fhircrackr`, `data.table`) vorhanden sind. Ist dies nicht der Fall, werden diese Pakete nachinstalliert – dieser Prozess kann einige Zeit in Anspruch nehmen.


#### R/RStudio
Durch Öffnen des R-Projektes (`Projectathon6-smith2.Rproj`) mit anschließendem Ausführen der Datei `consent.R` innerhalb von R/RStudio. Auch hier werden beim ersten Ausführen ggf. notwendige R-Pakete nachinstalliert.


## Ausführung im Docker Container
Um die Abfrage in einem Docker Container laufen zu lassen gibt es drei Möglichkeiten:

**A) Image bauen mit Docker Compose:**

1. Git-Repository klonen: `git clone -b consent_extraction https://github.com/medizininformatik-initiative/Projectathon6-smith2.git projectathon6-consent_extraction`
2. Verzeichniswechsel in das lokale Repository: `cd projectathon6-consent_extraction`
3. Konfiguration lokal anpassen: `./config.R.default` nach `./config.R` kopieren und anpassen 
4. Image bauen und Container starten: `docker compose up -d`

Zum Stoppen des Containers `docker compose stop`. Um ihn erneut zu starten, `docker compose start`.

**B) Image bauen ohne Docker Compose**

1. Git-Repository klonen: `git clone -b consent_extraction https://github.com/medizininformatik-initiative/Projectathon6-smith2.git projectathon6-consent_extraction`
2. Verzeichniswechsel in das lokale Repository: `cd projectathon6-consent_extraction`
3. Image bauen: `docker build -t projectathon6-consent_extraction .` 
4. Konfiguration lokal anpassen: `./config.R.default` nach `./config.R` kopieren und anpassen 
5. Container starten: `docker run --name projectathon6-consent_extraction -v "$(pwd)/Ergebnisse:/Ergebnisse" -v "$(pwd)/config.R:/config.R" projectathon6-consent_extraction`

Erklärung:

-  `-v "$(pwd)/config.R:/config.R""` bindet die lokal veränderte Variante des config-Files ein. Wenn dieses geändert wird, reicht es, den Container neu zu starten (`docker stop projectathon6-consent_extraction`, config.R ändern, dann `docker start projectathon6-consent_extraction`), ein erneutes `docker build` ist nicht nötig.


-----------------------------------------------------------------------------------------------

## Selbstsignierte Server-Zertifikate

Falls der verwendete FHIR-Server ein selbst-signiertes Zertifikat für HTTPS verwendet, ist es notwendig das zugehörige Root-Zertifikat zu übergeben. R nutzt die Systemzertifikate des Betriebssystems hierfür.

Wenn die Abfrage direkt (ohne Docker) ausgeführt wird muss sich das Root-Zertifikat in den systemweit vertrauenswürdigen Zertifikaten befinden. Dies ist Betriebssystemabhängig. Für die Ausführung im Docker-Container kann das Root-Zertifikat als Volume eingebunden werden.

**Docker**
Angenommen das Zertifikat liegt unter `./localca.pem` muss folgender zusätzlicher Parameter beim `docker run ...`-Befehl übergeben werden:
`-v ./localca.pem:/usr/local/share/ca-certificates.crt`

**Docker-Compose**
Angenommen das Zertifikat liegt unter `./localca.pem` muss folgender Eintrag in der `docker-compose.yml` gemacht werden:
```
[...]
  volumes:
  - ./localca.pem:/usr/local/share/ca-certificates.crt
[...]
```

Hintergrund:
Das Image basiert auf Debian und führt bei jedem Start den Befehl `update-ca-certificates` aus, mit dem es die Zertifikate unter `/usr/local/share/ca-certificates` einliest und zu den Vertrauenswürdigen hinzufügt.
