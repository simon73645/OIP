# Inbetriebnahme-Anleitung: Sensoren & SPS-Verbindung

Diese Anleitung beschreibt Schritt für Schritt, wie Sie die Sensoren (Color Sensor, Diffuse Sensor, Laser Sensor) in einer einfachen Simulation in Betrieb nehmen und sich mit einer Siemens SPS verbinden.

---

## Inhaltsverzeichnis

1. [Voraussetzungen](#1-voraussetzungen)
2. [SPS-Verbindung im Spiel herstellen](#2-sps-verbindung-im-spiel-herstellen)
3. [Sensoren platzieren und konfigurieren](#3-sensoren-platzieren-und-konfigurieren)
4. [Sensor-Datentypen und SPS-Adressen](#4-sensor-datentypen-und-sps-adressen)
5. [TIA Portal V19 – SPS-Programm erstellen](#5-tia-portal-v19--sps-programm-erstellen)
6. [End-to-End Test](#6-end-to-end-test)
7. [Fehlerbehebung](#7-fehlerbehebung)

---

## 1. Voraussetzungen

### Hardware
- Siemens SPS (z. B. S7-1500, *S7-1200*, S7-300 oder S7-400)
- Ethernet-Verbindung zwischen PC und SPS
- PC mit Godot 4.6.2 und dem Projekt

### Software
- **Godot 4.6.2** mit .NET-Unterstützung (für die C#-Komponenten des siemens_plugin)
- **TIA Portal V19** (für die SPS-Programmierung)
- Das Projekt muss gebaut sein (`dotnet build` im Projektverzeichnis)

### Netzwerk
- PC und SPS müssen sich im gleichen Netzwerk befinden
- Beispiel: PC = `10.64.77.17`, SPS = `10.64.77.102`
- Stellen Sie sicher, dass die Windows-Firewall den Port **102** (S7-Kommunikation) nicht blockiert

### SPS-Einstellungen (TIA Portal)
- **PUT/GET-Kommunikation** muss aktiviert sein:
  - Gehen Sie in TIA Portal zu: *Gerätekonfiguration → Eigenschaften → Schutz & Sicherheit → Verbindungsmechanismen*
  - Aktivieren Sie: **"Zugriff über PUT/GET-Kommunikation vom entfernten Partner erlauben"**
- Notieren Sie sich die **IP-Adresse**, den **Rack** und den **Slot** der SPS

---

## 2. SPS-Verbindung im Spiel herstellen

### Schritt 1: Spiel starten
Starten Sie das Spiel über Godot (F5 oder Play-Button). Sie sehen die Simulation mit der Menüleiste oben.

### Schritt 2: Connection-Dialog öffnen
Klicken Sie in der oberen Menüleiste auf den Button **"🔌 Connection"**. Es öffnet sich ein Fenster mit den Verbindungseinstellungen.

### Schritt 3: Verbindungsparameter eingeben

| Parameter   | Beschreibung                                          | Beispielwert     |
|-------------|-------------------------------------------------------|------------------|
| **IP Address** | IP-Adresse der SPS                                  | `10.64.77.102`    |
| **CPU Type**   | Typ der Siemens-CPU                                 | `S7-1200`        |
| **Rack**       | Rack-Nummer (meist 0)                               | `0`              |
| **Slot**       | Slot-Nummer (S7-1500: meist 1, S7-300/400: meist 2) | `1`              |

### Schritt 4: Verbindung testen (optional)
Klicken Sie auf **"Ping"**, um zu prüfen, ob die SPS erreichbar ist. Das Ergebnis wird im Info-Bereich angezeigt.

### Schritt 5: Verbindung herstellen
Klicken Sie auf **"Connect"**. Der Status wechselt zu **grün ("Connected")**, wenn die Verbindung erfolgreich ist.

### Schritt 6: Online-Modus aktivieren
Klicken Sie auf **"Online"**, um den Datenaustausch zu starten. Erst wenn der Online-Modus aktiv ist, werden Daten zwischen Simulation und SPS übertragen.

### Verbindungsstatus-Anzeige
In der oberen rechten Ecke der Menüleiste sehen Sie einen **farbigen Kreis**:
- 🟢 **Grün** = Verbunden
- 🔴 **Rot** = Nicht verbunden

Klicken Sie auf den Kreis für detaillierte Verbindungsinformationen.

---

## 3. Sensoren platzieren und konfigurieren

### Verfügbare Sensoren

| Sensor          | Beschreibung                                    | Ausgabewert         | SPS-Datentyp |
|-----------------|------------------------------------------------|---------------------|--------------|
| **Diffuse Sensor** | Erkennt Objekte in Reichweite (ja/nein)       | `true` / `false`    | `BOOL`       |
| **Laser Sensor**   | Misst Abstand zum erkannten Objekt            | Distanz in Metern   | `REAL`       |
| **Color Sensor**   | Erkennt Farbe des Objekts                     | Ganzzahl (Farbcode) | `DINT`       |

### Sensor platzieren

1. Im linken **Equipment-Panel** die Kategorie **"Sensors"** wählen
2. Den gewünschten Sensor anklicken (z. B. "Diffuse Sensor")
3. In der Simulation an die gewünschte Position klicken
4. Mit **R** kann der Sensor vor dem Platzieren rotiert werden

### Einfaches Simulationsszenario aufbauen

Für einen Test empfehlen wir folgendes Setup:

1. **Belt Conveyor** platzieren (Kategorie "Conveyors")
2. **Box Spawner** am Anfang des Conveyors platzieren (Kategorie "Spawners")
3. **Diffuse Sensor** neben dem Conveyor platzieren, so dass der Sensorstrahl den Conveyor kreuzt
4. Optional: **Color Sensor** für Farberkennung
5. Optional: **Laser Sensor** für Abstandsmessung

### Automatische Sensor-Registrierung

Wenn die SPS-Verbindung aktiv ist (Status **grün** und **Online** aktiviert), werden die Sensoren **automatisch** beim PLC registriert. Der **PlcSensorBridge** erkennt alle Sensoren in der Simulation und erstellt die passenden Datenitems (BoolItem, RealItem, DIntItem) unter dem PLC-Node.

**Wichtig:** Die automatische Registrierung erfolgt, sobald:
1. Die SPS-Verbindung erfolgreich hergestellt wurde (grüner Status)
2. Der **Online-Modus** aktiviert ist
3. Sensoren im **SimulationRoot** platziert sind

Auch Sensoren, die **nach** dem Verbindungsaufbau platziert werden, werden automatisch erkannt und registriert.

### Sensor-Einstellungen (In-Game UI)

Wenn Sie einen Sensor in der Simulation **anklicken** (im Select-Modus), öffnet sich auf der rechten Seite ein **Sensor-Settings-Panel**. Dort sehen Sie:

- **Typ**: Art des Sensors (Diffuse / Laser / Color)
- **Datentyp**: Der zugehörige SPS-Datentyp (BOOL / REAL / DINT)
- **SPS-Adresse**: Die automatisch zugewiesene Merker-Adresse (z. B. M0.0, MD4, MD8)
- **PLC-Status**: Ob die Verbindung aktiv ist

#### Adresse manuell konfigurieren

Im Sensor-Settings-Panel können Sie die SPS-Adresse auch **manuell anpassen**:

1. Sensor in der Simulation auswählen (anklicken)
2. Im Panel rechts den gewünschten **Start-Byte** eingeben
3. Für BOOL-Sensoren: auch das **Bit** (0–7) wählen
4. Auf **"Adresse übernehmen"** klicken

> **Beispiel:** Um den DiffuseSensor auf Adresse `M2.3` zu legen, geben Sie Start-Byte = 2 und Bit = 3 ein.

---

## 4. Sensor-Datentypen und SPS-Adressen

Die Sensoren schreiben ihre Werte standardmäßig in den **Merker-Bereich (Memory)** der SPS. Die Adresszuordnung erfolgt **automatisch** durch den PlcSensorBridge mit folgender Logik:

- **BOOL-Sensoren** (Diffuse Sensor): Belegen 1 Byte, Startadresse wird sequenziell vergeben
- **REAL-Sensoren** (Laser Sensor): Belegen 4 Bytes, werden auf 4-Byte-Grenzen ausgerichtet
- **DINT-Sensoren** (Color Sensor): Belegen 4 Bytes, werden auf 4-Byte-Grenzen ausgerichtet

### Standard-Adress-Schema (bei einem Sensor pro Typ)

| Sensor          | Datentyp | SPS-Bereich | Standard-Adresse |
|-----------------|----------|-------------|------------------|
| Diffuse Sensor  | BOOL     | Memory (M)  | `M0.0`           |
| Laser Sensor    | REAL     | Memory (MD) | `MD4`            |
| Color Sensor    | DINT     | Memory (MD) | `MD8`            |

> **Hinweis:** Bei mehreren Sensoren des gleichen Typs werden die Adressen automatisch inkrementiert. Zum Beispiel: Zweiter Diffuse Sensor → `M1.0`, zweiter Laser Sensor → `MD12` usw. Die Adressen können über das Sensor-Settings-Panel auch manuell angepasst werden.

### Manuelle Konfiguration

Die Adressen können auf zwei Arten konfiguriert werden:

**Im Spiel (empfohlen):**
1. Sensor auswählen (anklicken)
2. Im rechten **Sensor-Settings-Panel** die gewünschte Adresse eingeben
3. Auf **"Adresse übernehmen"** klicken

**Im Godot Editor (fortgeschritten):**
1. Öffnen Sie die Szene im Editor
2. Navigieren Sie zum PLC-Node → **SensorBridgeGroup**
3. Wählen Sie das gewünschte DataItem (z. B. `Sensor_DiffuseSensor`)
4. Passen Sie die Eigenschaften an:
   - **DataType**: Memory (131), DataBlock (132), Input (129), Output (130)
   - **StartByteAdr**: Startadresse im Byte-Bereich
   - **BitAdr**: Bit-Adresse (nur für BOOL)
   - **DB**: Datenbaustein-Nummer (nur bei DataBlock)

---

## 5. TIA Portal V19 – SPS-Programm erstellen

### Schritt 1: Neues Projekt anlegen

1. Öffnen Sie **TIA Portal V19**
2. Erstellen Sie ein neues Projekt: *Projekt → Neu erstellen*
3. Fügen Sie Ihre SPS hinzu: *Geräte → Neues Gerät hinzufügen*
4. Wählen Sie den passenden CPU-Typ (z. B. **CPU-1212C AC/DC/Rly**)

### Schritt 2: PUT/GET aktivieren

1. Doppelklicken Sie auf die CPU in der Geräteübersicht
2. Gehen Sie zu: *Eigenschaften → Allgemein → Schutz & Sicherheit → Verbindungsmechanismen*
3. Haken setzen bei: **"Zugriff über PUT/GET-Kommunikation vom entfernten Partner erlauben"**

### Schritt 3: IP-Adresse konfigurieren

1. In der Gerätekonfiguration → *PROFINET-Schnittstelle*
2. Setzen Sie die IP-Adresse (z. B. `10.64.77.102`)
3. Subnetzmaske: `255.255.255.0`

### Schritt 4: Merker-Variablen anlegen

Erstellen Sie in der **PLC-Variablen-Tabelle** die Variablen, die den Sensoren entsprechen. 
Das ganze findet sich unter dem Ordner "PLC-Variablen" in der PLC Hirachie. 
Hier einmal auf "Neue Variablentabelle anlegen" drücken und in der neuen 
Tabelle folgendes Eintragen:

| Name              | Datentyp | Adresse  | Beschreibung                         |
|-------------------|----------|----------|--------------------------------------|
| `DiffuseSensor1`  | Bool     | `M0.0`   | Diffuse Sensor – Objekt erkannt      |
| `LaserDistance1`   | Real     | `MD4`    | Laser Sensor – Distanz in Metern     |
| `ColorValue1`     | DInt     | `MD8`    | Color Sensor – Farbwert (1=Rot, 2=Grün, 3=Blau) |

> **Hinweis:** Die Adressen hier müssen mit den Adressen in der Simulation übereinstimmen. Prüfen Sie die Adressen im **Sensor-Settings-Panel** der Simulation, wenn Sie diese manuell geändert haben.

### Schritt 5: Beispiel-Programm in OB1 (Main)
1. Projektnavigation: Gehe in der Baumstruktur links wieder zu der CPU.

2. Programmbausteine: Öffne den Ordner "Programmbausteine".

3. Main (OB1): Dort findest du einen Baustein namens "Main [OB1]". Mache einen Doppelklick darauf.

**Sollte der Baustein keine Möglichkeit haben SCL Code ausführen zu können -> Baustein löschen und neuen Baustein hinzufügen. 
Hierbeiden Ogranisationsbaustein "Program cycle" wählen und im Dropdown Menü unter Sprache `SCL` wählen**

Hier ist ein einfaches Beispiel-Programm in **SCL (Structured Control Language)**, das auf die Sensorwerte reagiert:

```scl
// ============================================
// OB1 – Hauptprogramm
// Liest Sensorwerte aus der Simulation
// ============================================

// --- Diffuse Sensor auswerten ---
// M0.0 wird von der Simulation gesetzt,
// wenn ein Objekt erkannt wird
IF "DiffuseSensor1" THEN
	// Objekt erkannt – Beispiel: Ausgang setzen
	"Output_Lamp" := TRUE;     // z.B. Q0.0
ELSE
	"Output_Lamp" := FALSE;
END_IF;

// --- Laser Sensor auswerten ---
// MD4 enthält die Distanz in Metern
IF "LaserDistance1" < 0.5 THEN
	// Objekt ist näher als 50cm
	"Output_Alarm" := TRUE;    // z.B. Q0.1
ELSE
	"Output_Alarm" := FALSE;
END_IF;

// --- Color Sensor auswerten ---
// MD8 enthält den Farbcode
// 1 = Rot, 2 = Grün, 3 = Blau
CASE "ColorValue1" OF
	1:  // Rotes Objekt
		"Diverter_Red" := TRUE;
		"Diverter_Green" := FALSE;
		"Diverter_Blue" := FALSE;
	2:  // Grünes Objekt
		"Diverter_Green" := TRUE;
		"Diverter_Red" := FALSE;
		"Diverter_Blue" := FALSE;
	3:  // Blaues Objekt
		"Diverter_Blue" := TRUE;
		"Diverter_Red" := FALSE;
		"Diverter_Green" := FALSE;
	ELSE:
		"Diverter_Red" := FALSE;
		"Diverter_Green" := FALSE;
		"Diverter_Blue" := FALSE;
END_CASE;
```

### Schritt 6: Zusätzliche Variablen für Ausgänge

Falls Sie die SPS-Ausgänge zurück in die Simulation leiten möchten (z. B. zum Steuern eines Diverters), erstellen Sie zusätzliche Variablen:

| Name              | Datentyp | Adresse  | Beschreibung                    |
|-------------------|----------|----------|---------------------------------|
| `Output_Lamp`     | Bool     | `Q0.0`   | Signallampe                     |
| `Output_Alarm`    | Bool     | `Q0.1`   | Alarm bei zu geringem Abstand   |
| `Diverter_Red`    | Bool     | `Q0.2`   | Weiche für rote Objekte         |
| `Diverter_Green`  | Bool     | `Q0.3`   | Weiche für grüne Objekte        |
| `Diverter_Blue`   | Bool     | `Q0.4`   | Weiche für blaue Objekte        |

### Schritt 7: Programm kompilieren und übertragen

1. Klicken Sie auf **Übersetzen** (Strg+B)
2. Prüfen Sie auf Fehler im Kompilierungsfenster
3. Klicken Sie auf **Laden in Gerät** (Strg+L)
4. Wählen Sie die Schnittstelle (z. B. PN/IE) und klicken Sie auf **Laden**
5. Starten Sie die CPU: *Online → CPU starten*

---

## 6. End-to-End Test

### Schritt-für-Schritt Testablauf

1. **SPS vorbereiten:**
   - Programm ist geladen und CPU läuft (RUN-Modus)
   - PUT/GET ist aktiviert
   - IP-Adresse ist korrekt konfiguriert

2. **Spiel starten:**
   - Godot-Projekt öffnen und Spiel starten (F5)

3. **Verbindung herstellen:**
   - Klicken Sie auf **"🔌 Connection"** in der Menüleiste
   - Geben Sie die SPS-Daten ein (IP, CPU, Rack, Slot)
   - Klicken Sie auf **"Connect"**
   - Warten Sie, bis der Status auf **grün** wechselt
   - Aktivieren Sie **"Online"**

4. **Simulation aufbauen:**
   - Platzieren Sie einen **Belt Conveyor**
   - Platzieren Sie einen **Box Spawner** am Anfang
   - Platzieren Sie einen **Diffuse Sensor** seitlich am Conveyor

5. **Sensor-Adressen prüfen:**
   - Klicken Sie auf den **Diffuse Sensor** in der Simulation
   - Im rechten **Sensor-Settings-Panel** sehen Sie die zugewiesene Adresse (z. B. `M0.0`)
   - Die Adresse muss mit der Variablen-Tabelle in TIA Portal übereinstimmen
   - Bei Bedarf können Sie die Adresse im Panel anpassen

6. **Testen:**
   - Die Simulation läuft automatisch
   - Boxen werden gespawnt und fahren über den Conveyor
   - Wenn eine Box den Diffuse Sensor passiert, wechselt `M0.0` auf der SPS auf `TRUE`
   - Beobachten Sie die Werte in **TIA Portal** unter *Online & Diagnose → Variablen beobachten*

### Werte in TIA Portal beobachten

1. Öffnen Sie die **Beobachtungstabelle** (*Online → Beobachtungstabelle*)
2. Fügen Sie die Variablen hinzu: `DiffuseSensor1`, `LaserDistance1`, `ColorValue1`
3. Klicken Sie auf **Beobachten** (Brillen-Symbol)
4. Die Werte werden in Echtzeit aktualisiert

### Sensor-Adresse in der Beobachtungstabelle prüfen

Falls die Werte in der Beobachtungstabelle nicht aktualisiert werden:
1. Prüfen Sie im **Sensor-Settings-Panel** (Sensor anklicken), welche Adresse tatsächlich zugewiesen ist
2. Vergleichen Sie diese mit den Adressen in der TIA Portal Variablen-Tabelle
3. Passen Sie bei Abweichungen die Adresse im Sensor-Panel oder in TIA Portal an

---

## 7. Fehlerbehebung

### Verbindung schlägt fehl

| Problem                               | Lösung                                                      |
|----------------------------------------|-------------------------------------------------------------|
| Ping schlägt fehl                      | Netzwerkverbindung und IP-Adresse prüfen                    |
| Connection Timeout                     | Firewall-Einstellungen prüfen (Port 102)                    |
| "Invalid IP Address"                   | Korrekte IPv4-Adresse eingeben (z. B. `192.168.0.1`)       |
| Status bleibt auf "Unknown"            | PUT/GET auf der SPS aktivieren                               |
| Verbindung bricht ab                   | Netzwerk-Stabilität prüfen, Kabelverbindung testen          |

### Daten werden nicht übertragen

| Problem                               | Lösung                                                      |
|----------------------------------------|-------------------------------------------------------------|
| Sensorwerte ändern sich nicht          | Online-Modus aktivieren (Button "Online")                   |
| Falsche Werte in der SPS              | Adressen in Sensor-Panel und TIA Portal abgleichen          |
| Sensoren werden nicht registriert      | Prüfen ob Sensoren unter SimulationRoot platziert sind      |
| Adresse stimmt nicht überein           | Sensor anklicken und im Sensor-Settings-Panel prüfen        |

### Sensor-spezifische Probleme

| Problem                               | Lösung                                                      |
|----------------------------------------|-------------------------------------------------------------|
| Diffuse Sensor zeigt immer FALSE      | Sensorstrahl prüfen (grüner/roter Strahl sichtbar?)         |
| Laser Sensor zeigt max_range          | Sensor so ausrichten, dass Objekte im Strahl sind           |
| Color Sensor erkennt keine Farbe      | Nur Rot, Grün, Blau werden erkannt (color_map prüfen)      |
| Sensor-Panel erscheint nicht          | Sensor im Select-Modus anklicken (nicht im Delete-Modus)   |

### Typische Rack/Slot-Werte

| CPU-Typ        | Rack | Slot |
|----------------|------|------|
| S7-1500        | 0    | 1    |
| S7-1200        | 0    | 0    |
| S7-300         | 0    | 2    |
| S7-400         | 0    | 2    |
| S7-200 Smart   | 0    | 1    |

---

## Zusammenfassung

Die Integration folgt einem einfachen Prinzip:

```
┌─────────────┐         ┌──────────────────┐         ┌─────────┐
│  Simulation  │  ────▶  │  siemens_plugin  │  ────▶  │   SPS   │
│  (Sensoren)  │  ◀────  │  (S7.Net / TCP)  │  ◀────  │  (TIA)  │
└─────────────┘         └──────────────────┘         └─────────┘
```

1. **Sensoren** in der Simulation erfassen Werte (Farbe, Abstand, Objekterkennung)
2. Der **PlcSensorBridge** registriert die Sensoren automatisch beim PLC und weist ihnen eindeutige Merker-Adressen zu
3. Die **GroupData** (C#) liest regelmäßig die Sensorwerte aus und schreibt sie über **S7.Net** in den Merker-Bereich der SPS
4. Die SPS verarbeitet die Werte nach dem in **TIA Portal** programmierten Logik
5. Die SPS kann Ausgangswerte zurückschreiben, die in der Simulation visualisiert werden

### Datenfluss im Detail

```
Plc.MonitoringLoop()            → Polling-Schleife prüft Verbindung
  ↓
ProcessRegisteredActions()      → Ruft alle registrierten GroupData-Aktionen auf
  ↓
GroupData.Execute()             → Liest und schreibt alle DataItems
  ↓
DataItem.UpdateValue()          → Liest den Godot-Property-Wert (z.B. sensor.output)
  ↓
Plc.Write()                     → Schreibt die Werte über S7.Net an die SPS
  ↓
SPS (Merker-Bereich)            → Wert erscheint in der Beobachtungstabelle
```

Bei Fragen oder Problemen prüfen Sie die Godot-Konsole auf Fehlermeldungen des siemens_plugin.
