class_name OptionsPanel
extends Control
## Options overlay: mute toggle, master volume, and a two-step Reset Save. Audio settings persist
## globally via AudioManager (settings.cfg); reset clears the save and returns to a fresh title.

const TITLE_SCENE := "res://src/ui/TitleScreen.tscn"

var _reset_btn: Button
var _reset_armed := false
var _reset_timer: Timer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.06, 0.10, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 320)
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	panel.add_child(col)

	var header := HBoxContainer.new()
	col.add_child(header)
	var title := Label.new()
	title.text = "⚙ Options"
	title.add_theme_font_size_override("font_size", 26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.pressed.connect(close)
	header.add_child(close_btn)

	# Mute.
	var mute_row := HBoxContainer.new()
	col.add_child(mute_row)
	var mute_lbl := Label.new()
	mute_lbl.text = "Mute audio"
	mute_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mute_row.add_child(mute_lbl)
	var mute_chk := CheckButton.new()
	mute_chk.button_pressed = AudioManager.muted
	mute_chk.toggled.connect(func(on): AudioManager.set_muted(on))
	mute_row.add_child(mute_chk)

	# Volume.
	var vol_row := HBoxContainer.new()
	vol_row.add_theme_constant_override("separation", 12)
	col.add_child(vol_row)
	var vol_lbl := Label.new()
	vol_lbl.text = "Volume"
	vol_row.add_child(vol_lbl)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = AudioManager.master_volume
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(220, 0)
	slider.value_changed.connect(func(v): AudioManager.set_volume(v))
	vol_row.add_child(slider)

	col.add_child(Control.new())   # spacer

	# Reset save (two-step).
	_reset_btn = Button.new()
	_reset_btn.text = "Reset save"
	_reset_btn.add_theme_color_override("font_color", Color(1, 0.6, 0.55))
	_reset_btn.pressed.connect(_on_reset)
	col.add_child(_reset_btn)

	_reset_timer = Timer.new()
	_reset_timer.one_shot = true
	_reset_timer.wait_time = 3.0
	_reset_timer.timeout.connect(_disarm_reset)
	add_child(_reset_timer)

func show_panel() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = get_viewport().get_visible_rect().size
	position = Vector2.ZERO
	_disarm_reset()
	visible = true
	move_to_front()

func close() -> void:
	visible = false

func _on_reset() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_btn.text = "Really reset? (tap again)"
		_reset_timer.start()
		return
	SaveManager.reset_save()
	GameState.from_dict({})   # clean defaults
	get_tree().change_scene_to_file(TITLE_SCENE)

func _disarm_reset() -> void:
	_reset_armed = false
	if is_instance_valid(_reset_btn):
		_reset_btn.text = "Reset save"
