class_name Fish
extends Node3D
## A single fish: loads its Quaternius .glb (or a tinted primitive fallback), wanders inside the
## tank\'s bounds, gets hungry over time, eats dropped food, and — when happy & well-fed —
## periodically drips coins. Fish need care: PROLONGED starvation or filthy water (e.g. from
## overfeeding) slowly drains health and can eventually kill them — but it\'s Tamagotchi-paced,
## taking minutes of neglect with a clear 🤢 warning and plenty of grace to recover.

const TURN_SPEED := 2.5          # rad/s toward heading
const REPICK_DISTANCE := 0.25    # how close to a target before picking a new one
const HUNGER_RATE := 0.012       # hunger gained per second (gentle — feed every ~minute)
const HAPPY_DECAY := 0.025       # happiness lost per second when hungry/dirty
const HAPPY_RECOVER := 0.06      # happiness gained per second when fed & clean
const COIN_INTERVAL := 5.0       # seconds between coin checks
# --- Health / mortality (Tamagotchi-slow: only drains under sustained extreme neglect) ---
const HEALTH_DRAIN := 0.008      # /s, only while starving OR water is filthy (~125s to die)
const HEALTH_RECOVER := 0.05     # /s when fed & clean — bounces back fast once you care
const STARVING := 0.97           # hunger above this counts as starving
const FILTHY := 0.12             # cleanliness below this is health-threatening
const SICK_WARN := 0.45          # health below this shows the 🤢 warning emote
const EAT_RADIUS := 0.35
const EAT_COOLDOWN := 6.0         # after a bite a fish "digests": ignores food + drifts slowly so
                                  # hungry tankmates get a turn (stops the well-fed ones hogging food)
const FULL_HUNGER := 0.2          # below this a fish is full and won't chase food at all
const TARGET_LENGTH := 0.6        # fit every model to ~this many metres on its longest axis
const MODEL_YAW := PI             # Quaternius fish are authored facing +Z; spin them so their
                                   # nose aligns with the node\'s -Z (the direction looking_at uses)
const GROW_TIME := 60.0           # seconds for fry to grow from 0.45 scale to full size

var fish_id: int = -1
var species_id: String = ""
var swim_bounds: AABB = AABB(Vector3(-2, 0.3, -1), Vector3(4, 2, 2))

var _speed: float = 1.0
var _tint: Color = Color.WHITE
var _target: Vector3
var _hunger: float = 0.3
var _happiness: float = 0.8
var _health: float = 1.0
var _age: float = 999.0         # age in seconds; 999.0 means adult
var _dying: bool = false
var _coin_clock: float = 0.0
var _eat_cooldown: float = 0.0       # >0 while digesting after a meal: rests + ignores food
var _base_materials: Array[StandardMaterial3D] = []
var _base_colors: Array[Color] = []  # original albedo per material, for mood desaturation
var _genome: Array = ["O", "O"]      # colour alleles (see FishGenetics)
var _apply_genetic_tint: bool = false # only recolour non-default (bred/mutated) variants
var _mood_label: Label3D             # Tamagotchi-style emote above the fish
var _last_emote: String = "?"        # only rebuild the label text when the mood changes
var _bob_time: float = 0.0

## tank_id is needed so coin earnings/water lookups read the right tank.
var tank_id: String = "bowl"
var _click_area: Area3D
var _model_root: Node3D          # the model instance (or fallback mesh) — scaled for fry growth
var _base_model_scale: float = 1.0

func happiness() -> float:
	return _happiness

func hunger() -> float:
	return _hunger

func health() -> float:
	return _health

func is_adult() -> bool:
	return _age >= GROW_TIME

func genome() -> Array:
	return _genome

func variant_name() -> String:
	return FishGenetics.variant_name(_genome)

func variant_mult() -> float:
	return FishGenetics.value_mult(_genome)

func setup(p_fish_id: int, p_species: String, p_tank: String, bounds: AABB) -> void:
	fish_id = p_fish_id
	species_id = p_species
	tank_id = p_tank
	swim_bounds = bounds
	var data := FishDatabase.get_species(species_id)
	_speed = float(data.get("speed", 1.0))
	_tint = data.get("tint", Color.WHITE)
	# Seed stats from the saved record if present.
	for rec in GameState.fish.get(tank_id, []):
		if int(rec.get("id", -1)) == fish_id:
			_hunger = float(rec.get("hunger", 0.3))
			_happiness = float(rec.get("happiness", 0.8))
			_health = float(rec.get("health", 1.0))
			_age = float(rec.get("age", 999.0))
			var g: Array = rec.get("genome", [])
			if g.size() == 2:
				_genome = g.duplicate()
			break
	# A non-orange phenotype means this fish was bred/mutated to a variant colour — tint it so
	# rare ones stand out. Default ("O") fish keep their natural model colours.
	if FishGenetics.phenotype(_genome) != "O":
		_tint = FishGenetics.color_of(_genome)
		_apply_genetic_tint = true
	# Build now that species/bounds are known. setup() is the single entry point and runs
	# after add_child(), so doing this here (not in _ready) guarantees the model loads
	# instead of falling back to a placeholder.
	_build_model()
	_build_click_area()
	_build_mood_bubble()
	position = _random_point()
	_target = _random_point()

func _build_mood_bubble() -> void:
	_mood_label = Label3D.new()
	_mood_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_mood_label.no_depth_test = true
	_mood_label.pixel_size = 0.0025
	_mood_label.font_size = 72
	_mood_label.outline_size = 18
	_mood_label.outline_modulate = Color(0, 0.08, 0.15, 0.9)
	_mood_label.position = Vector3(0, 0.30, 0)
	_mood_label.render_priority = 2
	add_child(_mood_label)
	_refresh_mood()

## Pick the most actionable mood and update the floating emote only when it changes (rebuilding
## Label3D text every frame would be wasteful with many fish).
func _refresh_mood() -> void:
	if _mood_label == null:
		return
	var clean := float(GameState.cleanliness.get(tank_id, 1.0))
	var emote := ""
	if _health < SICK_WARN:
		emote = "🤢"          # sick — act now or it'll die
	elif _eat_cooldown > 0.0:
		emote = "💤"          # just ate — digesting, letting others feed
	elif _hunger > 0.7:
		emote = "🍴"          # hungry — feed me
	elif clean < 0.3:
		emote = "🫧"          # water's dirty
	elif _happiness < 0.35:
		emote = "😢"          # sad / neglected
	elif _happiness > 0.78:
		emote = "💕"          # thriving
	if emote != _last_emote:
		_last_emote = emote
		_mood_label.text = emote
		_mood_label.visible = emote != ""

func _build_click_area() -> void:
	_click_area = Area3D.new()
	_click_area.name = "ClickArea"
	_click_area.collision_layer = 1   # must be on a layer or the mouse-picking ray can't hit it
	_click_area.collision_mask = 0
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.3
	shape.shape = sphere
	_click_area.add_child(shape)
	_click_area.input_ray_pickable = true
	_click_area.input_event.connect(_on_click_area_input_event)
	add_child(_click_area)

func _on_click_area_input_event(_cam: Node, event: InputEvent, _hit_pos: Vector3, _hit_normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Events.fish_clicked.emit(fish_id, tank_id)
		get_viewport().set_input_as_handled()

func _build_model() -> void:
	var path := FishDatabase.model_path(species_id)
	if path != "" and ResourceLoader.exists(path):
		var scene := load(path) as PackedScene
		if scene:
			var inst := scene.instantiate()
			add_child(inst)
			_model_root = inst as Node3D
			_fit_model(inst, TARGET_LENGTH)
			(inst as Node3D).rotation.y = MODEL_YAW
			_play_swim_animation(inst)
			_collect_materials(inst)
			return
	# Fallback: a small flattened capsule so the game is playable without assets.
	var mesh := MeshInstance3D.new()
	var prim := CapsuleMesh.new()
	prim.radius = 0.12
	prim.height = 0.5
	mesh.mesh = prim
	mesh.rotation_degrees = Vector3(90, 0, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _tint
	mesh.material_override = mat
	_base_materials.append(mat)
	_base_colors.append(_tint)
	add_child(mesh)
	_model_root = mesh

func _collect_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var surf_count: int = mi.mesh.get_surface_count() if mi.mesh else 0
		for s in surf_count:
			var m := mi.get_active_material(s)
			if m is StandardMaterial3D:
				# Duplicate so mood-tinting this fish doesn't recolour every other fish
				# sharing the imported material.
				var dup := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
				var base_col := dup.albedo_color
				if _apply_genetic_tint:
					base_col = base_col.lerp(_tint, 0.6)
					dup.albedo_color = base_col
				mi.set_surface_override_material(s, dup)
				_base_materials.append(dup)
				_base_colors.append(base_col)
	for c in node.get_children():
		_collect_materials(c)

## Quaternius animated glbs park a ~100x scale on the Armature, so a raw instance is huge.
## Measure the rendered bounds (accumulating child transforms) and scale the instance so its
## longest axis equals `target`, regardless of the baked-in armature scale.
func _fit_model(inst: Node, target: float) -> void:
	if not (inst is Node3D):
		return
	var bounds := AABB()
	var seen := false
	for c in inst.get_children():
		var a := _accumulate_aabb(c, Transform3D.IDENTITY)
		if a.size == Vector3.ZERO:
			continue
		bounds = a if not seen else bounds.merge(a)
		seen = true
	if not seen:
		return
	var longest := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if longest > 0.0001:
		var s := target / longest
		var node3d := inst as Node3D
		node3d.scale = Vector3(s, s, s)
		_base_model_scale = s

func _accumulate_aabb(node: Node, parent_xform: Transform3D) -> AABB:
	var local := parent_xform
	if node is Node3D:
		local = parent_xform * (node as Node3D).transform
	var out := AABB()
	var seen := false
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		out = local * (node as MeshInstance3D).mesh.get_aabb()
		seen = true
	for c in node.get_children():
		var a := _accumulate_aabb(c, local)
		if a.size == Vector3.ZERO:
			continue
		out = a if not seen else out.merge(a)
		seen = true
	return out

func _play_swim_animation(inst: Node) -> void:
	var ap := _find_anim_player(inst)
	if ap == null:
		return
	var names := ap.get_animation_list()
	if names.is_empty():
		return
	# Prefer a swim/idle clip if named; otherwise just take the first.
	var chosen := String(names[0])
	for n in names:
		var ln := String(n).to_lower()
		if ln.contains("swim") or ln.contains("idle"):
			chosen = String(n)
			break
	var anim := ap.get_animation(chosen)
	if anim:
		anim.loop_mode = Animation.LOOP_LINEAR
	ap.play(chosen)

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for c in node.get_children():
		var found := _find_anim_player(c)
		if found:
			return found
	return null

func _process(delta: float) -> void:
	_update_needs(delta)
	_swim(delta)
	_maybe_earn(delta)
	# Gentle bob on the mood emote so it feels alive.
	if _mood_label and _mood_label.visible:
		_bob_time += delta
		_mood_label.position.y = 0.30 + sin(_bob_time * 2.2) * 0.03

func _update_needs(delta: float) -> void:
	if _eat_cooldown > 0.0:
		_eat_cooldown = maxf(0.0, _eat_cooldown - delta)
	_hunger = clampf(_hunger + HUNGER_RATE * delta, 0.0, 1.0)
	var clean := float(GameState.cleanliness.get(tank_id, 1.0))
	var thriving := _hunger < 0.6 and clean > 0.5
	if thriving:
		_happiness = clampf(_happiness + HAPPY_RECOVER * delta, 0.0, 1.0)
	else:
		_happiness = clampf(_happiness - HAPPY_DECAY * delta, 0.0, 1.0)
	# Mood shows in saturation: sad/neglected fish look washed out, never gone. Each
	# material desaturates from its own original colour so .glb textures stay intact.
	var washout := (1.0 - _happiness) * 0.65
	for i in _base_materials.size():
		_base_materials[i].albedo_color = _base_colors[i].lerp(Color(0.6, 0.6, 0.6), washout)
	_update_health(delta, clean)
	_refresh_mood()
	_sync_record()
	# Fry growth: scale from 0.45 to 1.0 over GROW_TIME seconds.
	if _age < GROW_TIME and _model_root:
		_age += delta
		# Scale the MODEL child only (not the Fish node — that would corrupt the rotation basis
		# the swim code slerps). rendered size = fit_scale × grow.
		var grow := lerpf(0.45, 1.0, clampf(_age / GROW_TIME, 0.0, 1.0))
		var s := _base_model_scale * grow
		_model_root.scale = Vector3(s, s, s)

## Tamagotchi-paced health: only erodes under sustained extremes (starving OR filthy water),
## bounces back quickly once cared for. Plenty of grace + a 🤢 warning before it's fatal.
func _update_health(delta: float, clean: float) -> void:
	if _dying:
		return
	if _hunger >= STARVING or clean <= FILTHY:
		_health = clampf(_health - HEALTH_DRAIN * delta, 0.0, 1.0)
		if _health <= 0.0:
			_die()
	elif _hunger < 0.6 and clean > 0.4:
		_health = clampf(_health + HEALTH_RECOVER * delta, 0.0, 1.0)

func _die() -> void:
	_dying = true
	Toasts.show_toast("💔 Your %s didn't make it…" % FishDatabase.species_name(species_id), Color(1, 0.6, 0.6))
	Events.fish_died.emit(fish_id, species_id, tank_id)
	GameState.remove_fish(tank_id, fish_id)   # emits fish_removed → Aquarium despawns this node

func _swim(delta: float) -> void:
	var to_target := _target - position
	if to_target.length() < REPICK_DISTANCE:
		_target = _pick_target()
		to_target = _target - position
	var dir := to_target.normalized()
	# Smoothly face travel direction, then move. Guard the gimbal case where the heading
	# is (anti)parallel to UP, which would make looking_at error.
	if dir.length() > 0.01 and absf(dir.dot(Vector3.UP)) < 0.98:
		var want := Basis.looking_at(dir, Vector3.UP)
		basis = basis.slerp(want, clampf(TURN_SPEED * delta, 0.0, 1.0)).orthonormalized()
	# Happy fish are a touch livelier; HUNGRY fish dart with urgency so even slow species (the
	# lionfish!) can reach food before it rots on the bottom.
	var pace := _speed * lerpf(0.6, 1.1, _happiness)
	if _hunger > 0.45:
		pace *= lerpf(1.0, 2.0, clampf((_hunger - 0.45) / 0.55, 0.0, 1.0))
	# Just-fed fish drift slowly while they "digest", so they drop back from the food.
	if _eat_cooldown > 0.0:
		pace *= 0.2
	position += dir * pace * delta
	position = _clamp_to_bounds(position)

func _maybe_earn(delta: float) -> void:
	_coin_clock += delta
	if _coin_clock < COIN_INTERVAL:
		return
	_coin_clock = 0.0
	if _happiness > 0.55 and _hunger < 0.7:
		var payout := int(round(lerpf(1.0, 5.0, _happiness)))
		GameState.add_coins(payout, global_position)
		Events.fish_mood_changed.emit(fish_id, _happiness)

## Called by Aquarium when food is dropped; returns true if this fish claims it.
func try_eat(food_pos: Vector3) -> bool:
	# Digesting (just ate) or already full → ignore the food entirely, leaving it for hungry fish.
	if _eat_cooldown > 0.0 or _hunger < FULL_HUNGER:
		return false
	if global_position.distance_to(food_pos) <= EAT_RADIUS:
		_hunger = clampf(_hunger - 0.5, 0.0, 1.0)
		_happiness = clampf(_happiness + 0.1, 0.0, 1.0)
		_eat_cooldown = EAT_COOLDOWN   # now rest a beat so others can feed
		Events.fish_fed.emit(fish_id)
		_sync_record()
		return true
	# Otherwise steer toward it.
	_target = food_pos
	return false

func _pick_target() -> Vector3:
	return _random_point()

func _random_point() -> Vector3:
	return Vector3(
		randf_range(swim_bounds.position.x, swim_bounds.end.x),
		randf_range(swim_bounds.position.y, swim_bounds.end.y),
		randf_range(swim_bounds.position.z, swim_bounds.end.z))

func _clamp_to_bounds(p: Vector3) -> Vector3:
	return Vector3(
		clampf(p.x, swim_bounds.position.x, swim_bounds.end.x),
		clampf(p.y, swim_bounds.position.y, swim_bounds.end.y),
		clampf(p.z, swim_bounds.position.z, swim_bounds.end.z))

func _sync_record() -> void:
	for rec in GameState.fish.get(tank_id, []):
		if int(rec.get("id", -1)) == fish_id:
			rec["hunger"] = _hunger
			rec["happiness"] = _happiness
			rec["health"] = _health
			rec["age"] = _age
			return
