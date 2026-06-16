extends Node3D
## Entry point. Spawns the Aquarium (3D world) and the HUD, and seeds a friendly starter
## fish on a brand-new save so the bowl is never empty on first launch.

func _ready() -> void:
	add_child(Aquarium.new())
	add_child(AquariumHUD.new())
	_seed_starter_fish()
	if not GameState.tips_seen:
		GameState.tips_seen = true
		# Open the full How-to-Play guide on the very first launch (a real panel the player can
		# read at their own pace and re-open later via ❔), then a couple of gentle nudges.
		await get_tree().create_timer(0.6).timeout
		Events.help_requested.emit()
		_show_first_run_tips()

func _seed_starter_fish() -> void:
	# Only on a fresh game (no save was loaded → bowl still empty).
	if GameState.fish_count("bowl") == 0 and not SaveManager.has_save():
		GameState.add_fish("goldfish", "bowl")
		GameState.add_fish("goldfish", "bowl")
		Toasts.show_toast("Welcome to PolyQuarium! Meet your two goldfish 🐟🐟")

## Staggered, readable hints — only on the very first play (persisted via GameState.tips_seen).
func _show_first_run_tips() -> void:
	await get_tree().create_timer(1.2).timeout
	Toasts.show_toast("👆 Click the water to drop food — or tap 🍤 Feed", Color(0.8, 0.95, 1.0))
	await get_tree().create_timer(2.6).timeout
	Toasts.show_toast("😊 Happy fish earn 🪙 — spend it in the 🛒 Shop", Color(1.0, 0.9, 0.6))
	await get_tree().create_timer(2.6).timeout
	Toasts.show_toast("🧽 Keep the water clean and your fish will thrive", Color(0.7, 1.0, 0.8))
