extends Node
## Persists GameState to user://polyquarium_save.json as JSON. Autosaves shortly after
## any economy/fish/tank change so the player never loses progress, debounced so a burst
## of changes writes once.

const SAVE_PATH := "user://polyquarium_save.json"
const AUTOSAVE_DELAY := 1.5  # seconds

var _autosave_timer: Timer

func _ready() -> void:
	_autosave_timer = Timer.new()
	_autosave_timer.one_shot = true
	_autosave_timer.wait_time = AUTOSAVE_DELAY
	_autosave_timer.timeout.connect(save_game)
	add_child(_autosave_timer)

	Events.coins_changed.connect(func(_t): _request_autosave())
	Events.fish_added.connect(func(_s, _t): _request_autosave())
	Events.fish_removed.connect(func(_id): _request_autosave())
	Events.tank_unlocked.connect(func(_t): _request_autosave())

	load_game()

## When true (e.g. on the title screen showing demo fish), changes don't autosave.
var paused: bool = false

func _request_autosave() -> void:
	if paused:
		return
	if is_instance_valid(_autosave_timer):
		_autosave_timer.start()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("PolyQuarium: could not open save file for writing (%d)" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(GameState.to_dict(), "\t"))
	f.close()
	Events.game_saved.emit()

func load_game() -> void:
	if not has_save():
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_warning("PolyQuarium: could not open save file for reading")
		return
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("PolyQuarium: save file is corrupt; ignoring")
		return
	GameState.from_dict(parsed)

func reset_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
