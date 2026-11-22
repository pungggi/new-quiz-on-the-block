class_name SeaWildlife
extends Node3D

## Ambient sea life: seagulls circling over the ocean with occasional
## dives (they catch and carry a little fish), plus fish that jump out
## of the water now and then. Purely visual - no collision, no saving.
## Activity follows the streaming center along the coast so the wildlife
## is always near where the player looks.


const GULL_COUNT: int = 4
const FISH_COUNT: int = 6
## Ocean strip (east side of the world). terrain_column() still validates
## every spot so the river mouth and the beach are never hit by accident.
## Homes stay this far from the strip edges so the whole circle (+ radius)
## remains above open water.
const OCEAN_X_MIN: int = 129
const OCEAN_X_MAX: int = 139
const Z_MIN: float = -125.0
const Z_MAX: float = 140.0
## Re-anchor the activity zone when the player focus drifts this far
const ANCHOR_DRIFT: float = 24.0

var _anchor_z: float = 0.0
var _gulls: Array[Seagull] = []
var _fish: Array[SeaFish] = []
var _anchor_timer: float = 3.0

## Shared materials (one instance for all animals)
static var _gull_body_mat: StandardMaterial3D
static var _gull_wing_mat: StandardMaterial3D
static var _beak_mat: StandardMaterial3D
static var _fish_mat: StandardMaterial3D
static var _splash_mat: StandardMaterial3D


func _ready() -> void:
	_setup_materials()
	for i in range(GULL_COUNT):
		var gull := Seagull.new()
		gull.name = "Gull%d" % i
		gull.home = _random_home()
		gull.dive_interval = randf_range(6.0, 16.0)
		_gulls.append(gull)
		add_child(gull)
	for i in range(FISH_COUNT):
		var fish := SeaFish.new()
		fish.name = "Fish%d" % i
		fish.jump_interval = randf_range(5.0, 15.0)
		_fish.append(fish)
		add_child(fish)


func _process(delta: float) -> void:
	_anchor_timer -= delta
	if _anchor_timer <= 0.0:
		_anchor_timer = 3.0
		var center: Vector3 = _get_stream_center()
		if absf(center.z - _anchor_z) >= ANCHOR_DRIFT:
			_anchor_z = clampf(center.z, Z_MIN, Z_MAX)
			for gull in _gulls:
				var new_home := _random_home()
				gull.relocate(new_home)


## ---------------------------------------------------------------- helpers

func _setup_materials() -> void:
	if _gull_body_mat:
		return
	_gull_body_mat = StandardMaterial3D.new()
	_gull_body_mat.albedo_color = Color(0.95, 0.95, 0.97)
	_gull_body_mat.roughness = 0.9

	_gull_wing_mat = StandardMaterial3D.new()
	_gull_wing_mat.albedo_color = Color(0.74, 0.78, 0.83)
	_gull_wing_mat.roughness = 0.9

	_beak_mat = StandardMaterial3D.new()
	_beak_mat.albedo_color = Color(1.0, 0.62, 0.1)

	_fish_mat = StandardMaterial3D.new()
	_fish_mat.albedo_color = Color(1.0, 0.55, 0.15)
	_fish_mat.roughness = 0.5

	_splash_mat = StandardMaterial3D.new()
	_splash_mat.albedo_color = Color(0.85, 0.93, 1.0)
	_splash_mat.roughness = 0.3


static func _box(size: Vector3, mat: StandardMaterial3D, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	return node


## Gull home: a spot over open water near the activity anchor
func _random_home() -> Vector3:
	return Vector3(
		float(randi_range(OCEAN_X_MIN, OCEAN_X_MAX)) + 0.5,
		WorldManager.WATER_SURFACE_MAX_Y,
		clampf(_anchor_z + randf_range(-18.0, 18.0), Z_MIN, Z_MAX)
	)


func _get_stream_center() -> Vector3:
	var cm: Node = get_node_or_null("/root/ChunkManager")
	if cm and cm.has_method("get_stream_center"):
		var center: Variant = cm.get_stream_center()
		if center is Vector3:
			return center
	return Vector3.ZERO


## A random spot on open water near the activity anchor (validated against
## the real terrain so nothing ever jumps into the sand).
func random_ocean_pos(z_spread: float = 25.0) -> Vector3:
	for i in range(8):
		var x: int = randi_range(OCEAN_X_MIN - 2, OCEAN_X_MAX + 2)
		var z: int = int(round(clampf(_anchor_z + randf_range(-z_spread, z_spread), Z_MIN, Z_MAX)))
		var col: Dictionary = WorldManager.terrain_column(x, z)
		if col["water"]:
			return Vector3(float(x) + 0.5, WorldManager.WATER_SURFACE_MAX_Y, float(z) + 0.5)
	return _random_home()


## Small white splash droplets at a water position.
func splash(pos: Vector3, strength: float = 1.0) -> void:
	var count: int = 4 + int(round(strength * 2.0))
	for i in range(count):
		var droplet := _box(Vector3.ONE * 0.1 * randf_range(0.8, 1.3), _splash_mat, pos)
		add_child(droplet)
		var vel := Vector3(randf_range(-1.0, 1.0), randf_range(1.8, 2.8), randf_range(-1.0, 1.0)) * strength
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(droplet, "position", pos + vel * 0.4, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(droplet, "scale", Vector3.ONE * 0.05, 0.4)
		tween.chain().tween_callback(droplet.queue_free)
