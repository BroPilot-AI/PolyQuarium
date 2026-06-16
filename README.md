# 🐟 PolyQuarium

A cozy little 3D aquarium care-sim. Keep fish happy, keep the water clean, earn coins, and grow from a humble goldfish bowl to a grand saltwater reef. No fail-spiral, no stress — just a calm tank to tend.

Built in **Godot 4** with **GDScript** and free CC0 / CC-BY low-poly art.

---

## ✨ Features

- **Three tanks to grow into** — a **Goldfish Bowl** on a desk, a **Freshwater Community** in a living room, and a **Saltwater Reef** in a grand display hall. Each is a fully built, lit room of its own.
- **Living fish** — 15 species (real `.glb` models with swim animations) that get hungry, change mood, and earn you coins when content.
- **Care loop** — drop food by clicking the water (or the Feed button), and keep the water clean. Overfeeding leaves food rotting on the substrate and fouls the tank, so it's a gentle balancing act.
- **Breeding & genetics** — healthy same-species pairs breed, mixing Mendelian colour alleles; rare variants are worth more.
- **Quest-gated progression** — finish a tank's cozy quests to unlock the next tank, bought from the Shop's Tanks tab. Completing a quest throws a little **fireworks + fanfare** celebration.
- **Shop** — buy fish, decorations, and tanks; **sell** fish from their info card.
- **Substrate, decor & atmosphere** — per-tank gravel/sand, placeable decorations, plus water caustics, glass fresnel, god rays, surface ripple, and rising bubbles.
- **Fishpedia, quests panel, options & a How-to-Play guide**, with procedural sound effects and ambient audio.

## 🎮 How to play

| Action | How |
|--------|-----|
| **Feed** | Click the water where you want food, or tap **🍤 Feed** |
| **Clean** | Tap **🧽 Clean** when the water meter drops |
| **Sell a fish** | Click the fish → its card opens → **Sell** |
| **Shop / buy tanks** | **🛒 Shop** (Fish · Decor · Tanks tabs) |
| **Help** | **❔** opens the How-to-Play guide |

Happy, well-fed fish in clean water earn coins on their own. Spend them in the shop, complete quests, and work your way up to the reef.

## 🚀 Running it

1. Install **[Godot 4](https://godotengine.org/)** (developed on 4.7).
2. Open this folder as a project in the Godot editor, or run it directly:
   ```
   godot --path .
   ```
3. Press **Play**. The first launch opens a short How-to-Play guide.

The `.godot/` import cache is regenerated automatically on first open and is intentionally not tracked.

## 🎨 Credits & licensing

All art is free low-poly content:

- **Fish** — Quaternius *Animated Fish* bundle (CC0).
- **Decor & props** — a mix of **Quaternius (CC0)** and **Poly Pizza** contributors (**CC-BY 3.0**, attribution required).

Per-asset sources, authors, and licenses are listed in:

- `assets/fish/CREDITS.md`
- `assets/decor/CREDITS.md`
- `assets/props/CREDITS.md`

CC-BY assets require keeping that attribution. The game code is © its author.
