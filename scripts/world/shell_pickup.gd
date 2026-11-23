class_name ShellPickup
extends Area3D

## One collectible shell on the beach. Walking into it collects it
## (Area3D, filtered to the Player - terrain bodies are ignored).
## Bobbing and turning so kids spot it from afar.

signal collected(position: Vector3)

const PICKUP_RADIUS: float = 0.9
const BASE_SCALE: float = 1.35 ## chunky enough to spot from afar
const PULSE: float = 0.1 ## gentle size glint so the eye catches it
const COLORS: Array[Color] = [
	Color(1.0, 0.72, 0.78), # pink
	Color(0.96, 0.88, 0.72), # sand
	Color(0.9, 0.93, 0.97), # pearl
]

var _base_y: float = 0.0
var _t: float = 0.0
var _rng := RandomNumberGenerator.new()
var _sparkle: Label3D = null
var _sparkle_phase: float = 0.0


func _ready() -> void:
	_rng.randomize()
	_base_y = position.y
	_sparkle_phase = _rng.randf_range(0.0, TAU)
	scale = Vector3.ONE * BASE_SCALE

	collision_layer = 0
	collision_mask = 1 # catch bodies, filter for Player in the handler
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = PICKUP_RADIUS
	shape.shape = sphere
	add_child(shape)
	body_entered.connect(_on_body_entered)

	_build_mesh()


## Chunky scallop shell: a fanned half-disc of ribbed plates with a
## bright pearl highlight and a little hinge - readable as a shell
## from across the beach, not just a stack of boxes.
func _build_mesh() -> void:
	var c: Color = COLORS[_rng.randi_range(0, COLORS.size() - 1)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Hinge knob at the back
	SurfaceBoxes.add_box(st, Vector3(-0.09, 0.0, -0.2), Vector3(0.09, 0.1, -0.1), c.darkened(0.25))

	# Fan: five ribbed segments spreading forward, each a thin wedge
	# that gets wider and slightly taller toward the rim
	var ribs: int = 5
	for i: int in range(ribs):
		var t: float = float(i) / float(ribs - 1) - 0.5 # -0.5..0.5 across the fan
		var spread: float = t * 0.46 # outer half-width at the rim
		var shade: Color = c.lightened(0.08 + 0.16 * absf(t))
		# Wedge from the hinge (narrow) to the rim (wide): built from
		# three stacked boxes that step outwards
		SurfaceBoxes.add_box(st, Vector3(-0.07 + spread * 0.2, 0.0, -0.08), Vector3(0.07 + spread * 0.2, 0.06, 0.06), shade)
		SurfaceBoxes.add_box(st, Vector3(-0.06 + spread * 0.55, 0.0, 0.04), Vector3(0.06 + spread * 0.55, 0.07, 0.18), shade.lightened(0.06))
		SurfaceBoxes.add_box(st, Vector3(-0.05 + spread * 0.95, 0.0, 0.16), Vector3(0.05 + spread * 0.95, 0.06, 0.3), shade.lightened(0.12))
		# Raised rib line along the middle of each segment
		SurfaceBoxes.add_box(st, Vector3(-0.02 + spread * 0.6, 0.06, -0.05), Vector3(0.02 + spread * 0.6, 0.1, 0.28), shade.lightened(0.3))

	# Pearl gleam on the top
	SurfaceBoxes.add_box(st, Vector3(-0.06, 0.1, -0.02), Vector3(0.06, 0.14, 0.14), Color(1.0, 0.98, 0.92))

	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = VertexColorMaterial.make()
	add_child(mi)

	# Sparkle that pops up every couple of seconds so the eye is drawn
	# to the shell even against light sand
	_sparkle = Label3D.new()
	_sparkle.text = "✨"
	_sparkle.font_size = 56
	_sparkle.outline_size = 8
	_sparkle.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sparkle.position = Vector3(0.0, 0.55, 0.0)
	_sparkle.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_sparkle.no_depth_test = true
	add_child(_sparkle)


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		collected.emit(global_position)
		queue_free()


func _process(delta: float) -> void:
	_t += delta
	rotation.y += delta * 1.4
	position.y = _base_y + sin(_t * 2.4) * 0.08
	scale = Vector3.ONE * (BASE_SCALE + sin(_t * 3.0) * PULSE)

	# Sparkle blink: short bright pulse every ~2.4 s, staggered per shell
	if _sparkle:
		var phase: float = fposmod(_t + _sparkle_phase, 2.4)
		var a: float = 0.0
		if phase < 0.7:
			a = sin(phase / 0.7 * PI) # rise and fall
		_sparkle.modulate.a = a
		_sparkle.position.y = 0.5 + phase * 0.35
		_sparkle.scale = Vector3.ONE * (0.8 + 0.5 * a)
