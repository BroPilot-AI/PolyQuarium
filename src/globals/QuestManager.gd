extends Node
## Cozy quests: gentle goals with coin rewards. Definitions live here; progress + completion
## persist in GameState (stats / species_seen / quests_done). Listens to gameplay events,
## updates counters, and awards quests the moment their goal is met. No fail states.

# kind:
#   "sell"        key=species_id   goal=N   -> sell N of a species
#   "own_in_tank" key=tank_id      goal=N   -> have N fish in a tank at once
#   "collect"     key=tank_type    goal=auto -> own every species of that tank type (ever)
#   "unlock"      key=tank_id      goal=1   -> unlock a tank
#   "decor_total" key=""           goal=N   -> place N decorations (across all tanks)
#   "earned"      key=""           goal=N   -> earn N coins total
const QUESTS := [
	{"id": "first_sale",   "kind": "sell",        "key": "goldfish",                    "goal": 1,  "reward": 20,  "title": "First Sale",        "desc": "Sell a goldfish"},
	{"id": "gold_5",       "kind": "sell",        "key": "goldfish",                    "goal": 5,  "reward": 60,  "title": "Goldfish Breeder",  "desc": "Sell 5 goldfish"},
	{"id": "gold_20",      "kind": "sell",        "key": "goldfish",                    "goal": 20, "reward": 250, "title": "Goldfish Tycoon",   "desc": "Sell 20 goldfish"},
	{"id": "full_bowl",    "kind": "own_in_tank", "key": "bowl",                        "goal": 3,  "reward": 50,  "title": "A Full Bowl",       "desc": "Have 3 fish in the bowl"},
	{"id": "home",         "kind": "unlock",      "key": "freshwater",                  "goal": 1,  "reward": 50,  "title": "Moving Up",         "desc": "Unlock the Freshwater tank"},
	{"id": "curator",      "kind": "unlock",      "key": "reef",                        "goal": 1,  "reward": 200, "title": "Grand Curator",     "desc": "Unlock the Saltwater Reef"},
	{"id": "decorator",    "kind": "decor_total", "key": "",                            "goal": 5,  "reward": 80,  "title": "Interior Designer", "desc": "Place 5 decorations"},
	{"id": "collect_fresh","kind": "collect",     "key": "1",                           "goal": 0, "reward": 300, "title": "Freshwater Collector", "desc": "Own every freshwater species"},
	{"id": "collect_reef", "kind": "collect",     "key": "2",                           "goal": 0, "reward": 600, "title": "Reef Collector",       "desc": "Own every reef species"},
	{"id": "nest_egg",     "kind": "earned",      "key": "",                            "goal": 1000, "reward": 100, "title": "Nest Egg",        "desc": "Earn 1000 coins total"},
	{"id": "geneticist",   "kind": "stat",        "key": "bred_rare",                   "goal": 1,  "reward": 150, "title": "Geneticist",        "desc": "Breed a rare colour variant"},
]

func _ready() -> void:
	Events.fish_sold.connect(_on_fish_sold)
	Events.fish_added.connect(_on_fish_added)
	Events.tank_unlocked.connect(func(_t): _evaluate())
	Events.decor_added.connect(func(_d, _t): _evaluate())
	Events.coins_earned.connect(_on_coins_earned)
	Events.game_loaded.connect(_evaluate)
	_evaluate()

func _on_fish_sold(species_id: String, _tank_id: String) -> void:
	GameState.bump_stat("sold_" + species_id, 1)
	_evaluate()

func _on_fish_added(species_id: String, _tank_id: String) -> void:
	GameState.mark_species_seen(species_id)
	_evaluate()

func _on_coins_earned(amount: int, _pos: Vector3) -> void:
	GameState.bump_stat("earned_total", amount)
	_evaluate()

## Current progress for a quest definition (clamped to its goal).
func progress(q: Dictionary) -> int:
	match String(q["kind"]):
		"sell":
			return int(GameState.stats.get("sold_" + String(q["key"]), 0))
		"own_in_tank":
			return GameState.fish_count(String(q["key"]))
		"unlock":
			return 1 if GameState.is_unlocked(String(q["key"])) else 0
		"decor_total":
			var n := 0
			for t in GameState.TANKS:
				n += GameState.decor_count(String(t))
			return n
		"earned":
			return int(GameState.stats.get("earned_total", 0))
		"stat":
			return int(GameState.stats.get(String(q["key"]), 0))
		"collect":
			var tank_type := int(String(q["key"]).to_int())
			var owned := 0
			for sp in FishDatabase.species_for_tank(tank_type):
				if GameState.species_seen.has(sp):
					owned += 1
			return owned
	return 0

## Goal value (collect quests derive theirs from the species count).
func goal_of(q: Dictionary) -> int:
	if String(q["kind"]) == "collect":
		return FishDatabase.species_for_tank(int(String(q["key"]).to_int())).size()
	return int(q["goal"])

func is_done(id: String) -> bool:
	return GameState.quests_done.has(id)

## Human-readable title for a quest id (for "Complete: …" gating hints). Falls back to the id.
func title_of(id: String) -> String:
	for q: Dictionary in QUESTS:
		if String(q["id"]) == id:
			return String(q["title"])
	return id

func _evaluate() -> void:
	for q: Dictionary in QUESTS:
		var id := String(q["id"])
		if is_done(id):
			continue
		if progress(q) >= goal_of(q):
			GameState.quests_done.append(id)
			var reward := int(q["reward"])
			GameState.add_coins(reward)
			Toasts.show_toast("✅ Quest complete: %s  +%d 🪙" % [q["title"], reward], Color(0.6, 1.0, 0.7))
			Events.quest_completed.emit(id, String(q["title"]), reward)
