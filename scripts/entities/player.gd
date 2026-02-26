extends CharacterBody3D
class_name Player

## Player Entity
##
## Player-controlled character that can walk around the world.
## Only moves when GameMode is WALK.
## Supports WASD movement and Space to jump.

const WALK_SPEED: float = 5.0
const ROTATION_SPEED: float = 10.0
const JUMP_VELOCITY: float = 6.0
const GRAVITY: float = 20.0
const COYOTE_TIME: float = 0.12  ## Grace period (seconds) to jump after leaving ground

## Body part references for animations
var _body_parts: Dictionary = {}
var _is_walking: bool = false
var _was_walking: bool = false
var _walk_tween: Tween
var _coyote_timer: float = 0.0  ## Remaining coyote time

## Build result from BlockyCharacterBuilder (contains materials)
var _build_result: BlockyCharacterBuilder.BuildResult

## Current customization reference
var _customization: PlayerCustomization

## Interaction
var _nearby_npcs: Array[NPC] = []
var _nearest_npc: NPC = null
var _nearby_buildings: Array[StaticBody3D] = []
var _nearest_building: StaticBody3D = null

signal nearest_npc_changed(npc: NPC)
signal nearest_building_changed(building: StaticBody3D)

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var interaction_area: Area3D = $InteractionArea


func _ready() -> void:
	add_to_group("player")

	# Register with GameMode
	GameMode.player = self

	# Setup collision to detect buildings
	collision_mask = Config.TERRAIN_COLLISION_LAYER | Config.BUILDING_COLLISION_LAYER

	# Create the blocky character mesh
	_create_blocky_person()

	# Set initial position
	position.y = Config.GROUND_Y

	# Setup interaction area signals
	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_area_body_entered)
		interaction_area.body_exited.connect(_on_interaction_area_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if not GameMode.is_walk_mode():
		return

	if event.is_action_pressed("interact"):
		var npc_manager: Node = get_node_or_null("/root/NPCManager")
		if _nearest_npc and npc_manager:
			npc_manager.interact_with(_nearest_npc)
			get_viewport().set_input_as_handled()
		elif _nearest_building and npc_manager:
			npc_manager.interact_with_building(_nearest_building)
			get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	# Only move in WALK mode
	if not GameMode.is_walk_mode():
		return

	# --- Gravity ---
	var grounded := is_on_floor()
	if grounded:
		_coyote_timer = COYOTE_TIME
	else:
		_coyote_timer -= delta
		velocity.y -= GRAVITY * delta

	# --- Jump ---
	var can_jump := grounded or _coyote_timer > 0.0
	if can_jump and Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY
		_coyote_timer = 0.0  # Consume coyote time

	# --- Horizontal movement (WASD) ---
	var input_dir := Vector2.ZERO
	if Input.is_action_pressed("move_forward"):
		input_dir.y += 1.0
	if Input.is_action_pressed("move_back"):
		input_dir.y -= 1.0
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1.0

	if input_dir.length_squared() > 0.0:
		input_dir = input_dir.normalized()
		_is_walking = true

		# Get camera forward direction (from the main camera)
		var camera := get_viewport().get_camera_3d()
		if camera:
			var cam_transform := camera.global_transform
			var forward := -cam_transform.basis.z
			forward.y = 0
			forward = forward.normalized()
			var right := cam_transform.basis.x
			right.y = 0
			right = right.normalized()

			# Calculate movement direction relative to camera
			var direction := (forward * input_dir.y + right * input_dir.x).normalized()
			velocity.x = direction.x * WALK_SPEED
			velocity.z = direction.z * WALK_SPEED

			# Rotate player to face movement direction
			var target_angle := atan2(direction.x, direction.z)
			rotation.y = lerp_angle(rotation.y, target_angle, delta * ROTATION_SPEED)
	else:
		_is_walking = false
		velocity.x = 0.0
		velocity.z = 0.0

	move_and_slide()

	# Clamp position to world boundaries
	position.x = clampf(position.x, Config.WORLD_MIN_X, Config.WORLD_MAX_X)
	position.z = clampf(position.z, Config.WORLD_MIN_Z, Config.WORLD_MAX_Z)

	# Prevent falling below ground level
	if position.y < Config.GROUND_Y:
		position.y = Config.GROUND_Y
		velocity.y = 0.0

	# Update walk animation based on movement
	if _is_walking and not _was_walking:
		_start_walk_animation()
	elif not _is_walking and _was_walking:
		_stop_walk_animation()
	_was_walking = _is_walking

	# Update nearest NPC and building
	_update_nearest_npc()
	_update_nearest_building()


func _create_blocky_person() -> void:
	# Remove default mesh
	mesh_instance.mesh = null

	# Load customization from profile
	_customization = _get_customization()

	# Use BlockyCharacterBuilder for unified character creation
	_build_result = BlockyCharacterBuilder.build_from_customization(mesh_instance, _customization)
	_body_parts = _build_result.body_parts


func _get_customization() -> PlayerCustomization:
	if ProfileManager and ProfileManager.current_profile:
		return ProfileManager.current_profile.get_customization()
	return PlayerCustomization.create_default()


## Rebuild character with new customization
func apply_customization(custom: PlayerCustomization) -> void:
	_customization = custom
	_create_blocky_person()


func _start_walk_animation() -> void:
	if _walk_tween and _walk_tween.is_valid():
		_walk_tween.kill()

	_walk_tween = create_tween()
	_walk_tween.set_loops()

	var walk_speed: float = 0.35
	var swing_angle: float = 0.5 # radians

	# Animate arms and legs swinging
	if _body_parts.has("left_arm"):
		var left_arm: MeshInstance3D = _body_parts["left_arm"]
		_walk_tween.parallel().tween_property(left_arm, "rotation:x", swing_angle, walk_speed)
	if _body_parts.has("right_arm"):
		var right_arm: MeshInstance3D = _body_parts["right_arm"]
		_walk_tween.parallel().tween_property(right_arm, "rotation:x", -swing_angle, walk_speed)
	if _body_parts.has("left_leg"):
		var left_leg: MeshInstance3D = _body_parts["left_leg"]
		_walk_tween.parallel().tween_property(left_leg, "rotation:x", -swing_angle * 0.7, walk_speed)
	if _body_parts.has("right_leg"):
		var right_leg: MeshInstance3D = _body_parts["right_leg"]
		_walk_tween.parallel().tween_property(right_leg, "rotation:x", swing_angle * 0.7, walk_speed)

	# Second half of walk cycle
	if _body_parts.has("left_arm"):
		var left_arm: MeshInstance3D = _body_parts["left_arm"]
		_walk_tween.tween_property(left_arm, "rotation:x", -swing_angle, walk_speed)
	if _body_parts.has("right_arm"):
		var right_arm: MeshInstance3D = _body_parts["right_arm"]
		_walk_tween.parallel().tween_property(right_arm, "rotation:x", swing_angle, walk_speed)
	if _body_parts.has("left_leg"):
		var left_leg: MeshInstance3D = _body_parts["left_leg"]
		_walk_tween.parallel().tween_property(left_leg, "rotation:x", swing_angle * 0.7, walk_speed)
	if _body_parts.has("right_leg"):
		var right_leg: MeshInstance3D = _body_parts["right_leg"]
		_walk_tween.parallel().tween_property(right_leg, "rotation:x", -swing_angle * 0.7, walk_speed)


func _stop_walk_animation() -> void:
	if _walk_tween and _walk_tween.is_valid():
		_walk_tween.kill()

	# Reset limbs to neutral position
	for part_name: String in ["left_arm", "right_arm", "left_leg", "right_leg"]:
		if _body_parts.has(part_name):
			var part: MeshInstance3D = _body_parts[part_name]
			part.rotation.x = 0.0


## --- NPC Proximity Detection ---

func _on_interaction_area_body_entered(body: Node3D) -> void:
	if body is NPC:
		var npc := body as NPC
		if not _nearby_npcs.has(npc):
			_nearby_npcs.append(npc)
	elif body is StaticBody3D and body.is_in_group("placed_buildings"):
		var building := body as StaticBody3D
		if not _nearby_buildings.has(building):
			_nearby_buildings.append(building)


func _on_interaction_area_body_exited(body: Node3D) -> void:
	if body is NPC:
		var npc := body as NPC
		_nearby_npcs.erase(npc)
		if _nearest_npc == npc:
			_nearest_npc = null
			nearest_npc_changed.emit(null)
	elif body is StaticBody3D and body.is_in_group("placed_buildings"):
		var building := body as StaticBody3D
		_nearby_buildings.erase(building)
		if _nearest_building == building:
			_nearest_building = null
			nearest_building_changed.emit(null)


func _update_nearest_npc() -> void:
	# Clean up invalid references
	var valid_npcs: Array[NPC] = []
	for npc: NPC in _nearby_npcs:
		if is_instance_valid(npc):
			valid_npcs.append(npc)
	_nearby_npcs = valid_npcs

	# Find closest NPC
	var closest: NPC = null
	var closest_dist: float = INF
	for npc: NPC in _nearby_npcs:
		var dist := global_position.distance_squared_to(npc.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = npc

	if closest != _nearest_npc:
		_nearest_npc = closest
		nearest_npc_changed.emit(_nearest_npc)


func _update_nearest_building() -> void:
	# Clean up invalid references
	var valid_buildings: Array[StaticBody3D] = []
	for building: StaticBody3D in _nearby_buildings:
		if is_instance_valid(building):
			valid_buildings.append(building)
	_nearby_buildings = valid_buildings

	# Find closest building
	var closest: StaticBody3D = null
	var closest_dist: float = INF
	for building: StaticBody3D in _nearby_buildings:
		var dist := global_position.distance_squared_to(building.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = building

	if closest != _nearest_building:
		_nearest_building = closest
		nearest_building_changed.emit(_nearest_building)
