extends CharacterBody3D
class_name Player

## Player Entity
##
## Player-controlled character that can walk around the world.
## Only moves when GameMode is WALK.

const WALK_SPEED: float = 5.0
const ROTATION_SPEED: float = 10.0

## Body part references for animations
var _body_parts: Dictionary = {}
var _is_walking: bool = false
var _was_walking: bool = false
var _walk_tween: Tween

## Build result from BlockyCharacterBuilder (contains materials)
var _build_result: BlockyCharacterBuilder.BuildResult

## Current customization reference
var _customization: PlayerCustomization

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	add_to_group("player")

	# Register with GameMode
	GameMode.player = self

	# Setup collision to detect buildings
	collision_mask = Config.BUILDING_COLLISION_LAYER

	# Create the blocky character mesh
	_create_blocky_person()

	# Set initial position
	position.y = Config.GROUND_Y


func _physics_process(delta: float) -> void:
	# Only move in WALK mode
	if not GameMode.is_walk_mode():
		return
	
	# Get input direction
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
			velocity = direction * WALK_SPEED
			
			# Rotate player to face movement direction
			var target_angle := atan2(direction.x, direction.z)
			rotation.y = lerp_angle(rotation.y, target_angle, delta * ROTATION_SPEED)
	else:
		_is_walking = false
		velocity = Vector3.ZERO

	move_and_slide()

	# Clamp position to world boundaries
	position.x = clampf(position.x, Config.WORLD_MIN_X, Config.WORLD_MAX_X)
	position.z = clampf(position.z, Config.WORLD_MIN_Z, Config.WORLD_MAX_Z)

	# Keep on ground
	position.y = Config.GROUND_Y

	# Update walk animation based on movement
	if _is_walking and not _was_walking:
		_start_walk_animation()
	elif not _is_walking and _was_walking:
		_stop_walk_animation()
	_was_walking = _is_walking


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
