extends Control
## In-game HUD: top toolbar, left-side parts catalogue, bottom status bar,
## action wheel and conveyor properties panel.
##
## The parts catalogue lists every *.tscn file in res://parts/ (excluding
## Building.tscn which is loaded automatically).  Clicking a part activates
## placement mode; toolbar buttons switch between Select / Delete modes.
## Move / Rotate / Scale are handled via the action wheel that appears when
## an object is selected or right-clicked.
##
## The catalogue can be displayed either as a textual list (default) or as a
## visual grid of 3D-preview cards by toggling the "3D Preview" checkbox.

signal part_selected(scene_path: String)
signal mode_changed(mode: String)
signal simulation_pause_requested
signal action_mode_selected(mode: String)
signal save_requested
signal load_requested

const ActionWheelScript := preload("res://game/ui/action_wheel.gd")
const ConveyorPropertiesPanelScript := preload("res://game/ui/conveyor_properties_panel.gd")
const PlcConnectionDialogScript := preload("res://game/ui/plc_connection_dialog.gd")
const PlcStatusIndicatorScript := preload("res://game/ui/plc_status_indicator.gd")
const HelpDialogScript := preload("res://game/ui/help_dialog.gd")
const PartsPreviewGridScript := preload("res://game/ui/parts_preview_grid.gd")
const UITheme := preload("res://game/ui/ui_theme.gd")

# ── Nodes built at runtime ───────────────────────────────────────────────────

var _toolbar: HBoxContainer
var _mode_buttons: Dictionary = {}  # mode_name -> Button
var _parts_panel: PanelContainer
var _parts_list: ItemList
var _parts_preview: ScrollContainer  # PartsPreviewGrid
var _preview_checkbox: CheckBox
var _search_bar: LineEdit
var _status_label: Label
var _pause_button: Button

var _action_wheel: Control
var _conveyor_panel: PanelContainer
var _plc_dialog: Window
var _plc_indicator: Control
var _help_dialog: Window

var _current_mode: String = "select"
var _preview_mode: bool = false

# Part catalogue data.  Each entry: { "name": String, "path": String }
var _parts: Array[Dictionary] = []

# ── Categories for the parts ─────────────────────────────────────────────────

const ASSEMBLY_SUFFIX := "Assembly"

const CATEGORIES: Dictionary = {
	"All": [],
	"Conveyors": [
		"BeltConveyorAssembly", "BeltSpurConveyorAssembly", "CurvedBeltConveyorAssembly",
		"RollerConveyorAssembly", "CurvedRollerConveyorAssembly", "RollerSpurConveyorAssembly",
	],
	"Sensors": [
		"LaserSensor", "ColorSensor", "DiffuseSensor",
	],
	"Equipment": [
		"SixAxisRobot", "StackLight", "PushButton",
		"Diverter", "ChainTransfer", "BladeStop",
	],
	"Spawners": [
		"BoxSpawner", "PalletSpawner", "Despawner",
	],
	"Objects": [
		"Box", "Pallet",
	],
}

var _category_tabs: TabBar
var _current_category: String = "All"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scan_parts()
	_build_ui()
	_populate_parts_list()


# ── Part scanning ────────────────────────────────────────────────────────────

func _scan_parts() -> void:
	_parts.clear()

	# Build a set of all base names that appear in at least one category.
	# Only assemblies listed in a category are considered user-facing parts;
	# the rest (ConveyorLegsAssembly, SideGuardsAssembly, etc.) are internal
	# building blocks used by the composite assemblies.
	var _categorized_bases: Dictionary = {}
	for cat_items: Array in CATEGORIES.values():
		for base_name: String in cat_items:
			_categorized_bases[base_name] = true

	# Scan assemblies first so we can identify bare parts that have assembly
	# counterparts.  Those bare parts are building blocks used internally by
	# the assemblies and should not be offered for direct placement because
	# they lack legs, side-guards, etc.
	var _assembly_bases: Array[String] = []
	var asm_dir := DirAccess.open("res://parts/assemblies")
	if asm_dir:
		asm_dir.list_dir_begin()
		var file_name := asm_dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tscn"):
				var base_name := file_name.get_basename()
				# Only include assemblies that are listed in a category.
				# Internal building-block assemblies (e.g. ConveyorLegsAssembly,
				# SideGuardsAssembly) are skipped.
				if _categorized_bases.has(base_name):
					_assembly_bases.append(base_name)
					# Display assemblies under their short name (without
					# "Assembly" suffix) so the catalogue reads e.g.
					# "Belt Conveyor" instead of "Belt Conveyor Assembly".
					var display_name := base_name
					if display_name.ends_with(ASSEMBLY_SUFFIX):
						display_name = display_name.substr(0, display_name.length() - ASSEMBLY_SUFFIX.length())
					_parts.append({
						"name": _humanize(display_name),
						"base": base_name,
						"path": "res://parts/assemblies/" + file_name,
					})
			file_name = asm_dir.get_next()
		asm_dir.list_dir_end()

	# Build a set of bare part names that are superseded by an assembly.
	# e.g. "BeltConveyorAssembly" supersedes "BeltConveyor".
	var _superseded_bases: Dictionary = {}
	for asm_base: String in _assembly_bases:
		if asm_base.ends_with(ASSEMBLY_SUFFIX):
			var bare_base := asm_base.substr(0, asm_base.length() - ASSEMBLY_SUFFIX.length())
			_superseded_bases[bare_base] = true

	# Non-placeable scenes (root is not Node3D).
	var _skip_scenes: Dictionary = { "GenericData": true }

	var dir := DirAccess.open("res://parts")
	if not dir:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	var excluded_files = ["Building.tscn", "ConveyorLeg.tscn", "ConveyorLegC.tscn", "Gantry.tscn", "SixAxisRobot.tscn", "SideGuardsCBC.tscn"]
	while file_name != "":
		if file_name.ends_with(".tscn") and not file_name in excluded_files:
			var base_name := file_name.get_basename()
			# Skip bare parts that have a corresponding assembly version,
			# and non-placeable scenes whose root is not Node3D.
			if not _superseded_bases.has(base_name) and not _skip_scenes.has(base_name):
				_parts.append({
					"name": _humanize(base_name),
					"base": base_name,
					"path": "res://parts/" + file_name,
				})
		file_name = dir.get_next()
	dir.list_dir_end()
	_parts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["name"] < b["name"])


static func _humanize(pascal: String) -> String:
	# "BeltConveyor" → "Belt Conveyor"
	var result := ""
	for i in range(pascal.length()):
		var c := pascal[i]
		if i > 0 and c == c.to_upper() and c != c.to_lower():
			var prev := pascal[i - 1]
			if prev != prev.to_upper() or prev == prev.to_lower():
				result += " "
		result += c
	return result


# ── UI construction ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	# ── Top toolbar ──────────────────────────────────────────────────────
	var top_bar := PanelContainer.new()
	top_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	top_bar.add_theme_stylebox_override("panel", UITheme.make_top_bar_style())
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar.custom_minimum_size.y = 50
	add_child(top_bar)

	_toolbar = HBoxContainer.new()
	_toolbar.alignment = BoxContainer.ALIGNMENT_CENTER
	_toolbar.add_theme_constant_override("separation", 8)
	top_bar.add_child(_toolbar)

	# App brand (left).
	var brand := Label.new()
	brand.text = "  ⚙  Open Industry"
	UITheme.style_title_label(brand, 16)
	_toolbar.add_child(brand)

	var brand_spacer := Control.new()
	brand_spacer.custom_minimum_size = Vector2(20, 0)
	_toolbar.add_child(brand_spacer)

	# Only Select and Delete remain in the toolbar.
	# Move / Rotate / Scale are accessed via the action wheel.
	for mode_name: String in ["select", "delete"]:
		var btn := Button.new()
		btn.text = mode_name.capitalize()
		btn.toggle_mode = true
		btn.button_pressed = (mode_name == "select")
		btn.custom_minimum_size = Vector2(80, 36)
		UITheme.style_toggle_button(btn)
		btn.pressed.connect(_on_mode_button_pressed.bind(mode_name))
		_toolbar.add_child(btn)
		_mode_buttons[mode_name] = btn

	# Spacer.
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_toolbar.add_child(spacer)

	# Save button.
	var save_btn := Button.new()
	save_btn.text = "💾  Speichern"
	save_btn.custom_minimum_size = Vector2(120, 36)
	UITheme.style_button(save_btn)
	save_btn.pressed.connect(func() -> void: save_requested.emit())
	_toolbar.add_child(save_btn)

	# Load button.
	var load_btn := Button.new()
	load_btn.text = "📂  Laden"
	load_btn.custom_minimum_size = Vector2(110, 36)
	UITheme.style_button(load_btn)
	load_btn.pressed.connect(func() -> void: load_requested.emit())
	_toolbar.add_child(load_btn)

	# Pause / Resume button.
	_pause_button = Button.new()
	_pause_button.text = "⏸  Pause"
	_pause_button.custom_minimum_size = Vector2(110, 36)
	UITheme.style_button(_pause_button, UITheme.ACCENT_WARNING)
	_pause_button.pressed.connect(func() -> void: simulation_pause_requested.emit())
	_toolbar.add_child(_pause_button)

	# Connection button – opens the PLC connection dialog.
	var connection_btn := Button.new()
	connection_btn.text = "🔌  Connection"
	connection_btn.custom_minimum_size = Vector2(140, 36)
	UITheme.style_button(connection_btn)
	connection_btn.pressed.connect(_on_connection_button_pressed)
	_toolbar.add_child(connection_btn)

	# Help button – opens the help / shortcuts dialog.
	var help_btn := Button.new()
	help_btn.text = "❓  Hilfe"
	help_btn.tooltip_text = "Tastenkombinationen und Features anzeigen"
	help_btn.custom_minimum_size = Vector2(100, 36)
	UITheme.style_button(help_btn, UITheme.ACCENT_SUCCESS)
	help_btn.pressed.connect(_on_help_button_pressed)
	_toolbar.add_child(help_btn)

	# PLC status indicator (green/red circle).
	_plc_indicator = Control.new()
	_plc_indicator.name = "PlcStatusIndicator"
	_plc_indicator.set_script(PlcStatusIndicatorScript)
	_toolbar.add_child(_plc_indicator)

	# ── Left parts panel ────────────────────────────────────────────────
	_parts_panel = PanelContainer.new()
	_parts_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_parts_panel.add_theme_stylebox_override("panel", UITheme.make_left_panel_style())
	_parts_panel.anchor_top = 0.0
	_parts_panel.anchor_bottom = 1.0
	_parts_panel.anchor_left = 0.0
	_parts_panel.anchor_right = 0.0
	_parts_panel.offset_top = 60
	_parts_panel.offset_bottom = -50
	_parts_panel.offset_right = 290
	add_child(_parts_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_parts_panel.add_child(vbox)

	# Title.
	var title := Label.new()
	title.text = "Equipment"
	UITheme.style_title_label(title, 18)
	vbox.add_child(title)

	# Search.
	_search_bar = LineEdit.new()
	_search_bar.placeholder_text = "🔍  Suchen..."
	_search_bar.clear_button_enabled = true
	UITheme.style_line_edit(_search_bar)
	_search_bar.text_changed.connect(func(_t: String) -> void: _populate_parts_list())
	vbox.add_child(_search_bar)

	# 3D Preview checkbox.
	_preview_checkbox = CheckBox.new()
	_preview_checkbox.text = "  3D Preview"
	_preview_checkbox.tooltip_text = "Parts als visuelle Karten mit 3D-Vorschau anzeigen."
	_preview_checkbox.toggled.connect(_on_preview_toggled)
	vbox.add_child(_preview_checkbox)

	# Category tabs.
	_category_tabs = TabBar.new()
	for cat_name: String in CATEGORIES.keys():
		_category_tabs.add_tab(cat_name)
	_category_tabs.tab_changed.connect(_on_category_changed)
	vbox.add_child(_category_tabs)

	# Parts list (default view).
	_parts_list = ItemList.new()
	_parts_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_parts_list.icon_mode = ItemList.ICON_MODE_LEFT
	_parts_list.fixed_icon_size = Vector2i(32, 32)
	_parts_list.item_clicked.connect(_on_part_clicked)
	vbox.add_child(_parts_list)

	# Parts preview grid (3D preview view).
	_parts_preview = ScrollContainer.new()
	_parts_preview.set_script(PartsPreviewGridScript)
	_parts_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_parts_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_parts_preview.visible = false
	_parts_preview.part_selected.connect(_on_preview_part_selected)
	vbox.add_child(_parts_preview)

	# ── Bottom status bar ────────────────────────────────────────────────
	var bottom_bar := PanelContainer.new()
	bottom_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bottom_bar.add_theme_stylebox_override("panel", UITheme.make_bottom_bar_style())
	bottom_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.custom_minimum_size.y = 36
	add_child(bottom_bar)

	_status_label = Label.new()
	_status_label.text = "  Click a part to place it, or use the toolbar to select/move/rotate/delete objects."
	UITheme.style_muted_label(_status_label)
	bottom_bar.add_child(_status_label)

	# ── Action wheel (full-screen overlay, initially hidden) ────────────
	_action_wheel = Control.new()
	_action_wheel.name = "ActionWheel"
	_action_wheel.set_script(ActionWheelScript)
	_action_wheel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_action_wheel)
	_action_wheel.mode_selected.connect(_on_wheel_mode_selected)

	# ── Conveyor properties panel (right side, initially hidden) ────────
	_conveyor_panel = PanelContainer.new()
	_conveyor_panel.name = "ConveyorPropertiesPanel"
	_conveyor_panel.set_script(ConveyorPropertiesPanelScript)
	add_child(_conveyor_panel)

	# ── PLC connection dialog (hidden, shown on demand) ─────────────────
	_plc_dialog = Window.new()
	_plc_dialog.name = "PlcConnectionDialog"
	_plc_dialog.set_script(PlcConnectionDialogScript)
	_plc_dialog.visible = false
	add_child(_plc_dialog)

	# ── Help dialog (hidden, shown on demand) ───────────────────────────
	_help_dialog = Window.new()
	_help_dialog.name = "HelpDialog"
	_help_dialog.set_script(HelpDialogScript)
	_help_dialog.visible = false
	add_child(_help_dialog)


# ── Parts list / preview population ─────────────────────────────────────────

func _filtered_parts() -> Array[Dictionary]:
	var filter := _search_bar.text.strip_edges().to_lower() if _search_bar else ""
	var cat_items: Array = CATEGORIES.get(_current_category, [])
	var result: Array[Dictionary] = []
	for part: Dictionary in _parts:
		var part_name: String = part["name"]
		var base: String = part["base"]

		# Category filter.
		if _current_category != "All" and not cat_items.has(base):
			continue

		# Text filter.
		if filter != "" and part_name.to_lower().find(filter) == -1:
			continue

		result.append(part)
	return result


func _populate_parts_list() -> void:
	var entries := _filtered_parts()
	if _preview_mode:
		# Update grid view.
		if _parts_preview and _parts_preview.has_method("set_parts"):
			_parts_preview.set_parts(entries)
	else:
		_parts_list.clear()
		for part: Dictionary in entries:
			_parts_list.add_item(part["name"])
			_parts_list.set_item_metadata(_parts_list.item_count - 1, part["path"])


# ── Callbacks ────────────────────────────────────────────────────────────────

func _on_mode_button_pressed(mode_name: String) -> void:
	_set_mode(mode_name)


func _on_category_changed(idx: int) -> void:
	_current_category = CATEGORIES.keys()[idx]
	_populate_parts_list()


func _on_part_clicked(index: int, _at_position: Vector2, _button: int) -> void:
	var path: String = _parts_list.get_item_metadata(index)
	if path:
		part_selected.emit(path)
		set_status("Placing: %s (Left-click = place, R = rotate, Right-click = cancel)" % _parts_list.get_item_text(index))


func _on_preview_part_selected(path: String) -> void:
	if path == "":
		return
	# Find the display name for nicer status feedback.
	var display := path.get_file().get_basename()
	for p: Dictionary in _parts:
		if p.get("path", "") == path:
			display = p.get("name", display)
			break
	part_selected.emit(path)
	set_status("Placing: %s (Left-click = place, R = rotate, Right-click = cancel)" % display)


func _on_preview_toggled(pressed: bool) -> void:
	_preview_mode = pressed
	if _parts_list:
		_parts_list.visible = not pressed
	if _parts_preview:
		_parts_preview.visible = pressed
	_populate_parts_list()


# ── Public API ───────────────────────────────────────────────────────────────

func set_mode(mode_name: String) -> void:
	_set_mode(mode_name)


func set_status(text: String) -> void:
	if _status_label:
		_status_label.text = "  " + text


func update_pause_button(paused: bool) -> void:
	if _pause_button:
		_pause_button.text = "▶  Resume" if paused else "⏸  Pause"


## Show the action wheel at the given screen position.
## When [param selected] is a snappable object the Snap sector is included.
func show_action_wheel(screen_pos: Vector2, selected: Node3D = null) -> void:
	if _action_wheel:
		var show_snap := false
		if selected:
			show_snap = ConveyorSnapping.can_snap(selected)
		_action_wheel.show_at(screen_pos, show_snap)


## Hide the action wheel if currently visible.
func hide_action_wheel() -> void:
	if _action_wheel and _action_wheel.visible:
		_action_wheel.close()


## Bind the conveyor properties panel to the given node (shows for belt
## conveyors, hides for everything else).
func bind_properties(node: Node3D) -> void:
	if _conveyor_panel:
		_conveyor_panel.bind(node)


## Unbind and hide the conveyor properties panel.
func unbind_properties() -> void:
	if _conveyor_panel:
		_conveyor_panel.unbind()


func _on_wheel_mode_selected(mode: String) -> void:
	action_mode_selected.emit(mode)
	match mode:
		"move":
			set_status("Bewegen: Klicke auf das Objekt, um es zu verschieben.  ESC = abbrechen.")
		"rotate":
			set_status("Rotieren: Klicke auf das Objekt, um es zu drehen.  ESC = abbrechen.")
		"scale":
			set_status("Skalieren: Klicke auf das Objekt, um es zu vergrößern/verkleinern.  ESC = abbrechen.")
		"snap":
			set_status("Snap: Klicke auf ein Ziel-Förderband, um das Objekt daran zu snappen.  ESC = abbrechen.")


func _on_connection_button_pressed() -> void:
	if _plc_dialog:
		_plc_dialog.popup_centered()


func _on_help_button_pressed() -> void:
	if _help_dialog:
		_help_dialog.popup_centered()


func _set_mode(mode_name: String) -> void:
	_current_mode = mode_name
	for key: String in _mode_buttons:
		(_mode_buttons[key] as Button).button_pressed = (key == mode_name)
	mode_changed.emit(mode_name)

	match mode_name:
		"select":
			set_status("Click an object to select it.  Right-click on selected object to change mode.")
		"delete":
			set_status("Click an object to delete it.")
