class_name PlanetCatalog
extends RefCounted

## Worlds selectable from the clock (HUD -> PlanetPicker). Sorted by day
## length, shortest first - a gentle lesson in planetary rotation.
## day_minutes: real minutes for one full day-night cycle.
## sun_intensity: multiplies the sun's energy (1.0 = Earth).

const PLANETS: Array[Dictionary] = [
	{"key": "mercury", "name": "Merkur", "color": Color(0.62, 0.52, 0.44), "day_minutes": 2.0, "sun_intensity": 1.6},
	{"key": "jupiter", "name": "Jupiter", "color": Color(0.9, 0.62, 0.36), "day_minutes": 5.0, "sun_intensity": 1.2},
	{"key": "mars", "name": "Mars", "color": Color(0.85, 0.32, 0.18), "day_minutes": 7.0, "sun_intensity": 0.8},
	{"key": "earth", "name": "Erde", "color": Color(0.25, 0.55, 0.9), "day_minutes": 10.0, "sun_intensity": 1.0},
	{"key": "neptune", "name": "Neptun", "color": Color(0.22, 0.36, 0.85), "day_minutes": 25.0, "sun_intensity": 0.45},
]


static func by_key(key: String) -> Dictionary:
	for p: Dictionary in PLANETS:
		if p["key"] == key:
			return p
	return PLANETS[0]
