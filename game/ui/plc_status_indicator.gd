extends Control
## Small coloured circle in the top-right corner of the HUD that shows
## the current PLC connection state.  Green = connected, Red = disconnected.
## Clicking the circle opens an information popup.

const RADIUS := 12.0
const MARGIN_RIGHT := 20.0
const MARGIN_TOP := 8.0

var _connected: bool = false
var _info_popup: AcceptDialog = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "SPS Connection Status – click for details"

	# Position: top-right, next to the toolbar.
	custom_minimum_size = Vector2(RADIUS * 2 + 4, RADIUS * 2 + 4)
	size = custom_minimum_size

	# Listen to connection changes.
	PlcConnectionManager.connection_state_changed.connect(_on_connection_changed)
	_connected = PlcConnectionManager.is_connected

	# Build the info popup (hidden by default).
	_info_popup = AcceptDialog.new()
	_info_popup.title = "SPS Connection Info"
	_info_popup.size = Vector2i(340, 200)
	_info_popup.exclusive = true
	_info_popup.transient = true
	add_child(_info_popup)


func _draw() -> void:
	var center := Vector2(size.x / 2.0, size.y / 2.0)
	var color := Color("#8eef97") if _connected else Color("#ff786b")
	draw_circle(center, RADIUS, color)
	# Thin border for visibility.
	draw_arc(center, RADIUS, 0, TAU, 32, Color(0.2, 0.2, 0.2, 0.6), 1.5)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_show_info()
			accept_event()


func _on_connection_changed(connected: bool) -> void:
	_connected = connected
	queue_redraw()


func _show_info() -> void:
	var info := PlcConnectionManager.get_connection_info()
	var text := ""
	text += "Status:  %s\n" % info["status"]
	text += "IP:          %s\n" % info["ip"]
	text += "CPU:       %s\n" % info["cpu"]
	text += "Rack:      %d\n" % info["rack"]
	text += "Slot:       %d\n" % info["slot"]

	_info_popup.dialog_text = text
	_info_popup.popup_centered()
