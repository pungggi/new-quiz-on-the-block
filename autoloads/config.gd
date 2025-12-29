extends Node

#region Chunk Constants
const CHUNK_SIZE: int = 16
const CHUNK_HEIGHT: int = 32
#endregion

#region World Constants
## Height at which entities stand on ground (feet touch Y=1.0 surface)
const GROUND_Y: float = 0.7

## World boundaries (3x3 chunks centered around origin)
## Chunk -1: x=-16 to -1, Chunk 0: x=0 to 15, Chunk 1: x=16 to 31
const WORLD_MIN_X: float = -15.5
const WORLD_MAX_X: float = 31.5
const WORLD_MIN_Z: float = -15.5
const WORLD_MAX_Z: float = 31.5
#endregion

#region Collision Layers
const TERRAIN_COLLISION_LAYER: int = 1
const BUILDING_COLLISION_LAYER: int = 2
const NPC_COLLISION_LAYER: int = 4
#endregion

#region Voxel Types
enum VoxelType {
	AIR = 0,
	GRASS = 1,
	DIRT = 2,
	STONE = 3
}
#endregion
