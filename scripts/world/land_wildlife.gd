class_name LandWildlife
extends Node3D

## Ambient wildlife population manager: keeps a lively mix of animals
## around the camera rig (deer, rabbits, foxes, insects ...) plus river
## birds (stork, swan, heron, frogs). Spawns only on habitat-valid
## columns and despawns animals left far behind. The owl is nocturnal.

const POPULATION: int = 18
const SPAWN_MIN: float = 24.0
const SPAWN_MAX: float = 52.0
const DESPAWN_DIST: float = 68.0
const MAINTAIN_INTERVAL: float = 1.5

var _follow: Node3D = null
var _rng := RandomNumberGenerator.new()
var _maintain_timer: float = 0.0
var _day_night: Node = null


func initialize(follow: Node3D) -> void:
	_follow = follow
	_rng.randomize()


func _process(delta: float) -> void:
	_maintain_timer -= delta
	if _maintain_timer > 0.0:
		return
	_maintain_timer = MAINTAIN_INTERVAL
	if _day_night == null and get_tree().current_scene:
		_day_night = get_tree().current_scene.get_node_or_null("DayNightCycle")
	_despawn_far()
	_spawn_missing()


## Which column rule fits a species (single source for spawn + wander)
static func habitat_rule(sp: Dictionary) -> String:
	var movement: String = String(sp["movement"])
	if String(sp["habitat"]) == "river":
		if movement == "swim" or movement == "wade":
			return movement
		return "bank" ## frogs & toads stay near the water
	if movement == "fly":
		return "grass" ## insects roam the meadow
	return "grass"


## Habitat rules: grass for walkers/hoppers/flyers, shallow water for
## wading birds, river water for swimmers, dry bank near the river for
## frogs and toads.
static func column_ok(x: int, z: int, rule: String) -> bool:
	if x < Config.WORLD_MIN_BLOCK or x >= Config.WORLD_MAX_BLOCK or z < Config.WORLD_MIN_BLOCK or z >= Config.WORLD_MAX_BLOCK:
		return false
	if WorldManager.is_bridge_column(x, z) or BushMaze.is_hedge_at(x, z):
		return false
	var col: Dictionary = WorldManager.terrain_column(x, z)
	var depth: int = WorldManager.water_depth(x, z)
	match rule:
		"grass":
			return col["top"] == Config.VoxelType.GRASS and not col["water"]
		"wade":
			return depth >= 1 and depth <= 2
		"swim":
			return depth >= 1 and depth <= 3
		"bank":
			if col["water"]:
				return false
			return absf(float(x) - WorldManager.river_center_x(z)) <= 8.0
	return false


## Next wander target for an animal (habitat-valid, 4-12 blocks away)
func pick_wander_target(animal: LandAnimal) -> Vector3:
	var rule: String = habitat_rule(animal.species)
	for i: int in range(8):
		var angle: float = _rng.randf() * TAU
		var dist: float = _rng.randf_range(4.0, 12.0)
		var x: int = int(floor(animal.global_position.x + cos(angle) * dist))
		var z: int = int(floor(animal.global_position.z + sin(angle) * dist))
		if column_ok(x, z, rule):
			return Vector3(float(x) + 0.5, 1.0, float(z) + 0.5)
	return Vector3.INF


func _despawn_far() -> void:
	if _follow == null:
		return
	for child in get_children():
		var animal := child as LandAnimal
		if animal == null:
			continue
		if animal.is_queued_for_deletion():
			continue
		if animal.global_position.distance_to(_follow.global_position) > DESPAWN_DIST:
			animal.queue_free()


func _spawn_missing() -> void:
	var alive: int = 0
	for child in get_children():
		if child is LandAnimal and not child.is_queued_for_deletion():
			alive += 1
	var is_night: bool = _day_night != null and int(_day_night.current_phase) == int(DayNightCycle.DayPhase.NIGHT)
	var fails: int = 0
	while alive < POPULATION and fails < 4:
		var sp: Dictionary = WildlifeCatalog.pick_weighted(_rng, is_night)
		var pos: Vector3 = _spawn_position(sp)
		if pos == Vector3.INF:
			fails += 1
			continue
		var animal := LandAnimal.new()
		animal.setup(sp, self, pos)
		add_child(animal)
		alive += 1


func _spawn_position(sp: Dictionary) -> Vector3:
	if String(sp["habitat"]) == "river":
		return _river_position(sp)
	return _meadow_position(sp)


func _meadow_position(sp: Dictionary) -> Vector3:
	if _follow == null:
		return Vector3.INF
	var rule: String = habitat_rule(sp)
	for i: int in range(12):
		var angle: float = _rng.randf() * TAU
		var dist: float = _rng.randf_range(SPAWN_MIN, SPAWN_MAX)
		var x: int = int(floor(_follow.global_position.x + cos(angle) * dist))
		var z: int = int(floor(_follow.global_position.z + sin(angle) * dist))
		if column_ok(x, z, rule):
			return Vector3(float(x) + 0.5, 1.0, float(z) + 0.5)
	return Vector3.INF


## River animals spawn along the meandering river near the camera
func _river_position(sp: Dictionary) -> Vector3:
	var rule: String = habitat_rule(sp)
	var fz: float = _follow.global_position.z if _follow else 0.0
	for i: int in range(12):
		var z: int = int(floor(fz + _rng.randf_range(-45.0, 45.0)))
		var rc: float = WorldManager.river_center_x(z)
		var x: float = rc
		match rule:
			"swim":
				x = rc + _rng.randf_range(-1.5, 1.5)
			"wade":
				x = rc + _rng.randf_range(-2.8, 2.8)
			"bank":
				x = rc + _rng.randf_range(3.5, 7.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
		var xi: int = int(floor(x))
		if column_ok(xi, z, rule):
			return Vector3(float(xi) + 0.5, 1.0, float(z) + 0.5)
	return Vector3.INF
