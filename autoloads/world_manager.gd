extends Node

## WorldManager
##
## Stores and manages voxel data for all chunks.
## Data is stored in PackedByteArray for memory efficiency.
##
## Usage:
##   WorldManager.get_chunk_data(0, 0) - Get voxel data for chunk
##   WorldManager.set_voxel(world_x, world_y, world_z, type) - Modify a voxel
##   WorldManager.get_voxel(world_x, world_y, world_z) - Get voxel type

var chunk_data: Dictionary = {} # Key: Vector2i(chunk_x, chunk_z), Value: PackedByteArray


func _ready() -> void:
	_generate_flat_terrain()


func _generate_flat_terrain() -> void:
	for x in range(-Config.WORLD_CHUNK_RADIUS, Config.WORLD_CHUNK_RADIUS + 1):
		for z in range(-Config.WORLD_CHUNK_RADIUS, Config.WORLD_CHUNK_RADIUS + 1):
			create_chunk_data(x, z)


## Create chunk data with flat grass terrain
func create_chunk_data(chunk_x: int, chunk_z: int) -> void:
	var key := Vector2i(chunk_x, chunk_z)
	if chunk_data.has(key):
		return # Already exists

	var data := PackedByteArray()
	data.resize(Config.CHUNK_SIZE * Config.CHUNK_SIZE * Config.CHUNK_HEIGHT)

	for x in range(Config.CHUNK_SIZE):
		for z in range(Config.CHUNK_SIZE):
			for y in range(Config.CHUNK_HEIGHT):
				var index := _get_index(x, y, z)
				if y == 0:
					data[index] = Config.VoxelType.GRASS
				else:
					data[index] = Config.VoxelType.AIR

	chunk_data[key] = data


## Get chunk data (returns empty array if not found)
func get_chunk_data(chunk_x: int, chunk_z: int) -> PackedByteArray:
	var key := Vector2i(chunk_x, chunk_z)
	if chunk_data.has(key):
		return chunk_data[key]
	return PackedByteArray()


## Set a voxel at world coordinates
func set_voxel(world_x: int, world_y: int, world_z: int, voxel_type: int) -> void:
	var chunk_x := _world_to_chunk(world_x)
	var chunk_z := _world_to_chunk(world_z)
	var key := Vector2i(chunk_x, chunk_z)

	if not chunk_data.has(key):
		push_warning("WorldManager: Chunk (%d, %d) not loaded" % [chunk_x, chunk_z])
		return

	var local_x := _world_to_local(world_x)
	var local_z := _world_to_local(world_z)
	var index := _get_index(local_x, world_y, local_z)

	if index < 0 or index >= chunk_data[key].size():
		push_warning("WorldManager: Invalid voxel position (%d, %d, %d)" % [world_x, world_y, world_z])
		return

	chunk_data[key][index] = voxel_type

	# Notify that chunk data changed
	EventManager.chunk_data_changed.emit(chunk_x, chunk_z)


## Get a voxel at world coordinates
func get_voxel(world_x: int, world_y: int, world_z: int) -> int:
	var chunk_x := _world_to_chunk(world_x)
	var chunk_z := _world_to_chunk(world_z)
	var key := Vector2i(chunk_x, chunk_z)

	if not chunk_data.has(key):
		return Config.VoxelType.AIR

	var local_x := _world_to_local(world_x)
	var local_z := _world_to_local(world_z)
	var index := _get_index(local_x, world_y, local_z)

	if index < 0 or index >= chunk_data[key].size():
		return Config.VoxelType.AIR

	return chunk_data[key][index]


# --- Helper Functions ---

func _get_index(local_x: int, y: int, local_z: int) -> int:
	return local_x + local_z * Config.CHUNK_SIZE + y * Config.CHUNK_SIZE * Config.CHUNK_SIZE


func _world_to_chunk(world_coord: int) -> int:
	if world_coord >= 0:
		@warning_ignore("integer_division")
		return world_coord / Config.CHUNK_SIZE
	else:
		@warning_ignore("integer_division")
		return (world_coord + 1) / Config.CHUNK_SIZE - 1


func _world_to_local(world_coord: int) -> int:
	var local := world_coord % Config.CHUNK_SIZE
	if local < 0:
		local += Config.CHUNK_SIZE
	return local
