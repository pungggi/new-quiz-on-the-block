extends Node3D

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var _grass_multimesh: MultiMeshInstance3D
static var _detail_mesh: BoxMesh
static var _detail_material: StandardMaterial3D

var chunk_x: int = 0
var chunk_z: int = 0

## Collision body reference for rebuilding
var _collision_body: StaticBody3D = null

# Grass material (shared across all chunks)
static var _grass_material: StandardMaterial3D


func _ready() -> void:
	_setup_material()
	_build_mesh()
	_add_collision()


## Rebuild the chunk mesh after voxel data has changed
func rebuild_mesh() -> void:
	_build_mesh()
	_rebuild_collision()


func _setup_material() -> void:
	# Create shared grass material only once
	if not _grass_material:
		_grass_material = StandardMaterial3D.new()
		_grass_material.albedo_color = Color(0.33, 0.65, 0.25) # Fresh grass green
		_grass_material.roughness = 0.85
		_grass_material.metallic = 0.0
		
		# Create a noise texture for details
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
		
		_grass_material.albedo_texture = noise_texture
		_grass_material.uv1_triplanar = true
		_grass_material.uv1_scale = Vector3(0.2, 0.2, 0.2)
		
		# Set up detail material and mesh
		_detail_material = StandardMaterial3D.new()
		_detail_material.albedo_color = Color(0.45, 0.85, 0.35)
		_detail_material.roughness = 0.9
		
		_detail_mesh = BoxMesh.new()
		_detail_mesh.size = Vector3(0.12, 0.25, 0.12)
		_detail_mesh.material = _detail_material

	mesh_instance.material_override = _grass_material

func _build_mesh() -> void:
	var data: PackedByteArray = WorldManager.get_chunk_data(chunk_x, chunk_z)
	if data.is_empty():
		push_warning("Chunk (%d, %d): No data found from WorldManager!" % [chunk_x, chunk_z])
		return
	
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var size := Config.CHUNK_SIZE
	var height := Config.CHUNK_HEIGHT
	
	var detail_transforms: Array[Transform3D] = []
	
	for x in range(size):
		for z in range(size):
			for y in range(height):
				var index: int = x + z * size + y * size * size
				var voxel: int = data[index]
				
				if voxel == Config.VoxelType.AIR:
					continue
				
				# Check if voxel above is air
				if y + 1 < height:
					var above_index: int = x + z * size + (y + 1) * size * size
					if data[above_index] != Config.VoxelType.AIR:
						continue
				
				# Add top face
				var base_x := x + chunk_x * size
				var base_z := z + chunk_z * size
				var top_y := y + 1
				
				var v1 := Vector3(base_x, top_y, base_z)
				var v2 := Vector3(base_x + 1, top_y, base_z)
				var v3 := Vector3(base_x + 1, top_y, base_z + 1)
				var v4 := Vector3(base_x, top_y, base_z + 1)
				
				var normal := Vector3.UP
				
				st.set_normal(normal)
				st.set_uv(Vector2(0, 0))
				st.add_vertex(v1)
				
				st.set_normal(normal)
				st.set_uv(Vector2(1, 0))
				st.add_vertex(v2)
				
				st.set_normal(normal)
				st.set_uv(Vector2(1, 1))
				st.add_vertex(v3)
				
				st.set_normal(normal)
				st.set_uv(Vector2(0, 0))
				st.add_vertex(v1)
				
				st.set_normal(normal)
				st.set_uv(Vector2(1, 1))
				st.add_vertex(v3)
				
				st.set_normal(normal)
				st.set_uv(Vector2(0, 1))
				st.add_vertex(v4)
				
				# Add grass details
				if voxel == Config.VoxelType.GRASS:
					seed(hash(Vector3(base_x, top_y, base_z)))
					var count := randi() % 4
					for i in range(count):
						var detail_pos := Vector3(
							base_x + 0.5 + randf_range(-0.4, 0.4),
							top_y + 0.125,
							base_z + 0.5 + randf_range(-0.4, 0.4)
						)
						var t := Transform3D(Basis().rotated(Vector3.UP, randf_range(0, TAU)), detail_pos)
						detail_transforms.append(t)
	
	var mesh: Mesh = st.commit()
	mesh_instance.mesh = mesh
	
	_build_details(detail_transforms)

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


func _add_collision() -> void:
	_collision_body = StaticBody3D.new()
	_collision_body.collision_layer = Config.TERRAIN_COLLISION_LAYER
	_collision_body.collision_mask = 0

	var collision_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(Config.CHUNK_SIZE, 1.0, Config.CHUNK_SIZE)
	collision_shape.shape = box_shape

	# Position collision at chunk center (y=0.5 for 1-unit tall box)
	_collision_body.position = Vector3(
		chunk_x * Config.CHUNK_SIZE + Config.CHUNK_SIZE / 2.0,
		0.5,
		chunk_z * Config.CHUNK_SIZE + Config.CHUNK_SIZE / 2.0
	)

	_collision_body.add_child(collision_shape)
	add_child(_collision_body)


func _rebuild_collision() -> void:
	# For now, collision is a simple box covering the chunk
	# Future: Generate precise collision from voxel data
	if _collision_body:
		_collision_body.position = Vector3(
			chunk_x * Config.CHUNK_SIZE + Config.CHUNK_SIZE / 2.0,
			0.5,
			chunk_z * Config.CHUNK_SIZE + Config.CHUNK_SIZE / 2.0
		)
