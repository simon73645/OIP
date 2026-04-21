extends Window
## Hilfe-Fenster: zeigt Tastenkombinationen und Features auf einen Blick.
##
## Das Fenster wird über den "Hilfe"-Button in der Top-Bar geöffnet und
## fasst die wichtigsten Steuerungen, Modi und Features zusammen, damit
## ein Anfänger ohne Vorwissen sofort loslegen kann.

const UITheme := preload("res://game/ui/ui_theme.gd")

const TITLE_TEXT := "Hilfe – Tastenkombinationen & Features"

const HELP_BBCODE := \
"""[color=#9ec3ff][b]Willkommen in der Simulation![/b][/color]
Hier findest du alle wichtigen Steuerungen und Features auf einen Blick.

[color=#ffd07a][b]🖱  Maus-Steuerung[/b][/color]
[color=#dddddd]• [b]Linksklick[/b] auf ein Part links in der Auswahl → platziert das Objekt.
• [b]Linksklick[/b] auf ein Objekt in der Szene → wählt es aus.
• [b]Rechtsklick[/b] auf ein ausgewähltes Objekt → öffnet das Aktions-Rad
  (Bewegen / Drehen / Skalieren / Snap).
• [b]Rechtsklick[/b] beim Platzieren → bricht das Platzieren ab.
• [b]Mittlere Maustaste / Maus halten[/b] → Kamera bewegen / drehen.
• [b]Mausrad[/b] → zoomen.[/color]

[color=#ffd07a][b]⌨  Tastenkürzel[/b][/color]
[color=#dddddd]• [b]Leertaste[/b] – Simulation starten / pausieren.
• [b]R[/b] – beim Platzieren das Objekt um 90° drehen.
• [b]Entf / Delete[/b] – ausgewähltes Objekt löschen.
• [b]Esc[/b] – Auswahl aufheben oder aktuelle Aktion abbrechen.
• [b]Tab[/b] – Parts-Panel ein-/ausblenden (sofern unterstützt).[/color]

[color=#ffd07a][b]🛠  Modi (Top-Bar)[/b][/color]
[color=#dddddd]• [b]Select[/b] – Objekte anwählen, um Eigenschaften zu sehen.
• [b]Delete[/b] – ein Klick auf ein Objekt löscht es sofort.
• [b]Speichern / Laden[/b] – Simulation als JSON-Datei speichern oder laden.
• [b]Pause[/b] – Simulation anhalten oder fortsetzen.
• [b]Connection[/b] – Dialog für die SPS-Verbindung (IP, CPU-Typ, …).[/color]

[color=#ffd07a][b]🎯  Aktions-Rad (Rechtsklick auf Objekt)[/b][/color]
[color=#dddddd]• [b]Move[/b] – Objekt mit der Maus verschieben.
• [b]Rotate[/b] – Objekt frei drehen.
• [b]Scale[/b] – Objekt vergrößern / verkleinern (Förderbänder verlängern).
• [b]Snap[/b] – nur bei Förderbändern: an einem anderen Förderband andocken.[/color]

[color=#ffd07a][b]🧩  Property-Panels (rechte Seite)[/b][/color]
[color=#dddddd]• Wird automatisch eingeblendet, sobald ein passendes Objekt
  ausgewählt ist (Conveyor, Sensor, Diverter, Box …).
• Mit dem [b]×[/b] in der Kopfzeile kann jedes Panel geschlossen werden.
• Solange ein Objekt ausgewählt bleibt, erscheint stattdessen ein
  blaues [b]⚙ Attribute-Icon[/b] am rechten Rand – ein Klick öffnet das
  Panel wieder.[/color]

[color=#ffd07a][b]📦  Equipment-Auswahl (linke Seite)[/b][/color]
[color=#dddddd]• Über das Suchfeld lassen sich Parts schnell finden.
• Tabs filtern nach Kategorie (Conveyors, Sensors, Equipment, …).
• Mit der Checkbox [b]3D Preview[/b] schaltest du zwischen Listen-
  Ansicht und visueller 3D-Vorschau um.[/color]

[color=#ffd07a][b]🔌  SPS-Anbindung[/b][/color]
[color=#dddddd]• Über [b]Connection[/b] mit einer Siemens S7-SPS verbinden.
• Sensoren und Diverter werden automatisch registriert.
• Im jeweiligen Property-Panel lässt sich die SPS-Adresse anpassen.[/color]

[color=#aaaaaa][i]Tipp: Drücke jederzeit [b]Esc[/b] um diesen Dialog zu schließen.[/i][/color]
"""


func _ready() -> void:
	title = TITLE_TEXT
	size = Vector2i(560, 600)
	min_size = Vector2i(420, 360)
	exclusive = false
	transient = true
	unresizable = false
	close_requested.connect(hide)

	_build_ui()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# Header.
	var header := Label.new()
	header.text = "Tastenkombinationen & Features"
	UITheme.style_title_label(header, 18)
	vbox.add_child(header)

	vbox.add_child(HSeparator.new())

	# Scrollable help text.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.scroll_active = false
	rich.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rich.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rich.text = HELP_BBCODE
	rich.add_theme_color_override("default_color", UITheme.TEXT_PRIMARY)
	scroll.add_child(rich)

	# Footer with close button.
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(footer)

	var close_btn := Button.new()
	close_btn.text = "Schließen"
	close_btn.custom_minimum_size = Vector2(120, 34)
	UITheme.style_button(close_btn)
	close_btn.pressed.connect(hide)
	footer.add_child(close_btn)


func _input(event: InputEvent) -> void:
	# Allow Esc to close the help window when it has focus.
	if visible and event is InputEventKey and (event as InputEventKey).pressed:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			hide()
			get_viewport().set_input_as_handled()
