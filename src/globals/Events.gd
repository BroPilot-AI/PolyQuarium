extends Node
## Global signal bus for PolyQuarium. Decouples systems: tanks, fish, HUD, shop, save.
## Nothing here holds state — it only relays. See GameState for the source of truth.

# --- Economy ---
signal coins_changed(total: int)
signal coins_earned(amount: int, world_pos: Vector3)   # for floating "+N" popups

# --- Fish lifecycle ---
signal fish_added(species_id: String, tank_id: String)
signal fish_removed(fish_id: int)
signal fish_died(fish_id: int, species_id: String, tank_id: String)
signal fish_sold(species_id: String, tank_id: String)
signal quest_completed(quest_id: String, title: String, reward: int)
signal fish_mood_changed(fish_id: int, happiness: float)
signal fish_fed(fish_id: int)
signal fish_clicked(fish_id: int, tank_id: String)

# --- Tank / water ---
signal tank_changed(tank_id: String)                    # player switched the active tank
signal tank_unlocked(tank_id: String)
signal water_quality_changed(tank_id: String, cleanliness: float)
signal food_dropped(world_pos: Vector3)

# --- Player actions (HUD -> world) ---
signal feed_requested
signal clean_requested
signal shop_open_requested
signal shop_close_requested
signal help_requested

# --- Decor ---
signal decor_added(decor_id: String, tank_id: String)

# --- Save ---
signal game_loaded
signal game_saved
