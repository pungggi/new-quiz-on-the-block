extends RefCounted
class_name BuildingMeshGenerator

## Procedural Building Mesh Generator
## Creates detailed voxel-style meshes for buildings

const WINDOW_SIZE: Vector2 = Vector2(0.25, 0.3)
const WINDOW_DEPTH: float = 0.05
const DOOR_WIDTH: float = 0.35
const DOOR_HEIGHT: float = 0.6
const ROOF_OVERHANG: float = 0.1
const ROOF_HEIGHT: float = 0.4


#region Core Box Helper - Must be first!
static func _add_box(st: SurfaceTool, o: Vector3, s: Vector3) -> void:
	var x1: float = o.x; var y1: float = o.y; var z1: float = o.z
	var x2: float = o.x + s.x; var y2: float = o.y + s.y; var z2: float = o.z + s.z
	# Top
	st.add_vertex(Vector3(x1, y2, z1)); st.add_vertex(Vector3(x2, y2, z1)); st.add_vertex(Vector3(x2, y2, z2))
	st.add_vertex(Vector3(x1, y2, z1)); st.add_vertex(Vector3(x2, y2, z2)); st.add_vertex(Vector3(x1, y2, z2))
	# Bottom
	st.add_vertex(Vector3(x2, y1, z1)); st.add_vertex(Vector3(x1, y1, z1)); st.add_vertex(Vector3(x1, y1, z2))
	st.add_vertex(Vector3(x2, y1, z1)); st.add_vertex(Vector3(x1, y1, z2)); st.add_vertex(Vector3(x2, y1, z2))
	# Front (+Z)
	st.add_vertex(Vector3(x1, y1, z2)); st.add_vertex(Vector3(x1, y2, z2)); st.add_vertex(Vector3(x2, y2, z2))
	st.add_vertex(Vector3(x1, y1, z2)); st.add_vertex(Vector3(x2, y2, z2)); st.add_vertex(Vector3(x2, y1, z2))
	# Back (-Z)
	st.add_vertex(Vector3(x2, y1, z1)); st.add_vertex(Vector3(x2, y2, z1)); st.add_vertex(Vector3(x1, y2, z1))
	st.add_vertex(Vector3(x2, y1, z1)); st.add_vertex(Vector3(x1, y2, z1)); st.add_vertex(Vector3(x1, y1, z1))
	# Right (+X)
	st.add_vertex(Vector3(x2, y1, z1)); st.add_vertex(Vector3(x2, y1, z2)); st.add_vertex(Vector3(x2, y2, z2))
	st.add_vertex(Vector3(x2, y1, z1)); st.add_vertex(Vector3(x2, y2, z2)); st.add_vertex(Vector3(x2, y2, z1))
	# Left (-X)
	st.add_vertex(Vector3(x1, y1, z2)); st.add_vertex(Vector3(x1, y1, z1)); st.add_vertex(Vector3(x1, y2, z1))
	st.add_vertex(Vector3(x1, y1, z2)); st.add_vertex(Vector3(x1, y2, z1)); st.add_vertex(Vector3(x1, y2, z2))
#endregion


#region Window/Door Helpers
static func _add_windows_row(st: SurfaceTool, pos: Vector3, width: float, col: Color, front: bool) -> void:
	st.set_color(col)
	var count: int = maxi(1, int(width / 0.6))
	var spacing: float = width / float(count)
	for i in range(count):
		var wx: float = pos.x + spacing * 0.5 + spacing * float(i) - WINDOW_SIZE.x * 0.5
		var wz: float = pos.z + (0.01 if front else -0.01)
		var z_off: float = 0.0 if front else WINDOW_DEPTH
		_add_box(st, Vector3(wx, pos.y, wz - z_off), Vector3(WINDOW_SIZE.x, WINDOW_SIZE.y, WINDOW_DEPTH))

static func _add_large_windows(st: SurfaceTool, pos: Vector3, width: float, col: Color, front: bool) -> void:
	st.set_color(col)
	var count: int = maxi(1, int(width / 0.8))
	var spacing: float = width / float(count)
	var lw: float = WINDOW_SIZE.x * 1.5; var lh: float = WINDOW_SIZE.y * 1.3
	for i in range(count):
		var wx: float = pos.x + spacing * 0.5 + spacing * float(i) - lw * 0.5
		var wz: float = pos.z + (0.01 if front else -0.01)
		var z_off: float = 0.0 if front else WINDOW_DEPTH
		_add_box(st, Vector3(wx, pos.y, wz - z_off), Vector3(lw, lh, WINDOW_DEPTH))

static func _add_storefront(st: SurfaceTool, pos: Vector3, width: float, col: Color) -> void:
	st.set_color(col)
	var sw: float = width * 0.7
	_add_box(st, Vector3(pos.x + (width - sw) * 0.5, pos.y + 0.15, pos.z + 0.01), Vector3(sw, 0.7, WINDOW_DEPTH))

static func _add_side_windows_row(st: SurfaceTool, pos: Vector3, depth: float, col: Color, right: bool) -> void:
	st.set_color(col)
	var count: int = maxi(1, int(depth / 0.6))
	var spacing: float = depth / float(count)
	for i in range(count):
		var wz: float = pos.z + spacing * 0.5 + spacing * float(i) - WINDOW_SIZE.x * 0.5
		var wx: float = pos.x + (0.01 if right else -0.01)
		var x_off: float = 0.0 if right else WINDOW_DEPTH
		_add_box(st, Vector3(wx - x_off, pos.y, wz), Vector3(WINDOW_DEPTH, WINDOW_SIZE.y, WINDOW_SIZE.x))

static func _add_door(st: SurfaceTool, pos: Vector3, col: Color) -> void:
	st.set_color(col.darkened(0.3))
	_add_box(st, Vector3(pos.x, pos.y, pos.z + 0.01), Vector3(DOOR_WIDTH, DOOR_HEIGHT, WINDOW_DEPTH))

static func _add_double_door(st: SurfaceTool, pos: Vector3, col: Color) -> void:
	st.set_color(col.darkened(0.3))
	_add_box(st, Vector3(pos.x, pos.y, pos.z + 0.01), Vector3(DOOR_WIDTH * 2, DOOR_HEIGHT * 1.1, WINDOW_DEPTH))

static func _add_awning(st: SurfaceTool, pos: Vector3, width: float, col: Color) -> void:
	st.set_color(col)
	_add_box(st, Vector3(pos.x + 0.1, pos.y, pos.z), Vector3(width - 0.2, 0.05, 0.4))

static func _add_steps(st: SurfaceTool, pos: Vector3, width: float, col: Color) -> void:
	st.set_color(col)
	_add_box(st, Vector3(pos.x - 0.1, 0, pos.z), Vector3(width + 0.2, 0.05, 0.2))
	_add_box(st, Vector3(pos.x - 0.05, 0.05, pos.z), Vector3(width + 0.1, 0.05, 0.1))

static func _add_ledge(st: SurfaceTool, pos: Vector3, size: Vector3, col: Color) -> void:
	st.set_color(col)
	var ld: float = 0.05
	var lh: float = 0.1
	_add_box(st, Vector3(pos.x - 0.02, pos.y, pos.z + size.z), Vector3(size.x + 0.04, lh, ld))
	_add_box(st, Vector3(pos.x - 0.02, pos.y, pos.z - ld), Vector3(size.x + 0.04, lh, ld))
	_add_box(st, Vector3(pos.x - ld, pos.y, pos.z - ld), Vector3(ld, lh, size.z + ld * 2))
	_add_box(st, Vector3(pos.x + size.x, pos.y, pos.z - ld), Vector3(ld, lh, size.z + ld * 2))

static func _add_pillars(st: SurfaceTool, pos: Vector3, size: Vector3, col: Color) -> void:
	st.set_color(col)
	var pw: float = 0.15
	_add_box(st, Vector3(pos.x - 0.02, pos.y, pos.z - 0.02), Vector3(pw, size.y, pw))
	_add_box(st, Vector3(pos.x + size.x - pw + 0.02, pos.y, pos.z - 0.02), Vector3(pw, size.y, pw))
	_add_box(st, Vector3(pos.x - 0.02, pos.y, pos.z + size.z - pw + 0.02), Vector3(pw, size.y, pw))
	_add_box(st, Vector3(pos.x + size.x - pw + 0.02, pos.y, pos.z + size.z - pw + 0.02), Vector3(pw, size.y, pw))
#endregion


#region Roof Helpers
static func _add_pitched_roof(st: SurfaceTool, pos: Vector3, size: Vector3, col: Color) -> void:
	st.set_color(col)
	var oh: float = ROOF_OVERHANG; var pk: float = ROOF_HEIGHT
	var p1 := Vector3(pos.x - oh, pos.y, pos.z - oh)
	var p2 := Vector3(pos.x - oh, pos.y, pos.z + size.z + oh)
	var p3 := Vector3(pos.x + size.x * 0.5, pos.y + pk, pos.z + size.z + oh)
	var p4 := Vector3(pos.x + size.x * 0.5, pos.y + pk, pos.z - oh)
	st.add_vertex(p1); st.add_vertex(p2); st.add_vertex(p3)
	st.add_vertex(p1); st.add_vertex(p3); st.add_vertex(p4)
	var p5 := Vector3(pos.x + size.x + oh, pos.y, pos.z + size.z + oh)
	var p6 := Vector3(pos.x + size.x + oh, pos.y, pos.z - oh)
	st.add_vertex(p5); st.add_vertex(p6); st.add_vertex(p4)
	st.add_vertex(p5); st.add_vertex(p4); st.add_vertex(p3)
	# Gables
	st.add_vertex(Vector3(pos.x - oh, pos.y, pos.z + size.z + oh))
	st.add_vertex(Vector3(pos.x + size.x + oh, pos.y, pos.z + size.z + oh))
	st.add_vertex(Vector3(pos.x + size.x * 0.5, pos.y + pk, pos.z + size.z + oh))
	st.add_vertex(Vector3(pos.x + size.x + oh, pos.y, pos.z - oh))
	st.add_vertex(Vector3(pos.x - oh, pos.y, pos.z - oh))
	st.add_vertex(Vector3(pos.x + size.x * 0.5, pos.y + pk, pos.z - oh))


static func _add_flat_roof_edge(st: SurfaceTool, pos: Vector3, size: Vector3, col: Color) -> void:
	st.set_color(col)
	var eh: float = 0.15; var ew: float = 0.08
	_add_box(st, Vector3(pos.x, pos.y, pos.z + size.z - ew), Vector3(size.x, eh, ew))
	_add_box(st, Vector3(pos.x, pos.y, pos.z), Vector3(size.x, eh, ew))
	_add_box(st, Vector3(pos.x, pos.y, pos.z), Vector3(ew, eh, size.z))
	_add_box(st, Vector3(pos.x + size.x - ew, pos.y, pos.z), Vector3(ew, eh, size.z))

static func _add_roof_details(st: SurfaceTool, pos: Vector3, size: Vector3) -> void:
	st.set_color(Color.DIM_GRAY)
	if size.x > 0.8 and size.z > 0.8:
		# Main AC unit
		_add_box(st, Vector3(pos.x + size.x * 0.2, pos.y, pos.z + size.z * 0.2), Vector3(0.4, 0.3, 0.4))
		# AC unit fan details (darker)
		st.set_color(Color(0.2, 0.2, 0.2))
		_add_box(st, Vector3(pos.x + size.x * 0.2 + 0.05, pos.y + 0.3, pos.z + size.z * 0.2 + 0.05), Vector3(0.3, 0.02, 0.3))
	st.set_color(Color.DIM_GRAY)
	if size.x > 1.2 and size.z > 1.2:
		# Chimney / vent stack
		_add_box(st, Vector3(pos.x + size.x * 0.7, pos.y, pos.z + size.z * 0.6), Vector3(0.2, 0.5, 0.2))
		_add_box(st, Vector3(pos.x + size.x * 0.68, pos.y + 0.45, pos.z + size.z * 0.58), Vector3(0.24, 0.05, 0.24))

static func _add_foundation(st: SurfaceTool, size: Vector3) -> void:
	st.set_color(Color.DARK_GRAY.darkened(0.4))
	var foh: float = 0.05
	_add_box(st, Vector3(-foh, 0, -foh), Vector3(size.x + foh * 2, 0.1, size.z + foh * 2))
#endregion


#region Main Generator
static func generate(building: BuildingData, level: int = 0) -> ArrayMesh:
	var st_body := SurfaceTool.new()
	st_body.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_win := SurfaceTool.new()
	st_win.begin(Mesh.PRIMITIVE_TRIANGLES)

	var size: Vector3 = Vector3(building.size)
	var primary: Color = building.color
	var secondary: Color = building.secondary_color

	# Apply color tint based on level
	primary = _apply_level_tint(primary, level)
	secondary = _apply_level_tint(secondary, level)

	match building.category:
		"residential":
			_generate_residential(st_body, st_win, size, primary, secondary)
		"commercial":
			_generate_commercial(st_body, st_win, size, primary, secondary)
		"education":
			_generate_education(st_body, st_win, size, primary, secondary)
		"infrastructure":
			if building.display_name == "Straßenlampe":
				_generate_street_lamp(st_body, st_win, size, primary, secondary)
			else:
				_generate_infrastructure(st_body, st_win, size, primary, secondary)
		_:
			_generate_default(st_body, st_win, size, primary, secondary)

	st_body.generate_normals()
	st_win.generate_normals()

	var mesh := ArrayMesh.new()
	st_body.commit(mesh)
	st_win.commit(mesh)
	return mesh


## Apply color tint based on building level
static func _apply_level_tint(color: Color, level: int) -> Color:
	match level:
		0:
			# Level 0: dark/locked appearance (55% brightness)
			return color * 0.55
		1:
			# Level 1: normal appearance (100% brightness)
			return color * 1.0
		_:
			# Level 2+: bright/upgraded appearance (130% brightness, clamped)
			var tinted := color * 1.3
			tinted.a = color.a  # Preserve alpha
			return tinted
#endregion


#region Building Type Generators
static func _generate_residential(st_body: SurfaceTool, st_win: SurfaceTool, size: Vector3, primary: Color, secondary: Color) -> void:
	_add_foundation(st_body, size)
	st_body.set_color(primary)
	_add_box(st_body, Vector3.ZERO, size)

	_add_pillars(st_body, Vector3.ZERO, size, secondary.darkened(0.1))

	for floor_idx in range(int(size.y)):
		var y_pos: float = float(floor_idx) + 0.35
		_add_windows_row(st_win, Vector3(0, y_pos, size.z), size.x, secondary, true)
		_add_windows_row(st_win, Vector3(0, y_pos, 0), size.x, secondary, false)
		_add_side_windows_row(st_win, Vector3(size.x, y_pos, 0), size.z, secondary, true)
		_add_side_windows_row(st_win, Vector3(0, y_pos, 0), size.z, secondary, false)

		if floor_idx > 0:
			_add_ledge(st_body, Vector3(0, float(floor_idx), 0), size, secondary.darkened(0.2))

	var door_pos := Vector3(size.x * 0.5 - DOOR_WIDTH * 0.5, 0, size.z)
	_add_door(st_win, door_pos, secondary)
	_add_steps(st_body, door_pos, DOOR_WIDTH, secondary.darkened(0.2))

	if size.y <= 2 and size.x <= 2:
		_add_pitched_roof(st_body, Vector3(0, size.y, 0), size, secondary)
	else:
		_add_flat_roof_edge(st_body, Vector3(0, size.y, 0), size, secondary.darkened(0.2))


static func _generate_commercial(st_body: SurfaceTool, st_win: SurfaceTool, size: Vector3, primary: Color, secondary: Color) -> void:
	_add_foundation(st_body, size)
	st_body.set_color(primary)
	_add_box(st_body, Vector3.ZERO, size)
	_add_storefront(st_win, Vector3(0, 0, size.z), size.x, secondary)

	_add_pillars(st_body, Vector3.ZERO, size, primary.darkened(0.15))

	for floor_idx in range(1, int(size.y)):
		var y_pos: float = float(floor_idx) + 0.35
		_add_windows_row(st_win, Vector3(0, y_pos, size.z), size.x, secondary, true)
		_add_windows_row(st_win, Vector3(0, y_pos, 0), size.x, secondary, false)
		_add_side_windows_row(st_win, Vector3(size.x, y_pos, 0), size.z, secondary, true)
		_add_side_windows_row(st_win, Vector3(0, y_pos, 0), size.z, secondary, false)

		_add_ledge(st_body, Vector3(0, float(floor_idx), 0), size, secondary.darkened(0.1))

	var door_pos := Vector3(size.x * 0.5 - DOOR_WIDTH * 0.5, 0, size.z)
	_add_steps(st_body, door_pos, DOOR_WIDTH, primary.darkened(0.3))

	_add_awning(st_body, Vector3(0, 1.0, size.z), size.x, secondary.darkened(0.2))
	_add_flat_roof_edge(st_body, Vector3(0, size.y, 0), size, secondary.darkened(0.2))
	_add_roof_details(st_body, Vector3(0, size.y, 0), size)


static func _generate_education(st_body: SurfaceTool, st_win: SurfaceTool, size: Vector3, primary: Color, secondary: Color) -> void:
	_add_foundation(st_body, size)
	st_body.set_color(primary)
	_add_box(st_body, Vector3.ZERO, size)

	_add_pillars(st_body, Vector3.ZERO, size, secondary)

	for floor_idx in range(int(size.y)):
		var y_pos: float = float(floor_idx) + 0.25
		_add_large_windows(st_win, Vector3(0, y_pos, size.z), size.x, secondary, true)
		_add_large_windows(st_win, Vector3(0, y_pos, 0), size.x, secondary, false)

		if floor_idx > 0:
			_add_ledge(st_body, Vector3(0, float(floor_idx), 0), size, primary.darkened(0.2))

	var door_pos := Vector3(size.x * 0.5 - DOOR_WIDTH, 0, size.z)
	_add_double_door(st_win, door_pos, secondary)
	_add_steps(st_body, door_pos, DOOR_WIDTH * 2, secondary.darkened(0.1))

	_add_flat_roof_edge(st_body, Vector3(0, size.y, 0), size, secondary)
	_add_roof_details(st_body, Vector3(0, size.y, 0), size)


static func _generate_infrastructure(st_body: SurfaceTool, _st_win: SurfaceTool, size: Vector3, primary: Color, secondary: Color) -> void:
	var height: float = 0.15
	st_body.set_color(primary)
	_add_box(st_body, Vector3.ZERO, Vector3(size.x, height, size.z))

	if size.x > 1 or size.z > 1:
		st_body.set_color(secondary)
		for x in range(int(size.x)):
			for z in range(int(size.z)):
				if (x + z) % 2 == 0:
					_add_box(st_body, Vector3(x + 0.1, height + 0.01, z + 0.1), Vector3(0.8, 0.01, 0.8))


static func _generate_default(st_body: SurfaceTool, st_win: SurfaceTool, size: Vector3, primary: Color, secondary: Color) -> void:
	_add_foundation(st_body, size)
	st_body.set_color(primary)
	_add_box(st_body, Vector3.ZERO, size)

	_add_pillars(st_body, Vector3.ZERO, size, primary.darkened(0.2))

	for floor_idx in range(int(size.y)):
		var y_pos: float = float(floor_idx) + 0.35
		_add_windows_row(st_win, Vector3(0, y_pos, size.z), size.x, secondary, true)
		_add_windows_row(st_win, Vector3(0, y_pos, 0), size.x, secondary, false)
		_add_side_windows_row(st_win, Vector3(size.x, y_pos, 0), size.z, secondary, true)
		_add_side_windows_row(st_win, Vector3(0, y_pos, 0), size.z, secondary, false)

		if floor_idx > 0:
			_add_ledge(st_body, Vector3(0, float(floor_idx), 0), size, secondary.darkened(0.2))

	_add_flat_roof_edge(st_body, Vector3(0, size.y, 0), size, secondary.darkened(0.2))
	_add_roof_details(st_body, Vector3(0, size.y, 0), size)


static func _generate_street_lamp(st_body: SurfaceTool, _st_win: SurfaceTool, _size: Vector3, primary: Color, _secondary: Color) -> void:
	# Base slab (infrastructure height)
	st_body.set_color(primary.darkened(0.3))
	_add_box(st_body, Vector3(0.3, 0.0, 0.3), Vector3(0.4, 0.05, 0.4))
	# Pole
	st_body.set_color(primary)
	_add_box(st_body, Vector3(0.45, 0.05, 0.45), Vector3(0.1, 1.8, 0.1))
	# Lamp head - horizontal arm
	st_body.set_color(primary)
	_add_box(st_body, Vector3(0.45, 1.85, 0.0), Vector3(0.1, 0.07, 0.5))
	# Lamp bulb housing (warm yellow)
	st_body.set_color(Color(0.9, 0.85, 0.6))
	_add_box(st_body, Vector3(0.4, 1.72, 0.05), Vector3(0.2, 0.13, 0.2))
#endregion
