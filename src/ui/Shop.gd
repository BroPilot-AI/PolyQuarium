class_name Shop
extends Control
## Modal shop overlay. Lists the fish that suit the active tank type with prices, and
## buys one into the current tank when affordable and there's room. Bought fish are
## handled by GameState.add_fish (which emits fish_added → the Aquarium spawns it).

var _list: VBoxContainer
var _title: Label
var _mode: String = "fish"   # "fish" | "decor"

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	# Center the panel via a full-rect CenterContainer (manual center-anchoring collapsed the panel
	# into the top-left corner — the same layout trap that hid the action bar).
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 520)
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	var header := HBoxContainer.new()
	col.add_child(header)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 24)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var close := Button.new()
	close.text = "✕"
	close.pressed.connect(close_shop)
	header.add_child(close)

	# Fish / Decor tabs.
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	col.add_child(tabs)
	var fish_tab := Button.new()
	fish_tab.text = "🐟 Fish"
	fish_tab.toggle_mode = true
	fish_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fish_tab.pressed.connect(func(): _set_mode("fish"))
	tabs.add_child(fish_tab)
	var decor_tab := Button.new()
	decor_tab.text = "🪸 Decor"
	decor_tab.toggle_mode = true
	decor_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	decor_tab.pressed.connect(func(): _set_mode("decor"))
	tabs.add_child(decor_tab)
	var tanks_tab := Button.new()
	tanks_tab.text = "🐠 Tanks"
	tanks_tab.toggle_mode = true
	tanks_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tanks_tab.pressed.connect(func(): _set_mode("tanks"))
	tabs.add_child(tanks_tab)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 380)
	col.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)

	Events.coins_changed.connect(func(_t): if visible: _populate())
	Events.fish_added.connect(func(_s, _t): if visible: _populate())
	Events.decor_added.connect(func(_d, _t): if visible: _populate())
	Events.quest_completed.connect(func(_i, _t, _r): if visible: _populate())
	Events.tank_unlocked.connect(func(_t): if visible: _populate())

func _set_mode(mode: String) -> void:
	_mode = mode
	_populate()

func open() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = get_viewport().get_visible_rect().size
	position = Vector2.ZERO
	_populate()
	visible = true
	move_to_front()

func close_shop() -> void:
	visible = false
	Events.shop_close_requested.emit()

func _populate() -> void:
	for c in _list.get_children():
		c.queue_free()
	var tank_id := GameState.active_tank
	var tank_type := int(GameState.tank_data(tank_id).get("type", 0))
	var tank_name: String = GameState.tank_data(tank_id).get("name", "Shop")

	if _mode == "tanks":
		_title.text = "🛒 Tanks"
		for tid: String in GameState.TANKS:
			_list.add_child(_tank_row(tid))
	elif _mode == "decor":
		_title.text = "🛒 %s — Decor (%d/%d)" % [tank_name, GameState.decor_count(tank_id), GameState.tank_data(tank_id).get("decor_slots", 0)]
		for decor_id in DecorDatabase.decor_for_tank(tank_type):
			_list.add_child(_decor_row(decor_id, tank_id))
	else:
		_title.text = "🛒 %s — Fish (%d/%d)" % [tank_name, GameState.fish_count(tank_id), GameState.capacity_of(tank_id)]
		for species_id in FishDatabase.species_for_tank(tank_type):
			_list.add_child(_fish_row(species_id, tank_id))

func _fish_row(species_id: String, tank_id: String) -> Control:
	var price := FishDatabase.price(species_id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var name_label := Label.new()
	name_label.text = FishDatabase.species_name(species_id)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 18)
	row.add_child(name_label)

	var price_label := Label.new()
	price_label.text = "%d 🪙" % price
	row.add_child(price_label)

	var buy := Button.new()
	buy.text = "Buy"
	var afford := GameState.can_afford(price)
	var room := GameState.has_room(tank_id)
	buy.disabled = not (afford and room)
	if not room:
		buy.text = "Full"
	buy.pressed.connect(_buy.bind(species_id, tank_id))
	row.add_child(buy)
	return row

func _buy(species_id: String, tank_id: String) -> void:
	var price := FishDatabase.price(species_id)
	if not GameState.has_room(tank_id):
		Toasts.show_toast("This tank is full", Color(1, 0.7, 0.5))
		return
	if not GameState.spend_coins(price):
		Toasts.show_toast("Not enough coins", Color(1, 0.7, 0.5))
		return
	GameState.add_fish(species_id, tank_id)
	Toasts.show_toast("Welcome, %s! 🐟" % FishDatabase.species_name(species_id))
	_populate()

## A tank row in the Tanks tab. Owned tanks show "Owned"; locked tanks must have their prerequisite
## quests done before the Buy button activates — that's how you "level up" to the next tank.
func _tank_row(tank_id: String) -> Control:
	var data := GameState.tank_data(tank_id)
	var price := int(data.get("unlock_price", 0))
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	row.add_child(top)

	var name_label := Label.new()
	name_label.text = String(data.get("name", tank_id))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 18)
	top.add_child(name_label)

	if GameState.is_unlocked(tank_id):
		var owned := Label.new()
		owned.text = "Owned ✓"
		owned.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
		top.add_child(owned)
		return row

	var price_label := Label.new()
	price_label.text = "%d 🪙" % price
	top.add_child(price_label)

	var missing: Array = GameState.missing_prereqs(tank_id)
	var buy := Button.new()
	if missing.is_empty():
		buy.text = "Buy"
		buy.disabled = not GameState.can_afford(price)
		buy.pressed.connect(_buy_tank.bind(tank_id))
	else:
		buy.text = "🔒 Locked"
		buy.disabled = true
		var titles := PackedStringArray()
		for qid in missing:
			titles.append(QuestManager.title_of(String(qid)))
		var hint := Label.new()
		hint.text = "Finish first: %s" % ", ".join(titles)
		hint.add_theme_font_size_override("font_size", 12)
		hint.add_theme_color_override("font_color", Color(1.0, 0.8, 0.55))
		row.add_child(hint)
	top.add_child(buy)
	return row

func _buy_tank(tank_id: String) -> void:
	if not GameState.prereqs_met(tank_id):
		Toasts.show_toast("Finish this tank's quests first", Color(1, 0.7, 0.5))
		return
	if not GameState.can_afford(int(GameState.tank_data(tank_id).get("unlock_price", 0))):
		Toasts.show_toast("Not enough coins", Color(1, 0.7, 0.5))
		return
	if GameState.unlock_tank(tank_id):
		Toasts.show_toast("Unlocked %s! 🎉" % GameState.tank_data(tank_id).get("name", tank_id))
		GameState.set_active_tank(tank_id)
		close_shop()
	_populate()

func _decor_row(decor_id: String, tank_id: String) -> Control:
	var price := DecorDatabase.price(decor_id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var name_label := Label.new()
	name_label.text = DecorDatabase.name_of(decor_id)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 18)
	row.add_child(name_label)

	var price_label := Label.new()
	price_label.text = "%d 🪙" % price
	row.add_child(price_label)

	var buy := Button.new()
	buy.text = "Buy"
	var room := GameState.has_decor_room(tank_id)
	buy.disabled = not (GameState.can_afford(price) and room)
	if not room:
		buy.text = "Full"
	buy.pressed.connect(_buy_decor.bind(decor_id, tank_id))
	row.add_child(buy)
	return row

## GameState.add_decor handles the coin spend internally, so we only pre-check (to show a
## friendly message) and never spend here — avoids double-charging.
func _buy_decor(decor_id: String, tank_id: String) -> void:
	if not GameState.has_decor_room(tank_id):
		Toasts.show_toast("No more decor room", Color(1, 0.7, 0.5))
		return
	if not GameState.can_afford(DecorDatabase.price(decor_id)):
		Toasts.show_toast("Not enough coins", Color(1, 0.7, 0.5))
		return
	if GameState.add_decor(decor_id, tank_id) >= 0:
		Toasts.show_toast("Placed %s 🪸" % DecorDatabase.name_of(decor_id))
	_populate()
