extends Resource
class_name BuildingData

## Building Data Resource
##
## Defines a building type with its properties, costs, and unlock requirements.
## Education points from quizzes are used as the building resource.

## Display name of the building
@export var display_name: String = "Building"

## Description shown to player
@export_multiline var description: String = ""

## Building category for organization
@export_enum("residential", "commercial", "education", "industry", "decoration") var category: String = "residential"

## Size in voxel units (width, height, depth)
@export var size: Vector3i = Vector3i(1, 1, 1)

## Cost in education points to build
@export var cost: int = 10

## Required quiz category to unlock (empty = any category)
@export var required_category: String = ""

## Minimum quiz questions answered correctly to unlock
@export var required_correct_answers: int = 0

## Building color (primary)
@export var color: Color = Color.CORNFLOWER_BLUE

## Optional secondary color for details
@export var secondary_color: Color = Color.WHITE

## Icon for UI display (optional)
@export var icon: Texture2D

## Whether this building can be stacked vertically
@export var stackable: bool = true

## Population capacity (for residential buildings)
@export var population: int = 0

## Education bonus (for education buildings like schools)
@export var education_bonus: float = 0.0

## Income generated per cycle (for commercial buildings)
@export var income: int = 0


## Check if player meets unlock requirements
func is_unlocked(stats: Dictionary) -> bool:
	# Check category requirement
	if required_category != "":
		var category_correct: int = stats.get("correct_" + required_category, 0)
		if category_correct < required_correct_answers:
			return false
	else:
		# Any category counts
		var total_correct: int = stats.get("total_correct", 0)
		if total_correct < required_correct_answers:
			return false
	return true


## Check if player can afford this building
func can_afford(education_points: int) -> bool:
	return education_points >= cost


## Get unlock progress as percentage (0.0 to 1.0)
func get_unlock_progress(stats: Dictionary) -> float:
	if required_correct_answers <= 0:
		return 1.0

	var current: int = 0
	if required_category != "":
		current = stats.get("correct_" + required_category, 0)
	else:
		current = stats.get("total_correct", 0)

	return clampf(float(current) / float(required_correct_answers), 0.0, 1.0)


## Create a preview mesh for this building
func create_preview_mesh(transparent: bool = true) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()

	# Create combined mesh for multi-block buildings
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Generate boxes for each cell of the building
	for x in range(size.x):
		for y in range(size.y):
			for z in range(size.z):
				_add_box_to_surface(surface_tool, Vector3(x, y, z))

	surface_tool.generate_normals()
	mesh_instance.mesh = surface_tool.commit()

	# Create material
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if transparent:
		mat.albedo_color.a = 0.6
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	mesh_instance.material_override = mat

	return mesh_instance


func _add_box_to_surface(st: SurfaceTool, offset: Vector3) -> void:
	var s := 0.98 # Slightly smaller for gaps
	var o := offset

	# Front face (+Z)
	st.add_vertex(Vector3(o.x, o.y, o.z + s))
	st.add_vertex(Vector3(o.x + s, o.y, o.z + s))
	st.add_vertex(Vector3(o.x + s, o.y + s, o.z + s))
	st.add_vertex(Vector3(o.x, o.y, o.z + s))
	st.add_vertex(Vector3(o.x + s, o.y + s, o.z + s))
	st.add_vertex(Vector3(o.x, o.y + s, o.z + s))

	# Back face (-Z)
	st.add_vertex(Vector3(o.x + s, o.y, o.z))
	st.add_vertex(Vector3(o.x, o.y, o.z))
	st.add_vertex(Vector3(o.x, o.y + s, o.z))
	st.add_vertex(Vector3(o.x + s, o.y, o.z))
	st.add_vertex(Vector3(o.x, o.y + s, o.z))
	st.add_vertex(Vector3(o.x + s, o.y + s, o.z))

	# Right face (+X)
	st.add_vertex(Vector3(o.x + s, o.y, o.z + s))
	st.add_vertex(Vector3(o.x + s, o.y, o.z))
	st.add_vertex(Vector3(o.x + s, o.y + s, o.z))
	st.add_vertex(Vector3(o.x + s, o.y, o.z + s))
	st.add_vertex(Vector3(o.x + s, o.y + s, o.z))
	st.add_vertex(Vector3(o.x + s, o.y + s, o.z + s))

	# Left face (-X)
	st.add_vertex(Vector3(o.x, o.y, o.z))
	st.add_vertex(Vector3(o.x, o.y, o.z + s))
	st.add_vertex(Vector3(o.x, o.y + s, o.z + s))
	st.add_vertex(Vector3(o.x, o.y, o.z))
	st.add_vertex(Vector3(o.x, o.y + s, o.z + s))
	st.add_vertex(Vector3(o.x, o.y + s, o.z))

	# Top face (+Y)
	st.add_vertex(Vector3(o.x, o.y + s, o.z + s))
	st.add_vertex(Vector3(o.x + s, o.y + s, o.z + s))
	st.add_vertex(Vector3(o.x + s, o.y + s, o.z))
	st.add_vertex(Vector3(o.x, o.y + s, o.z + s))
	st.add_vertex(Vector3(o.x + s, o.y + s, o.z))
	st.add_vertex(Vector3(o.x, o.y + s, o.z))

	# Bottom face (-Y)
	st.add_vertex(Vector3(o.x, o.y, o.z))
	st.add_vertex(Vector3(o.x + s, o.y, o.z))
	st.add_vertex(Vector3(o.x + s, o.y, o.z + s))
	st.add_vertex(Vector3(o.x, o.y, o.z))
	st.add_vertex(Vector3(o.x + s, o.y, o.z + s))
	st.add_vertex(Vector3(o.x, o.y, o.z + s))
