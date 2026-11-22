extends Node

## Save Manager (Autoload)
##
## Handles saving and loading WORLD STATE only (placed buildings).
## Player data (points, stats) is handled by ProfileManager.

const SAVE_PATH: String = "user://world_save.json"
const SAVE_VERSION: int = 2


signal game_saved()
signal game_loaded()

var _auto_save_timer: float = 0.0
const AUTO_SAVE_INTERVAL: float = 60.0 # Auto-save every 60 seconds


func _ready() -> void:
	# Auto-load on startup
	call_deferred("load_game")

	# Connect to events for auto-save triggers
	if BuildingManager:
		BuildingManager.building_placed_event.connect(_on_building_placed)

	# Connect to PropManager for prop save triggers
	if PropManager:
		PropManager.prop_placed.connect(func(_pos: Vector3, _name: String) -> void: save_game())
		PropManager.prop_removed.connect(func(_pos: Vector3) -> void: save_game())


func _process(delta: float) -> void:
	_auto_save_timer += delta
	if _auto_save_timer >= AUTO_SAVE_INTERVAL:
		_auto_save_timer = 0.0
		save_game()


func _on_building_placed(_building: BuildingData, _pos: Vector3i) -> void:
	# Save after placing a building
	save_game()


## Save the current world state (buildings only)
func save_game() -> bool:
	var save_data: Dictionary = {
		"version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"buildings": _get_placed_buildings(),
		"props": _get_placed_props(),
	}

	# Write to file
	var json_string := JSON.stringify(save_data, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("SaveManager: Could not open save file for writing")
		return false

	file.store_string(json_string)
	file.close()

	game_saved.emit()
	return true


## Load world state from file
func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
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

	# Restore buildings (deferred to ensure scene is ready)
	if save_data.has("buildings"):
		call_deferred("_restore_buildings", save_data["buildings"])

	# Restore props (deferred so the menu is ready; PropManager buffers until the world loads)
	if save_data.has("props"):
		call_deferred("_restore_props", save_data["props"])

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

			# Store building_id (display_name) for mesh regeneration
			if child.has_meta("building_id"):
				building_data["building_id"] = child.get_meta("building_id")

			# Store street lamp flag
			if child.has_meta("is_street_lamp"):
				building_data["is_street_lamp"] = true

			# Store building level (progression state)
			if child.has_meta("building_level"):
				building_data["building_level"] = child.get_meta("building_level")

			buildings.append(building_data)
	
	return buildings


func _restore_buildings(buildings_data: Array) -> void:
	# Wait for scene to be fully ready
	await get_tree().process_frame

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

		# Look up BuildingData by building_id (display_name)
		var building_id: String = bdata.get("building_id", "")
		var bdata_res: BuildingData = null
		if building_id != "" and BuildingManager:
			for b in BuildingManager.get_all_buildings():
				if b.display_name == building_id:
					bdata_res = b
					break

		var block_mesh := MeshInstance3D.new()
		block_mesh.name = "MeshInstance3D"

		# Generate detailed mesh if building data found, otherwise use fallback box
		if bdata_res:
			# Get building level from saved data, default to 0
			var level: int = bdata.get("building_level", 0)
			block_mesh.mesh = BuildingMeshGenerator.generate(bdata_res, level)
			# Store building ID meta
			building.set_meta("building_id", bdata_res.display_name)
			# Restore building level meta
			building.set_meta("building_level", level)

			# Set up window emission material (surface 1) if not infrastructure
			if bdata_res.category != "infrastructure":
				var win_mat := StandardMaterial3D.new()
				win_mat.vertex_color_use_as_albedo = true
				win_mat.emission_enabled = false
				win_mat.emission = bdata_res.secondary_color * 1.5
				win_mat.emission_energy_multiplier = 1.5
				block_mesh.set_surface_override_material(1, win_mat)
				block_mesh.set_meta("has_window_surface", true)
		else:
			# Fallback: simple box mesh with color
			var box_mesh := BoxMesh.new()
			box_mesh.size = Vector3(1.0, 1.0, 1.0)
			block_mesh.mesh = box_mesh
			var mat := StandardMaterial3D.new()
			if bdata.has("color"):
				mat.albedo_color = Color.html(bdata["color"])
			else:
				mat.albedo_color = Color.CORAL
			block_mesh.material_override = mat

		building.add_child(block_mesh)

		# Create collision shape
		var collision := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		if bdata_res:
			box_shape.size = Vector3(bdata_res.size)
		else:
			box_shape.size = Vector3(1.0, 1.0, 1.0)
		collision.shape = box_shape
		# Center collision for multi-block buildings
		collision.position = box_shape.size * 0.5 - Vector3(0.5, 0, 0.5)
		building.add_child(collision)

		# Restore street lamp if marked
		if bdata.get("is_street_lamp", false) and bdata_res:
			var lamp := OmniLight3D.new()
			lamp.name = "LampLight"
			lamp.position = Vector3(0.5, 2.0, 0.5)
			lamp.light_color = bdata_res.secondary_color
			lamp.light_energy = 2.5
			lamp.omni_range = 8.0
			lamp.shadow_enabled = false
			lamp.visible = false
			building.add_child(lamp)
			building.set_meta("is_street_lamp", true)

		# Add interaction prompt label (starts invisible)
		var prompt := Label3D.new()
		prompt.name = "InteractionPrompt"
		prompt.text = "[T] Erkunden"
		var prompt_y := float(bdata_res.size.y) if bdata_res else 1.0
		prompt.position = Vector3(0.5, prompt_y + 0.3, 0.5)
		prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		prompt.modulate = Color(1, 0.95, 0.6, 0)  # alpha = 0 (invisible)
		prompt.pixel_size = 0.01
		prompt.outline_modulate = Color(0.1, 0.1, 0.1, 1)
		building.add_child(prompt)

		building.position = pos
		buildings_root.add_child(building)


func _get_placed_props() -> Array:
	if PropManager:
		return PropManager.serialize_props()
	return []


func _restore_props(props_data: Array) -> void:
	# PropManager buffers the data internally until the world scene
	# calls initialize(), so no frame-waiting is needed here.
	if PropManager:
		PropManager.deserialize_props(props_data)
