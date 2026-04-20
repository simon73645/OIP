extends Node3D
## Main game controller — bootstraps the standalone simulation experience.
##
## Instantiates the building environment, camera, HUD, and the placement /
## selection systems, then wires them together so that equipment can be placed,
## selected, moved, rotated, scaled and deleted entirely in-game.

const GameCameraScript := preload("res://game/game_camera.gd")
const GameHUDScript := preload("res://game/ui/game_hud.gd")
const CurvedConveyorPanelScript := preload("res://game/ui/curved_conveyor_panel.gd")
const SensorPropertiesPanelScript := preload("res://game/ui/sensor_properties_panel.gd")
const DiverterPropertiesPanelScript := preload("res://game/ui/diverter_properties_panel.gd")
const PlacementSystemScript := preload("res://game/systems/placement_system.gd")
const SelectionSystemScript := preload("res://game/systems/selection_system.gd")
const PlcSensorBridgeScript := preload("res://game/plc/plc_sensor_bridge.gd")

# Scene references created at runtime.
var _camera: Camera3D
var _hud: Control
var _curved_panel: PanelContainer
var _sensor_panel: PanelContainer   # Sensor PLC settings panel
var _diverter_panel: PanelContainer # Diverter PLC settings panel
var _placement: Node3D       # PlacementSystem
var _selection: Node          # SelectionSystem
var _simulation_root: Node3D
var _building: Node3D
var _sensor_bridge: Node      # PlcSensorBridge

var _paused: bool = false


func _ready() -> void:
	_setup_environment()
	_setup_camera()
	_setup_simulation_root()
	_setup_systems()
	_setup_ui()
	_setup_plc_bridge()
	_connect_signals()


# ── Scene setup ──────────────────────────────────────────────────────────────

func _setup_environment() -> void:
	# Instantiate the warehouse building.
	var building_scene := load("res://parts/Building.tscn") as PackedScene
	if building_scene:
		_building = building_scene.instantiate()
		add_child(_building)


func _setup_camera() -> void:
	_camera = Camera3D.new()
	_camera.set_script(GameCameraScript)
	_camera.current = true
	add_child(_camera)


func _setup_simulation_root() -> void:
	# All placed equipment goes under this node.
	_simulation_root = Node3D.new()
	_simulation_root.name = "SimulationRoot"
	add_child(_simulation_root)


func _setup_systems() -> void:
	# Placement system (ghost preview + click-to-place).
	_placement = Node3D.new()
	_placement.name = "PlacementSystem"
	_placement.set_script(PlacementSystemScript)
	add_child(_placement)
	_placement.setup(_camera, _simulation_root)

	# Selection system (click-to-select + action-wheel modes).
	_selection = Node.new()
	_selection.name = "SelectionSystem"
	_selection.set_script(SelectionSystemScript)
	add_child(_selection)
	_selection.setup(_camera, _simulation_root)


func _setup_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "UILayer"
	add_child(canvas)

	_hud = Control.new()
	_hud.name = "GameHUD"
	_hud.set_script(GameHUDScript)
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(_hud)

	# Right-side panel for curved conveyor properties (radius / width / angle).
	_curved_panel = PanelContainer.new()
	_curved_panel.name = "CurvedConveyorPanel"
	_curved_panel.set_script(CurvedConveyorPanelScript)
	# Anchor to the right edge.
	_curved_panel.anchor_top = 0.0
	_curved_panel.anchor_bottom = 0.0
	_curved_panel.anchor_left = 1.0
	_curved_panel.anchor_right = 1.0
	_curved_panel.offset_top = 60
	_curved_panel.offset_left = -260
	_curved_panel.offset_right = 0
	_curved_panel.offset_bottom = 340
	canvas.add_child(_curved_panel)

	# Sensor PLC settings panel (right side, shown when a sensor is selected).
	_sensor_panel = PanelContainer.new()
	_sensor_panel.name = "SensorPropertiesPanel"
	_sensor_panel.set_script(SensorPropertiesPanelScript)
	canvas.add_child(_sensor_panel)

	# Diverter PLC settings panel (right side, shown when a diverter is selected).
	_diverter_panel = PanelContainer.new()
	_diverter_panel.name = "DiverterPropertiesPanel"
	_diverter_panel.set_script(DiverterPropertiesPanelScript)
	canvas.add_child(_diverter_panel)


# ── PLC sensor bridge setup ──────────────────────────────────────────────────

func _setup_plc_bridge() -> void:
	_sensor_bridge = Node.new()
	_sensor_bridge.name = "PlcSensorBridge"
	_sensor_bridge.set_script(PlcSensorBridgeScript)
	add_child(_sensor_bridge)
	_sensor_bridge.setup(_simulation_root)


# ── Signal wiring ────────────────────────────────────────────────────────────

func _connect_signals() -> void:
	# HUD → systems.
	_hud.part_selected.connect(_on_part_selected)
	_hud.mode_changed.connect(_on_mode_changed)
	_hud.simulation_pause_requested.connect(_on_pause_requested)
	_hud.action_mode_selected.connect(_on_action_mode_selected)

	# Placement system → HUD feedback.
	_placement.object_placed.connect(_on_object_placed)
	_placement.placement_cancelled.connect(_on_placement_cancelled)

	# Selection system → HUD feedback.
	_selection.selection_changed.connect(_on_selection_changed)
	_selection.action_wheel_requested.connect(_on_action_wheel_requested)


# ── Callbacks ────────────────────────────────────────────────────────────────

func _on_part_selected(scene_path: String) -> void:
	# Switch to placement mode.
	_selection.deselect()
	_placement.activate(scene_path)


func _on_mode_changed(mode: String) -> void:
	if mode != "place" and _placement.is_active():
		_placement.cancel_silently()
	_selection.set_mode(mode)


func _on_object_placed(instance: Node3D) -> void:
	_selection.select(instance)
	_hud.set_mode("select")
	_hud.set_status("Object placed.")
	# Auto-register new sensors with the PLC bridge.
	if _sensor_bridge and PlcConnectionManager.is_connected:
		_sensor_bridge.register_sensors()


func _on_placement_cancelled() -> void:
	_hud.set_mode("select")
	_hud.set_status("Placement cancelled.")


func _on_selection_changed(selected: Node3D) -> void:
	if selected:
		_hud.bind_properties(selected)
		_hud.set_status("Selected: %s  (Right-click = change mode, Del = delete, Esc = deselect)" % selected.name)

		# Show curved conveyor panel if applicable.
		if _curved_panel and (selected is CurvedBeltConveyorAssembly or selected is CurvedRollerConveyorAssembly):
			_curved_panel.show_for(selected)
		elif _curved_panel:
			_curved_panel.hide_panel()

		# Show sensor panel if applicable.
		if _sensor_panel and (selected is DiffuseSensor or selected is LaserSensor or selected is ColorSensor):
			_sensor_panel.bind(selected, _sensor_bridge)
		elif _sensor_panel:
			_sensor_panel.hide_panel()

		# Show diverter panel if applicable.
		if _diverter_panel and selected is Diverter:
			_diverter_panel.bind(selected, _sensor_bridge)
		elif _diverter_panel:
			_diverter_panel.hide_panel()
	else:
		_hud.unbind_properties()
		_hud.hide_action_wheel()
		_hud.set_status("Click a part to place it, or click an object to select it.")
		if _curved_panel:
			_curved_panel.hide_panel()
		if _sensor_panel:
			_sensor_panel.hide_panel()
		if _diverter_panel:
			_diverter_panel.hide_panel()


func _on_action_wheel_requested(screen_pos: Vector2) -> void:
	_hud.show_action_wheel(screen_pos)


func _on_action_mode_selected(mode: String) -> void:
	_selection.set_active_mode(mode)


func _on_pause_requested() -> void:
	_paused = not _paused
	SimulationManager.set_paused(_paused)
	_hud.update_pause_button(_paused)
	_hud.set_status("Simulation %s." % ("paused" if _paused else "resumed"))


# ── Global input (keyboard shortcuts) ───────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			match key.keycode:
				KEY_TAB:
					# Toggle parts panel visibility.
					if _hud.has_node("PanelContainer"):
						pass  # handled inside HUD
				KEY_SPACE:
					_on_pause_requested()
					get_viewport().set_input_as_handled()
