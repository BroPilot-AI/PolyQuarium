class_name FishGenetics
extends RefCounted
## Simple Mendelian colour genetics. Each fish carries two colour alleles; the most-dominant
## one is expressed (its phenotype). Breeding passes one random allele from each parent, with a
## small mutation chance — so rare recessive colours (white, black) emerge over generations and
## are worth more when sold. Pure logic, no state.

# allele -> colour it paints, dominance (higher shows over lower), and sell-value multiplier.
const ALLELES := {
	"O": {"color": Color(1.00, 0.55, 0.10), "dom": 2, "value": 1.0, "name": "Orange"},
	"Y": {"color": Color(1.00, 0.85, 0.15), "dom": 2, "value": 1.4, "name": "Golden"},
	"R": {"color": Color(0.85, 0.20, 0.20), "dom": 2, "value": 1.6, "name": "Red"},
	"B": {"color": Color(0.30, 0.50, 0.95), "dom": 1, "value": 2.2, "name": "Blue"},
	"W": {"color": Color(0.95, 0.95, 0.98), "dom": 0, "value": 3.0, "name": "White"},
	"K": {"color": Color(0.16, 0.16, 0.22), "dom": 0, "value": 4.0, "name": "Black"},
}
const MUTATION_CHANCE := 0.12
const POOL := ["O", "Y", "R", "B", "W", "K"]

static func default_genome() -> Array:
	return ["O", "O"]

## The expressed allele: highest dominance, ties broken by rarity (higher value shows).
static func phenotype(genome: Array) -> String:
	var best := "O"
	var best_dom := -1.0
	var best_val := -1.0
	for al in genome:
		var d := float(ALLELES.get(al, {}).get("dom", 0))
		var v := float(ALLELES.get(al, {}).get("value", 1.0))
		if d > best_dom or (is_equal_approx(d, best_dom) and v > best_val):
			best_dom = d
			best_val = v
			best = String(al)
	return best

static func color_of(genome: Array) -> Color:
	return ALLELES.get(phenotype(genome), {}).get("color", Color.WHITE)

static func value_mult(genome: Array) -> float:
	return float(ALLELES.get(phenotype(genome), {}).get("value", 1.0))

static func variant_name(genome: Array) -> String:
	return String(ALLELES.get(phenotype(genome), {}).get("name", "Common"))

## True when the expressed colour is one of the rare recessives.
static func is_rare(genome: Array) -> bool:
	return value_mult(genome) >= 2.2

## One allele from each parent, each with a small chance to mutate to anything in the pool.
static func cross(a: Array, b: Array, rng: RandomNumberGenerator) -> Array:
	var c1: String = String(a[rng.randi() % a.size()]) if a.size() > 0 else "O"
	var c2: String = String(b[rng.randi() % b.size()]) if b.size() > 0 else "O"
	if rng.randf() < MUTATION_CHANCE:
		c1 = POOL[rng.randi() % POOL.size()]
	if rng.randf() < MUTATION_CHANCE:
		c2 = POOL[rng.randi() % POOL.size()]
	return [c1, c2]
