extends Node3D
## Title screen with a LIVE aquarium behind the menu — the player's own bowl if they have a save,
## otherwise a couple of demo goldfish (not saved). UI sits on a CanvasLayer over the 3D tank.

const MAIN_SCENE := "res://src/Main.tscn"

var _had_save := false
var _credits: CreditsScreen
var _options: OptionsPanel

func _ready() -> void:
	# Don't let the demo / preview mutate the player's save while we're on the title.
	_had_save = SaveManager.has_save()
	SaveManager.paused = true
	GameState.active_tank = "bowl"
	if GameState.fish_count("bowl") == 0:
		GameState.add_fish("goldfish", "bowl")
		GameState.add_fish("goldfish", "bowl")

	add_child(Aquarium.new())   # live 3D background

	var ui := CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	_build_menu(ui)
	_credits = CreditsScreen.new()
	ui.add_child(_credits)
	_options = OptionsPanel.new()
	ui.add_child(_options)

func _build_menu(ui: CanvasLayer) -> void:
	var holder := CenterContainer.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(holder)

	# Translucent scrim so the menu stays readable over the bright tank.
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.07, 0.12, 0.62)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(30)
	sb.border_color = Color(0.3, 0.55, 0.7, 0.5)
	sb.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", sb)
	holder.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	vb.custom_minimum_size = Vector2(320, 0)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "🐟 PolyQuarium"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(0.88, 0.96, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.1, 0.2, 0.9))
	title.add_theme_constant_override("outline_size", 8)
	vb.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "a cozy aquarium"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 19)
	subtitle.add_theme_color_override("font_color", Color(0.65, 0.85, 0.98))
	vb.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	vb.add_child(spacer)

	vb.add_child(_menu_button("▶  Play", _on_play))
	vb.add_child(_menu_button("⚙  Options", func(): _options.show_panel()))
	vb.add_child(_menu_button("📜  Credits", func(): _credits.show_credits()))
	vb.add_child(_menu_button("✕  Quit", func(): get_tree().quit()))

func _menu_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 50)
	b.add_theme_font_size_override("font_size", 21)
	b.pressed.connect(cb)
	return b

func _on_play() -> void:
	SaveManager.paused = false
	# Fresh start (no save existed) → clear the demo fish so the game seeds a clean bowl + hints.
	if not _had_save:
		GameState.from_dict({})
	get_tree().change_scene_to_file(MAIN_SCENE)
