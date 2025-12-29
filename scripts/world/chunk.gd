extends Node3D

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var chunk_x: int = 0
var chunk_z: int = 0

# Grass material (shared across all chunks)
static var _grass_material: StandardMaterial3D

func _ready() -> void:
	_setup_material()
	_build_mesh()
	_add_collision()


func _setup_material() -> void:
	# Create shared grass material only once
	if not _grass_material:
		_grass_material = StandardMaterial3D.new()
		_grass_material.albedo_color = Color(0.33, 0.65, 0.25) # Fresh grass green
		_grass_material.roughness = 0.9
		_grass_material.metallic = 0.0

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
	
	var mesh: Mesh = st.commit()
	mesh_instance.mesh = mesh

func _add_collision() -> void:
	# Create a StaticBody3D for collision
	var static_body := StaticBody3D.new()
	static_body.collision_layer = Config.TERRAIN_COLLISION_LAYER
	static_body.collision_mask = 0 # Don't collide with other bodies
	
	# Create a box collision shape covering the chunk
	var collision_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(Config.CHUNK_SIZE, 1.0, Config.CHUNK_SIZE)
	collision_shape.shape = box_shape
	
	# Position the collision at y=1 (top of grass layer)
	# Local position relative to the chunk node
	# Center of the chunk in X and Z, and center of the 1-unit high block at Y=0.5 (since it's size 1)
	# Wait, the mesh generation puts vertices at integer coordinates.
	# A block at (x, 0, z) goes from x to x+1, 0 to 1, z to z+1.
	# So the center of that block is x+0.5, 0.5, z+0.5.
	# The chunk mesh is generated relative to the chunk node's position?
	# Let's check _build_mesh again.
	# var base_x := x + chunk_x * size
	# var base_z := z + chunk_z * size
	# It uses absolute world coordinates for vertices!
	# But the chunk node itself is positioned at (0,0,0) in main.gd?
	# In main.gd: chunk_root.add_child(chunk). No position set on chunk node.
	# So the chunk node is at (0,0,0).
	# The mesh vertices are offset by chunk_x * size.
	
	# So for the collision shape, we need to position it correctly in world space (since it's a child of chunk at 0,0,0).
	# The collision box should cover the whole chunk area (size * size) at height 1 (y=0 to y=1).
	# Center X = chunk_x * size + size / 2.0
	# Center Z = chunk_z * size + size / 2.0
	# Center Y = 0.5 (since it goes from 0 to 1)
	
	static_body.position = Vector3(
		chunk_x * Config.CHUNK_SIZE + Config.CHUNK_SIZE / 2.0,
		0.5,
		chunk_z * Config.CHUNK_SIZE + Config.CHUNK_SIZE / 2.0
	)
	
	static_body.add_child(collision_shape)
	add_child(static_body)
