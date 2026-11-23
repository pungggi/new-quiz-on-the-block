extends Node3D

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var _grass_multimesh: MultiMeshInstance3D
static var _detail_mesh: BoxMesh
static var _detail_material: StandardMaterial3D

var chunk_x: int = 0
var chunk_z: int = 0

## Water fills the column up to WorldManager.WATER_SURFACE_MAX_Y (flat,
## calm water line; the bed slopes beneath it)
## (river shallower than the open sea)

## Collision body reference for rebuilding
var _collision_body: StaticBody3D = null

## Separate water mesh (own material, NO collision - shallow paddling water)
var _water_mesh_instance: MeshInstance3D = null

# Terrain material (shared across all chunks, vertex colors pick the type)
static var _terrain_material: StandardMaterial3D
static var _water_material: StandardMaterial3D

## Vertex color per voxel type (multiplied with the noise texture)
const VOXEL_COLORS: Dictionary = {
	Config.VoxelType.GRASS: Color(0.33, 0.65, 0.25),
	Config.VoxelType.SAND: Color(0.87, 0.80, 0.55),
	Config.VoxelType.STONE: Color(0.55, 0.55, 0.58),
	Config.VoxelType.DIRT: Color(0.45, 0.33, 0.22),
}


func _ready() -> void:
	_setup_material()
	_build_mesh()
	_add_collision()


## Rebuild the chunk mesh after voxel data has changed
func rebuild_mesh() -> void:
	_build_mesh()
	_update_collision_shape()


func _setup_material() -> void:
	# Create shared terrain material only once. Vertex colors select the
	# voxel type color; backface culling is off so chunk border walls are
	# visible from outside the world (no winding surprises on side faces).
	if not _terrain_material:
		_terrain_material = StandardMaterial3D.new()
		_terrain_material.vertex_color_use_as_albedo = true
		_terrain_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_terrain_material.roughness = 0.9
		_terrain_material.metallic = 0.0

		# Subtle noise texture over all terrain colors
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		noise.frequency = 0.05
		noise.fractal_octaves = 3

		var gradient := Gradient.new()
		gradient.set_color(0, Color(0.8, 0.8, 0.8))
		gradient.set_color(1, Color(1.1, 1.1, 1.1))

		var noise_texture := NoiseTexture2D.new()
		noise_texture.noise = noise
		noise_texture.seamless = true
		noise_texture.color_ramp = gradient

		_terrain_material.albedo_texture = noise_texture
		_terrain_material.uv1_triplanar = true
		_terrain_material.uv1_scale = Vector3(0.2, 0.2, 0.2)

		# Water material: translucent, calm blue
		_water_material = StandardMaterial3D.new()
		_water_material.albedo_color = Color(0.25, 0.55, 0.85, 0.6)
		_water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_water_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_water_material.roughness = 0.15
		_water_material.metallic = 0.1

		# Grass blade details
		_detail_material = StandardMaterial3D.new()
		_detail_material.albedo_color = Color(0.45, 0.85, 0.35)
		_detail_material.roughness = 0.9

		_detail_mesh = BoxMesh.new()
		_detail_mesh.size = Vector3(0.12, 0.25, 0.12)
		_detail_mesh.material = _detail_material

	mesh_instance.material_override = _terrain_material


func _build_mesh() -> void:
	var data: PackedByteArray = WorldManager.get_chunk_data(chunk_x, chunk_z)
	if data.is_empty():
		push_warning("Chunk (%d, %d): No data found from WorldManager!" % [chunk_x, chunk_z])
		return

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var water_st := SurfaceTool.new()
	water_st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var size := Config.CHUNK_SIZE
	var height := Config.CHUNK_HEIGHT
	var detail_transforms: Array[Transform3D] = []
	var water_faces: int = 0

	for x in range(size):
		for z in range(size):
			var base_x := x + chunk_x * size
			var base_z := z + chunk_z * size

			# Column top: highest solid voxel; water voxel sits above it
			var col_h: int = 0
			var has_water: bool = false
			for y in range(height - 1, -1, -1):
				var index: int = x + z * size + y * size * size
				var voxel: int = data[index]
				if voxel == Config.VoxelType.WATER:
					has_water = true
					continue
				if voxel != Config.VoxelType.AIR:
					col_h = y + 1
					break
			if col_h == 0:
				continue

			var top_voxel: int = data[x + z * size + (col_h - 1) * size * size]

			# Bike park lanes are bare dirt: same grass voxel underneath, but
			# drawn in a dirt tone with no grass blades (see BikePark.is_track)
			var on_track: bool = BikePark.is_track(base_x, base_z)
			var top_color: Color = _voxel_color(top_voxel)
			if on_track and top_voxel == Config.VoxelType.GRASS:
				top_color = _track_color(base_x, base_z)

			# Top face sits at the surface height (water beds slope down)
			var surf: float = WorldManager.surface_y(base_x, base_z)
			_add_quad(st,
				Vector3(base_x, surf, base_z),
				Vector3(base_x + 1, surf, base_z),
				Vector3(base_x + 1, surf, base_z + 1),
				Vector3(base_x, surf, base_z + 1),
				Vector3.UP, top_color)

			# Side faces where the neighboring column is lower (mountains,
			# cliffs, underwater bed steps). surface_y is deterministic and
			# works across chunk borders without loading neighbor chunks.
			_add_column_sides(st, base_x, base_z, surf)

			# Grass blades only on grass - never on the bike track
			if top_voxel == Config.VoxelType.GRASS and not on_track:
				seed(hash(Vector3(base_x, surf, base_z)))
				var count := randi() % 4
				for i in range(count):
					var detail_pos := Vector3(
					base_x + 0.5 + randf_range(-0.4, 0.4),
					surf + 0.125,
					base_z + 0.5 + randf_range(-0.4, 0.4)
					)
					var t := Transform3D(Basis().rotated(Vector3.UP, randf_range(0, TAU)), detail_pos)
					detail_transforms.append(t)

			# Water fills the column up to the flat water line
			if has_water:
				var water_y: float = WorldManager.WATER_SURFACE_MAX_Y
				_add_quad(water_st,
					Vector3(base_x, water_y, base_z),
					Vector3(base_x + 1, water_y, base_z),
					Vector3(base_x + 1, water_y, base_z + 1),
					Vector3(base_x, water_y, base_z + 1),
					Vector3.UP, Color.WHITE)
				water_faces += 1
				_add_water_sides(water_st, base_x, base_z, water_y)

	mesh_instance.mesh = st.commit()
	_build_details(detail_transforms)
	_build_water(water_st, water_faces)


func _voxel_color(voxel: int) -> Color:
	return VOXEL_COLORS.get(voxel, Color.WHITE)


## Packed dirt for the bike park lanes, with a subtle per-cell jitter
## so the track doesn't read as one flat slab (deterministic)
func _track_color(world_x: int, world_z: int) -> Color:
	var base := Color(0.62, 0.5, 0.36)
	var h: int = hash(Vector2i(world_x, world_z))
	var f: float = float(h % 1000) / 1000.0
	return base.darkened(f * 0.12)


## Add the four side walls of a column that are higher than their neighbor
func _add_column_sides(st: SurfaceTool, base_x: int, base_z: int, surf: float) -> void:
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for d: Vector2i in dirs:
		var ns: float = _neighbor_surface(base_x + d.x, base_z + d.y)
		if ns >= surf - 0.02:
			continue
		# Cliff walls read as stone, shallow steps as dirt
		var wall_color: Color = _voxel_color(Config.VoxelType.STONE) if surf - ns > 2.0 else _voxel_color(Config.VoxelType.DIRT)
		_add_wall(st, base_x, base_z, d, ns, surf, wall_color)


## Water edge walls: wherever water borders land (or the world rim), add
## a translucent side so the water line never floats above dry ground.
func _add_water_sides(water_st: SurfaceTool, base_x: int, base_z: int, water_y: float) -> void:
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for d: Vector2i in dirs:
		var nx: int = base_x + d.x
		var nz: int = base_z + d.y
		var outside: bool = nx < Config.WORLD_MIN_BLOCK or nx >= Config.WORLD_MAX_BLOCK or nz < Config.WORLD_MIN_BLOCK or nz >= Config.WORLD_MAX_BLOCK
		if not outside and WorldManager.terrain_column(nx, nz)["water"]:
			continue
		var ns: float = _neighbor_surface(nx, nz)
		if ns >= water_y - 0.02:
			continue
		_add_wall(water_st, base_x, base_z, d, ns, water_y, Color.WHITE)


## One vertical quad on the boundary plane towards direction d, spanning
## y0..y1. Shared by opaque terrain walls and translucent water edges.
func _add_wall(st: SurfaceTool, base_x: int, base_z: int, d: Vector2i, y0: float, y1: float, color: Color) -> void:
	if d.x == 1:
		_add_quad(st, Vector3(base_x + 1, y0, base_z), Vector3(base_x + 1, y0, base_z + 1), Vector3(base_x + 1, y1, base_z + 1), Vector3(base_x + 1, y1, base_z), Vector3(1, 0, 0), color)
	elif d.x == -1:
		_add_quad(st, Vector3(base_x, y0, base_z + 1), Vector3(base_x, y0, base_z), Vector3(base_x, y1, base_z), Vector3(base_x, y1, base_z + 1), Vector3(-1, 0, 0), color)
	elif d.y == 1:
		_add_quad(st, Vector3(base_x + 1, y0, base_z + 1), Vector3(base_x, y0, base_z + 1), Vector3(base_x, y1, base_z + 1), Vector3(base_x + 1, y1, base_z + 1), Vector3(0, 0, 1), color)
	else:
		_add_quad(st, Vector3(base_x, y0, base_z), Vector3(base_x + 1, y0, base_z), Vector3(base_x + 1, y1, base_z), Vector3(base_x, y1, base_z), Vector3(0, 0, -1), color)


## Neighbor column surface; outside the world the ground drops to 0 so the
## world edge renders as a visible cliff face.
func _neighbor_surface(world_x: int, world_z: int) -> float:
	if world_x < Config.WORLD_MIN_BLOCK or world_x >= Config.WORLD_MAX_BLOCK:
		return 0.0
	if world_z < Config.WORLD_MIN_BLOCK or world_z >= Config.WORLD_MAX_BLOCK:
		return 0.0
	return WorldManager.surface_y(world_x, world_z)


## One quad (two triangles) with a flat color. Normals are set, winding is
## irrelevant because the terrain material disables backface culling.
func _add_quad(st: SurfaceTool, v1: Vector3, v2: Vector3, v3: Vector3, v4: Vector3, normal: Vector3, color: Color) -> void:
	st.set_normal(normal)
	st.set_color(color)
	st.add_vertex(v1)
	st.set_normal(normal)
	st.set_color(color)
	st.add_vertex(v2)
	st.set_normal(normal)
	st.set_color(color)
	st.add_vertex(v3)

	st.set_normal(normal)
	st.set_color(color)
	st.add_vertex(v1)
	st.set_normal(normal)
	st.set_color(color)
	st.add_vertex(v3)
	st.set_normal(normal)
	st.set_color(color)
	st.add_vertex(v4)


func _build_details(transforms: Array[Transform3D]) -> void:
	if not _grass_multimesh:
		_grass_multimesh = MultiMeshInstance3D.new()
		var multi_mesh := MultiMesh.new()
		multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
		multi_mesh.mesh = _detail_mesh
		_grass_multimesh.multimesh = multi_mesh
		add_child(_grass_multimesh)

	_grass_multimesh.multimesh.instance_count = transforms.size()
	for i in range(transforms.size()):
		_grass_multimesh.multimesh.set_instance_transform(i, transforms[i])


func _build_water(water_st: SurfaceTool, water_faces: int) -> void:
	if water_faces == 0:
		if _water_mesh_instance:
			_water_mesh_instance.mesh = null
		return
	if not _water_mesh_instance:
		_water_mesh_instance = MeshInstance3D.new()
		_water_mesh_instance.material_override = _water_material
		add_child(_water_mesh_instance)
	_water_mesh_instance.mesh = water_st.commit()


func _add_collision() -> void:
	_collision_body = StaticBody3D.new()
	_collision_body.collision_layer = Config.TERRAIN_COLLISION_LAYER
	_collision_body.collision_mask = 0
	add_child(_collision_body)
	_update_collision_shape()


## Precise collision from the terrain mesh (tops + cliffs). The water mesh is
## separate and contributes no collision: the sea floor is solid, water is
## shallow enough to wade through.
func _update_collision_shape() -> void:
	if not _collision_body:
		return
	for child in _collision_body.get_children():
		child.queue_free()
	var mesh: Mesh = mesh_instance.mesh
	if mesh == null:
		return
	var shape: ConcavePolygonShape3D = mesh.create_trimesh_shape()
	if shape == null:
		return
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = shape
	_collision_body.add_child(collision_shape)
