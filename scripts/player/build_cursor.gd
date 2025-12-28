extends Node3D

## Build Cursor
##
## Shows where the player would build on the voxel terrain.
## Casts a ray from the active Camera3D through the mouse position
## and snaps to the voxel grid. Click to place a building.

signal building_placed(grid_position: Vector3i)

# Visual references
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

# Camera reference
var camera: Camera3D

# Placed buildings container
var _buildings_root: Node3D

# Track current grid position for placement
var _current_grid_pos: Vector3i = Vector3i.ZERO
var _can_place: bool = false

# Building material
var _building_material: StandardMaterial3D

# Grid settings
const VOXEL_SIZE: float = 1.0
const PLACEMENT_HEIGHT: float = 1.0 # y=1 placement above grass at y=0
const BUILDING_COLLISION_LAYER: int = 2 # Layer for placed buildings

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

	# Create buildings container
	_buildings_root = Node3D.new()
	_buildings_root.name = "Buildings"
	get_tree().current_scene.add_child.call_deferred(_buildings_root)

	# Hide cursor initially
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	# Left click to place
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if _can_place and visible:
				_place_building()

	# Spacebar to place
	if event is InputEventKey:
		if event.keycode == KEY_SPACE and event.pressed and not event.echo:
			if _can_place and visible:
				_place_building()

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

	# Cast ray into world - check both terrain AND buildings
	var query_params := PhysicsRayQueryParameters3D.new()
	query_params.from = ray_origin
	query_params.to = ray_origin + ray_direction * 1000.0
	query_params.collision_mask = TERRAIN_COLLISION_LAYER | BUILDING_COLLISION_LAYER

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var result: Dictionary = space_state.intersect_ray(query_params)

	if result.is_empty():
		# No hit, hide cursor
		visible = false
		return

	# Get hit position and normal
	var hit_position: Vector3 = result["position"]
	var hit_normal: Vector3 = result["normal"]
	var hit_collider: Object = result["collider"]

	# Minecraft-style placement:
	# The new block goes in the adjacent cell in the direction of the hit normal
	var grid_x: int
	var grid_y: int
	var grid_z: int

	if hit_collider and hit_collider.is_in_group("placed_buildings"):
		# Hit a placed block - place adjacent block using normal
		# Get the center of the hit block
		var block_center: Vector3 = hit_collider.global_position

		# New block position = hit block position + normal (adjacent cell)
		var new_block_pos: Vector3 = block_center + hit_normal

		# Use round for all axes since blocks are centered at x.5, y, z.5
		grid_x = int(round(new_block_pos.x - 0.5))
		grid_y = int(round(new_block_pos.y))
		grid_z = int(round(new_block_pos.z - 0.5))

		print("Block hit: center=", block_center, " normal=", hit_normal, " new_pos=", new_block_pos, " grid=", Vector3i(grid_x, grid_y, grid_z))
	else:
		# Hit terrain - place at ground level
		grid_x = int(floor(hit_position.x))
		grid_y = int(PLACEMENT_HEIGHT)
		grid_z = int(floor(hit_position.z))

	# Store current grid position
	_current_grid_pos = Vector3i(grid_x, grid_y, grid_z)

	# Set cursor position centered on grid cell
	position = Vector3(grid_x + 0.5, grid_y, grid_z + 0.5)

	# Check if placement is valid
	_can_place = _is_placement_valid(grid_x, grid_y, grid_z)

	# Update cursor material based on validity
	if mesh_instance:
		mesh_instance.material_override = material_valid if _can_place else material_invalid

	visible = true

func _is_placement_valid(grid_x: int, grid_y: int, grid_z: int) -> bool:
	# Check if within world bounds
	if grid_x < WORLD_MIN_X or grid_x >= WORLD_MAX_X:
		return false
	if grid_z < WORLD_MIN_Z or grid_z >= WORLD_MAX_Z:
		return false

	# Check if position already has a building (must check X, Y, AND Z)
	if _buildings_root:
		for child in _buildings_root.get_children():
			var child_node := child as Node3D
			if child_node:
				var child_pos: Vector3 = child_node.global_position
				# Compare all three coordinates
				var cx: int = int(round(child_pos.x - 0.5))
				var cy: int = int(round(child_pos.y))
				var cz: int = int(round(child_pos.z - 0.5))
				if cx == grid_x and cy == grid_y and cz == grid_z:
					return false

	return true

func _place_building() -> void:
	if not _buildings_root:
		return

	# Create a StaticBody3D for collision (needed for stacking)
	var building := StaticBody3D.new()
	building.add_to_group("placed_buildings")
	building.collision_layer = BUILDING_COLLISION_LAYER
	building.collision_mask = 0 # Doesn't need to detect anything

	# Create mesh (tighter blocks - 1.0 size instead of 0.9)
	var block_mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(1.0, 1.0, 1.0) # Cube blocks, tight fit
	block_mesh.mesh = box_mesh

	# Random building color
	var mat := StandardMaterial3D.new()
	var colors := [Color.CORAL, Color.CORNFLOWER_BLUE, Color.GOLD, Color.MEDIUM_PURPLE, Color.TOMATO]
	mat.albedo_color = colors[randi() % colors.size()]
	block_mesh.material_override = mat
	building.add_child(block_mesh)

	# Create collision shape
	var collision := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(1.0, 1.0, 1.0)
	collision.shape = box_shape
	building.add_child(collision)

	# Position at grid location (centered)
	building.position = Vector3(_current_grid_pos.x + 0.5, _current_grid_pos.y, _current_grid_pos.z + 0.5)

	_buildings_root.add_child(building)
	building_placed.emit(_current_grid_pos)
