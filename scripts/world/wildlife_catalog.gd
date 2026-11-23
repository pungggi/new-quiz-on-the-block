class_name WildlifeCatalog
extends RefCounted

## Ambient fauna for the meadows and the river. Every species entry
## drives BOTH the blocky mesh (LandAnimal._build_body) and the
## movement behavior (LandAnimal._process).
##
## movement: walk | hop | wade | swim | fly
## habitat:  grass | river  (spawn + wander target rules)
## ears:     long | pointy | round | tuft | none
## tail:     bushy | thin | nub | short | none
## gear:     antlers | horns | snout | spikes | none
## wings:    "" | side | top (insects flap fast on top)

const SPECIES: Array[Dictionary] = [
	{"key": "deer", "name": "Reh", "color": Color(0.78, 0.62, 0.42), "color2": Color(0.95, 0.92, 0.85), "scale": 1.0, "legs": 4, "leg_h": 0.34, "body": Vector3(0.55, 0.32, 0.26), "head": 0.2, "ears": "pointy", "tail": "short", "gear": "antlers", "wings": "", "movement": "walk", "speed": 1.6, "flee": true, "habitat": "grass", "weight": 2},
	{"key": "rabbit", "name": "Hase", "color": Color(0.75, 0.7, 0.6), "color2": Color(0.9, 0.87, 0.8), "scale": 0.6, "legs": 4, "leg_h": 0.14, "body": Vector3(0.4, 0.26, 0.24), "head": 0.18, "ears": "long", "tail": "nub", "gear": "none", "wings": "", "movement": "hop", "speed": 2.6, "flee": true, "habitat": "grass", "weight": 4},
	{"key": "fox", "name": "Fuchs", "color": Color(0.85, 0.45, 0.15), "color2": Color(0.95, 0.93, 0.9), "scale": 0.85, "legs": 4, "leg_h": 0.22, "body": Vector3(0.5, 0.26, 0.22), "head": 0.18, "ears": "pointy", "tail": "bushy", "gear": "none", "wings": "", "movement": "walk", "speed": 2.0, "flee": true, "habitat": "grass", "weight": 2},
	{"key": "squirrel", "name": "Eichhoernchen", "color": Color(0.7, 0.4, 0.2), "color2": Color(0.85, 0.65, 0.45), "scale": 0.5, "legs": 4, "leg_h": 0.1, "body": Vector3(0.32, 0.2, 0.18), "head": 0.15, "ears": "pointy", "tail": "bushy", "gear": "none", "wings": "", "movement": "hop", "speed": 2.4, "flee": true, "habitat": "grass", "weight": 3},
	{"key": "boar", "name": "Wildschwein", "color": Color(0.4, 0.35, 0.3), "color2": Color(0.25, 0.2, 0.15), "scale": 0.9, "legs": 4, "leg_h": 0.18, "body": Vector3(0.62, 0.36, 0.34), "head": 0.2, "ears": "pointy", "tail": "thin", "gear": "snout", "wings": "", "movement": "walk", "speed": 1.5, "flee": true, "habitat": "grass", "weight": 2},
	{"key": "badger", "name": "Dachs", "color": Color(0.55, 0.53, 0.5), "color2": Color(0.92, 0.9, 0.86), "scale": 0.6, "legs": 4, "leg_h": 0.12, "body": Vector3(0.45, 0.24, 0.24), "head": 0.17, "ears": "round", "tail": "short", "gear": "none", "wings": "", "movement": "walk", "speed": 1.2, "flee": true, "habitat": "grass", "weight": 2},
	{"key": "owl", "name": "Eule", "color": Color(0.55, 0.42, 0.3), "color2": Color(0.85, 0.78, 0.65), "scale": 0.75, "legs": 2, "leg_h": 0.16, "body": Vector3(0.3, 0.3, 0.24), "head": 0.26, "ears": "tuft", "tail": "none", "gear": "none", "wings": "side", "movement": "walk", "speed": 1.0, "flee": false, "habitat": "grass", "weight": 1, "nocturnal": true},
	{"key": "mouse", "name": "Maus", "color": Color(0.7, 0.7, 0.72), "color2": Color(0.9, 0.75, 0.75), "scale": 0.4, "legs": 4, "leg_h": 0.07, "body": Vector3(0.3, 0.16, 0.16), "head": 0.13, "ears": "round", "tail": "thin", "gear": "none", "wings": "", "movement": "hop", "speed": 2.2, "flee": true, "habitat": "grass", "weight": 3},
	{"key": "hedgehog", "name": "Igel", "color": Color(0.6, 0.45, 0.3), "color2": Color(0.35, 0.28, 0.2), "scale": 0.55, "legs": 4, "leg_h": 0.07, "body": Vector3(0.34, 0.2, 0.26), "head": 0.13, "ears": "none", "tail": "nub", "gear": "spikes", "wings": "", "movement": "walk", "speed": 0.9, "flee": false, "habitat": "grass", "weight": 2},
	{"key": "raccoon", "name": "Waschbaer", "color": Color(0.6, 0.6, 0.62), "color2": Color(0.3, 0.28, 0.28), "scale": 0.65, "legs": 4, "leg_h": 0.13, "body": Vector3(0.45, 0.26, 0.24), "head": 0.17, "ears": "pointy", "tail": "bushy", "gear": "none", "wings": "", "movement": "walk", "speed": 1.5, "flee": true, "habitat": "grass", "weight": 2},
	{"key": "stork", "name": "Storch", "color": Color(0.95, 0.95, 0.94), "color2": Color(0.15, 0.15, 0.15), "scale": 1.0, "legs": 2, "leg_h": 0.55, "body": Vector3(0.4, 0.24, 0.28), "head": 0.16, "ears": "none", "tail": "short", "gear": "none", "wings": "side", "beak": Color(0.9, 0.25, 0.2), "neck": 0.35, "movement": "wade", "speed": 1.1, "flee": true, "habitat": "river", "weight": 2},
	{"key": "swan", "name": "Schwan", "color": Color(0.97, 0.97, 0.96), "color2": Color(0.97, 0.97, 0.96), "scale": 1.0, "legs": 2, "leg_h": 0.1, "body": Vector3(0.5, 0.3, 0.34), "head": 0.15, "ears": "none", "tail": "short", "gear": "none", "wings": "side", "beak": Color(0.95, 0.6, 0.15), "neck": 0.5, "movement": "swim", "speed": 0.9, "flee": false, "habitat": "river", "weight": 2},
	{"key": "heron", "name": "Reiher", "color": Color(0.55, 0.6, 0.7), "color2": Color(0.35, 0.4, 0.5), "scale": 1.0, "legs": 2, "leg_h": 0.55, "body": Vector3(0.38, 0.24, 0.26), "head": 0.15, "ears": "none", "tail": "short", "gear": "none", "wings": "side", "beak": Color(0.9, 0.8, 0.3), "neck": 0.45, "movement": "wade", "speed": 1.0, "flee": true, "habitat": "river", "weight": 2},
	{"key": "frog", "name": "Frosch", "color": Color(0.4, 0.7, 0.3), "color2": Color(0.55, 0.8, 0.4), "scale": 0.5, "legs": 4, "leg_h": 0.08, "body": Vector3(0.28, 0.16, 0.24), "head": 0.16, "ears": "none", "tail": "none", "gear": "none", "wings": "", "movement": "hop", "speed": 1.8, "flee": true, "habitat": "river", "weight": 3},
	{"key": "toad", "name": "Kroete", "color": Color(0.55, 0.5, 0.32), "color2": Color(0.45, 0.42, 0.28), "scale": 0.5, "legs": 4, "leg_h": 0.07, "body": Vector3(0.3, 0.17, 0.25), "head": 0.16, "ears": "none", "tail": "none", "gear": "none", "wings": "", "movement": "hop", "speed": 1.5, "flee": true, "habitat": "river", "weight": 3},
	{"key": "dragonfly", "name": "Libelle", "color": Color(0.3, 0.7, 0.8), "color2": Color(0.75, 0.9, 0.95), "scale": 0.5, "legs": 0, "leg_h": 0.0, "body": Vector3(0.4, 0.07, 0.07), "head": 0.1, "ears": "none", "tail": "none", "gear": "none", "wings": "top", "movement": "fly", "speed": 2.8, "flee": false, "habitat": "grass", "weight": 2, "flight_h": 1.1},
	{"key": "butterfly", "name": "Schmetterling", "color": Color(0.35, 0.3, 0.32), "color2": Color(0.3, 0.3, 0.32), "scale": 0.45, "legs": 0, "leg_h": 0.0, "body": Vector3(0.16, 0.06, 0.05), "head": 0.06, "ears": "none", "tail": "none", "gear": "none", "wings": "side", "movement": "fly", "speed": 1.2, "flee": false, "habitat": "grass", "weight": 4, "flight_h": 0.9, "wing_c": 0.28, "wing_color": Color(0.95, 0.6, 0.2)},
	{"key": "bee", "name": "Biene", "color": Color(0.95, 0.8, 0.15), "color2": Color(0.2, 0.16, 0.1), "scale": 0.35, "legs": 0, "leg_h": 0.0, "body": Vector3(0.24, 0.12, 0.12), "head": 0.09, "ears": "none", "tail": "none", "gear": "none", "wings": "top", "movement": "fly", "speed": 1.8, "flee": false, "habitat": "grass", "weight": 4, "flight_h": 0.8, "stripes": true},
	{"key": "bumblebee", "name": "Hummel", "color": Color(0.92, 0.75, 0.2), "color2": Color(0.18, 0.14, 0.1), "scale": 0.45, "legs": 0, "leg_h": 0.0, "body": Vector3(0.28, 0.18, 0.18), "head": 0.1, "ears": "none", "tail": "none", "gear": "none", "wings": "top", "movement": "fly", "speed": 1.3, "flee": false, "habitat": "grass", "weight": 3, "flight_h": 0.75, "stripes": true},
	{"key": "goat", "name": "Ziege", "color": Color(0.9, 0.88, 0.85), "color2": Color(0.6, 0.55, 0.5), "scale": 0.85, "legs": 4, "leg_h": 0.3, "body": Vector3(0.55, 0.32, 0.28), "head": 0.18, "ears": "pointy", "tail": "short", "gear": "horns", "wings": "", "movement": "walk", "speed": 1.3, "flee": true, "habitat": "grass", "weight": 2},
]


static func by_key(key: String) -> Dictionary:
	for s: Dictionary in SPECIES:
		if s["key"] == key:
			return s
	return SPECIES[0]


## Weighted random pick. is_night gates nocturnal species (the owl)
## in and lets the diurnal crowd through during the day.
static func pick_weighted(rng: RandomNumberGenerator, is_night: bool) -> Dictionary:
	var pool: Array[Dictionary] = []
	var total: int = 0
	for s: Dictionary in SPECIES:
		if s.get("nocturnal", false) and not is_night:
			continue
		pool.append(s)
		total += int(s["weight"])
	if pool.is_empty() or total <= 0:
		return SPECIES[0]
	var roll: int = rng.randi_range(1, total)
	for s: Dictionary in pool:
		roll -= int(s["weight"])
		if roll <= 0:
			return s
	return pool[pool.size() - 1]
