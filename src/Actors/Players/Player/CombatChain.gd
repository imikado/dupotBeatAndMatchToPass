class_name CombatChain
extends RefCounted

const LIGHT := "R"
const HEAVY := "H"
# un appui anticipé reste valable ce temps-là, puis il est oublié
const BUFFER_SECONDS := 0.30
const FLURRY_DURATION := 2.30
# rafale : sans nouvel appui pendant ce délai, elle s'interrompt
const MASH_WINDOW := 0.40
const FLURRY_TIMES := [0, 0.06, 0.12, 0.19, 0.26, 0.31, 0.37, 0.43, 0.5, 0.56, 0.62, 0.68, 0.75, 0.81, 0.87, 0.94, 1.01, 1.07, 1.13, 1.2, 1.27, 1.33, 1.39, 1.46, 1.53, 1.59, 1.65, 1.72, 1.8, 1.88, 1.96, 2.09]
const FLURRY_HITS := [0.12, 0.37, 0.56, 0.87, 1.13, 1.33, 1.65, 1.96]
const CROSS_DURATION := 2.80
const CROSS_TIMES := [0, 0.05, 0.1, 0.16, 0.23, 0.4, 0.6, 0.76, 0.84, 0.89, 0.95, 1.02, 1.1, 1.34, 1.46, 1.58, 1.66, 1.71, 1.78, 1.84, 1.92, 2.12, 2.34, 2.52]
const CROSS_HITS := [0.1, 0.6, 0.95, 1.34, 1.71, 2.34]
const RECIPES := {
	"RRRR": "RAFALE",
	"RRH": "BRISE-GARDE",
	"RRRH": "EXECUTION",
	"RHR": "CONTRE-TAILLE",
	"RHH": "FENDOIR",
	"HRR": "RIPOSTE",
	"HRH": "CROISE",
	"HHR": "REVERS",
	"HHH": "FRACAS",
}


static func strike(sequence: String) -> Dictionary:
	var heavy := sequence.ends_with(HEAVY)
	var finisher := RECIPES.has(sequence)
	var result := {
		"heavy": heavy,
		"finisher": finisher,
		"label": RECIPES.get(sequence, ""),
		"damage": (36 if heavy else 18) if finisher else (24 if heavy else 8),
		"duration": (0.80 if finisher else 0.70) if heavy else (0.32 if finisher else 0.26),
		"impact": (0.38 / 0.70 * 0.80 if finisher else 0.38) if heavy else 0.17,
		"knockback": (24.0 if heavy else 16.0) if finisher else (12.0 if heavy else 4.0),
		"lunge": (7.0 if heavy else 5.0) if finisher else 4.0,
	}

	if finisher:
		if sequence == "RRRR":
			result.merge({"animation": "combo_flurry", "duration": FLURRY_DURATION, "hits": FLURRY_HITS, "damage": 8, "radius": Vector2(30, 13), "slam": false, "mash": true, "cuts": ["down", "sweep", "backsweep", "rise", "down", "rise_back", "down", "thrust"], "heavy_cuts": [false, false, false, false, false, false, false, false]}, true)
		elif sequence in ["RRH", "RRRH", "RHH", "HHH"]:
			var strongest := sequence == "RRRH"
			result.merge({"animation": "combo_slam", "duration": 1.05, "hits": [0.56], "damage": 64 if strongest else 48, "radius": Vector2(56, 25) if strongest else Vector2(44, 20), "slam": true, "knockback": 30.0, "lunge": 4.0}, true)
		else:
			result.merge({"animation": "combo_cross", "duration": CROSS_DURATION, "hits": CROSS_HITS, "damage": 10 if heavy else 8, "radius": Vector2(34, 15), "slam": false, "mash": true, "cuts": ["rise", "down", "sweep", "backsweep", "rise_back", "down"], "heavy_cuts": [false, true, false, true, false, true], "hit_damage": [10, 14, 10, 14, 10, 14] if heavy else [8, 12, 8, 12, 8, 12]}, true)
		result.impact = result.hits[0]
		var last_hit: float = result.hits[-1]
		result.cancel = minf(last_hit + (0.24 if result.slam else 0.16), result.duration)
		result.input_open = maxf(last_hit - 0.35, 0.0)
	else:
		result.cancel = minf(result.impact + (0.12 if heavy else 0.05), result.duration)
		result.input_open = 0.0
	return result
