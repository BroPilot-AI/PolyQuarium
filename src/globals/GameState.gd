extends Node
## Single source of truth for PolyQuarium: economy, tank ownership, and the fish living
## in each tank. Mutations go through the methods here, which emit on Events so the HUD
## and world stay in sync. Persisted verbatim by SaveManager.

# Tank catalog. `type` matches FishDatabase.TankType (BOWL=0, FRESHWATER=1, REEF=2) —
# spelled as literals here because a const can't reference another autoload's enum.
# `unlock_price` of 0 means owned from the start. `capacity` caps fish; `decor_slots` decor.
const TANKS := {
	"bowl":       {"name": "Goldfish Bowl",       "type": 0, "capacity": 3,  "decor_slots": 2, "unlock_price": 0},
	"freshwater": {"name": "Freshwater Community", "type": 1, "capacity": 6,  "decor_slots": 5, "unlock_price": 500},
	"reef":       {"name": "Saltwater Reef",       "type": 2, "capacity": 10, "decor_slots": 8, "unlock_price": 2500},
}

const STARTING_COINS := 150

# Quests you must finish before a tank can be bought — you "level up" by completing the current
# tier's goals, not just by hoarding coins. Quest ids come from QuestManager.QUESTS.
const TANK_PREREQS := {
	"freshwater": ["first_sale", "full_bowl"],
	"reef": ["gold_5", "decorator"],
}

var coins: int = STARTING_COINS
var active_tank: String = "bowl"
var unlocked_tanks: Array[String] = ["bowl"]
# tank_id -> Array[Dictionary] of fish records {id:int, species:String, happiness:float, hunger:float}
var fish: Dictionary = {"bowl": [], "freshwater": [], "reef": []}
# tank_id -> float in [0,1]; 1.0 is pristine water.
var cleanliness: Dictionary = {"bowl": 1.0, "freshwater": 1.0, "reef": 1.0}
# tank_id -> Array[Dictionary] of decor records {id:int, decor_id:String}
var decor: Dictionary = {"bowl": [], "freshwater": [], "reef": []}

var _next_fish_id: int = 1
var _next_decor_id: int = 1
var tips_seen: bool = false   # first-run hints shown once, then persisted
# --- Quest tracking (see QuestManager) ---
var stats: Dictionary = {}            # cumulative counters, e.g. {"sold_goldfish": 3, "earned_total": 540}
var species_seen: Array[String] = []  # every species ever owned (for collection quests)
var quests_done: Array[String] = []   # completed quest ids

func bump_stat(key: String, amount: int = 1) -> void:
	stats[key] = int(stats.get(key, 0)) + amount

func mark_species_seen(id: String) -> void:
	if not species_seen.has(id):
		species_seen.append(id)

# --- Economy ---

func can_afford(amount: int) -> bool:
	return coins >= amount

func add_coins(amount: int, world_pos: Vector3 = Vector3.ZERO) -> void:
	if amount <= 0:
		return
	coins += amount
	Events.coins_earned.emit(amount, world_pos)
	Events.coins_changed.emit(coins)

func spend_coins(amount: int) -> bool:
	if amount < 0 or coins < amount:
		return false
	coins -= amount
	Events.coins_changed.emit(coins)
	return true

# --- Tanks ---

func tank_data(tank_id: String) -> Dictionary:
	return (TANKS[tank_id] as Dictionary).duplicate(true) if TANKS.has(tank_id) else {}

func is_unlocked(tank_id: String) -> bool:
	return unlocked_tanks.has(tank_id)

## Quest ids still needed before `tank_id` can be unlocked (empty == all prerequisites met).
func missing_prereqs(tank_id: String) -> Array:
	var out: Array = []
	for qid in TANK_PREREQS.get(tank_id, []):
		if not quests_done.has(qid):
			out.append(qid)
	return out

func prereqs_met(tank_id: String) -> bool:
	return missing_prereqs(tank_id).is_empty()

func unlock_tank(tank_id: String) -> bool:
	if not TANKS.has(tank_id) or is_unlocked(tank_id):
		return false
	if not prereqs_met(tank_id):
		return false
	var cost := int(TANKS[tank_id]["unlock_price"])
	if not spend_coins(cost):
		return false
	# New array (immutable-style update). duplicate() keeps the Array[String] typing —
	# `unlocked_tanks + [tank_id]` would produce an untyped Array and fail to assign back.
	var updated := unlocked_tanks.duplicate()
	updated.append(tank_id)
	unlocked_tanks = updated
	Events.tank_unlocked.emit(tank_id)
	return true

func set_active_tank(tank_id: String) -> void:
	if not is_unlocked(tank_id) or active_tank == tank_id:
		return
	active_tank = tank_id
	Events.tank_changed.emit(tank_id)

func capacity_of(tank_id: String) -> int:
	return int(TANKS.get(tank_id, {}).get("capacity", 0))

func fish_count(tank_id: String) -> int:
	return (fish.get(tank_id, []) as Array).size()

func has_room(tank_id: String) -> bool:
	return fish_count(tank_id) < capacity_of(tank_id)

# --- Fish ---

func add_fish(species_id: String, tank_id: String, genome: Array = [], age: float = -1.0) -> int:
	# Returns the new fish id, or -1 if it couldn't be added. genome [] -> common default.
	# Default age = -1.0 means adult (grow time completed). Fry passed as 0.0.
	if not FishDatabase.has_species(species_id) or not has_room(tank_id):
		return -1
	var id := _next_fish_id
	_next_fish_id += 1
	var g: Array = genome if genome.size() == 2 else FishGenetics.default_genome()
	var fish_age: float = 999.0 if age < 0.0 else age   # <0 sentinel = adult; fry passes 0.0
	var record := {"id": id, "species": species_id, "happiness": 0.8, "hunger": 0.3, "health": 1.0, "genome": g, "age": fish_age}
	(fish[tank_id] as Array).append(record)
	Events.fish_added.emit(species_id, tank_id)
	return id

func remove_fish(tank_id: String, fish_id: int) -> void:
	var arr: Array = fish.get(tank_id, [])
	for i in arr.size():
		if int(arr[i]["id"]) == fish_id:
			arr.remove_at(i)
			Events.fish_removed.emit(fish_id)
			return

# --- Decor ---

func decor_count(tank_id: String) -> int:
	return (decor.get(tank_id, []) as Array).size()

func has_decor_room(tank_id: String) -> bool:
	var slots: int = int(TANKS.get(tank_id, {}).get("decor_slots", 0))
	return decor_count(tank_id) < slots

func add_decor(decor_id: String, tank_id: String) -> int:
	# Returns the new decor id, or -1 if it couldn't be added.
	if not DecorDatabase.has_decor(decor_id) or not has_decor_room(tank_id):
		return -1
	# Check tank filter: -1 means any tank, otherwise must match.
	var filter: int = int(DecorDatabase.CATALOG[decor_id]["tank"])
	var tank_type: int = int(tank_data(tank_id).get("type", 0))
	if filter != -1 and filter != tank_type:
		return -1
	if not spend_coins(DecorDatabase.price(decor_id)):
		return -1
	var id := _next_decor_id
	_next_decor_id += 1
	var record := {"id": id, "decor_id": decor_id}
	(decor[tank_id] as Array).append(record)
	Events.decor_added.emit(decor_id, tank_id)
	return id

# --- Save hydration ---

func to_dict() -> Dictionary:
	return {
		"coins": coins,
		"active_tank": active_tank,
		"unlocked_tanks": unlocked_tanks.duplicate(),
		"fish": fish.duplicate(true),
		"cleanliness": cleanliness.duplicate(true),
		"decor": decor.duplicate(true),
		"next_fish_id": _next_fish_id,
		"next_decor_id": _next_decor_id,
		"tips_seen": tips_seen,
		"stats": stats.duplicate(true),
		"species_seen": species_seen.duplicate(),
		"quests_done": quests_done.duplicate(),
	}

func from_dict(data: Dictionary) -> void:
	coins = int(data.get("coins", STARTING_COINS))
	active_tank = String(data.get("active_tank", "bowl"))
	var ut: Array = data.get("unlocked_tanks", ["bowl"])
	unlocked_tanks = []
	for t in ut:
		unlocked_tanks.append(String(t))
	fish = (data.get("fish", {}) as Dictionary).duplicate(true)
	cleanliness = (data.get("cleanliness", {}) as Dictionary).duplicate(true)
	decor = (data.get("decor", {}) as Dictionary).duplicate(true)
	# Backfill any tank keys an older save predates, so per-tank lookups never KeyError.
	for tk: String in TANKS:
		if not fish.has(tk):
			fish[tk] = []
		if not decor.has(tk):
			decor[tk] = []
		if not cleanliness.has(tk):
			cleanliness[tk] = 1.0
	_next_fish_id = int(data.get("next_fish_id", 1))
	_next_decor_id = int(data.get("next_decor_id", 1))
	tips_seen = bool(data.get("tips_seen", false))
	stats = (data.get("stats", {}) as Dictionary).duplicate(true)
	species_seen = []
	for s in data.get("species_seen", []):
		species_seen.append(String(s))
	quests_done = []
	for q in data.get("quests_done", []):
		quests_done.append(String(q))
	Events.coins_changed.emit(coins)
	Events.game_loaded.emit()
