extends CharacterBody3D
class_name NPC

## NPC Entity
##
## Clickable NPC that triggers a quiz when interacted with.
## Rewards education points for correct answers.

signal clicked(npc: NPC)
signal quiz_completed(npc: NPC, was_correct: bool)

## NPC collision layer for raycast detection
const NPC_COLLISION_LAYER: int = 4

## NPC data resource defining category, rewards, etc.
@export var npc_data: NPCData

## Reference to mesh for color updates
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var label_3d: Label3D = $Label3D

## Material for the NPC mesh
var _material: StandardMaterial3D
var _base_color: Color

## Is this NPC currently in a quiz?
var _in_quiz: bool = false

## Is mouse hovering over this NPC?
var _is_hovered: bool = false


func _ready() -> void:
	add_to_group("npcs")

	# Setup material with NPC color
	_setup_material()

	# Setup label
	if label_3d and npc_data:
		label_3d.text = npc_data.display_name

	# Register with NPCManager (for NPCs placed in scene, not spawned)
	_register_with_manager()


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

	_material = StandardMaterial3D.new()
	if npc_data:
		_base_color = npc_data.color
	else:
		_base_color = Color.CORNFLOWER_BLUE

	_material.albedo_color = _base_color
	mesh_instance.material_override = _material


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
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y + 2.0, 0.3).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "scale", Vector3(0.1, 0.1, 0.1), 0.3)
	tween.tween_callback(queue_free)


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
