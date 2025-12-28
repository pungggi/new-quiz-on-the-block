extends Node3D

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var chunk_x: int = 0
var chunk_z: int = 0

func _ready() -> void:
	_build_mesh()

func _build_mesh() -> void:
	var data: PackedByteArray = WorldManager.get_chunk_data(chunk_x, chunk_z)
	if data.is_empty():
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
