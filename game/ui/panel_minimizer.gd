class_name PanelMinimizer
extends RefCounted
## Helper that adds "close (×) and re-open via floating attribute icon"
## behaviour to any [PanelContainer] property panel.
##
## Usage from a property panel script:
## [codeblock]
##     var _minimizer: PanelMinimizer
##     func _ready() -> void:
##         ...
##         _minimizer = PanelMinimizer.new(self, "Eigenschaften öffnen")
##         _minimizer.position_right_side(50)  # optional anchor offset from top
##         # Add header with close-button into your VBox:
##         var hdr := UITheme.make_panel_header("My Panel")
##         vbox.add_child(hdr["container"])
##         hdr["close"].pressed.connect(_minimizer.minimize)
## [/codeblock]
##
## When the user presses "×" the panel is hidden and a small circular
## "⚙" button appears at the same edge so the user can re-open the panel.

const UITheme := preload("res://game/ui/ui_theme.gd")

var panel: PanelContainer
var attribute_icon: Button
var is_minimized: bool = false

# Position of the attribute icon (offset from the right edge of the screen).
var _icon_top_offset: float = 60.0
var _icon_right_offset: float = 12.0


func _init(p_panel: PanelContainer, tooltip: String = "Eigenschaften öffnen") -> void:
	panel = p_panel
	attribute_icon = UITheme.make_attribute_icon_button(tooltip)
	attribute_icon.visible = false
	attribute_icon.pressed.connect(restore)
	# The icon must live in the same canvas as the panel; defer parenting until
	# the panel is in the tree.
	panel.tree_entered.connect(_attach_icon, CONNECT_ONE_SHOT)
	if panel.is_inside_tree():
		_attach_icon()


func _attach_icon() -> void:
	var parent := panel.get_parent()
	if parent and not attribute_icon.is_inside_tree():
		parent.add_child(attribute_icon)
		_apply_icon_anchors()


## Place the attribute icon at the right edge of the screen at the given
## vertical offset from the top.
func position_right_side(top_offset: float = 60.0) -> void:
	_icon_top_offset = top_offset
	_apply_icon_anchors()


func _apply_icon_anchors() -> void:
	if not attribute_icon or not attribute_icon.is_inside_tree():
		return
	attribute_icon.anchor_left = 1.0
	attribute_icon.anchor_right = 1.0
	attribute_icon.anchor_top = 0.0
	attribute_icon.anchor_bottom = 0.0
	attribute_icon.offset_right = -_icon_right_offset
	attribute_icon.offset_left = -_icon_right_offset - 40.0
	attribute_icon.offset_top = _icon_top_offset
	attribute_icon.offset_bottom = _icon_top_offset + 40.0


## Hide the panel and reveal the floating attribute icon.
func minimize() -> void:
	is_minimized = true
	panel.visible = false
	if attribute_icon:
		attribute_icon.visible = true


## Restore the panel and hide the attribute icon.
func restore() -> void:
	is_minimized = false
	panel.visible = true
	if attribute_icon:
		attribute_icon.visible = false


## Hide both the panel and the attribute icon (used when selection clears or
## the bound target becomes invalid).
func hide_all() -> void:
	is_minimized = false
	panel.visible = false
	if attribute_icon:
		attribute_icon.visible = false


## Call from `bind()` of the host panel.  If the user previously minimized
## the panel for a different target the state is reset so a fresh selection
## starts expanded.
func reset_for_new_target() -> void:
	is_minimized = false
	if attribute_icon:
		attribute_icon.visible = false
