class_name DriftBoat
extends Node3D

## A little wooden boat drifting on the ocean east of the beach. It
## bobs and rocks on the waves, sails slowly north/south along the
## coast and comes about (turns around) when it leaves the player's
## vicinity or reaches the world edge - like a toy boat carried by a
## reversing tidal current. Purely ambient, no collision.

const DRIFT_SPEED: float = 0.8 ## blocks per second along the coast
const TURN_DISTANCE: float = 55.0 ## come about this far from the player
const WORLD_MARGIN: float = 10.0 ## stay clear of the north/south edges
const OCEAN_D_EAST: int = 12 ## blocks from the east edge (depth ~8, well afloat)
const X_DRIFT: float = 1.5 ## gentle sideways wander amplitude

var _t: float = 0.0
var _dir: float = 1.0
var _spawn_x: float = 0.0
var _follow: Node3D = null


## Call BEFORE add_child so _ready can spawn near the player
func initialize(follow: Node3D) -> void:
	_follow = follow


func _ready() -> void:
	_spawn_x = float(Config.WORLD_MAX_BLOCK - OCEAN_D_EAST) + 0.5
	var start_z: float = _follow.global_position.z if _follow else 0.0
	start_z = clampf(start_z, float(Config.WORLD_MIN_BLOCK) + WORLD_MARGIN, float(Config.WORLD_MAX_BLOCK) - WORLD_MARGIN)
	position = Vector3(_spawn_x, WorldManager.WATER_SURFACE_MAX_Y, start_z)
	_build_boat()


func _process(delta: float) -> void:
	_t += delta

	# Tidal drift along the coast
	position.z += _dir * DRIFT_SPEED * delta
	position.x = _spawn_x + sin(_t * 0.23) * X_DRIFT

	# Bob and rock on the waves
	position.y = WorldManager.WATER_SURFACE_MAX_Y + sin(_t * 1.1) * 0.045
	rotation.z = sin(_t * 0.8) * 0.05
	rotation.x = sin(_t * 0.6 + 1.3) * 0.03

	# Come about when leaving the player's vicinity or the world: head
	# back toward the player (repeated calls are harmless, the value
	# just stays the same until the distance shrinks again)
	var flip: bool = false
	if _follow and is_instance_valid(_follow):
		if absf(position.z - _follow.global_position.z) > TURN_DISTANCE:
			_dir = -signf(position.z - _follow.global_position.z)
			flip = true
	if not flip:
		if position.z < float(Config.WORLD_MIN_BLOCK) + WORLD_MARGIN:
			_dir = 1.0
		elif position.z > float(Config.WORLD_MAX_BLOCK) - WORLD_MARGIN:
			_dir = -1.0

	# Face the travel direction (slow swing while coming about)
	var heading: float = 0.0 if _dir > 0.0 else PI
	rotation.y = lerp_angle(rotation.y, heading, delta * 1.5)


## Blocky wooden dinghy with a mast, sail and little flag (faces +Z)
func _build_boat() -> void:
	var hull: Color = Color(0.55, 0.38, 0.22)
	var rim: Color = Color(0.72, 0.52, 0.32)
	var wood: Color = Color(0.45, 0.33, 0.2)
	var sail_c: Color = Color(0.96, 0.93, 0.86)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Hull bottom + raised bow and stern
	SurfaceBoxes.add_box(st, Vector3(-0.32, -0.14, -0.65), Vector3(0.32, 0.02, 0.65), hull)
	SurfaceBoxes.add_box(st, Vector3(-0.22, -0.14, 0.65), Vector3(0.22, 0.06, 0.88), hull)
	SurfaceBoxes.add_box(st, Vector3(-0.26, -0.14, -0.78), Vector3(0.26, 0.06, -0.65), hull)

	# Gunwale rails along the sides
	SurfaceBoxes.add_box(st, Vector3(-0.36, 0.02, -0.65), Vector3(-0.28, 0.12, 0.65), rim)
	SurfaceBoxes.add_box(st, Vector3(0.28, 0.02, -0.65), Vector3(0.36, 0.12, 0.65), rim)

	# Bench seat across the middle
	SurfaceBoxes.add_box(st, Vector3(-0.28, 0.1, -0.08), Vector3(0.28, 0.16, 0.02), rim)

	# Mast + cream sail catching the current from behind + little flag
	SurfaceBoxes.add_box(st, Vector3(-0.03, 0.12, 0.15), Vector3(0.03, 1.15, 0.21), wood)
	SurfaceBoxes.add_box(st, Vector3(-0.02, 0.35, 0.24), Vector3(0.02, 1.02, 0.66), sail_c)
	SurfaceBoxes.add_box(st, Vector3(-0.02, 1.15, 0.16), Vector3(0.02, 1.27, 0.34), Color(0.85, 0.25, 0.2))

	var mi := MeshInstance3D.new()
	mi.name = "BoatMesh"
	mi.mesh = st.commit()
	mi.material_override = VertexColorMaterial.make()
	add_child(mi)
