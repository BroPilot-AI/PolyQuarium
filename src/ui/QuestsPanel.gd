class_name QuestsPanel
extends Control
## Overlay listing cozy quests with live progress and ✅ on completion. Reads definitions +
## progress from QuestManager. Same overlay pattern as the shop/credits — show_panel()/close().

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
	panel.custom_minimum_size = Vector2(540, 600)
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)

	var header := HBoxContainer.new()
	col.add_child(header)
	var title := Label.new()
	title.text = "📋 Quests"
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
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)

	Events.quest_completed.connect(func(_i, _t, _r): if visible: _populate())

func show_panel() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = get_viewport().get_visible_rect().size
	position = Vector2.ZERO
	_populate()
	visible = true
	move_to_front()

func close() -> void:
	visible = false

func _populate() -> void:
	for c in _list.get_children():
		c.queue_free()
	# Active quests first, completed at the bottom.
	for q: Dictionary in QuestManager.QUESTS:
		if not QuestManager.is_done(String(q["id"])):
			_list.add_child(_row(q))
	for q: Dictionary in QuestManager.QUESTS:
		if QuestManager.is_done(String(q["id"])):
			_list.add_child(_row(q))

func _row(q: Dictionary) -> Control:
	var done := QuestManager.is_done(String(q["id"]))
	var prog := QuestManager.progress(q)
	var goal := QuestManager.goal_of(q)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)

	var top := HBoxContainer.new()
	box.add_child(top)
	var name_lbl := Label.new()
	name_lbl.text = ("✅ " if done else "") + String(q["title"])
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7) if done else Color(0.92, 0.96, 1.0))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_lbl)
	var reward_lbl := Label.new()
	reward_lbl.text = "%d 🪙" % int(q["reward"])
	reward_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	top.add_child(reward_lbl)

	var desc := Label.new()
	desc.text = String(q["desc"])
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.7, 0.8, 0.88))
	box.add_child(desc)

	if not done:
		var bar := ProgressBar.new()
		bar.min_value = 0
		bar.max_value = maxf(1.0, float(goal))
		bar.value = clampf(float(prog), 0.0, float(goal))
		bar.custom_minimum_size = Vector2(0, 16)
		bar.show_percentage = false
		box.add_child(bar)
		var pl := Label.new()
		pl.text = "%d / %d" % [mini(prog, goal), goal]
		pl.add_theme_font_size_override("font_size", 12)
		box.add_child(pl)
	return box
