extends PanelContainer
## Right-side panel for editing Box properties (color selection).
##
## When a [Box] node is selected in the simulation, this panel shows a color
## picker that allows the user to choose red, blue, or green for the box.
## The [ColorSensor] can then detect and distinguish these colors.

var _target: Box = null

var _title: Label
var _color_label: Label
var _btn_red: Button
var _btn_green: Button
var _btn_blue: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	# Styling – matches the other property panels.
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.16, 0.94)
	style.corner_radius_top_left = 6
	style.corner_radius_bottom_left = 6
	add_theme_stylebox_override("panel", style)

	# Anchored to the right edge.
	anchor_top = 0.0
	anchor_bottom = 0.0
	anchor_left = 1.0
	anchor_right = 1.0
	offset_top = 50
	offset_left = -260
	offset_right = 0
	offset_bottom = 310

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	# Title.
	_title = Label.new()
	_title.text = "  Box"
	_title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(_title)

	vbox.add_child(HSeparator.new())

	# Color label.
	_color_label = Label.new()
	_color_label.text = "  Farbe wählen"
	_color_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_color_label)

	# Description.
	var desc := Label.new()
	desc.text = "  Der Color Sensor erkennt diese Farben."
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color("#aaaaaa"))
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
	current_lbl.text = "  Aktuelle Farbe:"
	vbox.add_child(current_lbl)


## Bind the panel to a selected Box node. Shows the panel only for Box
## instances; hides it for everything else.
func bind(node: Node3D) -> void:
	if node is Box:
		_target = node as Box
		_title.text = "  %s" % _target.name
		_update_button_states()
		visible = true
	else:
		hide_panel()


func unbind() -> void:
	hide_panel()


func hide_panel() -> void:
	_target = null
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
	_target.color = color
	_update_button_states()


func _update_button_states() -> void:
	if not _target:
		return
	_btn_red.button_pressed = _target.color.is_equal_approx(Color.RED)
	_btn_green.button_pressed = _target.color.is_equal_approx(Color.GREEN)
	_btn_blue.button_pressed = _target.color.is_equal_approx(Color.BLUE)
