extends Node3D

@onready var chunk_root: Node3D = $ChunkRoot
@onready var hud: HUD = $UI/HUD
@onready var quiz_window: QuizWindow = $UI/QuizWindow

func _ready() -> void:
	_spawn_chunks()
	hud.quiz_requested.connect(_on_hud_quiz_requested)


func _on_hud_quiz_requested() -> void:
	quiz_window.open()

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
