extends Node

## Prop Manager (Autoload)
##
## Manages prop spawning, tracking, removal, and saving.
##
## Streaming-aware: prop DATA lives in per-chunk records (a Dictionary per
## chunk key) and survives chunk load/unload cycles. Live prop NODES only
## exist while their chunk is streamed in - ChunkManager's signals spawn
## them on chunk_became_loaded and free them on chunk_became_unloaded.
## Saves serialize the records (world-wide, including unloaded areas).
##
## Connects to BuildingManager.building_placed_event to auto-decorate.

const PropMeshGen := preload("res://scripts/visuals/prop_mesh_generator.gd")

signal prop_placed(position: Vector3, prop_name: String)
signal prop_removed(position: Vector3)
signal initialized

## Nature props scattered per chunk at game start
const PROPS_PER_CHUNK_MIN: int = 4
const PROPS_PER_CHUNK_MAX: int = 7
## Live node cap (records bound the real count; this only guards runaway)
const LIVE_PROP_CAP: int = 1000

## All loaded prop types
var _prop_types: Array[PropData] = []

## Active (live) props in the scene
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

## Prop DATA per chunk. Key: Vector2i chunk, Value: Array[Dictionary]
## entries {name, x, y, z, rot_y}. Persistent across load/unload cycles.
var _prop_records: Dictionary = {}

## Live prop nodes per chunk. Key: Vector2i chunk, Value: Array[StaticBody3D]
var _live_props_by_chunk: Dictionary = {}

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

	# Connect to building placement and chunk streaming (deferred – other
	# autoloads may initialize after this one)
	call_deferred("_connect_signals")


func _connect_signals() -> void:
	if BuildingManager:
		BuildingManager.building_placed_event.connect(_on_building_placed)
	if ChunkManager and ChunkManager.has_signal("chunk_became_loaded"):
		ChunkManager.chunk_became_loaded.connect(_on_chunk_became_loaded)
		ChunkManager.chunk_became_unloaded.connect(_on_chunk_became_unloaded)


## Initialize with a parent node for all props
func initialize(props_root: Node3D) -> void:
	_props_root = props_root
	set_max_props(LIVE_PROP_CAP)
	clear_all_props()
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
		# Exported builds remap resources to "*.tres.remap"/"*.res.remap"
		# inside the PCK; load() resolves the trimmed path in both modes.
		var trimmed := file_name.trim_suffix(".remap")
		if trimmed.ends_with(".tres") or trimmed.ends_with(".res"):
			var resource := load(props_path + trimmed)
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


## Scatter nature props across the whole world (data only), then spawn nodes
## for the chunks that are currently streamed in.
func decorate_world() -> void:
	if not _props_root:
		push_warning("PropManager: No props root set. Call initialize() first.")
		return

	# A restored save already provides records for visited chunks; fill in
	# records for any chunk that has none yet (world may have grown since
	# the save was created).
	var nature_props: Array[PropData] = _get_nature_props()
	if nature_props.is_empty():
		return

	var world_r: int = Config.WORLD_CHUNK_RADIUS
	for cx in range(-world_r, world_r + 1):
		for cz in range(-world_r, world_r + 1):
			var chunk_key := Vector2i(cx, cz)
			if not _prop_records.has(chunk_key):
				_decorate_chunk(chunk_key, nature_props)

	_spawn_props_for_loaded_chunks()


## Generate the prop records for one chunk (no nodes are created).
## Props only grow on interior grass - never in the sea, on the beach,
## in the river or on the mountain rim.
func _decorate_chunk(chunk_key: Vector2i, nature_props: Array[PropData]) -> void:
	var count: int = randi_range(PROPS_PER_CHUNK_MIN, PROPS_PER_CHUNK_MAX)
	var origin_x: int = chunk_key.x * Config.CHUNK_SIZE
	var origin_z: int = chunk_key.y * Config.CHUNK_SIZE

	for i in range(count):
		var pos := Vector3(
			float(origin_x + randi_range(0, Config.CHUNK_SIZE - 1)) + 0.5,
			Config.GROUND_Y,
			float(origin_z + randi_range(0, Config.CHUNK_SIZE - 1)) + 0.5
		)
		if not _is_buildable_land(pos):
			continue
		var prop_data: PropData = nature_props[randi() % nature_props.size()]
		var entry := {
			"name": prop_data.display_name,
			"x": pos.x,
			"y": pos.y,
			"z": pos.z,
			"rot_y": randf() * TAU,
		}
		_add_record(entry)


## True if the column under pos is walkable interior grass (same rule as
## building placement and NPC spawns).
func _is_buildable_land(pos: Vector3) -> bool:
	var col: Dictionary = WorldManager.terrain_column(int(floor(pos.x)), int(floor(pos.z)))
	if col["top"] != Config.VoxelType.GRASS or col["water"]:
		return false
	# Keep nature props out of the hedge labyrinth footprint
	return not BushMaze.is_in_maze(int(floor(pos.x)), int(floor(pos.z)))


## Place a prop at a world position (records it and spawns the node)
func place_prop(pos: Vector3, prop_data: PropData, deduct_cost: bool = true) -> StaticBody3D:
	if not _props_root:
		push_error("PropManager: No props root. Call initialize() first.")
		return null

	# No props in the sea, on the beach, in the river or on cliffs
	if not _is_buildable_land(pos):
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

	var entry := {
		"name": prop_data.display_name,
		"x": pos.x,
		"y": pos.y,
		"z": pos.z,
		"rot_y": randf() * TAU,
	}
	var prop: StaticBody3D = _spawn_prop_node(entry, prop_data, true)
	if prop:
		_add_record(entry)
	return prop


## Build the actual node for a record entry. notify=false (streaming respawn)
## suppresses the prop_placed signal so saves are not re-triggered on every
## chunk load/unload cycle.
func _spawn_prop_node(entry: Dictionary, prop_data: PropData = null, notify: bool = false) -> StaticBody3D:
	if not _props_root or not is_instance_valid(_props_root):
		return null
	if _placed_props.size() >= _max_props:
		push_warning("PropManager: Max prop limit (%d) reached." % _max_props)
		return null

	if prop_data == null:
		prop_data = get_prop_data(entry.get("name", ""))
		if prop_data == null:
			push_warning("PropManager: Unknown prop '%s', skipping." % entry.get("name", ""))
			return null

	var pos := Vector3(entry.get("x", 0.0), entry.get("y", Config.GROUND_Y), entry.get("z", 0.0))

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

	# Position and rotation
	prop.position = pos
	prop.rotation.y = entry.get("rot_y", 0.0)

	_props_root.add_child(prop)
	_placed_props.append(prop)
	_mark_occupied(pos)
	_register_live(prop)

	# Pop-in animation
	_play_pop_animation(prop)

	if notify:
		prop_placed.emit(pos, prop_data.display_name)
	return prop


## Remove a prop permanently (middle-click or programmatic)
func remove_prop(prop: StaticBody3D) -> void:
	if not is_instance_valid(prop):
		return

	var pos: Vector3 = prop.position
	_unmark_occupied(pos)
	_placed_props.erase(prop)
	_unregister_live(prop)
	_remove_record(prop.position)

	# Shrink-out animation then free
	var tween := create_tween()
	tween.tween_property(prop, "scale", MIN_SCALE, 0.15).set_ease(Tween.EASE_IN)
	tween.tween_callback(prop.queue_free)

	prop_removed.emit(pos)


## Get current (live) prop count
func get_prop_count() -> int:
	return _placed_props.size()


## Get max prop limit
func get_max_props() -> int:
	return _max_props


## Dynamically adjust max props (e.g., based on FPS)
func set_max_props(new_max: int) -> void:
	_max_props = maxi(10, new_max)

#endregion


#region Chunk Streaming

## Chunk key for a world position (matches ChunkManager's coordinates)
func _chunk_key_for_pos(pos: Vector3) -> Vector2i:
	return Vector2i(
		floori(pos.x / float(Config.CHUNK_SIZE)),
		floori(pos.z / float(Config.CHUNK_SIZE)))


## Store a prop entry in its chunk's record and mark the cell occupied
func _add_record(entry: Dictionary) -> void:
	var pos := Vector3(entry.get("x", 0.0), entry.get("y", 0.0), entry.get("z", 0.0))
	var chunk_key := _chunk_key_for_pos(pos)
	if not _prop_records.has(chunk_key):
		_prop_records[chunk_key] = []
	(_prop_records[chunk_key] as Array).append(entry)
	_mark_occupied(pos)


## Delete the record entry occupying the same grid cell as pos
func _remove_record(pos: Vector3) -> void:
	var chunk_key := _chunk_key_for_pos(pos)
	if not _prop_records.has(chunk_key):
		return
	var cell := Vector2i(int(floor(pos.x)), int(floor(pos.z)))
	var entries: Array = _prop_records[chunk_key]
	for i in range(entries.size()):
		var e: Dictionary = entries[i]
		var e_cell := Vector2i(int(floor(e.get("x", 0.0))), int(floor(e.get("z", 0.0))))
		if e_cell == cell:
			entries.remove_at(i)
			return


## Track a live node in the per-chunk map
func _register_live(prop: StaticBody3D) -> void:
	var chunk_key := _chunk_key_for_pos(prop.position)
	if not _live_props_by_chunk.has(chunk_key):
		_live_props_by_chunk[chunk_key] = []
	(_live_props_by_chunk[chunk_key] as Array).append(prop)


## Stop tracking a live node (removal or unload)
func _unregister_live(prop: StaticBody3D) -> void:
	var chunk_key := _chunk_key_for_pos(prop.position)
	if not _live_props_by_chunk.has(chunk_key):
		return
	var live: Array = _live_props_by_chunk[chunk_key]
	live.erase(prop)
	if live.is_empty():
		_live_props_by_chunk.erase(chunk_key)


## Spawn nodes for every chunk that is currently loaded (initial fill)
func _spawn_props_for_loaded_chunks() -> void:
	if not _props_root or not is_instance_valid(_props_root):
		return
	for chunk_key: Variant in _prop_records.keys().duplicate():
		var key: Vector2i = chunk_key
		if ChunkManager and ChunkManager.is_chunk_loaded(key.x, key.y):
			_spawn_props_for_chunk(key)


## Spawn the recorded props of one chunk (no-op if already live)
func _spawn_props_for_chunk(chunk_key: Vector2i) -> void:
	if _live_props_by_chunk.has(chunk_key):
		return # already spawned
	if not _prop_records.has(chunk_key):
		return
	_live_props_by_chunk[chunk_key] = []
	for entry: Dictionary in _prop_records[chunk_key]:
		_spawn_prop_node(entry, null, false)


## A chunk streamed in: spawn its recorded props
func _on_chunk_became_loaded(chunk_x: int, chunk_z: int) -> void:
	if not _props_root or not is_instance_valid(_props_root):
		return
	_spawn_props_for_chunk(Vector2i(chunk_x, chunk_z))


## A chunk streamed out: free its prop nodes (the records persist)
func _on_chunk_became_unloaded(chunk_x: int, chunk_z: int) -> void:
	var chunk_key := Vector2i(chunk_x, chunk_z)
	if not _live_props_by_chunk.has(chunk_key):
		return
	var live: Array = _live_props_by_chunk[chunk_key]
	for prop in live:
		if is_instance_valid(prop):
			prop.queue_free()
		_placed_props.erase(prop)
	_live_props_by_chunk.erase(chunk_key)

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
	var matching: Array = []
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

	# Also check if a building is already here (query Buildings node).
	# current_scene can be null during early _ready calls (e.g. headless).
	var buildings_root: Node = null
	var scene: Node = get_tree().current_scene
	if scene:
		buildings_root = scene.get_node_or_null("Buildings")
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

## Serialize ALL prop records (including unloaded chunks) for saving
func serialize_props() -> Array[Dictionary]:
	var data: Array[Dictionary] = []
	for chunk_key: Variant in _prop_records:
		var entries: Array = _prop_records[chunk_key]
		for entry: Dictionary in entries:
			data.append(entry)
	return data


## Restore props from saved data (rebuilds records, spawns loaded chunks only)
func deserialize_props(saved_data: Array) -> void:
	# A save can load while still in the main menu, before the world scene
	# provides a props root. Buffer instead of dropping the props.
	if not _props_root:
		_pending_props_data = saved_data.duplicate()
		return

	# Clear existing props and records
	clear_all_props()

	for raw in saved_data:
		var entry: Dictionary = {
			"name": raw.get("name", ""),
			"x": raw.get("x", 0.0),
			"y": raw.get("y", Config.GROUND_Y),
			"z": raw.get("z", 0.0),
			"rot_y": raw.get("rot_y", 0.0),
		}
		if get_prop_data(entry["name"]) == null:
			push_warning("PropManager: Unknown prop '%s' in save data, skipping." % entry["name"])
			continue
		# Terrain may have changed since the save (e.g. a river now flows
		# here): drop props that no longer stand on land.
		var saved_pos := Vector3(entry["x"], entry["y"], entry["z"])
		if not _is_buildable_land(saved_pos):
			continue
		_add_record(entry)

	_spawn_props_for_loaded_chunks()


## Remove all prop nodes and records
func clear_all_props() -> void:
	for prop in _placed_props:
		if is_instance_valid(prop):
			prop.queue_free()
	_placed_props.clear()
	_occupied_positions.clear()
	_prop_records.clear()
	_live_props_by_chunk.clear()

#endregion
