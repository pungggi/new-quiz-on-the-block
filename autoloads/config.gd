extends Node

#region Chunk Constants
const CHUNK_SIZE: int = 16
const CHUNK_HEIGHT: int = 32
#endregion

#region World Constants
## Single source of truth for world size: chunk radius around origin chunk (0,0).
## Radius 1 = 3x3 chunks (48x48 blocks), radius 2 = 5x5 chunks (80x80 blocks).
const WORLD_CHUNK_RADIUS: int = 2

## Height at which entities stand on ground (top of terrain collision box)
const GROUND_Y: float = 1.0

## Derived world boundaries (block-center floats, entities clamp to these).
## Chunk r covers blocks [r*CHUNK_SIZE, r*CHUNK_SIZE + CHUNK_SIZE - 1].
const WORLD_MIN_X: float = float(-WORLD_CHUNK_RADIUS * CHUNK_SIZE) + 0.5
const WORLD_MAX_X: float = float((WORLD_CHUNK_RADIUS + 1) * CHUNK_SIZE) - 0.5
const WORLD_MIN_Z: float = float(-WORLD_CHUNK_RADIUS * CHUNK_SIZE) + 0.5
const WORLD_MAX_Z: float = float((WORLD_CHUNK_RADIUS + 1) * CHUNK_SIZE) - 0.5

## Integer block bounds for grid checks (min inclusive, max EXCLUSIVE).
const WORLD_MIN_BLOCK: int = -WORLD_CHUNK_RADIUS * CHUNK_SIZE
const WORLD_MAX_BLOCK: int = (WORLD_CHUNK_RADIUS + 1) * CHUNK_SIZE
#endregion

#region Collision Layers
const TERRAIN_COLLISION_LAYER: int = 1
const BUILDING_COLLISION_LAYER: int = 2
const NPC_COLLISION_LAYER: int = 4
const PROP_COLLISION_LAYER: int = 8
#endregion

#region Voxel Types
enum VoxelType {
	AIR = 0,
	GRASS = 1,
	DIRT = 2,
	STONE = 3
}
#endregion
