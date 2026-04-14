extends PanelContainer
## Right-side panel that appears when a curved conveyor is selected.
##
## Contains a slider to adjust the inner radius of curved belt / roller
## conveyors.  Automatically hides when no curved conveyor is selected.

signal radius_changed(new_radius: float)

const MIN_RADIUS: float = 0.1
const MAX_RADIUS: float = 5.0
const RADIUS_STEP: float = 0.05

var _target: Node3D = null

var _title_label: Label
var _radius_label: Label
var _radius_slider: HSlider
var _radius_value_label: Label
var _width_label: Label
var _width_slider: HSlider
var _width_value_label: Label
var _angle_label: Label
var _angle_slider: HSlider
var _angle_value_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_ui()


func _build_ui() -> void:
	# Panel styling.
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.16, 0.94)
	style.corner_radius_top_left = 6
	style.corner_radius_bottom_left = 6
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	# Title.
	_title_label = Label.new()
	_title_label.text = "  Curved Conveyor"
	_title_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_title_label)

	# Separator.
	vbox.add_child(HSeparator.new())

	# ── Radius slider ───────────────────────────────────────────────────
	_radius_label = Label.new()
	_radius_label.text = "  Inner Radius"
	vbox.add_child(_radius_label)

	var radius_hbox := HBoxContainer.new()
	radius_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(radius_hbox)

	_radius_slider = HSlider.new()
	_radius_slider.min_value = MIN_RADIUS
	_radius_slider.max_value = MAX_RADIUS
	_radius_slider.step = RADIUS_STEP
	_radius_slider.value = 0.5
	_radius_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_radius_slider.custom_minimum_size.x = 140
	_radius_slider.value_changed.connect(_on_radius_slider_changed)
	radius_hbox.add_child(_radius_slider)

	_radius_value_label = Label.new()
	_radius_value_label.text = "0.50 m"
	_radius_value_label.custom_minimum_size.x = 50
	radius_hbox.add_child(_radius_value_label)

	# ── Width slider ────────────────────────────────────────────────────
	_width_label = Label.new()
	_width_label.text = "  Width"
	vbox.add_child(_width_label)

	var width_hbox := HBoxContainer.new()
	width_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(width_hbox)

	_width_slider = HSlider.new()
	_width_slider.min_value = 0.1
	_width_slider.max_value = 5.0
	_width_slider.step = 0.05
	_width_slider.value = 1.524
	_width_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_width_slider.custom_minimum_size.x = 140
	_width_slider.value_changed.connect(_on_width_slider_changed)
	width_hbox.add_child(_width_slider)

	_width_value_label = Label.new()
	_width_value_label.text = "1.52 m"
	_width_value_label.custom_minimum_size.x = 50
	width_hbox.add_child(_width_value_label)

	# ── Angle slider ────────────────────────────────────────────────────
	_angle_label = Label.new()
	_angle_label.text = "  Angle"
	vbox.add_child(_angle_label)

	var angle_hbox := HBoxContainer.new()
	angle_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(angle_hbox)

	_angle_slider = HSlider.new()
	_angle_slider.min_value = 10.0
	_angle_slider.max_value = 180.0
	_angle_slider.step = 5.0
	_angle_slider.value = 90.0
	_angle_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_angle_slider.custom_minimum_size.x = 140
	_angle_slider.value_changed.connect(_on_angle_slider_changed)
	angle_hbox.add_child(_angle_slider)

	_angle_value_label = Label.new()
	_angle_value_label.text = "90°"
	_angle_value_label.custom_minimum_size.x = 50
	angle_hbox.add_child(_angle_value_label)


## Show the panel for the given curved conveyor.
func show_for(target: Node3D) -> void:
	_target = target
	visible = true
	_sync_from_target()


## Hide the panel.
func hide_panel() -> void:
	_target = null
	visible = false


## Update slider values from the current target.
func _sync_from_target() -> void:
	if not _target or not is_instance_valid(_target):
		return

	var conveyor := _target.get_node_or_null("ConveyorCorner")
	if not conveyor:
		return

	var radius: float = conveyor.get("inner_radius")
	var width: float = conveyor.get("conveyor_width")
	var angle: float = conveyor.get("conveyor_angle")

	_radius_slider.set_value_no_signal(radius)
	_radius_value_label.text = "%.2f m" % radius
	_width_slider.set_value_no_signal(width)
	_width_value_label.text = "%.2f m" % width
	_angle_slider.set_value_no_signal(angle)
	_angle_value_label.text = "%d°" % int(angle)


func _process(_delta: float) -> void:
	if visible and _target and is_instance_valid(_target):
		# Keep sliders in sync if values change externally (e.g. via resize gizmo).
		_sync_from_target()


# ── Slider callbacks ─────────────────────────────────────────────────────────

func _on_radius_slider_changed(value: float) -> void:
	_radius_value_label.text = "%.2f m" % value
	_apply_to_target("inner_radius", value)
	radius_changed.emit(value)


func _on_width_slider_changed(value: float) -> void:
	_width_value_label.text = "%.2f m" % value
	_apply_to_target("conveyor_width", value)


func _on_angle_slider_changed(value: float) -> void:
	_angle_value_label.text = "%d°" % int(value)
	_apply_to_target("conveyor_angle", value)


func _apply_to_target(property: String, value: float) -> void:
	if not _target or not is_instance_valid(_target):
		return
	var conveyor := _target.get_node_or_null("ConveyorCorner")
	if conveyor:
		conveyor.set(property, value)
	# Trigger attachment update on the assembly.
	if _target.has_method("_update_attachments"):
		_target._attachment_update_needed = true
		_target._update_attachments()
