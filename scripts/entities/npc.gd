extends CharacterBody3D
class_name NPC

## NPC Entity
##
## Clickable NPC that triggers a quiz when interacted with.
## Rewards education points for correct answers.

signal clicked(npc: NPC)
signal quiz_completed(npc: NPC, was_correct: bool)

## NPC collision layer for raycast detection (uses Config.NPC_COLLISION_LAYER)

## NPC data resource defining category, rewards, etc.
@export var npc_data: NPCData

## Reference to mesh for color updates
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var label_3d: Label3D = $Label3D

## Material for the NPC mesh (body material from build result)
var _material: StandardMaterial3D
var _base_color: Color

## Body part references for animations
var _body_parts: Dictionary = {}
var _build_result: BlockyCharacterBuilder.BuildResult

## Is this NPC currently in a quiz?
var _in_quiz: bool = false

## Is mouse hovering over this NPC?
var _is_hovered: bool = false

## Movement
var _walk_speed: float = 1.0
var _target_position: Vector3
var _walk_timer: float = 0.0
var _is_walking: bool = false
var _was_walking: bool = false
var _walk_tween: Tween
var _walk_range: float = 8.0


func _ready() -> void:
	add_to_group("npcs")

	# Setup material with NPC color
	_setup_material()

	# Setup label with emoji
	if label_3d and npc_data:
		label_3d.text = "%s %s" % [npc_data.emoji, npc_data.display_name]

	# Register with NPCManager (for NPCs placed in scene, not spawned)
	_register_with_manager()

	# Play spawn animation
	_play_spawn_animation()

	# Initialize walking
	_target_position = global_position
	_pick_new_target()


func _physics_process(delta: float) -> void:
	if _in_quiz:
		return

	# Move towards target
	var direction := (_target_position - global_position)
	direction.y = 0 # Stay on ground

	if direction.length() > 0.5:
		_is_walking = true
		direction = direction.normalized()
		velocity = direction * _walk_speed

		# Rotate to face direction
		var target_angle := atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, delta * 5.0)

		move_and_slide()

		# Keep on ground
		position.y = Config.GROUND_Y
	else:
		_is_walking = false
		velocity = Vector3.ZERO

		# Pick new target after waiting
		_walk_timer -= delta
		if _walk_timer <= 0:
			_pick_new_target()

	# Update walk animation based on movement
	if _is_walking and not _was_walking:
		_start_walk_animation()
	elif not _is_walking and _was_walking:
		_stop_walk_animation()
	_was_walking = _is_walking


func _pick_new_target() -> void:
	# Random point within walk range from current position
	var angle := randf() * TAU
	var distance := randf_range(2.0, _walk_range)

	_target_position = Vector3(
		global_position.x + cos(angle) * distance,
		Config.GROUND_Y,
		global_position.z + sin(angle) * distance
	)

	# Clamp to world bounds using Config constants
	_target_position.x = clampf(_target_position.x, Config.WORLD_MIN_X + 0.5, Config.WORLD_MAX_X - 0.5)
	_target_position.z = clampf(_target_position.z, Config.WORLD_MIN_Z + 0.5, Config.WORLD_MAX_Z - 0.5)

	# Wait 2-5 seconds before moving again after reaching target
	_walk_timer = randf_range(2.0, 5.0)


func _play_spawn_animation() -> void:
	# Scale from 0 to 1 with bounce
	scale = Vector3.ZERO
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.2, 1.2, 1.2), 0.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector3.ONE, 0.1).set_ease(Tween.EASE_IN_OUT)


func _start_walk_animation() -> void:
	# Walking animation - legs and arms swing
	if not _body_parts.has("left_leg"):
		return

	if _walk_tween and _walk_tween.is_valid():
		_walk_tween.kill()

	var left_leg: Node3D = _body_parts["left_leg"]
	var right_leg: Node3D = _body_parts["right_leg"]
	var left_arm: Node3D = _body_parts["left_arm"]
	var right_arm: Node3D = _body_parts["right_arm"]

	# Leg swing (walking motion)
	_walk_tween = create_tween()
	_walk_tween.set_loops()
	_walk_tween.tween_property(left_leg, "rotation_degrees:x", 25.0, 0.3).set_ease(Tween.EASE_IN_OUT)
	_walk_tween.parallel().tween_property(right_leg, "rotation_degrees:x", -25.0, 0.3).set_ease(Tween.EASE_IN_OUT)
	_walk_tween.parallel().tween_property(left_arm, "rotation_degrees:x", -20.0, 0.3).set_ease(Tween.EASE_IN_OUT)
	_walk_tween.parallel().tween_property(right_arm, "rotation_degrees:x", 20.0, 0.3).set_ease(Tween.EASE_IN_OUT)
	_walk_tween.tween_property(left_leg, "rotation_degrees:x", -25.0, 0.3).set_ease(Tween.EASE_IN_OUT)
	_walk_tween.parallel().tween_property(right_leg, "rotation_degrees:x", 25.0, 0.3).set_ease(Tween.EASE_IN_OUT)
	_walk_tween.parallel().tween_property(left_arm, "rotation_degrees:x", 20.0, 0.3).set_ease(Tween.EASE_IN_OUT)
	_walk_tween.parallel().tween_property(right_arm, "rotation_degrees:x", -20.0, 0.3).set_ease(Tween.EASE_IN_OUT)


func _stop_walk_animation() -> void:
	if _walk_tween and _walk_tween.is_valid():
		_walk_tween.kill()

	# Reset limbs to neutral position
	for part_name: String in ["left_arm", "right_arm", "left_leg", "right_leg"]:
		if _body_parts.has(part_name):
			var part: Node3D = _body_parts[part_name]
			part.rotation_degrees.x = 0.0


func _register_with_manager() -> void:
	var npc_manager: Node = get_node_or_null("/root/NPCManager")
	if npc_manager:
		# Connect signals
		if not clicked.is_connected(npc_manager._on_npc_clicked):
			clicked.connect(npc_manager._on_npc_clicked)
		if not quiz_completed.is_connected(npc_manager._on_npc_quiz_completed):
			quiz_completed.connect(npc_manager._on_npc_quiz_completed)


func _setup_material() -> void:
	if not mesh_instance:
		return

	# Get base color from NPC data
	if npc_data:
		_base_color = npc_data.color
	else:
		_base_color = Color.CORNFLOWER_BLUE

	# Create blocky person mesh
	_create_blocky_person()


func _create_blocky_person() -> void:
	# Remove default mesh
	mesh_instance.mesh = null

	# Use BlockyCharacterBuilder for unified character creation
	var hair_color := _get_hair_color()
	_build_result = BlockyCharacterBuilder.build_npc(mesh_instance, _base_color, hair_color)
	_body_parts = _build_result.body_parts
	_material = _build_result.materials.get("body") as StandardMaterial3D


func _get_hair_color() -> Color:
	# Variety of hair colors based on NPC category
	if not npc_data:
		return Color(0.3, 0.2, 0.1) # Brown

	match npc_data.category:
		"math":
			return Color(0.2, 0.15, 0.1) # Dark brown
		"science":
			return Color(0.1, 0.1, 0.1) # Black
		"geography":
			return Color(0.6, 0.4, 0.2) # Light brown
		"history":
			return Color(0.5, 0.5, 0.5) # Gray
		"language":
			return Color(0.8, 0.6, 0.3) # Blonde
		"music":
			return Color(0.9, 0.3, 0.3) # Red
		"art":
			return Color(0.6, 0.3, 0.6) # Purple
		_:
			return Color(0.3, 0.2, 0.1) # Brown


## Called by NPCManager when mouse hovers over this NPC
func set_hovered(hovered: bool) -> void:
	if _is_hovered == hovered:
		return
	_is_hovered = hovered

	if _material:
		if hovered:
			# Brighten color on hover
			_material.albedo_color = _base_color.lightened(0.3)
			_material.emission_enabled = true
			_material.emission = _base_color
			_material.emission_energy_multiplier = 0.5
		else:
			_material.albedo_color = _base_color
			_material.emission_enabled = false


## Called by NPCManager when clicked
func interact() -> void:
	if not _in_quiz:
		_start_interaction()


func _start_interaction() -> void:
	_in_quiz = true
	clicked.emit(self)
	
	# Visual feedback - slight scale up
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.2, 1.2, 1.2), 0.1)
	tween.tween_property(self, "scale", Vector3.ONE, 0.1)


## Called by QuizWindow when quiz is completed
func on_quiz_result(was_correct: bool) -> void:
	_in_quiz = false
	quiz_completed.emit(self, was_correct)
	
	if was_correct:
		_on_correct_answer()
	else:
		_on_wrong_answer()


func _on_correct_answer() -> void:
	# Happy animation - jump and disappear
	AudioManager.play_sfx(AudioManager.SFX.NPC_DESPAWN)

	# Spawn celebration particles
	_spawn_celebration_particles()

	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y + 2.0, 0.3).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "scale", Vector3(0.1, 0.1, 0.1), 0.3)
	tween.tween_callback(queue_free)


func _spawn_celebration_particles() -> void:
	var particles := GPUParticles3D.new()
	particles.position = global_position + Vector3(0, 0.5, 0)
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 20
	particles.lifetime = 0.8

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 60.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 6.0
	mat.gravity = Vector3(0, -5, 0)
	mat.scale_min = 0.08
	mat.scale_max = 0.15
	mat.color = _base_color.lightened(0.3)
	particles.process_material = mat

	var mesh := SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	particles.draw_pass_1 = mesh

	get_tree().current_scene.add_child(particles)

	# Auto-cleanup
	get_tree().create_timer(1.5).timeout.connect(func() -> void:
		if is_instance_valid(particles):
			particles.queue_free()
	)


func _on_wrong_answer() -> void:
	# Sad animation - shake head
	var tween := create_tween()
	var original_x := position.x
	tween.tween_property(self, "position:x", original_x - 0.2, 0.05)
	tween.tween_property(self, "position:x", original_x + 0.2, 0.1)
	tween.tween_property(self, "position:x", original_x - 0.2, 0.1)
	tween.tween_property(self, "position:x", original_x, 0.05)
	
	# Change color briefly to indicate wrong
	if _material:
		var original_color := _material.albedo_color
		_material.albedo_color = Color.INDIAN_RED
		await get_tree().create_timer(0.5).timeout
		_material.albedo_color = original_color


## Get the quiz category for this NPC
func get_category() -> String:
	if npc_data:
		return npc_data.category
	return ""


## Get reward points for correct answer
func get_reward_points() -> int:
	if npc_data:
		return npc_data.reward_points
	return 10
