class_name BikePark
extends Node3D

## A bicycle skill course south-west of the spawn lawn: five stations
## along a looping path, each paying a one-time education-point reward
## the first time the player clears it on the bike.
##
##   1 START     - checkered gate, sets you on the course
##   2 HOP       - a low hedge bar to bunny-hop (hop key: Space)
##   3 SLALOM    - five cones to weave through
##   4 BALANCE   - a narrow wooden beam over a shallow pit (stay on!)
##   5 JUMP      - a kicker ramp with a landing ramp
##   6 FINISH    - checkered arch, course complete bonus
##
## Every station is a trigger Area3D that watches the BIKE (riding the
## real player), so walking through on foot never collects anything.
## Rewards persist per profile: a station pays once, ever.

const ORIGIN: Vector2i = Vector2i(-24, -18) ## south-west corner of the park lawn
const SIZE: Vector2i = Vector2i(19, 15) ## park footprint in blocks

const STATION_REWARD: int = 10 ## education points per cleared station
const FINISH_REWARD: int = 25 ## course completion bonus

const HEDGE_BAR_H: float = 0.45 ## hop bar height (hop apex is ~1.1)
const CONE_H: float = 0.7
const BEAM_W: float = 0.8
const BEAM_Y: float = 0.9 ## beam top above ground (bike hop apex ~1.1)
const PIT_DEPTH: float = 0.5
const RAMP_H: float = 1.0 ## kicker height
const RAMP_LEN: float = 3.0
const RAMP_W: float = 2.4
const BALANCE_RAMP_LEN: float = 2.6 ## gentle ride up onto the beam
const JUMP_GAP: float = 2.6 ## gap between kicker lip and landing ramp
const RAMP_OVERLAP: float = 0.03 ## ramps end a hair ABOVE the beam top so the bike's box collider never catches a flush edge

const STATION_NAMES: Array[String] = ["Hop", "Slalom", "Balance", "Sprung", "Ziel"]
## Station ids as stored in the profile (stable strings, never rename)
const STATION_IDS: Array[String] = ["hop", "slalom", "balance", "jump", "finish"]

var _station_nodes: Dictionary = {} ## id -> Area3D
var _done_labels: Dictionary = {} ## id -> Label3D (check mark once cleared)


func _ready() -> void:
	_build_ground()
	_build_start_marker()
	_build_hop()
	_build_slalom()
	_build_balance()
	_build_jump()
	_build_finish()
	_refresh_marks()


## Static footprint test used by the build cursor and prop decoration
static func is_in_park(world_x: int, world_z: int) -> bool:
	var lx: int = world_x - ORIGIN.x
	var lz: int = world_z - ORIGIN.y
	return lx >= 0 and lx < SIZE.x and lz >= 0 and lz < SIZE.y


# ------------------------------------------------------------------ ground

## Soft dirt track ribbon around the course plus a border of little
## flags so the park reads as "a place" from the spawn lawn
func _build_ground() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dirt: Color = Color(0.62, 0.5, 0.36)
	var dirt_dark: Color = Color(0.55, 0.44, 0.31)

	# Main straight (west -> east) along z = ORIGIN.y + 4
	_track(st, ORIGIN.x, ORIGIN.y + 3, ORIGIN.x + SIZE.x - 1, ORIGIN.y + 5, dirt)
	# East turn down to the lower straight
	_track(st, ORIGIN.x + SIZE.x - 3, ORIGIN.y + 6, ORIGIN.x + SIZE.x - 1, ORIGIN.y + 9, dirt)
	# Lower straight (east -> west) along z = ORIGIN.y + 10
	_track(st, ORIGIN.x, ORIGIN.y + 9, ORIGIN.x + SIZE.x - 1, ORIGIN.y + 11, dirt)
	# West connector back up to the start
	_track(st, ORIGIN.x, ORIGIN.y + 6, ORIGIN.x + 2, ORIGIN.y + 9, dirt_dark)

	# Border flags every few blocks (bright pinwheels on sticks)
	var flag_cols: Array[Color] = [Color(0.9, 0.3, 0.25), Color(1.0, 0.8, 0.25), Color(0.3, 0.6, 0.95), Color(0.35, 0.8, 0.45)]
	var fi: int = 0
	for x: int in range(ORIGIN.x, ORIGIN.x + SIZE.x, 4):
		for z: int in [ORIGIN.y, ORIGIN.y + SIZE.y - 1]:
			_flag(st, Vector3(float(x) + 0.5, 1.0, float(z) + 0.5), flag_cols[fi % flag_cols.size()])
			fi += 1
	for z: int in range(ORIGIN.y + 2, ORIGIN.y + SIZE.y - 2, 4):
		for x: int in [ORIGIN.x, ORIGIN.x + SIZE.x - 1]:
			_flag(st, Vector3(float(x) + 0.5, 1.0, float(z) + 0.5), flag_cols[fi % flag_cols.size()])
			fi += 1

	var mi := MeshInstance3D.new()
	mi.name = "ParkMesh"
	mi.mesh = st.commit()
	mi.material_override = VertexColorMaterial.make()
	add_child(mi)


func _track(st: SurfaceTool, x0: int, z0: int, x1: int, z1: int, color: Color) -> void:
	# Thin dirt slab, no collision: purely visual, the grass stays walkable
	var y: float = Config.GROUND_Y + 0.02
	SurfaceBoxes.add_box(st, Vector3(float(x0), y, float(z0)), Vector3(float(x1 + 1), y + 0.02, float(z1 + 1)), color, color.lightened(0.05))


func _flag(st: SurfaceTool, pos: Vector3, color: Color) -> void:
	# Pole
	SurfaceBoxes.add_box(st, pos + Vector3(-0.03, 0.0, -0.03), pos + Vector3(0.03, 1.3, 0.03), Color(0.85, 0.85, 0.88))
	# Pinwheel blades
	var top: Vector3 = pos + Vector3(0.0, 1.25, 0.0)
	SurfaceBoxes.add_box(st, top + Vector3(-0.22, -0.06, -0.02), top + Vector3(0.22, 0.0, 0.02), color)
	SurfaceBoxes.add_box(st, top + Vector3(-0.02, -0.22, -0.02), top + Vector3(0.02, 0.16, 0.02), color.lightened(0.2))


# ------------------------------------------------------------- station bits

func _add_static_box(size: Vector3, center: Vector3, color: Color, top_color: Color = Color(0, 0, 0, 0), with_collision: bool = true) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if top_color.a > 0.0:
		SurfaceBoxes.add_box(st, center - size * 0.5, center + size * 0.5, color, top_color)
	else:
		SurfaceBoxes.add_box(st, center - size * 0.5, center + size * 0.5, color)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = VertexColorMaterial.make()
	add_child(mi)

	if not with_collision:
		return
	var body := StaticBody3D.new()
	body.collision_layer = Config.PROP_COLLISION_LAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = center
	add_child(body)


## A sloped ramp as a rotated slab on a wedge-shaped collider (the
## collider is a box tilted to match the surface; the bike's capsule
## glides up it like up the bridge ramps)
func _add_ramp(base_center: Vector3, length: float, height: float, width: float, color: Color, facing: Vector3) -> void:
	var dir: Vector3 = facing.normalized()
	var angle: float = atan2(height, length)
	var slope_len: float = sqrt(length * length + height * height)

	# Visual: a tilted slab
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mid: Vector3 = base_center + Vector3.UP * (height * 0.5) + dir * (length * 0.5)
	var thickness: float = 0.18
	var mn := Vector3(-width * 0.5, -thickness, -slope_len * 0.5)
	var mx := Vector3(width * 0.5, 0.0, slope_len * 0.5)
	_tilted_box(st, mid, mn, mx, angle, color, color.lightened(0.1))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = VertexColorMaterial.make()
	add_child(mi)

	# Collider: a box tilted the same way, riding on the prop layer.
	# Set the LOCAL transform before adding to the tree (global_position
	# on a node outside the tree is an error and silently lands at the
	# origin); the park itself sits unrotated at the origin, so local
	# == global here. The box is thin and sits so its FRONT face is
	# buried below ground - a box collider that pokes out of the ground
	# presents a vertical lip the bike's box can't slide up.
	var body := StaticBody3D.new()
	body.collision_layer = Config.PROP_COLLISION_LAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# Thin slab; shifted so the slab's top surface passes exactly through
	# base (ground) and top (ground + height), with the whole underside
	# hidden below the slope
	box.size = Vector3(width, thickness, slope_len)
	shape.shape = box
	body.add_child(shape)
	# Euler order is YXZ: yaw first (align with `facing`), then pitch
	# around the local X so the slab climbs along its own +Z
	var yaw: float = atan2(dir.x, dir.z)
	var surface_mid: Vector3 = base_center + Vector3.UP * (height * 0.5) + dir * (length * 0.5)
	body.transform = Transform3D(Basis.from_euler(Vector3(-angle, yaw, 0.0)), surface_mid - Vector3.UP * (thickness * 0.5))
	add_child(body)


## Box whose +Z end is lifted by `angle` around the X axis (a ramp)
func _tilted_box(st: SurfaceTool, center: Vector3, mn: Vector3, mx: Vector3, angle: float, color: Color, top: Color) -> void:
	var basis: Basis = Basis(Vector3.RIGHT, -angle)
	var corners: Array[Vector3] = [
		Vector3(mn.x, mn.y, mn.z), Vector3(mx.x, mn.y, mn.z), Vector3(mx.x, mn.y, mx.z), Vector3(mn.x, mn.y, mx.z),
		Vector3(mn.x, mx.y, mn.z), Vector3(mx.x, mx.y, mn.z), Vector3(mx.x, mx.y, mx.z), Vector3(mn.x, mx.y, mx.z),
	]
	var w: Array[Vector3] = []
	for c: Vector3 in corners:
		w.append(center + basis * c)
	# top (y+), bottom, sides
	_quad(st, w[4], w[5], w[6], w[7], basis * Vector3.UP, top)
	_quad(st, w[0], w[3], w[2], w[1], basis * Vector3.DOWN, color)
	_quad(st, w[0], w[1], w[5], w[4], basis * Vector3(0, 0, -1), color)
	_quad(st, w[3], w[2], w[6], w[7], basis * Vector3(0, 0, 1), color)
	_quad(st, w[0], w[4], w[7], w[3], basis * Vector3(-1, 0, 0), color)
	_quad(st, w[1], w[2], w[6], w[5], basis * Vector3(1, 0, 0), color)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, color: Color) -> void:
	# Two triangles, wound for the given normal (CULL_DISABLED material)
	st.set_normal(n)
	st.set_color(color)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(d)


# ---------------------------------------------------------------- stations

## Trigger that only reacts to the bike (with the player riding it)
func _add_trigger(id: String, center: Vector3, size: Vector3, label_text: String) -> void:
	var area := Area3D.new()
	area.name = "Trigger_" + id
	area.collision_layer = 0
	# Bikes are CharacterBody3Ds on layer 1 (terrain layer) - see bicycle.gd
	area.collision_mask = 1
	area.monitoring = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	area.add_child(shape)
	area.position = center
	area.body_entered.connect(_on_trigger_entered.bind(id))
	add_child(area)
	_station_nodes[id] = area

	# Floating station sign
	var sign := Label3D.new()
	sign.name = "Sign_" + id
	sign.text = label_text
	sign.position = center + Vector3(0.0, size.y * 0.5 + 1.2, 0.0)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.font_size = 72
	sign.outline_size = 12
	sign.modulate = Color(1.0, 1.0, 1.0)
	sign.no_depth_test = true
	add_child(sign)

	# Check mark shown once the station is cleared
	var done := Label3D.new()
	done.name = "Done_" + id
	done.text = "✔ +%d 📚" % STATION_REWARD
	done.position = sign.position + Vector3(0.0, 0.6, 0.0)
	done.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	done.font_size = 64
	done.outline_size = 10
	done.modulate = Color(0.5, 1.0, 0.55)
	done.no_depth_test = true
	add_child(done)
	_done_labels[id] = done


func _on_trigger_entered(body: Node3D, id: String) -> void:
	if not (body is Bicycle):
		return
	if ProfileManager.is_bike_station_done(id):
		return
	ProfileManager.set_bike_station_done(id, true)
	var reward: int = FINISH_REWARD if id == "finish" else STATION_REWARD
	ProfileManager.add_points(reward)
	AudioManager.play_sfx(AudioManager.SFX.QUIZ_CORRECT if id != "finish" else AudioManager.SFX.UNLOCK)
	Effects.spawn_confetti(body.global_position + Vector3.UP * 1.0)
	var label: String = STATION_NAMES[STATION_IDS.find(id)] if STATION_IDS.has(id) else id
	Effects.spawn_floating_text(body.global_position + Vector3.UP * 1.8, "✔ %s +%d 📚" % [label, reward], Color(0.5, 1.0, 0.55))
	_refresh_marks()


func _refresh_marks() -> void:
	for id: String in _done_labels.keys():
		var done: Label3D = _done_labels[id]
		done.visible = ProfileManager.is_bike_station_done(id)


## 2 HOP: a low bar across the west connector that must be hopped
## over on the way back up to the finish arch (travel direction north)
func _build_hop() -> void:
	var cx: float = float(ORIGIN.x + 1) + 1.0 # center of the west connector
	var cz: float = float(ORIGIN.y + 6.5)
	var green: Color = Color(0.3, 0.65, 0.32)
	# Hedge bar spanning the connector width (fits inside x 0..3)
	_add_static_box(Vector3(2.8, HEDGE_BAR_H, 0.6), Vector3(cx, Config.GROUND_Y + HEDGE_BAR_H * 0.5, cz), green, green.lightened(0.15))
	# Trigger sits right behind the bar (cleared when you pass it)
	_add_trigger("hop", Vector3(cx, Config.GROUND_Y + 0.6, cz + 1.4), Vector3(3.0, 1.2, 0.6), "2 Hop!")


## 3 SLALOM: five cones in a zigzag along the east turn
func _build_slalom() -> void:
	var orange: Color = Color(0.95, 0.55, 0.2)
	var white: Color = Color(0.97, 0.97, 0.97)
	var x: float = float(ORIGIN.x + SIZE.x - 2) + 0.5
	var zs: Array[float] = [6.5, 7.5, 8.5, 9.5, 10.5]
	var side: float = -0.9
	for i: int in range(zs.size()):
		var z: float = float(ORIGIN.y) + zs[i]
		var px: float = x + side
		_cone(Vector3(px, Config.GROUND_Y, z), orange, white)
		side = -side
	# Trigger at the end of the weave
	_add_trigger("slalom", Vector3(x, Config.GROUND_Y + 0.6, float(ORIGIN.y) + 11.3), Vector3(3.0, 1.2, 0.6), "3 🔺 Slalom")


func _cone(pos: Vector3, color: Color, stripe: Color) -> void:
	# Visual: stacked shrinking boxes (blocky traffic cone)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	SurfaceBoxes.add_box(st, pos + Vector3(-0.3, 0.0, -0.3), pos + Vector3(0.3, 0.12, 0.3), color)
	SurfaceBoxes.add_box(st, pos + Vector3(-0.22, 0.12, -0.22), pos + Vector3(0.22, 0.3, 0.22), color)
	SurfaceBoxes.add_box(st, pos + Vector3(-0.17, 0.3, -0.17), pos + Vector3(0.17, 0.42, 0.17), stripe)
	SurfaceBoxes.add_box(st, pos + Vector3(-0.12, 0.42, -0.12), pos + Vector3(0.12, CONE_H, 0.12), color)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = VertexColorMaterial.make()
	add_child(mi)
	# No collider: knocking a cone over shouldn't stop the bike (kids!)


## 4 BALANCE: a narrow beam over a shallow pit
func _build_balance() -> void:
	var wood: Color = Color(0.55, 0.39, 0.23)
	var x0: float = float(ORIGIN.x + 4)
	var x1: float = float(ORIGIN.x + 8)
	var z: float = float(ORIGIN.y + 10) + 0.5
	var length: float = x1 - x0
	# Beam TOP sits at GROUND_Y + BEAM_Y; the slab is 0.2 thick
	var mid: Vector3 = Vector3((x0 + x1) * 0.5, Config.GROUND_Y + BEAM_Y - 0.1, z)
	_add_static_box(Vector3(length, 0.2, BEAM_W), mid, wood, wood.lightened(0.12))
	# Ramps up to the beam on both ends: each ramp's TOP touches the
	# beam end, its base is one ramp-length further out on the ground.
	# _add_ramp puts the top at base + facing * length, so the EAST ramp
	# (base right of the beam) climbs west and the WEST ramp climbs east.
	_add_ramp(Vector3(x1 + BALANCE_RAMP_LEN, Config.GROUND_Y, z), BALANCE_RAMP_LEN, BEAM_Y + RAMP_OVERLAP, BEAM_W, wood, Vector3(-1, 0, 0))
	_add_ramp(Vector3(x0 - BALANCE_RAMP_LEN, Config.GROUND_Y, z), BALANCE_RAMP_LEN, BEAM_Y + RAMP_OVERLAP, BEAM_W, wood, Vector3(1, 0, 0))
	# Shallow pit marking (visual only): darker soil under the beam
	_add_static_box(Vector3(length + BALANCE_RAMP_LEN * 2.0, 0.04, 2.4), Vector3((x0 + x1) * 0.5, Config.GROUND_Y + 0.01, z), Color(0.35, 0.27, 0.18), Color(0, 0, 0, 0), false)
	# Trigger after the beam (west end exit, on the ground)
	_add_trigger("balance", Vector3(x0 - BALANCE_RAMP_LEN - 1.2, Config.GROUND_Y + 0.8, z), Vector3(0.6, 1.6, 2.0), "4 🪵 Balance!")


## Helper for tests: kicker base x (east end), lip x, landing top x.
## z = jump_row_z().
static func jump_geometry() -> Vector3:
	var base_x: float = float(ORIGIN.x + 15) + 0.5
	return Vector3(base_x, base_x - RAMP_LEN, base_x - RAMP_LEN - JUMP_GAP)


## Helper for tests: the row the kicker sits on
static func jump_row_z() -> float:
	return float(ORIGIN.y + 4) + 0.5


## Helper for tests: world position of the balance beam top center
static func balance_beam_top_center() -> Vector3:
	var x0: float = float(ORIGIN.x + 4)
	var x1: float = float(ORIGIN.x + 8)
	return Vector3((x0 + x1) * 0.5, Config.GROUND_Y + BEAM_Y, float(ORIGIN.y + 10) + 0.5)


## 5 JUMP: kicker ramp, gap, landing ramp along the west connector
func _build_jump() -> void:
	var wood: Color = Color(0.72, 0.52, 0.32)
	var red: Color = Color(0.85, 0.3, 0.25)
	# Travel direction here is WEST along the UPPER straight (z +4),
	# east of the hop bar (hop sits at ORIGIN.x + 7). Kicker climbs
	# westwards from its base to the lip, then a gap, then a landing
	# ramp whose TOP is at the far side of the gap and descends west.
	var z: float = float(ORIGIN.y + 4) + 0.5
	var base_x: float = float(ORIGIN.x + 15) + 0.5
	var lip_x: float = base_x - RAMP_LEN
	var land_x: float = lip_x - JUMP_GAP
	_add_ramp(Vector3(base_x, Config.GROUND_Y, z), RAMP_LEN, RAMP_H, RAMP_W, wood, Vector3(-1, 0, 0))
	# Red lip marker at the TOP (take-off) end - visual only, a collider
	# here would be a wall right behind the ramp crest
	_add_static_box(Vector3(0.3, 0.3, RAMP_W), Vector3(lip_x + 0.15, Config.GROUND_Y + RAMP_H + 0.15, z), red, Color(0, 0, 0, 0), false)
	# Landing ramp: top at land_x, descending west to the ground
	_add_ramp(Vector3(land_x - RAMP_LEN, Config.GROUND_Y, z), RAMP_LEN, RAMP_H, RAMP_W, wood, Vector3(1, 0, 0))
	# Gap marker: red-white stripes on the ground (visual only)
	for i: int in range(3):
		_add_static_box(Vector3(0.6, 0.03, RAMP_W), Vector3(lip_x - 0.4 - float(i) * 0.7, Config.GROUND_Y + 0.02, z), red if i % 2 == 0 else Color.WHITE, Color(0, 0, 0, 0), false)
	# Trigger in the gap (cleared when airborne over it)
	_add_trigger("jump", Vector3((lip_x + land_x) * 0.5, Config.GROUND_Y + 1.0, z), Vector3(JUMP_GAP, 2.0, RAMP_W), "5 🚀 Sprung!")


## 6 FINISH: checkered arch at the west end of the course
func _build_finish() -> void:
	var z: float = float(ORIGIN.y + 8.5) + 0.5
	var x: float = float(ORIGIN.x + 1) + 1.0 # center of the 3-wide west connector
	var black: Color = Color(0.12, 0.12, 0.14)
	var white: Color = Color(0.95, 0.95, 0.95)
	# Course runs north here: pillars stand left and right (in X), the
	# checkered bar spans across the connector width (x 0..3)
	for dx: float in [-1.3, 1.3]:
		_add_static_box(Vector3(0.4, 2.6, 0.4), Vector3(x + dx, Config.GROUND_Y + 1.3, z), white)
	# Checkered top bar
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y0: float = Config.GROUND_Y + 2.6
	var n: int = 8
	var seg: float = 3.0 / float(n)
	for i: int in range(n):
		var c: Color = black if (i % 2 == 0) else white
		var xa: float = x - 1.5 + float(i) * seg
		SurfaceBoxes.add_box(st, Vector3(xa, y0, z - 0.25), Vector3(xa + seg, y0 + 0.5, z + 0.25), c)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = VertexColorMaterial.make()
	add_child(mi)
	# Trigger under the arch
	_add_trigger("finish", Vector3(x, Config.GROUND_Y + 1.0, z), Vector3(3.0, 2.0, 0.8), "6 🏁 Ziel")


## Start gate sign (visual only, no reward): checkered post pair
## at the course entrance on the main straight
func _build_start_marker() -> void:
	var z: float = float(ORIGIN.y + 4) + 0.5
	var x: float = float(ORIGIN.x + 1) + 1.0
	var black: Color = Color(0.12, 0.12, 0.14)
	var white: Color = Color(0.95, 0.95, 0.95)
	for dz: float in [-1.6, 1.6]:
		_add_static_box(Vector3(0.4, 1.8, 0.4), Vector3(x, Config.GROUND_Y + 0.9, z + dz), white)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i: int in range(3):
			var c: Color = black if i % 2 == 0 else white
			SurfaceBoxes.add_box(st, Vector3(x - 0.2, Config.GROUND_Y + 0.3 + float(i) * 0.5, z + dz - 0.2), Vector3(x + 0.2, Config.GROUND_Y + 0.8 + float(i) * 0.5, z + dz + 0.2), c)
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = VertexColorMaterial.make()
		add_child(mi)
