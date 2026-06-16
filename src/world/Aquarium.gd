class_name Aquarium
extends Node3D
## Builds the active tank procedurally (glass, water volume, sand, lighting, camera),
## spawns the fish that live in it from GameState, and runs the care loop: feeding via
## click-to-drop food, and water cleanliness that slowly fouls and is restored by the
## Clean action. Rebuilds itself whenever the player switches tanks.

const FOUL_RATE := 0.0012         # cleanliness lost per second, per fish (gentle, cozy pace)
const BREED_INTERVAL := 14.0      # seconds between breeding checks
const BREED_CHANCE := 0.5         # chance a check yields a baby when a healthy pair exists
const CAUSTICS_SHADER := preload("res://src/world/shaders/caustics.gdshader")
const GLASS_SHADER := preload("res://src/world/shaders/glass.gdshader")
const GODRAY_SHADER := preload("res://src/world/shaders/godrays.gdshader")
const SURFACE_SHADER := preload("res://src/world/shaders/watersurface.gdshader")
const FOOD_FALL_SPEED := 0.6
const FOOD_LIFETIME := 16.0       # how long a pellet lingers on the substrate before it rots away
const FOOD_FOUL_RATE := 0.012     # cleanliness lost per second per uneaten pellet resting on bottom

var _bounds: AABB
var _sub_top: float = 0.0               # top surface of the substrate; decor + food rest here
var _swim_bounds: AABB                  # fish stay above the substrate (not inside it)
var _fish_nodes: Array[Fish] = []
var _decor_nodes: Array[Node3D] = []
var _food: Array[Dictionary] = []  # {node:MeshInstance3D, vel:float, age:float}
var _camera: Camera3D
var _tank_root: Node3D
var _env_res: Environment              # tuned per tank by TankSetting
var _sun: DirectionalLight3D           # re-aimed/tinted per tank by TankSetting
var _water_mat: ShaderMaterial         # glass shader; _process tunes murkiness by cleanliness
var _water_time: float = 0.0
var _breed_clock: float = 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	# Required for clicking a fish (Area3D input_event) to register — without it every click falls
	# through to the feed handler and you can never open a fish's card to sell it.
	get_viewport().physics_object_picking = true
	get_viewport().physics_object_picking_sort = true
	_build_environment()
	Events.tank_changed.connect(_on_tank_changed)
	Events.feed_requested.connect(_drop_food_center)
	Events.clean_requested.connect(_clean_water)
	Events.fish_added.connect(_on_fish_added)
	Events.fish_removed.connect(_on_fish_removed)
	Events.decor_added.connect(_on_decor_added)
	Events.coins_earned.connect(_on_coins_earned)
	_rebuild(GameState.active_tank)

## Floating "+N" coin popup where a fish earned, rising and fading. world_pos == ZERO means a
## non-positional gain (e.g. a sale) — skip those, they have their own toast.
func _on_coins_earned(amount: int, world_pos: Vector3) -> void:
	if world_pos == Vector3.ZERO or _tank_root == null:
		return
	var lbl := Label3D.new()
	lbl.text = "+%d" % amount
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.pixel_size = 0.0024
	lbl.font_size = 64
	lbl.modulate = Color(1.0, 0.85, 0.3)
	lbl.outline_size = 14
	lbl.outline_modulate = Color(0.2, 0.12, 0.0, 0.9)
	lbl.position = world_pos + Vector3(0, 0.18, 0)
	_tank_root.add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y + 0.55, 1.1)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.1).set_ease(Tween.EASE_IN)
	tw.set_parallel(false)
	tw.tween_callback(lbl.queue_free)

# --- Static scene scaffolding (built once) ---

func _build_environment() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.04, 0.10, 0.16)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.78, 0.86, 0.95)
	e.ambient_light_energy = 1.5

	# --- Cozy "nice looking" post-processing (global; survives per-tank tweaks) ---
	# AgX tonemapping for soft, filmic colour instead of flat clipped sRGB.
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = 1.05
	e.tonemap_white = 1.0
	# Gentle bloom so the window, lamps and caustics glow warmly (only bright/emissive pixels).
	e.glow_enabled = true
	e.glow_intensity = 0.55
	e.glow_strength = 1.0
	e.glow_bloom = 0.12
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	e.glow_hdr_threshold = 0.92
	# Soft contact shadows ground the furniture/props on the floor (kills the floaty look).
	e.ssao_enabled = true
	e.ssao_radius = 0.7
	e.ssao_intensity = 1.6
	e.ssao_power = 1.4
	e.ssao_detail = 0.5
	# A warm, slightly richer colour grade.
	e.adjustment_enabled = true
	e.adjustment_brightness = 1.02
	e.adjustment_contrast = 1.06
	e.adjustment_saturation = 1.08

	env.environment = e
	_env_res = e                 # TankSetting.apply_environment tunes this per tank
	add_child(env)

	_sun = DirectionalLight3D.new()
	# Soft sun shadows add depth without hard edges — cozy, not stark.
	_sun.shadow_enabled = true
	_sun.shadow_blur = 1.5
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	add_child(_sun)

	_camera = Camera3D.new()
	_camera.current = true
	add_child(_camera)

# --- Per-tank build ---

func _on_tank_changed(tank_id: String) -> void:
	_rebuild(tank_id)

func _rebuild(tank_id: String) -> void:
	if _tank_root:
		_tank_root.queue_free()
	for f in _food:
		if is_instance_valid(f["node"]):
			f["node"].queue_free()
	_food.clear()
	_fish_nodes.clear()
	for d in _decor_nodes:
		if is_instance_valid(d):
			d.queue_free()
	_decor_nodes.clear()

	_tank_root = Node3D.new()
	add_child(_tank_root)

	_bounds = _bounds_for(tank_id)
	var tank_type := int(GameState.tank_data(tank_id).get("type", 0))
	TankSetting.apply_environment(_env_res, _sun, tank_type)
	TankSetting.build_room(_tank_root, tank_type, _bounds)
	_build_glass_and_sand()
	# Fish swim above the substrate, not down into it.
	_swim_bounds = AABB(
		Vector3(_bounds.position.x, _sub_top + 0.12, _bounds.position.z),
		Vector3(_bounds.size.x, maxf(_bounds.end.y - (_sub_top + 0.12), 0.3), _bounds.size.z))
	_place_camera()
	_spawn_existing_fish(tank_id)
	_spawn_existing_decor(tank_id)

func _bounds_for(tank_id: String) -> AABB:
	match int(GameState.tank_data(tank_id).get("type", 0)):
		FishDatabase.TankType.BOWL:
			return AABB(Vector3(-1.2, 0.3, -0.8), Vector3(2.4, 1.4, 1.6))
		FishDatabase.TankType.FRESHWATER:
			return AABB(Vector3(-2.5, 0.3, -1.2), Vector3(5.0, 2.0, 2.4))
		_:
			return AABB(Vector3(-4.0, 0.3, -1.5), Vector3(8.0, 2.6, 3.0))

func _build_glass_and_sand() -> void:
	var size := _bounds.size + Vector3(0.6, 0.6, 0.6)
	var center := _bounds.position + _bounds.size * 0.5

	# Water volume — translucent tinted box. Full side/bottom margin, but only a thin lip above
	# the waterline so the tank reads as filled rather than a third empty up top.
	var glass_top := _bounds.end.y + 0.05
	var glass_bottom := _bounds.position.y - 0.3
	var water := MeshInstance3D.new()
	var wbox := BoxMesh.new()
	wbox.size = Vector3(size.x, glass_top - glass_bottom, size.z)
	water.mesh = wbox
	water.position = Vector3(center.x, (glass_top + glass_bottom) * 0.5, center.z)
	var wmat := ShaderMaterial.new()
	wmat.shader = GLASS_SHADER
	wmat.set_shader_parameter("water_color", Color(0.2, 0.55, 0.7, 0.14))
	water.material_override = wmat
	_water_mat = wmat
	_tank_root.add_child(water)

	_build_substrate(size, center, glass_bottom)

	_build_tank_frame(glass_top)
	_build_water_fx()
	_build_godrays()
	_build_water_surface()

## A bed of substrate at the tank bottom — a coloured caustic-lit base plus scattered low-poly
## grains so it reads as a real material: blue gravel (bowl), brown sand (freshwater), white sand
## (reef). Its top (_sub_top) is what decor and food rest on, and fish swim above it.
func _build_substrate(size: Vector3, center: Vector3, glass_bottom: float) -> void:
	var tank_type := int(GameState.tank_data(GameState.active_tank).get("type", 0))
	_sub_top = _bounds.position.y + 0.15
	var base_color: Color
	var gravel := false
	match tank_type:
		FishDatabase.TankType.BOWL:
			base_color = Color(0.26, 0.40, 0.62); gravel = true   # blue gravel
		FishDatabase.TankType.FRESHWATER:
			base_color = Color(0.55, 0.42, 0.27)                  # brown sand
		_:
			base_color = Color(0.90, 0.88, 0.82)                  # white sand

	var bed := MeshInstance3D.new()
	var bbox := BoxMesh.new()
	bbox.size = Vector3(size.x, _sub_top - glass_bottom, size.z)
	bed.mesh = bbox
	bed.position = Vector3(center.x, (_sub_top + glass_bottom) * 0.5, center.z)
	var smat := ShaderMaterial.new()
	smat.shader = CAUSTICS_SHADER
	smat.set_shader_parameter("base_color", base_color)
	smat.set_shader_parameter("caustic_strength", 1.3)
	smat.set_shader_parameter("sharpness", 4.5)
	smat.set_shader_parameter("caustic_scale", 4.0)
	bed.material_override = smat
	_tank_root.add_child(bed)

	# Scattered grains: chunky faceted pebbles for gravel, low wide humps for sand.
	var hx := size.x * 0.46
	var hz := size.z * 0.46
	var count := int(clampf(size.x * size.z * (16.0 if gravel else 9.0), 24, 240))
	for i in count:
		var m := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radial_segments = 6
		sph.rings = 3
		var r: float
		var flat: float
		var col: Color
		if gravel:
			r = _rng.randf_range(0.05, 0.11)
			flat = _rng.randf_range(0.55, 0.8)
			col = base_color.lerp(Color(_rng.randf_range(0.2, 0.45), _rng.randf_range(0.4, 0.6), _rng.randf_range(0.55, 0.85)), _rng.randf_range(0.0, 0.7))
		else:
			r = _rng.randf_range(0.09, 0.2)
			flat = _rng.randf_range(0.1, 0.2)
			col = base_color * _rng.randf_range(0.82, 1.12)
		sph.radius = r
		sph.height = r * 2.0 * flat
		m.mesh = sph
		m.position = Vector3(center.x + _rng.randf_range(-hx, hx), _sub_top - r * flat * 0.4, center.z + _rng.randf_range(-hz, hz))
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = col
		pmat.roughness = 0.92
		m.material_override = pmat
		_tank_root.add_child(m)

## A dark rim/bezel around the tank: top + bottom trim bars and four corner posts, like the
## anodized frame of a real aquarium. The bottom rim sits at the furniture surface so the tank
## reads as a distinct object resting on the desk/console rather than melting into it.
func _build_tank_frame(glass_top: float) -> void:
	var size := _bounds.size + Vector3(0.6, 0.6, 0.6)
	var center := _bounds.position + _bounds.size * 0.5
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var top_y := glass_top
	var bot_y := _bounds.position.y   # furniture surface — the tank/desk junction
	var t := clampf(minf(size.x, size.z) * 0.05, 0.05, 0.12)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.11, 0.11, 0.13)
	mat.metallic = 0.35
	mat.roughness = 0.45

	# Top + bottom rims: bars along X at the front/back faces, bars along Z at the side faces.
	for ry in [top_y, bot_y]:
		_frame_bar(Vector3(size.x + t, t, t), Vector3(center.x, ry, center.z + hz), mat)
		_frame_bar(Vector3(size.x + t, t, t), Vector3(center.x, ry, center.z - hz), mat)
		_frame_bar(Vector3(t, t, size.z + t), Vector3(center.x + hx, ry, center.z), mat)
		_frame_bar(Vector3(t, t, size.z + t), Vector3(center.x - hx, ry, center.z), mat)

	# Vertical corner posts joining the two rims.
	var ph := top_y - bot_y
	var cy := (top_y + bot_y) * 0.5
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_frame_bar(Vector3(t, ph, t), Vector3(center.x + hx * sx, cy, center.z + hz * sz), mat)

func _frame_bar(bar_size: Vector3, pos: Vector3, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = bar_size
	m.mesh = box
	m.position = pos
	m.material_override = mat
	_tank_root.add_child(m)

## Rising bubbles + a soft surface glow to make the tank feel alive. Cheap and tasteful;
## scaled to the current tank so the bowl and the reef both look right.
func _build_water_fx() -> void:
	var center := _bounds.position + _bounds.size * 0.5

	# Rising bubbles (CPU particles for safety across setups).
	var bubbles := CPUParticles3D.new()
	bubbles.amount = int(clampf(_bounds.size.x * _bounds.size.z * 6.0, 12, 80))
	# Constant rise (no gravity accel); lifetime is tuned so even the fastest bubble dissolves
	# just below the surface instead of shooting out of the water.
	var top_vel := 0.45
	bubbles.gravity = Vector3.ZERO
	bubbles.initial_velocity_min = 0.30
	bubbles.initial_velocity_max = top_vel
	bubbles.lifetime = (_bounds.size.y / top_vel) * 0.9
	bubbles.position = Vector3(center.x, _bounds.position.y + 0.05, center.z)
	bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	bubbles.emission_box_extents = Vector3(_bounds.size.x * 0.45, 0.04, _bounds.size.z * 0.45)
	bubbles.direction = Vector3.UP
	bubbles.spread = 5.0
	bubbles.scale_amount_min = 0.012
	bubbles.scale_amount_max = 0.035
	# Fade alpha to nothing over life so they dissolve at the surface.
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	bubbles.color_ramp = ramp
	var bmesh := SphereMesh.new()
	bmesh.radius = 1.0
	bmesh.height = 2.0
	bubbles.mesh = bmesh
	var bmat := StandardMaterial3D.new()
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.albedo_color = Color(0.8, 0.95, 1.0, 0.35)
	bmat.emission_enabled = true
	bmat.emission = Color(0.6, 0.85, 1.0)
	bmat.emission_energy_multiplier = 0.4
	bmesh.material = bmat
	_tank_root.add_child(bubbles)

	# Soft surface glow from just above the waterline.
	var glow := OmniLight3D.new()
	glow.position = Vector3(center.x, _bounds.end.y - 0.1, center.z)
	glow.light_color = Color(0.6, 0.85, 1.0)
	glow.light_energy = 1.2
	glow.omni_range = maxf(_bounds.size.x, _bounds.size.z) * 1.2
	glow.omni_attenuation = 1.5
	_tank_root.add_child(glow)

## A few faint camera-facing shafts of light from the surface — additive, fading to the floor.
func _build_godrays() -> void:
	var center := _bounds.position + _bounds.size * 0.5
	var mat := ShaderMaterial.new()
	mat.shader = GODRAY_SHADER
	mat.set_shader_parameter("top_y", _bounds.end.y)
	mat.set_shader_parameter("bottom_y", _bounds.position.y)
	for i in 3:
		var quad := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(_bounds.size.x * 0.32, _bounds.size.y)
		quad.mesh = qm
		quad.material_override = mat
		var fx := lerpf(-0.32, 0.32, float(i) / 2.0)
		quad.position = Vector3(center.x + _bounds.size.x * fx, center.y, center.z - _bounds.size.z * 0.1)
		quad.rotation.y = deg_to_rad(7.0 * float(i - 1))   # slight fan
		_tank_root.add_child(quad)

## A subtly rippling translucent plane at the waterline so the surface reads as moving water.
func _build_water_surface() -> void:
	var center := _bounds.position + _bounds.size * 0.5
	var surf := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(_bounds.size.x + 0.35, _bounds.size.z + 0.35)
	pm.subdivide_width = 16
	pm.subdivide_depth = 16
	surf.mesh = pm
	surf.position = Vector3(center.x, _bounds.end.y + 0.01, center.z)
	var mat := ShaderMaterial.new()
	mat.shader = SURFACE_SHADER
	surf.material_override = mat
	_tank_root.add_child(surf)

func _place_camera() -> void:
	var center := _bounds.position + _bounds.size * 0.5
	var dist := maxf(_bounds.size.x, _bounds.size.y) * 1.3 + 2.0
	_camera.position = center + Vector3(0, _bounds.size.y * 0.25, dist)
	_camera.look_at(center, Vector3.UP)

func _spawn_existing_fish(tank_id: String) -> void:
	for rec: Dictionary in GameState.fish.get(tank_id, []):
		_spawn_fish_node(int(rec["id"]), String(rec["species"]), tank_id)

func _on_fish_added(species_id: String, tank_id: String) -> void:
	if tank_id != GameState.active_tank:
		return  # it'll be spawned when the player visits that tank
	# add_fish appended the record just before emitting; the newest is last.
	var arr: Array = GameState.fish.get(tank_id, [])
	if arr.is_empty():
		return
	var rec: Dictionary = arr.back()
	_spawn_fish_node(int(rec["id"]), species_id, tank_id)

func _spawn_fish_node(fish_id: int, species_id: String, tank_id: String) -> void:
	var f := Fish.new()
	_tank_root.add_child(f)
	f.setup(fish_id, species_id, tank_id, _swim_bounds)
	_fish_nodes.append(f)

func _on_fish_removed(fish_id: int) -> void:
	for i in range(_fish_nodes.size() - 1, -1, -1):
		var f := _fish_nodes[i]
		if is_instance_valid(f) and f.fish_id == fish_id:
			_fish_nodes.remove_at(i)
			f.queue_free()
			return

# --- Decor ---

func _spawn_existing_decor(tank_id: String) -> void:
	for rec: Dictionary in GameState.decor.get(tank_id, []):
		_spawn_decor_node(String(rec["decor_id"]), tank_id)

func _on_decor_added(decor_id: String, tank_id: String) -> void:
	if tank_id != GameState.active_tank:
		return
	_spawn_decor_node(decor_id, tank_id)

func _spawn_decor_node(decor_id: String, tank_id: String) -> void:
	var data := DecorDatabase.get_decor(decor_id)
	var tint: Color = data.get("tint", Color(0.5, 0.5, 0.5))
	var node := Node3D.new()
	# Scatter across the sand using a low-discrepancy (golden-ratio) sequence on both X and
	# Z, so decor never stacks no matter how many there are. idx is taken before this node is
	# tracked, giving each piece a stable, well-spread spot.
	var idx := _decor_nodes.size()
	var center := _bounds.position + _bounds.size * 0.5
	var x_frac := fmod(float(idx) * 0.61803 + 0.13, 1.0)
	var z_frac := fmod(float(idx) * 0.37 + 0.2, 1.0)
	node.position = Vector3(
		center.x + lerpf(-_bounds.size.x * 0.4, _bounds.size.x * 0.4, x_frac),
		_sub_top,
		center.z + lerpf(-_bounds.size.z * 0.3, _bounds.size.z * 0.3, z_frac))
	# Directional props (chest, castle, anchor) keep their front toward the camera (+Z) with
	# just a small wiggle; organic decor (rocks, plants, coral) spins freely for variety.
	if bool(data.get("front", false)):
		node.rotate_y(randf_range(-0.35, 0.35))
	else:
		node.rotate_y(randf_range(0.0, TAU))
	_tank_root.add_child(node)
	_decor_nodes.append(node)   # track immediately, before any early return

	# Try loading the .glb; fall back to a tinted primitive.
	var path := DecorDatabase.model_path(decor_id)
	if path != "" and ResourceLoader.exists(path):
		var scene := load(path) as PackedScene
		if scene:
			var inst := scene.instantiate()
			node.add_child(inst)
			_fit_model(inst, randf_range(0.55, 0.85))
			_rest_on_substrate(inst)   # sit its base on the substrate, not floating above it
			return
	# Primitive fallback: mix of shapes for visual variety.
	var mesh_node := MeshInstance3D.new()
	var prim: Mesh
	match decor_id:
		"seaweed", "kelp":
			prim = CylinderMesh.new()
			(prim as CylinderMesh).top_radius = 0.04
			(prim as CylinderMesh).bottom_radius = 0.06
			(prim as CylinderMesh).height = 0.7
		"coral_fan", "anemone":
			prim = SphereMesh.new()
			(prim as SphereMesh).radius = 0.25
			(prim as SphereMesh).height = 0.5
		_:
			prim = BoxMesh.new()
			(prim as BoxMesh).size = Vector3(0.3, 0.25, 0.3)
	mesh_node.mesh = prim
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mesh_node.material_override = mat
	mesh_node.position.y = -prim.get_aabb().position.y   # base sits on the substrate
	node.add_child(mesh_node)
	# (node was already appended to _decor_nodes above, before the .glb branch.)

# --- Model fitting (shared logic for .glb instances) ---

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
		(inst as Node3D).scale = Vector3(s, s, s)

## Drop a fitted model so the bottom of its bounds sits at its node origin (which is on the
## substrate), instead of floating above or sinking into it.
func _rest_on_substrate(inst: Node) -> void:
	if not (inst is Node3D):
		return
	var ab := _accumulate_aabb(inst, Transform3D.IDENTITY)
	if ab.size != Vector3.ZERO:
		(inst as Node3D).position.y -= ab.position.y

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

# --- Care loop ---

func _process(delta: float) -> void:
	_foul_water(delta)
	_update_food(delta)
	_animate_water(delta)
	_maybe_breed(delta)

## Healthy, well-fed pairs of the same species occasionally produce a fry with a crossed genome
## (one allele from each parent + a small mutation chance). Only the active tank breeds (its
## fish are the ones instantiated). Respects capacity.
func _maybe_breed(delta: float) -> void:
	_breed_clock += delta
	if _breed_clock < BREED_INTERVAL:
		return
	_breed_clock = 0.0
	var tank := GameState.active_tank
	if not GameState.has_room(tank):
		return
	var by_species := {}
	for f in _fish_nodes:
		if is_instance_valid(f) and f.is_adult() and f.happiness() > 0.7 and f.hunger() < 0.5 and f.health() > 0.6:
			if not by_species.has(f.species_id):
				by_species[f.species_id] = []
			by_species[f.species_id].append(f)
	for sp: String in by_species:
		var group: Array = by_species[sp]
		if group.size() >= 2 and _rng.randf() < BREED_CHANCE:
			var child := FishGenetics.cross(group[0].genome(), group[1].genome(), _rng)
			if FishGenetics.is_rare(child):
				GameState.bump_stat("bred_rare", 1)   # feeds the Geneticist quest
			if GameState.add_fish(sp, tank, child, 0.0) > 0:
				var sname := FishDatabase.species_name(sp)
				if FishGenetics.is_rare(child):
					Toasts.show_toast("🐣✨ A rare %s %s was born!" % [FishGenetics.variant_name(child), sname], Color(1, 0.9, 0.5))
				else:
					Toasts.show_toast("🐣 A baby %s was born!" % sname, Color(0.8, 1.0, 0.85))
			return   # at most one birth per check

## A barely-there shimmer: pulse the water's alpha and roughness so the surface feels
## like moving water rather than a static pane. Tinted slightly cleaner when the water is.
func _animate_water(delta: float) -> void:
	if _water_mat == null:
		return
	var clean := float(GameState.cleanliness.get(GameState.active_tank, 1.0))
	# Dirtier water turns murkier and greener; clean water is clear blue. (Surface ripple +
	# fresnel provide the motion now.)
	var col := Color(0.20, 0.55, 0.70).lerp(Color(0.32, 0.46, 0.26), 1.0 - clean)
	col.a = lerpf(0.30, 0.12, clean)
	_water_mat.set_shader_parameter("water_color", col)

func _foul_water(delta: float) -> void:
	var n := _fish_nodes.size()
	if n == 0:
		return
	var prev := float(GameState.cleanliness.get(GameState.active_tank, 1.0))
	var next := clampf(prev - FOUL_RATE * n * delta, 0.0, 1.0)
	if not is_equal_approx(prev, next):
		GameState.cleanliness[GameState.active_tank] = next
		Events.water_quality_changed.emit(GameState.active_tank, next)

func _clean_water() -> void:
	GameState.cleanliness[GameState.active_tank] = 1.0
	Events.water_quality_changed.emit(GameState.active_tank, 1.0)
	Toasts.show_toast("Water cleaned ✨")

func _drop_food_center() -> void:
	var top := Vector3(
		randf_range(_bounds.position.x, _bounds.end.x),
		_bounds.end.y - 0.1,
		randf_range(_bounds.position.z, _bounds.end.z))
	_spawn_food(top)

func _spawn_food(pos: Vector3) -> void:
	var pellet := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.05
	sph.height = 0.10
	sph.radial_segments = 8
	sph.rings = 4
	pellet.mesh = sph
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.42, 0.22)
	mat.roughness = 0.85
	# No emission — with the scene's bloom, emissive pellets ballooned into big glowing orbs.
	pellet.material_override = mat
	pellet.position = pos
	_tank_root.add_child(pellet)
	_food.append({"node": pellet, "age": 0.0})
	Events.food_dropped.emit(pos)

func _update_food(delta: float) -> void:
	for i in range(_food.size() - 1, -1, -1):
		var entry: Dictionary = _food[i]
		var node: MeshInstance3D = entry["node"]
		if not is_instance_valid(node):
			_food.remove_at(i)
			continue
		# Fall until it lands on the substrate, then REST on top of it (still eatable) instead of
		# vanishing — so a fish coming off its digest cooldown can still find it on the bottom.
		if not bool(entry.get("resting", false)):
			node.position.y -= FOOD_FALL_SPEED * delta
			if node.position.y <= _sub_top + 0.05:
				node.position.y = _sub_top + 0.05
				entry["resting"] = true
		entry["age"] += delta
		var eaten := false
		for f in _fish_nodes:
			if is_instance_valid(f) and f.try_eat(node.position):
				eaten = true
				break
		# Uneaten food resting on the substrate rots and fouls the water continuously — the more
		# pellets pile up, the faster the tank festers, so overfeeding is a real balancing act.
		if not eaten and bool(entry.get("resting", false)):
			var c := float(GameState.cleanliness.get(GameState.active_tank, 1.0))
			var nc := clampf(c - FOOD_FOUL_RATE * delta, 0.0, 1.0)
			if not is_equal_approx(c, nc):
				GameState.cleanliness[GameState.active_tank] = nc
				Events.water_quality_changed.emit(GameState.active_tank, nc)
		if eaten or entry["age"] > FOOD_LIFETIME:
			node.queue_free()
			_food.remove_at(i)

# --- Input: click the water to feed there ---

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var drop := _project_click_into_tank(event.position)
		if drop != Vector3.INF:
			_spawn_food(drop)

func _project_click_into_tank(screen_pos: Vector2) -> Vector3:
	if _camera == null:
		return Vector3.INF
	var from := _camera.project_ray_origin(screen_pos)
	var dir := _camera.project_ray_normal(screen_pos)
	# Intersect the ray with the tank's mid-depth plane (z = center.z).
	var center := _bounds.position + _bounds.size * 0.5
	if absf(dir.z) < 0.0001:
		return Vector3.INF
	var t := (center.z - from.z) / dir.z
	if t <= 0.0:
		return Vector3.INF
	var hit := from + dir * t
	if _bounds.has_point(hit):
		return Vector3(hit.x, _bounds.end.y - 0.1, hit.z)
	return Vector3.INF
