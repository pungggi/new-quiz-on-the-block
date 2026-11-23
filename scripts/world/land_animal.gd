class_name LandAnimal
extends Node3D

## One ambient animal: blocky mesh AND behavior are fully driven by its
## WildlifeCatalog species entry. The manager (LandWildlife) provides
## habitat-aware wander targets; the animal handles movement itself:
## walking, hopping, wading, swimming or flying, plus fleeing from the
## player. Faces +Z like every other entity in the game.

enum State { IDLE, WANDER, FLEE }

const HOP_HEIGHT: float = 0.3
const FLEE_DISTANCE: float = 3.5

var species: Dictionary = {}
var manager: LandWildlife = null

var _state: int = State.IDLE
var _target: Vector3 = Vector3.ZERO
var _idle_left: float = 1.0
var _hop_t: float = 0.0
var _t: float = 0.0
var _speed_mult: float = 1.0
var _player: Node3D = null
var _mesh_root: Node3D = null
var _wing_pivots: Array[Node3D] = []


func setup(sp: Dictionary, mgr: LandWildlife, start_pos: Vector3) -> void:
	species = sp
	manager = mgr
	position = start_pos
	_target = start_pos


func _ready() -> void:
	if species.is_empty():
		return
	_build_body()
	_player = get_tree().get_first_node_in_group("player")


func _process(delta: float) -> void:
	if species.is_empty():
		return
	_t += delta
	_check_flee()
	match _state:
		State.IDLE:
			_idle_left -= delta
			if _idle_left <= 0.0:
				_pick_target()
		_:
			_move_toward(delta)
	_animate(delta)


## Skittish species bolt when the player comes too close
func _check_flee() -> void:
	if _state == State.FLEE:
		return
	if not (bool(species.get("flee", false)) and _player and is_instance_valid(_player)):
		return
	if global_position.distance_squared_to(_player.global_position) < FLEE_DISTANCE * FLEE_DISTANCE:
		var away: Vector3 = global_position - _player.global_position
		away.y = 0.0
		if away.length_squared() < 0.001:
			return
		_target = global_position + away.normalized() * 5.5
		_target.x = clampf(_target.x, Config.WORLD_MIN_X, Config.WORLD_MAX_X)
		_target.z = clampf(_target.z, Config.WORLD_MIN_Z, Config.WORLD_MAX_Z)
		_state = State.FLEE
		_speed_mult = 2.2


func _pick_target() -> void:
	var next: Vector3 = Vector3.INF
	if manager and is_instance_valid(manager):
		next = manager.pick_wander_target(self)
	if next == Vector3.INF:
		_idle_left = 0.8 ## nowhere to go right now, try again soon
		return
	_target = next
	_state = State.WANDER


func _move_toward(delta: float) -> void:
	var dir: Vector3 = _target - global_position
	dir.y = 0.0
	var dist: float = dir.length()
	if dist < 0.35:
		_speed_mult = 1.0
		_state = State.IDLE
		_idle_left = randf_range(1.0, 4.0) if String(species["movement"]) != "fly" else randf_range(0.4, 1.6)
		return
	dir = dir / dist
	var speed: float = float(species["speed"]) * _speed_mult
	global_position.x += dir.x * speed * delta
	global_position.z += dir.z * speed * delta

	var movement: String = String(species["movement"])
	if movement == "swim":
		global_position.y = WorldManager.WATER_SURFACE_MAX_Y - 0.16 + sin(_t * 1.6) * 0.03
	elif movement == "fly":
		var cruise: float = WorldManager.walk_surface_y_at(global_position) + float(species.get("flight_h", 1.0))
		global_position.y = lerpf(global_position.y, cruise, delta * 3.0)
	else:
		global_position.y = lerpf(global_position.y, WorldManager.walk_surface_y_at(global_position), delta * 8.0)

	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), delta * 6.0)


func _animate(delta: float) -> void:
	if _mesh_root == null:
		return
	var movement: String = String(species["movement"])
	var moving: bool = _state != State.IDLE

	# Hop arc for rabbits & frogs, gentle bob for walkers
	var bob: float = 0.0
	if moving and movement == "hop":
		_hop_t = fmod(_hop_t + delta * 3.2, 1.0)
		bob = sin(_hop_t * PI) * HOP_HEIGHT
	elif moving:
		bob = sin(_t * float(species["speed"]) * 5.0) * 0.02
	_mesh_root.position.y = bob

	# Wing flapping: insects beat fast, birds flap while moving
	if not _wing_pivots.is_empty():
		var flap: float = 0.0
		if movement == "fly":
			flap = sin(_t * 40.0) * 0.9
		elif moving:
			flap = sin(_t * 9.0) * 0.45
		for i: int in range(_wing_pivots.size()):
			var side: float = 1.0 if i == 0 else -1.0
			_wing_pivots[i].rotation.z = side * flap

	# Grounded animals settle onto the surface even while idle
	if not moving and movement != "fly" and movement != "swim":
		global_position.y = lerpf(global_position.y, WorldManager.walk_surface_y_at(global_position), delta * 4.0)


## Build the blocky body from the species entry. body = Vector3(length z,
## height y, width x); everything else snaps onto that box.
func _build_body() -> void:
	_mesh_root = Node3D.new()
	_mesh_root.name = "BodyRoot"
	add_child(_mesh_root)
	_mesh_root.scale = Vector3.ONE * float(species["scale"])

	var c: Color = species["color"]
	var c2: Color = species.get("color2", c)
	var blen: float = float(species["body"].x)
	var bh: float = float(species["body"].y)
	var bwid: float = float(species["body"].z)
	var leg_h: float = float(species["leg_h"])
	var head_s: float = float(species["head"])
	var leg_c: Color = c.darkened(0.15)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Legs
	var leg_w: float = 0.07
	if int(species["legs"]) == 4:
		for lx: float in [-bwid * 0.5 + leg_w, bwid * 0.5 - leg_w]:
			for lz: float in [-blen * 0.5 + leg_w, blen * 0.5 - leg_w]:
				SurfaceBoxes.add_box(st, Vector3(lx - leg_w * 0.5, 0.0, lz - leg_w * 0.5), Vector3(lx + leg_w * 0.5, leg_h, lz + leg_w * 0.5), leg_c)
	elif int(species["legs"]) == 2:
		for lx: float in [-0.06, 0.06]:
			SurfaceBoxes.add_box(st, Vector3(lx - leg_w * 0.5, 0.0, -leg_w * 0.5), Vector3(lx + leg_w * 0.5, leg_h, leg_w * 0.5), leg_c)

	# Body (striped species get three alternating segments)
	if bool(species.get("stripes", false)):
		for seg: int in range(3):
			var seg_c: Color = c if seg % 2 == 0 else c2
			var z0: float = -blen * 0.5 + blen * float(seg) / 3.0
			var z1: float = -blen * 0.5 + blen * float(seg + 1) / 3.0
			SurfaceBoxes.add_box(st, Vector3(-bwid * 0.5, leg_h, z0), Vector3(bwid * 0.5, leg_h + bh, z1), seg_c, c)
	else:
		SurfaceBoxes.add_box(st, Vector3(-bwid * 0.5, leg_h, -blen * 0.5), Vector3(bwid * 0.5, leg_h + bh, blen * 0.5), c, c.lightened(0.08))

	# Head: on a neck for birds, on the body front for everyone else
	var neck: float = float(species.get("neck", 0.0))
	var head_center: Vector3
	if neck > 0.0:
		SurfaceBoxes.add_box(st, Vector3(-0.05, leg_h + bh * 0.5, blen * 0.5 - 0.1), Vector3(0.05, leg_h + bh + neck, blen * 0.5 + 0.08), c)
		head_center = Vector3(0.0, leg_h + bh + neck + head_s * 0.5 - 0.02, blen * 0.5 + 0.02)
	else:
		head_center = Vector3(0.0, leg_h + bh * 0.8, blen * 0.5 + head_s * 0.5 - 0.04)
	SurfaceBoxes.add_box(st, head_center - Vector3(head_s * 0.45, head_s * 0.5, head_s * 0.5), head_center + Vector3(head_s * 0.45, head_s * 0.5, head_s * 0.5), c)
	var head_top: float = head_center.y + head_s * 0.5
	var head_front: float = head_center.z + head_s * 0.5

	# Ears
	var ear_c: Color = c.darkened(0.1)
	match String(species["ears"]):
		"long":
			for ex: float in [-head_s * 0.3, head_s * 0.3]:
				SurfaceBoxes.add_box(st, Vector3(ex - 0.035, head_top, -0.025), Vector3(ex + 0.035, head_top + 0.28, 0.025), ear_c)
		"pointy":
			for ex: float in [-head_s * 0.3, head_s * 0.3]:
				SurfaceBoxes.add_box(st, Vector3(ex - 0.04, head_top, -0.03), Vector3(ex + 0.04, head_top + 0.12, 0.03), ear_c)
		"round":
			for ex: float in [-head_s * 0.32, head_s * 0.32]:
				SurfaceBoxes.add_box(st, Vector3(ex - 0.05, head_top, -0.03), Vector3(ex + 0.05, head_top + 0.1, 0.03), ear_c)
		"tuft":
			for ex: float in [-head_s * 0.28, head_s * 0.28]:
				SurfaceBoxes.add_box(st, Vector3(ex - 0.025, head_top, -0.02), Vector3(ex + 0.025, head_top + 0.07, 0.02), ear_c)

	# Eyes
	var eye: Color = Color(0.12, 0.1, 0.1)
	for ex: float in [-head_s * 0.26, head_s * 0.26]:
		SurfaceBoxes.add_box(st, Vector3(ex - 0.02, head_center.y + head_s * 0.12, head_front - 0.005), Vector3(ex + 0.02, head_center.y + head_s * 0.12 + 0.04, head_front + 0.015), eye)

	# Beak / snout
	if species.has("beak"):
		var beak: Color = species["beak"]
		SurfaceBoxes.add_box(st, Vector3(-head_s * 0.3, head_center.y - 0.01, head_front), Vector3(head_s * 0.3, head_center.y + 0.05, head_front + 0.3), beak)
	if String(species["gear"]) == "snout":
		SurfaceBoxes.add_box(st, Vector3(-0.06, head_center.y - head_s * 0.3, head_front - 0.01), Vector3(0.06, head_center.y - head_s * 0.3 + 0.07, head_front + 0.09), c2)

	# Headgear
	match String(species["gear"]):
		"antlers":
			var antler: Color = Color(0.45, 0.35, 0.25)
			for ex: float in [-head_s * 0.25, head_s * 0.25]:
				SurfaceBoxes.add_box(st, Vector3(ex - 0.02, head_top, -0.02), Vector3(ex + 0.02, head_top + 0.22, 0.02), antler)
		"horns":
			var horn: Color = Color(0.7, 0.68, 0.65)
			for ex: float in [-head_s * 0.25, head_s * 0.25]:
				SurfaceBoxes.add_box(st, Vector3(ex - 0.03, head_top, -0.04), Vector3(ex + 0.03, head_top + 0.1, 0.04), horn)
		"spikes":
			for i: int in range(4):
				var sz: float = -blen * 0.35 + blen * 0.7 * float(i) / 3.0
				SurfaceBoxes.add_box(st, Vector3(-0.05, leg_h + bh, sz - 0.04), Vector3(0.05, leg_h + bh + 0.09, sz + 0.04), c2)

	# Tail
	match String(species["tail"]):
		"bushy":
			SurfaceBoxes.add_box(st, Vector3(-0.065, leg_h + bh * 0.45, -blen * 0.5 - 0.28), Vector3(0.065, leg_h + bh * 0.45 + 0.13, -blen * 0.5), c)
			SurfaceBoxes.add_box(st, Vector3(-0.065, leg_h + bh * 0.45, -blen * 0.5 - 0.37), Vector3(0.065, leg_h + bh * 0.45 + 0.13, -blen * 0.5 - 0.28), c2)
		"thin":
			SurfaceBoxes.add_box(st, Vector3(-0.02, leg_h + bh * 0.55, -blen * 0.5 - 0.26), Vector3(0.02, leg_h + bh * 0.55 + 0.04, -blen * 0.5), c2)
		"nub":
			SurfaceBoxes.add_box(st, Vector3(-0.045, leg_h + bh * 0.5, -blen * 0.5 - 0.07), Vector3(0.045, leg_h + bh * 0.5 + 0.09, -blen * 0.5), c2)
		"short":
			SurfaceBoxes.add_box(st, Vector3(-0.04, leg_h + bh * 0.4, -blen * 0.5 - 0.09), Vector3(0.04, leg_h + bh * 0.4 + 0.1, -blen * 0.5), c)

	var mi := MeshInstance3D.new()
	mi.name = "BodyMesh"
	mi.mesh = st.commit()
	mi.material_override = VertexColorMaterial.make()
	_mesh_root.add_child(mi)

	# Wings on their own pivots so they can flap
	if String(species["wings"]) != "":
		var wing_c: float = float(species.get("wing_c", 0.22))
		var wc: Color = species.get("wing_color", c2)
		for side: float in [-1.0, 1.0]:
			var pivot := Node3D.new()
			pivot.position = Vector3(side * bwid * 0.45, leg_h + bh * 0.7, 0.0)
			_mesh_root.add_child(pivot)
			var wst := SurfaceTool.new()
			wst.begin(Mesh.PRIMITIVE_TRIANGLES)
			if String(species["wings"]) == "side":
				SurfaceBoxes.add_box(wst, Vector3(minf(side * wing_c, 0.0), -0.02, -blen * 0.35), Vector3(maxf(side * wing_c, 0.0), 0.02, blen * 0.35), wc)
			else: ## top: insect wings
				SurfaceBoxes.add_box(wst, Vector3(minf(side * 0.3, 0.0), -0.005, -0.12), Vector3(maxf(side * 0.3, 0.0), 0.005, 0.12), wc.lightened(0.35))
			var wmi := MeshInstance3D.new()
			wmi.mesh = wst.commit()
			wmi.material_override = VertexColorMaterial.make()
			pivot.add_child(wmi)
			_wing_pivots.append(pivot)
