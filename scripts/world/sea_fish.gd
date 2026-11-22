class_name SeaFish
extends Node3D

## One fish: waits hidden under the surface, then jumps in a small arc
## out of the water (splash at start and landing) and hides again.
## Purely visual - picks its own spot over open water via SeaWildlife.


const JUMP_TIME: float = 0.85
const JUMP_PEAK: float = 1.0

## Public knobs (set by SeaWildlife)
var jump_interval: float = 10.0
## Read by tests / debug
var jumping: bool = false

var _timer: float = 0.0
var _t: float = 0.0
var _start_pos: Vector3 = Vector3.ZERO
var _end_pos: Vector3 = Vector3.ZERO

static var _fish_mat: StandardMaterial3D


func _ready() -> void:
	if not _fish_mat:
		_fish_mat = StandardMaterial3D.new()
		_fish_mat.albedo_color = Color(1.0, 0.55, 0.15)
		_fish_mat.roughness = 0.5

	# Body along X, little tail fin at the back
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.36, 0.16, 0.15)
	body_mesh.material = _fish_mat
	body.mesh = body_mesh
	add_child(body)

	var tail := MeshInstance3D.new()
	var tail_mesh := BoxMesh.new()
	tail_mesh.size = Vector3(0.14, 0.13, 0.06)
	tail_mesh.material = _fish_mat
	tail.mesh = tail_mesh
	tail.position = Vector3(0.22, 0, 0)
	add_child(tail)

	visible = false
	_timer = randf_range(2.0, jump_interval)


func _process(delta: float) -> void:
	if jumping:
		_jump_step(delta)
		return
	_timer -= delta
	if _timer <= 0.0:
		_begin_jump()


## ---------------------------------------------------------------- jump

func _begin_jump() -> void:
	var manager := get_parent() as SeaWildlife
	if manager == null:
		_timer = 2.0
		return
	var pos: Vector3 = manager.random_ocean_pos(25.0)
	var dirv := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	if dirv.length() < 0.1:
		dirv = Vector3(1.0, 0.0, 0.0)
	dirv = dirv.normalized()
	_start_pos = pos - dirv * 0.9
	_end_pos = pos + dirv * 0.9
	_t = 0.0
	jumping = true
	visible = true
	manager.splash(pos, 0.6)


func _jump_step(delta: float) -> void:
	_t += delta / JUMP_TIME
	if _t >= 1.0:
		_end_jump()
		return
	global_position = _start_pos.lerp(_end_pos, _t) + Vector3(
		0.0,
		(WorldManager.WATER_SURFACE_MAX_Y - 0.35) + 4.0 * JUMP_PEAK * _t * (1.0 - _t),
		0.0
	)
	rotation.z = -_t * 5.5 # playful tumble around the jump


func _end_jump() -> void:
	jumping = false
	visible = false
	rotation.z = 0.0
	var manager := get_parent() as SeaWildlife
	if manager:
		manager.splash(Vector3(global_position.x, WorldManager.WATER_SURFACE_MAX_Y, global_position.z), 0.6)
	_timer = randf_range(0.5, 1.5) * jump_interval


## For tests: trigger the next jump immediately
func force_jump() -> void:
	if not jumping:
		_timer = 0.01
