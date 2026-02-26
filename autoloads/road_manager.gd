extends Node

## Road Manager (Autoload)
##
## Handles road auto-connection logic.
## When a road is placed, updates neighboring roads to connect properly.

signal road_updated(position: Vector3i, road_type: int)

## Road types based on connections
enum RoadType {
	SINGLE = 0, # No connections (isolated)
	STRAIGHT_NS = 1, # North-South (Z-axis)
	STRAIGHT_EW = 2, # East-West (X-axis)
	CORNER_NE = 3, # Connects North + East
	CORNER_NW = 4, # Connects North + West
	CORNER_SE = 5, # Connects South + East
	CORNER_SW = 6, # Connects South + West
	T_NORTH = 7, # T facing North (missing South)
	T_SOUTH = 8, # T facing South (missing North)
	T_EAST = 9, # T facing East (missing West)
	T_WEST = 10, # T facing West (missing East)
	CROSS = 11, # 4-way intersection
}

## Direction flags for bitmask
const DIR_NORTH: int = 1 # -Z
const DIR_SOUTH: int = 2 # +Z
const DIR_EAST: int = 4 # +X
const DIR_WEST: int = 8 # -X

## Store all road positions -> Node3D reference
var _roads: Dictionary = {} # Vector3i -> Node3D


func _ready() -> void:
	# Connect to BuildingManager for road placement events
	if BuildingManager:
		BuildingManager.building_placed_event.connect(_on_building_placed)


func _on_building_placed(building: BuildingData, pos: Vector3i) -> void:
	if building.category != "infrastructure":
		return
	
	# Find the actual node that was just placed
	call_deferred("_register_new_road", pos)


func _register_new_road(pos: Vector3i) -> void:
	# Wait a frame for the node to be added
	await get_tree().process_frame
	
	var buildings_root: Node = get_tree().current_scene.get_node_or_null("Buildings")
	if not buildings_root:
		return
	
	# Find the road node at this position
	for child in buildings_root.get_children():
		var child_node := child as Node3D
		if child_node:
			var cx: int = int(round(child_node.global_position.x - 0.5))
			var cy: int = int(round(child_node.global_position.y))
			var cz: int = int(round(child_node.global_position.z - 0.5))
			var child_pos := Vector3i(cx, cy, cz)
			
			if child_pos == pos and not _roads.has(pos):
				_roads[pos] = child_node
				_update_road_and_neighbors(pos)
				return


## Get the road type based on neighbor connections
func _get_road_type(pos: Vector3i) -> int:
	var connections: int = _get_connection_mask(pos)
	
	match connections:
		0: return RoadType.SINGLE
		DIR_NORTH, DIR_SOUTH: return RoadType.STRAIGHT_NS
		DIR_NORTH | DIR_SOUTH: return RoadType.STRAIGHT_NS
		DIR_EAST, DIR_WEST: return RoadType.STRAIGHT_EW
		DIR_EAST | DIR_WEST: return RoadType.STRAIGHT_EW
		DIR_NORTH | DIR_EAST: return RoadType.CORNER_NE
		DIR_NORTH | DIR_WEST: return RoadType.CORNER_NW
		DIR_SOUTH | DIR_EAST: return RoadType.CORNER_SE
		DIR_SOUTH | DIR_WEST: return RoadType.CORNER_SW
		DIR_NORTH | DIR_EAST | DIR_WEST: return RoadType.T_NORTH
		DIR_SOUTH | DIR_EAST | DIR_WEST: return RoadType.T_SOUTH
		DIR_NORTH | DIR_SOUTH | DIR_EAST: return RoadType.T_EAST
		DIR_NORTH | DIR_SOUTH | DIR_WEST: return RoadType.T_WEST
		DIR_NORTH | DIR_SOUTH | DIR_EAST | DIR_WEST: return RoadType.CROSS
		_: return RoadType.SINGLE


## Get bitmask of connected neighbors
func _get_connection_mask(pos: Vector3i) -> int:
	var mask: int = 0
	
	if _roads.has(Vector3i(pos.x, pos.y, pos.z - 1)):
		mask |= DIR_NORTH
	if _roads.has(Vector3i(pos.x, pos.y, pos.z + 1)):
		mask |= DIR_SOUTH
	if _roads.has(Vector3i(pos.x + 1, pos.y, pos.z)):
		mask |= DIR_EAST
	if _roads.has(Vector3i(pos.x - 1, pos.y, pos.z)):
		mask |= DIR_WEST
	
	return mask


## Update a road and all its neighbors
func _update_road_and_neighbors(pos: Vector3i) -> void:
	_update_road_mesh(pos)
	
	# Update neighbors
	var neighbors: Array[Vector3i] = [
		Vector3i(pos.x, pos.y, pos.z - 1), # North
		Vector3i(pos.x, pos.y, pos.z + 1), # South
		Vector3i(pos.x + 1, pos.y, pos.z), # East
		Vector3i(pos.x - 1, pos.y, pos.z), # West
	]
	
	for neighbor_pos: Vector3i in neighbors:
		if _roads.has(neighbor_pos):
			_update_road_mesh(neighbor_pos)


## Update the mesh of a road based on its connections
func _update_road_mesh(pos: Vector3i) -> void:
	if not _roads.has(pos):
		return

	var road_node: Node3D = _roads[pos]
	if not is_instance_valid(road_node):
		_roads.erase(pos)
		return

	var road_type: int = _get_road_type(pos)
	_apply_road_mesh(road_node, road_type)
	road_updated.emit(pos, road_type)


## Apply the correct mesh for the road type
func _apply_road_mesh(road_node: Node3D, road_type: int) -> void:
	var mesh_instance: MeshInstance3D = road_node.get_node_or_null("MeshInstance3D")
	if not mesh_instance:
		return

	# Get or create the road mesh
	var road_mesh := _create_road_mesh(road_type)
	mesh_instance.mesh = road_mesh

	# Reset rotation (we handle direction in mesh generation)
	mesh_instance.rotation = Vector3.ZERO


## Create a road mesh for the given type
func _create_road_mesh(road_type: int) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var road_color := Color(0.25, 0.25, 0.28) # Dark gray asphalt
	var line_color := Color(0.9, 0.9, 0.8) # Yellow-white lines

	# Base road slab (slightly lower than 1.0)
	var height: float = 0.15

	# Main road surface
	st.set_color(road_color)
	_add_box(st, Vector3(0, 0, 0), Vector3(1.0, height, 1.0))

	# Add road markings based on type
	var line_h: float = height + 0.01 # Slightly above road
	var line_w: float = 0.08

	st.set_color(line_color)

	match road_type:
		RoadType.STRAIGHT_NS:
			# Center line along Z
			_add_box(st, Vector3(0.46, line_h, 0.1), Vector3(line_w, 0.01, 0.3))
			_add_box(st, Vector3(0.46, line_h, 0.6), Vector3(line_w, 0.01, 0.3))
		RoadType.STRAIGHT_EW:
			# Center line along X
			_add_box(st, Vector3(0.1, line_h, 0.46), Vector3(0.3, 0.01, line_w))
			_add_box(st, Vector3(0.6, line_h, 0.46), Vector3(0.3, 0.01, line_w))
		RoadType.CROSS:
			# No center lines on crossroads, just corners
			pass
		RoadType.CORNER_NE, RoadType.CORNER_NW, RoadType.CORNER_SE, RoadType.CORNER_SW:
			# Corner markings
			pass
		RoadType.T_NORTH, RoadType.T_SOUTH, RoadType.T_EAST, RoadType.T_WEST:
			# T-junction markings
			pass
		_:
			# Single/default - no special markings
			pass

	st.generate_normals()
	return st.commit()


## Helper to add a box to SurfaceTool
func _add_box(st: SurfaceTool, offset: Vector3, size: Vector3) -> void:
	var x1: float = offset.x
	var y1: float = offset.y
	var z1: float = offset.z
	var x2: float = offset.x + size.x
	var y2: float = offset.y + size.y
	var z2: float = offset.z + size.z

	# Top face
	st.add_vertex(Vector3(x1, y2, z1))
	st.add_vertex(Vector3(x2, y2, z1))
	st.add_vertex(Vector3(x2, y2, z2))
	st.add_vertex(Vector3(x1, y2, z1))
	st.add_vertex(Vector3(x2, y2, z2))
	st.add_vertex(Vector3(x1, y2, z2))

	# Bottom face
	st.add_vertex(Vector3(x2, y1, z1))
	st.add_vertex(Vector3(x1, y1, z1))
	st.add_vertex(Vector3(x1, y1, z2))
	st.add_vertex(Vector3(x2, y1, z1))
	st.add_vertex(Vector3(x1, y1, z2))
	st.add_vertex(Vector3(x2, y1, z2))

	# Front face (+Z)
	st.add_vertex(Vector3(x1, y1, z2))
	st.add_vertex(Vector3(x1, y2, z2))
	st.add_vertex(Vector3(x2, y2, z2))
	st.add_vertex(Vector3(x1, y1, z2))
	st.add_vertex(Vector3(x2, y2, z2))
	st.add_vertex(Vector3(x2, y1, z2))

	# Back face (-Z)
	st.add_vertex(Vector3(x2, y1, z1))
	st.add_vertex(Vector3(x2, y2, z1))
	st.add_vertex(Vector3(x1, y2, z1))
	st.add_vertex(Vector3(x2, y1, z1))
	st.add_vertex(Vector3(x1, y2, z1))
	st.add_vertex(Vector3(x1, y1, z1))

	# Right face (+X)
	st.add_vertex(Vector3(x2, y1, z1))
	st.add_vertex(Vector3(x2, y1, z2))
	st.add_vertex(Vector3(x2, y2, z2))
	st.add_vertex(Vector3(x2, y1, z1))
	st.add_vertex(Vector3(x2, y2, z2))
	st.add_vertex(Vector3(x2, y2, z1))

	# Left face (-X)
	st.add_vertex(Vector3(x1, y1, z2))
	st.add_vertex(Vector3(x1, y1, z1))
	st.add_vertex(Vector3(x1, y2, z1))
	st.add_vertex(Vector3(x1, y1, z2))
	st.add_vertex(Vector3(x1, y2, z1))
	st.add_vertex(Vector3(x1, y2, z2))


## Called when a road is removed
func unregister_road(pos: Vector3i) -> void:
	if _roads.has(pos):
		_roads.erase(pos)
		# Update neighbors
		var neighbors: Array[Vector3i] = [
			Vector3i(pos.x, pos.y, pos.z - 1),
			Vector3i(pos.x, pos.y, pos.z + 1),
			Vector3i(pos.x + 1, pos.y, pos.z),
			Vector3i(pos.x - 1, pos.y, pos.z),
		]
		for neighbor_pos: Vector3i in neighbors:
			if _roads.has(neighbor_pos):
				_update_road_mesh(neighbor_pos)
