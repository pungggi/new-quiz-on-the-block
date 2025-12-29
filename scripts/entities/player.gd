extends CharacterBody3D
class_name Player

## Player Entity
##
## Player-controlled character that can walk around the world.
## Only moves when GameMode is WALK.

const GROUND_Y: float = 0.7 # Same as NPCs - feet touch ground at Y=1.0
const WALK_SPEED: float = 5.0
const ROTATION_SPEED: float = 10.0

## World boundaries (3x3 chunks: chunk -1 to 1, each 16 units)
## Chunk -1: x=-16 to -1, Chunk 0: x=0 to 15, Chunk 1: x=16 to 31
## Total: x/z from -16 to 32 (48 units, but NOT centered at origin)
const WORLD_MIN_X: float = -15.5
const WORLD_MAX_X: float = 31.5
const WORLD_MIN_Z: float = -15.5
const WORLD_MAX_Z: float = 31.5

## Collision layers
const TERRAIN_COLLISION_LAYER: int = 1
const BUILDING_COLLISION_LAYER: int = 2

## Body part references for animations
var _body_parts: Dictionary = {}
var _is_walking: bool = false
var _was_walking: bool = false
var _walk_tween: Tween

## Material references (stored for runtime updates)
var _skin_material: StandardMaterial3D
var _hair_material: StandardMaterial3D
var _body_material: StandardMaterial3D
var _leg_material: StandardMaterial3D
var _glasses_material: StandardMaterial3D
var _hat_material: StandardMaterial3D

## Current customization reference
var _customization: PlayerCustomization

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	add_to_group("player")

	# Register with GameMode
	GameMode.player = self

	# Setup collision to detect buildings
	collision_mask = BUILDING_COLLISION_LAYER

	# Create the blocky character mesh
	_create_blocky_person()

	# Set initial position
	position.y = GROUND_Y


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
	position.x = clampf(position.x, WORLD_MIN_X, WORLD_MAX_X)
	position.z = clampf(position.z, WORLD_MIN_Z, WORLD_MAX_Z)

	# Keep on ground
	position.y = GROUND_Y

	# Update walk animation based on movement
	if _is_walking and not _was_walking:
		_start_walk_animation()
	elif not _is_walking and _was_walking:
		_stop_walk_animation()
	_was_walking = _is_walking


func _create_blocky_person() -> void:
	# Remove default mesh and old children
	mesh_instance.mesh = null
	for child in mesh_instance.get_children():
		child.queue_free()

	# Load customization from profile
	_customization = _get_customization()

	# Create materials from customization
	_skin_material = StandardMaterial3D.new()
	_skin_material.albedo_color = _customization.skin_color

	_hair_material = StandardMaterial3D.new()
	_hair_material.albedo_color = _customization.hair_color

	_body_material = StandardMaterial3D.new()
	_body_material.albedo_color = _customization.shirt_color

	_leg_material = StandardMaterial3D.new()
	_leg_material.albedo_color = _customization.pants_color

	_glasses_material = StandardMaterial3D.new()
	_glasses_material.albedo_color = _customization.glasses_color

	_hat_material = StandardMaterial3D.new()
	_hat_material.albedo_color = _customization.hat_color

	# HEAD
	var head := MeshInstance3D.new()
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.35, 0.35, 0.35)
	head.mesh = head_mesh
	head.position = Vector3(0, 0.9, 0)
	head.material_override = _skin_material
	mesh_instance.add_child(head)

	# HAIR (based on style)
	_create_hair(head)

	# GLASSES (if enabled)
	if _customization.glasses_type != PlayerCustomization.GlassesType.NONE:
		_create_glasses(head)

	# HAT (if enabled)
	if _customization.hat_type != PlayerCustomization.HatType.NONE:
		_create_hat(head)

	# BODY/TORSO
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.4, 0.5, 0.25)
	body.mesh = body_mesh
	body.position = Vector3(0, 0.45, 0)
	body.material_override = _body_material
	mesh_instance.add_child(body)

	# LEFT ARM
	var left_arm := MeshInstance3D.new()
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.15, 0.45, 0.15)
	left_arm.mesh = arm_mesh
	left_arm.position = Vector3(-0.275, 0.45, 0)
	left_arm.material_override = _skin_material
	mesh_instance.add_child(left_arm)

	# RIGHT ARM
	var right_arm := MeshInstance3D.new()
	right_arm.mesh = arm_mesh
	right_arm.position = Vector3(0.275, 0.45, 0)
	right_arm.material_override = _skin_material
	mesh_instance.add_child(right_arm)

	# LEFT LEG
	var left_leg := MeshInstance3D.new()
	var leg_mesh := BoxMesh.new()
	leg_mesh.size = Vector3(0.18, 0.4, 0.18)
	left_leg.mesh = leg_mesh
	left_leg.position = Vector3(-0.1, 0, 0)
	left_leg.material_override = _leg_material
	mesh_instance.add_child(left_leg)

	# RIGHT LEG
	var right_leg := MeshInstance3D.new()
	right_leg.mesh = leg_mesh
	right_leg.position = Vector3(0.1, 0, 0)
	right_leg.material_override = _leg_material
	mesh_instance.add_child(right_leg)

	# Store references
	_body_parts = {
		"head": head,
		"body": body,
		"left_arm": left_arm,
		"right_arm": right_arm,
		"left_leg": left_leg,
		"right_leg": right_leg
	}


func _get_customization() -> PlayerCustomization:
	if ProfileManager and ProfileManager.current_profile:
		return ProfileManager.current_profile.get_customization()
	return PlayerCustomization.create_default()


func _create_hair(head: MeshInstance3D) -> void:
	var hair := MeshInstance3D.new()
	hair.name = "Hair"
	var hair_mesh := BoxMesh.new()

	match _customization.hair_style:
		PlayerCustomization.HairStyle.SHORT:
			hair_mesh.size = Vector3(0.37, 0.12, 0.37)
			hair.position = Vector3(0, 0.17, 0)
		PlayerCustomization.HairStyle.LONG:
			hair_mesh.size = Vector3(0.38, 0.25, 0.38)
			hair.position = Vector3(0, 0.12, 0)
		PlayerCustomization.HairStyle.SPIKY:
			hair_mesh.size = Vector3(0.32, 0.18, 0.32)
			hair.position = Vector3(0, 0.20, 0)
		PlayerCustomization.HairStyle.BALD:
			return # No hair

	hair.mesh = hair_mesh
	hair.material_override = _hair_material
	head.add_child(hair)


func _create_glasses(head: MeshInstance3D) -> void:
	var glasses := MeshInstance3D.new()
	glasses.name = "Glasses"
	var glasses_mesh := BoxMesh.new()

	match _customization.glasses_type:
		PlayerCustomization.GlassesType.ROUND:
			glasses_mesh.size = Vector3(0.36, 0.08, 0.05)
		PlayerCustomization.GlassesType.SQUARE:
			glasses_mesh.size = Vector3(0.38, 0.10, 0.05)

	glasses.mesh = glasses_mesh
	glasses.position = Vector3(0, 0.02, 0.16)
	glasses.material_override = _glasses_material
	head.add_child(glasses)


func _create_hat(head: MeshInstance3D) -> void:
	var hat := MeshInstance3D.new()
	hat.name = "Hat"
	var hat_mesh := BoxMesh.new()

	match _customization.hat_type:
		PlayerCustomization.HatType.CAP:
			hat_mesh.size = Vector3(0.40, 0.10, 0.42)
			hat.position = Vector3(0, 0.20, 0.02)
			# Add cap visor
			var visor := MeshInstance3D.new()
			var visor_mesh := BoxMesh.new()
			visor_mesh.size = Vector3(0.30, 0.03, 0.15)
			visor.mesh = visor_mesh
			visor.position = Vector3(0, -0.03, 0.22)
			visor.material_override = _hat_material
			hat.add_child(visor)
		PlayerCustomization.HatType.BEANIE:
			hat_mesh.size = Vector3(0.38, 0.15, 0.38)
			hat.position = Vector3(0, 0.22, 0)

	hat.mesh = hat_mesh
	hat.material_override = _hat_material
	head.add_child(hat)


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
