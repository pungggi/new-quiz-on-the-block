extends Node3D
class_name Bridge

## Wooden bridge across the river. Geometry follows WorldManager.BRIDGE_*
## (the same constants drive walk_surface_y and this mesh, so they can
## never drift apart). Deck and ramps carry the PLAYER via colliders on
## Config.BRIDGE_COLLISION_LAYER - player-only, because NPCs glide over
## via WorldManager.walk_surface_y and would snag on the deck step.
## Railings use the prop layer so NPCs slide along them like around
## trees. Purely decorative: no gameplay logic lives here.

const DECK_THICKNESS: float = 0.2
const RAILING_H: float = 0.55
const RAILING_INSET: float = 0.12

const WOOD := Color(0.55, 0.39, 0.23)
const WOOD_DARK := Color(0.42, 0.29, 0.17)

var _cx: int = 0
var _bz: int = 0
var _deck_y: float = 0.0
var _half_len: float = 0.0
var _half_w: float = 0.0


func _ready() -> void:
	_cx = WorldManager.bridge_cx
	_bz = WorldManager.BRIDGE_Z
	_deck_y = WorldManager.BRIDGE_DECK_Y
	_half_len = float(WorldManager.BRIDGE_HALF_LEN)
	_half_w = float(WorldManager.BRIDGE_HALF_W)
	_build()


func _build() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260101
	_deck(st, rng)
	_ramp(st, -1)
	_ramp(st, 1)
	_railings(st)
	_support_posts(st)
	var mi := MeshInstance3D.new()
	mi.name = "BridgeMesh"
	mi.mesh = st.commit()
	mi.material_override = VertexColorMaterial.make()
	add_child(mi)


## Deck planks (one per block, jittered wood tones) on a player-only
## collider slab
func _deck(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var body := StaticBody3D.new()
	body.name = "Deck"
	body.collision_layer = Config.BRIDGE_COLLISION_LAYER
	add_child(body)
	var box := BoxShape3D.new()
	box.size = Vector3(_half_len * 2.0 + 1.0, DECK_THICKNESS, _half_w * 2.0 + 1.0)
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position = Vector3(float(_cx) + 0.5, _deck_y - DECK_THICKNESS * 0.5, float(_bz) + 0.5)
	body.add_child(shape)

	var planks: int = int(_half_len) * 2 + 1
	for i: int in range(planks):
		var j: float = rng.randf_range(-0.035, 0.035)
		var c := Color(WOOD.r + j, WOOD.g + j, WOOD.b + j)
		var x: float = float(_cx - int(_half_len) + i)
		SurfaceBoxes.add_box(st,
			Vector3(x, _deck_y - DECK_THICKNESS, float(_bz) - _half_w),
			Vector3(x + 1.0, _deck_y, float(_bz) + _half_w + 1.0),
			c, c.lightened(0.07), true)


## Sloped board from the grass up to the deck (dir: -1 west, +1 east),
## matching walk_surface_y's ramp columns
func _ramp(st: SurfaceTool, dir: int) -> void:
	# Surface runs from the deck edge (high) down to the grass (low)
	var x_top: float = float(_cx) + 0.5 + dir * (_half_len + 0.5)
	var x_low: float = x_top + dir * float(WorldManager.BRIDGE_RAMP_LEN)
	var run: float = absf(x_low - x_top)
	var rise: float = _deck_y - Config.GROUND_Y
	var angle: float = atan2(rise, run)
	var rot_z: float = -angle * float(dir)
	var mid := Vector3((x_top + x_low) * 0.5, Config.GROUND_Y + rise * 0.5, float(_bz) + 0.5)
	var n := Vector2(-sin(rot_z), cos(rot_z))
	var center := Vector3(mid.x - n.x * DECK_THICKNESS * 0.5, mid.y - n.y * DECK_THICKNESS * 0.5, mid.z)
	var length: float = sqrt(run * run + rise * rise)
	var width: float = _half_w * 2.0 + 1.0

	var body := StaticBody3D.new()
	body.name = "Ramp" + ("East" if dir > 0 else "West")
	body.collision_layer = Config.BRIDGE_COLLISION_LAYER
	add_child(body)
	var box := BoxShape3D.new()
	box.size = Vector3(length, DECK_THICKNESS, width)
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position = center
	shape.rotation = Vector3(0.0, 0.0, rot_z)
	body.add_child(shape)
	_rotated_box(st, center, box.size, rot_z, WOOD, WOOD.lightened(0.07))


## Oriented box (rotated around z) for the sloped ramp boards
func _rotated_box(st: SurfaceTool, center: Vector3, size: Vector3, rot_z: float, color: Color, top_color: Color) -> void:
	var u := Vector3(cos(rot_z), sin(rot_z), 0.0)
	var v := Vector3(-sin(rot_z), cos(rot_z), 0.0)
	var w := Vector3(0.0, 0.0, 1.0)
	var h := size * 0.5
	var lo_a := center - u * h.x - v * h.y - w * h.z
	var lo_b := center + u * h.x - v * h.y - w * h.z
	var hi_a := center - u * h.x + v * h.y - w * h.z
	var hi_b := center + u * h.x + v * h.y - w * h.z
	SurfaceBoxes.add_quad(st, hi_a, hi_b, hi_b + w * size.z, hi_a + w * size.z, v, top_color)
	SurfaceBoxes.add_quad(st, lo_a, lo_b, lo_b + w * size.z, lo_a + w * size.z, -v, color)
	SurfaceBoxes.add_quad(st, lo_a, hi_a, hi_a + w * size.z, lo_a + w * size.z, -u, color)
	SurfaceBoxes.add_quad(st, lo_b, hi_b, hi_b + w * size.z, lo_b + w * size.z, u, color)
	SurfaceBoxes.add_quad(st, lo_a, lo_b, hi_b, hi_a, -w, color)
	SurfaceBoxes.add_quad(st, lo_a + w * size.z, lo_b + w * size.z, hi_b + w * size.z, hi_a + w * size.z, w, color)


## Railings along the deck edges (entrance sides stay open)
func _railings(st: SurfaceTool) -> void:
	var body := StaticBody3D.new()
	body.name = "Railings"
	body.collision_layer = Config.PROP_COLLISION_LAYER
	add_child(body)
	var deck_len: float = _half_len * 2.0 + 1.0
	for side: float in [-1.0, 1.0]:
		var z: float = float(_bz) + 0.5 + side * (_half_w + 0.5 - RAILING_INSET)
		# Solid collider wall (blocks player AND NPCs)
		var box := BoxShape3D.new()
		box.size = Vector3(deck_len, RAILING_H, 0.16)
		var shape := CollisionShape3D.new()
		shape.shape = box
		shape.position = Vector3(float(_cx) + 0.5, _deck_y + RAILING_H * 0.5, z)
		body.add_child(shape)
		# Chunky look: posts plus a top bar
		var n_posts: int = int(_half_len) * 2 + 2
		for i: int in range(n_posts):
			var px: float = float(_cx) - _half_len + float(i) * (_half_len * 2.0) / float(n_posts - 1)
			SurfaceBoxes.add_box(st,
				Vector3(px - 0.07, _deck_y, z - 0.07),
				Vector3(px + 0.07, _deck_y + RAILING_H, z + 0.07),
				WOOD_DARK)
		SurfaceBoxes.add_box(st,
			Vector3(float(_cx) - _half_len, _deck_y + RAILING_H - 0.14, z - 0.1),
			Vector3(float(_cx) + _half_len + 1.0, _deck_y + RAILING_H + 0.02, z + 0.1),
			WOOD)


## Trestle posts under the deck, standing in the river bed
func _support_posts(st: SurfaceTool) -> void:
	for dx: int in [-2, 2]:
		var x: float = float(_cx + dx)
		var bed: float = WorldManager.surface_y(_cx + dx, _bz)
		SurfaceBoxes.add_box(st,
			Vector3(x + 0.39, bed - 0.2, float(_bz) - 0.75),
			Vector3(x + 0.61, _deck_y - DECK_THICKNESS + 0.05, float(_bz) + _half_w + 0.75),
			WOOD_DARK)
