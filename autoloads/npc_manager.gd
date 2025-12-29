extends Node

## NPC Manager (Autoload)
##
## Manages NPC spawning, tracking, and interaction flow.
## Handles mouse hover detection and click interaction via raycasts.
## Connects NPCs with the Quiz system.

signal npc_clicked(npc: NPC)
signal npc_quiz_completed(npc: NPC, was_correct: bool)
signal npc_spawned(npc: NPC)

const NPC_SCENE: PackedScene = preload("res://scenes/entities/npc.tscn")
const NPC_COLLISION_LAYER: int = 4

## Spawning configuration - BALANCED VALUES
const BASE_SPAWN_INTERVAL: float = 12.0 # Seconds between spawns (was 15)
const MIN_SPAWN_INTERVAL: float = 4.0 # Minimum interval (was 5)
const MAX_ACTIVE_NPCS: int = 6 # Maximum NPCs at once (was 8, less overwhelming)
const SPAWN_RADIUS_MIN: float = 3.0 # Min distance from center
const SPAWN_RADIUS_MAX: float = 14.0 # Max distance from center (terrain goes from -16 to +32)
const SPAWN_Y: float = 1.0 # Ground level (top of grass voxels)

## All loaded NPC data resources
var _npc_types: Dictionary = {}

## Currently active NPCs in the world
var _active_npcs: Array[NPC] = []

## The NPC currently in a quiz (if any)
var _current_quiz_npc: NPC = null

## Currently hovered NPC (for visual feedback)
var _hovered_npc: NPC = null

## Reference to QuizWindow (set by main scene)
var quiz_window: Control = null

## Reference to BuildingManager for points
var _building_manager: Node = null

## Camera reference for raycasts
var _camera: Camera3D = null

## Spawn timer
var _spawn_timer: float = 0.0
var _spawning_enabled: bool = true


func _ready() -> void:
	_load_npc_types()
	_building_manager = get_node_or_null("/root/BuildingManager")
	print("NPCManager: Loaded %d NPC types" % _npc_types.size())

	# Start spawning after a short delay
	_spawn_timer = 3.0 # First spawn after 3 seconds


func _process(delta: float) -> void:
	_update_hover()
	_update_spawning(delta)


func _update_spawning(delta: float) -> void:
	if not _spawning_enabled:
		return

	# Clean up invalid NPC references
	var valid_npcs: Array[NPC] = []
	for npc: NPC in _active_npcs:
		if is_instance_valid(npc):
			valid_npcs.append(npc)
	_active_npcs = valid_npcs

	# Check if we can spawn more
	if _active_npcs.size() >= MAX_ACTIVE_NPCS:
		return

	# Update timer
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_random_npc()
		_spawn_timer = _get_spawn_interval()


func _get_spawn_interval() -> float:
	# Spawn faster if player has more buildings
	var building_count: int = 0
	if _building_manager:
		building_count = _building_manager.player_stats.get("buildings_placed", 0)

	# Reduce interval by 1 second per 5 buildings, minimum MIN_SPAWN_INTERVAL
	var reduction: float = (building_count / 5.0) * 1.0
	return maxf(MIN_SPAWN_INTERVAL, BASE_SPAWN_INTERVAL - reduction)


func _spawn_random_npc() -> void:
	if _npc_types.is_empty():
		return

	# Pick random NPC type
	var types: Array = _npc_types.values()
	var npc_data: NPCData = types[randi() % types.size()]

	# Generate random position on terrain (centered around chunk 0,0)
	var angle: float = randf() * TAU
	var distance: float = randf_range(SPAWN_RADIUS_MIN, SPAWN_RADIUS_MAX)
	var spawn_pos := Vector3(
		cos(angle) * distance + 8.0, # Offset to center of chunk 0
		SPAWN_Y, # On top of grass voxels (y=1)
		sin(angle) * distance + 8.0 # Offset to center of chunk 0
	)

	# Spawn the NPC
	var npc := spawn_npc(spawn_pos, npc_data)
	if npc:
		npc_spawned.emit(npc)
		AudioManager.play_sfx(AudioManager.SFX.NPC_SPAWN)


func _input(event: InputEvent) -> void:
	# Handle NPC clicks (left click only - more intuitive)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if _hovered_npc and is_instance_valid(_hovered_npc):
				_hovered_npc.interact()
				get_viewport().set_input_as_handled()


func _update_hover() -> void:
	var npc := _raycast_for_npc()

	# Update hover state
	if npc != _hovered_npc:
		# Clear old hover
		if _hovered_npc and is_instance_valid(_hovered_npc):
			_hovered_npc.set_hovered(false)

		# Set new hover
		_hovered_npc = npc
		if _hovered_npc:
			_hovered_npc.set_hovered(true)


func _raycast_for_npc() -> NPC:
	if not _camera:
		_camera = get_viewport().get_camera_3d()
		if not _camera:
			return null

	var viewport := get_viewport()
	if not viewport:
		return null

	var mouse_pos := viewport.get_mouse_position()
	var ray_origin := _camera.project_ray_origin(mouse_pos)
	var ray_direction := _camera.project_ray_normal(mouse_pos)

	var space_state := _camera.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		ray_origin,
		ray_origin + ray_direction * 100.0
	)
	query.collision_mask = NPC_COLLISION_LAYER

	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return null

	var collider: Node = result.get("collider")
	if collider is NPC:
		return collider as NPC

	return null


func _load_npc_types() -> void:
	var dir := DirAccess.open("res://data/npcs")
	if not dir:
		push_warning("NPCManager: Could not open res://data/npcs")
		return
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var path := "res://data/npcs/" + file_name
			var npc_data: NPCData = load(path)
			if npc_data:
				_npc_types[npc_data.id] = npc_data
		file_name = dir.get_next()


## Spawn an NPC at position with given data
func spawn_npc(world_position: Vector3, npc_data: NPCData) -> NPC:
	var npc: NPC = NPC_SCENE.instantiate()
	npc.npc_data = npc_data
	npc.position = world_position
	
	# Connect signals
	npc.clicked.connect(_on_npc_clicked)
	npc.quiz_completed.connect(_on_npc_quiz_completed)
	
	# Add to scene
	get_tree().current_scene.add_child(npc)
	_active_npcs.append(npc)
	
	return npc


## Spawn NPC by type ID
func spawn_npc_by_id(world_position: Vector3, npc_type_id: String) -> NPC:
	if not _npc_types.has(npc_type_id):
		push_error("NPCManager: Unknown NPC type: " + npc_type_id)
		return null
	
	return spawn_npc(world_position, _npc_types[npc_type_id])


## Get all NPC types
func get_all_npc_types() -> Array:
	return _npc_types.values()


## Get NPC data by ID
func get_npc_data(npc_type_id: String) -> NPCData:
	return _npc_types.get(npc_type_id, null)


func _on_npc_clicked(npc: NPC) -> void:
	_current_quiz_npc = npc
	npc_clicked.emit(npc)
	
	# Open quiz with NPC's category
	if quiz_window and quiz_window.has_method("open_with_category"):
		quiz_window.open_with_category(npc.get_category())
	elif quiz_window and quiz_window.has_method("open"):
		quiz_window.open()


func _on_npc_quiz_completed(npc: NPC, was_correct: bool) -> void:
	npc_quiz_completed.emit(npc, was_correct)

	# Award points if correct
	if was_correct and _building_manager:
		var points := npc.get_reward_points()
		_building_manager.education_points += points

	# Remove from active list if NPC is being freed
	if was_correct:
		_active_npcs.erase(npc)

	_current_quiz_npc = null


## Called by QuizWindow when answer is submitted
func on_quiz_answer(was_correct: bool) -> void:
	if _current_quiz_npc:
		_current_quiz_npc.on_quiz_result(was_correct)


## Enable/disable automatic spawning
func set_spawning_enabled(enabled: bool) -> void:
	_spawning_enabled = enabled


## Get spawning state
func is_spawning_enabled() -> bool:
	return _spawning_enabled


## Get count of active NPCs
func get_active_npc_count() -> int:
	return _active_npcs.size()
