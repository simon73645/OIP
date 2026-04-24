extends ScrollContainer
## Visuelle 3D-Vorschau-Auswahl der platzierbaren Parts.
##
## Zeigt für jedes Part eine kleine Karte mit Name und einer 3D-Vorschau.
## Die Vorschau wird live über einen [SubViewport] gerendert, in den die
## Szene des jeweiligen Parts geladen wird.  So sieht der User sofort,
## was er platzieren möchte – ohne nur Text zu lesen.
##
## Wird beim Klick auf eine Karte das Signal [signal part_selected] mit
## dem Pfad zur Szene ausgelöst.

signal part_selected(scene_path: String)

const UITheme := preload("res://game/ui/ui_theme.gd")

const CARD_SIZE := Vector2(140, 150)
const PREVIEW_SIZE := Vector2i(128, 96)

var _grid: GridContainer
var _entries: Array[Dictionary] = []  # mirror of HUD parts list


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_grid)


## Replace the displayed cards with the given list of parts.
##
## [param parts] is an array of dictionaries with keys "name" and "path"
## (matching the structure used by the HUD parts catalogue).
func set_parts(parts: Array) -> void:
	_entries = []
	for p: Dictionary in parts:
		_entries.append(p)
	_rebuild()


func _rebuild() -> void:
	# Free existing cards.
	for child in _grid.get_children():
		child.queue_free()

	for entry: Dictionary in _entries:
		var card := _build_card(entry)
		if card:
			_grid.add_child(card)


func _build_card(entry: Dictionary) -> Control:
	var name_text: String = entry.get("name", "")
	var path: String = entry.get("path", "")
	if path == "":
		return null

	var card := PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.18, 0.22, 1.0)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = UITheme.BORDER_SUBTLE
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	# Preview area.
	var preview := _build_preview(path)
	if preview:
		vbox.add_child(preview)

	# Name label (centered, ellipsised if too long).
	var lbl := Label.new()
	lbl.text = name_text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl.clip_text = true
	UITheme.style_title_label(lbl, 12)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(lbl)

	# Make the entire card clickable.
	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.tooltip_text = "Platzieren: %s" % name_text
	btn.pressed.connect(func() -> void: part_selected.emit(path))
	card.add_child(btn)

	return card


## Build the 3D preview viewport for a given scene path.  Returns a [Control]
## that hosts a [SubViewportContainer].
func _build_preview(scene_path: String) -> Control:
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		return _build_preview_fallback()

	var instance: Node = packed.instantiate()
	if not (instance is Node3D):
		instance.queue_free()
		return _build_preview_fallback()

	var node3d := instance as Node3D

	var container := SubViewportContainer.new()
	container.stretch = true
	container.custom_minimum_size = PREVIEW_SIZE
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var viewport := SubViewport.new()
	viewport.size = PREVIEW_SIZE
	viewport.transparent_bg = true
	viewport.disable_3d = false
	viewport.handle_input_locally = false
	# Start disabled; we trigger an UPDATE_ONCE only after the camera has
	# been framed around the part's bounding box (see _frame_camera).
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	# Use a dedicated world so the part doesn't collide with the simulation.
	viewport.own_world_3d = true
	container.add_child(viewport)

	# Lighting.
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -35, 0)
	light.light_energy = 1.0
	viewport.add_child(light)

	var ambient := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.09, 0.12, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.65, 0.75)
	env.ambient_light_energy = 0.5
	ambient.environment = env
	viewport.add_child(ambient)

	# Place the instance in the viewport.
	viewport.add_child(node3d)

	# Camera framed on the instance's bounding box.
	var cam := Camera3D.new()
	cam.current = true
	viewport.add_child(cam)
	# Frame after the instance is in the tree (next idle frame ensures any
	# deferred geometry has been built).
	cam.call_deferred("look_at", Vector3.ZERO, Vector3.UP)
	_frame_camera_deferred(cam, node3d)

	# Trigger an additional update once the scene has settled.  The deferred
	# camera-framing call also requests an UPDATE_ONCE pass after positioning.
	viewport.call_deferred("set", "render_target_update_mode", SubViewport.UPDATE_ONCE)

	return container


func _frame_camera_deferred(cam: Camera3D, node3d: Node3D) -> void:
	# Defer twice so the node has a chance to update its bounding box.
	call_deferred("_frame_camera", cam, node3d)


func _frame_camera(cam: Camera3D, node3d: Node3D) -> void:
	if not is_instance_valid(cam) or not is_instance_valid(node3d):
		return
	var aabb := _compute_aabb(node3d)
	if aabb.size == Vector3.ZERO:
		# Fallback: small default frame.
		cam.transform.origin = Vector3(2, 1.5, 2.5)
		cam.look_at(Vector3.ZERO, Vector3.UP)
		return
	var center := aabb.position + aabb.size * 0.5
	var radius := aabb.size.length() * 0.6
	if radius < 0.5:
		radius = 0.5
	# Position the camera at an isometric-ish angle.
	var dir := Vector3(1, 0.7, 1).normalized()
	cam.transform.origin = center + dir * radius * 2.4
	cam.look_at(center, Vector3.UP)
	# Re-render once the camera has been positioned.
	var vp := cam.get_viewport() as SubViewport
	if vp:
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE


## Compute an aggregate world-space AABB for [param root] by walking
## VisualInstance3D children.  Works even before the node is fully ready
## as long as it is in a scene tree.
static func _compute_aabb(root: Node3D) -> AABB:
	var aabb := AABB()
	var first := true
	var stack: Array = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is VisualInstance3D:
			var v := node as VisualInstance3D
			# get_aabb() returns the AABB in the instance's local space.
			# Transform it into world space using the global transform.
			var local_box := v.get_aabb()
			var world_box := v.global_transform * local_box
			if first:
				aabb = world_box
				first = false
			else:
				aabb = aabb.merge(world_box)
		for c in node.get_children():
			stack.append(c)
	return aabb


## Plain placeholder when the scene cannot be loaded as Node3D.
func _build_preview_fallback() -> Control:
	var lbl := Label.new()
	lbl.text = "(keine Vorschau)"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.custom_minimum_size = PREVIEW_SIZE
	lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	return lbl
