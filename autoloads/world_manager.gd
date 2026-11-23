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

## Terrain shaping (fixed seed -> deterministic world, identical on every load)
const TERRAIN_SEED: int = 20261122
## East coast: beach strip then ocean, this many blocks wide from the east edge
const COAST_WIDTH: int = 28
const BEACH_WIDTH: int = 8 # of COAST_WIDTH, no water on the beach itself
## West mountain rim: rises up to this height over this many blocks
const MOUNTAIN_WIDTH: int = 20
const MOUNTAIN_HEIGHT: int = 6
## River: meanders roughly east-west through the whole world
const RIVER_HALF_WIDTH: int = 2 # 5 blocks wide water
const RIVER_BANK_WIDTH: int = 3 # +1 block sand banks on each side
const RIVER_MEANDER: float = 24.0

## Water surface height (top of the water, feet stay on the bed below)
const WATER_SURFACE_MAX_Y: float = 1.35
## How much the bed drops per water-depth block (sea slopes down)
const BED_DROP_PER_DEPTH: float = 0.06

## Wooden bridge across the river near spawn. The mesh/colliders live in
## scripts/world/bridge.gd; these constants drive BOTH the walkable
## surface (walk_surface_y) and that mesh so they never drift apart.
## The deck spans the water plus the inner sand banks, the ramps descend
## to the grass over BRIDGE_RAMP_LEN columns.
const BRIDGE_Z: int = -22
const BRIDGE_DECK_Y: float = 1.5
const BRIDGE_HALF_LEN: int = 4
const BRIDGE_HALF_W: int = 1
const BRIDGE_RAMP_LEN: int = 3
## River center column at BRIDGE_Z (set once in _ready, single source)
var bridge_cx: int = 0

var _noise: FastNoiseLite
var _river_noise: FastNoiseLite


func _ready() -> void:
	_noise = FastNoiseLite.new()
	_noise.seed = TERRAIN_SEED
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 0.06
	_noise.fractal_octaves = 2
	_river_noise = FastNoiseLite.new()
	_river_noise.seed = TERRAIN_SEED + 1
	_river_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_river_noise.frequency = 0.02
	_generate_flat_terrain()
	bridge_cx = int(round(river_center_x(BRIDGE_Z)))


## River center x position for a world z row (meandering line, west to east)
func river_center_x(world_z: int) -> float:
	var mid_x: float = (Config.WORLD_MIN_BLOCK + Config.WORLD_MAX_BLOCK) * 0.5
	return mid_x + sin(world_z * 0.045 + 1.3) * RIVER_MEANDER + _river_noise.get_noise_1d(world_z) * 6.0


## Column profile for a world position: how many solid voxels from y=0 up,
## which voxel type tops the column, and whether water covers the column.
func terrain_column(world_x: int, world_z: int) -> Dictionary:
	# River cuts through everything as a canyon (flat bank level, water on top)
	var river_dx: float = absf(float(world_x) - river_center_x(world_z))
	if river_dx <= float(RIVER_BANK_WIDTH):
		return {"h": 1, "top": Config.VoxelType.SAND, "water": river_dx <= float(RIVER_HALF_WIDTH)}

	# East: beach then ocean (SAND floor, water plane above it)
	var d_east: int = Config.WORLD_MAX_BLOCK - world_x
	if d_east <= COAST_WIDTH:
		var ocean: bool = d_east <= COAST_WIDTH - BEACH_WIDTH
		return {"h": 1, "top": Config.VoxelType.SAND, "water": ocean}

	# West: mountain rim rising steeply towards the world edge
	var d_west: int = world_x - Config.WORLD_MIN_BLOCK
	if d_west <= MOUNTAIN_WIDTH:
		var t: float = 1.0 - float(d_west) / float(MOUNTAIN_WIDTH) # 0 at foot, 1 at edge
		var rough: float = _noise.get_noise_2d(float(world_x) * 0.15, float(world_z) * 0.15) * 0.5 + 0.5
		var h: int = 1 + int(round(t * MOUNTAIN_HEIGHT * (0.6 + 0.4 * rough)))
		var top: int = Config.VoxelType.STONE if h > 1 else Config.VoxelType.GRASS
		return {"h": h, "top": top, "water": false}

	# Interior flatland (gameplay area)
	return {"h": 1, "top": Config.VoxelType.GRASS, "water": false}


## How far into the water a position is: 0 on land and at the waterline,
## 1-2 in the narrow river (always wading), up to COAST_WIDTH-BEACH_WIDTH
## far out in the sea. Characters wade first and start swimming once this
## passes Config.SWIM_DEPTH.
func water_depth(world_x: int, world_z: int) -> int:
	if not terrain_column(world_x, world_z)["water"]:
		return 0
	var river_dx: float = absf(float(world_x) - river_center_x(world_z))
	if river_dx <= float(RIVER_BANK_WIDTH):
		return maxi(0, RIVER_BANK_WIDTH - int(floor(river_dx)))
	var d_east: int = Config.WORLD_MAX_BLOCK - world_x
	return maxi(0, (COAST_WIDTH - BEACH_WIDTH) - d_east)


## Walkable surface height of a column: terrain height on land, the
## sloping bed in water (sea floor drops away from the beach, the river
## bed sits slightly lower than its banks). Characters follow this so
## wading actually stands IN the water.
func surface_y(world_x: int, world_z: int) -> float:
	var col: Dictionary = terrain_column(world_x, world_z)
	if not col["water"]:
		return float(col["h"])
	var bed: float = 1.0 - clampf(float(water_depth(world_x, world_z)), 0.0, 15.0) * BED_DROP_PER_DEPTH
	return maxf(bed, 0.1)


## Bridge footprint query (deck + ramps). Buildings and props stay off
## these columns.
func is_bridge_column(world_x: int, world_z: int) -> bool:
	if absi(world_z - BRIDGE_Z) > BRIDGE_HALF_W:
		return false
	return absi(world_x - bridge_cx) <= BRIDGE_HALF_LEN + BRIDGE_RAMP_LEN


## Walkable height INCLUDING structures: bridge deck level, ramps lerp
## down to the grass. surface_y() stays natural so the chunk mesher
## keeps drawing the river bed UNDER the bridge - only characters
## follow this one.
func walk_surface_y(world_x: int, world_z: int) -> float:
	if not is_bridge_column(world_x, world_z):
		return surface_y(world_x, world_z)
	var dx: int = absi(world_x - bridge_cx)
	if dx <= BRIDGE_HALF_LEN:
		return BRIDGE_DECK_Y
	var t: float = float(dx - BRIDGE_HALF_LEN) / float(BRIDGE_RAMP_LEN)
	return lerpf(BRIDGE_DECK_Y, 1.0, t)


## Position-based helpers so the rounding from world position to column
## index lives in exactly one place (used by NPC and Player).
func is_deep_water_at(pos: Vector3) -> bool:
	return water_depth(int(floor(pos.x)), int(floor(pos.z))) >= Config.SWIM_DEPTH


func surface_y_at(pos: Vector3) -> float:
	return surface_y(int(floor(pos.x)), int(floor(pos.z)))


func walk_surface_y_at(pos: Vector3) -> float:
	return walk_surface_y(int(floor(pos.x)), int(floor(pos.z)))


func _generate_flat_terrain() -> void:
	# Only the spawn area: chunks are created lazily by ChunkManager.load_chunk()
	# while streaming, which keeps startup fast for large WORLD_CHUNK_RADIUS values.
	for x in range(-1, 2):
		for z in range(-1, 2):
			create_chunk_data(x, z)


## Create chunk data: flat interior, east ocean, west mountains, one river
func create_chunk_data(chunk_x: int, chunk_z: int) -> void:
	var key := Vector2i(chunk_x, chunk_z)
	if chunk_data.has(key):
		return # Already exists

	var data := PackedByteArray()
	data.resize(Config.CHUNK_SIZE * Config.CHUNK_SIZE * Config.CHUNK_HEIGHT)
	data.fill(Config.VoxelType.AIR)

	for x in range(Config.CHUNK_SIZE):
		for z in range(Config.CHUNK_SIZE):
			var world_x: int = chunk_x * Config.CHUNK_SIZE + x
			var world_z: int = chunk_z * Config.CHUNK_SIZE + z
			var col: Dictionary = terrain_column(world_x, world_z)
			var h: int = col["h"]
			for y in range(h):
				data[_get_index(x, y, z)] = Config.VoxelType.DIRT if y < h - 1 else col["top"]
			if col["water"]:
				data[_get_index(x, h, z)] = Config.VoxelType.WATER

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
