class_name UITheme
extends RefCounted
## Centralized styling helpers for the in-game HUD and property panels.
##
## Exposes a small palette of dark-mode colors plus factory methods that build
## consistently styled [StyleBoxFlat]s, header bars and icon buttons so every
## panel in the simulation shares the same modern look-and-feel.

# ── Color palette ────────────────────────────────────────────────────────────

const BG_PANEL: Color           = Color(0.10, 0.11, 0.14, 0.96)
const BG_HEADER: Color          = Color(0.16, 0.18, 0.24, 1.0)
const BG_TOOLBAR: Color         = Color(0.11, 0.12, 0.16, 0.96)
const BG_BUTTON: Color          = Color(0.20, 0.22, 0.28, 1.0)
const BG_BUTTON_HOVER: Color    = Color(0.27, 0.30, 0.38, 1.0)
const BG_BUTTON_PRESSED: Color  = Color(0.32, 0.55, 0.95, 1.0)
const BG_BUTTON_DISABLED: Color = Color(0.16, 0.17, 0.20, 1.0)

const ACCENT_PRIMARY: Color   = Color(0.32, 0.55, 0.95, 1.0)   # Soft blue.
const ACCENT_SUCCESS: Color   = Color(0.36, 0.78, 0.45, 1.0)   # Green.
const ACCENT_WARNING: Color   = Color(1.00, 0.78, 0.30, 1.0)   # Amber.
const ACCENT_DANGER: Color    = Color(0.95, 0.32, 0.32, 1.0)   # Red.

const TEXT_PRIMARY: Color   = Color(0.94, 0.95, 0.98, 1.0)
const TEXT_SECONDARY: Color = Color(0.72, 0.74, 0.80, 1.0)
const TEXT_MUTED: Color     = Color(0.55, 0.57, 0.63, 1.0)

const BORDER_SUBTLE: Color = Color(1.0, 1.0, 1.0, 0.06)

const RADIUS: int        = 10
const HEADER_HEIGHT: int = 36
const PADDING: int       = 10


# ── StyleBox factories ───────────────────────────────────────────────────────

## Build the default panel style (rounded corners, subtle border, padding).
static func make_panel_style(corner_radius: int = RADIUS) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG_PANEL
	sb.corner_radius_top_left = corner_radius
	sb.corner_radius_top_right = corner_radius
	sb.corner_radius_bottom_left = corner_radius
	sb.corner_radius_bottom_right = corner_radius
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = BORDER_SUBTLE
	sb.content_margin_left = PADDING
	sb.content_margin_right = PADDING
	sb.content_margin_top = PADDING
	sb.content_margin_bottom = PADDING
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 2)
	return sb


## Panel style anchored to the right edge (no rounded right corners).
static func make_right_panel_style() -> StyleBoxFlat:
	var sb := make_panel_style()
	sb.corner_radius_top_right = 0
	sb.corner_radius_bottom_right = 0
	return sb


## Panel style anchored to the left edge (no rounded left corners).
static func make_left_panel_style() -> StyleBoxFlat:
	var sb := make_panel_style()
	sb.corner_radius_top_left = 0
	sb.corner_radius_bottom_left = 0
	return sb


## Top toolbar style (no rounded top corners, full width).
static func make_top_bar_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG_TOOLBAR
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	sb.border_width_bottom = 1
	sb.border_color = BORDER_SUBTLE
	sb.content_margin_left = PADDING
	sb.content_margin_right = PADDING
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


## Bottom status bar style.
static func make_bottom_bar_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG_TOOLBAR
	sb.border_width_top = 1
	sb.border_color = BORDER_SUBTLE
	sb.content_margin_left = PADDING
	sb.content_margin_right = PADDING
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


## Build a styled flat button look (4 stateboxes).
static func style_button(btn: Button, accent: Color = ACCENT_PRIMARY) -> void:
	btn.add_theme_color_override("font_color", TEXT_PRIMARY)
	btn.add_theme_color_override("font_hover_color", TEXT_PRIMARY)
	btn.add_theme_color_override("font_pressed_color", TEXT_PRIMARY)
	btn.add_theme_color_override("font_disabled_color", TEXT_MUTED)

	var normal := _btn_style(BG_BUTTON)
	var hover := _btn_style(BG_BUTTON_HOVER)
	var pressed := _btn_style(accent)
	var disabled := _btn_style(BG_BUTTON_DISABLED)
	# Accent border on hover for a subtle highlight.
	hover.border_width_left = 1
	hover.border_width_right = 1
	hover.border_width_top = 1
	hover.border_width_bottom = 1
	hover.border_color = accent
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_stylebox_override("disabled", disabled)


static func _btn_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


## Toggle-button look that highlights when pressed.
static func style_toggle_button(btn: Button) -> void:
	style_button(btn, ACCENT_PRIMARY)


## Compact icon-only button (square, single character/emoji glyph).
static func style_icon_button(btn: Button, size_px: int = 28) -> void:
	btn.custom_minimum_size = Vector2(size_px, size_px)
	btn.flat = false
	btn.add_theme_color_override("font_color", TEXT_PRIMARY)
	btn.add_theme_color_override("font_hover_color", TEXT_PRIMARY)
	btn.add_theme_color_override("font_pressed_color", TEXT_PRIMARY)
	btn.add_theme_font_size_override("font_size", 14)
	var normal := _icon_btn_style(Color(1, 1, 1, 0.06))
	var hover := _icon_btn_style(Color(1, 1, 1, 0.16))
	var pressed := _icon_btn_style(ACCENT_PRIMARY)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)


static func _icon_btn_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	return sb


## Style a [LineEdit] (search field, IP input, etc.).
static func style_line_edit(le: LineEdit) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.06, 0.07, 0.10, 1.0)
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
	normal.border_width_left = 1
	normal.border_width_right = 1
	normal.border_width_top = 1
	normal.border_width_bottom = 1
	normal.border_color = BORDER_SUBTLE
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	normal.content_margin_top = 5
	normal.content_margin_bottom = 5
	le.add_theme_stylebox_override("normal", normal)

	var focus := normal.duplicate() as StyleBoxFlat
	focus.border_color = ACCENT_PRIMARY
	le.add_theme_stylebox_override("focus", focus)
	le.add_theme_color_override("font_color", TEXT_PRIMARY)
	le.add_theme_color_override("font_placeholder_color", TEXT_MUTED)


## Style a section title label (large, primary text).
static func style_title_label(lbl: Label, size_px: int = 16) -> void:
	lbl.add_theme_font_size_override("font_size", size_px)
	lbl.add_theme_color_override("font_color", TEXT_PRIMARY)


## Style a secondary/muted label.
static func style_muted_label(lbl: Label) -> void:
	lbl.add_theme_color_override("font_color", TEXT_SECONDARY)


# ── Header builder ───────────────────────────────────────────────────────────

## Build a header bar containing a title label and an "×" close button.
##
## Returns a dictionary with the constructed nodes:
##   {"container": HBoxContainer, "title": Label, "close": Button}
##
## Caller is responsible for adding the container to a parent and connecting
## the close button's `pressed` signal.
static func make_panel_header(title_text: String) -> Dictionary:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title := Label.new()
	title.text = title_text
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	style_title_label(title, 16)
	hbox.add_child(title)

	var close := Button.new()
	close.text = "×"
	close.tooltip_text = "Schließen"
	close.add_theme_font_size_override("font_size", 18)
	style_icon_button(close, 26)
	hbox.add_child(close)

	return {"container": hbox, "title": title, "close": close}


## Build the small floating "Attribute" icon used to restore a hidden panel.
static func make_attribute_icon_button(tooltip: String = "Eigenschaften öffnen") -> Button:
	var btn := Button.new()
	btn.text = "⚙"
	btn.tooltip_text = tooltip
	btn.custom_minimum_size = Vector2(40, 40)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", TEXT_PRIMARY)
	var normal := StyleBoxFlat.new()
	normal.bg_color = ACCENT_PRIMARY
	normal.corner_radius_top_left = 20
	normal.corner_radius_top_right = 20
	normal.corner_radius_bottom_left = 20
	normal.corner_radius_bottom_right = 20
	normal.shadow_color = Color(0, 0, 0, 0.35)
	normal.shadow_size = 6
	normal.shadow_offset = Vector2(0, 2)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = ACCENT_PRIMARY.lightened(0.15)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = ACCENT_PRIMARY.darkened(0.15)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)
	return btn
