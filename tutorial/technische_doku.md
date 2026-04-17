# Technische Dokumentation – Open Industry Project (OIP)

> **Zielgruppe:** Entwickler, Studierende und Projektfremde, die das Projekt verstehen und erweitern möchten.

---

## Inhaltsverzeichnis

1. [Projektübersicht](#1-projektübersicht)
2. [Technische Umsetzung des Spiels / Simulation](#2-technische-umsetzung-des-spiels--simulation)
   - 2.1 [Verwendete Technologien](#21-verwendete-technologien)
   - 2.2 [Projektstruktur](#22-projektstruktur)
   - 2.3 [Architektur-Überblick](#23-architektur-überblick)
   - 2.4 [Szenenbaum und Node-Hierarchie](#24-szenenbaum-und-node-hierarchie)
   - 2.5 [SimulationManager – Zentrale Zustandsverwaltung](#25-simulationmanager--zentrale-zustandsverwaltung)
   - 2.6 [MainGame – Der Spielcontroller](#26-maingame--der-spielcontroller)
   - 2.7 [Simulations-Komponenten im Detail](#27-simulations-komponenten-im-detail)
   - 2.8 [Physik-Engine und Konfiguration](#28-physik-engine-und-konfiguration)
   - 2.9 [In-Game UI und Interaktionssysteme](#29-in-game-ui-und-interaktionssysteme)
   - 2.10 [Autoloads / Singletons](#210-autoloads--singletons)
3. [Kommunikation von Simulation mit der SPS Box](#3-kommunikation-von-simulation-mit-der-sps-box)
   - 3.1 [Übersicht der Kommunikationswege](#31-übersicht-der-kommunikationswege)
   - 3.2 [Weg 1: OIPComms – Multi-Protokoll-Kommunikation (Editor-Modus)](#32-weg-1-oipcomms--multi-protokoll-kommunikation-editor-modus)
   - 3.3 [Weg 2: Siemens Plugin – Direkte S7-Kommunikation (Spiel-Modus)](#33-weg-2-siemens-plugin--direkte-s7-kommunikation-spiel-modus)
   - 3.4 [SPS-Adressierung im Detail – Warum M, MD, Q?](#34-sps-adressierung-im-detail--warum-m-md-q)
   - 3.5 [Datentypen und ihre SPS-Repräsentation](#35-datentypen-und-ihre-sps-repräsentation)
   - 3.6 [Die C#-Schicht: DataItems, GroupData und Plc](#36-die-c-schicht-dataitems-groupdata-und-plc)
   - 3.7 [PlcSensorBridge – Automatische Sensor-Registrierung](#37-plcsensorbridge--automatische-sensor-registrierung)
   - 3.8 [Adresszuweisung und Speicherausrichtung (Alignment)](#38-adresszuweisung-und-speicherausrichtung-alignment)
   - 3.9 [EventBus – Entkoppelte Signalverarbeitung](#39-eventbus--entkoppelte-signalverarbeitung)
   - 3.10 [Datenfluss: Vom Sensor bis zur SPS](#310-datenfluss-vom-sensor-bis-zur-sps)
   - 3.11 [Datenfluss: Von der SPS zurück in die Simulation](#311-datenfluss-von-der-sps-zurück-in-die-simulation)
4. [Glossar](#4-glossar)

---

## 1. Projektübersicht

Das **Open Industry Project (OIP)** ist ein freies, quelloffenes Framework zur Erstellung industrieller Simulationen. Es basiert auf der **Godot Game Engine** und ermöglicht es, virtuelle Lager- und Fertigungsumgebungen aufzubauen und diese in Echtzeit mit echten **Speicherprogrammierbaren Steuerungen (SPS)** zu verbinden.

### Wofür ist das Projekt gedacht?

- **Ausbildung:** Studierende und Auszubildende können SPS-Programmierung erlernen, ohne teure physische Anlagen zu benötigen.
- **Prototyping:** Ingenieure können Steuerungslogik testen, bevor sie auf echter Hardware eingesetzt wird.
- **Simulation:** Komplette Förderbandanlagen mit Sensoren, Weichen und Robotern können virtuell nachgebaut werden.

### Was kann simuliert werden?

Das Projekt enthält eine umfangreiche Bibliothek industrieller Komponenten:

| Kategorie   | Komponenten                                                                 |
|-------------|-----------------------------------------------------------------------------|
| Förderbänder | Belt Conveyor, Roller Conveyor, Curved Belt/Roller, Spur Conveyor           |
| Sensoren     | Diffuse Sensor (Objekterkennung), Laser Sensor (Abstandsmessung), Color Sensor (Farberkennung) |
| Aktoren      | Diverter (Weiche), BladeStop, ChainTransfer, Push Button                    |
| Roboter      | Six Axis Robot, Gantry (Portalroboter)                                      |
| Spawner      | Box Spawner, Pallet Spawner, Despawner                                      |
| Sonstiges    | Stack Light (Signalleuchte), Building (Halle)                               |

---

## 2. Technische Umsetzung des Spiels / Simulation

### 2.1 Verwendete Technologien

| Technologie         | Verwendung                                     | Version / Details                          |
|---------------------|------------------------------------------------|-------------------------------------------|
| **Godot Engine**    | Game Engine / Basis-Framework                  | 4.6 (Custom Fork mit OIP-Erweiterungen)   |
| **GDScript**        | Hauptprogrammiersprache für Spiellogik         | Godot-eigene Skriptsprache, Python-ähnlich |
| **C# / .NET**       | SPS-Kommunikation (Siemens Plugin)             | Für S7.Net-Bibliothek und Datentypen       |
| **Jolt Physics**    | Physik-Engine für 3D-Simulationen              | Ersetzt die Standard-Godot-Physics         |
| **S7.Net**          | Siemens-SPS-Kommunikation via TCP/IP           | PUT/GET Protokoll über Port 102            |
| **open62541**       | OPC UA Client/Server-Kommunikation             | C-basierte Open-Source-Bibliothek          |
| **libplctag**       | EtherNet/IP und Modbus TCP-Kommunikation       | Plattformübergreifende C-Bibliothek        |

### Warum Godot?

Godot wurde gewählt, weil es:
- **Open Source** ist (MIT-Lizenz), was vollständige Anpassungen ermöglicht.
- Eine leistungsfähige **3D-Engine** mit Physiksimulation bietet.
- **GDScript** eine niedrige Einstiegshürde hat (ähnlich zu Python).
- **C#-Integration** für performance-kritische oder bibliotheksabhängige Teile wie die SPS-Kommunikation bietet.
- Ein **Szenen-System** hat, das perfekt für modulare, wiederverwendbare industrielle Komponenten geeignet ist.

### 2.2 Projektstruktur

```
OIP/
├── game/                        # Spiel-Modus: Laufzeit-Controller und UI
│   ├── main_game.gd             # Hauptcontroller (bootstrappt alles)
│   ├── main_game.tscn           # Hauptszene
│   ├── game_camera.gd           # 3D-Kamera-Steuerung
│   ├── simulation_manager.gd    # Autoload: Simulations-Zustandsverwaltung
│   ├── plc/                     # PLC-Verbindungslogik
│   │   ├── plc_connection_manager.gd  # Autoload: SPS-Verbindung verwalten
│   │   └── plc_sensor_bridge.gd      # Sensor → SPS Datenbrücke
│   ├── systems/                 # Interaktionssysteme
│   │   ├── placement_system.gd  # Drag-and-Drop Platzierung
│   │   ├── selection_system.gd  # Objekt-Selektion und Manipulation
│   │   ├── move_gizmo.gd       # Verschiebe-Gizmo
│   │   ├── rotation_gizmo.gd   # Rotations-Gizmo
│   │   └── resize_gizmo.gd     # Größenänderungs-Gizmo
│   └── ui/                      # In-Game Benutzeroberfläche
│       ├── game_hud.gd          # Hauptmenü, Toolbar, Teilekatalog
│       ├── action_wheel.gd      # Radialmenü für Aktionen
│       ├── plc_connection_dialog.gd   # Verbindungsdialog
│       ├── plc_status_indicator.gd    # Verbindungsanzeige (grün/rot)
│       ├── sensor_properties_panel.gd # Sensor-Einstellungspanel
│       └── conveyor_properties_panel.gd # Förderband-Einstellungen
│
├── src/                         # Quellcode der Simulationskomponenten
│   ├── Conveyor/                # Belt Conveyor + Mesh-Generierung
│   ├── RollerConveyor/          # Roller Conveyor
│   ├── DiffuseSensor/           # Diffuser Sensor (BOOL)
│   ├── LaserSensor/             # Laser-Abstandssensor (REAL)
│   ├── ColorSensor/             # Farbsensor (DINT)
│   ├── BoxSpawner/              # Box-Erzeuger
│   ├── Box/                     # Karton-Objekt
│   ├── Diverter/                # Weiche / Umlenker
│   ├── Despawner/               # Objekt-Entferner
│   ├── Gantry/                  # Portalroboter
│   ├── SixAxisRobot/            # 6-Achs-Roboter
│   ├── comms/                   # OIPComms-Helferklassen
│   │   ├── oip_comms_setup.gd   # Verbindungs-Setup für Properties
│   │   └── oip_comms_tag.gd     # Tag-Abstraktion (read/write)
│   └── ...                      # Weitere Komponenten
│
├── parts/                       # Fertige Szenen (.tscn) zum Platzieren
│   ├── BeltConveyor.tscn        # Einzelnes Förderband
│   ├── DiffuseSensor.tscn       # Sensor-Szene
│   ├── assemblies/              # Zusammengesetzte Baugruppen
│   │   ├── BeltConveyorAssembly.tscn  # Förderband mit Beinen + Seitenführungen
│   │   └── ...
│   └── ...
│
├── addons/                      # Godot Editor-Plugins
│   ├── siemens_plugin/          # Siemens SPS-Kommunikation (C#)
│   │   ├── plc/
│   │   │   ├── PlcNode.cs       # Plc-Node-Wrapper (aktuell auskommentiert)
│   │   │   ├── s7-1500/         # S7-1500 3D-Modell + Szene
│   │   │   ├── var_groups/
│   │   │   │   ├── GroupData.cs # Gruppe von DataItems → liest/schreibt SPS
│   │   │   │   └── IPlcAction.cs # Interface für PLC-Aktionen
│   │   │   └── var_items/       # Einzelne Datentyp-Items
│   │   │       ├── VarItem.cs   # Basisklasse für alle DataItems
│   │   │       ├── BoolItem.cs  # Boolean (Bit)
│   │   │       ├── RealItem.cs  # Float (32-Bit)
│   │   │       ├── DIntItem.cs  # Double Integer (32-Bit)
│   │   │       └── ...          # Weitere: Int, Word, DWord, etc.
│   │   ├── scripts/globals/
│   │   │   ├── event_bus.gd     # Autoload: Zentrale Signal-Verteilung
│   │   │   └── globals.gd       # Autoload: Globale Konstanten/Icons
│   │   └── libs/S7.Net/         # S7.Net-Bibliothek (C#)
│   │
│   ├── oip_comms/               # OIPComms GDExtension-Plugin
│   │   └── ...                  # Multi-Protokoll-Kommunikation
│   ├── tag_groups/              # Tag-Gruppen-Verwaltung
│   ├── opc_ua_browser/          # OPC UA Node-Browser
│   ├── oip_ui/                  # Editor-UI Erweiterungen
│   ├── scene-library/           # Szenen-Bibliothek Plugin
│   └── ...                      # Weitere Editor-Plugins
│
├── Simulation.tscn              # Standard-Simulationsszene
├── project.godot                # Godot-Projektdatei (Konfiguration)
└── Open Industry Project.sln    # .NET Solution (für C#-Komponenten)
```

### 2.3 Architektur-Überblick

Das Projekt folgt einer **Schichtarchitektur** mit klarer Trennung von Zuständigkeiten:

```
┌─────────────────────────────────────────────────────────────────┐
│                    Benutzer-Interaktion                         │
│  ┌──────────┐  ┌──────────────┐  ┌────────────────────────┐     │
│  │  GameHUD │  │ ActionWheel  │  │ PlcConnectionDialog    │     │
│  └─────┬────┘  └──────┬───────┘  └────────────┬───────────┘     │
│        │              │                       │                 │
├────────┴──────────────┴───────────────────────┴─────────────────┤
│                    Interaktionssysteme                          │
│  ┌──────────────────┐  ┌───────────────────┐                    │
│  │ PlacementSystem  │  │ SelectionSystem   │                    │
│  └────────┬─────────┘  └──────┬────────────┘                    │
│           │                   │                                 │
├───────────┴───────────────────┴─────────────────────────────────┤
│                    Simulation (Spiellogik)                      │
│  ┌──────────┐ ┌────────┐ ┌──────┐ ┌────────┐ ┌──────────┐       │
│  │ Conveyor │ │ Sensor │ │ Box  │ │Spawner │ │ Diverter │       │
│  └────┬─────┘ └───┬────┘ └──┬───┘ └───┬────┘ └────┬─────┘       │
│       │            │        │         │           │             │
├───────┴────────────┴────────┴─────────┴───────────┴─────────────┤
│                    Kommunikationsschicht                        │
│  ┌───────────────────────────┐  ┌─────────────────────────┐     │
│  │ OIPComms (GDExtension)    │  │  Siemens Plugin (C#)    │     │
│  │ • OPC UA (open62541)      │  │  • S7.Net (PUT/GET)     │     │
│  │ • EtherNet/IP (libplctag) │  │  • PlcSensorBridge      │     │
│  │ • Modbus TCP (libplctag)  │  │  • GroupData + DataItems│     │
│  └───────────┬───────────────┘  └───────────┬─────────────┘     │
│              │                              │                   │
├──────────────┴──────────────────────────────┴───────────────────┤
│                    Externe Geräte                               │
│  ┌────────────────┐  ┌───────────────┐  ┌────────────────────┐  │
│  │ Siemens SPS    │  │ Allen-Bradley │  │ OPC UA Server      │  │
│  │ (S7-1200/1500) │  │ (CompactLogix)│  │ (z.B. Ignition)    │  │
│  └────────────────┘  └───────────────┘  └────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### 2.4 Szenenbaum und Node-Hierarchie

Godot organisiert alles in einem **Szenenbaum** (Scene Tree). Jedes Objekt ist ein **Node** (Knoten), und Nodes können Kinder haben, wodurch eine Baumstruktur entsteht. In OIP sieht der Baum zur Laufzeit so aus:

```
Root (Fenster)
├── SimulationManager         ← Autoload: Verwaltet Running/Paused
├── ConveyorSnapping          ← Autoload: Förderband-Snap-Logik
├── Globals                   ← Autoload: Globale Icons/Konstanten
├── EventBus                  ← Autoload: Zentrale Signal-Verteilung
├── PlcConnectionManager      ← Autoload: SPS-Verbindungsverwaltung
│   └── PlcRuntime            ← Plc C#-Node (erst nach Connect)
│       └── SensorBridgeGroup ← GroupData mit DataItems
│
└── MainGame                  ← Hauptcontroller
    ├── Building              ← 3D-Hallenmodell
    ├── GameCamera            ← Kamera (fliegend steuerbar)
    ├── SimulationRoot        ← *** Hier kommen alle Objekte rein ***
    │   ├── BeltConveyorAssembly   ← Platziertes Förderband
    │   ├── DiffuseSensor          ← Platzierter Sensor
    │   ├── BoxSpawner             ← Platzierter Spawner
    │   └── ...
    ├── PlacementSystem       ← Ghost-Vorschau beim Platzieren
    ├── SelectionSystem       ← Selektion + Gizmos
    ├── UILayer (CanvasLayer) ← 2D-UI über der 3D-Szene
    │   ├── GameHUD           ← Toolbar, Teilekatalog, Statusleiste
    │   ├── CurvedConveyorPanel
    │   └── SensorPropertiesPanel
    └── PlcSensorBridge       ← Sensor → SPS Datenbrücke
```

**Warum ist das wichtig?**

- Alle vom Benutzer platzierten Objekte landen unter **SimulationRoot**. Das erleichtert das Scannen nach Sensoren und die Verwaltung.
- **Autoloads** (oben im Baum) sind globale Singletons, die überall im Code zugänglich sind, z. B. `SimulationManager.is_simulation_running()`.
- Der **PlcSensorBridge** scannt den SimulationRoot nach Sensoren und erstellt automatisch die passenden C# DataItems unter dem Plc-Node.

### 2.5 SimulationManager – Zentrale Zustandsverwaltung

Der `SimulationManager` ist ein **Autoload-Singleton**, d. h. er wird beim Programmstart automatisch geladen und ist global verfügbar (`SimulationManager.xxx()`).

**Datei:** `game/simulation_manager.gd`

Er verwaltet drei Zustände:

| Zustand    | Variable    | Bedeutung                                    |
|------------|-------------|----------------------------------------------|
| Laufend    | `_running`  | Simulation ist gestartet                     |
| Pausiert   | `_paused`   | Simulation läuft, aber Objekte bewegen sich nicht |
| Gestoppt   | `!_running` | Simulation ist nicht aktiv                   |

**Signale:**
- `simulation_started` – Wird emittiert, wenn die Simulation startet. Sensoren und Conveyor registrieren sich bei diesem Signal mit ihren OIPComms-Tags.
- `simulation_stopped` – Wird emittiert, wenn die Simulation stoppt.
- `simulation_pause_toggled(paused)` – Wird emittiert, wenn der Pause-Zustand wechselt.

**Warum Signale?**

Godot verwendet ein **Signal-Slot-Pattern** (ähnlich dem Observer-Pattern). Ein Objekt emittiert ein Signal, und andere Objekte, die sich für dieses Signal registriert haben (via `connect()`), werden automatisch benachrichtigt. Das entkoppelt die Komponenten voneinander.

```
SimulationManager.simulation_started  ──→  DiffuseSensor._on_simulation_started()
                                       ──→  BeltConveyor._on_simulation_started()
                                       ──→  BoxSpawner._on_simulation_started()
```

### 2.6 MainGame – Der Spielcontroller

**Datei:** `game/main_game.gd`

Der `MainGame`-Controller ist der Einstiegspunkt des Spiels. In seiner `_ready()`-Funktion (wird aufgerufen, wenn der Node initialisiert ist) baut er die komplette Spielwelt auf:

1. **`_setup_environment()`** – Lädt und instanziiert das Hallen-3D-Modell (`Building.tscn`).
2. **`_setup_camera()`** – Erstellt die 3D-Kamera mit Steuerungslogik.
3. **`_setup_simulation_root()`** – Erstellt den `SimulationRoot`-Node, unter dem alle platzierten Objekte liegen.
4. **`_setup_systems()`** – Erstellt das `PlacementSystem` (zum Platzieren) und das `SelectionSystem` (zum Auswählen/Bewegen/Rotieren).
5. **`_setup_ui()`** – Erstellt die Benutzeroberfläche (HUD, Panels, Dialoge).
6. **`_setup_plc_bridge()`** – Erstellt den `PlcSensorBridge`, der Sensoren automatisch mit der SPS verbindet.
7. **`_connect_signals()`** – Verdrahtet alle Signale zwischen UI, Systemen und Spiellogik.

### 2.7 Simulations-Komponenten im Detail

#### 2.7.1 Belt Conveyor (Förderband)

**Datei:** `src/Conveyor/belt_conveyor.gd`  
**Klasse:** `BeltConveyor extends ResizableNode3D`

Ein Förderband bewegt Objekte über seine Oberfläche. Es besteht aus:

- **StaticBody3D** mit `constant_linear_velocity` – Das ist der Physikkörper, der Objekte transportiert. Godot's Physik-Engine wendet automatisch die eingestellte Geschwindigkeit auf berührende Objekte an.
- **MeshInstance3D** – Das sichtbare 3D-Modell (prozedural generiert mit Shadern für die Bandtextur-Animation).
- **CollisionShape3D** – Die unsichtbare Kollisionsform, die bestimmt, wo Objekte aufliegen.

**Wichtige Eigenschaften:**
- `speed` (REAL, m/s) – Bandgeschwindigkeit. Kann von der SPS gelesen werden.
- `reverse_belt` (BOOL) – Richtungsumkehr.
- `size` (Vector3) – Länge × Höhe × Breite. Kann zur Laufzeit geändert werden.

**Physik-Tick (`_physics_process`):**
```
Jeder Physik-Frame (120x pro Sekunde):
  → Berechne Geschwindigkeitsvektor basierend auf Richtung und speed
  → Setze constant_linear_velocity auf dem StaticBody3D
  → Aktualisiere die Shader-Parameter für die visuelle Bandanimation
```

#### 2.7.2 Diffuse Sensor (Objekterkennung)

**Datei:** `src/DiffuseSensor/diffuse_sensor.gd`  
**Klasse:** `DiffuseSensor extends Node3D`

Simuliert einen industriellen **Reflexionstaster**. Er sendet einen Strahl aus und erkennt, ob ein Objekt in Reichweite ist.

**Funktionsweise:**

1. In jedem Physik-Frame wird ein **Raycast** (Strahlabfrage) entlang der lokalen Z-Achse des Sensors gesendet.
2. Der Raycast prüft Kollisionen auf Layer 8 (`collision_mask = 8`), das ist der "Box"-Layer.
3. Wenn ein Objekt getroffen wird → `detected = true` → Strahl wird rot angezeigt.
4. Wenn kein Objekt getroffen wird → `detected = false` → Strahl wird grün angezeigt.

**Datenfluss:**
```
Raycast (Physik) → detected (bool) → _update_output() → output (bool) → SPS
```

Die `normally_closed`-Option invertiert die Logik (wie bei einem echten Sensor mit NC-Kontakt).

**SPS-Datentyp:** `BOOL` (1 Bit)  
**OIPComms-Tag:** Wird als Bit geschrieben (`_tag.write_bit(value)`)

#### 2.7.3 Laser Sensor (Abstandsmessung)

**Datei:** `src/LaserSensor/laser_sensor.gd`  
**Klasse:** `LaserSensor extends Node3D`

Simuliert einen industriellen **Distanz-Sensor** (z. B. Sick DT50). Er misst den Abstand zum nächsten Objekt.

**Funktionsweise:**

Identisch zum DiffuseSensor wird ein Raycast ausgeführt, aber statt eines Boolean-Werts wird die **Distanz** (Entfernung in Metern) als Float-Wert zurückgegeben.

**SPS-Datentyp:** `REAL` (32-Bit Float, 4 Bytes)  
**OIPComms-Tag:** Wird als Float geschrieben (`_tag.write_float32(value)`)

#### 2.7.4 Color Sensor (Farberkennung)

**Datei:** `src/ColorSensor/color_sensor.gd`  
**Klasse:** `ColorSensor extends Node3D`

Simuliert einen **Farbsensor**, der die Farbe eines erkannten Objekts identifiziert.

**Funktionsweise:**

1. Raycast trifft ein Objekt.
2. Vom getroffenen `CollisionObject3D` wird die `MeshInstance3D` geholt.
3. Vom Mesh wird das `StandardMaterial3D` abgefragt.
4. Die `albedo_color` (Grundfarbe) des Materials wird mit einer **Color Map** verglichen.
5. Die Color Map übersetzt Farben in ganzzahlige Werte:

| Farbe   | Godot-Color  | Integer-Wert |
|---------|-------------|-------------|
| Rot     | `Color.RED`  | 1           |
| Grün    | `Color.GREEN`| 2           |
| Blau    | `Color.BLUE` | 3           |
| Unbekannt | —         | 0           |

**SPS-Datentyp:** `DINT` (32-Bit Integer, 4 Bytes)  
**OIPComms-Tag:** Wird als Int32 geschrieben (`_tag.write_int32(value)`)

#### 2.7.5 Box Spawner (Karton-Erzeuger)

**Datei:** `src/BoxSpawner/box_spawner.gd`  
**Klasse:** `BoxSpawner extends Node3D`

Erzeugt in regelmäßigen Abständen neue Kartons in der Simulation.

**Konfiguration:**
- `boxes_per_minute` – Erzeugungsrate (Standard: 45/Minute).
- `fixed_rate` – Feste oder zufällige Erzeugungsrate.
- `random_size` – Aktiviert zufällige Kartongrößen.
- `box_color` – Farbe der erzeugten Kartons (wichtig für den Color Sensor).
- `conveyor` – Optionale Referenz auf ein Förderband. Wenn die Förderbandgeschwindigkeit 0 ist, pausiert der Spawner.

#### 2.7.6 Diverter (Weiche)

**Datei:** `src/Diverter/diverter.gd`  
**Klasse:** `Diverter extends Node3D`

Simuliert eine mechanische Weiche, die Objekte vom Hauptförderband auf ein Nebenband lenkt.

**Steuerung:**
- `_fire_divert` (BOOL) – Trigger-Signal. Wird auf `true` gesetzt, fährt die Weiche aus, nach 0.3 Sekunden automatisch zurück.
- Kann per OIPComms-Tag von der SPS gesteuert werden (`_tag.read_bit()`).

### 2.8 Physik-Engine und Konfiguration

Das Projekt verwendet **Jolt Physics** anstelle der Standard-Godot-Physik. Jolt ist eine industrietaugliche Physik-Engine (entwickelt für Horizon Forbidden West), die deutlich genauere und stabilere Simulationen ermöglicht.

**Konfiguration in `project.godot`:**

| Parameter                        | Wert   | Bedeutung                                          |
|----------------------------------|--------|---------------------------------------------------|
| `physics_ticks_per_second`       | 120    | 120 Physik-Berechnungen pro Sekunde                |
| `physics_engine`                 | Jolt   | Jolt Physics statt Godot Physics                   |
| `velocity_steps`                 | 15     | Geschwindigkeitsauflösung pro Tick                 |
| `position_steps`                 | 20     | Positionskorrektur-Iterationen                     |
| `run_on_separate_thread`         | true   | Physik läuft auf eigenem Thread (Performance)      |

**Physics Layer (Kollisionsebenen):**

| Layer | Name                  | Verwendung                                      |
|-------|-----------------------|------------------------------------------------|
| 1     | Static                | Gebäude, Boden, statische Objekte              |
| 2     | Dynamic               | Bewegliche Objekte (allgemein)                 |
| 3     | Belt                  | Förderbandöberflächen                          |
| 4     | Box                   | Kartons und Paletten (für Sensor-Raycasts)     |
| 5     | SimpleConveyorShape   | Vereinfachte Conveyor-Kollisionsformen         |

Die Layer sind entscheidend: Sensoren nutzen `collision_mask = 8` (binär: 0b1000 = Layer 4 = Box-Layer), damit sie **nur** Kartons erkennen und nicht den Boden oder das Förderband selbst.

### 2.9 In-Game UI und Interaktionssysteme

#### PlacementSystem (Platzierungssystem)

**Datei:** `game/systems/placement_system.gd`

Ermöglicht das Platzieren von Equipment per Drag-and-Drop:

1. Benutzer klickt im Teilekatalog auf ein Teil (z. B. "Belt Conveyor").
2. Das System erstellt eine **halbtransparente Vorschau** (Ghost) des Objekts.
3. Die Vorschau folgt dem Mauszeiger auf der Bodenebene (Y=0).
4. Positionen werden auf ein **0.25m-Raster** eingerastet.
5. **R-Taste** rotiert die Vorschau um 90°.
6. **Linksklick** platziert das Objekt unter `SimulationRoot`.
7. **Rechtsklick** oder **Escape** bricht ab.

Die Vorschau-Instanz wird speziell präpariert:
- Alle Meshes werden halbtransparent (60% Transparenz).
- Alle Kollisionen werden deaktiviert.
- Alle RigidBodies werden eingefroren.
- Processing wird deaktiviert, damit Skripte nicht laufen.

#### SelectionSystem (Auswahl- und Manipulationssystem)

**Datei:** `game/systems/selection_system.gd`

Ermöglicht das Auswählen und Manipulieren platzierter Objekte:

1. **Linksklick** auf ein Objekt → Selektion + blaues Highlight.
2. **Rechtsklick** auf selektiertes Objekt → Action Wheel öffnet sich.
3. **Action Wheel** bietet drei Modi:
   - **Move** – Objekt verschieben (Maus auf Bodenebene projiziert).
   - **Rotate** – Objekt drehen (Maus-X = Rotationswinkel).
   - **Scale** – Objekt skalieren (Maus-Y = Größenfaktor).
4. **Tastenkürzel:** G = Greifen, R = 90° rotieren, Q/E = Höhe ändern, Del = Löschen.

Die Selektion arbeitet mit **Raycasts**: Ein Strahl wird von der Kamera durch den Mauszeiger in die 3D-Szene geschossen. Das erste getroffene Objekt unter `SimulationRoot` wird ausgewählt.

#### GameHUD (Head-Up Display)

**Datei:** `game/ui/game_hud.gd`

Die Hauptbenutzeroberfläche, bestehend aus:

| Element            | Position      | Funktion                                        |
|--------------------|---------------|------------------------------------------------|
| Toolbar            | Oben          | Select/Delete-Buttons, Pause, Connection, Status |
| Parts Panel        | Links         | Teilekatalog mit Kategorien und Suchfunktion    |
| Status Bar         | Unten         | Kontextbezogene Statusinformationen             |
| Action Wheel       | Überlagernd   | Radialmenü für Move/Rotate/Scale                |
| Conveyor Panel     | Rechts        | Förderband-Eigenschaften                        |
| Sensor Panel       | Rechts        | Sensor-SPS-Adresseinstellungen                  |

Der Teilekatalog wird automatisch generiert, indem alle `.tscn`-Dateien im `parts/`-Verzeichnis gescannt werden. Die Teile werden in Kategorien eingeteilt (Conveyors, Sensors, Equipment, Spawners, Objects).

### 2.10 Autoloads / Singletons

Autoloads sind Nodes, die beim Programmstart automatisch geladen werden und global im gesamten Code zugänglich sind. Sie dienen als zentrale Anlaufstellen für bestimmte Funktionalitäten.

| Autoload                  | Datei                                    | Aufgabe                                         |
|---------------------------|------------------------------------------|-------------------------------------------------|
| `SimulationManager`       | `game/simulation_manager.gd`             | Simulations-Zustandsverwaltung (Start/Stop/Pause) |
| `ConveyorSnapping`        | `addons/oip_ui/Autoload/ConveyorSnapping.gd` | Automatisches Einrasten von Förderbändern  |
| `Globals`                 | `addons/siemens_plugin/scripts/globals/globals.gd` | Globale Icons und Konstanten           |
| `EventBus`                | `addons/siemens_plugin/scripts/globals/event_bus.gd` | Zentrale Signal-Verteilung für SPS-Events |
| `PlcConnectionManager`    | `game/plc/plc_connection_manager.gd`     | SPS-Verbindungsverwaltung                       |

---

## 3. Kommunikation von Simulation mit der SPS Box

### 3.1 Übersicht der Kommunikationswege

Das Projekt bietet **zwei parallele Kommunikationswege** zur SPS, die sich in Zweck und Technik unterscheiden:

```
┌─────────────────────────────────────────────────────────────────┐
│                       Simulation                                │
│                                                                 │
│   Weg 1: OIPComms (GDExtension)     Weg 2: Siemens Plugin (C#)│
│   ━━━━━━━━━━━━━━━━━━━━━━━━━━━      ━━━━━━━━━━━━━━━━━━━━━━━━━  │
│   • Editor + Spiel-Modus            • Spiel-Modus               │
│   • Multi-Protokoll:                • Nur Siemens S7:           │
│     - OPC UA (open62541)              - S7.Net (PUT/GET)        │
│     - EtherNet/IP (libplctag)       • Automatische              │
│     - Modbus TCP (libplctag)          Sensor-Registrierung      │
│     - Siemens S7 (PUT/GET)          • GroupData / DataItems     │
│   • Tag-Gruppen basiert             • Direkte Adressierung      │
│   • Polling-basiert                 • PlcSensorBridge           │
│                                                                 │
│         │                                    │                  │
│         ▼                                    ▼                  │
│   ┌──────────┐                        ┌──────────┐             │
│   │ SPS/OPC  │                        │ Siemens  │             │
│   │ Server   │                        │ SPS      │             │
│   └──────────┘                        └──────────┘             │
└─────────────────────────────────────────────────────────────────┘
```

**Wann benutzt man welchen Weg?**

| Kriterium                 | OIPComms (Weg 1)              | Siemens Plugin (Weg 2)        |
|---------------------------|-------------------------------|-------------------------------|
| Protokoll                 | OPC UA, EIP, Modbus, S7       | Nur Siemens S7                |
| Konfiguration             | Im Editor (Comms Panel)       | Im Spiel (Connection Dialog)  |
| Sensor-Registrierung      | Manuell (Tag-Name setzen)     | Automatisch (PlcSensorBridge) |
| Verwendung im Editor      | ✅ Ja                         | ❌ Nein                       |
| Verwendung im Spiel       | ✅ Ja                         | ✅ Ja                         |
| Typischer Einsatz         | Komplexe Multi-SPS-Setups     | Schneller Einstieg, Lehre     |

### 3.2 Weg 1: OIPComms – Multi-Protokoll-Kommunikation (Editor-Modus)

OIPComms ist eine **GDExtension** – ein nativer Plugin-Mechanismus von Godot, der C/C++-Bibliotheken direkt in die Engine einbindet.

#### Konfiguration im Editor

Im Godot-Editor gibt es unten das **Comms-Panel**, in dem Tag-Gruppen konfiguriert werden:

1. **Tag-Gruppe erstellen** – Jede Gruppe ist einem Gerät (SPS oder OPC-Server) zugeordnet.
2. **Protokoll wählen** – `ab_eip`, `modbus_tcp`, `opc_ua` oder `siemens put/get`.
3. **Verbindungsparameter** – IP-Adresse, Port, Rack/Slot etc.
4. **Polling Rate** – Wie oft die Tags gelesen werden (in Millisekunden).

#### Tag-Konfiguration am Objekt

Jedes kommunikationsfähige Objekt (Sensor, Conveyor, Diverter) hat eine `Communications`-Sektion im Inspector:

```
┌─ Communications ─────────────────────────────┐
│  Enable Comms:   ☑                           │
│  Tag Group:      [SPS_Linie1]                │
│  Tag Name:       M0.0                        │
└──────────────────────────────────────────────┘
```

- **Enable Comms:** Aktiviert die Kommunikation für dieses Objekt.
- **Tag Group:** Wählt aus, mit welchem Gerät kommuniziert wird.
- **Tag Name:** Das Format hängt vom gewählten Protokoll ab (siehe Abschnitt 3.4).

#### OIPCommsTag – Die Tag-Abstraktion

**Datei:** `src/comms/oip_comms_tag.gd`

Die Klasse `OIPCommsTag` kapselt die gesamte Lese-/Schreiblogik:

```gdscript
# Beispiel: So nutzt ein DiffuseSensor die Kommunikation
var _tag := OIPCommsTag.new()

# Bei Simulationsstart: Tag registrieren
func _on_simulation_started():
    _tag.register("SPS_Linie1", "M0.0")  # Gruppe + Adresse

# Bei Sensorwert-Änderung: Wert schreiben
func _update_output():
    _tag.write_bit(output)  # BOOL-Wert an SPS senden
```

Verfügbare Methoden:
- `read_bit()` / `write_bit(value)` – für BOOL-Werte
- `read_float32()` / `write_float32(value)` – für REAL-Werte
- `read_int32()` / `write_int32(value)` – für DINT-Werte
- `read_int16()` / `write_int16(value)` – für INT-Werte
- `read_uint8()` / `write_uint8(value)` – für BYTE-Werte

#### Polling-Mechanismus

OIPComms arbeitet **Polling-basiert**:

1. Ein Hintergrund-Thread liest in regelmäßigen Abständen (Polling Rate) **alle Tags** einer Tag-Gruppe.
2. Die gelesenen Werte werden in einen **thread-sicheren Puffer** geschrieben.
3. Die Simulation liest aus diesem Puffer (nicht direkt vom Gerät).
4. Schreibvorgänge werden in eine Queue eingereiht und nach dem nächsten Poll-Zyklus gesendet.

```
┌──────────────┐     Polling      ┌──────────┐     TCP/IP      ┌─────┐
│ Simulation   │ ←── (Puffer) ←── │ OIPComms │ ←─────────────→ │ SPS │
│ (GDScript)   │ ──→ (Queue)  ──→ │ (Thread) │                 │     │
└──────────────┘                  └──────────┘                  └─────┘
```

### 3.3 Weg 2: Siemens Plugin – Direkte S7-Kommunikation (Spiel-Modus)

Das Siemens Plugin ist ein **Godot Editor-Plugin** bestehend aus GDScript- und C#-Komponenten, das speziell für die Kommunikation mit Siemens-SPS entwickelt wurde.

#### Die Plc-Klasse (C#)

Die `Plc`-Klasse (aus der S7.Net-Bibliothek) ist das zentrale C#-Objekt, das die TCP/IP-Verbindung zur SPS herstellt und verwaltet. Sie implementiert das **S7-Protokoll** (ISO on TCP, Port 102).

```
┌─────────────────────────────┐
│        Plc (C#)             │
│                             │
│  IP:  "10.64.77.102"       │
│  CPU: S7-1500              │
│  Rack: 0, Slot: 1          │
│                             │
│  Methoden:                  │
│  • Open() – Verbinden       │
│  • Close() – Trennen        │
│  • Read() – Daten lesen     │
│  • Write() – Daten schreiben│
│  • ReadMultipleVars()       │
│  • RegisterAction()         │
│  • ProcessRegisteredActions()│
│                             │
│  Monitoring-Loop:           │
│  → Prüft Verbindung         │
│  → Ruft alle Actions auf    │
│  → Actions lesen/schreiben  │
└─────────────────────────────┘
```

#### PlcConnectionManager – Verbindungsverwaltung

**Datei:** `game/plc/plc_connection_manager.gd`

Dieser Autoload-Singleton verwaltet die SPS-Verbindung im Spiel-Modus:

1. **`ensure_plc_node()`** – Erstellt einen Plc-Node (instanziiert `s7_1500.tscn`) und setzt IP, CPU, Rack, Slot.
2. **`connect_plc()`** – Startet den Verbindungsaufbau (ruft `ConnectPlc()` auf dem C#-Node auf).
3. **`disconnect_plc()`** – Trennt die Verbindung.
4. **`set_online(value)`** – Aktiviert/deaktiviert den Datenaustausch.

**CPU-Typen:**

| Anzeigename     | Enum-Wert | Typisches Rack | Typischer Slot |
|-----------------|-----------|----------------|----------------|
| S7-200          | 0         | 0              | 0              |
| Logo 0BA8       | 1         | 0              | 0              |
| S7-200 Smart    | 2         | 0              | 1              |
| S7-300          | 10        | 0              | 2              |
| S7-400          | 20        | 0              | 2              |
| S7-1200         | 30        | 0              | 0              |
| S7-1500         | 40        | 0              | 1              |

### 3.4 SPS-Adressierung im Detail – Warum M, MD, Q?

Dieser Abschnitt erklärt die SPS-Adressierung von Grund auf, da sie für das Verständnis der Kommunikation essentiell ist.

#### Speicherbereiche einer Siemens SPS

Eine Siemens SPS (z. B. S7-1200 oder S7-1500) hat verschiedene **Speicherbereiche**, in denen Daten abgelegt werden können:

| Präfix | Speicherbereich       | Englisch         | Richtung              | Beschreibung                                      |
|--------|-----------------------|------------------|-----------------------|---------------------------------------------------|
| **I**  | Eingänge (Inputs)     | Process Image Input  | Lesen (von SPS)   | Physische Eingangssignale (z. B. Taster, Schalter) |
| **Q**  | Ausgänge (Outputs)    | Process Image Output | Schreiben (von SPS)| Physische Ausgangssignale (z. B. Motorsteuerung)   |
| **M**  | Merker (Memory)       | Memory Flags     | Lesen + Schreiben    | Interner Arbeitsbereich, frei verwendbar           |
| **DB** | Datenbaustein         | Data Block       | Lesen + Schreiben    | Strukturierte Datenspeicher                        |

**Warum M (Merker)?**

In der Simulation werden Sensorwerte standardmäßig in den **Merker-Bereich** geschrieben, weil:
1. Merker sind frei beschreibbar – sowohl von der SPS als auch von externen Geräten (via PUT/GET).
2. Eingänge (I) und Ausgänge (Q) sind an physische Hardware gebunden und können unter Umständen nicht von externen Geräten beschrieben werden.
3. Merker kollidieren nicht mit bereits vorhandener Hardware-Verdrahtung.

#### Byte- und Bit-Adressierung

Der gesamte SPS-Speicher ist in **Bytes** organisiert (1 Byte = 8 Bit). Die Adressierung folgt dem Schema:

```
Bereich  Byte.Bit
   M      0  .0

   ↑      ↑   ↑
   │      │   └── Bit-Position innerhalb des Bytes (0–7)
   │      └────── Byte-Adresse (ab 0 aufsteigend)
   └───────────── Speicherbereich (M = Merker)
```

**Beispiel: 4 Bytes im Merker-Bereich**

```
Byte 0       Byte 1       Byte 2       Byte 3
┌─┬─┬─┬─┬─┬─┬─┬─┐ ┌─┬─┬─┬─┬─┬─┬─┬─┐ ┌─┬─┬─┬─┬─┬─┬─┬─┐ ┌─┬─┬─┬─┬─┬─┬─┬─┐
│7│6│5│4│3│2│1│0│ │7│6│5│4│3│2│1│0│ │7│6│5│4│3│2│1│0│ │7│6│5│4│3│2│1│0│
└─┴─┴─┴─┴─┴─┴─┴─┘ └─┴─┴─┴─┴─┴─┴─┴─┘ └─┴─┴─┴─┴─┴─┴─┴─┘ └─┴─┴─┴─┴─┴─┴─┴─┘
 M0.7 ... M0.0      M1.7 ... M1.0      M2.7 ... M2.0      M3.7 ... M3.0
```

#### Adress-Notationen und ihre Bedeutung

Abhängig vom **Datentyp** werden unterschiedlich viele Bytes zusammengefasst:

| Notation | Datentyp | Größe   | Beispiel  | Bedeutung                                        |
|----------|----------|---------|-----------|--------------------------------------------------|
| **M0.0** | BOOL     | 1 Bit   | `M0.0`    | Merker, Byte 0, Bit 0 (einzelnes Bit)            |
| **M0.3** | BOOL     | 1 Bit   | `M0.3`    | Merker, Byte 0, Bit 3                            |
| **MB0**  | BYTE     | 1 Byte  | `MB0`     | Merker-Byte 0 (alle 8 Bits von Byte 0)           |
| **MW0**  | WORD/INT | 2 Bytes | `MW0`     | Merker-Wort ab Byte 0 (Byte 0 + Byte 1)          |
| **MD0**  | DWORD/DINT/REAL | 4 Bytes | `MD0` | Merker-Doppelwort ab Byte 0 (Byte 0–3)     |

**Wichtig – Überlappungsgefahr!**

Da MD, MW und MB auf denselben physischen Speicher zugreifen, können sie sich überlappen:

```
MD0  = Byte 0 + Byte 1 + Byte 2 + Byte 3
MW0  = Byte 0 + Byte 1
MW2  = Byte 2 + Byte 3
MB0  = Byte 0
M0.0 = Byte 0, Bit 0

→ Eine Änderung an MD0 verändert auch MW0, MW2, MB0 und M0.0!
```

Deshalb ist es extrem wichtig, dass **Adressen sich nicht überlappen**, wenn sie für verschiedene Variablen verwendet werden.

#### Adressierung im Projekt

Das Projekt verwendet folgendes Standard-Schema für Sensoren:

```
Byte:  0       1       2       3       4       5       6       7       8       9      10      11
      ┌───────┬───────┬───────┬───────┬───────┬───────┬───────┬───────┬───────┬───────┬───────┬───────┐
      │ BOOL  │ (frei)│ (frei)│ (frei)│        REAL (4 Bytes)        │        DINT (4 Bytes)        │
      │ M0.0  │       │       │       │          MD4                 │          MD8                 │
      │Diffuse│       │       │       │      LaserSensor             │      ColorSensor             │
      └───────┴───────┴───────┴───────┴───────┴───────┴───────┴───────┴───────┴───────┴───────┴───────┘
```

**Warum beginnt der Laser Sensor bei MD4 und nicht bei MD1?**

REAL- und DINT-Werte (4 Bytes) müssen an einer **4-Byte-Grenze** ausgerichtet sein. Das heißt, die Startadresse muss ein Vielfaches von 4 sein (0, 4, 8, 12, ...). Dies ist eine Anforderung der SPS-Hardware für effiziente Datenzugriffe. Byte 1, 2, 3 bleiben daher ungenutzt (Padding).

#### Adressierung von Ausgängen

Für SPS-Ausgänge (z. B. eine Signallampe, die die SPS steuert) wird der **Q-Bereich** (Output) verwendet:

| Notation | Bedeutung                                  |
|----------|-------------------------------------------|
| `Q0.0`   | Ausgang, Byte 0, Bit 0                    |
| `Q0.1`   | Ausgang, Byte 0, Bit 1                    |
| `QW0`    | Ausgangs-Wort ab Byte 0 (2 Bytes)         |

#### Zusammenfassung der Adress-Präfixe

| Buchstabe | Bereich    | B (Byte) | W (Word) | D (Double) | .x (Bit) |
|-----------|------------|----------|----------|------------|----------|
| **I**     | Eingang    | IB0      | IW0      | ID0        | I0.0     |
| **Q**     | Ausgang    | QB0      | QW0      | QD0        | Q0.0     |
| **M**     | Merker     | MB0      | MW0      | MD0        | M0.0     |

### 3.5 Datentypen und ihre SPS-Repräsentation

| Simulations-Komponente | Godot-Typ | SPS-Datentyp | Größe     | SPS-Notation    | Beispiel    |
|------------------------|-----------|-------------|-----------|-----------------|-------------|
| DiffuseSensor.output   | `bool`    | BOOL        | 1 Bit     | `Mx.y`          | `M0.0`      |
| LaserSensor.distance   | `float`   | REAL        | 4 Bytes   | `MDx`           | `MD4`       |
| ColorSensor.color_value| `int`     | DINT        | 4 Bytes   | `MDx`           | `MD8`       |
| BeltConveyor.speed     | `float`   | REAL        | 4 Bytes   | `MDx`           | `MD12`      |
| Diverter._fire_divert  | `bool`    | BOOL        | 1 Bit     | `Mx.y`          | `M1.0`      |

**Hinweis:** Obwohl REAL und DINT beide `MDx` als Notation verwenden, sind es unterschiedliche Datentypen! Die SPS interpretiert die gleichen 4 Bytes entweder als Fließkommazahl (REAL) oder als Ganzzahl (DINT), abhängig von der Variablendeklaration in TIA Portal.

### 3.6 Die C#-Schicht: DataItems, GroupData und Plc

Die SPS-Kommunikation im Siemens Plugin basiert auf einer **dreistufigen C#-Hierarchie**:

```
Plc (C# Klasse, Wurzel)
 │
 ├── GroupData ("SensorBridgeGroup")
 │    │
 │    ├── BoolItem ("Sensor_DiffuseSensor")
 │    │     • Mode: WriteToPlc
 │    │     • DataType: Memory (131)
 │    │     • StartByteAdr: 0
 │    │     • BitAdr: 0
 │    │     • VisualComponent: → DiffuseSensor-Node
 │    │     • VisualProperty: "output"
 │    │
 │    ├── RealItem ("Sensor_LaserSensor")
 │    │     • Mode: WriteToPlc
 │    │     • DataType: Memory (131)
 │    │     • StartByteAdr: 4
 │    │     • BitAdr: 0
 │    │     • VisualComponent: → LaserSensor-Node
 │    │     • VisualProperty: "distance"
 │    │
 │    └── DIntItem ("Sensor_ColorSensor")
 │          • Mode: WriteToPlc
 │          • DataType: Memory (131)
 │          • StartByteAdr: 8
 │          • BitAdr: 0
 │          • VisualComponent: → ColorSensor-Node
 │          • VisualProperty: "color_value"
 │
 └── (weitere GroupDatas für andere Zwecke)
```

#### DataItem (Basisklasse)

**Datei:** `addons/siemens_plugin/plc/var_items/VarItem.cs`

Jedes `DataItem` repräsentiert **eine Variable** auf der SPS. Die Basisklasse definiert:

- **Mode** – Zugriffsrichtung:
  - `ReadFromPlc` (0): Simulation liest Wert von der SPS.
  - `WriteToPlc` (1): Simulation schreibt Wert an die SPS.
- **VisualComponent** – Referenz auf den Godot-Node (z. B. DiffuseSensor).
- **VisualProperty** – Name der Eigenschaft im Godot-Node (z. B. "output").
- **UpdateGDValue()** – Übernimmt den SPS-Wert in die Godot-Eigenschaft.
- **UpdateValue()** – Liest die Godot-Eigenschaft und bereitet sie für den SPS-Transfer vor.

#### Konkrete DataItem-Typen

| Klasse    | SPS-Typ | Godot-Typ | Bytes | Datei              |
|-----------|---------|-----------|-------|--------------------|
| BoolItem  | BOOL    | `bool`    | 1 Bit | `BoolItem.cs`      |
| RealItem  | REAL    | `float`   | 4     | `RealItem.cs`      |
| DIntItem  | DINT    | `int`     | 4     | `DIntItem.cs`      |
| IntItem   | INT     | `short`   | 2     | `IntItem.cs`       |
| WordItem  | WORD    | `ushort`  | 2     | `WordItem.cs`      |
| DWordItem | DWORD   | `uint`    | 4     | `DWordItem.cs`     |
| ByteItem  | BYTE    | `byte`    | 1     | `ByteItem.cs`      |
| StringItem| STRING  | `string`  | var.  | `StringItem.cs`    |
| TimeItem  | TIME    | —         | 4     | `TimeItem.cs`      |
| LRealItem | LREAL   | `double`  | 8     | `LRealItem.cs`     |

#### DataType-Enum (Speicherbereich)

In den C#-DataItems wird der Speicherbereich als Integer definiert:

| Wert | Konstante   | SPS-Bereich          | Präfix im Adress-Notation |
|------|-------------|----------------------|---------------------------|
| 129  | Input       | Eingänge             | I                         |
| 130  | Output      | Ausgänge             | Q                         |
| 131  | Memory      | Merker               | M                         |
| 132  | DataBlock   | Datenbaustein        | DB                        |

#### GroupData – Gruppenverwaltung

**Datei:** `addons/siemens_plugin/plc/var_groups/GroupData.cs`

Eine `GroupData` fasst mehrere DataItems zusammen und wird als **IPlcAction** bei der Plc-Klasse registriert. In jedem Kommunikationszyklus wird `Execute()` aufgerufen:

```csharp
public void Execute()
{
    ReadAll();   // 1. Alle ReadFromPlc-Items von der SPS lesen
    WriteAll();  // 2. Alle WriteToPlc-Items an die SPS schreiben
}
```

**ReadAll():**
1. Filtert alle Items mit `Mode != WriteToPlc`.
2. Ruft `Plc.ReadMultipleVars()` auf → liest alle Werte in einem einzigen SPS-Request.
3. Ruft für jedes Item `UpdateGDValue()` auf → aktualisiert die Godot-Eigenschaft.

**WriteAll():**
1. Filtert alle Items mit `Mode != ReadFromPlc`.
2. Für jedes Item: `UpdateValue()` → liest die aktuelle Godot-Eigenschaft.
3. Ruft `Plc.Write()` auf → schreibt alle Werte an die SPS.

**Lebenszyklus:**
- Wenn eine GroupData als Kind eines Plc-Nodes hinzugefügt wird, registriert sie sich automatisch via `Plc.RegisterAction(this)`.
- Wenn sie entfernt wird, deregistriert sie sich via `Plc.RemoveAction(this)`.
- Bei Änderungen an den Kindern (DataItems hinzu/entfernt) wird die Item-Liste automatisch aktualisiert.

### 3.7 PlcSensorBridge – Automatische Sensor-Registrierung

**Datei:** `game/plc/plc_sensor_bridge.gd`

Der `PlcSensorBridge` ist das Herzstück der Spiel-Modus-SPS-Integration. Er scannt automatisch alle Sensoren in der Simulation und erstellt die passenden C# DataItems.

#### Funktionsweise

```
1. SPS-Verbindung wird hergestellt
   │
   ▼
2. PlcConnectionManager emittiert Signal: connection_state_changed(true)
   │
   ▼
3. PlcSensorBridge._on_connection_changed(true) → register_sensors()
   │
   ▼
4. _find_sensors() scannt SimulationRoot rekursiv nach:
   • ColorSensor-Instanzen
   • DiffuseSensor-Instanzen
   • LaserSensor-Instanzen
   │
   ▼
5. Für jeden gefundenen Sensor:
   a) _allocate_address() → Freie Adresse berechnen
   b) _register_sensor() → C# DataItem erstellen und konfigurieren:
      • BoolItem für DiffuseSensor
      • RealItem für LaserSensor
      • DIntItem für ColorSensor
   c) DataItem wird als Kind der GroupData hinzugefügt
   │
   ▼
6. GroupData registriert sich automatisch beim Plc-Node
   │
   ▼
7. Plc-Monitoring-Loop ruft GroupData.Execute() auf → Daten fließen
```

#### Nachträgliches Platzieren

Sensoren, die **nach** dem Verbindungsaufbau platziert werden, werden ebenfalls automatisch registriert. Der `MainGame`-Controller ruft nach jedem Platzierungsvorgang `_sensor_bridge.register_sensors()` auf:

```gdscript
func _on_object_placed(instance: Node3D) -> void:
    if _sensor_bridge and PlcConnectionManager.is_connected:
        _sensor_bridge.register_sensors()
```

### 3.8 Adresszuweisung und Speicherausrichtung (Alignment)

Die Funktion `_allocate_address()` im `PlcSensorBridge` vergibt automatisch SPS-Adressen:

#### BOOL-Sensoren (DiffuseSensor)

BOOL-Werte belegen nur 1 Bit. Mehrere BOOL-Sensoren werden in ein Byte **gepackt**:

```
Sensor 1: M0.0  (Byte 0, Bit 0)
Sensor 2: M0.1  (Byte 0, Bit 1)
Sensor 3: M0.2  (Byte 0, Bit 2)
...
Sensor 8: M0.7  (Byte 0, Bit 7)
Sensor 9: M1.0  (Byte 1, Bit 0)  ← Nächstes Byte
```

Dies entspricht dem tatsächlichen Verhalten auf einer echten SPS, wo ein Byte 8 Bit-Merker aufnehmen kann.

#### REAL/DINT-Sensoren (LaserSensor, ColorSensor)

4-Byte-Werte müssen an einer **4-Byte-Grenze** ausgerichtet sein:

```python
# Ausrichtungsberechnung (aus plc_sensor_bridge.gd):
static func _align(value: int, alignment: int) -> int:
    var remainder := value % alignment
    if remainder == 0:
        return value
    return value + (alignment - remainder)
```

**Beispiel-Berechnung:**

```
Nächste freie Adresse: 1 (nach BOOL bei M0.0)
Ausrichtung: _align(1, 4) = 1 + (4 - 1) = 4
→ REAL wird bei MD4 platziert

Nächste freie Adresse: 8 (nach REAL bei MD4, 4+4=8)
Ausrichtung: _align(8, 4) = 8 (bereits ausgerichtet)
→ DINT wird bei MD8 platziert
```

#### Manuelle Adressüberschreibung

Der Benutzer kann über das Sensor-Settings-Panel oder die Funktion `set_sensor_address()` eine eigene Adresse festlegen:

```gdscript
# Beispiel: DiffuseSensor auf M2.3 setzen
sensor_bridge.set_sensor_address(diffuse_sensor, 2, 3)  # Byte 2, Bit 3
```

Diese Überschreibungen werden im Dictionary `_address_overrides` gespeichert und bei der nächsten Registrierung berücksichtigt.

### 3.9 EventBus – Entkoppelte Signalverarbeitung

**Datei:** `addons/siemens_plugin/scripts/globals/event_bus.gd`

Der `EventBus` ist ein Autoload-Singleton, der als **zentraler Nachrichtenverteiler** dient. Er entkoppelt die C#-SPS-Schicht von der GDScript-UI-Schicht.

**Signale (Auswahl):**

| Signal                         | Emittiert von    | Empfänger                      | Bedeutung                          |
|--------------------------------|------------------|--------------------------------|------------------------------------|
| `plc_connected(plc)`          | Plc (C#)         | PlcConnectionManager           | SPS erfolgreich verbunden          |
| `plc_disconnected(plc)`       | Plc (C#)         | PlcConnectionManager           | SPS getrennt                       |
| `plc_connection_failed(plc, error)` | Plc (C#)  | PlcConnectionManager, UI       | Verbindungsfehler                  |
| `plc_connection_lost(plc)`    | Plc (C#)         | PlcConnectionManager           | Verbindung verloren                |
| `ping_completed(ip, success)` | Plc (C#)         | PlcConnectionDialog            | Ping-Ergebnis                      |

**Warum ein EventBus?**

In Godot können C#-Nodes nicht direkt GDScript-Signale emittieren und umgekehrt. Der EventBus löst dieses Problem:

```
C# (Plc-Klasse)                    GDScript (UI)
     │                                  │
     │   EventBus.plc_connected(plc)    │
     ├─────────────────────────────────→│
     │                                  │ PlcConnectionManager
     │                                  │ aktualisiert is_connected
     │                                  │
     │                                  │ PlcStatusIndicator
     │                                  │ zeigt grünen Kreis
     │                                  │
     │                                  │ PlcSensorBridge
     │                                  │ registriert Sensoren
```

### 3.10 Datenfluss: Vom Sensor bis zur SPS

Hier der **komplette Datenfluss** am Beispiel eines DiffuseSensors, der ein Objekt erkennt:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ 1. PHYSIK-SIMULATION (120× pro Sekunde)                                    │
│                                                                             │
│    DiffuseSensor._physics_process():                                        │
│    → Raycast entlang Z-Achse, collision_mask = 8 (Box-Layer)               │
│    → Ergebnis: Box getroffen, Distanz = 0.3m                               │
│    → detected = true                                                        │
│    → _update_output() → output = true (bzw. false bei normally_closed)      │
│                                                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│ 2a. OIPComms-Weg (wenn enable_comms = true im Editor)                       │
│                                                                             │
│    output.set() → _tag.write_bit(true)                                      │
│    → OIPComms.write_bit("SPS_Linie1", "M0.0", true)                        │
│    → Wert wird in die Schreib-Queue eingereiht                              │
│    → Nächster Polling-Zyklus: Wert wird über TCP an SPS gesendet            │
│                                                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│ 2b. Siemens-Plugin-Weg (wenn über PlcSensorBridge registriert)              │
│                                                                             │
│    Plc.MonitoringLoop() → ProcessRegisteredActions()                        │
│    → GroupData.Execute()                                                    │
│      → WriteAll()                                                           │
│        → BoolItem.UpdateValue()                                             │
│          → Liest DiffuseSensor.output (über VisualComponent.Get("output"))  │
│          → GDValue = true                                                   │
│          → Value = true                                                     │
│        → Plc.Write([BoolItem, ...])                                         │
│          → S7.Net sendet TPKT/COTP/S7-Paket über TCP Port 102              │
│          → SPS empfängt: M0.0 = TRUE                                        │
│                                                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│ 3. SPS (TIA Portal V19)                                                     │
│                                                                             │
│    OB1 – Hauptprogramm (zyklisch, z. B. alle 10ms):                         │
│    IF "DiffuseSensor1" THEN    // Liest M0.0                                │
│        "Output_Lamp" := TRUE;  // Setzt Q0.0                                │
│    END_IF;                                                                  │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.11 Datenfluss: Von der SPS zurück in die Simulation

Die SPS kann auch Werte zurück in die Simulation schreiben, z. B. um ein Förderband zu steuern:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ 1. SPS-PROGRAMM (TIA Portal)                                               │
│                                                                             │
│    "ConveyorSpeed" := 2.5;  // Schreibt 2.5 in MD20 (REAL)                 │
│                                                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│ 2a. OIPComms-Weg                                                            │
│                                                                             │
│    Polling-Thread liest MD20 → Wert 2.5 im Puffer                           │
│    → tag_group_polled Signal wird emittiert                                 │
│    → BeltConveyor._tag_group_polled():                                      │
│      → speed = _speed_tag.read_float32() → 2.5                             │
│    → Förderband dreht sich mit 2.5 m/s                                      │
│                                                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│ 2b. Siemens-Plugin-Weg                                                      │
│                                                                             │
│    GroupData.Execute() → ReadAll()                                           │
│    → Plc.ReadMultipleVars([RealItem, ...])                                  │
│      → S7.Net liest MD20 von der SPS                                        │
│      → RealItem.Value = 2.5                                                 │
│    → RealItem.UpdateGDValue()                                               │
│      → UpdateVisualComponent(2.5)                                           │
│      → BeltConveyor.set("speed", 2.5)                                       │
│    → Förderband dreht sich mit 2.5 m/s                                      │
│                                                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│ 3. SIMULATION                                                               │
│                                                                             │
│    BeltConveyor._physics_process():                                         │
│    → constant_linear_velocity = basis.x * 2.5 m/s                          │
│    → Kartons auf dem Band bewegen sich mit 2.5 m/s                          │
│    → Belt-Textur animiert sich passend                                      │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Netzwerk-Architektur

```
┌──────────────┐                              ┌────────────────────┐
│              │         Ethernet              │                    │
│   PC mit     │◄────────────────────────────►│  Siemens SPS       │
│   Godot +    │     TCP/IP Port 102          │  (S7-1200/1500)    │
│   OIP        │     S7-Protokoll             │                    │
│              │                              │  TIA Portal V19    │
│  IP: z. B.   │                              │  IP: z. B.         │
│  10.64.77.17 │                              │  10.64.77.102      │
│              │                              │                    │
└──────────────┘                              └────────────────────┘
        │                                              │
        │  Voraussetzungen:                            │  Voraussetzungen:
        │  • Port 102 nicht blockiert                  │  • PUT/GET aktiviert
        │  • Gleiches Subnetz                          │  • CPU im RUN-Modus
        │  • Windows-Firewall erlaubt                  │  • IP konfiguriert
        │    Verbindung auf Port 102                   │
```

---

## 4. Glossar

| Begriff               | Erklärung                                                                                           |
|-----------------------|-----------------------------------------------------------------------------------------------------|
| **SPS**               | Speicherprogrammierbare Steuerung – ein Industriecomputer zur Steuerung von Maschinen.              |
| **PLC**               | Programmable Logic Controller – englische Bezeichnung für SPS.                                       |
| **TIA Portal**        | Totally Integrated Automation Portal – die Programmierumgebung von Siemens für SPS.                  |
| **S7-Protokoll**      | Das proprietäre Kommunikationsprotokoll von Siemens-SPS (ISO on TCP, Port 102).                     |
| **PUT/GET**           | Kommunikationsmechanismus, der externen Geräten erlaubt, direkt auf SPS-Speicher zuzugreifen.       |
| **OPC UA**            | Open Platform Communications Unified Architecture – offener Industriestandard für Kommunikation.     |
| **EtherNet/IP**       | Industrial Protocol – Kommunikationsstandard von Rockwell Automation (Allen-Bradley).                |
| **Modbus TCP**        | Offenes Kommunikationsprotokoll für industrielle Geräte über TCP/IP.                                |
| **Merker (M)**        | Interner Speicherbereich der SPS für Zwischenwerte (frei les- und schreibbar).                       |
| **Eingang (I)**       | Speicherbereich für physische Eingangssignale (z. B. Taster, Sensoren an der echten SPS).           |
| **Ausgang (Q)**       | Speicherbereich für physische Ausgangssignale (z. B. Motorsteuerung, Lampen).                        |
| **Datenbaustein (DB)**| Strukturierter Speicher in der SPS zur Organisation komplexer Daten.                                |
| **BOOL**              | Boolean – Datentyp mit Wert `true` oder `false`. Belegt 1 Bit.                                      |
| **REAL**              | Fließkommazahl (32-Bit IEEE 754). Belegt 4 Bytes.                                                    |
| **DINT**              | Double Integer – 32-Bit Ganzzahl mit Vorzeichen. Belegt 4 Bytes.                                     |
| **INT**               | Integer – 16-Bit Ganzzahl mit Vorzeichen. Belegt 2 Bytes.                                            |
| **WORD**              | 16-Bit Wert ohne Vorzeichen. Belegt 2 Bytes.                                                         |
| **Byte**              | 8 Bit = die kleinste adressierbare Speichereinheit.                                                   |
| **Alignment**         | Speicherausrichtung – manche Datentypen müssen an bestimmten Byte-Grenzen beginnen.                  |
| **Node**              | Grundbaustein in Godot. Alles ist ein Node (3D-Objekte, UI, Skripte, etc.).                          |
| **Scene**             | Eine Godot-Szene – ein wiederverwendbarer Baum aus Nodes, gespeichert als `.tscn`-Datei.             |
| **Autoload**          | Ein Godot-Singleton, der beim Programmstart automatisch geladen wird und global verfügbar ist.        |
| **Signal**            | Godot-Mechanismus zur entkoppelten Kommunikation (Observer-Pattern).                                  |
| **GDScript**          | Godot's eigene Skriptsprache, syntaktisch ähnlich zu Python.                                          |
| **GDExtension**       | Mechanismus, um native C/C++-Bibliotheken in Godot einzubinden.                                      |
| **Raycast**           | Ein unsichtbarer Strahl in der 3D-Szene, der Kollisionen erkennt – wie ein virtueller Sensorstrahl.  |
| **Rack/Slot**         | Physische Position der CPU-Baugruppe im SPS-Aufbau. Rack = Gestell, Slot = Steckplatz.               |
| **Tag**               | Eine benannte Variable/Adresse auf der SPS oder im OPC UA Server.                                     |
| **Polling**           | Zyklisches Abfragen von Werten in festem Zeitintervall.                                               |
| **Jolt Physics**      | Externe Physik-Engine (ursprünglich für Horizon Forbidden West), die in Godot integriert ist.         |
