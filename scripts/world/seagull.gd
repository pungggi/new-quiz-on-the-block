class_name Seagull
extends Node3D

## One seagull: circles over its ocean home, occasionally dives down to
## the water (splash), catches a little fish it carries in its beak for a
## few seconds, then climbs back into the circle. Purely visual.


enum State { CIRCLE, DIVE, CLIMB }

const WATER_Y: float = 1.02
const DIVE_TIME: float = 1.15
const CLIMB_TIME: float = 1.7
const CARRY_TIME: float = 3.5

## Circle geometry (relative to home); randomized per gull
var radius: float = randf_range(3.0, 5.0)
var height: float = randf_range(4.5, 7.5)
var speed: float = randf_range(0.7, 1.1)
## Circle direction (clockwise / counter-clockwise)
var dir: int = 1 if randf() > 0.5 else -1

## Public knobs (set by SeaWildlife before/after add_child)
var home: Vector3 = Vector3.ZERO
var dive_interval: float = 10.0
## Read by tests / debug
var state: int = State.CIRCLE

var _home_target: Vector3 = Vector3.ZERO
var _angle: float = randf() * TAU
var _dive_timer: float = 0.0
var _t: float = 0.0
var _dive_start: Vector3 = Vector3.ZERO
var _dive_target: Vector3 = Vector3.ZERO
var _climb_start: Vector3 = Vector3.ZERO
var _carry_timer: float = 0.0
var _time: float = 0.0
var _fold: float = 0.0 # 0 = flapping, 1 = wings swept back (dive)

var _left_wing: Node3D
var _right_wing: Node3D
var _carried_fish: MeshInstance3D

static var _body_mat: StandardMaterial3D
static var _wing_mat: StandardMaterial3D
static var _beak_mat: StandardMaterial3D
static var _fish_mat: StandardMaterial3D


func _ready() -> void:
	if not _body_mat:
		_body_mat = StandardMaterial3D.new()
		_body_mat.albedo_color = Color(0.95, 0.95, 0.97)
		_body_mat.roughness = 0.9
		_wing_mat = StandardMaterial3D.new()
		_wing_mat.albedo_color = Color(0.74, 0.78, 0.83)
		_wing_mat.roughness = 0.9
		_beak_mat = StandardMaterial3D.new()
		_beak_mat.albedo_color = Color(1.0, 0.62, 0.1)
		_fish_mat = StandardMaterial3D.new()
		_fish_mat.albedo_color = Color(1.0, 0.55, 0.15)

	# Body (forward = -Z)
	var body := _mesh(Vector3(0.26, 0.24, 0.55), _body_mat)
	add_child(body)
	add_child(_mesh(Vector3(0.08, 0.07, 0.16), _beak_mat, Vector3(0, 0.01, -0.36)))
	add_child(_mesh(Vector3(0.16, 0.05, 0.2), _body_mat, Vector3(0, 0.02, 0.3)))

	# Wings on pivots so they can flap around the body side
	_left_wing = Node3D.new()
	_left_wing.position = Vector3(0.13, 0.1, 0.02)
	_left_wing.add_child(_mesh(Vector3(0.72, 0.05, 0.3), _wing_mat, Vector3(0.36, 0, 0)))
	add_child(_left_wing)
	_right_wing = Node3D.new()
	_right_wing.position = Vector3(-0.13, 0.1, 0.02)
	_right_wing.add_child(_mesh(Vector3(0.72, 0.05, 0.3), _wing_mat, Vector3(-0.36, 0, 0)))
	add_child(_right_wing)

	# The caught fish (hidden until a dive succeeds)
	_carried_fish = _mesh(Vector3(0.22, 0.09, 0.28), _fish_mat, Vector3(0, -0.16, -0.38))
	_carried_fish.visible = false
	add_child(_carried_fish)

	_home_target = home
	_dive_timer = dive_interval
	global_position = _circle_pos()


func _process(delta: float) -> void:
	_time += delta
	match state:
		State.CIRCLE:
			_circle(delta)
		State.DIVE:
			_dive(delta)
		State.CLIMB:
			_climb(delta)
	_animate_wings(delta)
	if _carry_timer > 0.0:
		_carry_timer -= delta
		if _carry_timer <= 0.0:
			_carried_fish.visible = false


## ---------------------------------------------------------------- states

func _circle(delta: float) -> void:
	# Glide toward a moved home instead of teleporting
	home = home.move_toward(_home_target, delta * 4.0)
	_angle += float(dir) * speed * delta
	global_position = _circle_pos()
	_face(_circle_pos_angle(_angle + float(dir) * 0.12))
	_dive_timer -= delta
	if _dive_timer <= 0.0:
		_begin_dive()


func _begin_dive() -> void:
	_dive_start = global_position
	_dive_target = Vector3(global_position.x, WATER_Y + 0.05, global_position.z)
	_t = 0.0
	state = State.DIVE


func _dive(delta: float) -> void:
	_t += delta / DIVE_TIME
	if _t >= 1.0:
		# Splash + catch: carry the fish for a few seconds
		_splash(_dive_target, 1.2)
		_carried_fish.visible = true
		_carry_timer = CARRY_TIME
		_climb_start = global_position
		_t = 0.0
		state = State.CLIMB
		return
	global_position = _bez(_dive_start, _dive_target, -1.6, _t)
	_face(_bez(_dive_start, _dive_target, -1.6, _t + 0.03))


func _climb(delta: float) -> void:
	_t += delta / CLIMB_TIME
	var target: Vector3 = _circle_pos()
	if _t >= 1.0:
		global_position = target
		_dive_timer = randf_range(0.6, 1.4) * dive_interval
		state = State.CIRCLE
		return
	global_position = _bez(_climb_start, target, 2.8, _t)
	_face(_bez(_climb_start, target, 2.8, _t + 0.03))


## ---------------------------------------------------------------- visuals

func _animate_wings(delta: float) -> void:
	# Fold wings back while diving, otherwise flap (faster after the catch)
	var desired: float = 0.0
	match state:
		State.DIVE:
			desired = 1.0
		State.CIRCLE:
			desired = 0.0
		State.CLIMB:
			desired = 0.0
	_fold = lerpf(_fold, desired, delta * 6.0)
	var flap_speed: float = 9.0 if state != State.CLIMB else 13.0
	var flap: float = sin(_time * flap_speed) * (0.55 if state != State.CLIMB else 0.8)
	var angle: float = lerpf(flap, 1.15 * float(dir), _fold)
	_left_wing.rotation.z = angle
	_right_wing.rotation.z = -angle


func _circle_pos() -> Vector3:
	return _circle_pos_angle(_angle)


func _circle_pos_angle(a: float) -> Vector3:
	return home + Vector3(
		cos(a) * radius,
		height + sin(a * 2.3) * 0.35,
		sin(a) * radius
	)


func _face(target: Vector3) -> void:
	var dir := target - global_position
	if dir.length() <= 0.05:
		return
	# Steep dives look almost straight down - the default up vector is
	# colinear there, so fall back to a sideways up for those frames.
	var up := Vector3.UP
	if absf(dir.normalized().dot(Vector3.UP)) > 0.99:
		up = Vector3.FORWARD
	look_at(target, up)


static func _bez(p0: Vector3, p1: Vector3, ctrl_lift: float, t: float) -> Vector3:
	var ctrl: Vector3 = (p0 + p1) * 0.5 + Vector3(0, ctrl_lift, 0)
	var u: float = 1.0 - t
	return u * u * p0 + 2.0 * u * t * ctrl + t * t * p1


static func _mesh(size: Vector3, mat: StandardMaterial3D, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	return node


func _splash(pos: Vector3, strength: float) -> void:
	var manager := get_parent() as SeaWildlife
	if manager:
		manager.splash(pos, strength)


## ---------------------------------------------------------------- api

## Move the circle center (glides there instead of teleporting)
func relocate(new_home: Vector3) -> void:
	_home_target = new_home


## For tests: trigger the next dive immediately
func force_dive() -> void:
	if state == State.CIRCLE:
		_dive_timer = 0.01
