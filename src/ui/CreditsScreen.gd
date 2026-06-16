class_name CreditsScreen
extends Control
## Reusable credits overlay listing every asset attribution (CC-BY requires it; CC0 credited
## as courtesy). Built in code so it can be dropped onto the title screen and the in-game HUD
## alike — call show_credits() / close().

const SECTIONS := [
	{"title": "PolyQuarium", "lines": ["A cozy aquarium care-sim", "Made with Godot 4.7"]},
	{"title": "Fish — Quaternius (CC0)", "lines": [
		"Animated Fish Bundle — 15 species",
	]},
	{"title": "Decor", "lines": [
		"Sea Anemone — Poly by Google (CC-BY)",
		"Seaweed — Laney XR Labs (CC-BY)",
		"Kelp — Poly by Google (CC-BY)",
		"Coral — God Appeasers (CC-BY)",
		"Driftwood — J.B. Samuel (CC-BY)",
		"Castle — sirkitree (CC-BY)",
		"Anchor — Poly by Google (CC-BY)",
		"Rock — Quaternius (CC0)",
		"Treasure Chest — Quaternius (CC0)",
	]},
	{"title": "Furniture", "lines": [
		"Book Stack — Danni Bittman (CC-BY)",
		"Coffee Cup — Zsky (CC-BY)",
		"Flower Pot — Zsky (CC-BY)",
		"Bench — CMHT Oculus (CC-BY)",
		"Couch — Quaternius (CC0)",
		"Bookcase — Quaternius (CC0)",
		"Armchair — CreativeTrio (CC0)",
	]},
	{"title": "", "lines": [
		"All 3D models via Poly Pizza (poly.pizza)",
		"Licensed CC0 / CC-BY 3.0 — thank you, creators! 💙",
	]},
]

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.06, 0.10, 0.92)
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
	title.text = "Credits"
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
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)

	for section: Dictionary in SECTIONS:
		if String(section["title"]) != "":
			var s := Label.new()
			s.text = String(section["title"])
			s.add_theme_font_size_override("font_size", 19)
			s.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
			var pad := Control.new()
			pad.custom_minimum_size = Vector2(0, 8)
			list.add_child(pad)
			list.add_child(s)
		for line: String in section["lines"]:
			var l := Label.new()
			l.text = line
			l.add_theme_font_size_override("font_size", 15)
			l.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
			list.add_child(l)

func show_credits() -> void:
	# Belt-and-suspenders: fill the viewport in case the parent hadn't laid out yet.
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = get_viewport().get_visible_rect().size
	position = Vector2.ZERO
	visible = true
	move_to_front()

func close() -> void:
	visible = false
