extends Node

## Save Manager (Autoload)
##
## Handles saving and loading game state.
## Saves: education_points, player_stats, placed buildings

const SAVE_PATH: String = "user://savegame.json"

signal game_saved()
signal game_loaded()


var _auto_save_timer: float = 0.0
const AUTO_SAVE_INTERVAL: float = 30.0 # Auto-save every 30 seconds


func _ready() -> void:
	# Auto-load on startup
	call_deferred("load_game")

	# Connect to events for auto-save triggers
	var building_manager: Node = get_node_or_null("/root/BuildingManager")
	if building_manager:
		building_manager.building_placed_event.connect(_on_building_placed)


func _process(delta: float) -> void:
	_auto_save_timer += delta
	if _auto_save_timer >= AUTO_SAVE_INTERVAL:
		_auto_save_timer = 0.0
		save_game()


func _on_building_placed(_building: Resource, _pos: Vector3i) -> void:
	# Save after placing a building
	save_game()


## Save the current game state
func save_game() -> bool:
	var building_manager: Node = get_node_or_null("/root/BuildingManager")
	var quiz_manager: Node = get_node_or_null("/root/QuizManager")
	
	var save_data: Dictionary = {
		"version": 1,
		"timestamp": Time.get_unix_time_from_system(),
	}
	
	# Save BuildingManager data
	if building_manager:
		save_data["education_points"] = building_manager.education_points
		save_data["player_stats"] = building_manager.player_stats
	
	# Save QuizManager stats
	if quiz_manager:
		save_data["quiz_stats"] = {
			"total_answered": quiz_manager.total_questions_answered,
			"total_correct": quiz_manager.total_correct_answers,
			"by_category": quiz_manager.questions_by_category
		}
	
	# Save placed buildings
	save_data["buildings"] = _get_placed_buildings()
	
	# Write to file
	var json_string := JSON.stringify(save_data, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("SaveManager: Could not open save file for writing")
		return false
	
	file.store_string(json_string)
	file.close()
	
	print("SaveManager: Game saved successfully")
	game_saved.emit()
	return true


## Load game state from file
func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		print("SaveManager: No save file found, starting fresh")
		return false
	
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("SaveManager: Could not open save file for reading")
		return false
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		push_error("SaveManager: Failed to parse save file")
		return false
	
	var save_data: Dictionary = json.data
	
	var building_manager: Node = get_node_or_null("/root/BuildingManager")
	var quiz_manager: Node = get_node_or_null("/root/QuizManager")
	
	# Restore BuildingManager data
	if building_manager and save_data.has("education_points"):
		building_manager.education_points = int(save_data["education_points"])
	if building_manager and save_data.has("player_stats"):
		building_manager.player_stats = save_data["player_stats"]
	
	# Restore QuizManager stats
	if quiz_manager and save_data.has("quiz_stats"):
		var stats: Dictionary = save_data["quiz_stats"]
		quiz_manager.total_questions_answered = int(stats.get("total_answered", 0))
		quiz_manager.total_correct_answers = int(stats.get("total_correct", 0))
		quiz_manager.questions_by_category = stats.get("by_category", {})
	
	# Restore buildings (deferred to ensure scene is ready)
	if save_data.has("buildings"):
		call_deferred("_restore_buildings", save_data["buildings"])
	
	print("SaveManager: Game loaded successfully")
	game_loaded.emit()
	return true


func _get_placed_buildings() -> Array:
	var buildings: Array = []
	var buildings_root: Node = get_tree().current_scene.get_node_or_null("Buildings")
	
	if not buildings_root:
		return buildings
	
	for child in buildings_root.get_children():
		if child.is_in_group("placed_buildings"):
			var pos: Vector3 = child.global_position
			# Try to get building type from metadata or color
			var building_data: Dictionary = {
				"position": {"x": pos.x, "y": pos.y, "z": pos.z}
			}
			# Store color for reconstruction
			var mesh: MeshInstance3D = child.get_node_or_null("MeshInstance3D")
			if mesh and mesh.material_override:
				var mat: StandardMaterial3D = mesh.material_override as StandardMaterial3D
				if mat:
					building_data["color"] = mat.albedo_color.to_html()
			buildings.append(building_data)
	
	return buildings


func _restore_buildings(buildings_data: Array) -> void:
	# Wait for scene to be fully ready
	await get_tree().process_frame
	
	var build_cursor: Node = get_tree().current_scene.get_node_or_null("BuildCursor")
	if not build_cursor:
		return
	
	var buildings_root: Node = get_tree().current_scene.get_node_or_null("Buildings")
	if not buildings_root:
		return
	
	for bdata in buildings_data:
		var pos_data: Dictionary = bdata.get("position", {})
		var pos := Vector3(
			float(pos_data.get("x", 0)),
			float(pos_data.get("y", 1)),
			float(pos_data.get("z", 0))
		)
		
		# Create building
		var building := StaticBody3D.new()
		building.add_to_group("placed_buildings")
		building.collision_layer = 2
		building.collision_mask = 0
		
		var block_mesh := MeshInstance3D.new()
		var box_mesh := BoxMesh.new()
		box_mesh.size = Vector3(1.0, 1.0, 1.0)
		block_mesh.mesh = box_mesh
		block_mesh.name = "MeshInstance3D"
		
		var mat := StandardMaterial3D.new()
		if bdata.has("color"):
			mat.albedo_color = Color.html(bdata["color"])
		else:
			mat.albedo_color = Color.CORAL
		block_mesh.material_override = mat
		building.add_child(block_mesh)
		
		var collision := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(1.0, 1.0, 1.0)
		collision.shape = box_shape
		building.add_child(collision)
		
		building.position = pos
		buildings_root.add_child(building)
	
	print("SaveManager: Restored %d buildings" % buildings_data.size())
