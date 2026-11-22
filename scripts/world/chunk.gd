extends Node3D

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var _grass_multimesh: MultiMeshInstance3D
static var _detail_mesh: BoxMesh
static var _detail_material: StandardMaterial3D

var chunk_x: int = 0
var chunk_z: int = 0

## Water surface sits a hair above the sand floor (and below grass blades)
const WATER_SURFACE_Y: float = 1.02

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

			# Top face (vertex color per voxel type)
			_add_quad(st,
				Vector3(base_x, col_h, base_z),
				Vector3(base_x + 1, col_h, base_z),
				Vector3(base_x + 1, col_h, base_z + 1),
				Vector3(base_x, col_h, base_z + 1),
				Vector3.UP, _voxel_color(top_voxel))

			# Side faces where the neighboring column is lower (mountains,
			# world edge cliffs). terrain_column is deterministic and works
			# across chunk borders without loading neighbor chunks.
			_add_column_sides(st, base_x, base_z, col_h)

			# Grass blades only on grass
			if top_voxel == Config.VoxelType.GRASS:
				seed(hash(Vector3(base_x, col_h, base_z)))
				var count := randi() % 4
				for i in range(count):
					var detail_pos := Vector3(
						base_x + 0.5 + randf_range(-0.4, 0.4),
						col_h + 0.125,
						base_z + 0.5 + randf_range(-0.4, 0.4)
					)
					var t := Transform3D(Basis().rotated(Vector3.UP, randf_range(0, TAU)), detail_pos)
					detail_transforms.append(t)

			# Water surface quad just above the sand floor
			if has_water:
				_add_quad(water_st,
					Vector3(base_x, WATER_SURFACE_Y, base_z),
					Vector3(base_x + 1, WATER_SURFACE_Y, base_z),
					Vector3(base_x + 1, WATER_SURFACE_Y, base_z + 1),
					Vector3(base_x, WATER_SURFACE_Y, base_z + 1),
					Vector3.UP, Color.WHITE)
				water_faces += 1

	mesh_instance.mesh = st.commit()
	_build_details(detail_transforms)
	_build_water(water_st, water_faces)


func _voxel_color(voxel: int) -> Color:
	return VOXEL_COLORS.get(voxel, Color.WHITE)


## Add the four side walls of a column that are higher than their neighbor
func _add_column_sides(st: SurfaceTool, base_x: int, base_z: int, col_h: int) -> void:
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for d: Vector2i in dirs:
		var nx: int = base_x + d.x
		var nz: int = base_z + d.y
		var nh: int = _neighbor_height(nx, nz)
		if nh >= col_h:
			continue
		# Cliff walls read as stone, shallow steps as dirt
		var wall_color: Color = _voxel_color(Config.VoxelType.STONE) if col_h - nh > 2 else _voxel_color(Config.VoxelType.DIRT)
		var y0: float = float(nh)
		var y1: float = float(col_h)
		if d.x == 1:
			_add_quad(st, Vector3(base_x + 1, y0, base_z), Vector3(base_x + 1, y0, base_z + 1), Vector3(base_x + 1, y1, base_z + 1), Vector3(base_x + 1, y1, base_z), Vector3(1, 0, 0), wall_color)
		elif d.x == -1:
			_add_quad(st, Vector3(base_x, y0, base_z + 1), Vector3(base_x, y0, base_z), Vector3(base_x, y1, base_z), Vector3(base_x, y1, base_z + 1), Vector3(-1, 0, 0), wall_color)
		elif d.y == 1:
			_add_quad(st, Vector3(base_x + 1, y0, base_z + 1), Vector3(base_x, y0, base_z + 1), Vector3(base_x, y1, base_z + 1), Vector3(base_x + 1, y1, base_z + 1), Vector3(0, 0, 1), wall_color)
		else:
			_add_quad(st, Vector3(base_x, y0, base_z), Vector3(base_x + 1, y0, base_z), Vector3(base_x + 1, y1, base_z), Vector3(base_x, y1, base_z), Vector3(0, 0, -1), wall_color)


## Neighbor column height; outside the world the ground drops to 0 so the
## world edge renders as a visible cliff face.
func _neighbor_height(world_x: int, world_z: int) -> int:
	if world_x < Config.WORLD_MIN_BLOCK or world_x >= Config.WORLD_MAX_BLOCK:
		return 0
	if world_z < Config.WORLD_MIN_BLOCK or world_z >= Config.WORLD_MAX_BLOCK:
		return 0
	var col: Dictionary = WorldManager.terrain_column(world_x, world_z)
	return col["h"]


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
