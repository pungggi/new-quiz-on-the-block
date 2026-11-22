extends Node

## ChunkManager
##
## Manages chunk loading, unloading, and rebuilding.
## Listens to EventManager signals for decoupled communication.
##
## Streaming: only chunks within Config.CHUNK_STREAM_RADIUS (Chebyshev) around
## a follow target (the camera rig) stay alive as nodes. Chunks up to
## +Config.CHUNK_UNLOAD_MARGIN further out are kept loaded as hysteresis so
## panning along a chunk border does not thrash load/unload. World size is
## bounded by Config.WORLD_CHUNK_RADIUS; voxel data is created lazily on first
## load and never evicted (a PackedByteArray is 8 KB, node meshes are the cost).
##
## Usage:
##   ChunkManager.set_follow_target(camera_rig) - start streaming around a node
##   ChunkManager.load_chunk(0, 0) - Load a specific chunk
##   ChunkManager.unload_chunk(0, 0) - Unload a specific chunk
##   ChunkManager.rebuild_chunk(0, 0) - Rebuild chunk mesh after data change

const CHUNK_SCENE: PackedScene = preload("res://scenes/world/chunk.tscn")

## Seconds between streaming update ticks
const STREAM_TICK: float = 0.25
## Max chunks loaded per tick (mesh building is synchronous; keep small so
## panning never produces frame spikes)
const MAX_LOADS_PER_TICK: int = 2

## Emitted when streaming loads/unloads a chunk (props/NPCs can react)
signal chunk_became_loaded(chunk_x: int, chunk_z: int)
signal chunk_became_unloaded(chunk_x: int, chunk_z: int)

## Currently loaded chunks: Key = Vector2i(chunk_x, chunk_z), Value = Chunk node
var _loaded_chunks: Dictionary = {}

## Parent node for all chunks
var _chunk_root: Node3D = null

## Streaming: node whose position defines the streaming center (camera rig)
var _follow_target: Node3D = null
var _tick_accum: float = 0.0


func _ready() -> void:
	# Connect to EventManager signals
	EventManager.chunk_data_changed.connect(_on_chunk_data_changed)
	EventManager.spawn_chunk_requested.connect(_on_spawn_chunk_requested)


func _process(delta: float) -> void:
	if not _follow_target or not is_instance_valid(_follow_target):
		return
	if not _chunk_root or not is_instance_valid(_chunk_root):
		# World scene was freed (e.g. back to main menu): drop stale references
		# so the next game start can load chunks again.
		_loaded_chunks.clear()
		_follow_target = null
		return

	_tick_accum += delta
	if _tick_accum < STREAM_TICK:
		return
	_tick_accum = 0.0
	_update_streaming()


## Core streaming step: load wanted chunks near the target, unload far ones
func _update_streaming() -> void:
	var center: Vector3 = _follow_target.global_position
	var cx: int = floori(center.x / float(Config.CHUNK_SIZE))
	var cz: int = floori(center.z / float(Config.CHUNK_SIZE))
	var r: int = Config.CHUNK_STREAM_RADIUS
	var world_r: int = Config.WORLD_CHUNK_RADIUS

	# Queue missing chunks inside the stream radius (nearest first)
	var wanted: Array = []
	for x in range(cx - r, cx + r + 1):
		for z in range(cz - r, cz + r + 1):
			if absi(x) > world_r or absi(z) > world_r:
				continue # outside the world
			var key := Vector2i(x, z)
			if not _loaded_chunks.has(key):
				wanted.append(key)
	if not wanted.is_empty():
		var center_key := Vector2i(cx, cz)
		wanted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return (a - center_key).length_squared() < (b - center_key).length_squared())
		var budget: int = MAX_LOADS_PER_TICK
		for key in wanted:
			if budget <= 0:
				break
			if load_chunk(key.x, key.y) != null:
				budget -= 1

	# Unload chunks beyond radius + margin (Chebyshev = square rings)
	var unload_r: int = r + Config.CHUNK_UNLOAD_MARGIN
	for key in _loaded_chunks.keys():
		if maxi(absi(key.x - cx), absi(key.y - cz)) > unload_r:
			unload_chunk(key.x, key.y)


## Register the node to stream around (usually the camera rig)
func set_follow_target(target: Node3D) -> void:
	_follow_target = target
	_tick_accum = STREAM_TICK # stream on the very next frame


## Initialize with a parent node for chunks
func initialize(chunk_root: Node3D) -> void:
	_chunk_root = chunk_root
	_loaded_chunks.clear()


## Load initial chunks around origin (stream radius; the rest streams in)
func load_initial_chunks(radius: int = -1) -> void:
	if radius < 0:
		radius = Config.CHUNK_STREAM_RADIUS
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
	chunk_became_loaded.emit(chunk_x, chunk_z)

	return chunk


## Unload a specific chunk (voxel data stays in WorldManager)
func unload_chunk(chunk_x: int, chunk_z: int) -> void:
	var key := Vector2i(chunk_x, chunk_z)

	if not _loaded_chunks.has(key):
		return

	var chunk: Node3D = _loaded_chunks[key]
	chunk.queue_free()
	_loaded_chunks.erase(key)
	chunk_became_unloaded.emit(chunk_x, chunk_z)


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


## Check whether a world position currently has a loaded chunk beneath it
func is_position_loaded(pos: Vector3) -> bool:
	var key := Vector2i(
		floori(pos.x / float(Config.CHUNK_SIZE)),
		floori(pos.z / float(Config.CHUNK_SIZE)))
	return _loaded_chunks.has(key)


## Center of the streamed area (follow target position, e.g. camera rig)
func get_stream_center() -> Vector3:
	if _follow_target and is_instance_valid(_follow_target):
		return _follow_target.global_position
	return Vector3.ZERO


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
