extends Node

var chunk_data: Dictionary = {} # Key: Vector2i(chunk_x, chunk_z), Value: PackedByteArray

func _ready() -> void:
	_generate_flat_terrain()

func _generate_flat_terrain() -> void:
	for x in range(-1, 2):
		for z in range(-1, 2):
			_create_chunk_data(x, z)

func _create_chunk_data(chunk_x: int, chunk_z: int) -> void:
	var data := PackedByteArray()
	data.resize(Config.CHUNK_SIZE * Config.CHUNK_SIZE * Config.CHUNK_HEIGHT)
	
	for x in range(Config.CHUNK_SIZE):
		for z in range(Config.CHUNK_SIZE):
			for y in range(Config.CHUNK_HEIGHT):
				var index := x + z * Config.CHUNK_SIZE + y * Config.CHUNK_SIZE * Config.CHUNK_SIZE
				if y == 0:
					data[index] = Config.VoxelType.GRASS
				else:
					data[index] = Config.VoxelType.AIR
	
	chunk_data[Vector2i(chunk_x, chunk_z)] = data

func get_chunk_data(chunk_x: int, chunk_z: int) -> PackedByteArray:
	var key := Vector2i(chunk_x, chunk_z)
	if chunk_data.has(key):
		return chunk_data[key]
	return PackedByteArray()
