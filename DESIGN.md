# PolyQuarium — design

A cozy 3D aquarium care-sim. Keep fish, feed them, keep the water nice, earn coins,
and grow from a humble goldfish bowl to a vibrant saltwater reef.

**Engine:** Godot 4.7 (RC). **Models:** Quaternius *Animated Fish Bundle* (CC0).

## Core loop
Fish gain hunger over time and lose happiness when hungry or in dirty water. Happy,
well-fed fish periodically **drip coins**. Spend coins on **food** (free action for now),
new **fish**, **decor**, and **unlocking** the next tank. Cleanliness slowly fouls with
more fish and is restored by the Clean action.

**Non-lethal house rule:** neglect only dulls a fish's colour and mood — fish never die.

## Progression (3 tanks)
| Tank | Capacity | Unlock | Fish |
|------|----------|--------|------|
| Goldfish Bowl | 3 | owned | Goldfish, Blue Goldfish, Koi |
| Freshwater Community | 6 | 500🪙 | Tetra, Cardinal, Betta, Mandarin, Flower Horn, Armored Catfish |
| Saltwater Reef | 10 | 2500🪙 | Clownfish, Blue/Yellow Tang, Royal Gramma, Moorish Idol, Lionfish |

## Architecture
- **Autoload globals:** `Events` (signal bus), `GameState` (economy/tanks/fish — source of
  truth + save hydration), `FishDatabase` (species catalog), `SaveManager` (JSON autosave),
  `Toasts` (notifications).
- **World:** `Aquarium` builds the active tank procedurally (glass, water, sand, lights,
  camera), spawns fish, runs feeding (click water to drop food) + cleanliness. `Fish` loads
  its `.glb` (auto-fit for the Quaternius 100x armature trap, autoplays swim anim) with a
  tinted-primitive fallback, wanders, gets hungry, eats, and earns coins.
- **UI:** `AquariumHUD` (coins, tank name + water meter, Feed/Clean/Shop, tank switcher),
  `Shop` (buy fish for the active tank type).

## Status
Core game complete and runnable. Pending verification on the 4.7 RC + Godot MCP repoint.
Next wave queued in `tickets/` (decor, water FX, fish info card, audio).
