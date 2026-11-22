extends Node3D

## Build Cursor
##
## Shows where the player would build on the voxel terrain.
## Casts a ray from the active Camera3D through the mouse position
## and snaps to the voxel grid. Click to place a building.

const BuildingMeshGen := preload("res://scripts/visuals/building_mesh_generator.gd")

signal building_placed(grid_position: Vector3i)

# Visual references
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

# Camera reference
var camera: Camera3D
var _camera_rig: Node3D # Reference to RTS camera rig for auto-pan

# Placed buildings container
var _buildings_root: Node3D

# BuildingManager reference
var _building_manager: Node

# UI blocking - when true, building input is disabled
var _ui_blocking: bool = false

# Track current grid position for placement
var _current_grid_pos: Vector3i = Vector3i.ZERO
var _last_placed_pos: Vector3i = Vector3i(-9999, -9999, -9999) # Track last placed position
var _drag_start_pos: Vector3i = Vector3i(-9999, -9999, -9999) # Where drag started
var _drag_start_mouse: Vector2 = Vector2.ZERO # Mouse position when drag started
var _drag_direction: int = -1 # 0=horizontal, 1=vertical(Y), -1=not set
var _can_place: bool = false
var _is_mouse_held: bool = false
var _place_cooldown: float = 0.0
const PLACE_DELAY: float = 0.30 # Seconds between continuous placements

# Grid settings
const VOXEL_SIZE: float = 1.0
const PLACEMENT_HEIGHT: float = 1.0 # y=1 placement above grass at y=0
const INFRASTRUCTURE_HEIGHT: float = 1.0 # y=1 on top of grass (mesh itself is only 0.15 high)
const BUILDING_COLLISION_LAYER: int = 2 # Layer for placed buildings
const PROP_COLLISION_LAYER: int = 8 # Layer for props

# World build bounds derive from Config (auto-scale with world size)

# Collision layer for terrain raycasting
const TERRAIN_COLLISION_LAYER: int = 1 # Layer 1 for terrain

# Materials for valid/invalid placement
var material_valid: StandardMaterial3D
var material_invalid: StandardMaterial3D

# Current preview mesh (changes based on selected building)
var _preview_mesh: MeshInstance3D = null
var _current_preview_building: BuildingData = null

# Prop placement support
var _selected_prop: PropData = null
var _current_preview_prop: PropData = null
var _prop_manager: Node = null

func _ready() -> void:
	# Add to group so UI can find us
	add_to_group("build_cursor")

	# Create materials for cursor states
	_setup_materials()

	# Find the active camera
	_find_camera()

	# Get BuildingManager
	_building_manager = get_node_or_null("/root/BuildingManager")
	_prop_manager = get_node_or_null("/root/PropManager")

	# Connect to BuildingPanel prop selection (deferred)
	call_deferred("_connect_prop_selection")

	# Create buildings container
	_buildings_root = Node3D.new()
	_buildings_root.name = "Buildings"
	get_tree().current_scene.add_child.call_deferred(_buildings_root)

	# Hide default mesh (we'll use preview meshes instead)
	if mesh_instance:
		mesh_instance.visible = false

	# Hide cursor initially
	visible = false


func _connect_prop_selection() -> void:
	await get_tree().process_frame
	var panel: Node = get_tree().current_scene.get_node_or_null("UI/BuildingPanel")
	if panel and panel.has_signal("prop_selected"):
		panel.prop_selected.connect(_on_prop_selected)


func _on_prop_selected(prop: PropData) -> void:
	_selected_prop = prop
	# Deselect building
	if _building_manager:
		_building_manager.deselect_building()

## Call this to block building input (e.g., when a dialog opens)
func set_ui_blocking(blocking: bool) -> void:
	_ui_blocking = blocking
	if blocking:
		_is_mouse_held = false # Reset drag state
		visible = false # Hide cursor preview

func _unhandled_input(event: InputEvent) -> void:
	# Block input when UI dialogs are open
	if _ui_blocking:
		return

	# Block building when not in BUILD mode
	var game_mode: Node = get_node_or_null("/root/GameMode")
	if game_mode and not game_mode.is_build_mode():
		return

	# Escape to deselect building or prop (exit build mode)
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
			if _selected_prop:
				_selected_prop = null
				_is_mouse_held = false
				visible = false
				return
			if _building_manager and _building_manager.selected_building:
				_building_manager.deselect_building()
				_is_mouse_held = false
				visible = false
				return

	# Only handle build input if a building or prop is selected
	var has_selection: bool = (_building_manager and _building_manager.selected_building != null) or _selected_prop != null
	if not has_selection:
		return

	# Track mouse button state for continuous building
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_mouse_held = true
				_drag_start_pos = _current_grid_pos
				_drag_start_mouse = get_viewport().get_mouse_position()
				_drag_direction = -1 # Reset direction
				if _can_place and visible:
					_place_building()
					_last_placed_pos = _current_grid_pos
			else:
				_is_mouse_held = false
				_drag_direction = -1 # Reset on release
		elif event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
			_try_remove_block()

	# Spacebar to place (single placement, no drag)
	if event is InputEventKey:
		if event.keycode == KEY_SPACE and event.pressed and not event.echo:
			if _can_place and visible:
				_place_building()
				_last_placed_pos = _current_grid_pos

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

	# Find camera rig (parent of camera with look_towards method)
	if camera and not _camera_rig:
		var parent: Node = camera.get_parent()
		while parent:
			if parent.has_method("look_towards"):
				_camera_rig = parent as Node3D
				break
			parent = parent.get_parent()


func _update_preview_mesh() -> void:
	# Check if we're previewing a prop
	if _selected_prop:
		if _selected_prop == _current_preview_prop:
			return
		_clear_preview()
		_current_preview_prop = _selected_prop
		# Create prop preview mesh
		var prop_mesh := PropMeshGenerator.generate(_selected_prop)
		_preview_mesh = MeshInstance3D.new()
		_preview_mesh.mesh = prop_mesh
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1, 1, 1, 0.6)
		_preview_mesh.material_override = mat
		add_child(_preview_mesh)
		return

	# Otherwise preview building
	if not _building_manager:
		return
	var selected: BuildingData = _building_manager.selected_building

	# Only update if building changed
	if selected == _current_preview_building:
		return

	_clear_preview()
	_current_preview_building = selected

	if selected:
		_preview_mesh = selected.create_preview_mesh(true)
		add_child(_preview_mesh)


func _clear_preview() -> void:
	if _preview_mesh:
		_preview_mesh.queue_free()
		_preview_mesh = null
	_current_preview_building = null
	_current_preview_prop = null


func _process(delta: float) -> void:
	# Hide and skip when UI is blocking
	if _ui_blocking:
		visible = false
		return

	# Hide cursor when not in BUILD mode
	var game_mode: Node = get_node_or_null("/root/GameMode")
	if game_mode and not game_mode.is_build_mode():
		visible = false
		_clear_preview()
		_selected_prop = null
		return

	# Show cursor if either building or prop is selected
	var has_building: bool = _building_manager and _building_manager.selected_building != null
	var has_prop: bool = _selected_prop != null

	if not has_building and not has_prop:
		visible = false
		_clear_preview()
		return

	if not camera:
		_find_camera()
		if not camera:
			return

	# Update preview mesh if building changed
	_update_preview_mesh()

	_update_cursor_position()

	# Update cooldown
	if _place_cooldown > 0.0:
		_place_cooldown -= delta

	# Continuous building while mouse held
	if _is_mouse_held and _can_place and visible and _place_cooldown <= 0.0:
		# Only place if cursor moved to new position
		if _current_grid_pos != _last_placed_pos:
			# Determine drag direction on first move using SCREEN mouse movement
			if _drag_direction == -1:
				var current_mouse: Vector2 = get_viewport().get_mouse_position()
				var mouse_diff: Vector2 = current_mouse - _drag_start_mouse
				# Use screen-space: horizontal (X) vs vertical (Y on screen = usually Z or Y in world)
				if abs(mouse_diff.x) >= abs(mouse_diff.y):
					_drag_direction = 0 # Horizontal screen movement
				else:
					_drag_direction = 1 # Vertical screen movement

			# Only place if position stays on the locked axis from start
			var can_place_in_direction: bool = false
			match _drag_direction:
				0: # Horizontal - lock Y height, allow X or Z movement
					can_place_in_direction = (_current_grid_pos.y == _drag_start_pos.y)
				1: # Vertical - lock X and Z, allow Y movement (stacking up)
					can_place_in_direction = (_current_grid_pos.x == _drag_start_pos.x and _current_grid_pos.z == _drag_start_pos.z)

			if can_place_in_direction:
				_place_building()
				_last_placed_pos = _current_grid_pos
				_place_cooldown = PLACE_DELAY

				# Auto-pan camera based on build direction
				if _camera_rig:
					if _drag_direction == 0:
						# Horizontal building - rotate camera towards build direction
						var target_world_pos := Vector3(
							_current_grid_pos.x + 0.5,
							0.0,
							_current_grid_pos.z + 0.5
						)
						_camera_rig.look_towards(target_world_pos, 1.5)
					elif _drag_direction == 1:
						# Vertical building - tilt camera up to see tower
						_camera_rig.look_up_towards(_current_grid_pos.y, 2.0)

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

	# Get selected building to determine placement rules
	var selected_building: BuildingData = null
	if _building_manager:
		selected_building = _building_manager.selected_building

	var is_infrastructure: bool = selected_building and selected_building.category == "infrastructure"

	if is_infrastructure:
		# Infrastructure (roads, sidewalks) - always place at ground level
		grid_x = int(floor(hit_position.x))
		grid_y = int(INFRASTRUCTURE_HEIGHT)
		grid_z = int(floor(hit_position.z))
	elif hit_collider and hit_collider.is_in_group("placed_buildings"):
		# Hit a placed block - place adjacent block using normal
		# Get the center of the hit block
		var block_center: Vector3 = hit_collider.global_position

		# New block position = hit block position + normal (adjacent cell)
		var new_block_pos: Vector3 = block_center + hit_normal

		# Use round for all axes since blocks are centered at x.5, y, z.5
		grid_x = int(round(new_block_pos.x - 0.5))
		grid_y = int(round(new_block_pos.y))
		grid_z = int(round(new_block_pos.z - 0.5))
	else:
		# Hit terrain - place at normal building level
		grid_x = int(floor(hit_position.x))
		grid_y = int(PLACEMENT_HEIGHT)
		grid_z = int(floor(hit_position.z))

	# Store current grid position
	_current_grid_pos = Vector3i(grid_x, grid_y, grid_z)

	# Set cursor position centered on grid cell
	position = Vector3(grid_x + 0.5, grid_y, grid_z + 0.5)

	# Check if placement is valid
	_can_place = _is_placement_valid(grid_x, grid_y, grid_z)

	# Update preview mesh color based on validity
	if _preview_mesh:
		var mat: StandardMaterial3D = _preview_mesh.material_override as StandardMaterial3D
		if mat:
			if _can_place:
				mat.albedo_color.a = 0.6
			else:
				mat.albedo_color = Color(1.0, 0.3, 0.3, 0.6) # Red tint

	visible = true

func _is_placement_valid(grid_x: int, grid_y: int, grid_z: int) -> bool:
	# Check if within world bounds
	if grid_x < Config.WORLD_MIN_BLOCK or grid_x >= Config.WORLD_MAX_BLOCK:
		return false
	if grid_z < Config.WORLD_MIN_BLOCK or grid_z >= Config.WORLD_MAX_BLOCK:
		return false

	# Buildings only on interior grass (no beach, sea, cliffs, river)
	var col: Dictionary = WorldManager.terrain_column(grid_x, grid_z)
	if col["top"] != Config.VoxelType.GRASS or col["water"]:
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

	# Check if position already has a prop
	var props_root: Node = get_tree().current_scene.get_node_or_null("Props")
	if props_root:
		for child in props_root.get_children():
			var child_node := child as Node3D
			if child_node:
				var px: int = int(floor(child_node.global_position.x))
				var pz: int = int(floor(child_node.global_position.z))
				if px == grid_x and pz == grid_z:
					return false

	return true

func _place_building() -> void:
	# Handle prop placement
	if _selected_prop and _prop_manager:
		var prop_pos := Vector3(
			float(_current_grid_pos.x) + 0.5,
			Config.GROUND_Y,
			float(_current_grid_pos.z) + 0.5
		)
		var placed: StaticBody3D = _prop_manager.place_prop(prop_pos, _selected_prop, true)
		if placed:
			building_placed.emit(_current_grid_pos)
		return

	if not _buildings_root:
		return

	# Get selected building from manager
	var building_data: BuildingData = null

	if _building_manager and _building_manager.selected_building:
		building_data = _building_manager.selected_building
		# Check if player can afford
		if not _building_manager.try_place_building(_current_grid_pos):
			return # Can't afford or not unlocked

	# Create a StaticBody3D for collision (needed for stacking)
	var building := StaticBody3D.new()
	building.add_to_group("placed_buildings")
	building.collision_layer = BUILDING_COLLISION_LAYER
	building.collision_mask = 0 # Doesn't need to detect anything

	# Create detailed mesh using BuildingMeshGen
	var block_mesh := MeshInstance3D.new()
	block_mesh.name = "MeshInstance3D"

	if building_data:
		# Use procedural detailed mesh
		block_mesh.mesh = BuildingMeshGen.generate(building_data)
		# Store building data for save/load
		building.set_meta("building_id", building_data.display_name)
	else:
		# Fallback to simple box
		var box_mesh := BoxMesh.new()
		box_mesh.size = Vector3(1.0, 1.0, 1.0)
		block_mesh.mesh = box_mesh
		var mat := StandardMaterial3D.new()
		var colors := [Color.CORAL, Color.CORNFLOWER_BLUE, Color.GOLD]
		mat.albedo_color = colors[randi() % colors.size()]
		block_mesh.material_override = mat

	building.add_child(block_mesh)

	# Create collision shape based on building size
	var collision := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	var collision_size := Vector3(1.0, 1.0, 1.0)
	if building_data:
		collision_size = Vector3(building_data.size)
	box_shape.size = collision_size
	collision.shape = box_shape
	# Center collision for multi-block buildings
	collision.position = collision_size * 0.5 - Vector3(0.5, 0, 0.5)
	building.add_child(collision)

	# Position at grid location (centered for 1x1, corner for larger)
	building.position = Vector3(_current_grid_pos.x + 0.5, _current_grid_pos.y, _current_grid_pos.z + 0.5)

	_buildings_root.add_child(building)

	# Set up window emission material (surface index 1) for night illumination
	if building_data and building_data.category != "infrastructure":
		var win_mat := StandardMaterial3D.new()
		win_mat.vertex_color_use_as_albedo = true
		win_mat.emission_enabled = false
		win_mat.emission = building_data.secondary_color * 1.5
		win_mat.emission_energy_multiplier = 1.5
		block_mesh.set_surface_override_material(1, win_mat)
		block_mesh.set_meta("has_window_surface", true)

	# Attach lamp light for street lamp buildings
	if building_data and building_data.display_name == "Straßenlampe":
		var lamp := OmniLight3D.new()
		lamp.name = "LampLight"
		lamp.position = Vector3(0.5, 2.0, 0.5)
		lamp.light_color = building_data.secondary_color
		lamp.light_energy = 2.5
		lamp.omni_range = 8.0
		lamp.shadow_enabled = false
		lamp.visible = false
		building.add_child(lamp)
		building.set_meta("is_street_lamp", true)

	# Add interaction prompt label (starts invisible)
	var prompt := Label3D.new()
	prompt.name = "InteractionPrompt"
	prompt.text = "[T] Erkunden"
	var prompt_y: float = float(building_data.size.y) if building_data else 1.0
	prompt.position = Vector3(0.5, prompt_y + 0.3, 0.5)
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.modulate = Color(1, 0.95, 0.6, 0)  # alpha = 0 (invisible)
	prompt.pixel_size = 0.01
	prompt.outline_modulate = Color(0.1, 0.1, 0.1, 1)
	building.add_child(prompt)

	# Initialize building level (progression state)
	building.set_meta("building_level", 0)

	# Play pop-in animation
	_play_building_pop_animation(building)

	building_placed.emit(_current_grid_pos)


func _play_building_pop_animation(building: Node3D) -> void:
	# Scale bounce animation
	building.scale = Vector3.ZERO
	var tween := create_tween()
	tween.tween_property(building, "scale", Vector3(1.15, 1.15, 1.15), 0.12).set_ease(Tween.EASE_OUT)
	tween.tween_property(building, "scale", Vector3.ONE, 0.08).set_ease(Tween.EASE_IN_OUT)

	# Small shake
	var original_pos := building.position
	tween.parallel().tween_property(building, "position:x", original_pos.x + 0.03, 0.03)
	tween.tween_property(building, "position:x", original_pos.x - 0.03, 0.06)
	tween.tween_property(building, "position:x", original_pos.x, 0.03)

	# Spawn particles
	_spawn_placement_particles(building.position)

func _try_remove_block() -> void:
	if not camera:
		return

	var viewport: Viewport = get_viewport()
	if not viewport:
		return

	var mouse_pos: Vector2 = viewport.get_mouse_position()
	var ray_origin: Vector3 = camera.project_ray_origin(mouse_pos)
	var ray_direction: Vector3 = camera.project_ray_normal(mouse_pos)

	# Setup raycast - hit buildings (layer 2) and props (layer 8)
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		ray_origin,
		ray_origin + ray_direction * 100.0
	)
	query.collision_mask = BUILDING_COLLISION_LAYER | PROP_COLLISION_LAYER

	var result: Dictionary = space_state.intersect_ray(query)

	if result.is_empty():
		return

	# Get the collider (StaticBody3D building or prop)
	var collider: Node = result.get("collider")
	if collider and collider.is_in_group("placed_buildings"):
		collider.queue_free()
	elif collider and collider.is_in_group("placed_props"):
		var prop_manager: Node = get_node_or_null("/root/PropManager")
		if prop_manager:
			prop_manager.remove_prop(collider)
		else:
			collider.queue_free()


func _spawn_placement_particles(pos: Vector3) -> void:
	# Create simple particle burst using GPUParticles3D
	var particles := GPUParticles3D.new()
	particles.position = pos + Vector3(0, 0.5, 0)
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 12
	particles.lifetime = 0.6

	# Create particle material
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 45.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 4.0
	mat.gravity = Vector3(0, -8, 0)
	mat.scale_min = 0.1
	mat.scale_max = 0.2
	mat.color = Color(1.0, 0.9, 0.5, 1.0) # Golden sparkle
	particles.process_material = mat

	# Create simple mesh for particles
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	particles.draw_pass_1 = mesh

	get_tree().current_scene.add_child(particles)

	# Auto-cleanup
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(particles):
		particles.queue_free()
