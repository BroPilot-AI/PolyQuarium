extends Node
## Static decor catalog for PolyQuarium. Pure data + lookups, no mutation.
## Models are .glb files under res://assets/decor/ (may not exist yet —
## Aquarium.gd uses a tinted-primitive fallback when the asset is missing).
## `tank` is 0/1/2 matching FishDatabase.TankType, or -1 for any tank.

const CATALOG := {
	# --- Any tank ---
	"seaweed":     {"name": "Seaweed",     "price": 15,  "tank": -1, "model": "Seaweed",     "tint": Color(0.2, 0.7, 0.3)},
	"kelp":        {"name": "Kelp",        "price": 20,  "tank": -1, "model": "Kelp",        "tint": Color(0.15, 0.55, 0.25)},
	"rock":          {"name": "Rock",          "price": 10,  "tank": -1, "model": "Rock",          "tint": Color(0.45, 0.42, 0.38)},
	"driftwood":     {"name": "Driftwood",     "price": 25,  "tank": -1, "model": "Driftwood",     "tint": Color(0.55, 0.4, 0.25)},
	"treasure_chest":{"name": "Treasure Chest","price": 75,  "tank": -1, "model": "TreasureChest",  "tint": Color(0.6, 0.45, 0.2),  "front": true},
	"castle":        {"name": "Castle",        "price": 90,  "tank": -1, "model": "Castle",         "tint": Color(0.6, 0.6, 0.65),  "front": true},
	"anchor":        {"name": "Anchor",        "price": 45,  "tank": -1, "model": "Anchor",         "tint": Color(0.4, 0.42, 0.45),  "front": true},

	# --- Freshwater only (tank 1) ---
	"fresh_fern":  {"name": "Water Fern",    "price": 30,  "tank": 1,  "model": "FreshFern",   "tint": Color(0.25, 0.6, 0.3)},
	"cattail":     {"name": "Cattail Reeds", "price": 35,  "tank": 1,  "model": "Cattail",     "tint": Color(0.4, 0.55, 0.25)},
	"aqua_grass":  {"name": "Aquatic Grass", "price": 25,  "tank": 1,  "model": "AquaGrass",    "tint": Color(0.3, 0.65, 0.35)},

	# --- Reef only ---
	"coral_fan":   {"name": "Coral Fan",   "price": 40,  "tank": 2,  "model": "CoralFan",    "tint": Color(0.95, 0.35, 0.5)},
	"coral_brain": {"name": "Coral Brain", "price": 50,  "tank": 2,  "model": "CoralBrain",  "tint": Color(0.85, 0.75, 0.3)},
	"anemone":     {"name": "Anemone",     "price": 35,  "tank": 2,  "model": "Anemone",     "tint": Color(0.9, 0.4, 0.7)},
}

const MODEL_DIR := "res://assets/decor/"

func has_decor(id: String) -> bool:
	return CATALOG.has(id)

func get_decor(id: String) -> Dictionary:
	return (CATALOG[id] as Dictionary).duplicate(true) if CATALOG.has(id) else {}

func name_of(id: String) -> String:
	return CATALOG.get(id, {}).get("name", id)

func price(id: String) -> int:
	return int(CATALOG.get(id, {}).get("price", 0))

func model_path(id: String) -> String:
	var m: String = CATALOG.get(id, {}).get("model", "")
	return MODEL_DIR + m + ".glb" if m != "" else ""

## Returns decor ids available for a given tank type (includes tank==-1 entries).
func decor_for_tank(tank_type: int) -> Array[String]:
	var out: Array[String] = []
	for id: String in CATALOG:
		var t: int = int(CATALOG[id]["tank"])
		if t == -1 or t == tank_type:
			out.append(id)
	return out
