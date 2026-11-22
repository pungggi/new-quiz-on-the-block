extends CharacterBody3D
class_name NPC

## NPC Entity
##
## Clickable NPC that triggers a quiz when interacted with.
## Rewards education points for correct answers.
## Can make campfires during night if configured.

signal clicked(npc: NPC)
signal quiz_completed(npc: NPC, was_correct: bool)

## NPC collision layer for raycast detection (uses Config.NPC_COLLISION_LAYER)

## NPC data resource defining category, rewards, etc.
@export var npc_data: NPCData

## Reference to mesh for color updates
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var label_3d: Label3D = $Label3D
@onready var interaction_prompt: Label3D = $InteractionPrompt

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
var _stuck_timer: float = 0.0
var _last_position: Vector3 = Vector3.ZERO

## Idle animation
var _idle_tween: Tween
var _idle_timer: float = 0.0
const IDLE_ANIM_INTERVAL_MIN: float = 1.5
const IDLE_ANIM_INTERVAL_MAX: float = 4.0

## Fire
const FIRE_SCENE: PackedScene = preload("res://scenes/effects/campfire.tscn")
var _campfire: Node3D = null
var _can_make_fire: bool = false

## Prompt animation
var _prompt_tween: Tween


func _ready() -> void:
	add_to_group("npcs")

	# Terrain, buildings AND props block NPCs - they slide around trees and
	# cliffs instead of walking through them. Layer stays NPC (4) for raycasts.
	collision_mask = Config.TERRAIN_COLLISION_LAYER | Config.BUILDING_COLLISION_LAYER | Config.PROP_COLLISION_LAYER

	# Setup material with NPC color
	_setup_material()

	# Setup label with emoji
	if label_3d and npc_data:
		label_3d.text = "%s %s" % [npc_data.emoji, npc_data.display_name]
		_can_make_fire = npc_data.can_make_fire

	# Register with NPCManager (for NPCs placed in scene, not spawned)
	_register_with_manager()

	# Connect to day/night cycle
	_connect_to_day_night_cycle()

	# Play spawn animation
	_play_spawn_animation()

	# Initialize walking
	_target_position = global_position
	_last_position = global_position
	_pick_new_target()
	
	# Check if it's night and spawn fire if needed
	call_deferred("_check_night_fire")

	# Connect to NPCManager prompt signals
	_connect_to_npc_manager_prompts()


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

		# Stuck detector: a head-on hit on a tree has no slide direction,
		# so give up on this target and pick a fresh one.
		if global_position.distance_to(_last_position) < 0.02:
			_stuck_timer += delta
			if _stuck_timer > 0.8:
				_stuck_timer = 0.0
			_pick_new_target()
		else:
			_stuck_timer = 0.0
	else:
		_is_walking = false
		velocity = Vector3.ZERO

		# Idle animation while waiting
		_idle_timer -= delta
		if _idle_timer <= 0:
			_play_idle_animation()
			_idle_timer = randf_range(IDLE_ANIM_INTERVAL_MIN, IDLE_ANIM_INTERVAL_MAX)

		# Pick new target after waiting
		_walk_timer -= delta
		if _walk_timer <= 0:
			_pick_new_target()

	# Update walk animation based on movement
	if _is_walking and not _was_walking:
		_kill_idle_animation()
		_start_walk_animation()
	elif not _is_walking and _was_walking:
		_stop_walk_animation()
	_was_walking = _is_walking
	_last_position = global_position


func _pick_new_target() -> void:
	# 30% chance to walk towards a building if any exist
	var npc_manager: Node = get_node_or_null("/root/NPCManager")
	if npc_manager and not npc_manager._building_positions.is_empty() and randf() < 0.3:
		_pick_building_target(npc_manager._building_positions)
		return

	# Default: random point within walk range
	_pick_random_target()


func _pick_random_target() -> void:
	# Try a few candidates: NPCs only walk on interior grass - never onto
	# the beach, into the sea, the river or up the cliffs.
	_target_position = global_position # stand still if nothing walkable is found
	for i in range(8):
		var angle := randf() * TAU
		var distance := randf_range(2.0, _walk_range)
		var candidate := Vector3(
			global_position.x + cos(angle) * distance,
			Config.GROUND_Y,
			global_position.z + sin(angle) * distance
		)
		candidate.x = clampf(candidate.x, Config.WORLD_MIN_X + 0.5, Config.WORLD_MAX_X - 0.5)
		candidate.z = clampf(candidate.z, Config.WORLD_MIN_Z + 0.5, Config.WORLD_MAX_Z - 0.5)
		if _is_walkable(candidate.x, candidate.z):
			_target_position = candidate
			break
	_walk_timer = randf_range(2.0, 5.0)


func _pick_building_target(building_positions: Array[Vector3]) -> void:
	# Pick a random building and walk near it
	var building_pos: Vector3 = building_positions[randi() % building_positions.size()]
	_target_position = building_pos # fallback: the building itself stands on grass
	for i in range(6):
		var offset_angle := randf() * TAU
		var offset_dist := randf_range(1.5, 4.0)
		var candidate := Vector3(
			building_pos.x + cos(offset_angle) * offset_dist,
			Config.GROUND_Y,
			building_pos.z + sin(offset_angle) * offset_dist
		)
		if _is_walkable(candidate.x, candidate.z):
			_target_position = candidate
			break
	_walk_timer = randf_range(3.0, 7.0) # Stay longer near buildings


## True if a world position stands on walkable interior grass
func _is_walkable(x: float, z: float) -> bool:
	var col: Dictionary = WorldManager.terrain_column(int(floor(x)), int(floor(z)))
	return col["top"] == Config.VoxelType.GRASS and not col["water"]


func _clamp_target_to_world() -> void:
	_target_position.x = clampf(_target_position.x, Config.WORLD_MIN_X + 0.5, Config.WORLD_MAX_X - 0.5)
	_target_position.z = clampf(_target_position.z, Config.WORLD_MIN_Z + 0.5, Config.WORLD_MAX_Z - 0.5)


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


## Play a random idle animation while standing still
func _play_idle_animation() -> void:
	if _is_walking or _in_quiz:
		return

	_kill_idle_animation()

	match randi() % 3:
		0: # Look around - gentle rotation
			_idle_tween = create_tween()
			var look_angle := randf_range(-0.5, 0.5)
			_idle_tween.tween_property(self, "rotation:y", rotation.y + look_angle, 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
			_idle_tween.tween_interval(randf_range(0.5, 1.5))
			_idle_tween.tween_property(self, "rotation:y", rotation.y, 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

		1: # Head bob (uses head body part if available)
			if _body_parts.has("head"):
				var head: Node3D = _body_parts["head"]
				_idle_tween = create_tween()
				_idle_tween.tween_property(head, "rotation_degrees:x", -8.0, 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
				_idle_tween.tween_property(head, "rotation_degrees:x", 0.0, 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

		2: # Body sway - slight left-right rocking
			_idle_tween = create_tween()
			_idle_tween.tween_property(self, "rotation:z", 0.03, 0.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
			_idle_tween.tween_property(self, "rotation:z", -0.03, 1.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
			_idle_tween.tween_property(self, "rotation:z", 0.0, 0.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


## Kill any running idle animation and reset
func _kill_idle_animation() -> void:
	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.kill()
	# Reset body sway
	rotation.z = 0.0
	# Reset head
	if _body_parts.has("head"):
		var head: Node3D = _body_parts["head"]
		head.rotation_degrees.x = 0.0


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


## Connect to day/night cycle signals
func _connect_to_day_night_cycle() -> void:
	var day_night_cycle: DayNightCycle = get_node_or_null("/root/Main/DayNightCycle")
	if day_night_cycle:
		if not day_night_cycle.night_started.is_connected(_on_night_started):
			day_night_cycle.night_started.connect(_on_night_started)
		if not day_night_cycle.night_ended.is_connected(_on_night_ended):
			day_night_cycle.night_ended.connect(_on_night_ended)


## Check if it's night and spawn fire
func _check_night_fire() -> void:
	var day_night_cycle: DayNightCycle = get_node_or_null("/root/Main/DayNightCycle")
	if day_night_cycle and day_night_cycle.current_phase == DayNightCycle.DayPhase.NIGHT:
		_on_night_started()


## Called when night starts
func _on_night_started() -> void:
	if not _can_make_fire or _campfire != null:
		return
	
	# Spawn campfire
	_campfire = FIRE_SCENE.instantiate()
	_campfire.position = Vector3(0.8, 0, 0.8) # Offset from NPC
	add_child(_campfire)
	
	# Animate fire appearance
	_campfire.scale = Vector3.ZERO
	var tween := create_tween()
	tween.tween_property(_campfire, "scale", Vector3.ONE, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


## Called when night ends
func _on_night_ended() -> void:
	if _campfire == null:
		return
	
	# Animate fire disappearance
	var tween := create_tween()
	tween.tween_property(_campfire, "scale", Vector3.ZERO, 0.3).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		if _campfire and is_instance_valid(_campfire):
			_campfire.queue_free()
		_campfire = null
	)


## Clean up fire on exit
func _exit_tree() -> void:
	if _campfire and is_instance_valid(_campfire):
		_campfire.queue_free()
		_campfire = null


## --- Interaction Prompt ---

func _connect_to_npc_manager_prompts() -> void:
	var npc_manager: Node = get_node_or_null("/root/NPCManager")
	if npc_manager:
		if npc_manager.has_signal("interaction_prompt_show"):
			npc_manager.interaction_prompt_show.connect(_on_prompt_show)
		if npc_manager.has_signal("interaction_prompt_hide"):
			npc_manager.interaction_prompt_hide.connect(_on_prompt_hide)


func _on_prompt_show(npc: NPC) -> void:
	if npc == self:
		show_interaction_prompt()
	else:
		hide_interaction_prompt()


func _on_prompt_hide() -> void:
	hide_interaction_prompt()


## Show interaction prompt with fade-in
func show_interaction_prompt() -> void:
	if not interaction_prompt:
		return
	if _prompt_tween and _prompt_tween.is_valid():
		_prompt_tween.kill()
	_prompt_tween = create_tween()
	_prompt_tween.tween_property(interaction_prompt, "modulate:a", 1.0, 0.2)


## Hide interaction prompt with fade-out
func hide_interaction_prompt() -> void:
	if not interaction_prompt:
		return
	if _prompt_tween and _prompt_tween.is_valid():
		_prompt_tween.kill()
	_prompt_tween = create_tween()
	_prompt_tween.tween_property(interaction_prompt, "modulate:a", 0.0, 0.15)

