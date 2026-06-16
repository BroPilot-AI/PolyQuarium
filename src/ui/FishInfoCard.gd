class_name FishInfoCard
extends PanelContainer
## A cozy card that pops up when you click a fish, showing its species name,
## mood, hunger, and a Sell button. Wired by AquariumHUD via Events.fish_clicked.

var _name_label: Label
var _mood_bar: ProgressBar
var _hunger_bar: ProgressBar
var _sell_btn: Button
var _fish_id: int = -1
var _tank_id: String = ""
var _species_id: String = ""
var _variant_mult: float = 1.0

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()

func _build_ui() -> void:
	custom_minimum_size = Vector2(240, 0)
	# Cozy rounded panel.
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.18, 0.24, 0.92)
	style.border_color = Color(0.35, 0.55, 0.7, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(14)
	add_theme_stylebox_override("panel", style)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	add_child(col)

	# Header: species name + a close (✕) button so the card can always be dismissed.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	col.add_child(header)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 20)
	_name_label.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_name_label)
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.pressed.connect(close)
	header.add_child(close_btn)

	# Mood row.
	var mood_row := HBoxContainer.new()
	mood_row.add_theme_constant_override("separation", 8)
	col.add_child(mood_row)
	mood_row.add_child(_small_label("Mood"))
	_mood_bar = _make_bar()
	mood_row.add_child(_mood_bar)

	# Hunger row.
	var hunger_row := HBoxContainer.new()
	hunger_row.add_theme_constant_override("separation", 8)
	col.add_child(hunger_row)
	hunger_row.add_child(_small_label("Hunger"))
	_hunger_bar = _make_bar()
	hunger_row.add_child(_hunger_bar)

	# Sell button.
	_sell_btn = Button.new()
	_sell_btn.text = "Sell"
	_sell_btn.custom_minimum_size = Vector2(80, 36)
	_sell_btn.add_theme_font_size_override("font_size", 16)
	_sell_btn.pressed.connect(_on_sell)
	col.add_child(_sell_btn)

func show_for(fish_id: int, tank_id: String) -> void:
	_fish_id = fish_id
	_tank_id = tank_id
	# Find the Fish node to read its live stats.
	var fish_node := _find_fish(fish_id)
	if fish_node == null:
		visible = false
		return
	_species_id = fish_node.species_id
	_variant_mult = fish_node.variant_mult()
	# Show the colour variant for non-common fish (e.g. "Blue Goldfish ✨").
	var base_name := FishDatabase.species_name(_species_id)
	if _variant_mult > 1.0:
		var v := fish_node.variant_name()
		var spark := " ✨" if _variant_mult >= 2.2 else ""
		_name_label.text = "%s %s%s" % [v, base_name, spark]
	else:
		_name_label.text = base_name
	_mood_bar.value = fish_node.happiness() * 100.0
	_hunger_bar.value = fish_node.hunger() * 100.0
	_sell_btn.text = "Sell (%d 🪙)" % _sell_value()
	visible = true

func _sell_value() -> int:
	return maxi(1, int(FishDatabase.price(_species_id) * 0.5 * _variant_mult))

func _on_sell() -> void:
	if _fish_id < 0:
		return
	var refund: int = _sell_value()
	GameState.add_coins(refund)
	GameState.remove_fish(_tank_id, _fish_id)
	Events.fish_sold.emit(_species_id, _tank_id)   # feeds the quest tracker
	var species_name := FishDatabase.species_name(_species_id)
	Toasts.show_toast("Sold %s! +%d 🪙" % [species_name, refund])
	close()

## Named close() rather than hide() so it doesn't shadow CanvasItem.hide().
func close() -> void:
	visible = false
	_fish_id = -1
	_tank_id = ""

func _find_fish(target_id: int) -> Fish:
	# Fish live nested under the Aquarium's tank root, not as direct children of the
	# scene, so search the whole tree recursively.
	return _find_fish_recursive(get_tree().root, target_id)

func _find_fish_recursive(node: Node, target_id: int) -> Fish:
	if node is Fish and (node as Fish).fish_id == target_id:
		return node as Fish
	for c in node.get_children():
		var found := _find_fish_recursive(c, target_id)
		if found:
			return found
	return null

# --- Widget factories ---

func _small_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(0.7, 0.82, 0.9))
	return l

func _make_bar() -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = 50
	bar.custom_minimum_size = Vector2(120, 14)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.2, 0.28, 0.35)
	bg.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.35, 0.75, 0.5)
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	return bar
