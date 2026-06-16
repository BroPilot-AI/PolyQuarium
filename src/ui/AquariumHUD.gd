class_name AquariumHUD
extends CanvasLayer
## The cozy on-screen interface: coin counter, the active tank's name + water meter,
## and the action bar (Feed / Clean / Shop / switch tanks). Built in code so it has no
## fragile .tscn to keep in sync; it talks to the world only through Events + GameState.

var _coin_label: Label
var _tank_label: Label
var _summary_label: Label
var _water_bar: ProgressBar
var _tank_bar: HBoxContainer
var _shop: Shop
var _fish_card: FishInfoCard
var _credits: CreditsScreen
var _quests: QuestsPanel
var _options: OptionsPanel
var _fishpedia: Fishpedia
var _howto: HowToPlay

func _ready() -> void:
	layer = 10
	_build_top_bar()
	_build_tank_switcher()
	_build_action_bar()
	_shop = Shop.new()
	add_child(_shop)

	_fish_card = FishInfoCard.new()
	add_child(_fish_card)

	_credits = CreditsScreen.new()
	add_child(_credits)

	_quests = QuestsPanel.new()
	add_child(_quests)

	_options = OptionsPanel.new()
	add_child(_options)

	_fishpedia = Fishpedia.new()
	add_child(_fishpedia)

	_howto = HowToPlay.new()
	add_child(_howto)

	Events.coins_changed.connect(_on_coins_changed)
	Events.help_requested.connect(func(): _howto.show_panel())
	Events.tank_changed.connect(func(_t): _refresh())
	Events.tank_unlocked.connect(func(_t): _rebuild_tank_switcher())
	Events.water_quality_changed.connect(_on_water_changed)
	Events.fish_added.connect(func(_s, _t): _refresh())
	Events.fish_clicked.connect(_on_fish_clicked)
	# Dropping food (clicking the water or the Feed button) dismisses any open fish card.
	Events.food_dropped.connect(func(_pos): _fish_card.close())
	# Celebrate quest completions with a banner + fireworks (the fanfare sound is in AudioManager).
	Events.quest_completed.connect(_on_quest_completed)
	Events.shop_open_requested.connect(func(): _shop.open())

	# Live tank summary (avg mood + how many need care) refreshed twice a second.
	var summary_timer := Timer.new()
	summary_timer.wait_time = 0.5
	summary_timer.timeout.connect(_refresh_summary)
	add_child(summary_timer)
	summary_timer.start()

	_refresh()
	_refresh_summary()

## Average happiness + count of fish needing care for the active tank, read straight from the
## saved fish records (kept current by Fish._sync_record).
func _refresh_summary() -> void:
	var recs: Array = GameState.fish.get(GameState.active_tank, [])
	if recs.is_empty():
		_summary_label.text = ""
		return
	var sum_h := 0.0
	var needs := 0
	for r in recs:
		sum_h += float(r.get("happiness", 0.8))
		if float(r.get("health", 1.0)) < 0.45:
			needs += 1
	var avg := sum_h / recs.size()
	var face := "😊" if avg > 0.66 else ("😐" if avg > 0.4 else "😟")
	var txt := "%s %d%%" % [face, int(round(avg * 100.0))]
	if needs > 0:
		txt += "   🤒 %d" % needs
	_summary_label.text = txt
	_summary_label.add_theme_color_override("font_color",
		Color(0.6, 1, 0.7) if avg > 0.66 else (Color(1, 0.9, 0.5) if avg > 0.4 else Color(1, 0.6, 0.6)))

# --- Top bar: coins + tank name + water ---

func _build_top_bar() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 12
	panel.offset_top = 12
	panel.offset_right = -12
	add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	panel.add_child(row)

	_coin_label = _big_label("🪙 0")
	row.add_child(_coin_label)

	_tank_label = _big_label("")
	row.add_child(_tank_label)

	_summary_label = _big_label("")
	row.add_child(_summary_label)

	var water_box := VBoxContainer.new()
	water_box.custom_minimum_size = Vector2(180, 0)
	row.add_child(water_box)
	water_box.add_child(_small_label("Water"))
	_water_bar = ProgressBar.new()
	_water_bar.min_value = 0
	_water_bar.max_value = 100
	_water_bar.custom_minimum_size = Vector2(180, 18)
	water_box.add_child(_water_bar)

# --- Bottom-left: tank switcher ---

func _build_tank_switcher() -> void:
	_tank_bar = HBoxContainer.new()
	_tank_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	# Anchored to the corner, the container must grow UP (and right) from it, or it lays itself
	# out off-screen below the bottom edge and the buttons never appear.
	_tank_bar.grow_horizontal = Control.GROW_DIRECTION_END
	_tank_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_tank_bar.offset_left = 16
	_tank_bar.offset_bottom = -16
	_tank_bar.add_theme_constant_override("separation", 8)
	add_child(_tank_bar)
	_rebuild_tank_switcher()

## The switcher only switches between tanks you already OWN — it is not a way to jump levels.
## New tanks are earned by finishing quests and bought from the 🛒 Shop's Tanks tab. Any still-locked
## tank shows a dim, non-switching hint pointing the player there.
func _rebuild_tank_switcher() -> void:
	for c in _tank_bar.get_children():
		c.queue_free()
	for tank_id: String in GameState.TANKS:
		var data: Dictionary = GameState.TANKS[tank_id]
		var btn := Button.new()
		if GameState.is_unlocked(tank_id):
			btn.text = String(data["name"])
			btn.pressed.connect(func(): GameState.set_active_tank(tank_id))
		else:
			btn.text = "🔒 %s" % data["name"]
			btn.disabled = true
			btn.tooltip_text = "Finish your quests, then buy this tank in the Shop"
		_tank_bar.add_child(btn)

# --- Bottom-right: actions ---

func _build_action_bar() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	# Same fix as the tank switcher: grow UP and LEFT from the bottom-right corner so the row of
	# action buttons (Feed / Clean / Shop / …) sits on-screen instead of off the bottom edge.
	bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.offset_right = -16
	bar.offset_bottom = -16
	bar.add_theme_constant_override("separation", 10)
	add_child(bar)

	bar.add_child(_action_button("🍤 Feed", func(): Events.feed_requested.emit()))
	bar.add_child(_action_button("🧽 Clean", func(): Events.clean_requested.emit()))
	bar.add_child(_action_button("🛒 Shop", func(): Events.shop_open_requested.emit()))
	bar.add_child(_action_button("🐟", func(): _fishpedia.show_panel()))
	bar.add_child(_action_button("📋", func(): _quests.show_panel()))
	bar.add_child(_action_button("❔", func(): _howto.show_panel()))
	bar.add_child(_action_button("⚙", func(): _options.show_panel()))
	bar.add_child(_action_button("📜", func(): _credits.show_credits()))

# --- Refresh helpers ---

func _refresh() -> void:
	_on_coins_changed(GameState.coins)
	var td := GameState.tank_data(GameState.active_tank)
	var count := GameState.fish_count(GameState.active_tank)
	var cap := GameState.capacity_of(GameState.active_tank)
	_tank_label.text = "%s  (%d/%d 🐟)" % [td.get("name", "?"), count, cap]
	_on_water_changed(GameState.active_tank, float(GameState.cleanliness.get(GameState.active_tank, 1.0)))

func _on_coins_changed(total: int) -> void:
	_coin_label.text = "🪙 %d" % total

func _on_water_changed(tank_id: String, cleanliness: float) -> void:
	if tank_id != GameState.active_tank:
		return
	_water_bar.value = cleanliness * 100.0
	var c := Color(0.3, 0.8, 0.4) if cleanliness > 0.5 else Color(0.85, 0.6, 0.25)
	if cleanliness < 0.25:
		c = Color(0.8, 0.35, 0.3)
	_water_bar.add_theme_color_override("font_color", c)

func _on_fish_clicked(fish_id: int, tank_id: String) -> void:
	# Hide any open card first (e.g. if user clicks a different fish).
	_fish_card.close()
	# Position card near centre of screen.
	_fish_card.position = Vector2(get_viewport().get_visible_rect().size.x * 0.5 - 120, get_viewport().get_visible_rect().size.y * 0.5 - 80)
	_fish_card.show_for(fish_id, tank_id)

# --- Quest celebration: a banner + a few firework bursts (sound handled by AudioManager) ---

func _on_quest_completed(_id: String, title: String, reward: int) -> void:
	_celebration_banner(title, reward)
	var w := get_viewport().get_visible_rect().size.x
	var cols := [Color(1, 0.85, 0.3), Color(0.5, 0.85, 1.0), Color(1, 0.5, 0.7), Color(0.6, 1.0, 0.6), Color(1, 0.7, 0.3)]
	for k in 5:
		_firework(Vector2(w * lerpf(0.18, 0.82, randf()), randf_range(130.0, 280.0)), cols[k % cols.size()], float(k) * 0.2)

func _firework(pos: Vector2, color: Color, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	var p := CPUParticles2D.new()
	p.position = pos
	p.texture = _spark_texture()
	p.amount = 70
	p.lifetime = 1.5
	p.one_shot = true
	p.explosiveness = 1.0          # all sparks at once = a burst
	p.spread = 180.0
	p.direction = Vector2(1, 0)
	p.gravity = Vector2(0, 240)
	p.initial_velocity_min = 170.0
	p.initial_velocity_max = 380.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	p.color = color
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))   # twinkle out
	p.color_ramp = ramp
	add_child(p)
	p.emitting = true
	get_tree().create_timer(2.2).timeout.connect(p.queue_free)

func _spark_texture() -> ImageTexture:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)

func _celebration_banner(title: String, reward: int) -> void:
	var banner := Label.new()
	banner.text = "🎉  Quest Complete!  🎉\n%s   +%d 🪙" % [title, reward]
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 36)
	banner.add_theme_color_override("font_color", Color(1, 0.96, 0.72))
	banner.add_theme_color_override("font_outline_color", Color(0.15, 0.1, 0.0))
	banner.add_theme_constant_override("outline_size", 12)
	banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	banner.offset_top = 96
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.modulate.a = 0.0
	add_child(banner)
	var tw := create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.25)
	tw.tween_interval(1.9)
	tw.tween_property(banner, "modulate:a", 0.0, 0.6)
	tw.tween_callback(banner.queue_free)

# --- Tiny widget factories ---

func _big_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 26)
	return l

func _small_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	return l

func _action_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(110, 48)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(cb)
	return b
