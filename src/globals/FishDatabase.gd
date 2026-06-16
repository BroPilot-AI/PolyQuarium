extends Node
## Static species catalog for PolyQuarium. Pure data + lookups, no mutation of entries.
## Models are Quaternius "Animated Fish Bundle" (CC0) .glb files under res://assets/fish/.
## `model` is the basename; Fish.gd resolves it to a path and falls back to a tinted
## primitive when the asset is missing, so the game runs before assets land.

enum TankType { BOWL, FRESHWATER, REEF }

# Each species: display name, which tank it belongs to, price in coins, base swim
# speed (m/s), whether it schools, a fallback tint (used until the .glb is present),
# and the model basename (matches the bundle's glTF export, sans extension).
const SPECIES := {
	# --- Tank 1: Goldfish Bowl ---
	"goldfish":      {"name": "Goldfish",       "tank": TankType.BOWL,       "price": 2,    "speed": 0.8, "school": false, "tint": Color(1.0, 0.55, 0.1),  "model": "Goldfish"},
	"blue_goldfish": {"name": "Blue Goldfish",  "tank": TankType.BOWL,       "price": 60,   "speed": 0.8, "school": false, "tint": Color(0.3, 0.55, 0.95), "model": "BlueGoldfish"},
	"koi":           {"name": "Koi",            "tank": TankType.BOWL,       "price": 120,  "speed": 0.7, "school": false, "tint": Color(0.95, 0.75, 0.7), "model": "Koi"},

	# --- Tank 2: Freshwater Community ---
	"tetra":         {"name": "Tetra",          "tank": TankType.FRESHWATER, "price": 25,   "speed": 1.3, "school": true,  "tint": Color(0.6, 0.85, 1.0),  "model": "Tetra"},
	"cardinal":      {"name": "Cardinal Fish",  "tank": TankType.FRESHWATER, "price": 40,   "speed": 1.2, "school": true,  "tint": Color(0.85, 0.2, 0.3),  "model": "CardinalFish"},
	"betta":         {"name": "Betta",          "tank": TankType.FRESHWATER, "price": 90,   "speed": 0.6, "school": false, "tint": Color(0.7, 0.2, 0.8),   "model": "Betta"},
	"mandarin":      {"name": "Mandarin Fish",  "tank": TankType.FRESHWATER, "price": 150,  "speed": 0.7, "school": false, "tint": Color(0.2, 0.6, 0.9),   "model": "MandarinFish"},
	"flower_horn":   {"name": "Flower Horn",    "tank": TankType.FRESHWATER, "price": 200,  "speed": 0.7, "school": false, "tint": Color(1.0, 0.4, 0.3),   "model": "FlowerHorn"},
	"catfish":       {"name": "Armored Catfish","tank": TankType.FRESHWATER, "price": 110,  "speed": 0.5, "school": false, "tint": Color(0.4, 0.35, 0.3),  "model": "ArmoredCatfish"},

	# --- Tank 3: Saltwater Reef ---
	"clownfish":     {"name": "Clownfish",      "tank": TankType.REEF,       "price": 80,   "speed": 1.0, "school": false, "tint": Color(1.0, 0.5, 0.1),   "model": "Clownfish"},
	"blue_tang":     {"name": "Blue Tang",      "tank": TankType.REEF,       "price": 180,  "speed": 1.1, "school": false, "tint": Color(0.15, 0.35, 0.9), "model": "BlueTang"},
	"yellow_tang":   {"name": "Yellow Tang",    "tank": TankType.REEF,       "price": 170,  "speed": 1.1, "school": false, "tint": Color(1.0, 0.85, 0.1),  "model": "YellowTang"},
	"royal_gramma":  {"name": "Royal Gramma",   "tank": TankType.REEF,       "price": 140,  "speed": 1.0, "school": true,  "tint": Color(0.7, 0.3, 0.85),  "model": "RoyalGramma"},
	"moorish_idol":  {"name": "Moorish Idol",   "tank": TankType.REEF,       "price": 220,  "speed": 0.9, "school": false, "tint": Color(0.95, 0.9, 0.8),  "model": "MoorishIdol"},
	"lionfish":      {"name": "Lionfish",       "tank": TankType.REEF,       "price": 300,  "speed": 0.5, "school": false, "tint": Color(0.8, 0.3, 0.2),   "model": "Lionfish"},
}

const MODEL_DIR := "res://assets/fish/"

func has_species(id: String) -> bool:
	return SPECIES.has(id)

func get_species(id: String) -> Dictionary:
	# Returns a copy so callers can never mutate the catalog.
	return (SPECIES[id] as Dictionary).duplicate(true) if SPECIES.has(id) else {}

func species_name(id: String) -> String:
	return SPECIES.get(id, {}).get("name", id)

func price(id: String) -> int:
	return int(SPECIES.get(id, {}).get("price", 0))

func model_path(id: String) -> String:
	var m: String = SPECIES.get(id, {}).get("model", "")
	return MODEL_DIR + m + ".glb" if m != "" else ""

## All species ids that belong to a given tank type, in catalog order.
func species_for_tank(tank_type: int) -> Array[String]:
	var out: Array[String] = []
	for id: String in SPECIES:
		if int(SPECIES[id]["tank"]) == tank_type:
			out.append(id)
	return out
