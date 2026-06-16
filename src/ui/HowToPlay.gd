class_name HowToPlay
extends Control
## A persistent "How to Play" guide the player can re-open any time from the ❔ button, and
## that shows itself automatically on the very first launch. Replaces the old transient toasts
## (which scrolled away before they could be read). Pure code so there's no .tscn to drift.

const ENTRIES := [
	["🍤", "Feed", "Click the water to drop food where you want it, or tap the Feed button. Happy, fed fish earn you coins."],
	["🧽", "Clean", "Water slowly gets murky (faster with more fish, or from uneaten food). Tap Clean to refresh it. Dirty water makes fish unhappy."],
	["🛒", "Shop", "Buy new fish and decorations here. The Tanks tab is where you buy bigger tanks once you've unlocked them."],
	["💰", "Sell", "Click any fish to open its card — see its mood and hunger, and Sell it for coins when you like."],
	["🐟", "Fishpedia", "Browse every species you've kept. Healthy pairs of the same fish breed — colours mix, and rare variants are worth more."],
	["📋", "Quests", "Cozy goals that reward coins. Finishing a tank's quests is what unlocks the next tank to buy in the Shop."],
	["🪙", "Coins", "Earned passively by content fish. Keep them fed and in clean water and your coins tick up on their own."],
	["🐠", "Tanks", "Switch between tanks you own at the bottom-left. To get the next one: finish your current quests, then buy it in the Shop's Tanks tab."],
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
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)

	var header := HBoxContainer.new()
	col.add_child(header)
	var title := Label.new()
	title.text = "🐟 How to Play"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.pressed.connect(close)
	header.add_child(close_btn)

	var intro := Label.new()
	intro.text = "Keep your fish happy and your water clean. That's the whole job — relax and watch them grow."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", 15)
	intro.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	col.add_child(intro)

	col.add_child(HSeparator.new())

	for e in ENTRIES:
		col.add_child(_entry_row(e[0], e[1], e[2]))

	col.add_child(HSeparator.new())

	var got_it := Button.new()
	got_it.text = "Got it!"
	got_it.custom_minimum_size = Vector2(0, 44)
	got_it.add_theme_font_size_override("font_size", 18)
	got_it.pressed.connect(close)
	col.add_child(got_it)

## One "icon — title: description" line, laid out so the icon column stays aligned.
func _entry_row(icon: String, label: String, desc: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var icon_lbl := Label.new()
	icon_lbl.text = icon
	icon_lbl.add_theme_font_size_override("font_size", 26)
	icon_lbl.custom_minimum_size = Vector2(40, 0)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(icon_lbl)

	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.custom_minimum_size = Vector2(440, 0)
	text.text = "[b]%s[/b]  —  %s" % [label, desc]
	row.add_child(text)
	return row

func show_panel() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = get_viewport().get_visible_rect().size
	position = Vector2.ZERO
	visible = true
	move_to_front()

func close() -> void:
	visible = false
