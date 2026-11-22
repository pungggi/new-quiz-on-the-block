extends Node

## ChunkManager
##
## Manages chunk loading, unloading, and rebuilding.
## Listens to EventManager signals for decoupled communication.
##
## Usage:
##   ChunkManager.load_chunk(0, 0) - Load a specific chunk
##   ChunkManager.unload_chunk(0, 0) - Unload a specific chunk
##   ChunkManager.rebuild_chunk(0, 0) - Rebuild chunk mesh after data change

const CHUNK_SCENE: PackedScene = preload("res://scenes/world/chunk.tscn")

## Currently loaded chunks: Key = Vector2i(chunk_x, chunk_z), Value = Chunk node
var _loaded_chunks: Dictionary = {}

## Parent node for all chunks
var _chunk_root: Node3D = null


func _ready() -> void:
	# Connect to EventManager signals
	EventManager.chunk_data_changed.connect(_on_chunk_data_changed)
	EventManager.spawn_chunk_requested.connect(_on_spawn_chunk_requested)


## Initialize with a parent node for chunks
func initialize(chunk_root: Node3D) -> void:
	_chunk_root = chunk_root


## Load initial chunks around origin (grid size derives from Config.WORLD_CHUNK_RADIUS)
func load_initial_chunks(radius: int = -1) -> void:
	if radius < 0:
		radius = Config.WORLD_CHUNK_RADIUS
	if not _chunk_root:
		push_error("ChunkManager: No chunk root set. Call initialize() first.")
		return
	
	for x in range(-radius, radius + 1):
		for z in range(-radius, radius + 1):
			load_chunk(x, z)


## Load a specific chunk
func load_chunk(chunk_x: int, chunk_z: int) -> Node3D:
	var key := Vector2i(chunk_x, chunk_z)
	
	# Already loaded?
	if _loaded_chunks.has(key):
		return _loaded_chunks[key]
	
	if not _chunk_root:
		push_error("ChunkManager: No chunk root set.")
		return null
	
	# Ensure WorldManager has data for this chunk
	var data: PackedByteArray = WorldManager.get_chunk_data(chunk_x, chunk_z)
	if data.is_empty():
		WorldManager.create_chunk_data(chunk_x, chunk_z)
	
	# Instantiate and configure chunk
	var chunk: Node3D = CHUNK_SCENE.instantiate()
	chunk.chunk_x = chunk_x
	chunk.chunk_z = chunk_z
	chunk.name = "Chunk_%d_%d" % [chunk_x, chunk_z]
	
	_chunk_root.add_child(chunk)
	_loaded_chunks[key] = chunk
	
	return chunk


## Unload a specific chunk
func unload_chunk(chunk_x: int, chunk_z: int) -> void:
	var key := Vector2i(chunk_x, chunk_z)
	
	if not _loaded_chunks.has(key):
		return
	
	var chunk: Node3D = _loaded_chunks[key]
	chunk.queue_free()
	_loaded_chunks.erase(key)


## Rebuild a chunk's mesh (after voxel data changed)
func rebuild_chunk(chunk_x: int, chunk_z: int) -> void:
	var key := Vector2i(chunk_x, chunk_z)
	
	if not _loaded_chunks.has(key):
		push_warning("ChunkManager: Cannot rebuild unloaded chunk (%d, %d)" % [chunk_x, chunk_z])
		return
	
	var chunk: Node3D = _loaded_chunks[key]
	if chunk.has_method("rebuild_mesh"):
		chunk.rebuild_mesh()


## Check if a chunk is loaded
func is_chunk_loaded(chunk_x: int, chunk_z: int) -> bool:
	return _loaded_chunks.has(Vector2i(chunk_x, chunk_z))


## Get a loaded chunk (or null)
func get_chunk(chunk_x: int, chunk_z: int) -> Node3D:
	return _loaded_chunks.get(Vector2i(chunk_x, chunk_z), null)


## Get all loaded chunk coordinates
func get_loaded_chunk_coords() -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	for key in _loaded_chunks.keys():
		coords.append(key)
	return coords


## Unload all chunks
func unload_all_chunks() -> void:
	for key in _loaded_chunks.keys():
		var chunk: Node3D = _loaded_chunks[key]
		chunk.queue_free()
	_loaded_chunks.clear()


# --- Signal Callbacks ---

func _on_chunk_data_changed(chunk_x: int, chunk_z: int) -> void:
	rebuild_chunk(chunk_x, chunk_z)


func _on_spawn_chunk_requested(chunk_x: int, chunk_z: int) -> void:
	load_chunk(chunk_x, chunk_z)

