## Autoload singleton that manages the runtime SPS/PLC connection.
##
## Holds the Plc node, exposes connection state, and re-emits relevant
## EventBus signals so that any UI element can react to connection changes
## without knowing about the plugin internals.
extends Node

# ── Signals ──────────────────────────────────────────────────────────────────

## Emitted whenever the connection state changes (true = connected).
signal connection_state_changed(connected: bool)

## Emitted when connection details change (for the info dialog).
signal connection_info_updated(info: Dictionary)

# ── Public state ─────────────────────────────────────────────────────────────

## The Plc node instance managed by this singleton.  Created lazily on first
## connect request.
var plc_node: Node = null

## Current connection parameters (persisted across connect/disconnect).
var plc_ip: String = "192.168.0.1"
var plc_cpu_type: int = 40  # CpuType.S71500
var plc_rack: int = 0
var plc_slot: int = 1

## Cached connection status.
var is_connected: bool = false


# ── CPU type helpers ─────────────────────────────────────────────────────────

## Mapping from display name → CpuType enum value used by the C# Plc class.
const CPU_TYPES: Dictionary = {
	"S7-200": 0,
	"Logo 0BA8": 1,
	"S7-200 Smart": 2,
	"S7-300": 10,
	"S7-400": 20,
	"S7-1200": 30,
	"S7-1500": 40,
}

## Returns ordered list of display names.
static func get_cpu_type_names() -> Array:
	return CPU_TYPES.keys()


## Returns the CpuType int for a display name.
static func cpu_type_from_name(display_name: String) -> int:
	return CPU_TYPES.get(display_name, 40)


## Returns the display name for a CpuType int.
static func cpu_type_to_name(cpu_type: int) -> String:
	for key: String in CPU_TYPES:
		if CPU_TYPES[key] == cpu_type:
			return key
	return "S7-1500"


# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Connect to EventBus signals emitted by the siemens_plugin C# layer.
	_connect_event_bus()


func _connect_event_bus() -> void:
	if not EventBus:
		return
	EventBus.plc_connected.connect(_on_plc_connected)
	EventBus.plc_disconnected.connect(_on_plc_disconnected)
	EventBus.plc_connection_lost.connect(_on_plc_connection_lost)
	EventBus.plc_already_disconnected.connect(_on_plc_already_disconnected)
	EventBus.plc_connection_failed.connect(_on_plc_connection_failed)


# ── Public API ───────────────────────────────────────────────────────────────

## Ensures a Plc node exists in the scene tree with the current parameters.
func _ensure_plc_node() -> void:
	if plc_node and is_instance_valid(plc_node):
		# Update properties on existing node.
		plc_node.set("IP", plc_ip)
		plc_node.set("CPU", plc_cpu_type)
		plc_node.set("Rack", plc_rack)
		plc_node.set("Slot", plc_slot)
		return

	# Instantiate the S7-1500 scene which contains the Plc C# script.
	var plc_scene := load("res://addons/siemens_plugin/plc/s7-1500/s7_1500.tscn") as PackedScene
	if not plc_scene:
		push_error("PlcConnectionManager: Could not load S7-1500 scene.")
		return

	plc_node = plc_scene.instantiate()
	plc_node.name = "PlcRuntime"
	plc_node.set("IP", plc_ip)
	plc_node.set("CPU", plc_cpu_type)
	plc_node.set("Rack", plc_rack)
	plc_node.set("Slot", plc_slot)
	add_child(plc_node)


## Start the connection process.
func connect_plc() -> void:
	_ensure_plc_node()
	plc_node.set("ValidConfiguration", true)
	plc_node.call("ConnectPlc", EventBus)


## Disconnect from the PLC.
func disconnect_plc() -> void:
	if plc_node and is_instance_valid(plc_node):
		plc_node.call("Disconnect", EventBus)


## Ping the PLC.
func ping_plc() -> void:
	if plc_node and is_instance_valid(plc_node):
		plc_node.set("ValidConfiguration", true)
		plc_node.call("PingPlc", EventBus)


## Set the PLC online/offline (enables data exchange).
func set_online(value: bool) -> void:
	if plc_node and is_instance_valid(plc_node):
		plc_node.set("IsOnline", value)


## Returns a dictionary with current connection info for display.
func get_connection_info() -> Dictionary:
	var status_text := "Disconnected"
	if is_connected:
		status_text = "Connected"
	elif plc_node and is_instance_valid(plc_node):
		var cs: int = plc_node.get("CurrentStatus")
		match cs:
			0: status_text = "Connected"
			1: status_text = "Disconnected"
			_: status_text = "Unknown"

	return {
		"status": status_text,
		"ip": plc_ip,
		"cpu": cpu_type_to_name(plc_cpu_type),
		"rack": plc_rack,
		"slot": plc_slot,
		"connected": is_connected,
	}


## Returns the managed Plc node (or null).
func get_plc_node() -> Node:
	return plc_node if plc_node and is_instance_valid(plc_node) else null


# ── EventBus callbacks ───────────────────────────────────────────────────────

func _on_plc_connected(_plc: Node) -> void:
	is_connected = true
	connection_state_changed.emit(true)
	connection_info_updated.emit(get_connection_info())


func _on_plc_disconnected(_plc: Node) -> void:
	is_connected = false
	connection_state_changed.emit(false)
	connection_info_updated.emit(get_connection_info())


func _on_plc_connection_lost(_plc: Node) -> void:
	is_connected = false
	connection_state_changed.emit(false)
	connection_info_updated.emit(get_connection_info())


func _on_plc_already_disconnected(_plc: Node) -> void:
	is_connected = false
	connection_state_changed.emit(false)
	connection_info_updated.emit(get_connection_info())


func _on_plc_connection_failed(_plc: Node, _error: String) -> void:
	is_connected = false
	connection_state_changed.emit(false)
	connection_info_updated.emit(get_connection_info())
