class_name TankSetting
extends RefCounted
## Builds the room/setting around a tank and tunes the environment per stage, so each tank
## feels like a different place:
##   bowl (0)       -> a cozy wooden DESK in a warm room
##   freshwater (1) -> a LIVING ROOM console with a carpet and a window
##   reef (2)       -> a grand, dark DISPLAY HALL with dramatic lighting
## All geometry is parented into the tank root (rebuilt on tank switch). Walls sit behind /
## beside the tank so they never block the front camera.

# --- Environment mood ---

static func apply_environment(env: Environment, sun: DirectionalLight3D, tank_type: int) -> void:
	match tank_type:
		0:  # Desk — warm and cozy
			env.background_color = Color(0.18, 0.14, 0.11)
			env.ambient_light_color = Color(0.96, 0.88, 0.76)
			env.ambient_light_energy = 1.4
			env.fog_enabled = true
			env.fog_light_color = Color(0.35, 0.34, 0.32)
			env.fog_density = 0.008
			sun.light_color = Color(1.0, 0.94, 0.84)
			sun.light_energy = 1.6
			sun.rotation_degrees = Vector3(-50, -35, 0)
		1:  # Living room — warm neutral, homely
			env.background_color = Color(0.14, 0.13, 0.13)
			env.ambient_light_color = Color(0.88, 0.84, 0.8)
			env.ambient_light_energy = 1.3
			env.fog_enabled = true
			env.fog_light_color = Color(0.3, 0.32, 0.34)
			env.fog_density = 0.01
			sun.light_color = Color(1.0, 0.92, 0.82)
			sun.light_energy = 1.5
			sun.rotation_degrees = Vector3(-45, -25, 0)
		_:  # Reef — moody display hall, but lit enough to read the room/furniture
			env.background_color = Color(0.05, 0.07, 0.11)
			env.ambient_light_color = Color(0.55, 0.68, 0.82)
			env.ambient_light_energy = 2.1
			env.fog_enabled = true
			env.fog_light_color = Color(0.12, 0.22, 0.32)
			env.fog_density = 0.006
			sun.light_color = Color(0.82, 0.9, 1.0)
			sun.light_energy = 2.2
			sun.rotation_degrees = Vector3(-60, -20, 0)

# --- Room geometry ---

static func build_room(parent: Node3D, tank_type: int, bounds: AABB) -> void:
	match tank_type:
		0:
			_build_desk(parent, bounds)
		1:
			_build_living_room(parent, bounds)
		_:
			_build_display_hall(parent, bounds)

static func _build_desk(parent: Node3D, bounds: AABB) -> void:
	var c := bounds.position + bounds.size * 0.5
	var base_y := bounds.position.y
	var desk_cz := c.z + 0.2
	var top_half_x := (bounds.size.x + 2.4) * 0.5
	var top_half_z := (bounds.size.z + 1.8) * 0.5

	# --- Room shell: a cozy enclosed room (floor + back wall + two side walls + ceiling). The
	# front is open — that's the wall the camera looks in through. This is the player's FIRST view
	# of the game, so it has to read as a real room, not a single wall floating in a grey void. ---
	var room_hx := 6.6
	# Extra depth behind the tank so a full-height bookcase can stand against the back wall without
	# punching through the tank glass or the desk.
	var back_z := c.z - bounds.size.z * 0.5 - 2.6
	var front_z := 5.2
	var floor_y := base_y - 2.4
	var ceil_y := base_y + 4.1
	var room_cz := (back_z + front_z) * 0.5
	var room_dz := front_z - back_z
	var wall_h := ceil_y - floor_y
	var wall_cy := (ceil_y + floor_y) * 0.5
	var wall_col := Color(0.86, 0.78, 0.66)
	_surf(parent, Vector3(room_hx * 2.0, 0.2, room_dz), Vector3(c.x, floor_y, room_cz), Color(0.46, 0.31, 0.19), 0.9)
	_surf(parent, Vector3(room_hx * 2.0, wall_h, 0.3), Vector3(c.x, wall_cy, back_z), wall_col, 0.95)
	_surf(parent, Vector3(0.3, wall_h, room_dz), Vector3(c.x - room_hx, wall_cy, room_cz), wall_col, 0.95)
	_surf(parent, Vector3(0.3, wall_h, room_dz), Vector3(c.x + room_hx, wall_cy, room_cz), wall_col, 0.95)
	_surf(parent, Vector3(room_hx * 2.0, 0.3, room_dz), Vector3(c.x, ceil_y, room_cz), Color(0.9, 0.86, 0.78), 1.0)
	# Ceiling light: a visible glowing fixture + an omni below it (so the bright patch has a source
	# instead of an unexplained bloom on a bare ceiling).
	_ceiling_light(parent, Vector3(c.x, ceil_y - 0.18, room_cz - 0.6), 1.4, 16.0)
	# --- Real CC0 prop models (Poly Pizza) instead of flat boxes. ---
	# Oriental rug under the table (footprint-fitted so it lies flat).
	_place_prop_wide(parent, "Rug", Vector3(c.x, floor_y + 0.12, desk_cz), bounds.size.x + 4.0, 0.0)
	# Window on the LEFT wall, framed picture on the RIGHT wall — on the SIDE walls so the
	# transparent tank can never sit in front of them (the old "floating inside the bowl" bug).
	# These models are thin on X (flat face points ±X), so they hang FLUSH on the side walls with
	# yaw 0 (left wall, facing +X into the room) / PI (right wall, facing -X). A 90° turn would make
	# them jut out of the wall.
	# The picture HANGS (proud of the wall). The window is set almost FLUSH into the wall (only just
	# proud) so it reads as a window, not a hung frame.
	var rwx := c.x + room_hx - 0.18
	_place_prop(parent, "Window", Vector3(c.x - room_hx + 0.15, base_y + 0.5, desk_cz - 0.2), 2.0, 0.0)
	_place_prop(parent, "Painting", Vector3(rwx, base_y + 1.05, desk_cz - 0.1), 0.85, PI)

	# --- Furniture: the desk the bowl rests on, its four legs, desk clutter, and floor pieces. ---
	_surf(parent, Vector3(bounds.size.x + 2.4, 0.22, bounds.size.z + 1.8), Vector3(c.x, base_y - 0.11, desk_cz), Color(0.5, 0.33, 0.18), 0.7)
	var desktop_bottom := base_y - 0.22
	var leg_h := desktop_bottom - floor_y
	var leg_cy := (desktop_bottom + floor_y) * 0.5
	for lx in [-1.0, 1.0]:
		for lz in [-1.0, 1.0]:
			_slab(parent, Vector3(0.18, leg_h, 0.18), Vector3(c.x + (top_half_x - 0.4) * lx, leg_cy, desk_cz + (top_half_z - 0.4) * lz), Color(0.42, 0.27, 0.14), 0.7)
	# Desk clutter, BESIDE the tank (glass spans ±glass_half_x), never inside it.
	var glass_half_x := (bounds.size.x + 0.6) * 0.5
	_place_prop(parent, "BookStack", Vector3(c.x - glass_half_x - 0.5, base_y, c.z + 0.55), 0.42, PI * 0.5)
	_place_prop(parent, "CoffeeCup", Vector3(c.x + glass_half_x + 0.45, base_y, c.z + 0.6), 0.4, PI)
	_place_prop(parent, "FlowerPot", Vector3(c.x + glass_half_x + 0.55, base_y, c.z - 0.5), 0.8, PI)
	# Floor pieces: a full-height bookcase against the back wall (a real bookcase nearly reaches the
	# ceiling — it shouldn't read as a tiny nightstand next to the books on the desk), and a leafy
	# house plant standing in the front-right corner where it isn't hidden under the table.
	_place_prop(parent, "Bookcase", Vector3(c.x, floor_y + 0.1, back_z + 0.7), 5.6, 0.0)
	# Potted plants lined up along the LEFT wall, under the window (yaw 90° so the row of pots runs
	# along the wall instead of poking out toward the camera).
	_place_prop(parent, "HousePlant", Vector3(c.x - room_hx + 0.8, floor_y + 0.1, c.z), 1.3, PI * 0.5)
	# A tall standing floor lamp in the back-right corner, where a real standing lamp would go.
	_place_prop(parent, "Lamp", Vector3(c.x + room_hx - 0.8, floor_y + 0.1, back_z + 0.8), 3.1, PI)

static func _build_living_room(parent: Node3D, bounds: AABB) -> void:
	var c := bounds.position + bounds.size * 0.5
	var base_y := bounds.position.y

	# --- Enclosed living room shell (floor + back + 2 side walls + ceiling), same approach as the
	# bowl's desk room so the tank sits in a real room rather than against a single wall. ---
	var room_hx := 9.5
	# Extra depth behind the tank so a full-height bookcase can stand centred on the back wall
	# without punching through the console or tank (same as the bowl room).
	var back_z := c.z - bounds.size.z * 0.5 - 2.4
	var front_z := 8.0
	var floor_y := base_y - 1.35
	var ceil_y := base_y + 4.6
	var room_cz := (back_z + front_z) * 0.5
	var room_dz := front_z - back_z
	var wall_h := ceil_y - floor_y
	var wall_cy := (ceil_y + floor_y) * 0.5
	var wall_col := Color(0.66, 0.6, 0.54)
	_surf(parent, Vector3(room_hx * 2.0, 0.2, room_dz), Vector3(c.x, floor_y, room_cz), Color(0.42, 0.34, 0.33), 1.0)
	_surf(parent, Vector3(room_hx * 2.0, wall_h, 0.3), Vector3(c.x, wall_cy, back_z), wall_col, 0.95)
	_surf(parent, Vector3(0.3, wall_h, room_dz), Vector3(c.x - room_hx, wall_cy, room_cz), wall_col, 0.95)
	_surf(parent, Vector3(0.3, wall_h, room_dz), Vector3(c.x + room_hx, wall_cy, room_cz), wall_col, 0.95)
	_surf(parent, Vector3(room_hx * 2.0, 0.3, room_dz), Vector3(c.x, ceil_y, room_cz), Color(0.88, 0.84, 0.78), 1.0)
	_ceiling_light(parent, Vector3(c.x, ceil_y - 0.18, room_cz - 1.5), 2.0, 26.0)

	# Dark-wood console cabinet under the tank (the stand it rests on).
	_surf(parent, Vector3(bounds.size.x + 1.8, 1.3, bounds.size.z + 1.2),
		Vector3(c.x, base_y - 0.65, c.z), Color(0.32, 0.21, 0.13), 0.6)

	# Window + framed picture on the side walls (clear of the tank).
	# Thin-on-X models hang flush with yaw 0 (left wall) / PI (right wall) — see _build_desk note.
	var lwx := c.x - room_hx + 0.18
	var rwx := c.x + room_hx - 0.18
	_place_prop(parent, "Window", Vector3(lwx, base_y + 0.9, c.z - 0.2), 2.4, 0.0)
	_place_prop(parent, "Painting", Vector3(rwx, base_y + 1.6, c.z - 0.4), 1.0, PI)

	# Furniture (real CC0 models): couch + armchair framing the front on a rug, bookcase + plant +
	# lamp around the edges. Floor top ≈ floor_y + 0.1.
	var fy := floor_y + 0.1
	_place_prop_wide(parent, "Rug", Vector3(c.x, fy + 0.02, c.z + bounds.size.z * 0.5 + 1.8), bounds.size.x + 2.0, 0.0)
	_place_prop(parent, "Couch", Vector3(c.x - bounds.size.x * 0.62, fy, c.z + bounds.size.z * 0.5 + 2.4), 2.0, PI * 0.8)
	_place_prop(parent, "Armchair", Vector3(c.x + bounds.size.x * 0.66, fy, c.z + bounds.size.z * 0.5 + 2.3), 1.9, -PI * 0.8)
	# Bookcase centred on the back wall; a tall standing lamp in each back corner.
	_place_prop(parent, "Bookcase", Vector3(c.x, fy, back_z + 0.7), 5.2, 0.0)
	_place_prop(parent, "Lamp", Vector3(c.x - room_hx + 1.0, fy, back_z + 0.8), 3.1, PI)
	_place_prop(parent, "Lamp", Vector3(c.x + room_hx - 1.0, fy, back_z + 0.8), 3.1, PI)

static func _build_display_hall(parent: Node3D, bounds: AABB) -> void:
	var c := bounds.position + bounds.size * 0.5
	var base_y := bounds.position.y
	# Black plinth the big tank stands on.
	_slab(parent, Vector3(bounds.size.x + 2.0, 1.6, bounds.size.z + 1.6),
		Vector3(c.x, base_y - 0.8, c.z), Color(0.05, 0.05, 0.07), 0.4)
	# Gallery floor — deep slate blue (lifted from near-black so the room reads).
	_surf(parent, Vector3(bounds.size.x + 22, 0.2, bounds.size.z + 16),
		Vector3(c.x, base_y - 1.6, c.z + 3.0), Color(0.16, 0.18, 0.22), 0.5)
	# Walls — back + two sides — wider apart so there's room around the exhibit, lit enough to read.
	_surf(parent, Vector3(bounds.size.x + 22, bounds.size.y + 12, 0.3),
		Vector3(c.x, base_y + 3.0, c.z - bounds.size.z * 0.5 - 2.0), Color(0.12, 0.15, 0.22), 0.9)
	_surf(parent, Vector3(0.3, bounds.size.y + 12, bounds.size.z + 14),
		Vector3(c.x - bounds.size.x * 0.5 - 4.5, base_y + 3.0, c.z), Color(0.12, 0.15, 0.22), 0.9)
	_surf(parent, Vector3(0.3, bounds.size.y + 12, bounds.size.z + 14),
		Vector3(c.x + bounds.size.x * 0.5 + 4.5, base_y + 3.0, c.z), Color(0.12, 0.15, 0.22), 0.9)
	# Dramatic cool spotlights from above-front.
	for sx in [-0.3, 0.3]:
		var spot := SpotLight3D.new()
		spot.position = Vector3(c.x + bounds.size.x * sx, bounds.end.y + 1.6, c.z + bounds.size.z * 0.5 + 1.0)
		spot.look_at_from_position(spot.position, Vector3(c.x + bounds.size.x * sx * 0.5, c.y, c.z), Vector3.UP)
		spot.light_color = Color(0.6, 0.85, 1.0)
		spot.light_energy = 4.0
		spot.spot_range = bounds.size.length() * 2.0
		spot.spot_angle = 35.0
		spot.shadow_enabled = true
		parent.add_child(spot)
	# Ceiling so the hall is fully enclosed (no grey void overhead).
	_surf(parent, Vector3(bounds.size.x + 22, 0.3, bounds.size.z + 16),
		Vector3(c.x, base_y + 5.6, c.z + 3.0), Color(0.10, 0.12, 0.17), 0.9)
	# A row of gallery benches in front of the exhibit for "visitors". Floor top ≈ base_y-1.5.
	var bench_z := c.z + bounds.size.z * 0.5 + 3.0
	for bx in [-4.4, 0.0, 4.4]:
		_place_prop(parent, "Bench", Vector3(c.x + bx, base_y - 1.5, bench_z), 1.1, PI)
	# Framed exhibit art on the side walls, each lit by its own warm accent lamp so it reads in the
	# dark. Paintings are thin on X → they sit flat on the side walls facing inward.
	var hall_hx := bounds.size.x * 0.5 + 4.5
	for sx in [-1.0, 1.0]:
		var px: float = c.x + (hall_hx - 0.2) * sx
		# Hang flush on each side wall: left wall faces +X (yaw 0), right wall faces -X (yaw PI).
		var pyaw: float = PI if sx > 0.0 else 0.0
		_place_prop(parent, "Painting", Vector3(px, base_y + 1.3, c.z + 0.5), 1.3, pyaw)
		var accent := OmniLight3D.new()
		accent.position = Vector3(px - 0.8 * sx, base_y + 1.8, c.z + 0.5)
		accent.light_color = Color(1.0, 0.9, 0.7)
		accent.light_energy = 2.0
		accent.omni_range = 4.0
		parent.add_child(accent)

# A flush ceiling light: a glowing fixture panel with an OmniLight just beneath it, so the lit
# patch on the ceiling reads as a real fixture rather than an unexplained bloom.
static func _ceiling_light(parent: Node3D, pos: Vector3, size: float, range_m: float) -> void:
	var panel := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(size, 0.12, size)
	panel.mesh = box
	panel.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.96, 0.86)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.93, 0.78)
	mat.emission_energy_multiplier = 2.2
	panel.material_override = mat
	parent.add_child(panel)
	var omni := OmniLight3D.new()
	omni.position = pos - Vector3(0, 0.35, 0)
	omni.light_color = Color(1.0, 0.92, 0.78)
	omni.light_energy = 2.0
	omni.omni_range = range_m
	omni.shadow_enabled = true
	parent.add_child(omni)

# --- props ---

## Load a furniture .glb, scale it to `target_h` metres tall, sit its base on the floor with
## its footprint centred at `base_pos`, and face it by `yaw`. Skips silently if the asset is
## missing so the setting still builds. A holder node does the place/rotate so centring stays
## correct after rotation.
static func _place_prop(parent: Node3D, model_name: String, base_pos: Vector3, target_h: float, yaw: float) -> void:
	var path := "res://assets/props/%s.glb" % model_name
	if not ResourceLoader.exists(path):
		return
	var scene := load(path) as PackedScene
	if scene == null:
		return
	var holder := Node3D.new()
	parent.add_child(holder)
	var inst := scene.instantiate() as Node3D
	holder.add_child(inst)
	var aabb := _model_aabb(inst)
	if aabb.size.y < 0.0001:
		return
	var s := target_h / aabb.size.y
	inst.scale = Vector3(s, s, s)
	# Centre the footprint on X/Z and drop the base to y=0 within the holder.
	inst.position = Vector3(
		-(aabb.position.x + aabb.size.x * 0.5) * s,
		-aabb.position.y * s,
		-(aabb.position.z + aabb.size.z * 0.5) * s)
	holder.position = base_pos
	holder.rotation.y = yaw

## Like _place_prop, but scales to a target horizontal FOOTPRINT (max of width/depth) instead of
## height — for flat things like rugs where height-based scaling would blow them up or flatten them.
static func _place_prop_wide(parent: Node3D, model_name: String, base_pos: Vector3, target_w: float, yaw: float) -> void:
	var path := "res://assets/props/%s.glb" % model_name
	if not ResourceLoader.exists(path):
		return
	var scene := load(path) as PackedScene
	if scene == null:
		return
	var holder := Node3D.new()
	parent.add_child(holder)
	var inst := scene.instantiate() as Node3D
	holder.add_child(inst)
	var aabb := _model_aabb(inst)
	var foot := maxf(aabb.size.x, aabb.size.z)
	if foot < 0.0001:
		return
	var s := target_w / foot
	inst.scale = Vector3(s, s, s)
	inst.position = Vector3(
		-(aabb.position.x + aabb.size.x * 0.5) * s,
		-aabb.position.y * s,
		-(aabb.position.z + aabb.size.z * 0.5) * s)
	holder.position = base_pos
	holder.rotation.y = yaw

static func _model_aabb(node: Node) -> AABB:
	var out := AABB()
	var seen := false
	for c in node.get_children():
		var a := _accumulate_aabb(c, Transform3D.IDENTITY)
		if a.size == Vector3.ZERO:
			continue
		out = a if not seen else out.merge(a)
		seen = true
	return out

static func _accumulate_aabb(node: Node, parent_xform: Transform3D) -> AABB:
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

# --- helper ---

static func _slab(parent: Node3D, size: Vector3, pos: Vector3, color: Color, rough: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	m.mesh = box
	m.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	m.material_override = mat
	parent.add_child(m)
	return m

# A subtle procedural "mottle" so big flat surfaces (walls, floors, ceilings) read as painted
# plaster / real wood instead of dead-flat plastic. Brightness only varies ~0.82..1.0, world-space
# triplanar so it never stretches on a box and tiles consistently across rooms. Cached once.
static var _mottle: NoiseTexture2D

static func _mottle_tex() -> NoiseTexture2D:
	if _mottle == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.7
		n.fractal_octaves = 3
		var t := NoiseTexture2D.new()
		t.width = 256
		t.height = 256
		t.seamless = true
		# Gentle large-scale variation (~0.74..1.0) — visible as plaster/wood, not grime.
		var ramp := Gradient.new()
		ramp.set_color(0, Color(0.74, 0.74, 0.74))
		ramp.set_color(1, Color(1.0, 1.0, 1.0))
		t.color_ramp = ramp
		t.noise = n
		_mottle = t
	return _mottle

## Like _slab, but with the subtle mottle texture — use for walls / floors / ceilings.
static func _surf(parent: Node3D, size: Vector3, pos: Vector3, color: Color, rough: float) -> MeshInstance3D:
	var m := _slab(parent, size, pos, color, rough)
	var mat := m.material_override as StandardMaterial3D
	mat.albedo_texture = _mottle_tex()
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3(0.18, 0.18, 0.18)
	return m
