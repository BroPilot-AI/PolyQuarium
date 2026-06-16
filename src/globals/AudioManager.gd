extends Node
## Procedural audio: synthesizes short SFX as AudioStreamWAV at startup (no asset files) and
## plays them on game events — coin, feed, clean, purchase — plus a gentle ambient "bloop" so
## the tank sounds alive. Mute + volume for the options menu.

const RATE := 22050
const VOICES := 6
const SETTINGS_PATH := "user://settings.cfg"

var muted: bool = false
var master_volume: float = 0.9   # 0..1, persisted in settings.cfg
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _sfx: Dictionary = {}
var _ambient_timer: Timer
var _last_coin_ms: int = 0

func _ready() -> void:
	_load_settings()
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)

	_sfx["coin"] = _coin()
	_sfx["feed"] = _feed()
	_sfx["clean"] = _clean()
	_sfx["buy"] = _buy()
	_sfx["bloop"] = _bloop()
	_sfx["fanfare"] = _fanfare()

	Events.coins_earned.connect(func(_a, _p): _play_coin())
	Events.fish_fed.connect(func(_id): play("feed", -3.0))
	Events.clean_requested.connect(func(): play("clean"))
	Events.fish_added.connect(func(_s, _t): play("buy"))
	Events.tank_unlocked.connect(func(_t): play("buy", 3.0))
	Events.quest_completed.connect(func(_i, _t, _r): play("fanfare", 2.0))

	_ambient_timer = Timer.new()
	_ambient_timer.one_shot = true
	_ambient_timer.timeout.connect(_ambient)
	add_child(_ambient_timer)
	_schedule_ambient()

func play(sound: String, db: float = 0.0) -> void:
	if muted or not _sfx.has(sound):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _sfx[sound]
	p.volume_db = db + linear_to_db(maxf(master_volume, 0.0001))
	p.pitch_scale = randf_range(0.94, 1.06)
	p.play()

func set_muted(value: bool) -> void:
	muted = value
	_save_settings()

func set_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_save_settings()
	if not muted:
		play("bloop", -18.0)   # tiny audible preview

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		muted = bool(cfg.get_value("audio", "muted", false))
		master_volume = float(cfg.get_value("audio", "volume", 0.9))

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "muted", muted)
	cfg.set_value("audio", "volume", master_volume)
	cfg.save(SETTINGS_PATH)

# Coins can fire in bursts (many happy fish); throttle so it stays pleasant.
func _play_coin() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_coin_ms < 220:
		return
	_last_coin_ms = now
	play("coin", -5.0)

func _ambient() -> void:
	play("bloop", -17.0)
	_schedule_ambient()

func _schedule_ambient() -> void:
	_ambient_timer.start(randf_range(2.5, 5.5))

# --- tiny synth ---

func _make_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var d := PackedByteArray()
	d.resize(samples.size() * 2)
	for i in samples.size():
		d.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = d
	return w

func _append_tone(arr: PackedFloat32Array, freq: float, dur: float, decay: float, amp: float) -> void:
	var n := int(dur * RATE)
	for i in n:
		var t := float(i) / RATE
		arr.append(sin(TAU * freq * t) * exp(-t * decay) * amp)

func _coin() -> AudioStreamWAV:
	var a := PackedFloat32Array()
	_append_tone(a, 880.0, 0.07, 14.0, 0.40)
	_append_tone(a, 1320.0, 0.11, 10.0, 0.40)
	return _make_wav(a)

## A short victory arpeggio (C-E-G-C) for completing a quest.
func _fanfare() -> AudioStreamWAV:
	var a := PackedFloat32Array()
	_append_tone(a, 523.25, 0.10, 7.0, 0.36)
	_append_tone(a, 659.25, 0.10, 7.0, 0.36)
	_append_tone(a, 783.99, 0.10, 7.0, 0.36)
	_append_tone(a, 1046.50, 0.26, 5.0, 0.42)
	return _make_wav(a)

func _feed() -> AudioStreamWAV:
	var a := PackedFloat32Array()
	var n := int(0.14 * RATE)
	for i in n:
		var t := float(i) / RATE
		var f := lerpf(360.0, 200.0, t / 0.14)
		a.append(sin(TAU * f * t) * exp(-t * 16.0) * 0.4)
	return _make_wav(a)

func _clean() -> AudioStreamWAV:
	var a := PackedFloat32Array()
	_append_tone(a, 1200.0, 0.05, 18.0, 0.30)
	_append_tone(a, 1600.0, 0.05, 18.0, 0.30)
	_append_tone(a, 2100.0, 0.09, 13.0, 0.30)
	return _make_wav(a)

func _buy() -> AudioStreamWAV:
	var a := PackedFloat32Array()
	var n := int(0.24 * RATE)
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * 6.5)
		a.append((sin(TAU * 523.0 * t) + sin(TAU * 659.0 * t) + sin(TAU * 784.0 * t)) * 0.16 * env)
	return _make_wav(a)

func _bloop() -> AudioStreamWAV:
	var a := PackedFloat32Array()
	var n := int(0.18 * RATE)
	for i in n:
		var t := float(i) / RATE
		var f := lerpf(180.0, 320.0, t / 0.18)
		a.append(sin(TAU * f * t) * exp(-t * 9.0) * 0.35)
	return _make_wav(a)
