extends Node3D

## Build Cursor
##
## Shows where the player would build on the voxel terrain.
## Casts a ray from the active Camera3D through the mouse position
## and snaps to the voxel grid.

# Visual references
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

# Camera reference
var camera: Camera3D

# Grid settings
const VOXEL_SIZE: float = 1.0
const PLACEMENT_HEIGHT: float = 1.0 # y=1 placement above grass at y=0

# World bounds (3x3 chunks at 16x16 each = 48x48 units centered at origin)
const WORLD_MIN_X: float = -24.0
const WORLD_MAX_X: float = 24.0
const WORLD_MIN_Z: float = -24.0
const WORLD_MAX_Z: float = 24.0

# Collision layer for terrain raycasting
const TERRAIN_COLLISION_LAYER: int = 1 # Layer 1 for terrain

# Materials for valid/invalid placement
var material_valid: StandardMaterial3D
var material_invalid: StandardMaterial3D

func _ready() -> void:
	# Create materials for cursor states
	_setup_materials()
	
	# Find the active camera
	_find_camera()
	
	# Hide cursor initially
	visible = false

func _setup_materials() -> void:
	# Valid placement material (green, transparent)
	material_valid = StandardMaterial3D.new()
	material_valid.albedo_color = Color(0.0, 1.0, 0.0, 0.5) # Green with 50% alpha
	material_valid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material_valid.cull_mode = BaseMaterial3D.CULL_BACK
	material_valid.flags_do_not_receive_shadows = true
	material_valid.flags_unshaded = true
	
	# Invalid placement material (red, transparent)
	material_invalid = StandardMaterial3D.new()
	material_invalid.albedo_color = Color(1.0, 0.0, 0.0, 0.5) # Red with 50% alpha
	material_invalid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material_invalid.cull_mode = BaseMaterial3D.CULL_BACK
	material_invalid.flags_do_not_receive_shadows = true
	material_invalid.flags_unshaded = true
	
	# Apply initial material
	if mesh_instance and mesh_instance.mesh:
		mesh_instance.material_override = material_valid

func _find_camera() -> void:
	# Get the current camera from the viewport
	var viewport: Viewport = get_viewport()
	if viewport:
		camera = viewport.get_camera_3d()
	
	# Fallback: search scene tree for Camera3D
	if not camera:
		camera = get_tree().get_first_node_in_group("camera")
	
	# Final fallback: find any Camera3D in scene
	if not camera:
		camera = get_viewport().get_camera_3d()

func _process(_delta: float) -> void:
	if not camera:
		_find_camera()
		if not camera:
			return
	
	_update_cursor_position()

func _update_cursor_position() -> void:
	var viewport: Viewport = get_viewport()
	if not viewport:
		return
	
	var mouse_pos: Vector2 = viewport.get_mouse_position()
	
	# Get ray from camera through mouse position
	var ray_origin: Vector3 = camera.project_ray_origin(mouse_pos)
	var ray_direction: Vector3 = camera.project_ray_normal(mouse_pos)
	
	# Cast ray into world
	var query_params := PhysicsRayQueryParameters3D.new()
	query_params.from = ray_origin
	query_params.to = ray_origin + ray_direction * 1000.0
	query_params.collision_mask = TERRAIN_COLLISION_LAYER
	
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var result: Dictionary = space_state.intersect_ray(query_params)
	
	if result.is_empty():
		# No hit, hide cursor
		visible = false
		return
	
	# Get hit position
	var hit_position: Vector3 = result["position"]
	
	# Snap to voxel grid (floor to get integer coordinates)
	var grid_x: int = floor(hit_position.x)
	var grid_z: int = floor(hit_position.z)
	
	# Set cursor position (at y=1 for placement above grass)
	position = Vector3(grid_x, PLACEMENT_HEIGHT, grid_z)
	
	# Check if placement is valid
	var is_valid: bool = _is_placement_valid(grid_x, grid_z)
	
	# Update cursor material based on validity
	if mesh_instance:
		mesh_instance.material_override = material_valid if is_valid else material_invalid
	
	visible = true

func _is_placement_valid(grid_x: int, grid_z: int) -> bool:
	# Check if within world bounds
	if grid_x < WORLD_MIN_X or grid_x >= WORLD_MAX_X:
		return false
	if grid_z < WORLD_MIN_Z or grid_z >= WORLD_MAX_Z:
		return false
	
	# For MVP, assume valid if within bounds (grass exists at y=0)
	# In full implementation, would check WorldManager for underlying voxel
	return true
