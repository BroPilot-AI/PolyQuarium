class_name Fishpedia
extends Control
## Fish collection log: every species grouped by tank, with owned ones named (+ price) and
## undiscovered ones shown as "🔒 ???". Read-only overlay (same pattern as QuestsPanel).

var _list: VBoxContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.06, 0.10, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 600)
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)

	var header := HBoxContainer.new()
	col.add_child(header)
	var title := Label.new()
	title.text = "🐟 Fishpedia"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.pressed.connect(close)
	header.add_child(close_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 520)
	col.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)

	Events.fish_added.connect(func(_s, _t): if visible: _populate())

func show_panel() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = get_viewport().get_visible_rect().size
	position = Vector2.ZERO
	_populate()
	visible = true
	move_to_front()

func close() -> void:
	visible = false

const GROUPS := [
	{"name": "Goldfish Bowl", "type": 0},
	{"name": "Freshwater", "type": 1},
	{"name": "Saltwater Reef", "type": 2},
]

func _populate() -> void:
	for c in _list.get_children():
		c.queue_free()
	for g: Dictionary in GROUPS:
		var species: Array[String] = FishDatabase.species_for_tank(int(g["type"]))
		var seen := 0
		for sp in species:
			if GameState.species_seen.has(sp):
				seen += 1
		_list.add_child(_header("%s   %d/%d" % [g["name"], seen, species.size()]))
		for sp in species:
			_list.add_child(_species_row(sp))

func _header(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 19)
	l.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	return l

func _species_row(species_id: String) -> Control:
	var seen := GameState.species_seen.has(species_id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var name_lbl := Label.new()
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 16)
	if seen:
		name_lbl.text = FishDatabase.species_name(species_id)
		name_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	else:
		name_lbl.text = "🔒  ???"
		name_lbl.add_theme_color_override("font_color", Color(0.55, 0.6, 0.65))
	row.add_child(name_lbl)

	if seen:
		var price_lbl := Label.new()
		price_lbl.text = "%d 🪙" % FishDatabase.price(species_id)
		price_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		row.add_child(price_lbl)
	return row
