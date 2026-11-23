class_name ShellPickup
extends Area3D

## One collectible shell on the beach. Walking into it collects it
## (Area3D, filtered to the Player - terrain bodies are ignored).
## Bobbing and turning so kids spot it from afar.

signal collected(position: Vector3)

const PICKUP_RADIUS: float = 0.9
const COLORS: Array[Color] = [
	Color(1.0, 0.72, 0.78), # pink
	Color(0.96, 0.88, 0.72), # sand
	Color(0.9, 0.93, 0.97), # pearl
]

var _base_y: float = 0.0
var _t: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_base_y = position.y

	collision_layer = 0
	collision_mask = 1 # catch bodies, filter for Player in the handler
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = PICKUP_RADIUS
	shape.shape = sphere
	add_child(shape)
	body_entered.connect(_on_body_entered)

	_build_mesh()


## Chunky shell fan: three stacked, shrinking plates
func _build_mesh() -> void:
	var c: Color = COLORS[_rng.randi_range(0, COLORS.size() - 1)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	SurfaceBoxes.add_box(st, Vector3(-0.24, 0.0, -0.19), Vector3(0.24, 0.07, 0.19), c)
	SurfaceBoxes.add_box(st, Vector3(-0.17, 0.07, -0.14), Vector3(0.17, 0.14, 0.14), c.lightened(0.12))
	SurfaceBoxes.add_box(st, Vector3(-0.08, 0.14, -0.07), Vector3(0.08, 0.21, 0.07), c.lightened(0.24))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = VertexColorMaterial.make()
	add_child(mi)


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		collected.emit(global_position)
		queue_free()


func _process(delta: float) -> void:
	_t += delta
	rotation.y += delta * 1.4
	position.y = _base_y + sin(_t * 2.4) * 0.06
