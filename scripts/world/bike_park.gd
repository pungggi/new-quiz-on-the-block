class_name BikePark
extends Node3D

## A real bicycle skill course WEST of the spawn lawn (36 x 32 blocks,
## 8-block-wide dirt lanes, generous corners). Five stations along a
## big loop, each paying a one-time education-point reward the first
## time the player clears it on the bike:
##
##   START      - checkered gate on the lane right next to the spawn lawn
##   1 SLALOM   - five cones, 4 blocks apart, down the north lane
##   2 HOP      - a low hedge bar across the east lane (hop key: Space)
##   3 JUMP     - kicker ramp, 3-block gap, landing ramp
##   4 BALANCE  - a wide wooden beam over a marked pit
##   5 FINISH   - checkered arch back at the start
##
## Every station is a trigger Area3D that watches the BIKE (riding the
## real player), so walking through on foot never collects anything.
## Rewards persist per profile: a station pays once, ever.

const ORIGIN: Vector2i = Vector2i(-50, 0) ## south-west corner: the park's east lane borders the spawn lawn
const SIZE: Vector2i = Vector2i(36, 32) ## park footprint in blocks

const LANE_W: int = 8 ## lane width in blocks (bike needs room to steer)
const STATION_REWARD: int = 10 ## education points per cleared station
const FINISH_REWARD: int = 25 ## course completion bonus

const HEDGE_BAR_H: float = 0.45 ## hop bar height (hop apex is ~1.1)
const CONE_H: float = 0.7
const CONE_SPACING: float = 4.0 ## slalom: blocks between cones
const BEAM_W: float = 1.6 ## wide enough to stay on with the capsule
const BEAM_Y: float = 0.9 ## beam top above ground
const BALANCE_RAMP_LEN: float = 3.0
const RAMP_OVERLAP: float = 0.03 ## ramps end a hair above the beam top
const RAMP_H: float = 1.0 ## kicker height
const RAMP_LEN: float = 3.5
const RAMP_W: float = 6.0 ## wide kicker: the whole lane
const JUMP_GAP: float = 2.2 ## gap between kicker lip and landing ramp (ride at speed 9 clears ~3)

const STATION_NAMES: Array[String] = ["Slalom", "Hop", "Balance", "Sprung", "Ziel"]
## Station ids as stored in the profile (stable strings, never rename)
const STATION_IDS: Array[String] = ["slalom", "hop", "balance", "jump", "finish"]

var _done_labels: Dictionary = {} ## id -> Label3D (check mark once cleared)


func _ready() -> void:
	_build_ground()
	_build_start_marker()
	_build_slalom()
	_build_hop()
	_build_jump()
	_build_balance()
	_build_finish()
	_refresh_marks()


## Static footprint test used by the build cursor and prop decoration
static func is_in_park(world_x: int, world_z: int) -> bool:
	var lx: int = world_x - ORIGIN.x
	var lz: int = world_z - ORIGIN.y
	return lx >= 0 and lx < SIZE.x and lz >= 0 and lz < SIZE.y


# ------------------------------------------------------------- lane geometry
# The loop runs counter-clockwise on three lanes:
#   north lane  z = ORIGIN.y + 24 .. +32  (east -> west)
#   west lane   x = ORIGIN.x .. +8        (north -> south)
#   south lane  z = ORIGIN.y .. +8        (west -> east)
#   east lane   x = ORIGIN.x + 28 .. +36  (south -> north)

static func north_lane_z() -> float: ## lane center
	return float(ORIGIN.y + 28)
static func south_lane_z() -> float:
	return float(ORIGIN.y + 4)
static func east_lane_x() -> float:
	return float(ORIGIN.x + 32)
static func west_lane_x() -> float:
	return float(ORIGIN.x + 4)


# ------------------------------------------------------------------ ground

func _build_ground() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dirt: Color = Color(0.62, 0.5, 0.36)
	var dirt_dark: Color = Color(0.55, 0.44, 0.31)
	var x0: int = ORIGIN.x
	var z0: int = ORIGIN.y
	var x1: int = ORIGIN.x + SIZE.x - 1
	var z1: int = ORIGIN.y + SIZE.y - 1
	# Three lanes forming a loop (the big infield stays grass)
	_track(st, x0, z1 - LANE_W + 1, x1, z1, dirt) # north
	_track(st, x0, z0, x0 + LANE_W - 1, z1, dirt) # west
	_track(st, x0, z0, x1, z0 + LANE_W - 1, dirt) # south
	_track(st, x1 - LANE_W + 1, z0, x1, z1, dirt) # east
	# Border pinwheels every 4 blocks
	var flag_cols: Array[Color] = [Color(0.9, 0.3, 0.25), Color(1.0, 0.8, 0.25), Color(0.3, 0.6, 0.95), Color(0.35, 0.8, 0.45)]
	var fi: int = 0
	for x: int in range(x0, x1 + 1, 4):
		for z: int in [z0, z1]:
			_flag(st, Vector3(float(x) + 0.5, 1.0, float(z) + 0.5), flag_cols[fi % flag_cols.size()])
			fi += 1
	for z: int in range(z0 + 4, z1 - 2, 4):
		for x: int in [x0, x1]:
			_flag(st, Vector3(float(x) + 0.5, 1.0, float(z) + 0.5), flag_cols[fi % flag_cols.size()])
			fi += 1
	var mi := MeshInstance3D.new()
	mi.name = "ParkMesh"
	mi.mesh = st.commit()
	mi.material_override = VertexColorMaterial.make()
	add_child(mi)


func _track(st: SurfaceTool, x0: int, z0: int, x1: int, z1: int, color: Color) -> void:
	var y: float = Config.GROUND_Y + 0.02
	SurfaceBoxes.add_box(st, Vector3(float(x0), y, float(z0)), Vector3(float(x1 + 1), y + 0.02, float(z1 + 1)), color, color.lightened(0.05))


func _flag(st: SurfaceTool, pos: Vector3, color: Color) -> void:
	SurfaceBoxes.add_box(st, pos + Vector3(-0.03, 0.0, -0.03), pos + Vector3(0.03, 1.3, 0.03), Color(0.85, 0.85, 0.88))
	var top: Vector3 = pos + Vector3(0.0, 1.25, 0.0)
	SurfaceBoxes.add_box(st, top + Vector3(-0.22, -0.06, -0.02), top + Vector3(0.22, 0.0, 0.02), color)
	SurfaceBoxes.add_box(st, top + Vector3(-0.02, -0.22, -0.02), top + Vector3(0.02, 0.16, 0.02), color.lightened(0.2))


# ------------------------------------------------------------- build blocks

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


## A sloped ramp: base_center is on the ground where the ramp starts,
## it climbs `height` over `length` along `facing`. The collider is a
## thin tilted box whose TOP surface runs from base to top (its front
## face is buried; the bike's capsule slides up).
func _add_ramp(base_center: Vector3, length: float, height: float, width: float, color: Color, facing: Vector3) -> void:
	var dir: Vector3 = facing.normalized()
	var angle: float = atan2(height, length)
	var slope_len: float = sqrt(length * length + height * height)
	var thickness: float = 0.18
	var mid: Vector3 = base_center + Vector3.UP * (height * 0.5) + dir * (length * 0.5)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_tilted_box(st, mid, Vector3(-width * 0.5, -thickness, -slope_len * 0.5), Vector3(width * 0.5, 0.0, slope_len * 0.5), angle, color, color.lightened(0.1))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = VertexColorMaterial.make()
	add_child(mi)

	var body := StaticBody3D.new()
	body.collision_layer = Config.PROP_COLLISION_LAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, thickness, slope_len)
	shape.shape = box
	body.add_child(shape)
	var yaw: float = atan2(dir.x, dir.z)
	body.transform = Transform3D(Basis.from_euler(Vector3(-angle, yaw, 0.0)), mid - Vector3.UP * (thickness * 0.5))
	add_child(body)


func _tilted_box(st: SurfaceTool, center: Vector3, mn: Vector3, mx: Vector3, angle: float, color: Color, top: Color) -> void:
	var basis: Basis = Basis(Vector3.RIGHT, -angle)
	var corners: Array[Vector3] = [
		Vector3(mn.x, mn.y, mn.z), Vector3(mx.x, mn.y, mn.z), Vector3(mx.x, mn.y, mx.z), Vector3(mn.x, mn.y, mx.z),
		Vector3(mn.x, mx.y, mn.z), Vector3(mx.x, mx.y, mn.z), Vector3(mx.x, mx.y, mx.z), Vector3(mn.x, mx.y, mx.z),
	]
	var w: Array[Vector3] = []
	for c: Vector3 in corners:
		w.append(center + basis * c)
	_quad(st, w[4], w[5], w[6], w[7], basis * Vector3.UP, top)
	_quad(st, w[0], w[3], w[2], w[1], basis * Vector3.DOWN, color)
	_quad(st, w[0], w[1], w[5], w[4], basis * Vector3(0, 0, -1), color)
	_quad(st, w[3], w[2], w[6], w[7], basis * Vector3(0, 0, 1), color)
	_quad(st, w[0], w[4], w[7], w[3], basis * Vector3(-1, 0, 0), color)
	_quad(st, w[1], w[2], w[6], w[5], basis * Vector3(1, 0, 0), color)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, color: Color) -> void:
	st.set_normal(n)
	st.set_color(color)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(d)


## Trigger that only reacts to the bike (with the player riding it)
func _add_trigger(id: String, center: Vector3, size: Vector3, label_text: String) -> void:
	var area := Area3D.new()
	area.name = "Trigger_" + id
	area.collision_layer = 0
	area.collision_mask = 1 ## bikes are CharacterBody3Ds on layer 1
	area.monitoring = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	area.add_child(shape)
	area.position = center
	area.body_entered.connect(_on_trigger_entered.bind(id))
	add_child(area)

	var sign := Label3D.new()
	sign.name = "Sign_" + id
	sign.text = label_text
	sign.position = center + Vector3(0.0, size.y * 0.5 + 2.2, 0.0)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.font_size = 96
	sign.outline_size = 14
	sign.modulate = Color(1.0, 1.0, 1.0)
	sign.no_depth_test = true
	add_child(sign)

	var done := Label3D.new()
	done.name = "Done_" + id
	done.text = "Done! +%d points" % STATION_REWARD
	done.position = sign.position + Vector3(0.0, 0.7, 0.0)
	done.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	done.font_size = 80
	done.outline_size = 12
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
	Effects.spawn_floating_text(body.global_position + Vector3.UP * 1.8, "%s +%d" % [label, reward], Color(0.5, 1.0, 0.55))
	_refresh_marks()


func _refresh_marks() -> void:
	for id: String in _done_labels.keys():
		var done: Label3D = _done_labels[id]
		done.visible = ProfileManager.is_bike_station_done(id)


# ---------------------------------------------------------------- stations

## 1 SLALOM: five cones zigzagging along the north lane (travel: east -> west)
func _build_slalom() -> void:
	var orange: Color = Color(0.95, 0.55, 0.2)
	var white: Color = Color(0.97, 0.97, 0.97)
	var z: float = north_lane_z()
	var x_start: float = float(ORIGIN.x + 26)
	var side: float = -2.5 ## +- 2.5 from the lane center: 5 blocks swing
	for i: int in range(5):
		_cone(Vector3(x_start - float(i) * CONE_SPACING, Config.GROUND_Y, z + side), orange, white)
		side = -side
	# Trigger after the last cone (west of it)
	_add_trigger("slalom", Vector3(x_start - 4.0 * CONE_SPACING - 2.5, Config.GROUND_Y + 0.8, z), Vector3(1.0, 1.6, LANE_W), "1 Slalom")


## 2 HOP: a low bar right across the east lane (travel: south -> north)
func _build_hop() -> void:
	var cx: float = east_lane_x()
	var cz: float = float(ORIGIN.y + 16)
	var green: Color = Color(0.3, 0.65, 0.32)
	_add_static_box(Vector3(LANE_W - 1.0, HEDGE_BAR_H, 0.6), Vector3(cx, Config.GROUND_Y + HEDGE_BAR_H * 0.5, cz), green, green.lightened(0.15))
	_add_trigger("hop", Vector3(cx, Config.GROUND_Y + 0.6, cz + 1.6), Vector3(LANE_W - 1.0, 1.2, 0.8), "2 Hop!")


## 3 JUMP: kicker, gap, landing along the south lane (travel: west -> east)
func _build_jump() -> void:
	var wood: Color = Color(0.72, 0.52, 0.32)
	var red: Color = Color(0.85, 0.3, 0.25)
	var z: float = south_lane_z()
	var base_x: float = float(ORIGIN.x + 14)
	var lip_x: float = base_x + RAMP_LEN ## climbs eastwards (+X)
	var land_x: float = lip_x + JUMP_GAP
	_add_ramp(Vector3(base_x, Config.GROUND_Y, z), RAMP_LEN, RAMP_H, RAMP_W, wood, Vector3(1, 0, 0))
	_add_static_box(Vector3(0.3, 0.3, RAMP_W), Vector3(lip_x - 0.15, Config.GROUND_Y + RAMP_H + 0.15, z), red, Color(0, 0, 0, 0), false)
	# Landing ramp: top at land_x, descending eastwards
	_add_ramp(Vector3(land_x + RAMP_LEN, Config.GROUND_Y, z), RAMP_LEN, RAMP_H, RAMP_W, wood, Vector3(-1, 0, 0))
	for i: int in range(3):
		_add_static_box(Vector3(0.6, 0.03, RAMP_W), Vector3(lip_x + 0.5 + float(i) * 0.8, Config.GROUND_Y + 0.02, z), red if i % 2 == 0 else Color.WHITE, Color(0, 0, 0, 0), false)
	_add_trigger("jump", Vector3((lip_x + land_x) * 0.5, Config.GROUND_Y + 1.0, z), Vector3(JUMP_GAP, 2.2, RAMP_W), "3 Jump!")


## 4 BALANCE: a wide beam over a marked pit on the south lane, east of the jump
func _build_balance() -> void:
	var wood: Color = Color(0.55, 0.39, 0.23)
	var z: float = south_lane_z()
	var x0: float = float(ORIGIN.x + 27)
	var x1: float = float(ORIGIN.x + 31)
	var length: float = x1 - x0
	var mid: Vector3 = Vector3((x0 + x1) * 0.5, Config.GROUND_Y + BEAM_Y - 0.1, z)
	_add_static_box(Vector3(length, 0.2, BEAM_W), mid, wood, wood.lightened(0.12))
	_add_ramp(Vector3(x0 - BALANCE_RAMP_LEN, Config.GROUND_Y, z), BALANCE_RAMP_LEN, BEAM_Y + RAMP_OVERLAP, BEAM_W, wood, Vector3(1, 0, 0))
	_add_ramp(Vector3(x1 + BALANCE_RAMP_LEN, Config.GROUND_Y, z), BALANCE_RAMP_LEN, BEAM_Y + RAMP_OVERLAP, BEAM_W, wood, Vector3(-1, 0, 0))
	_add_static_box(Vector3(length + BALANCE_RAMP_LEN * 2.0, 0.04, 3.0), Vector3((x0 + x1) * 0.5, Config.GROUND_Y + 0.01, z), Color(0.35, 0.27, 0.18), Color(0, 0, 0, 0), false)
	_add_trigger("balance", Vector3(x1 + BALANCE_RAMP_LEN + 1.5, Config.GROUND_Y + 0.8, z), Vector3(1.0, 1.6, LANE_W), "4 Balance")


func _cone(pos: Vector3, color: Color, stripe: Color) -> void:
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


## 5 FINISH: checkered arch across the east lane near the north-east corner
func _build_finish() -> void:
	var z: float = float(ORIGIN.y + 24) + 0.5
	var x: float = east_lane_x()
	var black: Color = Color(0.12, 0.12, 0.14)
	var white: Color = Color(0.95, 0.95, 0.95)
	var half: float = 3.6 ## 7.2 gap between pillars: nearly the full lane
	for dx: float in [-half, half]:
		_add_static_box(Vector3(0.5, 2.8, 0.5), Vector3(x + dx, Config.GROUND_Y + 1.4, z), white)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y0: float = Config.GROUND_Y + 2.8
	var n: int = 10
	var total: float = half * 2.0 + 0.5
	var seg: float = total / float(n)
	for i: int in range(n):
		var c: Color = black if (i % 2 == 0) else white
		var xa: float = x - total * 0.5 + float(i) * seg
		SurfaceBoxes.add_box(st, Vector3(xa, y0, z - 0.25), Vector3(xa + seg, y0 + 0.5, z + 0.25), c)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = VertexColorMaterial.make()
	add_child(mi)
	_add_trigger("finish", Vector3(x, Config.GROUND_Y + 1.0, z), Vector3(half * 2.0, 2.0, 0.8), "5 Finish")


## START gate sign (visual only, no reward) where the loop begins:
## south lane right at the spawn-facing edge of the park
func _build_start_marker() -> void:
	var z: float = south_lane_z()
	var x: float = float(ORIGIN.x + 1) + 0.5
	var black: Color = Color(0.12, 0.12, 0.14)
	var white: Color = Color(0.95, 0.95, 0.95)
	for dz: float in [-3.4, 3.4]:
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


# ------------------------------------------------------------ test helpers

static func balance_beam_top_center() -> Vector3:
	var x0: float = float(ORIGIN.x + 27)
	var x1: float = float(ORIGIN.x + 31)
	return Vector3((x0 + x1) * 0.5, Config.GROUND_Y + BEAM_Y, south_lane_z())


## x: kicker base, y: lip, z: landing top. z-row: south_lane_z()
static func jump_geometry() -> Vector3:
	var base_x: float = float(ORIGIN.x + 14)
	return Vector3(base_x, base_x + RAMP_LEN, base_x + RAMP_LEN + JUMP_GAP)
