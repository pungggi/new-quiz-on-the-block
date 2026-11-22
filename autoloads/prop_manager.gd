extends Node

## Prop Manager (Autoload)
##
## Manages prop spawning, tracking, removal, and saving.
## Spawns decoration around buildings automatically and supports
## manual placement through the building panel.
##
## Connects to BuildingManager.building_placed_event to auto-decorate.

const PropMeshGen := preload("res://scripts/visuals/prop_mesh_generator.gd")

signal prop_placed(position: Vector3, prop_name: String)
signal prop_removed(position: Vector3)
signal initialized

## All loaded prop types
var _prop_types: Array[PropData] = []

## Active props in the scene
var _placed_props: Array[StaticBody3D] = []

## Parent node for all props
var _props_root: Node3D = null

## Props from a save that arrived before the world scene was ready.
## Flushed by initialize().
var _pending_props_data: Array = []

## Track occupied grid positions to avoid overlap
var _occupied_positions: Dictionary = {}  # Key: Vector2i(x, z), Value: true

## Dynamic performance cap – adjusted at runtime
var _max_props: int = 100

## Context-sensitive prop selection by building category
const CATEGORY_PROPS: Dictionary = {
	"residential": ["Eiche", "Birke", "Tanne", "Busch", "Parkbank", "Briefkasten", "Schaukel", "Sandkasten"],
	"commercial": ["Mülleimer", "Blumenbeet", "Busch", "Telefonzelle", "Fahrradständer"],
	"education": ["Parkbank", "Eiche", "Birke", "Blumenbeet", "Tafel", "Bücherstapel", "Picknicktisch"],
	"decoration": ["Busch", "Blumenbeet", "Parklaterne", "Springbrunnen (klein)"],
}

## Nature-only props for initial scatter
const NATURE_PROP_NAMES: Array[String] = ["Eiche", "Birke", "Tanne", "Busch"]


func _ready() -> void:
	_load_prop_types()

	# Connect to building placement (deferred – BuildingManager loads first)
	call_deferred("_connect_signals")


func _connect_signals() -> void:
	if BuildingManager:
		BuildingManager.building_placed_event.connect(_on_building_placed)


## Initialize with a parent node for all props
func initialize(props_root: Node3D) -> void:
	_props_root = props_root
	_flush_pending_props()
	initialized.emit()


## Restore props that arrived before initialize() (e.g. save loaded from menu)
func _flush_pending_props() -> void:
	if _pending_props_data.is_empty():
		return
	var pending: Array = _pending_props_data
	_pending_props_data = []
	deserialize_props(pending)


## Shared, immutable prop material (vertex-color props all use the same
## settings; one instance serves every placed prop instead of one per prop).
var _shared_prop_material: StandardMaterial3D = null


func _get_prop_material() -> StandardMaterial3D:
	if _shared_prop_material == null:
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.cull_mode = BaseMaterial3D.CULL_BACK
		_shared_prop_material = mat
	return _shared_prop_material


## Load all prop definitions from res://data/props/
func _load_prop_types() -> void:
	var props_path := "res://data/props/"
	var dir := DirAccess.open(props_path)

	if not dir:
		push_warning("PropManager: Props directory not found at %s" % props_path)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var resource := load(props_path + file_name)
			if resource is PropData:
				_prop_types.append(resource)
		file_name = dir.get_next()

	dir.list_dir_end()


#region Public API

## Get all prop types (for UI panel)
func get_all_props() -> Array[PropData]:
	return _prop_types


## Get a prop type by display name
func get_prop_data(display_name: String) -> PropData:
	for p in _prop_types:
		if p.display_name == display_name:
			return p
	return null


## Scatter nature props across the world at game start
func decorate_world() -> void:
	if not _props_root:
		push_warning("PropManager: No props root set. Call initialize() first.")
		return

	var nature_props: Array[PropData] = _get_nature_props()
	if nature_props.is_empty():
		return

	# Scale prop count with world area so larger worlds don't feel barren
	# (base density tuned for the original 48x48 world at WORLD_CHUNK_RADIUS 1)
	var world_width: float = Config.WORLD_MAX_X - Config.WORLD_MIN_X
	var area_factor: float = world_width * world_width / (48.0 * 48.0)
	set_max_props(int(100.0 * area_factor))
	var prop_count: int = int(float(randi_range(15, 25)) * area_factor)

	for i in range(prop_count):
		if _placed_props.size() >= _max_props:
			break

		var pos := Vector3(
			randf_range(Config.WORLD_MIN_X + 1.0, Config.WORLD_MAX_X - 1.0),
			Config.GROUND_Y,
			randf_range(Config.WORLD_MIN_Z + 1.0, Config.WORLD_MAX_Z - 1.0)
		)

		# Snap to grid center
		pos.x = floor(pos.x) + 0.5
		pos.z = floor(pos.z) + 0.5

		if _is_position_free(pos):
			var prop_data: PropData = nature_props[randi() % nature_props.size()]
			place_prop(pos, prop_data, false)


## Place a prop at a world position
func place_prop(pos: Vector3, prop_data: PropData, deduct_cost: bool = true) -> StaticBody3D:
	if not _props_root:
		push_error("PropManager: No props root. Call initialize() first.")
		return null

	if _placed_props.size() >= _max_props:
		push_warning("PropManager: Max prop limit (%d) reached." % _max_props)
		return null

	# Deduct cost if manually placed
	if deduct_cost:
		if not BuildingManager:
			return null
		if BuildingManager.education_points < prop_data.cost:
			return null
		BuildingManager.education_points -= prop_data.cost

	# Create StaticBody3D for collision
	var prop := StaticBody3D.new()
	prop.collision_layer = Config.PROP_COLLISION_LAYER
	prop.collision_mask = 0
	prop.add_to_group("placed_props")
	prop.set_meta("prop_name", prop_data.display_name)

	# Generate mesh
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	mesh_instance.mesh = PropMeshGen.generate(prop_data)
	mesh_instance.material_override = _get_prop_material()

	prop.add_child(mesh_instance)

	# Collision shape
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = prop_data.size
	collision.shape = shape
	collision.position = Vector3(0, prop_data.size.y * 0.5, 0)
	prop.add_child(collision)

	# Position
	prop.position = pos

	# Random Y rotation for visual variety
	prop.rotation.y = randf() * TAU

	_props_root.add_child(prop)
	_placed_props.append(prop)
	_mark_occupied(pos)

	# Pop-in animation
	_play_pop_animation(prop)

	prop_placed.emit(pos, prop_data.display_name)
	return prop


## Remove a prop (middle-click or programmatic)
func remove_prop(prop: StaticBody3D) -> void:
	if not is_instance_valid(prop):
		return

	var pos: Vector3 = prop.position
	_unmark_occupied(pos)
	_placed_props.erase(prop)

	# Shrink-out animation then free
	var tween := create_tween()
	tween.tween_property(prop, "scale", MIN_SCALE, 0.15).set_ease(Tween.EASE_IN)
	tween.tween_callback(prop.queue_free)

	prop_removed.emit(pos)


## Get current prop count
func get_prop_count() -> int:
	return _placed_props.size()


## Get max prop limit
func get_max_props() -> int:
	return _max_props


## Dynamically adjust max props (e.g., based on FPS)
func set_max_props(new_max: int) -> void:
	_max_props = maxi(10, new_max)

#endregion


#region Auto-Placement (triggered by building placement)

func _on_building_placed(building: BuildingData, pos: Vector3i) -> void:
	if not _props_root:
		return

	# Don't auto-decorate infrastructure (roads, sidewalks, lamps)
	if building.category == "infrastructure":
		return

	# Get candidate positions around the building
	var candidates: Array[Vector3] = _get_candidate_positions(pos, building.size)
	candidates = _filter_free_positions(candidates)

	if candidates.is_empty():
		return

	# Shuffle for randomness
	candidates.shuffle()

	# Place 1-3 props around the building
	var count: int = randi_range(1, mini(3, candidates.size()))
	for i in range(count):
		if _placed_props.size() >= _max_props:
			break
		var prop_data: PropData = _select_prop_for_category(building.category)
		if prop_data:
			place_prop(candidates[i], prop_data, false)  # Auto-placed = free


## Get candidate positions in a ring around a building
func _get_candidate_positions(pos: Vector3i, size: Vector3i) -> Array[Vector3]:
	var candidates: Array[Vector3] = []

	for x in range(pos.x - 1, pos.x + size.x + 1):
		for z in range(pos.z - 1, pos.z + size.z + 1):
			# Only positions outside the building footprint
			var inside_x: bool = x >= pos.x and x < pos.x + size.x
			var inside_z: bool = z >= pos.z and z < pos.z + size.z
			if not (inside_x and inside_z):
				var candidate := Vector3(float(x) + 0.5, Config.GROUND_Y, float(z) + 0.5)
				# Check world bounds
				if candidate.x > Config.WORLD_MIN_X and candidate.x < Config.WORLD_MAX_X:
					if candidate.z > Config.WORLD_MIN_Z and candidate.z < Config.WORLD_MAX_Z:
						candidates.append(candidate)

	return candidates


## Select a fitting prop based on building category
func _select_prop_for_category(category: String) -> PropData:
	var preferred_names: Array = CATEGORY_PROPS.get(category, [])
	if preferred_names.is_empty():
		# Fallback: any nature prop
		var nature: Array[PropData] = _get_nature_props()
		if nature.is_empty():
			return null
		return nature[randi() % nature.size()]

	# Try to find a matching prop type
	var matching: Array[PropData] = []
	for p in _prop_types:
		if p.display_name in preferred_names:
			matching.append(p)

	if matching.is_empty():
		return null

	return matching[randi() % matching.size()]

#endregion


#region Position Tracking

func _is_position_free(pos: Vector3) -> bool:
	var key := Vector2i(int(floor(pos.x)), int(floor(pos.z)))
	if _occupied_positions.has(key):
		return false

	# Also check if a building is already here (query Buildings node)
	var buildings_root: Node = get_tree().current_scene.get_node_or_null("Buildings")
	if buildings_root:
		for child in buildings_root.get_children():
			var child_node := child as Node3D
			if child_node:
				var bx: int = int(round(child_node.global_position.x - 0.5))
				var bz: int = int(round(child_node.global_position.z - 0.5))
				if bx == key.x and bz == key.y:
					return false

	return true


func _filter_free_positions(candidates: Array[Vector3]) -> Array[Vector3]:
	var free: Array[Vector3] = []
	for c in candidates:
		if _is_position_free(c):
			free.append(c)
	return free


func _mark_occupied(pos: Vector3) -> void:
	var key := Vector2i(int(floor(pos.x)), int(floor(pos.z)))
	_occupied_positions[key] = true


func _unmark_occupied(pos: Vector3) -> void:
	var key := Vector2i(int(floor(pos.x)), int(floor(pos.z)))
	_occupied_positions.erase(key)

#endregion


#region Helpers

func _get_nature_props() -> Array[PropData]:
	var nature: Array[PropData] = []
	for p in _prop_types:
		if p.display_name in NATURE_PROP_NAMES:
			nature.append(p)
	return nature


## Smallest visible scale. Never use Vector3.ZERO for animations:
## a zero-scale basis is non-invertible and spams "det == 0"
## errors from engine math (physics/culling) on every affected node.
const MIN_SCALE: Vector3 = Vector3(0.001, 0.001, 0.001)


func _play_pop_animation(prop: Node3D) -> void:
	prop.scale = MIN_SCALE
	var tween := create_tween()
	tween.tween_property(prop, "scale", Vector3(1.1, 1.1, 1.1), 0.12).set_ease(Tween.EASE_OUT)
	tween.tween_property(prop, "scale", Vector3.ONE, 0.08).set_ease(Tween.EASE_IN_OUT)


## Clean up invalid prop references (nodes freed externally)
func _cleanup_invalid_refs() -> void:
	var valid: Array[StaticBody3D] = []
	for p in _placed_props:
		if is_instance_valid(p):
			valid.append(p)
	_placed_props = valid

#endregion


#region Save/Load Support

## Serialize all placed props for saving
func serialize_props() -> Array[Dictionary]:
	_cleanup_invalid_refs()
	var data: Array[Dictionary] = []
	for prop in _placed_props:
		if not is_instance_valid(prop):
			continue
		data.append({
			"name": prop.get_meta("prop_name", ""),
			"x": prop.position.x,
			"y": prop.position.y,
			"z": prop.position.z,
			"rot_y": prop.rotation.y,
		})
	return data


## Restore props from saved data
func deserialize_props(saved_data: Array) -> void:
	# A save can load while still in the main menu, before the world scene
	# provides a props root. Buffer instead of dropping the props.
	if not _props_root:
		_pending_props_data = saved_data.duplicate()
		return

	# Clear existing props
	clear_all_props()

	for entry in saved_data:
		var prop_name: String = entry.get("name", "")
		var prop_data: PropData = get_prop_data(prop_name)
		if not prop_data:
			push_warning("PropManager: Unknown prop '%s' in save data, skipping." % prop_name)
			continue

		var pos := Vector3(
			entry.get("x", 0.0),
			entry.get("y", Config.GROUND_Y),
			entry.get("z", 0.0),
		)

		var prop: StaticBody3D = place_prop(pos, prop_data, false)
		if prop:
			prop.rotation.y = entry.get("rot_y", 0.0)


## Remove all props
func clear_all_props() -> void:
	for prop in _placed_props:
		if is_instance_valid(prop):
			prop.queue_free()
	_placed_props.clear()
	_occupied_positions.clear()

#endregion
