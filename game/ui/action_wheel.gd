extends Control
## Radial action wheel for choosing between Move, Rotate, Scale — and
## optionally Snap — modes.
##
## Appears as a full-screen overlay with an annular (ring-shaped) menu.
## Clicking a sector emits [signal mode_selected] and hides the wheel.
## Clicking outside or pressing Escape closes it.
##
## The Snap sector is only shown when [method show_at] is called with
## [code]show_snap = true[/code].

signal mode_selected(mode: String)
signal closed

const RADIUS := 70.0
const INNER_RADIUS := 25.0

## Base sectors that are always visible.
const _BASE_SECTORS: Array[Array] = [
	["move", "Move", "✥", [0.25, 0.50, 0.90]],
	["rotate", "Rotate", "⟳", [0.25, 0.75, 0.40]],
	["scale", "Scale", "⤢", [0.90, 0.55, 0.20]],
]

## Additional snap sector, appended when the selected object is snappable.
const _SNAP_SECTOR: Array = ["snap", "Snap", "🔗", [0.75, 0.35, 0.85]]

## Currently active sectors (rebuilt on every [method show_at] call).
var _sectors: Array[Array] = []

var _center: Vector2 = Vector2.ZERO
var _hovered: int = -1


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	visible = false


## Show the wheel at [param pos].  When [param show_snap] is true the Snap
## sector is included in the ring.
func show_at(pos: Vector2, show_snap: bool = false) -> void:
	_sectors = _BASE_SECTORS.duplicate(true)
	if show_snap:
		_sectors.append(_SNAP_SECTOR.duplicate())

	# Clamp so the wheel stays fully on-screen.
	_center.x = clampf(pos.x, RADIUS + 10.0, size.x - RADIUS - 10.0)
	_center.y = clampf(pos.y, RADIUS + 10.0, size.y - RADIUS - 10.0)
	_hovered = -1
	visible = true
	queue_redraw()


func close() -> void:
	visible = false
	_hovered = -1
	closed.emit()


# ── Drawing ──────────────────────────────────────────────────────────────────

func _draw() -> void:
	if not visible:
		return

	# Semi-transparent backdrop.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.1))

	var count := _sectors.size()
	var sector_angle := TAU / float(count)
	var start_offset := -PI / 2.0  # first sector points upward

	for i in range(count):
		var a0 := start_offset + i * sector_angle
		var col_arr: Array = _sectors[i][3]
		var base_color := Color(col_arr[0], col_arr[1], col_arr[2])
		var brightness := 1.25 if i == _hovered else 1.0
		var alpha := 0.80 if i == _hovered else 0.70
		var color := Color(
			minf(base_color.r * brightness, 1.0),
			minf(base_color.g * brightness, 1.0),
			minf(base_color.b * brightness, 1.0),
			alpha,
		)

		# Annular sector polygon (inner arc → outer arc reversed).
		var pts := PackedVector2Array()
		var steps := 32
		for s in range(steps + 1):
			var a := a0 + sector_angle * float(s) / float(steps)
			pts.append(_center + Vector2(cos(a), sin(a)) * INNER_RADIUS)
		for s in range(steps, -1, -1):
			var a := a0 + sector_angle * float(s) / float(steps)
			pts.append(_center + Vector2(cos(a), sin(a)) * RADIUS)
		draw_colored_polygon(pts, color)

		# Divider line at sector start.
		draw_line(
			_center + Vector2(cos(a0), sin(a0)) * INNER_RADIUS,
			_center + Vector2(cos(a0), sin(a0)) * RADIUS,
			Color(1.0, 1.0, 1.0, 0.35), 1.5,
		)

		# Icon + label in the middle of the sector.
		var mid_a := a0 + sector_angle / 2.0
		var text_r := (RADIUS + INNER_RADIUS) / 2.0
		var text_pos := _center + Vector2(cos(mid_a), sin(mid_a)) * text_r

		var font: Font = ThemeDB.fallback_font

		# Icon character.
		var icon_text: String = _sectors[i][2]
		var icon_fs := 26
		var icon_sz := font.get_string_size(icon_text, HORIZONTAL_ALIGNMENT_CENTER, -1, icon_fs)
		draw_string(
			font,
			text_pos + Vector2(-icon_sz.x / 2.0, icon_fs * 0.35 - 6.0),
			icon_text, HORIZONTAL_ALIGNMENT_CENTER, -1, icon_fs, Color.WHITE,
		)

		# Label.
		var lbl_text: String = _sectors[i][1]
		var lbl_fs := 12
		var lbl_sz := font.get_string_size(lbl_text, HORIZONTAL_ALIGNMENT_CENTER, -1, lbl_fs)
		draw_string(
			font,
			text_pos + Vector2(-lbl_sz.x / 2.0, lbl_fs * 0.35 + 12.0),
			lbl_text, HORIZONTAL_ALIGNMENT_CENTER, -1, lbl_fs, Color.WHITE,
		)

	# Centre disc.
	draw_circle(_center, INNER_RADIUS, Color(0.12, 0.12, 0.16, 0.95))
	draw_arc(_center, INNER_RADIUS, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.25), 1.5)
	# Outer ring.
	draw_arc(_center, RADIUS, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, 0.25), 1.5)


# ── Input ────────────────────────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventMouseMotion:
		_hovered = _get_sector(event.position)
		queue_redraw()
		accept_event()

	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_LEFT:
				var sector := _get_sector(mb.position)
				if sector >= 0:
					mode_selected.emit(_sectors[sector][0])
					close()
				else:
					# Click outside the wheel — just close.
					close()
				accept_event()
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				close()
				accept_event()

	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			close()
			accept_event()


## Returns sector index or -1 if position is outside the ring.
func _get_sector(pos: Vector2) -> int:
	if _sectors.is_empty():
		return -1
	var dist := _center.distance_to(pos)
	if dist < INNER_RADIUS or dist > RADIUS:
		return -1
	var dir := pos - _center
	# atan2 gives angle in standard math coords.  Shift so that -PI/2 (top)
	# maps to 0 and angles increase clockwise.
	var angle := atan2(dir.y, dir.x) - (-PI / 2.0)
	if angle < 0.0:
		angle += TAU
	var sector := int(angle / (TAU / float(_sectors.size())))
	return clampi(sector, 0, _sectors.size() - 1)
