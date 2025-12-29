extends Node3D

@onready var chunk_root: Node3D = $ChunkRoot
@onready var hud: HUD = $UI/HUD
@onready var quiz_window: QuizWindow = $UI/QuizWindow
@onready var build_cursor: Node3D = $BuildCursor

var _npc_manager: Node = null
var _effects: Node = null


func _ready() -> void:
	_spawn_chunks()
	hud.quiz_requested.connect(_on_hud_quiz_requested)

	# Get autoloads
	_npc_manager = get_node_or_null("/root/NPCManager")
	_effects = get_node_or_null("/root/Effects")

	if _npc_manager:
		_npc_manager.npc_quiz_completed.connect(_on_npc_quiz_completed)

	if build_cursor:
		build_cursor.building_placed.connect(_on_building_placed)


func _on_hud_quiz_requested() -> void:
	quiz_window.open()


func _on_building_placed(grid_pos: Vector3i) -> void:
	if _effects:
		var world_pos := Vector3(grid_pos.x, grid_pos.y, grid_pos.z)
		_effects.spawn_confetti(world_pos)


func _on_npc_quiz_completed(npc: NPC, was_correct: bool) -> void:
	if not _effects:
		return
	var pos := npc.global_position
	if was_correct:
		_effects.spawn_success(pos)
		var points := npc.get_reward_points()
		_effects.spawn_floating_text(pos, "+%d 📚" % points, Color.GREEN)
	else:
		_effects.spawn_failure(pos)


func _spawn_chunks() -> void:
	for x in range(-1, 2):
		for z in range(-1, 2):
			_spawn_chunk(x, z)


func _spawn_chunk(chunk_x: int, chunk_z: int) -> void:
	var chunk_scene := preload("res://scenes/world/chunk.tscn")
	var chunk: Node3D = chunk_scene.instantiate()
	chunk.chunk_x = chunk_x
	chunk.chunk_z = chunk_z
	chunk_root.add_child(chunk)
