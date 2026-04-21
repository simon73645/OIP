extends PanelContainer
## Right-side panel for editing Box and BoxSpawner color properties.
##
## When a [Box] or [BoxSpawner] node is selected in the simulation, this panel
## shows a color picker that allows the user to choose red, blue, or green.
## The [ColorSensor] can then detect and distinguish these colors.
## For [BoxSpawner] nodes the chosen color is applied to all future spawned boxes.

const UITheme := preload("res://game/ui/ui_theme.gd")
const PanelMinimizer := preload("res://game/ui/panel_minimizer.gd")

var _target: Node3D = null

var _title: Label
var _color_label: Label
var _btn_red: Button
var _btn_green: Button
var _btn_blue: Button

var _minimizer: PanelMinimizer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	# Modern panel styling.
	add_theme_stylebox_override("panel", UITheme.make_right_panel_style())

	# Anchored to the right edge.
	anchor_top = 0.0
	anchor_bottom = 0.0
	anchor_left = 1.0
	anchor_right = 1.0
	offset_top = 60
	offset_left = -280
	offset_right = 0
	offset_bottom = 320

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	# Header with title + close button.
	var header := UITheme.make_panel_header("Box")
	_title = header["title"] as Label
	vbox.add_child(header["container"])
	(header["close"] as Button).pressed.connect(_on_close_pressed)

	vbox.add_child(HSeparator.new())

	# Color label.
	_color_label = Label.new()
	_color_label.text = "Farbe wählen"
	UITheme.style_title_label(_color_label, 14)
	vbox.add_child(_color_label)

	# Description.
	var desc := Label.new()
	desc.text = "Der Color Sensor erkennt diese Farben."
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	# Color buttons.
	var btn_container := HBoxContainer.new()
	btn_container.add_theme_constant_override("separation", 8)
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_container)

	_btn_red = _create_color_button("Rot", Color.RED)
	_btn_red.pressed.connect(_on_color_selected.bind(Color.RED))
	btn_container.add_child(_btn_red)

	_btn_green = _create_color_button("Grün", Color.GREEN)
	_btn_green.pressed.connect(_on_color_selected.bind(Color.GREEN))
	btn_container.add_child(_btn_green)

	_btn_blue = _create_color_button("Blau", Color.BLUE)
	_btn_blue.pressed.connect(_on_color_selected.bind(Color.BLUE))
	btn_container.add_child(_btn_blue)

	vbox.add_child(HSeparator.new())

	# Current color indicator.
	var current_lbl := Label.new()
	current_lbl.text = "Aktuelle Farbe:"
	UITheme.style_muted_label(current_lbl)
	vbox.add_child(current_lbl)

	_minimizer = PanelMinimizer.new(self, "Box Eigenschaften öffnen")
	_minimizer.position_right_side(260.0)


func _on_close_pressed() -> void:
	if _minimizer:
		_minimizer.minimize()


## Bind the panel to a selected Box or BoxSpawner node. Shows the panel only
## for Box and BoxSpawner instances; hides it for everything else.
func bind(node: Node3D) -> void:
	if node is Box:
		_target = node as Box
		_title.text = "%s" % _target.name
		if _minimizer:
			_minimizer.reset_for_new_target()
		_update_button_states()
		visible = true
	elif node is BoxSpawner:
		_target = node as BoxSpawner
		_title.text = "%s" % _target.name
		if _minimizer:
			_minimizer.reset_for_new_target()
		_update_button_states()
		visible = true
	else:
		hide_panel()


func unbind() -> void:
	hide_panel()


func hide_panel() -> void:
	_target = null
	if _minimizer:
		_minimizer.hide_all()
	else:
		visible = false


func _create_color_button(label: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(60, 36)
	btn.toggle_mode = true
	# Color the button text to match.
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = color.darkened(0.4)
	style_normal.corner_radius_top_left = 4
	style_normal.corner_radius_top_right = 4
	style_normal.corner_radius_bottom_left = 4
	style_normal.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", style_normal)

	var style_pressed := StyleBoxFlat.new()
	style_pressed.bg_color = color
	style_pressed.corner_radius_top_left = 4
	style_pressed.corner_radius_top_right = 4
	style_pressed.corner_radius_bottom_left = 4
	style_pressed.corner_radius_bottom_right = 4
	style_pressed.border_width_bottom = 3
	style_pressed.border_width_top = 3
	style_pressed.border_width_left = 3
	style_pressed.border_width_right = 3
	style_pressed.border_color = Color.WHITE
	btn.add_theme_stylebox_override("pressed", style_pressed)

	var style_hover := StyleBoxFlat.new()
	style_hover.bg_color = color.darkened(0.2)
	style_hover.corner_radius_top_left = 4
	style_hover.corner_radius_top_right = 4
	style_hover.corner_radius_bottom_left = 4
	style_hover.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("hover", style_hover)

	return btn


func _on_color_selected(color: Color) -> void:
	if not _target:
		return
	if _target is Box:
		(_target as Box).color = color
	elif _target is BoxSpawner:
		(_target as BoxSpawner).box_color = color
	_update_button_states()


func _update_button_states() -> void:
	if not _target:
		return
	var current_color: Color = Color.WHITE
	if _target is Box:
		current_color = (_target as Box).color
	elif _target is BoxSpawner:
		current_color = (_target as BoxSpawner).box_color
	_btn_red.button_pressed = current_color.is_equal_approx(Color.RED)
	_btn_green.button_pressed = current_color.is_equal_approx(Color.GREEN)
	_btn_blue.button_pressed = current_color.is_equal_approx(Color.BLUE)
