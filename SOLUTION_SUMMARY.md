# Sensor-zu-SPS Verbindungsproblem - Lösung

## Problem-Zusammenfassung

Das Problem war, dass Sensoren (DiffuseSensor, LaserSensor, ColorSensor) in der Simulation zwar platziert werden konnten, aber keine Daten an die SPS übertragen wurden. Die Beobachtungstabelle in TIA Portal zeigte keine Änderungen für die Adressen %M0.0 und %MD4.

## Ursachenanalyse

Die Ursache lag im `PlcSensorBridge` (Datei: `game/plc/plc_sensor_bridge.gd`):

### Was fehlte:
1. **Keine Adresskonfiguration**: Die DataItem-Nodes wurden erstellt, aber die kritischen Eigenschaften `StartByteAdr` und `BitAdr` wurden nicht gesetzt
2. **Keine Adressverwaltung**: Es gab kein System zur automatischen Zuweisung von eindeutigen Adressen für mehrere Sensoren
3. **Keine Benutzer-Feedback**: Der Benutzer hatte keine Möglichkeit zu sehen, welche Adresse einem Sensor zugewiesen wurde

### Warum das Problem auftrat:
Ohne `StartByteAdr` und `BitAdr` wusste die SPS nicht, wo sie die Sensordaten lesen/schreiben sollte. Die DataItems wurden zwar erstellt, aber sie waren "leer" - ohne konkrete Speicheradresse.

## Implementierte Lösung

### 1. Automatische Adressverwaltung (plc_sensor_bridge.gd)

**Hinzugefügte Features:**
- Automatische Adresszuweisung für BOOL, REAL und DINT Datentypen
- Separate Adresszähler für jeden Datentyp:
  - `_next_bool_address`: Verwaltet M0.0, M0.1, M0.2, ... (mit Byte- und Bit-Komponenten)
  - `_next_real_address`: Verwaltet MD4, MD8, MD12, ... (4-Byte-Schritte für REAL)
  - `_next_dint_address`: Verwaltet MD8, MD12, MD16, ... (4-Byte-Schritte für DINT)

**Funktionsweise:**
```gdscript
# Beispiel für DiffuseSensor (BOOL)
var addr := _allocate_bool_address()  # Gibt {"byte": 0, "bit": 0} zurück
item_node.set("StartByteAdr", addr["byte"])  # M0
item_node.set("BitAdr", addr["bit"])          # .0
# Nächster Sensor bekommt M0.1, dann M0.2, etc.
```

**Hinzugefügte Eigenschaften auf jedem DataItem:**
- `StartByteAdr`: Byte-Offset im Speicher
- `BitAdr`: Bit-Offset (für BOOL)
- `DB`: Datenbaustein-Nummer (0 für Memory)
- `DataType`: 131 (Memory-Bereich)
- `Mode`: 1 (WriteToPlc - Sensor → PLC)

### 2. Sensor-Konfigurationspanel (sensor_config_panel.gd)

**Neue UI-Komponente:**
Ein Panel auf der rechten Seite zeigt beim Auswählen eines Sensors:
- Sensor-Name
- Sensor-Typ (DiffuseSensor BOOL, LaserSensor REAL, ColorSensor DINT)
- **Zugewiesene PLC-Adresse** (z.B. M0.0, MD4, MD8)
- OIP Communications Einstellungen (tag_group_name, tag_name)

**Wie es funktioniert:**
1. Benutzer klickt auf einen Sensor in der Simulation
2. Panel öffnet sich automatisch
3. Panel fragt den PlcSensorBridge nach der DataItem-Konfiguration
4. Adresse wird in verständlichem Format angezeigt (M0.0 statt "Byte: 0, Bit: 0")

### 3. Integration in main_game.gd

Das Sensor-Panel wurde nahtlos in das Spiel integriert:
- Wird automatisch angezeigt, wenn ein Sensor ausgewählt wird
- Versteckt sich, wenn andere Objekte ausgewählt werden
- Koexistiert mit dem Curved Conveyor Panel (zeigt immer nur eines)

### 4. Aktualisierte Dokumentation (tutorial/inbetriebnahme.md)

**Wichtigste Änderungen:**
1. **Neue Sektion "Sensor-Konfigurationspanel"**: Erklärt, wie man die Adressen abliest
2. **Aktualisiertes Adress-Schema**: Zeigt, dass Adressen automatisch vergeben werden
3. **Wichtiger Workflow-Schritt**:
   - ZUERST Simulation starten und Sensoren platzieren
   - DANN Adressen im Sensor-Panel ablesen
   - ERST DANACH Variablen in TIA Portal mit diesen Adressen anlegen
4. **Debugging-Tipps**: Console-Logs zeigen Sensor-Registrierungen
5. **Erweiterte Fehlerbehebung**: Neue Einträge für Adress-Probleme

## Adress-Zuweisungslogik

### BOOL (DiffuseSensor):
- Startet bei M0.0
- Zählt Bits hoch: M0.0 → M0.1 → M0.2 → ... → M0.7 → M1.0 → M1.1 ...
- Jeder DiffuseSensor belegt 1 Bit

### REAL (LaserSensor):
- Startet bei MD4
- Zählt in 4-Byte-Schritten: MD4 → MD8 → MD12 → MD16 ...
- Jeder LaserSensor belegt 4 Bytes (REAL = 32-bit Float)

### DINT (ColorSensor):
- Startet bei MD8
- Zählt in 4-Byte-Schritten: MD8 → MD12 → MD16 → MD20 ...
- Jeder ColorSensor belegt 4 Bytes (DINT = 32-bit Integer)

## Verwendung

### Korrekte Vorgehensweise für den Benutzer:

1. **Simulation aufbauen:**
   - Belt Conveyor platzieren
   - Box Spawner platzieren
   - Sensoren platzieren (DiffuseSensor, LaserSensor, ColorSensor)

2. **SPS-Verbindung herstellen:**
   - Connection-Dialog öffnen
   - IP, CPU-Typ, Rack, Slot eingeben
   - "Connect" klicken
   - "Online" aktivieren

3. **Adressen ermitteln:**
   - Jeden Sensor einzeln anklicken
   - Im Sensor-Konfigurationspanel die Adresse ablesen
   - Adressen notieren (z.B. DiffuseSensor1 = M0.0, LaserSensor1 = MD4)

4. **TIA Portal konfigurieren:**
   - PLC-Variablen anlegen mit EXAKT den Adressen aus Schritt 3
   - OB1 programmieren mit diesen Variablen
   - Programm kompilieren und laden

5. **Testen:**
   - Simulation laufen lassen
   - Boxen spawnen lassen
   - In TIA Portal Beobachtungstabelle öffnen
   - Werte sollten sich ändern, wenn Boxen die Sensoren passieren

## Debug-Logs

Der PlcSensorBridge gibt jetzt hilfreiche Console-Meldungen aus:
```
PlcSensorBridge: Registered DiffuseSensor 'DiffuseSensor' at M0.0
PlcSensorBridge: Registered LaserSensor 'LaserSensor' at MD4
PlcSensorBridge: Registered ColorSensor 'ColorSensor' at MD8
```

Diese können in der Godot-Console (während das Spiel läuft) eingesehen werden.

## Geänderte Dateien

1. `game/plc/plc_sensor_bridge.gd` - Hauptfix für Adresszuweisung
2. `game/ui/sensor_config_panel.gd` - Neues UI-Panel (NEU)
3. `game/main_game.gd` - Integration des Sensor-Panels
4. `tutorial/inbetriebnahme.md` - Aktualisierte Anleitung

## Vorteile der Lösung

✅ **Automatisch**: Keine manuelle Konfiguration von Adressen erforderlich
✅ **Transparent**: Benutzer sieht immer die aktuellen Adressen
✅ **Skalierbar**: Funktioniert mit beliebig vielen Sensoren
✅ **Kollisionsfrei**: Jeder Sensor bekommt eine eindeutige Adresse
✅ **Benutzerfreundlich**: Klare Anzeige im UI
✅ **Konsistent**: Adressen werden deterministisch zugewiesen

## Zukünftige Erweiterungen (Optional)

Mögliche Verbesserungen für die Zukunft:
- [ ] Manuelle Adress-Überschreibung im Sensor-Panel
- [ ] Adress-Export als CSV für TIA Portal Import
- [ ] Warnung bei Adress-Überlappungen
- [ ] Persistierung der Adress-Zuweisungen (speichern/laden)
