extends Node

## Save Manager (Autoload)
##
## Handles saving and loading WORLD STATE only (placed buildings).
## Player data (points, stats) is handled by ProfileManager.

const SAVE_PATH: String = "user://world_save.json"
## The save as it was before the last write; used if the save is damaged
const BACKUP_PATH: String = "user://world_save.json.bak"
const SAVE_VERSION: int = 2


signal game_saved()
signal game_loaded()

var _auto_save_timer: float = 0.0
const AUTO_SAVE_INTERVAL: float = 60.0 # Auto-save every 60 seconds
## Buildings from the last load, waiting for the game scene (bind_scene)
var _pending_buildings: Array = []
## Off in tests and probes: nothing reaches the disk, whatever happens
var saves_enabled: bool = true

## Debounced event saves: bursts of changes (e.g. restoring a save with
## many props) trigger exactly one write shortly after the last change,
## instead of one write per placed/removed object.
const DEBOUNCE_DELAY: float = 2.0
var _debounce_timer: Timer = null
var _save_pending: bool = false


func _ready() -> void:
	# Auto-load on startup
	call_deferred("load_game")

	# Debounce timer for event-driven saves
	_debounce_timer = Timer.new()
	_debounce_timer.one_shot = true
	_debounce_timer.wait_time = DEBOUNCE_DELAY
	_debounce_timer.timeout.connect(_on_debounce_timeout)
	add_child(_debounce_timer)

	# Connect to events for auto-save triggers
	if BuildingManager:
		BuildingManager.building_placed_event.connect(_on_building_placed)
		BuildingManager.building_level_changed.connect(_on_building_upgraded)

	# Connect to PropManager for prop save triggers
	if PropManager:
		PropManager.prop_placed.connect(_on_prop_changed)
		PropManager.prop_removed.connect(_on_prop_removed)


func _process(delta: float) -> void:
	if not saves_enabled or not is_world_loaded():
		return # main menu: nothing to save, and saving would empty the city
	_auto_save_timer += delta
	if _auto_save_timer >= AUTO_SAVE_INTERVAL:
		_auto_save_timer = 0.0
		save_game()


## Closing the window saves like "Beenden" in the pause menu does
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and saves_enabled and is_world_loaded():
		save_game()


func _on_building_placed(_building: BuildingData, _pos: Vector3i) -> void:
	_mark_save_dirty()


## An upgraded building (quiz answered) is part of the city from now on
func _on_building_upgraded(_building: StaticBody3D, _new_level: int) -> void:
	_mark_save_dirty()


func _on_prop_changed(_pos: Vector3, _name: String) -> void:
	_mark_save_dirty()


func _on_prop_removed(_pos: Vector3) -> void:
	_mark_save_dirty()


## Mark the world dirty; a single save fires DEBOUNCE_DELAY seconds
## after the last change.
func _mark_save_dirty() -> void:
	if not saves_enabled:
		return
	_save_pending = true
	_debounce_timer.start()


func _on_debounce_timeout() -> void:
	if _save_pending:
		_save_pending = false
		save_game()


## True while the game scene (the one with the "Buildings" node) is the
## current scene. The main menu has no buildings: saving there would write
## an EMPTY city over the real save.
func is_world_loaded() -> bool:
	var scene: Node = get_tree().current_scene
	return scene != null and scene.get_node_or_null("Buildings") != null


## Save the current world state (buildings + props). Does nothing while
## the game scene is not loaded and returns false then.
func save_game() -> bool:
	if not saves_enabled or not is_world_loaded():
		return false

	var save_data: Dictionary = {
		"version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"buildings": _get_placed_buildings(),
		"props": _get_placed_props(),
	}

	# The previous save is kept one step as a backup
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(SAVE_PATH, BACKUP_PATH)

	# Write to file
	var json_string := JSON.stringify(save_data, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("SaveManager: Could not open save file for writing")
		return false

	file.store_string(json_string)
	file.close()

	# An explicit save covers any pending debounced changes
	_save_pending = false
	if _debounce_timer:
		_debounce_timer.stop()

	game_saved.emit()
	return true


## Load world state from file
func load_game() -> bool:
	var save_data: Dictionary = _read_save_file(SAVE_PATH)
	if save_data.is_empty() and FileAccess.file_exists(BACKUP_PATH):
		push_warning("SaveManager: save file unreadable, loading the backup copy")
		save_data = _read_save_file(BACKUP_PATH)
	if save_data.is_empty():
		return false

	# Buildings need the game scene. It does not exist at start-up (the main
	# menu is up), so they are buffered until main.gd calls bind_scene().
	if save_data.has("buildings"):
		_pending_buildings = save_data["buildings"]

	# Restore props (deferred so the menu is ready; PropManager buffers until the world loads)
	if save_data.has("props"):
		call_deferred("_restore_props", save_data["props"])

	game_loaded.emit()
	return true


## Parsed contents of a save file, or {} when it is missing or damaged
func _read_save_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		push_error("SaveManager: Failed to parse %s: %s" % [path, json.get_error_message()])
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("SaveManager: %s does not contain a save" % path)
		return {}
	var data: Dictionary = json.data
	return data


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


## Called by the game scene (main.gd) once it is in the tree: puts the
## buffered buildings into the world and lets the roads connect.
func bind_scene(scene: Node) -> void:
	if _pending_buildings.is_empty():
		return
	var buildings_root: Node = scene.get_node_or_null("Buildings")
	if buildings_root == null:
		return
	var pending: Array = _pending_buildings
	_pending_buildings = []
	_restore_buildings(pending, buildings_root)


## Rebuild saved buildings under buildings_root, exactly as placing them
## would have (mesh, collider, lamp, prompt, level).
func _restore_buildings(buildings_data: Array, buildings_root: Node) -> void:
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
		building.collision_layer = Config.BUILDING_COLLISION_LAYER
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
		prompt.text = "[E] Erkunden"
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
