extends CanvasLayer
## Lightweight transient notifications. Call Toasts.show_toast("Fed the fish!").
## Stacks bottom-up, fades out on its own. Kept deliberately tiny and dependency-free.

const HOLD_TIME := 2.2
const FADE_TIME := 0.5
const MAX_VISIBLE := 4

var _box: VBoxContainer

func _ready() -> void:
	layer = 100
	_box = VBoxContainer.new()
	_box.alignment = BoxContainer.ALIGNMENT_END
	_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_box.offset_left = 24
	_box.offset_right = -24
	_box.offset_bottom = -24
	_box.add_theme_constant_override("separation", 6)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)

func show_toast(text: String, color: Color = Color(0.9, 0.97, 1.0)) -> void:
	if _box.get_child_count() >= MAX_VISIBLE:
		_box.get_child(0).queue_free()

	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(label)

	var tween := create_tween()
	tween.tween_interval(HOLD_TIME)
	tween.tween_property(label, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(label.queue_free)
